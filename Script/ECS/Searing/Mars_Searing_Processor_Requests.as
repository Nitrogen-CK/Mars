// One release's answer, broadcast after the whole drain applied.
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

// Drains Reset -> SetHeat -> TakeOut (the station's take-outs after the pan's own) -> Readopt -> the station inbox's
// releases -> Look. Reset resets the pan, chills it and zeroes the tally, and keeps every piece with its sear; SetHeat is
// last-wins and drives the pan (Driven while hot); TakeOut hands pieces back with their cook state written and their bodies
// Kinematic, each onto the request's tray (the station's take-out contract) or to the caller, and one that hands none back
// is refused (NoRoom under a cap of zero or with no tray named by the station, else NothingReady); Readopt puts a
// handed-back piece nobody took back on the books where it lies; each release in the inbox is adopted or rejected (a cold
// pan accepts; every one in a drain that also reset is rejected: the release belongs to the attempt the reset ended);
// looks are forwarded to the pan while it is hot. The pan feature measures the looks in its Tick. The heat edge, then
// every take-out and every refused take-out, then OnPieceReady for a piece readopted Ready, then every admission answer on
// the station's OnAdmission (and OnPieceAdded for an accepted one) are broadcast last.
//
// A piece is the kernel's guest: the kernel creates no entity, and a piece it holds ends only lost (the Tick) or with the
// station (OnSearingBeginDestroy). The pan is the one owner of its pieces' lease facts: it stamps every piece it takes on
// with the holder fact and its pickup's Ledger claim, removes the holder when it hands the piece back, and releases the
// claim when the piece lands on its tray (or at once when the take-out named none); a tray's refusal readopts the piece.
//
// It also listens: the station's queue (OnQueued wakes this drain) and the answers of every tray it loads (OnLoaded,
// OnLoadRefused).
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
        TArray<FMars_Request_Searing_Readopt> ReadoptRequests = InRequests.ReadoptRequests;
        TArray<FMars_Request_Searing_Look> LookRequests = InRequests.LookRequests;

        // InRequests is invalid past this line; removing before broadcasting lets re-entrant requests survive.
        Self.Request_TryRemove(FMars_Fragment_Searing_Requests);

        Watch_Station(Self);
        TArray<FMars_CookingFeed_Release> Inbox = utils_cooking_feed::Take_Inbox(InHandle);
        TArray<FMars_Request_StationTakeOut> StationTakeOuts = utils_cooking_feed::Take_TakeOutRequests(InHandle);
        for (const auto& TakeOut : StationTakeOuts)
        { TakeOutRequests.Add(Make_TakeOut(TakeOut)); }

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
        TArray<EMars_CookingFeed_TakeOutRefusal> TakeOutRefusals;
        for (const auto& Request : TakeOutRequests)
        {
            const auto Taken = Apply_TakeOut(Self, InState, Request);
            if (Taken.Num() == 0)
            { TakeOutRefusals.Add(Get_TakeOutRefusal(Request)); }

            Land(Self, Request, Taken);
            TakenOut.Append(Taken);
        }

        TArray<FMars_CookingFeed_PieceId> ReadoptedReady;
        for (const auto& Request : ReadoptRequests)
        {
            const auto Status = Apply_Readopt(Self, InState, Request);
            if (Status.IsSet() && Status.GetValue() == EMars_Searing_PieceStatus::Ready)
            { ReadoptedReady.Add(Request.PieceId); }
        }

        TArray<FMars_Searing_AdmissionResult> Admissions;
        for (const auto& Release : Inbox)
        {
            if (HasReset)
            { Admissions.Add(Reject_InResetDrain(Self, Release)); }
            else
            { Admissions.Add(Apply_AddPiece(Self, InState, Release)); }
        }

        if (NewHeat == EMars_Searing_Heat::Hot)
        {
            for (const auto& Request : LookRequests)
            { Pan.Request_Look(FMars_Request_Implement_Look(Request.LookDelta)); }
        }

        const auto Tally = InState.Tally;
        if (NewHeat != StartHeat && Self.Has_Fragment(FMars_Fragment_Searing_Signals))
        { Self.Get_Fragment(FMars_Fragment_Searing_Signals).OnHeatChanged.Broadcast(Self, NewHeat); }

        for (const auto& Result : TakenOut)
        {
            if (Self.Has_Fragment(FMars_Fragment_Searing_Signals))
            { Self.Get_Fragment(FMars_Fragment_Searing_Signals).OnPieceTakenOut.Broadcast(Self, Result.Id, Result.Piece); }
        }

        for (const auto Refusal : TakeOutRefusals)
        {
            if (Self.Has_Fragment(FMars_Fragment_Searing_Signals))
            { Self.Get_Fragment(FMars_Fragment_Searing_Signals).OnTakeOutRefused.Broadcast(Self, Refusal); }
        }

        for (const auto& PieceId : ReadoptedReady)
        {
            if (Self.Has_Fragment(FMars_Fragment_Searing_Signals))
            { Self.Get_Fragment(FMars_Fragment_Searing_Signals).OnPieceReady.Broadcast(Self, PieceId, Tally); }
        }

        FCk_Handle Station = Self;
        for (const auto& Result : Admissions)
        {
            utils_cooking_feed::Broadcast_Admission(Station, FMars_CookingFeed_AdmissionAnswer(Result.Id, Result.Admission, Result.Reason));
            if (Result.Admission == EMars_CookingFeed_Admission::Accepted && Self.Has_Fragment(FMars_Fragment_Searing_Signals))
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
    }

    private FMars_Searing_AdmissionResult Reject_InResetDrain(FCk_Handle_Searing& InSearing, const FMars_CookingFeed_Release& InRelease)
    {
        auto Result = FMars_Searing_AdmissionResult();
        Result.Id = InRelease.PieceId;
        Result.Reason = "reset in the same drain";
        return Result;
    }

    // A station take-out is the pan's own TakeOut onto its tray, capped at the room the press read: no tray caps it at none.
    private FMars_Request_Searing_TakeOut Make_TakeOut(const FMars_Request_StationTakeOut& InTakeOut) const
    {
        const auto MaxPieces = ck::IsValid(InTakeOut.Tray) ? InTakeOut.MaxPieces : 0;
        return FMars_Request_Searing_TakeOut(TOptional<FCk_Handle_FoodPiece>(), TOptional<int32>(MaxPieces), InTakeOut.Tray);
    }

    // Unset Piece: every Ready piece, in admission order; set: that piece while it is on the pan and not lost. MaxPieces caps
    // either. Each one leaves the books with its cook state written onto the piece, its body Kinematic (a platter takes it
    // next) and its holder fact gone; its Resting stays for whoever adopts it next to retarget.
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

            Hand_Back(InSearing, Piece);

            auto Result = FMars_Searing_TakeOutResult();
            Result.Id = Piece.Id;
            Result.Piece = Piece.Piece;
            Taken.Add(Result);
        }

        InState.Pieces = Kept;
        InState.Tally.TakenOut += Taken.Num();

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

    // Why a take-out took nothing: a cap of zero left no room (no tray docked, or a full one), else nothing was takeable.
    private EMars_CookingFeed_TakeOutRefusal Get_TakeOutRefusal(const FMars_Request_Searing_TakeOut& InRequest) const
    {
        if (InRequest.MaxPieces.IsSet() && InRequest.MaxPieces.GetValue() <= 0)
        { return EMars_CookingFeed_TakeOutRefusal::NoRoom; }

        return EMars_CookingFeed_TakeOutRefusal::NothingReady;
    }

    private void Hand_Back(const FCk_Handle_Searing& InSearing, const FMars_Searing_PieceState& InPiece)
    {
        auto Piece = InPiece.Piece;
        Piece.Request_SetCookState(FMars_Request_FoodPiece_SetCookState(utils_searing::Get_CookState(InPiece, Piece.Get_CookState())));

        auto Body = InPiece.Body;
        utils_jolt_body::Request_SetMotionType(Body, FCk_Request_JoltBody_SetMotionType(ECk_MotionType::Kinematic));
        utils_foodpiece::Clear_Holder(Piece, InSearing);
    }

    // Every piece a take-out handed back goes onto the request's tray (detached first, its landing watched: its Ledger claim
    // stays the pan's until it lands), else to the caller, its claim released.
    private void Land(const FCk_Handle_Searing& InSearing, const FMars_Request_Searing_TakeOut& InRequest,
        const TArray<FMars_Searing_TakeOutResult>& InTaken)
    {
        for (const auto& Result : InTaken)
        {
            auto Piece = Result.Piece;
            if (ck::IsValid(InRequest.Tray))
            { utils_cooking_feed::Send_ToTray(Piece, FMars_Fragment_StationLanding(InSearing, Result.Id, InRequest.Tray)); }
            else
            { utils_world_item::Request_ClaimPickup(Piece, EMars_Interactable_DisableReason::Ledger, ECk_EnableDisable::Enable); }
        }

        if (InTaken.Num() > 0 && ck::IsValid(InRequest.Tray))
        { Watch_Tray(InRequest.Tray); }
    }

    // A handed-back piece nobody took, back on the books where it lies (it is not moved): the record rebuilt from the piece
    // (the take-out wrote its sear into its cook state), its body Dynamic again, its Resting on the pan, its holder fact and
    // its pickup's Ledger claim the pan's. The take-out it undoes leaves the tally. Unset when it is not readopted (a piece
    // gone, attached, or that another ledger holds by now).
    private TOptional<EMars_Searing_PieceStatus> Apply_Readopt(FCk_Handle_Searing& InSearing, FMars_Fragment_Searing& InState,
        const FMars_Request_Searing_Readopt& InRequest)
    {
        auto Piece = InRequest.Piece;
        const auto PieceName = utils_cooking_feed::Get_PieceName(InRequest.PieceId);
        if (Get_IsGone(Piece))
        { return TOptional<EMars_Searing_PieceStatus>(); }

        FCk_Handle Entity = Piece;
        const auto Holder = Piece.TryGet_Holder();
        if ((ck::IsValid(Holder) && Holder != InSearing) || Entity.Is_SceneNode())
        { return TOptional<EMars_Searing_PieceStatus>(); }

        const auto IsOnBooks = utils_searing::Find_PieceIndexByHandle(InState.Pieces, Piece) >= 0
            || utils_searing::Find_PieceIndex(InState.Pieces, InRequest.PieceId) >= 0;
        if (ck::EnsureIfNot(IsOnBooks == false, f"[Searing] [{InSearing.ToString()}] was asked to readopt piece {PieceName} [{Piece.ToString()}], which it already holds"))
        { return TOptional<EMars_Searing_PieceStatus>(); }

        if (ck::EnsureIfNot(Entity.Is_JoltBody(), f"[Searing] [{InSearing.ToString()}] was asked to readopt piece {PieceName} [{Piece.ToString()}], which has no body: it handed back only bodied pieces"))
        { return TOptional<EMars_Searing_PieceStatus>(); }

        const auto Spec = InSearing.Get_Spec();
        auto Body = Entity.As_JoltBody();
        utils_jolt_body::Request_SetMotionType(Body, FCk_Request_JoltBody_SetMotionType(ECk_MotionType::Dynamic));

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
        const auto PieceWorld = utils_transform::Get_EntityCurrentTransform(Entity.As_Transform());
        auto State = FMars_Searing_PieceState();
        State.Id = InRequest.PieceId;
        State.Piece = Piece;
        State.Entity = Entity;
        State.Body = Body;
        State.CentreLocal = utils_searing::Get_BoundsCentre(Metrics);
        State.HalfExtents = utils_searing::Get_BoundsHalfExtents(Metrics);
        State.RestingFace = utils_searing::Get_DownFace(PieceWorld.GetRotation(), InSearing.Get_PanUp());

        const auto CookState = Piece.Get_CookState();
        for (int32 Index = 0; Index < utils_searing::k_FaceCount; ++Index)
        { State.FaceSear.Add(CookState.Sear.IsValidIndex(Index) ? Math::Clamp(CookState.Sear[Index], 0.0f, 1.0f) : 0.0f); }

        if (utils_searing::Get_SearedFaceCount(State.FaceSear) >= utils_searing::k_FaceCount)
        { State.Status = EMars_Searing_PieceStatus::Ready; }

        InState.Pieces.Add(State);
        InState.Tally.TakenOut = Math::Max(0, InState.Tally.TakenOut - 1);
        utils_foodpiece::Stamp_Holder(Piece, InSearing);
        utils_world_item::Request_ClaimPickup(Piece, EMars_Interactable_DisableReason::Ledger, ECk_EnableDisable::Disable);
        Watch_Teardown(InSearing);

        return TOptional<EMars_Searing_PieceStatus>(State.Status);
    }

    // Adopted: the released piece (Release.Piece, Ready, held by no other ledger and on no scene node) moves to the release
    // pose, flat as released (NegZ is its resting face), with a dynamic body moving at the release's velocities and a
    // Resting on the pan base body (which tells whether it lies on the pan); its sear is seeded from its cook state; the
    // pan stamps it with the holder fact and its pickup's Ledger claim. It starts Airborne and becomes OnPan once it rests on
    // the base. Rejected: the piece is left as it was.
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
        else if (ck::IsValid(Piece.TryGet_Holder()))
        { Result.Reason = "another ledger holds it"; }
        else if (Entity.Is_SceneNode())
        { Result.Reason = "still attached"; }
        else if (utils_searing::Get_LivePieceCount(InState.Pieces) >= Spec.Supply.MaxPieces)
        { Result.Reason = f"the pan already holds Supply.MaxPieces [{Spec.Supply.MaxPieces}] pieces"; }

        if (Result.Reason.Len() > 0)
        { return Result; }

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

        // A face seared elsewhere arrives seared; a piece seared all round arrives Ready. Its batter is not sear: a fried face
        // arrives raw to the pan, and keeps its batter in the ledger.
        const auto Seed = Piece.Get_CookState();
        for (int32 Index = 0; Index < utils_searing::k_FaceCount; ++Index)
        { State.FaceSear.Add(Seed.Sear.IsValidIndex(Index) ? Math::Clamp(Seed.Sear[Index], 0.0f, 1.0f) : 0.0f); }

        if (utils_searing::Get_SearedFaceCount(State.FaceSear) >= utils_searing::k_FaceCount)
        { State.Status = EMars_Searing_PieceStatus::Ready; }

        InState.Pieces.Add(State);
        utils_foodpiece::Stamp_Holder(Piece, InSearing);
        utils_world_item::Request_ClaimPickup(Piece, EMars_Interactable_DisableReason::Ledger, ECk_EnableDisable::Disable);
        Watch_Teardown(InSearing);

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

    // Unbinding first keeps the watch single across drains: the station's queue wakes this drain.
    private void Watch_Station(const FCk_Handle_Searing& InSearing)
    {
        FCk_Handle Station = InSearing;
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

    // A live pan's station: a landing whose pan is gone has nothing to go back to.
    private bool Get_IsSearing(const FCk_Handle& InStation) const
    {
        return ck::IsValid(InStation)
            && utils_entity_lifetime::Get_IsPendingDestroy(InStation, ECk_EntityLifetime_DestructionPhase::BeginDestroy) == false
            && InStation.Is_Searing();
    }

    // The station queued a release or a take-out: the pan drains it this frame.
    UFUNCTION()
    private void OnStationQueued(FCk_Handle InStation)
    {
        auto Station = InStation;
        if (Station.Is_Searing())
        { Station.AddOrGet_Fragment(FMars_Fragment_Searing_Requests); }
    }

    // A piece the pan handed to a tray landed there: the tray holds it now, and its pickup's Ledger claim goes.
    UFUNCTION()
    private void OnTrayLoaded(FCk_Handle_Platter InTray, FCk_Handle_FoodPiece InPiece)
    {
        const auto Landing = utils_cooking_feed::TryGet_Landing(InPiece, InTray);
        if (Landing.IsSet() == false || Get_IsSearing(Landing.GetValue().Station) == false)
        { return; }

        auto Piece = InPiece;
        utils_cooking_feed::Clear_Landing(Piece);
        utils_world_item::Request_ClaimPickup(Piece, EMars_Interactable_DisableReason::Ledger, ECk_EnableDisable::Enable);
    }

    // A piece the pan handed to a tray was refused: back on the pan's books where it lies.
    UFUNCTION()
    private void OnTrayLoadRefused(FCk_Handle_Platter InTray, FCk_Handle_FoodPiece InPiece, EMars_Platter_LoadRefusal InRefusal)
    {
        const auto Landing = utils_cooking_feed::TryGet_Landing(InPiece, InTray);
        if (Landing.IsSet() == false || Get_IsSearing(Landing.GetValue().Station) == false)
        { return; }

        auto Piece = InPiece;
        utils_cooking_feed::Clear_Landing(Piece);
        auto Station = Landing.GetValue().Station;
        auto Searing = Station.As_Searing();
        Searing.Request_Readopt(FMars_Request_Searing_Readopt(Landing.GetValue().PieceId, Piece));
    }

    // The pieces on the pan end with the station: under the world's transient entity they would outlive it.
    UFUNCTION()
    private void OnSearingBeginDestroy(FCk_Handle InSearing)
    {
        auto SearingEntity = InSearing;
        if (SearingEntity.Has_Fragment(FMars_Fragment_Searing) == false)
        { return; }

        const auto State = SearingEntity.Get_Fragment(FMars_Fragment_Searing);
        for (const auto& Piece : State.Pieces)
        {
            if (Get_IsGone(Piece.Piece))
            { continue; }

            utils_entity_lifetime::Request_DestroyEntity(Piece.Entity);
        }
    }
}
