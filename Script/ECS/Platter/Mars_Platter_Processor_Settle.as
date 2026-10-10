// What one Settle pass saw and did, broadcast at its end.
struct FMars_Platter_SettlePass
{
    FCk_Handle_Platter Platter;
    FTransform RootWorld;
    bool IsStill = false;
    float32 Seconds = 0.0f;
    TArray<FCk_Handle_FoodPiece> Loaded;
    TArray<FMars_Platter_LoadRefused> Refused;
    // Landed pieces something else took while they re-settled.
    TArray<FCk_Handle_FoodPiece> Unloaded;
}

// The pile, every pass: first the settling pieces, then the next drop.
//
// Settle: a Dynamic piece is watched until it rests on the platter (the drift watchdog, in the root's frame so a pile riding
// a carried tray between its walls still settles, or Jolt's sleep), or is frozen where it is at Settle.MaxSeconds (traced).
// Freezing asks for Kinematic; once the body's mirror reads it (utils_jolt_body::Get_MotionType is what the SetMotionType
// handler stamps: attaching a Dynamic body would fight the Jolt writeback) the piece is attached to the root keeping its
// world pose, joins Held, and OnLoaded fires for a first landing. A piece that froze outside the walls (or under the floor)
// is re-dropped once while the root is still, then accepted where it lies. A settling piece something else attached (a
// hand's Carry) is forgotten before it is watched: a re-settling one is unloaded and the rest re-settle.
//
// Drop: while the root is still, one queued piece per Settle.DropCadenceSeconds, oldest first among those that can drop
// (Ready; a body, if it has one, added): it gets its convex body if it has none, is detached, teleported over a random
// point between the walls (utils_platter::Make_DropPose) and turned Dynamic. A queued piece whose import failed is refused
// Failed. A gone piece is Reconcile's.
class UMars_Processor_Platter_Settle : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_Platter);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle, FMars_Fragment_Platter& InState)
    {
        auto Platter = InHandle.As_Platter();
        const auto Spec = Platter.Get_Spec();
        const auto Seconds = float32(InDeltaT.Get_Seconds());

        const auto RootWorld = utils_transform::Get_EntityCurrentTransform(InHandle.As_Transform());
        const auto IsStill = InState.RootLast.IsSet() && utils_platter::Get_IsStill(InState.RootLast.GetValue(), RootWorld);
        InState.RootLast = TOptional<FTransform>(RootWorld);

        if (InState.Settling.Num() == 0 && InState.Queue.Num() == 0)
        { return; }

        auto Pass = FMars_Platter_SettlePass();
        Pass.Platter = Platter;
        Pass.RootWorld = RootWorld;
        Pass.IsStill = IsStill;
        Pass.Seconds = Seconds;

        Settle_Pieces(Pass, InState, Spec);
        if (Pass.Unloaded.Num() > 0)
        { utils_platter::Resettle(InState, RootWorld); }

        // Jolt runs only in a game world: in an editor's preview world a queued piece stays queued.
        const UWorld World = utils_entity_lifetime::Get_WorldForEntity(InHandle);
        const auto CanDrop = IsStill && ck::IsValid(World) && World.IsGameWorld();
        if (CanDrop)
        {
            InState.SinceDrop += Seconds;
            if (InState.SinceDrop >= Spec.Settle.DropCadenceSeconds && Drop_Next(Pass, InState, Spec))
            { InState.SinceDrop = 0.0f; }
        }
        else
        { InState.SinceDrop = 0.0f; }

        Broadcast(Pass);
    }

    private void Settle_Pieces(FMars_Platter_SettlePass& InPass, FMars_Fragment_Platter& InState, const FMars_Platter_Spec& InSpec)
    {
        TArray<FMars_Platter_Settling> StillSettling;
        for (const auto& Entry : InState.Settling)
        {
            auto Settling = Entry;
            if (Get_IsGone(Settling.Piece))
            {
                StillSettling.Add(Settling);
                continue;
            }

            // Taken before it froze: the freeze's attach would pull it back out of the hand.
            if (utils_platter::Get_IsTaken(Settling.Piece))
            {
                Forget_Taken(InPass, Settling);
                continue;
            }

            if (Settling.Freeze.IsSet() == false)
            {
                Watch(InPass, Settling, InSpec);
                StillSettling.Add(Settling);
                continue;
            }

            if (Try_Attach(InPass, Settling, InSpec) == false)
            { StillSettling.Add(Settling); }
            else
            { InState.Held.Add(Settling.Piece); }
        }

        InState.Settling = StillSettling;
    }

    // A piece re-settling had landed: its leaving is an unload. A first landing never landed: it leaves silently.
    private void Forget_Taken(FMars_Platter_SettlePass& InPass, const FMars_Platter_Settling& InSettling)
    {
        auto Piece = InSettling.Piece;
        Piece.Request_TryRemove(FMars_Fragment_Platter_Membership);
        if (InSettling.Reason == EMars_Platter_SettleReason::Resettle)
        { InPass.Unloaded.Add(Piece); }

        ck::Trace(f"[Platter] [{InPass.Platter.ToString()}] [{Piece.ToString()}] was taken while it settled ({InSettling.Reason :n}): it leaves the pile");
    }

    // The watchdog, in the root's frame: a body not added yet only ages.
    private void Watch(const FMars_Platter_SettlePass& InPass, FMars_Platter_Settling& InSettling, const FMars_Platter_Spec& InSpec)
    {
        FCk_Handle PieceEntity = InSettling.Piece;
        auto Body = PieceEntity.As_JoltBody(ECk_SanityCheck::UnChecked);
        InSettling.Seconds += InPass.Seconds;

        if (ck::Is_NOT_Valid(Body) || utils_jolt_body::Get_IsBodyAdded(Body) == false)
        { return; }

        const auto& Tuners = InSpec.Settle;
        InSettling.SinceSample += InPass.Seconds;
        if (InSettling.SinceSample >= Tuners.SampleSeconds)
        {
            const auto Elapsed = InSettling.SinceSample;
            InSettling.SinceSample = 0.0f;

            const auto Location = Get_RootLocal(InPass, InSettling.Piece);
            if (Location.Distance(InSettling.LastSample) <= float64(Tuners.DriftCm))
            { InSettling.StillSeconds += Elapsed; }
            else
            {
                InSettling.StillSeconds = 0.0f;
                InSettling.LastSample = Location;
            }
        }

        // A body asleep in its first sample window may still carry the sleep of its Kinematic past.
        const auto IsAsleep = InPass.IsStill && InSettling.Seconds >= Tuners.SampleSeconds
            && utils_jolt_body::Get_SleepState(Body) == ECk_Jolt_SleepState::Asleep;
        if (InSettling.StillSeconds >= Tuners.DwellSeconds || IsAsleep)
        {
            Freeze(InSettling, EMars_Platter_FreezeCause::Settled);
            return;
        }

        if (InSettling.Seconds >= Tuners.MaxSeconds)
        {
            ck::Trace(f"[Platter] [{InPass.Platter.ToString()}] [{InSettling.Piece.ToString()}] still moving after {InSettling.Seconds} s: frozen where it is");
            Freeze(InSettling, EMars_Platter_FreezeCause::TimedOut);
        }
    }

    private FVector Get_RootLocal(const FMars_Platter_SettlePass& InPass, const FCk_Handle_FoodPiece& InPiece) const
    {
        FCk_Handle PieceEntity = InPiece;
        return InPass.RootWorld.InverseTransformPosition(utils_transform::Get_EntityCurrentTransform(PieceEntity.As_Transform()).GetLocation());
    }

    private void Freeze(FMars_Platter_Settling& InSettling, EMars_Platter_FreezeCause InCause)
    {
        InSettling.Freeze = TOptional<EMars_Platter_FreezeCause>(InCause);

        FCk_Handle PieceEntity = InSettling.Piece;
        auto Body = PieceEntity.As_JoltBody(ECk_SanityCheck::UnChecked);
        if (ck::IsValid(Body))
        { utils_jolt_body::Request_SetMotionType(Body, FCk_Request_JoltBody_SetMotionType(ECk_MotionType::Kinematic)); }
    }

    // True once the piece is attached. The SetMotionType handler drops a request that reaches it before the body is added,
    // so it is asked again until the mirror reads Kinematic. An escape gets one re-drop (the piece stays settling).
    private bool Try_Attach(FMars_Platter_SettlePass& InPass, FMars_Platter_Settling& InSettling, const FMars_Platter_Spec& InSpec)
    {
        FCk_Handle PieceEntity = InSettling.Piece;
        auto Body = PieceEntity.As_JoltBody(ECk_SanityCheck::UnChecked);
        if (ck::IsValid(Body))
        {
            if (utils_jolt_body::Get_IsBodyAdded(Body) == false)
            { return false; }

            if (utils_jolt_body::Get_MotionType(Body) != ECk_MotionType::Kinematic)
            {
                utils_jolt_body::Request_SetMotionType(Body, FCk_Request_JoltBody_SetMotionType(ECk_MotionType::Kinematic));
                return false;
            }
        }

        const auto Cause = InSettling.Freeze.GetValue();
        if (utils_platter::Get_IsInside(InSpec.Bounds, InPass.RootWorld, InSettling.Piece) == false)
        {
            if (InSettling.Redrops < 1 && InPass.IsStill)
            {
                ck::Trace(f"[Platter] [{InPass.Platter.ToString()}] [{InSettling.Piece.ToString()}] froze outside the walls: dropped again");
                Drop_Piece(InPass, InSettling, InSpec);
                return false;
            }

            ck::Trace(f"[Platter] [{InPass.Platter.ToString()}] [{InSettling.Piece.ToString()}] froze outside the walls again: accepted where it lies");
        }

        auto Node = PieceEntity.As_SceneNode(ECk_SanityCheck::UnChecked);
        if (ck::IsValid(Node))
        { utils_scene_node::Request_Detach(Node); }

        FCk_Handle PlatterEntity = InPass.Platter;
        auto Root = PlatterEntity.As_Transform();
        auto PieceTransform = PieceEntity.As_Transform();
        const auto PieceWorld = utils_transform::Get_EntityCurrentTransform(PieceTransform);
        utils_scene_node::Add(PieceTransform, Root, PieceWorld.GetRelativeTransform(InPass.RootWorld));

        if (InSettling.Reason == EMars_Platter_SettleReason::Load)
        { InPass.Loaded.Add(InSettling.Piece); }

        ck::Trace(f"[Platter] [{InPass.Platter.ToString()}] [{InSettling.Piece.ToString()}] froze into the pile ({Cause :n}, {InSettling.Reason :n}, after {InSettling.Seconds} s)");
        return true;
    }

    // The oldest queued piece that can drop now; false when none could.
    private bool Drop_Next(FMars_Platter_SettlePass& InPass, FMars_Fragment_Platter& InState, const FMars_Platter_Spec& InSpec)
    {
        for (int32 Index = 0; Index < InState.Queue.Num(); ++Index)
        {
            auto Piece = InState.Queue[Index];
            if (Get_IsGone(Piece))
            { continue; }

            const auto Status = Piece.Get_Status();
            if (Status == EMars_FoodPiece_Status::Failed)
            {
                InState.Queue.RemoveAt(Index);
                Piece.Request_TryRemove(FMars_Fragment_Platter_Membership);
                InPass.Refused.Add(FMars_Platter_LoadRefused(Piece, EMars_Platter_LoadRefusal::Failed));
                ck::Trace(f"[Platter] [{InPass.Platter.ToString()}] refused [{Piece.ToString()}]: its import failed while queued");
                return false;
            }

            if (Status != EMars_FoodPiece_Status::Ready)
            { continue; }

            FCk_Handle PieceEntity = Piece;
            auto Body = PieceEntity.As_JoltBody(ECk_SanityCheck::UnChecked);
            if (ck::IsValid(Body) && utils_jolt_body::Get_IsBodyAdded(Body) == false)
            { continue; }

            InState.Queue.RemoveAt(Index);
            auto Settling = FMars_Platter_Settling(Piece, EMars_Platter_SettleReason::Load, FVector::ZeroVector);
            Drop_Piece(InPass, Settling, InSpec);
            InState.Settling.Add(Settling);
            return true;
        }

        return false;
    }

    // Detached, posed over a random point between the walls and Dynamic. An existing body is turned Dynamic and teleported
    // (the only transform write a Dynamic body gets); a bodiless piece is posed first, then given its body, which reads the
    // posed transform when it is set up.
    private void Drop_Piece(const FMars_Platter_SettlePass& InPass, FMars_Platter_Settling& InSettling, const FMars_Platter_Spec& InSpec)
    {
        auto Piece = InSettling.Piece;
        FCk_Handle PieceEntity = Piece;

        auto Node = PieceEntity.As_SceneNode(ECk_SanityCheck::UnChecked);
        if (ck::IsValid(Node))
        { utils_scene_node::Request_Detach(Node); }

        const auto Pose = utils_platter::Make_DropPose(InSpec.Bounds, utils_runtime_mesh::Get_Metrics(Piece.Get_Geometry()));
        const auto World = FTransform(Pose.Rotation, Pose.Location) * InPass.RootWorld;

        auto Body = PieceEntity.As_JoltBody(ECk_SanityCheck::UnChecked);
        if (ck::IsValid(Body))
        {
            utils_jolt_body::Request_SetMotionType(Body, FCk_Request_JoltBody_SetMotionType(ECk_MotionType::Dynamic));
            utils_jolt_body::Request_Teleport(Body, FCk_Request_JoltBody_Teleport(World.GetLocation(), World.Rotator()));
            utils_jolt_body::Request_SetLinearVelocity(Body, FCk_Request_JoltBody_SetLinearVelocity(FVector::ZeroVector));
        }
        else
        {
            auto PieceTransform = PieceEntity.As_Transform();
            utils_transform::Request_SetLocation(PieceTransform, FCk_Request_Transform_SetLocation(World.GetLocation()));
            utils_transform::Request_SetRotation(PieceTransform, FCk_Request_Transform_SetRotation(World.Rotator()));
            utils_foodpiece::Add_Body(Piece, FMars_FoodPiece_BodyTuners());
        }

        if (InSettling.Freeze.IsSet())
        { ++InSettling.Redrops; }

        InSettling.Freeze.Reset();
        InSettling.LastSample = Pose.Location;
        InSettling.StillSeconds = 0.0f;
        InSettling.SinceSample = 0.0f;
        InSettling.Seconds = 0.0f;

        ck::Trace(f"[Platter] [{InPass.Platter.ToString()}] dropped [{Piece.ToString()}] at {Pose.Location} (root frame), yaw {Pose.Rotation.Yaw}");
    }

    private bool Get_IsGone(const FCk_Handle_FoodPiece& InPiece) const
    {
        return ck::Is_NOT_Valid(InPiece) || utils_entity_lifetime::Get_IsPendingDestroy(InPiece, ECk_EntityLifetime_DestructionPhase::BeginDestroy);
    }

    private void Broadcast(FMars_Platter_SettlePass& InPass)
    {
        auto Platter = InPass.Platter;
        for (const auto& Piece : InPass.Loaded)
        {
            if (Platter.Has_Fragment(FMars_Fragment_Platter_Signals))
            { Platter.Get_Fragment(FMars_Fragment_Platter_Signals).OnLoaded.Broadcast(Platter, Piece); }
        }

        for (const auto& Refused : InPass.Refused)
        {
            if (Platter.Has_Fragment(FMars_Fragment_Platter_Signals))
            { Platter.Get_Fragment(FMars_Fragment_Platter_Signals).OnLoadRefused.Broadcast(Platter, Refused.Piece, Refused.Refusal); }
        }

        for (const auto& Piece : InPass.Unloaded)
        {
            if (Platter.Has_Fragment(FMars_Fragment_Platter_Signals))
            { Platter.Get_Fragment(FMars_Fragment_Platter_Signals).OnUnloaded.Broadcast(Platter, Piece); }
        }
    }
}

