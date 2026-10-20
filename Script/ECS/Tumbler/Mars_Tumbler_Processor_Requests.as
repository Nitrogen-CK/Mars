// One release's answer, broadcast after the whole drain applied.
struct FMars_Tumbler_AdmissionResult
{
    FMars_CookingFeed_PieceId Id;
    EMars_CookingFeed_Admission Admission = EMars_CookingFeed_Admission::Rejected;
    FString Reason;
    // Accepted only: the adopted piece's entity.
    FCk_Handle Entity;
}

// One piece a take-out handed back, broadcast after the whole drain applied.
struct FMars_Tumbler_TakeOutResult
{
    FMars_CookingFeed_PieceId Id;
    FCk_Handle_FoodPiece Piece;
}

// What one drain broadcasts once it applied: the hand, hatch and drum it started from (the edges), its refusals, its
// take-outs and its admission answers.
struct FMars_Tumbler_DrainEdges
{
    EMars_Tumbler_HandMode StartMode = EMars_Tumbler_HandMode::Free;
    EMars_Tumbler_Hatch StartHatch = EMars_Tumbler_Hatch::Closed;
    EMars_Tumbler_Drum StartDrum = EMars_Tumbler_Drum::Home;
    TArray<EMars_Tumbler_Refusal> Refusals;
    TArray<FMars_Tumbler_TakeOutResult> TakenOut;
    TArray<EMars_CookingFeed_TakeOutRefusal> TakeOutRefusals;
    TArray<FMars_Tumbler_AdmissionResult> Admissions;
}

