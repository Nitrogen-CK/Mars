// One AddPiece's answer, broadcast after the whole drain applied.
struct FMars_Tumbler_AdmissionResult
{
    FMars_CookingFeed_PieceId Id;
    EMars_CookingFeed_Admission Admission = EMars_CookingFeed_Admission::Rejected;
    FString Reason;
    // Accepted only: the new piece entity (its body's).
    FCk_Handle Entity;
}

// What one drain broadcasts once it applied: the hand, hatch and drum it started from (the edges), its refusals and its
// admission answers.
struct FMars_Tumbler_DrainEdges
{
    EMars_Tumbler_HandMode StartMode = EMars_Tumbler_HandMode::Free;
    EMars_Tumbler_Hatch StartHatch = EMars_Tumbler_Hatch::Closed;
    EMars_Tumbler_Drum StartDrum = EMars_Tumbler_Drum::Home;
    TArray<EMars_Tumbler_Refusal> Refusals;
    TArray<FMars_Tumbler_AdmissionResult> Admissions;
}

// Drains Reset -> Cancel -> SetLoading -> AddPiece -> Release -> Press -> Look (see FMars_Fragment_Tumbler_Requests). Reset
// destroys every piece entity (its body with it), frees the hand, closes the hatch and lets go of the lever; Cancel ends a
// grip (the drum returns) or a reach; SetLoading is last-wins; AddPiece admits (a dynamic body at the release) or rejects
// each release; Release lets go; each Press toggles
// the hovered hatch, starts a reach to the hovered lever, or is refused (consumed, nothing queued); the summed look moves
// the free cursor or rocks the gripped lever. The hand, hatch and drum edges, the refusals, then every admission answer (and
// OnPieceAdded for an accepted one) are broadcast last. The drain decides and the Tick moves: nothing here integrates over
// time.
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
        TArray<FMars_Request_Tumbler_SetLoading> SetLoadingRequests = InRequests.SetLoadingRequests;
        TArray<FMars_Request_Tumbler_AddPiece> AddPieceRequests = InRequests.AddPieceRequests;
        const auto ReleaseCount = InRequests.ReleaseRequests.Num();
        const auto PressCount = InRequests.PressRequests.Num();
        auto LookDelta = FVector::ZeroVector;
        for (const auto& Request : InRequests.LookRequests)
        { LookDelta += Request.LookDelta; }

        const auto HasLook = InRequests.LookRequests.Num() > 0;

        // InRequests is invalid past this line; removing before broadcasting lets re-entrant requests survive.
        Self.Request_TryRemove(FMars_Fragment_Tumbler_Requests);

        auto Edges = FMars_Tumbler_DrainEdges();
        Edges.StartMode = InState.Hand.Mode;
        Edges.StartHatch = InState.Hatch;
        Edges.StartDrum = InState.Drum;

        if (HasReset)
        { Apply_Reset(Self, InState); }

        if (HasCancel)
        { Apply_Cancel(Self, InState); }

        if (SetLoadingRequests.Num() > 0)
        { InState.Loading = SetLoadingRequests.Last().Loading; }

        for (const auto& Request : AddPieceRequests)
        { Edges.Admissions.Add(Apply_AddPiece(Self, InState, Request.Release)); }

        for (int32 Index = 0; Index < ReleaseCount; ++Index)
        { Apply_Release(Self, InState); }

        for (int32 Index = 0; Index < PressCount; ++Index)
        { Apply_Press(Self, InState, Edges.Refusals); }

        if (HasLook)
        { Apply_Look(Self, InState, LookDelta); }

        Broadcast(Self, InState, Edges);
    }

    private void Broadcast(FCk_Handle_Tumbler& InTumbler, const FMars_Fragment_Tumbler& InState, const FMars_Tumbler_DrainEdges& InEdges)
    {
        if (InTumbler.Has_Fragment(FMars_Fragment_Tumbler_Signals) == false)
        { return; }

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
            if (InTumbler.Has_Fragment(FMars_Fragment_Tumbler_Signals) == false)
            { return; }

            InTumbler.Get_Fragment(FMars_Fragment_Tumbler_Signals).OnPressRefused.Broadcast(InTumbler, Refusal);
        }

        for (const auto& Result : InEdges.Admissions)
        {
            if (InTumbler.Has_Fragment(FMars_Fragment_Tumbler_Signals) == false)
            { return; }

            InTumbler.Get_Fragment(FMars_Fragment_Tumbler_Signals).OnPieceAdmission.Broadcast(InTumbler, Result.Id, Result.Admission, Result.Reason);
            if (Result.Admission == EMars_CookingFeed_Admission::Accepted && InTumbler.Has_Fragment(FMars_Fragment_Tumbler_Signals))
            { InTumbler.Get_Fragment(FMars_Fragment_Tumbler_Signals).OnPieceAdded.Broadcast(InTumbler, Result.Id, Result.Entity); }
        }
    }

    // Every piece entity this kernel made is destroyed here (its body dies with it), never left to the station's teardown
    // alone.
    private void Apply_Reset(FCk_Handle_Tumbler& InTumbler, FMars_Fragment_Tumbler& InState)
    {
        for (const auto& Piece : InState.Pieces)
        {
            if (ck::IsValid(Piece.Entity))
            { utils_entity_lifetime::Request_DestroyEntity(Piece.Entity); }
        }

        const auto Destroyed = InState.Pieces.Num();
        InState.Pieces.Empty();
        InState.Reseats = 0;

        const auto Spec = InTumbler.Get_Spec();
        auto Lever = Spec.Nodes.Lever;
        if (InState.Hand.Mode == EMars_Tumbler_HandMode::Gripped)
        {
            Lever.Request_EndManipulation();
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

        ck::Trace(f"[Tumbler] [{InTumbler.ToString()}] reset: {Destroyed} piece(s) destroyed, hand free, hatch {InState.Hatch :n}, drum {InState.Drum :n}");
    }

    // A leave mid-grip lets go (the Control settles the drum home); a leave mid-reach stops it. Loading is the feed task's.
    private void Apply_Cancel(FCk_Handle_Tumbler& InTumbler, FMars_Fragment_Tumbler& InState)
    {
        if (InState.Hand.Mode == EMars_Tumbler_HandMode::Free)
        { return; }

        if (InState.Hand.Mode == EMars_Tumbler_HandMode::Gripped)
        { Let_Go(InTumbler, InState); }

        InState.Hand.Mode = EMars_Tumbler_HandMode::Free;
        InState.Hand.ReachElapsed = 0.0f;
        ck::Trace(f"[Tumbler] [{InTumbler.ToString()}] cancelled: hand free, drum {InState.Drum :n}");
    }

    private void Apply_Release(FCk_Handle_Tumbler& InTumbler, FMars_Fragment_Tumbler& InState)
    {
        if (InState.Hand.Mode == EMars_Tumbler_HandMode::Free)
        { return; }

        if (InState.Hand.Mode == EMars_Tumbler_HandMode::Reaching)
        { ck::Trace(f"[Tumbler] [{InTumbler.ToString()}] reach released before the grip"); }
        else
        { Let_Go(InTumbler, InState); }

        InState.Hand.Mode = EMars_Tumbler_HandMode::Free;
        InState.Hand.ReachElapsed = 0.0f;
    }

    private void Let_Go(FCk_Handle_Tumbler& InTumbler, FMars_Fragment_Tumbler& InState)
    {
        auto Lever = InTumbler.Get_Spec().Nodes.Lever;
        Lever.Request_EndManipulation();
        InState.Drum = EMars_Tumbler_Drum::Returning;
        ck::Trace(f"[Tumbler] [{InTumbler.ToString()}] grip ended at {InState.DrumDegrees :.1} degrees: the drum returns");
    }

    // The hovered hatch toggles; the hovered lever starts a reach; anything else is refused and consumed.
    private void Apply_Press(FCk_Handle_Tumbler& InTumbler, FMars_Fragment_Tumbler& InState, TArray<EMars_Tumbler_Refusal>& OutRefusals)
    {
        if (InState.Hovered == EMars_Tumbler_Target::Hatch)
        {
            if (utils_tumbler::Get_CanToggleHatch(InState) == false)
            {
                Refuse(InTumbler, utils_tumbler::Get_HatchRefusal(InState), OutRefusals);
                return;
            }

            const auto Opening = InState.Hatch == EMars_Tumbler_Hatch::Closed;
            auto Hatch = InTumbler.Get_Spec().Nodes.Hatch;
            Hatch.Request_MoveTo(FMars_Request_Mover_MoveTo(Opening ? EMars_Mover_Pose::End : EMars_Mover_Pose::Start));
            InState.Hatch = Opening ? EMars_Tumbler_Hatch::Opening : EMars_Tumbler_Hatch::Closing;
            ck::Trace(f"[Tumbler] [{InTumbler.ToString()}] hatch {InState.Hatch :n}");
            return;
        }

        if (InState.Hovered == EMars_Tumbler_Target::Lever)
        {
            if (utils_tumbler::Get_CanGrip(InState) == false)
            {
                Refuse(InTumbler, utils_tumbler::Get_GripRefusal(InState), OutRefusals);
                return;
            }

            InState.Hand.Mode = EMars_Tumbler_HandMode::Reaching;
            InState.Hand.ReachElapsed = 0.0f;
            InState.Hand.ReachFrom = InState.Hand.HandLocal;
            InState.Hand.ReachFromRotation = InState.Hand.HandRotationLocal;
            ck::Trace(f"[Tumbler] [{InTumbler.ToString()}] reaching for the lever at drum {InState.Drum :n}");
            return;
        }

        Refuse(InTumbler, InState.Hand.Mode == EMars_Tumbler_HandMode::Free ? EMars_Tumbler_Refusal::NoTarget : EMars_Tumbler_Refusal::HandBusy, OutRefusals);
    }

    private void Refuse(FCk_Handle_Tumbler& InTumbler, EMars_Tumbler_Refusal InRefusal, TArray<EMars_Tumbler_Refusal>& OutRefusals)
    {
        OutRefusals.Add(InRefusal);
        ck::Trace(f"[Tumbler] [{InTumbler.ToString()}] press refused: {InRefusal :n}");
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

    // Accepted: a piece entity (a lifetime child of the station) at the release pose with a dynamic box body moving at the
    // release's velocities, coverage 0. Rejected: nothing made, the reason naming the gate.
    private FMars_Tumbler_AdmissionResult Apply_AddPiece(FCk_Handle_Tumbler& InTumbler, FMars_Fragment_Tumbler& InState,
        const FMars_CookingFeed_Release& InRelease)
    {
        auto Result = FMars_Tumbler_AdmissionResult();
        Result.Id = InRelease.PieceId;

        const auto Spec = InTumbler.Get_Spec();
        const auto PieceName = utils_cooking_feed::Get_PieceName(InRelease.PieceId);

        // The shell's bodies are added to the simulation a frame or more after they are built; a piece added before them
        // falls through the drum.
        if (utils_jolt_body::Get_IsBodyAdded(Spec.Nodes.DrumBody) == false)
        { Result.Reason = "the drum body is not in the simulation yet"; }
        else if (InState.Hatch != EMars_Tumbler_Hatch::Open)
        { Result.Reason = f"hatch is {InState.Hatch :n}"; }
        else if (InState.Drum != EMars_Tumbler_Drum::Home)
        { Result.Reason = f"drum is {InState.Drum :n}"; }
        else if (utils_tumbler::Find_PieceIndex(InState.Pieces, InRelease.PieceId) >= 0)
        { Result.Reason = f"piece {PieceName} is already in"; }
        else if (InState.Pieces.Num() >= Spec.Drum.Capacity)
        { Result.Reason = f"Capacity [{Spec.Drum.Capacity}] pieces are already in"; }

        if (Result.Reason.Len() > 0)
        {
            ck::Trace(f"[Tumbler] [{InTumbler.ToString()}] rejected piece {PieceName}: {Result.Reason}");
            return Result;
        }

        const auto& PieceSpec = Spec.Piece;
        const auto ReleaseLocation = InRelease.WorldTransform.GetLocation();
        auto Entity = utils_entity_lifetime::Request_CreateEntity(InTumbler);
        utils_transform::Add(Entity, FTransform(InRelease.WorldTransform.GetRotation(), ReleaseLocation), ECk_Replication::DoesNotReplicate);

        auto Shape = FCk_Jolt_ShapeDimensions(ECk_Jolt_ShapeType::Box);
        Shape.Set_HalfExtents(FVector(PieceSpec.HalfSize, PieceSpec.HalfSize, PieceSpec.HalfSize));
        auto BodySpec = FCk_JoltBody_Spec(ECk_JoltBody_ShapeSource::ExplicitShape);
        BodySpec.Set_ShapeDimensions(Shape);
        BodySpec.Set_MotionType(ECk_MotionType::Dynamic);
        BodySpec.Set_MotionQuality(ECk_MotionQuality::LinearCast);
        BodySpec.Set_MassSource(ECk_JoltBody_MassSource::Explicit);
        BodySpec.Set_MassKg(PieceSpec.MassKg);
        BodySpec.Set_SurfaceSource(ECk_JoltBody_SurfaceSource::Explicit);
        BodySpec.Set_Friction(PieceSpec.Friction);
        BodySpec.Set_Restitution(PieceSpec.Restitution);
        BodySpec.Set_LinearDamping(PieceSpec.LinearDamping);
        BodySpec.Set_AngularDamping(PieceSpec.AngularDamping);
        BodySpec.Set_PersistContacts(ECk_EnableDisable::Enable);
        auto Body = utils_jolt_body::Add(Entity, BodySpec);

        // The body handles its requests only once it is set up and added (the same frame or later), so these wait for it.
        if (InRelease.LinearVelocity.IsNearlyZero() == false)
        { utils_jolt_body::Request_SetLinearVelocity(Body, FCk_Request_JoltBody_SetLinearVelocity(InRelease.LinearVelocity)); }

        if (InRelease.AngularVelocity.IsNearlyZero() == false)
        { utils_jolt_body::Request_SetAngularVelocity(Body, FCk_Request_JoltBody_SetAngularVelocity(InRelease.AngularVelocity)); }

        auto Piece = FMars_Tumbler_PieceState();
        Piece.Id = InRelease.PieceId;
        Piece.PresetIndex = InRelease.PresetIndex;
        Piece.Entity = Entity;
        Piece.Body = Body;
        // The admission frame coats nothing: the first step is measured from where the piece was released.
        Piece.LastWorld = ReleaseLocation;
        InState.Pieces.Add(Piece);

        ck::Trace(f"[Tumbler] [{InTumbler.ToString()}] admitted piece {PieceName} as [{Entity.ToString()}] at {ReleaseLocation} "
            + f"({InState.Pieces.Num()} in the drum)");

        Result.Admission = EMars_CookingFeed_Admission::Accepted;
        Result.Entity = Piece.Entity;
        return Result;
    }
}