// The platter is a lease over its pieces, reconciled every pass: a piece something else took (detached from the root,
// carried off by a hand, a settling piece attached anywhere) or destroyed leaves the ledger. A landed piece that left
// broadcasts OnUnloaded and the rest of the pile re-settles; a queued piece that is destroyed, or one dropping for its first
// landing that is destroyed or taken, is dropped silently (it never landed).
class UMars_Processor_Platter_Reconcile : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_Platter);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle, FMars_Fragment_Platter& InState)
    {
        if (InState.Held.Num() == 0 && InState.Settling.Num() == 0 && InState.Queue.Num() == 0)
        { return; }

        auto Platter = InHandle.As_Platter();
        auto Root = InHandle.As_Transform();
        TArray<FCk_Handle_FoodPiece> Left;

        TArray<FCk_Handle_FoodPiece> StillHeld;
        for (const auto& Held : InState.Held)
        {
            auto Piece = Held;
            if (Get_IsGone(Piece) == false && Get_IsOnRoot(Piece, Root))
            {
                StillHeld.Add(Piece);
                continue;
            }

            Forget(Piece);
            Left.Add(Piece);
        }

        InState.Held = StillHeld;

        TArray<FMars_Platter_Settling> StillSettling;
        for (const auto& Settling : InState.Settling)
        {
            auto Piece = Settling.Piece;
            if (Get_IsGone(Piece) == false && utils_platter::Get_IsTaken(Piece) == false)
            {
                StillSettling.Add(Settling);
                continue;
            }

            Forget(Piece);
            if (Settling.Reason == EMars_Platter_SettleReason::Resettle)
            { Left.Add(Piece); }
        }

        InState.Settling = StillSettling;

        TArray<FCk_Handle_FoodPiece> StillQueued;
        for (const auto& Queued : InState.Queue)
        {
            auto Piece = Queued;
            if (Get_IsGone(Piece) == false)
            {
                StillQueued.Add(Piece);
                continue;
            }

            Forget(Piece);
            ck::Trace(f"[Platter] [{Platter.ToString()}] dropped the queued load of [{Piece.ToString()}]: it was destroyed");
        }

        InState.Queue = StillQueued;

        if (Left.Num() == 0)
        { return; }

        utils_platter::Resettle(InState, utils_transform::Get_EntityCurrentTransform(Root));

        // InState is not read past this line: a listener may add a request fragment to the platter.
        for (const auto& Piece : Left)
        {
            ck::Trace(f"[Platter] [{Platter.ToString()}] [{Piece.ToString()}] left the pile without an unload: the rest re-settles");
            if (Platter.Has_Fragment(FMars_Fragment_Platter_Signals))
            { Platter.Get_Fragment(FMars_Fragment_Platter_Signals).OnUnloaded.Broadcast(Platter, Piece); }
        }
    }

    // A held piece is a scene-node child of the root; anything else took it.
    private bool Get_IsOnRoot(const FCk_Handle_FoodPiece& InPiece, const FCk_Handle_Transform& InRoot) const
    {
        FCk_Handle PieceEntity = InPiece;
        auto Node = PieceEntity.As_SceneNode(ECk_SanityCheck::UnChecked);
        return ck::IsValid(Node) && utils_scene_node::Get_Parent(Node) == InRoot;
    }

    private void Forget(FCk_Handle_FoodPiece& InPiece)
    {
        if (ck::IsValid(InPiece))
        { InPiece.Request_TryRemove(FMars_Fragment_Platter_Membership); }
    }

    private bool Get_IsGone(const FCk_Handle_FoodPiece& InPiece) const
    {
        return ck::Is_NOT_Valid(InPiece) || utils_entity_lifetime::Get_IsPendingDestroy(InPiece, ECk_EntityLifetime_DestructionPhase::BeginDestroy);
    }
}