// Drains Reset -> Cancel -> the station's take-outs -> Readopt -> the station inbox's releases -> Release -> Press -> Look
// (see FMars_Fragment_Tumbler_Requests). Reset destroys every piece in the drum (its body with it), frees the hand, closes
// the hatch and lets go of the lever; Cancel ends a grip (the drum returns) or a reach; a take-out hands back every tumbled
// piece (coverage at Coating.TakeOutCoverage) up to its cap, its crumb written into its cook state and its body Kinematic,
// onto the take-out's tray, and one that hands none back is refused (NoRoom under a cap of zero or with no tray, else
// NothingReady); Readopt puts a handed-back piece its tray refused back in the drum where it lies; each release in the
// station's inbox is adopted (the released piece itself, on its own body made Dynamic at the release) or rejected; Release
// lets go; each Press toggles the hovered hatch, starts a reach to the hovered lever, or is refused (consumed, nothing
// queued); the summed look moves the free cursor or rocks the gripped lever. The hand, hatch and drum edges, the refusals,
// every take-out and refused take-out, then every admission answer on the station's OnAdmission (and OnPieceAdded for an
// accepted one) are broadcast last. The drain decides and the Tick moves: nothing here integrates over time.
//
// A piece is the drum's guest: the kernel creates no entity, and a piece it holds ends only with a Reset or with the station
// (OnTumblerBeginDestroy). The drum is the one owner of its pieces' lease facts: it stamps every piece it takes on with the
// holder fact and its pickup's Ledger claim, removes the holder when it hands the piece back, and releases the claim when
// the piece lands on its tray (or at once when the take-out named none); a tray's refusal readopts the piece. It also
// listens: the station's queue (OnQueued wakes this drain) and the answers of every tray it loads.
class UMars_Processor_Tumbler_HandleRequests : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _MarkedDirtyBy = FMars_Fragment_Tumbler_Requests;

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_Tumbler);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle,
                       FMars_Fragment_Tumbler_Requests& InRequests,
                       FMars_Fragment_Tumbler& InState)
    {
        auto Self = InHandle.As_Tumbler();

        const auto HasReset = InRequests.ResetRequests.Num() > 0;
        const auto HasCancel = InRequests.CancelRequests.Num() > 0;
        TArray<FMars_Request_Tumbler_Readopt> ReadoptRequests = InRequests.ReadoptRequests;
        const auto ReleaseCount = InRequests.ReleaseRequests.Num();
        const auto PressCount = InRequests.PressRequests.Num();
        auto LookDelta = FVector::ZeroVector;
        for (const auto& Request : InRequests.LookRequests)
        { LookDelta += Request.LookDelta; }

        const auto HasLook = InRequests.LookRequests.Num() > 0;

        // InRequests is invalid past this line; removing before broadcasting lets re-entrant requests survive.
        Self.Request_TryRemove(FMars_Fragment_Tumbler_Requests);

        Watch_Station(Self);
        TArray<FMars_CookingFeed_Release> Inbox = utils_cooking_feed::Take_Inbox(InHandle);
        TArray<FMars_Request_StationTakeOut> TakeOuts = utils_cooking_feed::Take_TakeOutRequests(InHandle);

        auto Edges = FMars_Tumbler_DrainEdges();
        Edges.StartMode = InState.Hand.Mode;
        Edges.StartHatch = InState.Hatch;
        Edges.StartDrum = InState.Drum;

        if (HasReset)
        { Apply_Reset(Self, InState); }

        if (HasCancel)
        { Apply_LetGo(Self, InState); }

        for (const auto& TakeOut : TakeOuts)
        { Apply_TakeOut(Self, InState, TakeOut, Edges); }

        for (const auto& Request : ReadoptRequests)
        { Apply_Readopt(Self, InState, Request); }

        for (const auto& Release : Inbox)
        { Edges.Admissions.Add(Apply_AddPiece(Self, InState, Release)); }

        for (int32 Index = 0; Index < ReleaseCount; ++Index)
        { Apply_LetGo(Self, InState); }

        for (int32 Index = 0; Index < PressCount; ++Index)
        { Apply_Press(Self, InState, Edges.Refusals); }

        if (HasLook)
        { Apply_Look(Self, InState, LookDelta); }

        Broadcast(Self, InState, Edges);
    }

    private void Broadcast(FCk_Handle_Tumbler& InTumbler, const FMars_Fragment_Tumbler& InState, const FMars_Tumbler_DrainEdges& InEdges)
    {
        const auto Mode = InState.Hand.Mode;
        const auto Hatch = InState.Hatch;
        const auto Drum = InState.Drum;

        if (Mode != InEdges.StartMode && InTumbler.Has_Fragment(FMars_Fragment_Tumbler_Signals))
        { InTumbler.Get_Fragment(FMars_Fragment_Tumbler_Signals).OnHandModeChanged.Broadcast(InTumbler, Mode); }

        if (Hatch != InEdges.StartHatch && InTumbler.Has_Fragment(FMars_Fragment_Tumbler_Signals))
        { InTumbler.Get_Fragment(FMars_Fragment_Tumbler_Signals).OnHatchChanged.Broadcast(InTumbler, Hatch); }

        if (Drum != InEdges.StartDrum && InTumbler.Has_Fragment(FMars_Fragment_Tumbler_Signals))
        { InTumbler.Get_Fragment(FMars_Fragment_Tumbler_Signals).OnDrumChanged.Broadcast(InTumbler, Drum); }

        for (const auto Refusal : InEdges.Refusals)
        {
            if (InTumbler.Has_Fragment(FMars_Fragment_Tumbler_Signals))
            { InTumbler.Get_Fragment(FMars_Fragment_Tumbler_Signals).OnPressRefused.Broadcast(InTumbler, Refusal); }
        }

        for (const auto& Result : InEdges.TakenOut)
        {
            if (InTumbler.Has_Fragment(FMars_Fragment_Tumbler_Signals))
            { InTumbler.Get_Fragment(FMars_Fragment_Tumbler_Signals).OnPieceTakenOut.Broadcast(InTumbler, Result.Id, Result.Piece); }
        }

        for (const auto Refusal : InEdges.TakeOutRefusals)
        {
            if (InTumbler.Has_Fragment(FMars_Fragment_Tumbler_Signals))
            { InTumbler.Get_Fragment(FMars_Fragment_Tumbler_Signals).OnTakeOutRefused.Broadcast(InTumbler, Refusal); }
        }

        FCk_Handle Station = InTumbler;
        for (const auto& Result : InEdges.Admissions)
        {
            utils_cooking_feed::Broadcast_Admission(Station, FMars_CookingFeed_AdmissionAnswer(Result.Id, Result.Admission, Result.Reason));
            if (Result.Admission == EMars_CookingFeed_Admission::Accepted && InTumbler.Has_Fragment(FMars_Fragment_Tumbler_Signals))
            { InTumbler.Get_Fragment(FMars_Fragment_Tumbler_Signals).OnPieceAdded.Broadcast(InTumbler, Result.Id, Result.Entity); }
        }
    }

    // Every piece in the drum is destroyed here (its body dies with it), never left to the station's teardown alone.
    private void Apply_Reset(FCk_Handle_Tumbler& InTumbler, FMars_Fragment_Tumbler& InState)
    {
        for (const auto& Piece : InState.Pieces)
        {
            if (Piece.Piece.Get_IsGone() == false)
            { utils_entity_lifetime::Request_DestroyEntity(Piece.Entity); }
        }

        InState.Pieces.Empty();
        InState.Reseats = 0;

        const auto Spec = InTumbler.Get_Spec();
        auto Lever = Spec.Nodes.Lever;
        if (InState.Hand.Mode == EMars_Tumbler_HandMode::Gripped)
        {
            Lever.Request_EndManipulation(FMars_Request_Control_EndManipulation());
            InState.Drum = EMars_Tumbler_Drum::Returning;
        }

        InState.Hand.Mode = EMars_Tumbler_HandMode::Free;
        InState.Hand.ReachElapsed = 0.0f;

        if (InState.Hatch != EMars_Tumbler_Hatch::Closed)
        {
            auto Hatch = Spec.Nodes.Hatch;
            Hatch.Request_MoveTo(FMars_Request_Mover_MoveTo(EMars_Mover_Pose::Start));
            InState.Hatch = EMars_Tumbler_Hatch::Closing;
        }
    }

    // Cancel and Release both: a grip lets go (the Control settles the drum home); a reach stops.
    private void Apply_LetGo(FCk_Handle_Tumbler& InTumbler, FMars_Fragment_Tumbler& InState)
    {
        if (InState.Hand.Mode == EMars_Tumbler_HandMode::Free)
        { return; }

        if (InState.Hand.Mode == EMars_Tumbler_HandMode::Gripped)
        { Let_Go(InTumbler, InState); }

        InState.Hand.Mode = EMars_Tumbler_HandMode::Free;
        InState.Hand.ReachElapsed = 0.0f;
    }

    private void Let_Go(FCk_Handle_Tumbler& InTumbler, FMars_Fragment_Tumbler& InState)
    {
        auto Lever = InTumbler.Get_Spec().Nodes.Lever;
        Lever.Request_EndManipulation(FMars_Request_Control_EndManipulation());
        InState.Drum = EMars_Tumbler_Drum::Returning;
    }

    // The hovered hatch toggles; the hovered lever starts a reach; anything else is refused and consumed.
    private void Apply_Press(FCk_Handle_Tumbler& InTumbler, FMars_Fragment_Tumbler& InState, TArray<EMars_Tumbler_Refusal>& OutRefusals)
    {
        const auto FeedPhase = utils_tumbler::Get_FeedPhase(InTumbler);
        if (InState.Hovered == EMars_Tumbler_Target::Hatch)
        {
            if (utils_tumbler::Get_CanToggleHatch(InState, FeedPhase) == false)
            {
                OutRefusals.Add(utils_tumbler::Get_HatchRefusal(InState));
                return;
            }

            const auto Opening = InState.Hatch == EMars_Tumbler_Hatch::Closed;
            auto Hatch = InTumbler.Get_Spec().Nodes.Hatch;
            Hatch.Request_MoveTo(FMars_Request_Mover_MoveTo(Opening ? EMars_Mover_Pose::End : EMars_Mover_Pose::Start));
            InState.Hatch = Opening ? EMars_Tumbler_Hatch::Opening : EMars_Tumbler_Hatch::Closing;
            return;
        }

        if (InState.Hovered == EMars_Tumbler_Target::Lever)
        {
            if (utils_tumbler::Get_CanGrip(InState, FeedPhase) == false)
            {
                OutRefusals.Add(utils_tumbler::Get_GripRefusal(InState));
                return;
            }

            InState.Hand.Mode = EMars_Tumbler_HandMode::Reaching;
            InState.Hand.ReachElapsed = 0.0f;
            InState.Hand.ReachFrom = InState.Hand.HandLocal;
            InState.Hand.ReachFromRotation = InState.Hand.HandRotationLocal;
            return;
        }

        OutRefusals.Add(InState.Hand.Mode == EMars_Tumbler_HandMode::Free ? EMars_Tumbler_Refusal::NoTarget : EMars_Tumbler_Refusal::HandBusy);
    }

    // Free: the cursor moves on the reach plane (look right +Y, look down -Z), clamped. Gripped: the look's projection on the
    // lever's screen pull direction rocks it. Reaching: dropped.
    private void Apply_Look(FCk_Handle_Tumbler& InTumbler, FMars_Fragment_Tumbler& InState, FVector InLookDelta)
    {
        const auto Spec = InTumbler.Get_Spec();
        if (InState.Hand.Mode == EMars_Tumbler_HandMode::Free)
        {
            const auto Step = float64(Spec.Hand.CmPerLookDegree);
            const auto Moved = InState.Hand.Cursor + FVector2D(InLookDelta.X * Step, -InLookDelta.Y * Step);
            InState.Hand.Cursor = FVector2D(
                Math::Clamp(Moved.X, -float64(Spec.Hand.HalfExtentY), float64(Spec.Hand.HalfExtentY)),
                Math::Clamp(Moved.Y, -float64(Spec.Hand.HalfExtentZ), float64(Spec.Hand.HalfExtentZ)));
            return;
        }

        if (InState.Hand.Mode != EMars_Tumbler_HandMode::Gripped)
        { return; }

        auto Lever = Spec.Nodes.Lever;
        const auto ViewWorld = utils_transform::Get_EntityCurrentTransform(Spec.Nodes.View);
        const auto PullDegrees = utils_control::Get_PullDegrees(Lever.Get_PullDirectionWorld(), ViewWorld, InLookDelta);
        Lever.Request_Nudge(FMars_Request_Control_Nudge(PullDegrees));
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Admission, take-out, readopt
    //----------------------------------------------------------------------------------------------------------------------

    // Adopted: the released piece (Release.Piece, Ready, held by no other ledger and on no scene node) on its own body made
    // Dynamic at the release pose and velocities (a bodiless piece gets one of its own mesh with Spec.Piece's feel), its
    // coverage seeded from the crumb its cook state carries; the drum stamps it with the holder fact and its pickup's
    // Ledger claim. Rejected: the piece is left as it was, the reason naming the gate.
    private FMars_Tumbler_AdmissionResult Apply_AddPiece(FCk_Handle_Tumbler& InTumbler, FMars_Fragment_Tumbler& InState,
        const FMars_CookingFeed_Release& InRelease)
    {
        auto Result = FMars_Tumbler_AdmissionResult();
        Result.Id = InRelease.PieceId;

        const auto Spec = InTumbler.Get_Spec();
        const auto PieceName = utils_cooking_feed::Get_PieceName(InRelease.PieceId);
        auto Piece = InRelease.Piece;
        FCk_Handle Entity = Piece;

        // The shell's bodies are added to the simulation a frame or more after they are built; a piece added before them
        // falls through the drum.
        if (utils_jolt_body::Get_IsBodyAdded(Spec.Nodes.DrumBody) == false)
        { Result.Reason = "the drum body is not in the simulation yet"; }
        else if (InState.Hatch != EMars_Tumbler_Hatch::Open)
        { Result.Reason = f"hatch is {InState.Hatch :n}"; }
        else if (InState.Drum != EMars_Tumbler_Drum::Home)
        { Result.Reason = f"drum is {InState.Drum :n}"; }
        else if (Piece.Get_IsGone())
        { Result.Reason = "no piece"; }
        else if (Piece.Get_Status() != EMars_FoodPiece_Status::Ready)
        { Result.Reason = "the piece is not ready"; }
        else if (utils_tumbler::Find_PieceIndexByHandle(InState.Pieces, Piece).IsSet())
        { Result.Reason = "already admitted"; }
        else if (utils_tumbler::Find_PieceIndex(InState.Pieces, InRelease.PieceId).IsSet())
        { Result.Reason = f"piece {PieceName} is already in"; }
        else if (ck::IsValid(Piece.TryGet_Holder()))
        { Result.Reason = "another ledger holds it"; }
        else if (Entity.Is_SceneNode())
        { Result.Reason = "still attached"; }
        else if (InState.Pieces.Num() >= Spec.Drum.Capacity)
        { Result.Reason = f"Capacity [{Spec.Drum.Capacity}] pieces are already in"; }

        if (Result.Reason.Len() > 0)
        { return Result; }

        auto State = FMars_Tumbler_PieceState();
        State.Id = InRelease.PieceId;
        State.Piece = Piece;
        State.Entity = Entity;
        State.Body = Adopt_Body(Piece, InRelease, Spec.Piece);
        // The admission frame coats nothing: the first step is measured from where the piece was released.
        State.LastWorld = InRelease.WorldTransform.GetLocation();
        State.Coverage = utils_tumbler::Get_SeedCoverage(Piece);
        InState.Pieces.Add(State);

        utils_foodpiece::Stamp_Holder(Piece, InTumbler);
        utils_world_item::Request_ClaimPickup(Piece, EMars_Interactable_DisableReason::Ledger, ECk_EnableDisable::Disable);
        Watch_Teardown(InTumbler);

        Result.Admission = EMars_CookingFeed_Admission::Accepted;
        Result.Entity = Entity;
        return Result;
    }

    // A piece with a body (every piece a platter brings) keeps it: switched to Dynamic and teleported to the release. A
    // bodiless one is posed at the release first (a body reads its entity's pose when it is added) and given a dynamic
    // convex body of its own mesh with InSpec's mass and feel. Either way the release's velocities follow (the body handles
    // its requests once it is set up and added, so these wait for it).
    private FCk_Handle_JoltBody Adopt_Body(FCk_Handle_FoodPiece InPiece, const FMars_CookingFeed_Release& InRelease,
        const FMars_Tumbler_PieceSpec& InSpec)
    {
        FCk_Handle Entity = InPiece;
        const auto Location = InRelease.WorldTransform.GetLocation();
        const auto Rotation = InRelease.WorldTransform.Rotator();

        auto Body = FCk_Handle_JoltBody();
        if (Entity.Is_JoltBody())
        {
            Body = Entity.As_JoltBody();
            utils_jolt_body::Request_SetMotionType(Body, FCk_Request_JoltBody_SetMotionType(ECk_MotionType::Dynamic));
            utils_jolt_body::Request_Teleport(Body, FCk_Request_JoltBody_Teleport(Location, Rotation));
        }
        else
        {
            auto Transform = Entity.As_Transform();
            utils_transform::Request_SetLocation(Transform, FCk_Request_Transform_SetLocation(Location));
            utils_transform::Request_SetRotation(Transform, FCk_Request_Transform_SetRotation(Rotation));

            auto Convex = FCk_JoltBody_RuntimeConvexSpec();
            Convex.Set_PointsCm(utils_runtime_mesh::Copy_LocalVerticesCm(InPiece.Get_Geometry()));

            auto BodySpec = FCk_JoltBody_Spec(ECk_JoltBody_ShapeSource::RuntimeConvex);
            BodySpec.Set_RuntimeConvex(Convex);
            BodySpec.Set_MotionType(ECk_MotionType::Dynamic);
            BodySpec.Set_MotionQuality(ECk_MotionQuality::LinearCast);
            BodySpec.Set_MassSource(ECk_JoltBody_MassSource::Explicit);
            BodySpec.Set_MassKg(InSpec.MassKg);
            BodySpec.Set_SurfaceSource(ECk_JoltBody_SurfaceSource::Explicit);
            BodySpec.Set_Friction(InSpec.Friction);
            BodySpec.Set_Restitution(InSpec.Restitution);
            BodySpec.Set_LinearDamping(InSpec.LinearDamping);
            BodySpec.Set_AngularDamping(InSpec.AngularDamping);
            BodySpec.Set_PersistContacts(ECk_EnableDisable::Enable);
            Body = utils_jolt_body::Add(Entity, BodySpec);
        }

        if (InRelease.LinearVelocity.IsNearlyZero() == false)
        { utils_jolt_body::Request_SetLinearVelocity(Body, FCk_Request_JoltBody_SetLinearVelocity(InRelease.LinearVelocity)); }

        if (InRelease.AngularVelocity.IsNearlyZero() == false)
        { utils_jolt_body::Request_SetAngularVelocity(Body, FCk_Request_JoltBody_SetAngularVelocity(InRelease.AngularVelocity)); }

        return Body;
    }

    // Every tumbled piece, in admission order, up to the cap the press read (no tray caps it at none): each leaves the drum
    // with its coverage written as its cook state's crumb, its body Kinematic (a platter takes it next) and its holder fact
    // gone, and goes onto the tray (its Ledger claim stays the drum's until it lands). One that hands none back is refused.
    private void Apply_TakeOut(FCk_Handle_Tumbler& InTumbler, FMars_Fragment_Tumbler& InState,
        const FMars_Request_StationTakeOut& InTakeOut, FMars_Tumbler_DrainEdges& OutEdges)
    {
        const auto MaxPieces = ck::IsValid(InTakeOut.Tray) ? InTakeOut.MaxPieces : 0;
        const auto TakeOutCoverage = InTumbler.Get_Spec().Coating.TakeOutCoverage;

        TArray<FMars_Tumbler_TakeOutResult> Taken;
        TArray<FMars_Tumbler_PieceState> Kept;
        for (const auto& Piece : InState.Pieces)
        {
            const auto IsTumbled = Piece.Piece.Get_IsGone() == false && Piece.Coverage >= TakeOutCoverage;
            if (Taken.Num() >= MaxPieces || IsTumbled == false)
            {
                Kept.Add(Piece);
                continue;
            }

            Hand_Back(InTumbler, Piece);

            auto Result = FMars_Tumbler_TakeOutResult();
            Result.Id = Piece.Id;
            Result.Piece = Piece.Piece;
            Taken.Add(Result);
        }

        InState.Pieces = Kept;

        if (Taken.Num() == 0)
        {
            OutEdges.TakeOutRefusals.Add(MaxPieces <= 0 ? EMars_CookingFeed_TakeOutRefusal::NoRoom : EMars_CookingFeed_TakeOutRefusal::NothingReady);
            return;
        }

        for (const auto& Result : Taken)
        {
            auto Piece = Result.Piece;
            utils_cooking_feed::Send_ToTray(Piece, FMars_Fragment_StationLanding(InTumbler, Result.Id, InTakeOut.Tray));
        }

        Watch_Tray(InTakeOut.Tray);
        OutEdges.TakenOut.Append(Taken);
    }

    private void Hand_Back(const FCk_Handle_Tumbler& InTumbler, const FMars_Tumbler_PieceState& InPiece)
    {
        auto Piece = InPiece.Piece;
        auto CookState = Piece.Get_CookState();
        CookState.Crumb = InPiece.Coverage;
        Piece.Request_SetCookState(FMars_Request_FoodPiece_SetCookState(CookState));

        auto Body = InPiece.Body;
        utils_jolt_body::Request_SetMotionType(Body, FCk_Request_JoltBody_SetMotionType(ECk_MotionType::Kinematic));
        utils_foodpiece::Clear_Holder(Piece, InTumbler);
    }

    // A handed-back piece its tray refused, back in the drum where it lies (it is not moved): its record rebuilt from the
    // piece (the take-out wrote its coverage as its crumb), its body Dynamic again, its holder fact and its pickup's Ledger
    // claim the drum's. Not readopted: a piece gone, attached, or that another ledger holds by now.
    private void Apply_Readopt(FCk_Handle_Tumbler& InTumbler, FMars_Fragment_Tumbler& InState, const FMars_Request_Tumbler_Readopt& InRequest)
    {
        auto Piece = InRequest.Piece;
        if (Piece.Get_IsGone())
        { return; }

        FCk_Handle Entity = Piece;
        const auto Holder = Piece.TryGet_Holder();
        if ((ck::IsValid(Holder) && Holder != InTumbler) || Entity.Is_SceneNode())
        { return; }

        const auto PieceName = utils_cooking_feed::Get_PieceName(InRequest.PieceId);
        const auto IsInDrum = utils_tumbler::Find_PieceIndexByHandle(InState.Pieces, Piece).IsSet()
            || utils_tumbler::Find_PieceIndex(InState.Pieces, InRequest.PieceId).IsSet();
        if (ck::EnsureIfNot(IsInDrum == false, f"[Tumbler] [{InTumbler.ToString()}] was asked to readopt piece {PieceName} [{Piece.ToString()}], which it already holds"))
        { return; }

        if (ck::EnsureIfNot(Entity.Is_JoltBody(), f"[Tumbler] [{InTumbler.ToString()}] was asked to readopt piece {PieceName} [{Piece.ToString()}], which has no body: it handed back only bodied pieces"))
        { return; }

        auto Body = Entity.As_JoltBody();
        utils_jolt_body::Request_SetMotionType(Body, FCk_Request_JoltBody_SetMotionType(ECk_MotionType::Dynamic));

        auto State = FMars_Tumbler_PieceState();
        State.Id = InRequest.PieceId;
        State.Piece = Piece;
        State.Entity = Entity;
        State.Body = Body;
        State.LastWorld = utils_transform::Get_EntityCurrentLocation(Entity.As_Transform());
        State.Coverage = utils_tumbler::Get_SeedCoverage(Piece);
        InState.Pieces.Add(State);

        utils_foodpiece::Stamp_Holder(Piece, InTumbler);
        utils_world_item::Request_ClaimPickup(Piece, EMars_Interactable_DisableReason::Ledger, ECk_EnableDisable::Disable);
        Watch_Teardown(InTumbler);
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Watches
    //----------------------------------------------------------------------------------------------------------------------

    // Unbinding first keeps the watch single across admissions.
    private void Watch_Teardown(const FCk_Handle_Tumbler& InTumbler)
    {
        FCk_Handle Tumbler = InTumbler;
        Tumbler.UnbindFrom_OnBeginDestroy(FCk_Delegate_OnBeginDestroy(this, n"OnTumblerBeginDestroy"));
        Tumbler.BindTo_OnBeginDestroy(FCk_Delegate_OnBeginDestroy(this, n"OnTumblerBeginDestroy"));
    }

    // Unbinding first keeps the watch single across drains: the station's queue wakes this drain.
    private void Watch_Station(const FCk_Handle_Tumbler& InTumbler)
    {
        FCk_Handle Station = InTumbler;
        utils_cooking_feed::UnbindFrom_OnQueued(Station, FMars_Delegate_StationAdmission_OnQueued(this, n"OnStationQueued"));
        utils_cooking_feed::BindTo_OnQueued(Station, FMars_Delegate_StationAdmission_OnQueued(this, n"OnStationQueued"));
    }

    // Unbinding first keeps one binding per tray across take-outs.
    private void Watch_Tray(const FCk_Handle_Platter& InTray)
    {
        auto Tray = InTray;
        Tray.UnbindFrom_OnLoaded(FMars_Delegate_Platter_OnLoaded(this, n"OnTrayLoaded"));
        Tray.UnbindFrom_OnLoadRefused(FMars_Delegate_Platter_OnLoadRefused(this, n"OnTrayLoadRefused"));
        Tray.BindTo_OnLoaded(FMars_Delegate_Platter_OnLoaded(this, n"OnTrayLoaded"));
        Tray.BindTo_OnLoadRefused(FMars_Delegate_Platter_OnLoadRefused(this, n"OnTrayLoadRefused"));
    }

    // A live drum's station: a landing whose drum is gone has nothing to go back to.
    private bool Get_IsTumbler(const FCk_Handle& InStation) const
    {
        return ck::IsValid(InStation)
            && utils_entity_lifetime::Get_IsPendingDestroy(InStation, ECk_EntityLifetime_DestructionPhase::BeginDestroy) == false
            && InStation.Is_Tumbler();
    }

    // The station queued a release or a take-out: the drum drains it this frame.
    UFUNCTION()
    private void OnStationQueued(FCk_Handle InStation)
    {
        auto Station = InStation;
        if (Station.Is_Tumbler())
        { Station.AddOrGet_Fragment(FMars_Fragment_Tumbler_Requests); }
    }

    // A piece the drum handed to a tray landed there: the tray holds it now, and its pickup's Ledger claim goes.
    UFUNCTION()
    private void OnTrayLoaded(FCk_Handle_Platter InTray, FCk_Handle_FoodPiece InPiece)
    {
        const auto Landing = utils_cooking_feed::TryGet_Landing(InPiece, InTray);
        if (Landing.IsSet() == false || Get_IsTumbler(Landing.GetValue().Station) == false)
        { return; }

        auto Piece = InPiece;
        utils_cooking_feed::Clear_Landing(Piece);
        utils_world_item::Request_ClaimPickup(Piece, EMars_Interactable_DisableReason::Ledger, ECk_EnableDisable::Enable);
    }

    // A piece the drum handed to a tray was refused: back in the drum where it lies.
    UFUNCTION()
    private void OnTrayLoadRefused(FCk_Handle_Platter InTray, FCk_Handle_FoodPiece InPiece, EMars_Platter_LoadRefusal InRefusal)
    {
        const auto Landing = utils_cooking_feed::TryGet_Landing(InPiece, InTray);
        if (Landing.IsSet() == false || Get_IsTumbler(Landing.GetValue().Station) == false)
        { return; }

        auto Piece = InPiece;
        utils_cooking_feed::Clear_Landing(Piece);
        auto Station = Landing.GetValue().Station;
        auto Tumbler = Station.As_Tumbler();
        Tumbler.Request_Readopt(FMars_Request_Tumbler_Readopt(Landing.GetValue().PieceId, Piece));
    }

    // The pieces in the drum end with the station: under the world's transient entity they would outlive it.
    UFUNCTION()
    private void OnTumblerBeginDestroy(FCk_Handle InTumbler)
    {
        auto TumblerEntity = InTumbler;
        if (TumblerEntity.Has_Fragment(FMars_Fragment_Tumbler) == false)
        { return; }

        const auto State = TumblerEntity.Get_Fragment(FMars_Fragment_Tumbler);
        for (const auto& Piece : State.Pieces)
        {
            if (Piece.Piece.Get_IsGone())
            { continue; }

            utils_entity_lifetime::Request_DestroyEntity(Piece.Entity);
        }
    }
}
