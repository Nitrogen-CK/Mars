// One release's answer, broadcast after the whole drain applied.
struct FMars_Batter_AdmissionResult
{
    FMars_CookingFeed_PieceId Id;
    EMars_CookingFeed_Admission Admission = EMars_CookingFeed_Admission::Rejected;
    // Rejected only: why, and the kernel's own words for it (the station's OnAdmission carries the words).
    EMars_Batter_AdmissionRefusal Refusal = EMars_Batter_AdmissionRefusal::Unavailable;
    FString Reason;
    // Accepted only: the adopted piece's entity.
    FCk_Handle Entity;
}

// What one drain broadcasts once it applied: the bowl it started from (the edge), its take-outs and refused take-outs, the
// pieces it readopted, and its admission answers.
struct FMars_Batter_DrainEdges
{
    EMars_Batter_Bowl StartBowl = EMars_Batter_Bowl::Resting;
    TArray<FMars_CookingFeed_TakeOutResult> TakenOut;
    TArray<EMars_Batter_TakeOutRefusal> TakeOutRefusals;
    TArray<FMars_Batter_PieceState> Readopted;
    TArray<FMars_Batter_AdmissionResult> Admissions;
}

// Drains Reset -> Lift -> the station's take-outs -> Readopt -> the station inbox's releases -> Dip (see
// FMars_Fragment_Batter_Requests). Reset destroys every piece in the bowl and lifts it; Lift brings the pieces back up (their
// coats kept); a take-out hands back every fully coated piece lifted back to rest up to its cap, its ledger battered (Battered = 1, through the
// FoodPiece request), detached and onto the take-out's tray, and one that hands none back is refused (NoRoom under a cap of
// zero or with no tray, Empty with nothing in the bowl, StillInTheBatter for a coated piece not lifted yet, else
// CoatIncomplete); Readopt puts a handed-back piece its tray refused back at a free slot; each release in the station's
// inbox is adopted or rejected with a reason (NotWhole, NotBatterable, AlreadyBattered, Full, or the identity and readiness
// gates); Dip holds the pieces under. The bowl edge, every take-out and refused take-out, then OnPieceAdded for every
// readopted piece, then every admission answer on the station's OnAdmission (and OnPieceAdded or OnAdmissionRefused) are
// broadcast last. The drain decides and the Tick moves: nothing here integrates over time.
//
// A piece is the bowl's guest: the kernel creates no entity, and a piece it holds ends only with a Reset or with the station
// (OnBatterBeginDestroy). The bowl is the one owner of its pieces' lease facts: it stamps every piece it takes on with the
// holder fact and its pickup's Ledger claim, removes the holder when it hands the piece back, and releases the claim when the
// piece lands on its tray; a tray's refusal readopts the piece. It also listens: the station's queue (OnQueued wakes this
// drain) and the answers of every tray it loads.
class UMars_Processor_Batter_HandleRequests : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _MarkedDirtyBy = FMars_Fragment_Batter_Requests;

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_Batter);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle,
                       FMars_Fragment_Batter_Requests& InRequests,
                       FMars_Fragment_Batter& InState)
    {
        auto Self = InHandle.As_Batter();

        const auto HasReset = InRequests.ResetRequests.Num() > 0;
        const auto HasLift = InRequests.LiftRequests.Num() > 0;
        const auto HasDip = InRequests.DipRequests.Num() > 0;
        TArray<FMars_Request_Batter_Readopt> ReadoptRequests = InRequests.ReadoptRequests;

        // InRequests is invalid past this line; removing before broadcasting lets re-entrant requests survive.
        Self.Request_TryRemove(FMars_Fragment_Batter_Requests);

        Watch_Station(Self);
        TArray<FMars_CookingFeed_Release> Inbox = utils_cooking_feed::Take_Inbox(InHandle);
        TArray<FMars_Request_StationTakeOut> TakeOuts = utils_cooking_feed::Take_TakeOutRequests(InHandle);

        auto Edges = FMars_Batter_DrainEdges();
        Edges.StartBowl = InState.Bowl;

        if (HasReset)
        { Apply_Reset(InState); }

        if (HasLift)
        { InState.Bowl = EMars_Batter_Bowl::Resting; }

        for (const auto& TakeOut : TakeOuts)
        { Apply_TakeOut(Self, InState, TakeOut, Edges); }

        for (const auto& Request : ReadoptRequests)
        {
            const auto Readopt = Apply_Readopt(Self, InState, Request);
            if (Readopt.IsSet())
            { Edges.Readopted.Add(Readopt.GetValue()); }
        }

        for (const auto& Release : Inbox)
        { Edges.Admissions.Add(Apply_AddPiece(Self, InState, Release)); }

        if (HasDip)
        { InState.Bowl = EMars_Batter_Bowl::Dipped; }

        Broadcast(Self, InState, Edges);
    }

    private void Broadcast(FCk_Handle_Batter& InBatter, const FMars_Fragment_Batter& InState, const FMars_Batter_DrainEdges& InEdges)
    {
        const auto Bowl = InState.Bowl;
        if (Bowl != InEdges.StartBowl && InBatter.Has_Fragment(FMars_Fragment_Batter_Signals))
        { InBatter.Get_Fragment(FMars_Fragment_Batter_Signals).OnBowlChanged.Broadcast(InBatter, Bowl); }

        for (const auto& Result : InEdges.TakenOut)
        {
            if (InBatter.Has_Fragment(FMars_Fragment_Batter_Signals))
            { InBatter.Get_Fragment(FMars_Fragment_Batter_Signals).OnPieceTakenOut.Broadcast(InBatter, Result.Id, Result.Piece); }
        }

        for (const auto Refusal : InEdges.TakeOutRefusals)
        {
            if (InBatter.Has_Fragment(FMars_Fragment_Batter_Signals))
            { InBatter.Get_Fragment(FMars_Fragment_Batter_Signals).OnTakeOutRefused.Broadcast(InBatter, Refusal); }
        }

        for (const auto& Piece : InEdges.Readopted)
        {
            if (InBatter.Has_Fragment(FMars_Fragment_Batter_Signals))
            { InBatter.Get_Fragment(FMars_Fragment_Batter_Signals).OnPieceAdded.Broadcast(InBatter, Piece.Id, Piece.Entity); }
        }

        FCk_Handle Station = InBatter;
        for (const auto& Result : InEdges.Admissions)
        {
            utils_cooking_feed::Broadcast_Admission(Station, FMars_CookingFeed_AdmissionAnswer(Result.Id, Result.Admission, Result.Reason));
            if (InBatter.Has_Fragment(FMars_Fragment_Batter_Signals) == false)
            { continue; }

            if (Result.Admission == EMars_CookingFeed_Admission::Accepted)
            { InBatter.Get_Fragment(FMars_Fragment_Batter_Signals).OnPieceAdded.Broadcast(InBatter, Result.Id, Result.Entity); }
            else
            { InBatter.Get_Fragment(FMars_Fragment_Batter_Signals).OnAdmissionRefused.Broadcast(InBatter, Result.Id, Result.Refusal); }
        }
    }

    // Every piece in the bowl is destroyed here, never left to the station's teardown alone.
    private void Apply_Reset(FMars_Fragment_Batter& InState)
    {
        for (const auto& Piece : InState.Pieces)
        {
            if (Piece.Piece.Get_IsGone() == false)
            { utils_entity_lifetime::Request_DestroyEntity(Piece.Entity); }
        }

        InState.Pieces.Empty();
        InState.Bowl = EMars_Batter_Bowl::Resting;
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Admission, take-out, readopt
    //----------------------------------------------------------------------------------------------------------------------

    // Adopted: the released piece (Release.Piece: Ready, held by no other ledger, on no scene node, whole, of a batterable
    // food and not battered yet) at the lowest free slot, attached under the bowl node at rest (its body, if any, Kinematic);
    // the bowl stamps it with the holder fact and its pickup's Ledger claim. Rejected: the piece is left as it was, the
    // refusal naming the gate.
    private FMars_Batter_AdmissionResult Apply_AddPiece(FCk_Handle_Batter& InBatter, FMars_Fragment_Batter& InState,
        const FMars_CookingFeed_Release& InRelease)
    {
        auto Result = FMars_Batter_AdmissionResult();
        Result.Id = InRelease.PieceId;

        const auto Spec = InBatter.Get_Spec();
        const auto PieceName = utils_cooking_feed::Get_PieceName(InRelease.PieceId);
        auto Piece = InRelease.Piece;
        FCk_Handle Entity = Piece;

        if (Piece.Get_IsGone())
        { Result.Reason = "no piece"; }
        else if (Piece.Get_Status() != EMars_FoodPiece_Status::Ready)
        { Result.Reason = "the piece is not ready"; }
        else if (utils_batter::Find_PieceIndexByHandle(InState.Pieces, Piece) >= 0)
        {
            Result.Refusal = EMars_Batter_AdmissionRefusal::Duplicate;
            Result.Reason = "already admitted";
        }
        else if (utils_batter::Find_PieceIndex(InState.Pieces, InRelease.PieceId) >= 0)
        {
            Result.Refusal = EMars_Batter_AdmissionRefusal::Duplicate;
            Result.Reason = f"piece {PieceName} is already in";
        }
        else if (ck::IsValid(Piece.TryGet_Holder()))
        { Result.Reason = "another ledger holds it"; }
        else if (Entity.Is_SceneNode())
        { Result.Reason = "still attached"; }

        if (Result.Reason.Len() > 0)
        { return Result; }

        const auto Refusal = utils_batter::Get_PieceRefusal(InState, Spec, Piece);
        if (Refusal.IsSet())
        {
            Result.Refusal = Refusal.GetValue();
            Result.Reason = Get_RefusalReason(Refusal.GetValue(), Spec);
            return Result;
        }

        Adopt(InBatter, InState, FMars_Batter_PieceState_Seed(InRelease.PieceId, Piece));

        Result.Admission = EMars_CookingFeed_Admission::Accepted;
        Result.Entity = Entity;
        return Result;
    }

    // The kernel's words for a piece-rule refusal (the station's OnAdmission carries them; the assembly says its own).
    private FString Get_RefusalReason(EMars_Batter_AdmissionRefusal InRefusal, const FMars_Batter_Spec& InSpec) const
    {
        if (InRefusal == EMars_Batter_AdmissionRefusal::NotWhole)
        { return "not whole: the bowl takes full ingredients only"; }

        if (InRefusal == EMars_Batter_AdmissionRefusal::NotBatterable)
        { return "not batterable: its food has no battered variant"; }

        if (InRefusal == EMars_Batter_AdmissionRefusal::AlreadyBattered)
        { return "already battered"; }

        return f"Capacity [{InSpec.Bowl.Capacity}] pieces are already in";
    }

    // InSeed's piece at the lowest free slot, at rest, attached under the bowl node (detached first if it hangs anywhere),
    // its body Kinematic, the holder fact and the Ledger claim the bowl's: the record it seated. Its coat is the seed's (0
    // for an admission: a piece is never admitted battered; 1 for a readopt, whose full coat its ledger already says).
    private FMars_Batter_PieceState Adopt(FCk_Handle_Batter& InBatter, FMars_Fragment_Batter& InState, const FMars_Batter_PieceState_Seed& InSeed)
    {
        const auto Spec = InBatter.Get_Spec();
        auto Piece = InSeed.Piece;
        FCk_Handle Entity = Piece;

        auto State = FMars_Batter_PieceState();
        State.Id = InSeed.Id;
        State.Piece = Piece;
        State.Entity = Entity;
        State.Slot = utils_batter::Get_FreeSlot(InState.Pieces, Spec.Bowl.Capacity);
        State.Coat = InSeed.Coat;
        State.Stage = utils_batter::Get_CoatStage(InSeed.Coat);

        auto Body = Entity.As_JoltBody(ECk_SanityCheck::UnChecked);
        if (ck::IsValid(Body))
        { utils_jolt_body::Request_SetMotionType(Body, FCk_Request_JoltBody_SetMotionType(ECk_MotionType::Kinematic)); }

        auto PieceTransform = Entity.As_Transform();
        auto BowlNode = Spec.Nodes.Bowl;
        utils_scene_node::Add(PieceTransform, BowlNode, utils_batter::Get_PieceOffset(Spec.Bowl, State));
        InState.Pieces.Add(State);

        utils_foodpiece::Stamp_Holder(Piece, InBatter);
        utils_world_item::Request_ClaimPickup(Piece, EMars_Interactable_DisableReason::Ledger, ECk_EnableDisable::Disable);
        Watch_Teardown(InBatter);
        return State;
    }

    // Every fully coated piece lifted back to rest, in admission order, up to the cap the press read (no tray caps it at
    // none): each leaves the bowl with its ledger battered and its holder fact gone, and goes onto the tray (its Ledger claim
    // stays the bowl's until it lands). One that hands none back is refused.
    private void Apply_TakeOut(FCk_Handle_Batter& InBatter, FMars_Fragment_Batter& InState,
        const FMars_Request_StationTakeOut& InTakeOut, FMars_Batter_DrainEdges& OutEdges)
    {
        const auto MaxPieces = ck::IsValid(InTakeOut.Tray) ? InTakeOut.MaxPieces : 0;

        TArray<FMars_CookingFeed_TakeOutResult> Taken;
        TArray<FMars_Batter_PieceState> Kept;
        for (const auto& Piece : InState.Pieces)
        {
            const auto IsTakeable = Piece.Piece.Get_IsGone() == false && utils_batter::Get_IsTakeable(Piece);
            if (Taken.Num() >= MaxPieces || IsTakeable == false)
            {
                Kept.Add(Piece);
                continue;
            }

            Hand_Back(InBatter, Piece);

            Taken.Add(FMars_CookingFeed_TakeOutResult(Piece.Id, Piece.Piece));
        }

        if (Taken.Num() == 0)
        {
            OutEdges.TakeOutRefusals.Add(Get_TakeOutRefusal(InState, MaxPieces));
            return;
        }

        InState.Pieces = Kept;
        for (const auto& Result : Taken)
        {
            auto Piece = Result.Piece;
            utils_cooking_feed::Send_ToTray(Piece, FMars_Fragment_StationLanding(InBatter, Result.Id, InTakeOut.Tray));
        }

        Watch_Tray(InTakeOut.Tray);
        OutEdges.TakenOut.Append(Taken);
    }

    private EMars_Batter_TakeOutRefusal Get_TakeOutRefusal(const FMars_Fragment_Batter& InState, int32 InMaxPieces) const
    {
        if (InMaxPieces <= 0)
        { return EMars_Batter_TakeOutRefusal::NoRoom; }

        if (InState.Pieces.Num() == 0)
        { return EMars_Batter_TakeOutRefusal::Empty; }

        for (const auto& Piece : InState.Pieces)
        {
            if (utils_batter::Get_IsCoated(Piece))
            { return EMars_Batter_TakeOutRefusal::StillInTheBatter; }
        }

        return EMars_Batter_TakeOutRefusal::CoatIncomplete;
    }

    // The dip enters the piece's ledger with the rest of its cook state as it is (the kernel's only ledger write).
    private void Hand_Back(const FCk_Handle_Batter& InBatter, const FMars_Batter_PieceState& InPiece)
    {
        auto Piece = InPiece.Piece;
        auto CookState = Piece.Get_CookState();
        CookState.Battered = 1.0f;
        Piece.Request_SetCookState(FMars_Request_FoodPiece_SetCookState(CookState));
        utils_foodpiece::Clear_Holder(Piece, InBatter);
    }

    // A handed-back piece its tray refused, back in the bowl at a free slot: fully coated (its ledger says battered), its
    // holder fact and its pickup's Ledger claim the bowl's: the record it seated. Unset when it is not readopted: a piece
    // gone, or that another ledger holds by now, is left alone; one attached somewhere stays there, and one the bowl has no
    // free slot left for (a release was admitted into the slot its take-out freed) ensures and lies where it is; both with
    // their pickup's Ledger claim released, so a hand can take them.
    private TOptional<FMars_Batter_PieceState> Apply_Readopt(FCk_Handle_Batter& InBatter, FMars_Fragment_Batter& InState,
        const FMars_Request_Batter_Readopt& InRequest)
    {
        auto Piece = InRequest.Piece;
        const auto PieceName = utils_cooking_feed::Get_PieceName(InRequest.PieceId);
        const auto Gate = utils_cooking_feed::Get_ReadoptGate(InBatter, Piece);
        if (Gate == EMars_CookingFeed_ReadoptGate::Attached)
        { utils_world_item::Request_ClaimPickup(Piece, EMars_Interactable_DisableReason::Ledger, ECk_EnableDisable::Enable); }

        if (Gate != EMars_CookingFeed_ReadoptGate::Readopt)
        { return TOptional<FMars_Batter_PieceState>(); }

        const auto IsInBowl = utils_batter::Find_PieceIndexByHandle(InState.Pieces, Piece) >= 0
            || utils_batter::Find_PieceIndex(InState.Pieces, InRequest.PieceId) >= 0;
        if (ck::EnsureIfNot(IsInBowl == false, f"[Batter] [{InBatter.ToString()}] was asked to readopt piece {PieceName} [{Piece.ToString()}], which it already holds"))
        { return TOptional<FMars_Batter_PieceState>(); }

        const auto Capacity = InBatter.Get_Spec().Bowl.Capacity;
        if (ck::EnsureIfNot(utils_batter::Get_FreeSlot(InState.Pieces, Capacity) >= 0,
            f"[Batter] [{InBatter.ToString()}] has no free slot to readopt piece {PieceName} [{Piece.ToString()}] ({InState.Pieces.Num()} of {Capacity} taken): it lies where its tray refused it"))
        {
            utils_world_item::Request_ClaimPickup(Piece, EMars_Interactable_DisableReason::Ledger, ECk_EnableDisable::Enable);
            return TOptional<FMars_Batter_PieceState>();
        }

        auto Seed = FMars_Batter_PieceState_Seed(InRequest.PieceId, Piece);
        Seed.Coat = 1.0f;
        return TOptional<FMars_Batter_PieceState>(Adopt(InBatter, InState, Seed));
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Watches
    //----------------------------------------------------------------------------------------------------------------------

    // Unbinding first keeps the watch single across admissions.
    private void Watch_Teardown(const FCk_Handle_Batter& InBatter)
    {
        FCk_Handle Batter = InBatter;
        Batter.UnbindFrom_OnBeginDestroy(FCk_Delegate_OnBeginDestroy(this, n"OnBatterBeginDestroy"));
        Batter.BindTo_OnBeginDestroy(FCk_Delegate_OnBeginDestroy(this, n"OnBatterBeginDestroy"));
    }

    // Unbinding first keeps the watch single across drains: the station's queue wakes this drain.
    private void Watch_Station(const FCk_Handle_Batter& InBatter)
    {
        FCk_Handle Station = InBatter;
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

    // A live bowl's station: a landing whose bowl is gone has nothing to go back to.
    private bool Get_IsBatter(const FCk_Handle& InStation) const
    {
        return ck::IsValid(InStation)
            && utils_entity_lifetime::Get_IsPendingDestroy(InStation, ECk_EntityLifetime_DestructionPhase::BeginDestroy) == false
            && InStation.Is_Batter();
    }

    // The station queued a release or a take-out: the bowl drains it this frame.
    UFUNCTION()
    private void OnStationQueued(FCk_Handle InStation)
    {
        auto Station = InStation;
        if (Station.Is_Batter())
        { Station.AddOrGet_Fragment(FMars_Fragment_Batter_Requests); }
    }

    // A piece the bowl handed to a tray landed there: the tray holds it now, and its pickup's Ledger claim goes.
    UFUNCTION()
    private void OnTrayLoaded(FCk_Handle_Platter InTray, FCk_Handle_FoodPiece InPiece)
    {
        const auto Landing = utils_cooking_feed::TryGet_Landing(InPiece, InTray);
        if (Landing.IsSet() == false || Get_IsBatter(Landing.GetValue().Station) == false)
        { return; }

        auto Piece = InPiece;
        utils_cooking_feed::Clear_Landing(Piece);
        utils_world_item::Request_ClaimPickup(Piece, EMars_Interactable_DisableReason::Ledger, ECk_EnableDisable::Enable);
    }

    // A piece the bowl handed to a tray was refused: back in the bowl.
    UFUNCTION()
    private void OnTrayLoadRefused(FCk_Handle_Platter InTray, FCk_Handle_FoodPiece InPiece, EMars_Platter_LoadRefusal InRefusal)
    {
        const auto Landing = utils_cooking_feed::TryGet_Landing(InPiece, InTray);
        if (Landing.IsSet() == false || Get_IsBatter(Landing.GetValue().Station) == false)
        { return; }

        auto Piece = InPiece;
        utils_cooking_feed::Clear_Landing(Piece);
        auto Station = Landing.GetValue().Station;
        auto Batter = Station.As_Batter();
        Batter.Request_Readopt(FMars_Request_Batter_Readopt(Landing.GetValue().PieceId, Piece));
    }

    // The pieces in the bowl end with the station: under the world's transient entity they would outlive it.
    UFUNCTION()
    private void OnBatterBeginDestroy(FCk_Handle InBatter)
    {
        auto BatterEntity = InBatter;
        if (BatterEntity.Has_Fragment(FMars_Fragment_Batter) == false)
        { return; }

        const auto State = BatterEntity.Get_Fragment(FMars_Fragment_Batter);
        for (const auto& Piece : State.Pieces)
        {
            if (Piece.Piece.Get_IsGone())
            { continue; }

            utils_entity_lifetime::Request_DestroyEntity(Piece.Entity);
        }
    }
}

// What Adopt seats: the identity, the piece and the coat it starts with (0 for an admission, 1 for a readopt).
struct FMars_Batter_PieceState_Seed
{
    FMars_CookingFeed_PieceId Id;
    FCk_Handle_FoodPiece Piece;
    float32 Coat = 0.0f;

    FMars_Batter_PieceState_Seed() {}

    FMars_Batter_PieceState_Seed(FMars_CookingFeed_PieceId InId, FCk_Handle_FoodPiece InPiece)
    {
        Id = InId;
        Piece = InPiece;
    }
}
