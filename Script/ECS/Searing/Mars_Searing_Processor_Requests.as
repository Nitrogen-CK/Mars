// One AddPiece's answer, broadcast after the whole drain applied.
struct FMars_Searing_AdmissionResult
{
    FMars_CookingFeed_PieceId Id;
    EMars_CookingFeed_Admission Admission = EMars_CookingFeed_Admission::Rejected;
    FString Reason;
    // Accepted only: the adopted piece's entity.
    FCk_Handle Entity;
}

// One piece a TakeOut handed back, broadcast after the whole drain applied.
struct FMars_Searing_TakeOutResult
{
    FMars_CookingFeed_PieceId Id;
    FCk_Handle_FoodPiece Piece;
}

// Drains Reset -> SetHeat -> TakeOut -> AddPiece -> Look. Reset resets the pan, chills it and zeroes the tally, and keeps
// every piece with its sear; SetHeat is last-wins and drives the pan (Driven while hot); TakeOut hands pieces back with
// their cook state written and their bodies Kinematic; AddPiece adopts or rejects each released piece (a cold pan accepts;
// every one in a drain that also reset is rejected: the release belongs to the attempt the reset ended); looks are forwarded
// to the pan while it is hot. The pan feature measures the looks in its Tick. The heat edge, then every take-out, then
// every admission answer (and OnPieceAdded for an accepted one) are broadcast last.
//
// A piece is the kernel's guest: the kernel creates no entity, and a piece it holds ends only lost (the Tick) or with the
// station (OnSearingBeginDestroy).
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
        TArray<FMars_Request_Searing_TakeOut> TakeOutRequests = InRequests.TakeOutRequests;
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

        TArray<FMars_Searing_TakeOutResult> TakenOut;
        for (const auto& Request : TakeOutRequests)
        { TakenOut.Append(Apply_TakeOut(Self, InState, Request)); }

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

        for (const auto& Result : TakenOut)
        { Self.Get_Fragment(FMars_Fragment_Searing_Signals).OnPieceTakenOut.Broadcast(Self, Result.Id, Result.Piece); }

        for (const auto& Result : Admissions)
        {
            Self.Get_Fragment(FMars_Fragment_Searing_Signals).OnPieceAdmission.Broadcast(Self, Result.Id, Result.Admission, Result.Reason);
            if (Result.Admission == EMars_CookingFeed_Admission::Accepted)
            { Self.Get_Fragment(FMars_Fragment_Searing_Signals).OnPieceAdded.Broadcast(Self, Result.Id, Result.Entity); }
        }
    }

    // The player's food is theirs: every piece stays on the pan with its sear (a lost one lingers out its time); only the
    // tally, the heat and the pan go back.
    private void Apply_Reset(FCk_Handle_Searing& InSearing, FMars_Fragment_Searing& InState)
    {
        InState.Tally = FMars_Searing_Tally();
        InState.Heat = EMars_Searing_Heat::Cold;

        auto Pan = InSearing.Get_Pan();
        Pan.Request_Reset(FMars_Request_Implement_Reset());

        ck::Trace(f"[Searing] [{InSearing.ToString()}] reset: {InState.Pieces.Num()} piece(s) kept, pan reset and cold");
    }

    private FMars_Searing_AdmissionResult Reject_InResetDrain(FCk_Handle_Searing& InSearing, const FMars_CookingFeed_Release& InRelease)
    {
        auto Result = FMars_Searing_AdmissionResult();
        Result.Id = InRelease.PieceId;
        Result.Reason = "reset in the same drain";
        ck::Trace(f"[Searing] [{InSearing.ToString()}] rejected piece {utils_cooking_feed::Get_PieceName(InRelease.PieceId)}: {Result.Reason}");
        return Result;
    }

    // Unset Piece: every Ready piece, in admission order; set: that piece while it is on the pan and not lost. MaxPieces caps
    // either. Each one leaves the books with its cook state written onto the piece and its body Kinematic (a platter takes it
    // next); its Resting stays for whoever adopts it next to retarget.
    private TArray<FMars_Searing_TakeOutResult> Apply_TakeOut(FCk_Handle_Searing& InSearing, FMars_Fragment_Searing& InState,
        const FMars_Request_Searing_TakeOut& InRequest)
    {
        TArray<FMars_Searing_TakeOutResult> Taken;
        TArray<FMars_Searing_PieceState> Kept;
        for (const auto& Piece : InState.Pieces)
        {
            const auto IsCapped = InRequest.MaxPieces.IsSet() && Taken.Num() >= InRequest.MaxPieces.GetValue();
            if (IsCapped || Get_IsTakeable(Piece, InRequest) == false)
            {
                Kept.Add(Piece);
                continue;
            }

            Hand_Back(Piece);

            auto Result = FMars_Searing_TakeOutResult();
            Result.Id = Piece.Id;
            Result.Piece = Piece.Piece;
            Taken.Add(Result);
        }

        InState.Pieces = Kept;
        InState.Tally.TakenOut += Taken.Num();

        ck::Trace(f"[Searing] [{InSearing.ToString()}] took out {Taken.Num()} piece(s) ({utils_searing::Get_LivePieceCount(InState.Pieces)} left on the pan)");
        return Taken;
    }

    private bool Get_IsTakeable(const FMars_Searing_PieceState& InPiece, const FMars_Request_Searing_TakeOut& InRequest) const
    {
        if (Get_IsGone(InPiece.Piece))
        { return false; }

        if (InRequest.Piece.IsSet())
        { return InPiece.Piece == InRequest.Piece.GetValue() && InPiece.Status != EMars_Searing_PieceStatus::Lost; }

        return InPiece.Status == EMars_Searing_PieceStatus::Ready;
    }

    private void Hand_Back(const FMars_Searing_PieceState& InPiece)
    {
        auto Piece = InPiece.Piece;
        Piece.Request_SetCookState(FMars_Request_FoodPiece_SetCookState(utils_searing::Get_CookState(InPiece, Piece.Get_CookState())));

        auto Body = InPiece.Body;
        utils_jolt_body::Request_SetMotionType(Body, FCk_Request_JoltBody_SetMotionType(ECk_MotionType::Kinematic));
    }

    // Adopted: the released piece (Release.Piece, Ready, on no platter and no scene node) moves to the release pose, flat as
    // released (NegZ is its resting face), with a dynamic body moving at the release's velocities and a Resting on the pan
    // base body (which tells whether it lies on the pan); its sear is seeded from its cook state. It starts Airborne and
    // becomes OnPan once it rests on the base. Rejected: the piece is left as it was.
    private FMars_Searing_AdmissionResult Apply_AddPiece(FCk_Handle_Searing& InSearing, FMars_Fragment_Searing& InState,
        const FMars_CookingFeed_Release& InRelease)
    {
        auto Result = FMars_Searing_AdmissionResult();
        Result.Id = InRelease.PieceId;

        const auto Spec = InSearing.Get_Spec();
        const auto PieceName = utils_cooking_feed::Get_PieceName(InRelease.PieceId);
        auto Piece = InRelease.Piece;
        FCk_Handle Entity = Piece;

        // The pan body cooks from its mesh after a preload; a piece added over a pan that is not there yet falls through it.
        if (utils_jolt_body::Get_IsBodyAdded(Spec.Nodes.PanBaseBody) == false)
        { Result.Reason = "the pan body is not in the simulation yet"; }
        else if (Get_IsGone(Piece))
        { Result.Reason = "no piece"; }
        else if (Piece.Get_Status() != EMars_FoodPiece_Status::Ready)
        { Result.Reason = "the piece is not ready"; }
        else if (utils_searing::Find_PieceIndexByHandle(InState.Pieces, Piece) >= 0)
        { Result.Reason = "already admitted"; }
        else if (utils_searing::Find_PieceIndex(InState.Pieces, InRelease.PieceId) >= 0)
        { Result.Reason = f"piece {PieceName} is already on the pan"; }
        else if (ck::IsValid(Piece.TryGet_Platter()))
        { Result.Reason = "still on its platter"; }
        else if (Entity.Is_SceneNode())
        { Result.Reason = "still attached"; }
        else if (utils_searing::Get_LivePieceCount(InState.Pieces) >= Spec.Supply.MaxPieces)
        { Result.Reason = f"the pan already holds Supply.MaxPieces [{Spec.Supply.MaxPieces}] pieces"; }

        if (Result.Reason.Len() > 0)
        {
            ck::Trace(f"[Searing] [{InSearing.ToString()}] rejected piece {PieceName} [{Piece.ToString()}]: {Result.Reason}");
            return Result;
        }

        const auto Body = Adopt_Body(Piece, InRelease, Spec.Piece);

        // A piece that rested on another station's supports already tracks them: it is pointed at this pan instead.
        if (Entity.Is_Resting())
        {
            TArray<FCk_Handle> Targets;
            Targets.Add(Spec.Nodes.PanBaseBody);
            auto Resting = Entity.As_Resting();
            Resting.Request_Retarget(FMars_Request_Resting_Retarget(Targets, Spec.Piece.ContactGraceSeconds, k_HopMinSeconds));
        }
        else
        { utils_resting::Add(Entity, FMars_Resting_Spec(Spec.Nodes.PanBaseBody, Spec.Piece.ContactGraceSeconds, k_HopMinSeconds)); }

        const auto Metrics = utils_runtime_mesh::Get_Metrics(Piece.Get_Geometry());
        auto State = FMars_Searing_PieceState();
        State.Id = InRelease.PieceId;
        State.Piece = Piece;
        State.Entity = Entity;
        State.Body = Body;
        State.CentreLocal = utils_searing::Get_BoundsCentre(Metrics);
        State.HalfExtents = utils_searing::Get_BoundsHalfExtents(Metrics);
        State.Arriving = TOptional<FVector>(InRelease.WorldTransform.GetLocation());

        // A face seared elsewhere arrives seared; a piece seared all round arrives Ready.
        const auto Seed = Piece.Get_CookState();
        for (int32 Index = 0; Index < utils_searing::k_FaceCount; ++Index)
        { State.FaceSear.Add(Seed.FaceSear.IsValidIndex(Index) ? Math::Clamp(Seed.FaceSear[Index], 0.0f, 1.0f) : 0.0f); }

        if (utils_searing::Get_SearedFaceCount(State.FaceSear) >= utils_searing::k_FaceCount)
        { State.Status = EMars_Searing_PieceStatus::Ready; }

        InState.Pieces.Add(State);
        Watch_Teardown(InSearing);

        ck::Trace(f"[Searing] [{InSearing.ToString()}] adopted piece {PieceName} [{Entity.ToString()}] "
            + f"({utils_searing::Get_SearedFaceCount(State.FaceSear)} face(s) seared, {utils_searing::Get_LivePieceCount(InState.Pieces)} on the pan)");

        Result.Admission = EMars_CookingFeed_Admission::Accepted;
        Result.Entity = Entity;
        return Result;
    }

    // A piece without a body is posed at the release first (a body reads its entity's pose when it is added) and given a
    // dynamic convex body from its own mesh at its own mass. A piece that left another station keeps its body: switched back
    // to Dynamic and teleported to the release. Either way the release's velocities follow (the body handles its requests
    // once it is set up and added, so these wait for it).
    private FCk_Handle_JoltBody Adopt_Body(FCk_Handle_FoodPiece InPiece, const FMars_CookingFeed_Release& InRelease,
        const FMars_Searing_PieceSpec& InSpec)
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
            BodySpec.Set_MassKg(float32(InPiece.Get_MassKg()));
            BodySpec.Set_SurfaceSource(ECk_JoltBody_SurfaceSource::Explicit);
            BodySpec.Set_Friction(InSpec.Friction);
            BodySpec.Set_Restitution(InSpec.Restitution);
            BodySpec.Set_LinearDamping(InSpec.LinearDamping);
            BodySpec.Set_AngularDamping(InSpec.AngularDamping);
            // The Resting needs a Persisted contact every step from a resting awake piece.
            BodySpec.Set_PersistContacts(ECk_EnableDisable::Enable);
            Body = utils_jolt_body::Add(Entity, BodySpec);
        }

        if (InRelease.LinearVelocity.IsNearlyZero() == false)
        { utils_jolt_body::Request_SetLinearVelocity(Body, FCk_Request_JoltBody_SetLinearVelocity(InRelease.LinearVelocity)); }

        if (InRelease.AngularVelocity.IsNearlyZero() == false)
        { utils_jolt_body::Request_SetAngularVelocity(Body, FCk_Request_JoltBody_SetAngularVelocity(InRelease.AngularVelocity)); }

        return Body;
    }

    private bool Get_IsGone(const FCk_Handle_FoodPiece& InPiece) const
    {
        return ck::Is_NOT_Valid(InPiece) || utils_entity_lifetime::Get_IsPendingDestroy(InPiece, ECk_EntityLifetime_DestructionPhase::BeginDestroy);
    }

    // Unbinding first keeps the watch single across admissions.
    private void Watch_Teardown(const FCk_Handle_Searing& InSearing)
    {
        FCk_Handle Searing = InSearing;
        Searing.UnbindFrom_OnBeginDestroy(FCk_Delegate_OnBeginDestroy(this, n"OnSearingBeginDestroy"));
        Searing.BindTo_OnBeginDestroy(FCk_Delegate_OnBeginDestroy(this, n"OnSearingBeginDestroy"));
    }

    // The pieces on the pan end with the station: under the world's transient entity they would outlive it.
    UFUNCTION()
    private void OnSearingBeginDestroy(FCk_Handle InSearing)
    {
        auto SearingEntity = InSearing;
        if (SearingEntity.Has_Fragment(FMars_Fragment_Searing) == false)
        { return; }

        const auto State = SearingEntity.Get_Fragment(FMars_Fragment_Searing);
        auto Destroyed = 0;
        for (const auto& Piece : State.Pieces)
        {
            if (Get_IsGone(Piece.Piece))
            { continue; }

            utils_entity_lifetime::Request_DestroyEntity(Piece.Entity);
            ++Destroyed;
        }

        ck::Trace(f"[Searing] [{SearingEntity.ToString()}] destroyed: {Destroyed} piece(s) destroyed with it");
    }
}
