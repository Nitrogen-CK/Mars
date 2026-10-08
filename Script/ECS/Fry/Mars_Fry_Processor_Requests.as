// One AddPiece's answer, broadcast after the whole drain applied.
struct FMars_Fry_AdmissionResult
{
    FMars_CookingFeed_PieceId Id;
    EMars_CookingFeed_Admission Admission = EMars_CookingFeed_Admission::Rejected;
    FString Reason;
    // Accepted only: the new piece entity.
    FCk_Handle Entity;
}

// Drains Reset -> SetDrive -> AddPiece -> Skim -> Look. Reset destroys every piece (the lingering lost ones too), resets the
// skimmer (carry, level, back at its park, idle) and zeroes the tally; SetDrive is last-wins and drives the skimmer (an idle
// one carries); AddPiece admits or rejects each released piece (every one in a drain that also reset is rejected: the
// release belongs to the attempt the reset ended); Skim dips inside the pot, pours over the basket, carries anywhere, and
// is ignored elsewhere or while idle; a look moves the skimmer's target within the reach (the pot only while the scoop is
// dipped or still below the rim) while driven. The new target goes to the skimmer's commanded slide once. The drive and skim
// edges, then every admission answer (and OnPieceAdded for an accepted one) are broadcast last. The drain collects and the
// Tick measures: nothing here integrates over time.
class UMars_Processor_Fry_HandleRequests : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _MarkedDirtyBy = FMars_Fragment_Fry_Requests;

    // A piece's Resting counts a landing after this long apart as a hop (its own default; the kernel does not read hops).
    private const float32 k_HopMinSeconds = 0.12f;

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_Fry);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle,
                       FMars_Fragment_Fry_Requests& InRequests,
                       FMars_Fragment_Fry& InState)
    {
        auto Self = InHandle.As_Fry();

        const auto HasReset = InRequests.ResetRequests.Num() > 0;
        TArray<FMars_Request_Fry_SetDrive> SetDriveRequests = InRequests.SetDriveRequests;
        TArray<FMars_Request_Fry_AddPiece> AddPieceRequests = InRequests.AddPieceRequests;
        TArray<FMars_Request_Fry_Skim> SkimRequests = InRequests.SkimRequests;
        TArray<FMars_Request_Fry_Look> LookRequests = InRequests.LookRequests;

        // InRequests is invalid past this line; removing before broadcasting lets re-entrant requests survive.
        Self.Request_TryRemove(FMars_Fragment_Fry_Requests);

        const auto StartDrive = InState.Drive;
        const auto StartSkim = InState.Skim;

        if (HasReset)
        { Apply_Reset(Self, InState); }

        if (SetDriveRequests.Num() > 0)
        { Apply_SetDrive(Self, InState, SetDriveRequests.Last().Drive); }

        TArray<FMars_Fry_AdmissionResult> Admissions;
        for (const auto& Request : AddPieceRequests)
        {
            if (HasReset)
            { Admissions.Add(Reject_InResetDrain(Self, Request.Release)); }
            else
            { Admissions.Add(Apply_AddPiece(Self, InState, Request.Release)); }
        }

        const auto TargetBeforeSteering = InState.SkimmerTarget;

        for (const auto& Request : SkimRequests)
        { Apply_Skim(Self, InState, Request.Skim); }

        if (LookRequests.Num() > 0 && InState.Drive == EMars_Implement_Drive::Driven)
        {
            // Look right moves the target +Y, look down moves it -X, Reach.CmPerLookDegree per degree; each step is clamped
            // to the reach, the pot only for a dipped scoop or one still below the rim (measured once: the looks of one drain
            // all see the scoop where the last transform update left it).
            const auto Spec = Self.Get_Spec();
            const auto Step = float64(Spec.Reach.CmPerLookDegree);
            const auto ReachSkim = Self.Get_IsScoopClearOfRim() ? InState.Skim : EMars_Fry_Skim::Dip;
            for (const auto& Request : LookRequests)
            {
                const auto Target = InState.SkimmerTarget + FVector2D(-Request.LookDelta.Y * Step, Request.LookDelta.X * Step);
                InState.SkimmerTarget = utils_fry::Clamp_Reach(Target, Spec, ReachSkim);
            }
        }

        if ((InState.SkimmerTarget - TargetBeforeSteering).Size() > 0.0001)
        { Send_SlideTarget(Self, InState); }

        if (Self.Has_Fragment(FMars_Fragment_Fry_Signals) == false)
        { return; }

        if (InState.Drive != StartDrive)
        { Self.Get_Fragment(FMars_Fragment_Fry_Signals).OnDriveChanged.Broadcast(Self, InState.Drive); }

        if (InState.Skim != StartSkim && Self.Has_Fragment(FMars_Fragment_Fry_Signals))
        { Self.Get_Fragment(FMars_Fragment_Fry_Signals).OnSkimChanged.Broadcast(Self, InState.Skim); }

        for (const auto& Result : Admissions)
        {
            if (Self.Has_Fragment(FMars_Fragment_Fry_Signals) == false)
            { return; }

            Self.Get_Fragment(FMars_Fragment_Fry_Signals).OnPieceAdmission.Broadcast(Self, Result.Id, Result.Admission, Result.Reason);
            if (Result.Admission == EMars_CookingFeed_Admission::Accepted && Self.Has_Fragment(FMars_Fragment_Fry_Signals))
            { Self.Get_Fragment(FMars_Fragment_Fry_Signals).OnPieceAdded.Broadcast(Self, Result.Id, Result.Entity); }
        }
    }

    // Every piece this kernel admitted is destroyed here (the lost ones too), never left to the station's teardown alone.
    // The skimmer's own reset idles and levels it and zeroes its slide; its lift target goes back to the carry.
    private void Apply_Reset(FCk_Handle_Fry& InFry, FMars_Fragment_Fry& InState)
    {
        for (const auto& Piece : InState.Pieces)
        {
            if (ck::IsValid(Piece.Entity))
            { utils_entity_lifetime::Request_DestroyEntity(Piece.Entity); }
        }

        const auto Destroyed = InState.Pieces.Num();
        InState.Pieces.Empty();
        InState.Tally = FMars_Fry_Tally();
        InState.Drive = EMars_Implement_Drive::Idle;
        InState.Skim = EMars_Fry_Skim::Carry;
        InState.SkimmerTarget = InState.SkimmerPark;

        auto Skimmer = InFry.Get_Skimmer();
        Skimmer.Request_Reset(FMars_Request_Implement_Reset());
        // After the implement's reset in its own drain: the carry height is the skimmer's, not necessarily its rest.
        Skimmer.Request_SetLiftTarget(FMars_Request_Implement_SetLiftTarget(InFry.Get_Spec().Scoop.CarryLift));
        Skimmer.Request_SetSlideTarget(FMars_Request_Implement_SetSlideTarget(FVector2D::ZeroVector));

        ck::Trace(f"[Fry] [{InFry.ToString()}] reset: {Destroyed} piece(s) destroyed, skimmer parked, carrying and idle");
    }

    // An idle skimmer carries: nobody holds it in the oil.
    private void Apply_SetDrive(FCk_Handle_Fry& InFry, FMars_Fragment_Fry& InState, EMars_Implement_Drive InDrive)
    {
        if (InDrive == InState.Drive)
        { return; }

        InState.Drive = InDrive;
        auto Skimmer = InFry.Get_Skimmer();
        Skimmer.Request_SetDrive(FMars_Request_Implement_SetDrive(InDrive));

        if (InDrive == EMars_Implement_Drive::Idle)
        { Set_Skim(InFry, InState, EMars_Fry_Skim::Carry); }

        ck::Trace(f"[Fry] [{InFry.ToString()}] skimmer {InDrive :n}");
    }

    private FMars_Fry_AdmissionResult Reject_InResetDrain(FCk_Handle_Fry& InFry, const FMars_CookingFeed_Release& InRelease)
    {
        auto Result = FMars_Fry_AdmissionResult();
        Result.Id = InRelease.PieceId;
        Result.Reason = "reset in the same drain";
        ck::Trace(f"[Fry] [{InFry.ToString()}] rejected piece {utils_cooking_feed::Get_PieceName(InRelease.PieceId)}: {Result.Reason}");
        return Result;
    }

    // Admitted: a piece entity (a lifetime child of the station) at the release pose, with a dynamic box body moving at the
    // release's velocities and a Resting on the scoop disc and the basket floor (which tell whether it lies on the scoop and
    // whether it is supported in the basket). It starts Airborne, its last home the Oil. Rejected: nothing made.
    private FMars_Fry_AdmissionResult Apply_AddPiece(FCk_Handle_Fry& InFry, FMars_Fragment_Fry& InState,
        const FMars_CookingFeed_Release& InRelease)
    {
        auto Result = FMars_Fry_AdmissionResult();
        Result.Id = InRelease.PieceId;

        const auto Spec = InFry.Get_Spec();
        const auto PieceName = utils_cooking_feed::Get_PieceName(InRelease.PieceId);

        // A piece's Resting needs both bodies, and a piece dropped toward a body not there yet falls through it.
        if (utils_jolt_body::Get_IsBodyAdded(Spec.Nodes.ScoopBody) == false || utils_jolt_body::Get_IsBodyAdded(Spec.Nodes.BasketBody) == false)
        { Result.Reason = "the scoop or basket body is not in the simulation yet"; }
        else if (utils_fry::Find_PieceIndex(InState.Pieces, InRelease.PieceId) >= 0)
        { Result.Reason = f"piece {PieceName} is already in play"; }
        else if (utils_fry::Get_LivePieceCount(InState.Pieces) >= Spec.Supply.MaxPieces)
        { Result.Reason = f"Supply.MaxPieces [{Spec.Supply.MaxPieces}] pieces are already in play"; }

        if (Result.Reason.Len() > 0)
        {
            ck::Trace(f"[Fry] [{InFry.ToString()}] rejected piece {PieceName}: {Result.Reason}");
            return Result;
        }

        const auto& PieceSpec = Spec.Piece;
        auto Entity = utils_entity_lifetime::Request_CreateEntity(InFry);
        utils_transform::Add(Entity, FTransform(InRelease.WorldTransform.GetRotation(), InRelease.WorldTransform.GetLocation()),
            ECk_Replication::DoesNotReplicate);

        const auto HalfSize = float64(PieceSpec.HalfSize);
        auto Shape = FCk_Jolt_ShapeDimensions(ECk_Jolt_ShapeType::Box);
        Shape.Set_HalfExtents(FVector(HalfSize, HalfSize, HalfSize));
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
        BodySpec.Set_GravityFactor(PieceSpec.GravityFactor);
        // The Resting needs a Persisted contact every step from a resting awake piece.
        BodySpec.Set_PersistContacts(ECk_EnableDisable::Enable);
        auto Body = utils_jolt_body::Add(Entity, BodySpec);

        // The body handles its requests only once it is set up and added (the same frame or later), so these wait for it.
        if (InRelease.LinearVelocity.IsNearlyZero() == false)
        { utils_jolt_body::Request_SetLinearVelocity(Body, FCk_Request_JoltBody_SetLinearVelocity(InRelease.LinearVelocity)); }

        if (InRelease.AngularVelocity.IsNearlyZero() == false)
        { utils_jolt_body::Request_SetAngularVelocity(Body, FCk_Request_JoltBody_SetAngularVelocity(InRelease.AngularVelocity)); }

        TArray<FCk_Handle> Supports;
        Supports.Add(Spec.Nodes.ScoopBody);
        Supports.Add(Spec.Nodes.BasketBody);
        utils_resting::Add(Entity, FMars_Resting_Spec(Supports, Spec.Receiver.SupportGraceSeconds, k_HopMinSeconds));

        auto Piece = FMars_Fry_PieceState();
        Piece.Id = InRelease.PieceId;
        Piece.PresetIndex = InRelease.PresetIndex;
        Piece.Entity = Entity;
        Piece.Body = Body;
        Piece.Whereabouts = EMars_Fry_Whereabouts::Airborne;
        Piece.LastHome = EMars_Fry_Whereabouts::Oil;
        for (int32 Index = 0; Index < utils_searing::k_FaceCount; ++Index)
        {
            Piece.FaceHeat.Add(0.0f);
            Piece.ReportedStage.Add(EMars_Fry_HeatStage::Pale);
        }

        InState.Pieces.Add(Piece);

        ck::Trace(f"[Fry] [{InFry.ToString()}] admitted piece {PieceName} as [{Entity.ToString()}] "
            + f"({utils_fry::Get_LivePieceCount(InState.Pieces)} in play)");

        Result.Admission = EMars_CookingFeed_Admission::Accepted;
        Result.Entity = Entity;
        return Result;
    }

    // Carry is honoured anywhere. A Dip (or a Pour asked for) dips with the whole scoop inside the pot (and holds the target
    // there, so it cannot carry on out while dipped), pours with the whole bowl over the basket interior (lowering the disc
    // there would press the basket's pieces through its floor), and is ignored elsewhere (in the corridor the disc would
    // drop into the counter).
    private void Apply_Skim(FCk_Handle_Fry& InFry, FMars_Fragment_Fry& InState, EMars_Fry_Skim InSkim)
    {
        if (InState.Drive != EMars_Implement_Drive::Driven)
        {
            ck::Trace(f"[Fry] [{InFry.ToString()}] skim {InSkim :n} ignored (the skimmer is idle)");
            return;
        }

        const auto ScoopRoot = InFry.Get_ScoopRoot();
        if (InSkim == EMars_Fry_Skim::Carry)
        {
            Set_Skim(InFry, InState, EMars_Fry_Skim::Carry);
            ck::Trace(f"[Fry] [{InFry.ToString()}] skim Carry with the scoop at root XY ({ScoopRoot.X :.2}, {ScoopRoot.Y :.2})");
            return;
        }

        if (InFry.Get_IsScoopInPot())
        {
            Set_Skim(InFry, InState, EMars_Fry_Skim::Dip);
            InState.SkimmerTarget = utils_fry::Clamp_Reach(InState.SkimmerTarget, InFry.Get_Spec(), EMars_Fry_Skim::Dip);
            ck::Trace(f"[Fry] [{InFry.ToString()}] skim Dip with the scoop at root XY ({ScoopRoot.X :.2}, {ScoopRoot.Y :.2})");
            return;
        }

        if (InFry.Get_IsScoopOverBasket())
        {
            Set_Skim(InFry, InState, EMars_Fry_Skim::Pour);
            ck::Trace(f"[Fry] [{InFry.ToString()}] skim Pour with the scoop at root XY ({ScoopRoot.X :.2}, {ScoopRoot.Y :.2})");
            return;
        }

        ck::Trace(f"[Fry] [{InFry.ToString()}] skim {InSkim :n} ignored: the scoop at root XY ({ScoopRoot.X :.2}, {ScoopRoot.Y :.2}) is neither in the pot nor over the basket");
    }

    // The skimmer implement's commanded lift and tilt follow the skim: its spring lowers or raises the scoop, its tilt tips
    // it toward the operator for the pour (a positive pitch raises the far side, +X, in the skimmer's rest frame, which Add
    // ensures is axis-aligned with the root) or levels it.
    private void Set_Skim(FCk_Handle_Fry& InFry, FMars_Fragment_Fry& InState, EMars_Fry_Skim InSkim)
    {
        const auto& Scoop = InFry.Get_Spec().Scoop;
        const auto Lift = InSkim == EMars_Fry_Skim::Dip ? Scoop.DipLift : Scoop.CarryLift;
        const auto Pitch = InSkim == EMars_Fry_Skim::Pour ? float64(Scoop.PourPitchDegrees) : 0.0;
        auto Skimmer = InFry.Get_Skimmer();
        Skimmer.Request_SetLiftTarget(FMars_Request_Implement_SetLiftTarget(Lift));
        Skimmer.Request_SetTiltTarget(FMars_Request_Implement_SetTiltTarget(FRotator(Pitch, 0.0, 0.0)));
        InState.Skim = InSkim;
    }

    // The target in the skimmer's rest frame: its offset from the park (the rest frame is axis-aligned with the root; Add
    // ensures it).
    private void Send_SlideTarget(FCk_Handle_Fry& InFry, const FMars_Fragment_Fry& InState)
    {
        auto Skimmer = InFry.Get_Skimmer();
        Skimmer.Request_SetSlideTarget(FMars_Request_Implement_SetSlideTarget(InState.SkimmerTarget - InState.SkimmerPark));
    }
}
