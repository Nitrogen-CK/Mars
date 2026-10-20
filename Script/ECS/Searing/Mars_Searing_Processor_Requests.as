// One release's answer, broadcast after the whole drain applied.
struct FMars_Searing_AdmissionResult
{
    FMars_CookingFeed_PieceId Id;
    EMars_CookingFeed_Admission Admission = EMars_CookingFeed_Admission::Rejected;
    // Rejected only: why, and the kernel's own words for it (the station's OnAdmission carries the words).
    EMars_Searing_AdmissionRefusal Refusal = EMars_Searing_AdmissionRefusal::Unavailable;
    FString Reason;
    // Accepted only: the adopted piece's entity.
    FCk_Handle Entity;
}

// One piece a Readopt put back on the books, broadcast after the drain's take-outs.
struct FMars_Searing_ReadoptResult
{
    FMars_CookingFeed_PieceId Id;
    FCk_Handle Entity;
    EMars_Searing_PieceStatus Status = EMars_Searing_PieceStatus::Cooking;
}

// Drains Reset -> SetHeat -> TakeOut (the station's take-outs after the pan's own) -> Readopt -> the station inbox's
// releases -> Look. Reset resets the pan, chills it and zeroes the tally, and keeps every piece with its sear; SetHeat is
// last-wins and drives the pan (Driven while hot); TakeOut hands pieces back with their cook state written and their bodies
// Kinematic, each onto the request's tray (the station's take-out contract) or to the caller, and one that hands none back
// is refused (NoRoom under a cap of zero or with no tray named by the station, else NothingReady); Readopt puts a
// handed-back piece nobody took back on the books where it lies; each release in the inbox is adopted or rejected (a cold
// pan accepts; every one in a drain that also reset is rejected: the release belongs to the attempt the reset ended);
// looks are forwarded to the pan while it is hot. The pan feature measures the looks in its Tick. The heat edge, then
// every take-out and every refused take-out, then OnPieceAdded for every readopted piece (and OnPieceReady for one
// readopted Ready), then every admission answer on the station's OnAdmission (and OnPieceAdded for an accepted one,
// OnAdmissionRefused for a rejected one) are broadcast last.
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

        TArray<FMars_CookingFeed_TakeOutResult> TakenOut;
        TArray<EMars_CookingFeed_TakeOutRefusal> TakeOutRefusals;
        for (const auto& Request : TakeOutRequests)
        {
            const auto Taken = Apply_TakeOut(Self, InState, Request);
            if (Taken.Num() == 0)
            { TakeOutRefusals.Add(utils_cooking_feed::Get_TakeOutRefusal(Request.MaxPieces)); }

            utils_cooking_feed::Land_OnTray(Self, Request.Tray, Taken);
            if (Taken.Num() > 0 && ck::IsValid(Request.Tray))
            { Watch_Tray(Request.Tray); }

            TakenOut.Append(Taken);
        }

        TArray<FMars_Searing_ReadoptResult> Readopted;
        for (const auto& Request : ReadoptRequests)
        {
            const auto Result = Apply_Readopt(Self, InState, Request);
            if (Result.IsSet())
            { Readopted.Add(Result.GetValue()); }
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

        for (const auto& Result : Readopted)
        {
            if (Self.Has_Fragment(FMars_Fragment_Searing_Signals))
            { Self.Get_Fragment(FMars_Fragment_Searing_Signals).OnPieceAdded.Broadcast(Self, Result.Id, Result.Entity); }

            if (Result.Status == EMars_Searing_PieceStatus::Ready && Self.Has_Fragment(FMars_Fragment_Searing_Signals))
            { Self.Get_Fragment(FMars_Fragment_Searing_Signals).OnPieceReady.Broadcast(Self, Result.Id, Tally); }
        }

        FCk_Handle Station = Self;
        for (const auto& Result : Admissions)
        {
            utils_cooking_feed::Broadcast_Admission(Station, FMars_CookingFeed_AdmissionAnswer(Result.Id, Result.Admission, Result.Reason));
            if (Self.Has_Fragment(FMars_Fragment_Searing_Signals) == false)
            { continue; }

            if (Result.Admission == EMars_CookingFeed_Admission::Accepted)
            { Self.Get_Fragment(FMars_Fragment_Searing_Signals).OnPieceAdded.Broadcast(Self, Result.Id, Result.Entity); }
            else
            { Self.Get_Fragment(FMars_Fragment_Searing_Signals).OnAdmissionRefused.Broadcast(Self, Result.Id, Result.Refusal); }
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
        const auto MaxPieces = utils_cooking_feed::Get_StationTakeOutCap(InTakeOut);
        return FMars_Request_Searing_TakeOut(TOptional<FCk_Handle_FoodPiece>(), TOptional<int32>(MaxPieces), InTakeOut.Tray);
    }

    // Unset Piece: every Ready piece, in admission order; set: that piece while it is on the pan and not lost. MaxPieces caps
    // either. Each one leaves the books with its cook state written onto the piece, its body Kinematic (a platter takes it
    // next) and its holder fact gone; its Resting stays for whoever adopts it next to retarget.
    private TArray<FMars_CookingFeed_TakeOutResult> Apply_TakeOut(FCk_Handle_Searing& InSearing, FMars_Fragment_Searing& InState,
        const FMars_Request_Searing_TakeOut& InRequest)
    {
        TArray<FMars_CookingFeed_TakeOutResult> Taken;
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
            Taken.Add(FMars_CookingFeed_TakeOutResult(Piece.Id, Piece.Piece));
        }

        InState.Pieces = Kept;
        InState.Tally.TakenOut += Taken.Num();

        return Taken;
    }

    private bool Get_IsTakeable(const FMars_Searing_PieceState& InPiece, const FMars_Request_Searing_TakeOut& InRequest) const
    {
        if (InPiece.Piece.Get_IsGone())
        { return false; }

        if (InRequest.Piece.IsSet())
        { return InPiece.Piece == InRequest.Piece.GetValue() && InPiece.Status != EMars_Searing_PieceStatus::Lost; }

        return InPiece.Status == EMars_Searing_PieceStatus::Ready;
    }

    private void Hand_Back(const FCk_Handle_Searing& InSearing, const FMars_Searing_PieceState& InPiece)
    {
        auto Piece = InPiece.Piece;
        Piece.Request_SetCookState(FMars_Request_FoodPiece_SetCookState(utils_searing::Get_CookState(InPiece, Piece.Get_CookState())));

        auto Body = InPiece.Body;
        utils_jolt_body::Request_SetMotionType(Body, FCk_Request_JoltBody_SetMotionType(ECk_MotionType::Kinematic));
        utils_foodpiece::Clear_Holder(Piece, InSearing);
    }

    // A handed-back piece nobody took, back on the books where it lies (it is not moved): the record rebuilt from the piece
    // (the take-out wrote its sear into its cook state), its resting face from its pose, its body Dynamic again, its Resting
    // on the pan, its holder fact and its pickup's Ledger claim the pan's. The take-out it undoes leaves the tally; it may
    // take the pan past Supply.MaxPieces (it was already the pan's). Unset when it is not readopted: a piece gone, or that
    // another ledger holds by now, is left alone; one attached somewhere stays there with its claim released.
    private TOptional<FMars_Searing_ReadoptResult> Apply_Readopt(FCk_Handle_Searing& InSearing, FMars_Fragment_Searing& InState,
        const FMars_Request_Searing_Readopt& InRequest)
    {
        auto Piece = InRequest.Piece;
        const auto PieceName = utils_cooking_feed::Get_PieceName(InRequest.PieceId);
        const auto Gate = utils_cooking_feed::Get_ReadoptGate(InSearing, Piece);
        if (Gate == EMars_CookingFeed_ReadoptGate::Attached)
        { utils_world_item::Request_ClaimPickup(Piece, EMars_Interactable_DisableReason::Ledger, ECk_EnableDisable::Enable); }

        if (Gate != EMars_CookingFeed_ReadoptGate::Readopt)
        { return TOptional<FMars_Searing_ReadoptResult>(); }

        FCk_Handle Entity = Piece;
        const auto IsOnBooks = utils_searing::Find_PieceIndexByHandle(InState.Pieces, Piece) >= 0
            || utils_searing::Find_PieceIndex(InState.Pieces, InRequest.PieceId) >= 0;
        if (ck::EnsureIfNot(IsOnBooks == false, f"[Searing] [{InSearing.ToString()}] was asked to readopt piece {PieceName} [{Piece.ToString()}], which it already holds"))
        { return TOptional<FMars_Searing_ReadoptResult>(); }

        if (ck::EnsureIfNot(Entity.Is_JoltBody(), f"[Searing] [{InSearing.ToString()}] was asked to readopt piece {PieceName} [{Piece.ToString()}], which has no body: it handed back only bodied pieces"))
        {
            utils_world_item::Request_ClaimPickup(Piece, EMars_Interactable_DisableReason::Ledger, ECk_EnableDisable::Enable);
            return TOptional<FMars_Searing_ReadoptResult>();
        }

        auto Body = Entity.As_JoltBody();
        utils_jolt_body::Request_SetMotionType(Body, FCk_Request_JoltBody_SetMotionType(ECk_MotionType::Dynamic));

        const auto PieceWorld = utils_transform::Get_EntityCurrentTransform(Entity.As_Transform());
        auto State = Make_PieceState(InRequest.PieceId, Piece);
        State.Body = Body;
        State.RestingFace = utils_foodpiece::Get_DownFace(PieceWorld.GetRotation(), InSearing.Get_PanUp());

        InState.Tally.TakenOut = Math::Max(0, InState.Tally.TakenOut - 1);
        Take_OnBooks(InSearing, InState, State);

        auto Result = FMars_Searing_ReadoptResult();
        Result.Id = State.Id;
        Result.Entity = Entity;
        Result.Status = State.Status;
        return TOptional<FMars_Searing_ReadoptResult>(Result);
    }

    // Adopted: the released piece (Release.Piece, Ready, held by no other ledger and on no scene node) moves to the release
    // pose, flat as released (NegZ is its resting face), with a dynamic body moving at the release's velocities and a
    // Resting on the pan base body (which tells whether it lies on the pan); its sear is seeded from its cook state; the
    // pan stamps it with the holder fact and its pickup's Ledger claim. It starts Airborne and becomes OnPan once it rests on
    // the base. Rejected: the piece is left as it was, the refusal naming the gate.
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
        else if (Piece.Get_IsGone())
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
        {
            Result.Refusal = EMars_Searing_AdmissionRefusal::Full;
            Result.Reason = f"the pan already holds Supply.MaxPieces [{Spec.Supply.MaxPieces}] pieces";
        }

        if (Result.Reason.Len() > 0)
        { return Result; }

        const auto Body = utils_cooking_feed::Adopt_Body(Piece, InRelease, Make_BodySurface(Spec.Piece));
        auto State = Make_PieceState(InRelease.PieceId, Piece);
        State.Body = Body;
        State.Arriving = TOptional<FVector>(InRelease.WorldTransform.GetLocation());
        Take_OnBooks(InSearing, InState, State);

        Result.Admission = EMars_CookingFeed_Admission::Accepted;
        Result.Entity = Entity;
        return Result;
    }

    // The record Add and Readopt share, its body still to set: the piece's geometry read once from its mesh's metrics, its
    // sear seeded from its cook state (a face seared elsewhere arrives seared; a piece seared all round arrives Ready). Its
    // batter is not sear: a fried face arrives raw to the pan, and keeps its batter in the ledger.
    private FMars_Searing_PieceState Make_PieceState(const FMars_CookingFeed_PieceId& InPieceId, const FCk_Handle_FoodPiece& InPiece) const
    {
        FCk_Handle Entity = InPiece;
        const auto Metrics = utils_runtime_mesh::Get_Metrics(InPiece.Get_Geometry());
        auto State = FMars_Searing_PieceState();
        State.Id = InPieceId;
        State.Piece = InPiece;
        State.Entity = Entity;
        State.CentreLocal = utils_foodpiece::Get_BoundsCentre(Metrics);
        State.HalfExtents = utils_foodpiece::Get_BoundsHalfExtents(Metrics);
        State.FaceSear = utils_cooking_feed::Seed_Faces(InPiece.Get_CookState().Sear, 1.0f);
        if (utils_searing::Get_SearedFaceCount(State.FaceSear) >= utils_searing::k_FaceCount)
        { State.Status = EMars_Searing_PieceStatus::Ready; }

        return State;
    }

    // InPiece on the books (its body set): its Resting pointed at the pan base body (which tells whether it lies on the pan),
    // the holder fact and its pickup's Ledger claim the pan's, and the pan's own teardown watched.
    private void Take_OnBooks(FCk_Handle_Searing& InSearing, FMars_Fragment_Searing& InState, const FMars_Searing_PieceState& InPiece)
    {
        const auto Spec = InSearing.Get_Spec();
        auto Entity = InPiece.Entity;
        utils_cooking_feed::Rest_On(Entity,
            FMars_Resting_Spec(Spec.Nodes.PanBaseBody, Spec.Piece.ContactGraceSeconds, utils_cooking_feed::k_PieceHopMinSeconds));

        auto Piece = InPiece.Piece;
        InState.Pieces.Add(InPiece);
        utils_foodpiece::Stamp_Holder(Piece, InSearing);
        utils_world_item::Request_ClaimPickup(Piece, EMars_Interactable_DisableReason::Ledger, ECk_EnableDisable::Disable);
        Watch_Teardown(InSearing);
    }

    private FMars_CookingFeed_BodySurface Make_BodySurface(const FMars_Searing_PieceSpec& InSpec) const
    {
        auto Surface = FMars_CookingFeed_BodySurface();
        Surface.Friction = InSpec.Friction;
        Surface.Restitution = InSpec.Restitution;
        Surface.LinearDamping = InSpec.LinearDamping;
        Surface.AngularDamping = InSpec.AngularDamping;
        return Surface;
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
            if (Piece.Piece.Get_IsGone())
            { continue; }

            utils_entity_lifetime::Request_DestroyEntity(Piece.Entity);
        }
    }
}
