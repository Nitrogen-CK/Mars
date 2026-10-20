// What one Settle pass saw and did, broadcast at its end.
struct FMars_Platter_SettlePass
{
    FCk_Handle_Platter Platter;
    EMars_Platter_Mounting Mounting = EMars_Platter_Mounting::Free;
    FTransform RootWorld;
    bool IsStill = false;
    float32 Seconds = 0.0f;
    TArray<FCk_Handle_FoodPiece> Loaded;
    TArray<FMars_Platter_LoadRefused> Refused;
    // Landed pieces something else took while they re-settled.
    TArray<FCk_Handle_FoodPiece> Unloaded;
    // Set when one of them left: the first freeze index it may have supported (utils_platter::Resettle).
    TOptional<int32> ResettleFrom;
}

// Where one settling piece stands after a pass.
enum EMars_Platter_SettleStep
{
    // Still dropping, re-settling or waiting to attach.
    Settling,
    Attached,
    // Off the ledger, refused Failed.
    Refused
}

// The pile, every pass: first the settling pieces, then the next drop.
//
// Settle: a Dynamic piece is watched until it rests on the platter (the drift watchdog, in the root's frame so a pile riding
// a carried tray between its walls still settles, or Jolt's sleep), or is frozen where it is at Settle.MaxSeconds. A piece
// whose body is not in the simulation by Settle.MaxSeconds, or whose body the drop gave it fails setup, cannot be loaded:
// it leaves the ledger refused Failed, with an ensure naming its body's setup. Freezing asks for Kinematic, and asks again
// every pass until the body's mirror reads it (utils_jolt_body::Get_MotionType is what the SetMotionType handler stamps:
// attaching a Dynamic body would fight the Jolt writeback), at most constants_platter::k_MotionTypeAskBudget times before
// the piece is refused the same way; then the piece is attached to the root keeping its world pose, joins Held, and
// OnLoaded fires for a first landing; a piece landing on a mounted platter takes the pile's pawn-ignoring profile there. A
// piece that froze outside the walls (or under the floor) is re-dropped once the root is still; while the root moves it
// waits, its Seconds still ageing, and at Settle.MaxSeconds it is accepted where it lies. A second escape is accepted where
// it lies. A settling piece something else attached (a hand's Carry) is forgotten before it is watched: a re-settling one
// is unloaded and what froze since it let go re-settles.
//
// Drop: while the root is still, one queued piece per Settle.DropCadenceSeconds, oldest first among those that can drop
// (Ready, not taken, a body, if it has one, added): it gets its convex body if it has none (its setup watched), is detached,
// turned Dynamic and, unless it already lies over the tray, teleported over a random point between the walls
// (utils_platter::Make_DropPose). A queued piece whose
// import or body setup failed is refused Failed. A gone or taken piece is Reconcile's.
class UMars_Processor_Platter_Settle : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _RunAfter.Add(n"/Script/Angelscript.Mars_Processor_Platter_HandleRequests");
    default _RunAfter.Add(n"/Script/Angelscript.Mars_Processor_Platter_Reconcile");

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
        Pass.Mounting = InState.Mounting;
        Pass.RootWorld = RootWorld;
        Pass.IsStill = IsStill;
        Pass.Seconds = Seconds;

        Settle_Pieces(Pass, InState, Spec);
        if (Pass.ResettleFrom.IsSet())
        { utils_platter::Resettle(InState, RootWorld, Pass.ResettleFrom.GetValue()); }

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
            if (Settling.Piece.Get_IsGone())
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

            const auto Step = Settling.Freeze.IsSet() ? Try_Attach(InPass, Settling, InSpec) : Watch(InPass, Settling, InSpec);
            if (Step == EMars_Platter_SettleStep::Settling)
            { StillSettling.Add(Settling); }
            else if (Step == EMars_Platter_SettleStep::Attached)
            {
                InState.Held.Add(FMars_Platter_Held(Settling.Piece, InState.NextFreezeIndex));
                ++InState.NextFreezeIndex;
            }
        }

        InState.Settling = StillSettling;
    }

    // A piece re-settling had landed: its leaving is an unload. A first landing never landed: it leaves silently.
    private void Forget_Taken(FMars_Platter_SettlePass& InPass, const FMars_Platter_Settling& InSettling)
    {
        auto Piece = InSettling.Piece;
        utils_platter::Leave_Ledger(Piece, InPass.Platter);
        if (InSettling.Reason == EMars_Platter_SettleReason::Resettle)
        {
            InPass.Unloaded.Add(Piece);
            utils_platter::Lower_ResettleFrom(InPass.ResettleFrom, InSettling.FreezeFloor);
        }
    }

    // The watchdog, in the root's frame. A piece whose body is not in the simulation only ages, and is refused once it has
    // aged Settle.MaxSeconds.
    private EMars_Platter_SettleStep Watch(FMars_Platter_SettlePass& InPass, FMars_Platter_Settling& InSettling, const FMars_Platter_Spec& InSpec)
    {
        FCk_Handle PieceEntity = InSettling.Piece;
        auto Body = PieceEntity.As_JoltBody(ECk_SanityCheck::UnChecked);
        InSettling.Seconds += InPass.Seconds;

        const auto& Tuners = InSpec.Settle;
        if (ck::Is_NOT_Valid(Body) || utils_jolt_body::Get_IsBodyAdded(Body) == false)
        {
            if (InSettling.Seconds < Tuners.MaxSeconds)
            { return EMars_Platter_SettleStep::Settling; }

            Refuse(InPass, InSettling, "its body never reached the simulation");
            return EMars_Platter_SettleStep::Refused;
        }

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
            return EMars_Platter_SettleStep::Settling;
        }

        if (InSettling.Seconds >= Tuners.MaxSeconds)
        { Freeze(InSettling, EMars_Platter_FreezeCause::TimedOut); }

        return EMars_Platter_SettleStep::Settling;
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

    // Attached once the body's mirror reads Kinematic. The SetMotionType handler drops a request that reaches a body before it
    // is added, so Kinematic is asked again every pass, at most constants_platter::k_MotionTypeAskBudget times before the
    // piece is refused. An escape (outside the walls, or under the floor) is re-dropped once the root is still; while the
    // root moves it waits, its Seconds still ageing, until Settle.MaxSeconds, past which it is accepted where it lies. A
    // second escape is accepted where it lies.
    private EMars_Platter_SettleStep Try_Attach(FMars_Platter_SettlePass& InPass, FMars_Platter_Settling& InSettling, const FMars_Platter_Spec& InSpec)
    {
        InSettling.Seconds += InPass.Seconds;

        FCk_Handle PieceEntity = InSettling.Piece;
        auto Body = PieceEntity.As_JoltBody(ECk_SanityCheck::UnChecked);
        if (ck::IsValid(Body))
        {
            const auto IsKinematic = utils_jolt_body::Get_IsBodyAdded(Body) && utils_jolt_body::Get_MotionType(Body) == ECk_MotionType::Kinematic;
            if (IsKinematic == false)
            {
                if (InSettling.MotionTypeAsks >= constants_platter::k_MotionTypeAskBudget)
                {
                    Refuse(InPass, InSettling, f"its body never read Kinematic after {InSettling.MotionTypeAsks} asks");
                    return EMars_Platter_SettleStep::Refused;
                }

                InSettling.MotionTypeAsks += 1;
                utils_jolt_body::Request_SetMotionType(Body, FCk_Request_JoltBody_SetMotionType(ECk_MotionType::Kinematic));
                return EMars_Platter_SettleStep::Settling;
            }
        }

        // A second escape, or a first one still out when the wait runs out, falls through and is accepted where it lies.
        const auto IsFirstEscape = utils_platter::Get_IsInside(InSpec.Bounds, InPass.RootWorld, InSettling.Piece) == false
            && InSettling.Redrops < 1;
        if (IsFirstEscape && InPass.IsStill)
        {
            Drop_Piece(InPass, InSettling, InSpec);
            return EMars_Platter_SettleStep::Settling;
        }

        if (IsFirstEscape && InSettling.Seconds < InSpec.Settle.MaxSeconds)
        { return EMars_Platter_SettleStep::Settling; }

        auto Node = PieceEntity.As_SceneNode(ECk_SanityCheck::UnChecked);
        if (ck::IsValid(Node))
        { utils_scene_node::Request_Detach(Node); }

        FCk_Handle PlatterEntity = InPass.Platter;
        auto Root = PlatterEntity.As_Transform();
        auto PieceTransform = PieceEntity.As_Transform();
        const auto PieceWorld = utils_transform::Get_EntityCurrentTransform(PieceTransform);
        utils_scene_node::Add(PieceTransform, Root, PieceWorld.GetRelativeTransform(InPass.RootWorld));

        if (InPass.Mounting == EMars_Platter_Mounting::Mounted)
        { utils_platter::Apply_PileProfile(InSettling.Piece, InPass.Mounting); }

        if (InSettling.Reason == EMars_Platter_SettleReason::Load)
        { InPass.Loaded.Add(InSettling.Piece); }

        return EMars_Platter_SettleStep::Attached;
    }

    // The piece cannot be loaded: it leaves the ledger and is refused Failed. Its body (or its lack of one) is a defect: the
    // ensure names the body's setup. The caller drops it from Settling.
    private void Refuse(FMars_Platter_SettlePass& InPass, const FMars_Platter_Settling& InSettling, const FString& InWhy)
    {
        auto Piece = InSettling.Piece;
        utils_platter::Leave_Ledger(Piece, InPass.Platter);
        InPass.Refused.Add(FMars_Platter_LoadRefused(Piece, EMars_Platter_LoadRefusal::Failed));
        if (InPass.Mounting == EMars_Platter_Mounting::Mounted)
        { utils_platter::Apply_PileProfile(Piece, EMars_Platter_Mounting::Free); }

        FCk_Handle PieceEntity = Piece;
        auto Body = PieceEntity.As_JoltBody(ECk_SanityCheck::UnChecked);
        FString BodySetup = "no body";
        if (ck::IsValid(Body))
        { BodySetup = f"body {utils_jolt_body::Get_SetupState(Body) :n}: {utils_jolt_body::Get_SetupDiagnostic(Body)}"; }

        ck::EnsureIfNot(false, f"[Platter] [{InPass.Platter.ToString()}] [{Piece.ToString()}] could not be loaded after {InSettling.Seconds :.2} s: {InWhy} ({BodySetup})");
    }

    // The oldest queued piece that can drop now; false when none could.
    private bool Drop_Next(FMars_Platter_SettlePass& InPass, FMars_Fragment_Platter& InState, const FMars_Platter_Spec& InSpec)
    {
        for (int32 Index = 0; Index < InState.Queue.Num(); ++Index)
        {
            auto Piece = InState.Queue[Index];
            if (Piece.Get_IsGone() || utils_platter::Get_IsTaken(Piece))
            { continue; }

            const auto Status = Piece.Get_Status();
            if (Status == EMars_FoodPiece_Status::Failed)
            {
                InState.Queue.RemoveAt(Index);
                utils_platter::Leave_Ledger(Piece, InPass.Platter);
                InPass.Refused.Add(FMars_Platter_LoadRefused(Piece, EMars_Platter_LoadRefusal::Failed));
                return false;
            }

            if (Status != EMars_FoodPiece_Status::Ready)
            { continue; }

            FCk_Handle PieceEntity = Piece;
            auto Body = PieceEntity.As_JoltBody(ECk_SanityCheck::UnChecked);
            if (ck::IsValid(Body) && utils_jolt_body::Get_SetupState(Body) == ECk_JoltBody_SetupState::Failed)
            {
                InState.Queue.RemoveAt(Index);
                utils_platter::Leave_Ledger(Piece, InPass.Platter);
                InPass.Refused.Add(FMars_Platter_LoadRefused(Piece, EMars_Platter_LoadRefusal::Failed));
                return false;
            }

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

    // Detached, Dynamic, and posed over a random point between the walls unless it already lies over the tray. An existing body is turned Dynamic and teleported
    // (the only transform write a Dynamic body gets); a bodiless piece is posed first, then given its body, which reads the
    // posed transform when it is set up, and whose setup the platter watches.
    private void Drop_Piece(const FMars_Platter_SettlePass& InPass, FMars_Platter_Settling& InSettling, const FMars_Platter_Spec& InSpec)
    {
        auto Piece = InSettling.Piece;
        FCk_Handle PieceEntity = Piece;

        auto Node = PieceEntity.As_SceneNode(ECk_SanityCheck::UnChecked);
        if (ck::IsValid(Node))
        { utils_scene_node::Request_Detach(Node); }

        // A piece let go over the tray (a hand's deposit, a feed's return) falls from where it is: re-posing it would snap
        // it through the air. Only a piece arriving from outside the walls gets the random drop pose.
        const auto KeepsPose = utils_platter::Get_IsInside(InSpec.Bounds, InPass.RootWorld, Piece);
        auto Pose = FMars_Platter_DropPose();
        if (KeepsPose)
        { Pose.Location = Get_RootLocal(InPass, Piece); }
        else
        { Pose = utils_platter::Make_DropPose(InSpec.Bounds, utils_runtime_mesh::Get_Metrics(Piece.Get_Geometry())); }
        const auto World = FTransform(Pose.Rotation, Pose.Location) * InPass.RootWorld;

        auto Body = PieceEntity.As_JoltBody(ECk_SanityCheck::UnChecked);
        if (ck::IsValid(Body))
        {
            utils_jolt_body::Request_SetMotionType(Body, FCk_Request_JoltBody_SetMotionType(ECk_MotionType::Dynamic));
            if (KeepsPose == false)
            { utils_jolt_body::Request_Teleport(Body, FCk_Request_JoltBody_Teleport(World.GetLocation(), World.Rotator())); }
            utils_jolt_body::Request_SetLinearVelocity(Body, FCk_Request_JoltBody_SetLinearVelocity(FVector::ZeroVector));
            if (InPass.Mounting == EMars_Platter_Mounting::Mounted)
            { utils_platter::Apply_PileProfile(Piece, InPass.Mounting); }
        }
        else
        {
            if (KeepsPose == false)
            {
                auto PieceTransform = PieceEntity.As_Transform();
                utils_transform::Request_SetLocation(PieceTransform, FCk_Request_Transform_SetLocation(World.GetLocation()));
                utils_transform::Request_SetRotation(PieceTransform, FCk_Request_Transform_SetRotation(World.Rotator()));
            }

            const auto NewBody = utils_foodpiece::Add_Body(Piece);
            const auto IsObserved = utils_jolt_body::TryPromise_OnSetupResolved(NewBody, FCk_Delegate_JoltBody_OnSetupResolved(this, n"OnDroppedBodySetupResolved"));
            ck::EnsureIfNot(IsObserved, f"[Platter] [{InPass.Platter.ToString()}] dropped [{Piece.ToString()}] with a body whose setup cannot be observed");
        }

        if (InSettling.Freeze.IsSet())
        { ++InSettling.Redrops; }

        InSettling.Freeze.Reset();
        InSettling.LastSample = Pose.Location;
        InSettling.StillSeconds = 0.0f;
        InSettling.SinceSample = 0.0f;
        InSettling.Seconds = 0.0f;
        InSettling.MotionTypeAsks = 0;
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

    // The body the drop gave a piece failed setup: the piece is refused in the frame the failure is known. A body cancelled
    // with its entity or world is no defect, and a piece no longer settling on a platter (unloaded, taken, or already refused)
    // is no platter's to refuse.
    UFUNCTION()
    private void OnDroppedBodySetupResolved(FCk_Handle_JoltBody InBody, ECk_JoltBody_SetupState InState, ECk_JoltBody_SetupFailure InFailure)
    {
        if (InState != ECk_JoltBody_SetupState::Failed || InFailure == ECk_JoltBody_SetupFailure::Cancelled)
        { return; }

        FCk_Handle PieceEntity = InBody;
        const auto Piece = PieceEntity.As_FoodPiece(ECk_SanityCheck::UnChecked);
        auto Platter = Piece.TryGet_Platter();
        if (ck::Is_NOT_Valid(Platter) || utils_entity_lifetime::Get_IsPendingDestroy(Platter, ECk_EntityLifetime_DestructionPhase::BeginDestroy))
        { return; }

        auto& State = Platter.Get_Fragment(FMars_Fragment_Platter);
        for (int32 Index = 0; Index < State.Settling.Num(); ++Index)
        {
            if (State.Settling[Index].Piece != Piece)
            { continue; }

            const auto Settling = State.Settling[Index];
            State.Settling.RemoveAt(Index);

            // State is not read past this line: a listener may add a request fragment to the platter.
            auto Pass = FMars_Platter_SettlePass();
            Pass.Platter = Platter;
            Pass.Mounting = State.Mounting;
            Refuse(Pass, Settling, f"its body failed setup ({InFailure :n})");
            Broadcast(Pass);
            return;
        }
    }
}

// The platter is a lease over its pieces, reconciled every pass: a piece something else took (detached from the root,
// carried off by a hand, a queued or settling piece attached anywhere) or destroyed leaves the ledger. A landed piece that
// left broadcasts OnUnloaded and the rest of the pile re-settles; a queued piece that is destroyed or taken, or one dropping
// for its first landing that is destroyed or taken, is dropped silently (it never landed).
class UMars_Processor_Platter_Reconcile : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _RunAfter.Add(n"/Script/Angelscript.Mars_Processor_Platter_HandleRequests");

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
        auto ResettleFrom = TOptional<int32>();

        TArray<FMars_Platter_Held> StillHeld;
        for (const auto& Held : InState.Held)
        {
            auto Piece = Held.Piece;
            if (Piece.Get_IsGone() == false && Get_IsOnRoot(Piece, Root))
            {
                StillHeld.Add(Held);
                continue;
            }

            Forget(Piece, Platter);
            Left.Add(Piece);
            utils_platter::Lower_ResettleFrom(ResettleFrom, Held.FreezeIndex + 1);
        }

        InState.Held = StillHeld;

        TArray<FMars_Platter_Settling> StillSettling;
        for (const auto& Settling : InState.Settling)
        {
            auto Piece = Settling.Piece;
            if (Piece.Get_IsGone() == false && utils_platter::Get_IsTaken(Piece) == false)
            {
                StillSettling.Add(Settling);
                continue;
            }

            Forget(Piece, Platter);
            if (Settling.Reason == EMars_Platter_SettleReason::Resettle)
            {
                Left.Add(Piece);
                utils_platter::Lower_ResettleFrom(ResettleFrom, Settling.FreezeFloor);
            }
        }

        InState.Settling = StillSettling;

        TArray<FCk_Handle_FoodPiece> StillQueued;
        for (const auto& Queued : InState.Queue)
        {
            auto Piece = Queued;
            if (Piece.Get_IsGone())
            {
                Forget(Piece, Platter);
                continue;
            }

            if (utils_platter::Get_IsTaken(Piece))
            {
                Forget(Piece, Platter);
                continue;
            }

            StillQueued.Add(Piece);
        }

        InState.Queue = StillQueued;

        if (Left.Num() == 0)
        { return; }

        utils_platter::Resettle(InState, utils_transform::Get_EntityCurrentTransform(Root), ResettleFrom.GetValue());

        // InState is not read past this line: a listener may add a request fragment to the platter.
        for (const auto& Piece : Left)
        {
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

    private void Forget(FCk_Handle_FoodPiece& InPiece, const FCk_Handle_Platter& InPlatter)
    {
        utils_platter::Leave_Ledger(InPiece, InPlatter);
    }
}
