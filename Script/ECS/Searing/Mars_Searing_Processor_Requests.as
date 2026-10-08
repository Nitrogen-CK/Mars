// One AddPiece's answer, broadcast after the whole drain applied.
struct FMars_Searing_AdmissionResult
{
    FMars_CookingFeed_PieceId Id;
    EMars_CookingFeed_Admission Admission = EMars_CookingFeed_Admission::Rejected;
    FString Reason;
    // Accepted only: the new piece entity.
    FCk_Handle Entity;
}

// Drains Reset -> SetHeat -> AddPiece -> Look. Reset destroys every piece (the lingering lost ones too), resets the pan,
// chills it and zeroes the tally; SetHeat is last-wins and drives the pan (Driven while hot); AddPiece admits or rejects
// each released piece (a cold pan accepts; every one in a drain that also reset is rejected: the release belongs to the
// attempt the reset ended); looks are forwarded to the pan while it is hot. The pan feature measures the
// looks in its Tick. The heat edge, then every admission answer (and OnPieceAdded for an accepted one) are broadcast last.
class UMars_Processor_Searing_HandleRequests : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _MarkedDirtyBy = FMars_Fragment_Searing_Requests;

    // A piece's Resting counts a landing after this long apart as a hop (its own default; the kernel does not read hops).
    private const float32 k_HopMinSeconds = 0.12f;

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_Searing);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle,
                       FMars_Fragment_Searing_Requests& InRequests,
                       FMars_Fragment_Searing& InState)
    {
        auto Self = InHandle.As_Searing();
        auto Pan = Self.Get_Pan();

        const auto HasReset = InRequests.ResetRequests.Num() > 0;
        TArray<FMars_Request_Searing_SetHeat> SetHeatRequests = InRequests.SetHeatRequests;
        TArray<FMars_Request_Searing_AddPiece> AddPieceRequests = InRequests.AddPieceRequests;
        TArray<FMars_Request_Searing_Look> LookRequests = InRequests.LookRequests;

        // InRequests is invalid past this line; removing before broadcasting lets re-entrant requests survive.
        Self.Request_TryRemove(FMars_Fragment_Searing_Requests);

        const auto StartHeat = InState.Heat;

        if (HasReset)
        { Apply_Reset(Self, InState); }

        if (SetHeatRequests.Num() > 0)
        { InState.Heat = SetHeatRequests.Last().Heat; }

        const auto NewHeat = InState.Heat;

        // The pan's reset idles it, so a reset re-sends the drive too (a reset and a heat can share a drain).
        if (HasReset || NewHeat != StartHeat)
        {
            const auto Drive = NewHeat == EMars_Searing_Heat::Hot ? EMars_Implement_Drive::Driven : EMars_Implement_Drive::Idle;
            Pan.Request_SetDrive(FMars_Request_Implement_SetDrive(Drive));
        }

        TArray<FMars_Searing_AdmissionResult> Admissions;
        for (const auto& Request : AddPieceRequests)
        {
            if (HasReset)
            { Admissions.Add(Reject_InResetDrain(Self, Request.Release)); }
            else
            { Admissions.Add(Apply_AddPiece(Self, InState, Request.Release)); }
        }

        if (NewHeat == EMars_Searing_Heat::Hot)
        {
            for (const auto& Request : LookRequests)
            { Pan.Request_Look(FMars_Request_Implement_Look(Request.LookDelta)); }
        }

        if (Self.Has_Fragment(FMars_Fragment_Searing_Signals) == false)
        { return; }

        if (NewHeat != StartHeat)
        { Self.Get_Fragment(FMars_Fragment_Searing_Signals).OnHeatChanged.Broadcast(Self, NewHeat); }

        for (const auto& Result : Admissions)
        {
            Self.Get_Fragment(FMars_Fragment_Searing_Signals).OnPieceAdmission.Broadcast(Self, Result.Id, Result.Admission, Result.Reason);
            if (Result.Admission == EMars_CookingFeed_Admission::Accepted)
            { Self.Get_Fragment(FMars_Fragment_Searing_Signals).OnPieceAdded.Broadcast(Self, Result.Id, Result.Entity); }
        }
    }

    // Every piece this kernel admitted is destroyed here (the lost ones too), never left to the station's teardown alone.
    private void Apply_Reset(FCk_Handle_Searing& InSearing, FMars_Fragment_Searing& InState)
    {
        for (const auto& Piece : InState.Pieces)
        {
            if (ck::IsValid(Piece.Entity))
            { utils_entity_lifetime::Request_DestroyEntity(Piece.Entity); }
        }

        const auto Destroyed = InState.Pieces.Num();
        InState.Pieces.Empty();
        InState.Tally = FMars_Searing_Tally();
        InState.Heat = EMars_Searing_Heat::Cold;

        auto Pan = InSearing.Get_Pan();
        Pan.Request_Reset(FMars_Request_Implement_Reset());

        ck::Trace(f"[Searing] [{InSearing.ToString()}] reset: {Destroyed} piece(s) destroyed, pan reset and cold");
    }

    private FMars_Searing_AdmissionResult Reject_InResetDrain(FCk_Handle_Searing& InSearing, const FMars_CookingFeed_Release& InRelease)
    {
        auto Result = FMars_Searing_AdmissionResult();
        Result.Id = InRelease.PieceId;
        Result.Reason = "reset in the same drain";
        ck::Trace(f"[Searing] [{InSearing.ToString()}] rejected piece {utils_cooking_feed::Get_PieceName(InRelease.PieceId)}: {Result.Reason}");
        return Result;
    }

    // Admitted: a piece entity (a lifetime child of the station) at the release pose, flat as released (NegZ is its resting
    // face), with a dynamic box body moving at the release's velocities and a Resting on the pan base body (which tells
    // whether it lies on the pan). It starts Airborne and becomes OnPan once it rests on the base. Rejected: nothing made.
    private FMars_Searing_AdmissionResult Apply_AddPiece(FCk_Handle_Searing& InSearing, FMars_Fragment_Searing& InState,
        const FMars_CookingFeed_Release& InRelease)
    {
        auto Result = FMars_Searing_AdmissionResult();
        Result.Id = InRelease.PieceId;

        const auto Spec = InSearing.Get_Spec();
        const auto PieceName = utils_cooking_feed::Get_PieceName(InRelease.PieceId);

        // The pan body cooks from its mesh after a preload; a piece added over a pan that is not there yet falls through it.
        if (utils_jolt_body::Get_IsBodyAdded(Spec.Nodes.PanBaseBody) == false)
        { Result.Reason = "the pan body is not in the simulation yet"; }
        else if (utils_searing::Find_PieceIndex(InState.Pieces, InRelease.PieceId) >= 0)
        { Result.Reason = f"piece {PieceName} is already on the pan"; }
        else if (utils_searing::Get_LivePieceCount(InState.Pieces) >= Spec.Supply.MaxPieces)
        { Result.Reason = f"the pan already holds Supply.MaxPieces [{Spec.Supply.MaxPieces}] pieces"; }

        if (Result.Reason.Len() > 0)
        {
            ck::Trace(f"[Searing] [{InSearing.ToString()}] rejected piece {PieceName}: {Result.Reason}");
            return Result;
        }

        const auto& SteakSpec = Spec.Steak;
        auto Entity = utils_entity_lifetime::Request_CreateEntity(InSearing);
        utils_transform::Add(Entity, FTransform(InRelease.WorldTransform.GetRotation(), InRelease.WorldTransform.GetLocation()),
            ECk_Replication::DoesNotReplicate);

        auto Shape = FCk_Jolt_ShapeDimensions(ECk_Jolt_ShapeType::Box);
        Shape.Set_HalfExtents(FVector(SteakSpec.HalfSize, SteakSpec.HalfSize, SteakSpec.HalfSize));
        auto BodySpec = FCk_JoltBody_Spec(ECk_JoltBody_ShapeSource::ExplicitShape);
        BodySpec.Set_ShapeDimensions(Shape);
        BodySpec.Set_MotionType(ECk_MotionType::Dynamic);
        BodySpec.Set_MotionQuality(ECk_MotionQuality::LinearCast);
        BodySpec.Set_MassSource(ECk_JoltBody_MassSource::Explicit);
        BodySpec.Set_MassKg(SteakSpec.MassKg);
        BodySpec.Set_SurfaceSource(ECk_JoltBody_SurfaceSource::Explicit);
        BodySpec.Set_Friction(SteakSpec.Friction);
        BodySpec.Set_Restitution(SteakSpec.Restitution);
        BodySpec.Set_LinearDamping(SteakSpec.LinearDamping);
        BodySpec.Set_AngularDamping(SteakSpec.AngularDamping);
        // The Resting needs a Persisted contact every step from a resting awake piece.
        BodySpec.Set_PersistContacts(ECk_EnableDisable::Enable);
        auto Body = utils_jolt_body::Add(Entity, BodySpec);

        // The body handles its requests only once it is set up and added (the same frame or later), so these wait for it.
        if (InRelease.LinearVelocity.IsNearlyZero() == false)
        { utils_jolt_body::Request_SetLinearVelocity(Body, FCk_Request_JoltBody_SetLinearVelocity(InRelease.LinearVelocity)); }

        if (InRelease.AngularVelocity.IsNearlyZero() == false)
        { utils_jolt_body::Request_SetAngularVelocity(Body, FCk_Request_JoltBody_SetAngularVelocity(InRelease.AngularVelocity)); }

        utils_resting::Add(Entity, FMars_Resting_Spec(Spec.Nodes.PanBaseBody, SteakSpec.ContactGraceSeconds, k_HopMinSeconds));

        auto Piece = FMars_Searing_PieceState();
        Piece.Id = InRelease.PieceId;
        Piece.Entity = Entity;
        Piece.Body = Body;
        for (int32 Index = 0; Index < utils_searing::k_FaceCount; ++Index)
        { Piece.FaceSear.Add(0.0f); }

        InState.Pieces.Add(Piece);

        ck::Trace(f"[Searing] [{InSearing.ToString()}] admitted piece {PieceName} as [{Entity.ToString()}] "
            + f"({utils_searing::Get_LivePieceCount(InState.Pieces)} on the pan)");

        Result.Admission = EMars_CookingFeed_Admission::Accepted;
        Result.Entity = Entity;
        return Result;
    }
}
