// One release's answer, broadcast after the whole drain applied.
struct FMars_Fry_AdmissionResult
{
    FMars_CookingFeed_PieceId Id;
    EMars_CookingFeed_Admission Admission = EMars_CookingFeed_Admission::Rejected;
    // Rejected only: why, and the kernel's own words for it (the station's OnAdmission carries the words).
    EMars_Fry_AdmissionRefusal Refusal = EMars_Fry_AdmissionRefusal::Unavailable;
    FString Reason;
    // Accepted only: the adopted piece's entity.
    FCk_Handle Entity;
}

// One piece a TakeOut handed back, broadcast after the whole drain applied.
struct FMars_Fry_TakeOutResult
{
    FMars_CookingFeed_PieceId Id;
    FCk_Handle_FoodPiece Piece;
}

// Drains Reset -> SetDrive -> TakeOut (the station's take-outs after the fryer's own) -> Readopt -> the station inbox's
// releases -> Skim -> Look. Reset resets the skimmer (carry, level, back at its park, idle) and zeroes the tally, and keeps
// every piece with its heat; SetDrive is last-wins and drives the skimmer (an idle one carries); TakeOut hands pieces back
// with their cook state written and their bodies Kinematic, each onto the request's tray (the station's take-out contract)
// or to the caller, and one that hands none back is refused (NoRoom under a cap of zero or with no tray named by the
// station, else NothingReady); Readopt puts a handed-back piece nobody took back in play where it lies; each release in the
// inbox is adopted or rejected (every one in a drain that also reset is rejected: the release belongs to the attempt the
// reset ended; an unbattered piece is refused NotBattered: the fryer fries only what the batter station coated); Skim dips
// inside the pot, pours over the basket, carries anywhere, is refused elsewhere (the corridor) and ignored while idle; a
// look moves the skimmer's target within the reach (the pot only while the scoop is dipped or still below the rim) while
// driven. The new target goes to the skimmer's commanded slide once. The drive and skim edges and every refused skim, then
// every take-out and every refused take-out, then every admission answer on the station's OnAdmission (and OnPieceAdded
// for an accepted one, OnAdmissionRefused for a rejected one) are broadcast last. The drain collects and the Tick
// measures: nothing here integrates over time.
//
// A piece is the kernel's guest: the kernel creates no entity, and a piece it holds ends only lost (the Tick) or with the
// station (OnFryBeginDestroy). The fryer is the one owner of its pieces' lease facts: it stamps every piece it takes on
// with the holder fact and its pickup's Ledger claim, removes the holder when it hands the piece back, and releases the
// claim when the piece lands on its tray (or at once when the take-out named none); a tray's refusal readopts the piece.
//
// It also listens: the station's queue (OnQueued wakes this drain) and the answers of every tray it loads (OnLoaded,
// OnLoadRefused).
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
        TArray<FMars_Request_Fry_TakeOut> TakeOutRequests = InRequests.TakeOutRequests;
        TArray<FMars_Request_Fry_Readopt> ReadoptRequests = InRequests.ReadoptRequests;
        TArray<FMars_Request_Fry_Skim> SkimRequests = InRequests.SkimRequests;
        TArray<FMars_Request_Fry_Look> LookRequests = InRequests.LookRequests;

        // InRequests is invalid past this line; removing before broadcasting lets re-entrant requests survive.
        Self.Request_TryRemove(FMars_Fragment_Fry_Requests);

        Watch_Station(Self);
        TArray<FMars_CookingFeed_Release> Inbox = utils_cooking_feed::Take_Inbox(InHandle);
        TArray<FMars_Request_StationTakeOut> StationTakeOuts = utils_cooking_feed::Take_TakeOutRequests(InHandle);
        for (const auto& TakeOut : StationTakeOuts)
        { TakeOutRequests.Add(Make_TakeOut(TakeOut)); }

        const auto StartDrive = InState.Drive;
        const auto StartSkim = InState.Skim;

        if (HasReset)
        { Apply_Reset(Self, InState); }

        if (SetDriveRequests.Num() > 0)
        { Apply_SetDrive(Self, InState, SetDriveRequests.Last().Drive); }

        TArray<FMars_Fry_TakeOutResult> TakenOut;
        TArray<EMars_CookingFeed_TakeOutRefusal> TakeOutRefusals;
        for (const auto& Request : TakeOutRequests)
        {
            const auto Taken = Apply_TakeOut(Self, InState, Request);
            if (Taken.Num() == 0)
            { TakeOutRefusals.Add(Get_TakeOutRefusal(Request)); }

            Land(Self, Request, Taken);
            TakenOut.Append(Taken);
        }

        for (const auto& Request : ReadoptRequests)
        { Apply_Readopt(Self, InState, Request); }

        TArray<FMars_Fry_AdmissionResult> Admissions;
        for (const auto& Release : Inbox)
        {
            if (HasReset)
            { Admissions.Add(Reject_InResetDrain(Self, Release)); }
            else
            { Admissions.Add(Apply_AddPiece(Self, InState, Release)); }
        }

        const auto TargetBeforeSteering = InState.SkimmerTarget;

        TArray<EMars_Fry_Skim> RefusedSkims;
        for (const auto& Request : SkimRequests)
        {
            const auto Refused = Apply_Skim(Self, InState, Request.Skim);
            if (Refused.IsSet())
            { RefusedSkims.Add(Refused.GetValue()); }
        }

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

        const auto EndDrive = InState.Drive;
        const auto EndSkim = InState.Skim;
        if (EndDrive != StartDrive && Self.Has_Fragment(FMars_Fragment_Fry_Signals))
        { Self.Get_Fragment(FMars_Fragment_Fry_Signals).OnDriveChanged.Broadcast(Self, EndDrive); }

        if (EndSkim != StartSkim && Self.Has_Fragment(FMars_Fragment_Fry_Signals))
        { Self.Get_Fragment(FMars_Fragment_Fry_Signals).OnSkimChanged.Broadcast(Self, EndSkim); }

        for (const auto Skim : RefusedSkims)
        {
            if (Self.Has_Fragment(FMars_Fragment_Fry_Signals))
            { Self.Get_Fragment(FMars_Fragment_Fry_Signals).OnSkimRefused.Broadcast(Self, Skim); }
        }

        for (const auto& Result : TakenOut)
        {
            if (Self.Has_Fragment(FMars_Fragment_Fry_Signals))
            { Self.Get_Fragment(FMars_Fragment_Fry_Signals).OnPieceTakenOut.Broadcast(Self, Result.Id, Result.Piece); }
        }

        for (const auto Refusal : TakeOutRefusals)
        {
            if (Self.Has_Fragment(FMars_Fragment_Fry_Signals))
            { Self.Get_Fragment(FMars_Fragment_Fry_Signals).OnTakeOutRefused.Broadcast(Self, Refusal); }
        }

        FCk_Handle Station = Self;
        for (const auto& Result : Admissions)
        {
            utils_cooking_feed::Broadcast_Admission(Station, FMars_CookingFeed_AdmissionAnswer(Result.Id, Result.Admission, Result.Reason));
            if (Self.Has_Fragment(FMars_Fragment_Fry_Signals) == false)
            { continue; }

            if (Result.Admission == EMars_CookingFeed_Admission::Accepted)
            { Self.Get_Fragment(FMars_Fragment_Fry_Signals).OnPieceAdded.Broadcast(Self, Result.Id, Result.Entity); }
            else
            { Self.Get_Fragment(FMars_Fragment_Fry_Signals).OnAdmissionRefused.Broadcast(Self, Result.Id, Result.Refusal); }
        }
    }

    // The player's food is theirs: every piece stays in play with its heat (a lost one lingers out its time); only the tally
    // and the skimmer go back. The skimmer's own reset idles and levels it and zeroes its slide; its lift target goes back to
    // the carry.
    private void Apply_Reset(FCk_Handle_Fry& InFry, FMars_Fragment_Fry& InState)
    {
        InState.Tally = FMars_Fry_Tally();
        InState.Drive = EMars_Implement_Drive::Idle;
        InState.Skim = EMars_Fry_Skim::Carry;
        InState.SkimmerTarget = InState.SkimmerPark;

        auto Skimmer = InFry.Get_Skimmer();
        Skimmer.Request_Reset(FMars_Request_Implement_Reset());
        // After the implement's reset in its own drain: the carry height is the skimmer's, not necessarily its rest.
        Skimmer.Request_SetLiftTarget(FMars_Request_Implement_SetLiftTarget(InFry.Get_Spec().Scoop.CarryLift));
        Skimmer.Request_SetSlideTarget(FMars_Request_Implement_SetSlideTarget(FVector2D::ZeroVector));
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
    }

    private FMars_Fry_AdmissionResult Reject_InResetDrain(FCk_Handle_Fry& InFry, const FMars_CookingFeed_Release& InRelease)
    {
        auto Result = FMars_Fry_AdmissionResult();
        Result.Id = InRelease.PieceId;
        Result.Reason = "reset in the same drain";
        return Result;
    }

    // A station take-out is the fryer's own TakeOut onto its tray, capped at the room the press read: no tray caps it at none.
    private FMars_Request_Fry_TakeOut Make_TakeOut(const FMars_Request_StationTakeOut& InTakeOut) const
    {
        const auto MaxPieces = ck::IsValid(InTakeOut.Tray) ? InTakeOut.MaxPieces : 0;
        return FMars_Request_Fry_TakeOut(TOptional<FCk_Handle_FoodPiece>(), TOptional<int32>(MaxPieces), InTakeOut.Tray);
    }

    // Unset Piece: every Drained piece, in admission order; set: that piece while it is in play and not lost. MaxPieces caps
    // either. Each one leaves play with its cook state written onto the piece, its body Kinematic (a platter takes it next)
    // and its holder fact gone; its Resting stays for whoever adopts it next to retarget.
    private TArray<FMars_Fry_TakeOutResult> Apply_TakeOut(FCk_Handle_Fry& InFry, FMars_Fragment_Fry& InState,
        const FMars_Request_Fry_TakeOut& InRequest)
    {
        TArray<FMars_Fry_TakeOutResult> Taken;
        TArray<FMars_Fry_PieceState> Kept;
        for (const auto& Piece : InState.Pieces)
        {
            const auto IsCapped = InRequest.MaxPieces.IsSet() && Taken.Num() >= InRequest.MaxPieces.GetValue();
            if (IsCapped || Get_IsTakeable(Piece, InRequest) == false)
            {
                Kept.Add(Piece);
                continue;
            }

            Hand_Back(InFry, Piece);

            auto Result = FMars_Fry_TakeOutResult();
            Result.Id = Piece.Id;
            Result.Piece = Piece.Piece;
            Taken.Add(Result);
        }

        InState.Pieces = Kept;
        InState.Tally.TakenOut += Taken.Num();

        return Taken;
    }

    private bool Get_IsTakeable(const FMars_Fry_PieceState& InPiece, const FMars_Request_Fry_TakeOut& InRequest) const
    {
        if (Get_IsGone(InPiece.Piece))
        { return false; }

        if (InRequest.Piece.IsSet())
        { return InPiece.Piece == InRequest.Piece.GetValue() && InPiece.Whereabouts != EMars_Fry_Whereabouts::Lost; }

        return InPiece.Drain == EMars_Fry_Drain::Drained;
    }

    // Why a take-out took nothing: a cap of zero left no room (no tray docked, or a full one), else nothing was takeable.
    private EMars_CookingFeed_TakeOutRefusal Get_TakeOutRefusal(const FMars_Request_Fry_TakeOut& InRequest) const
    {
        if (InRequest.MaxPieces.IsSet() && InRequest.MaxPieces.GetValue() <= 0)
        { return EMars_CookingFeed_TakeOutRefusal::NoRoom; }

        return EMars_CookingFeed_TakeOutRefusal::NothingReady;
    }

    // The piece leaves with its batter and the oil the basket left on it (Receiver.DrainedOilCoat): its sheen at the next
    // station.
    private void Hand_Back(const FCk_Handle_Fry& InFry, const FMars_Fry_PieceState& InPiece)
    {
        auto Piece = InPiece.Piece;
        auto CookState = utils_fry::Get_CookState(InPiece, Piece.Get_CookState());
        CookState.OilCoat = InFry.Get_Spec().Receiver.DrainedOilCoat;
        Piece.Request_SetCookState(FMars_Request_FoodPiece_SetCookState(CookState));

        auto Body = InPiece.Body;
        utils_jolt_body::Request_SetMotionType(Body, FCk_Request_JoltBody_SetMotionType(ECk_MotionType::Kinematic));
        utils_foodpiece::Clear_Holder(Piece, InFry);
    }

    // Every piece a take-out handed back goes onto the request's tray (detached first, its landing watched: its Ledger claim
    // stays the fryer's until it lands), else to the caller, its claim released.
    private void Land(const FCk_Handle_Fry& InFry, const FMars_Request_Fry_TakeOut& InRequest, const TArray<FMars_Fry_TakeOutResult>& InTaken)
    {
        for (const auto& Result : InTaken)
        {
            auto Piece = Result.Piece;
            if (ck::IsValid(InRequest.Tray))
            { utils_cooking_feed::Send_ToTray(Piece, FMars_Fragment_StationLanding(InFry, Result.Id, InRequest.Tray)); }
            else
            { utils_world_item::Request_ClaimPickup(Piece, EMars_Interactable_DisableReason::Ledger, ECk_EnableDisable::Enable); }
        }

        if (InTaken.Num() > 0 && ck::IsValid(InRequest.Tray))
        { Watch_Tray(InRequest.Tray); }
    }

    // A handed-back piece nobody took, back in play where it lies (it is not moved): the record rebuilt from the piece (the
    // take-out wrote its faces' heat into its cook state as its batter), its body Dynamic again, its Resting on the scoop
    // and the basket, its holder fact and its pickup's Ledger claim the fryer's. It starts as an admitted piece does,
    // Airborne and NotDraining: the Tick judges where it is from its pose, and a piece lying in the basket drains again. The take-out it undoes leaves the tally. A piece gone, attached, or that another ledger
    // holds by now is not readopted.
    private void Apply_Readopt(FCk_Handle_Fry& InFry, FMars_Fragment_Fry& InState, const FMars_Request_Fry_Readopt& InRequest)
    {
        auto Piece = InRequest.Piece;
        const auto PieceName = utils_cooking_feed::Get_PieceName(InRequest.PieceId);
        if (Get_IsGone(Piece))
        { return; }

        FCk_Handle Entity = Piece;
        const auto Holder = Piece.TryGet_Holder();
        if ((ck::IsValid(Holder) && Holder != InFry) || Entity.Is_SceneNode())
        { return; }

        const auto IsInPlay = utils_fry::Find_PieceIndexByHandle(InState.Pieces, Piece) >= 0
            || utils_fry::Find_PieceIndex(InState.Pieces, InRequest.PieceId) >= 0;
        if (ck::EnsureIfNot(IsInPlay == false, f"[Fry] [{InFry.ToString()}] was asked to readopt piece {PieceName} [{Piece.ToString()}], which is already in play"))
        { return; }

        if (ck::EnsureIfNot(Entity.Is_JoltBody(), f"[Fry] [{InFry.ToString()}] was asked to readopt piece {PieceName} [{Piece.ToString()}], which has no body: it handed back only bodied pieces"))
        { return; }

        const auto Spec = InFry.Get_Spec();
        auto Body = Entity.As_JoltBody();
        utils_jolt_body::Request_SetMotionType(Body, FCk_Request_JoltBody_SetMotionType(ECk_MotionType::Dynamic));

        TArray<FCk_Handle> Supports;
        Supports.Add(Spec.Nodes.ScoopBody);
        Supports.Add(Spec.Nodes.BasketBody);
        if (Entity.Is_Resting())
        {
            auto Resting = Entity.As_Resting();
            Resting.Request_Retarget(FMars_Request_Resting_Retarget(Supports, Spec.Receiver.SupportGraceSeconds, k_HopMinSeconds));
        }
        else
        { utils_resting::Add(Entity, FMars_Resting_Spec(Supports, Spec.Receiver.SupportGraceSeconds, k_HopMinSeconds)); }

        const auto Metrics = utils_runtime_mesh::Get_Metrics(Piece.Get_Geometry());
        auto State = FMars_Fry_PieceState();
        State.Id = InRequest.PieceId;
        State.Piece = Piece;
        State.Entity = Entity;
        State.Body = Body;
        State.CentreLocal = utils_searing::Get_BoundsCentre(Metrics);
        State.HalfExtents = utils_searing::Get_BoundsHalfExtents(Metrics);
        State.Whereabouts = EMars_Fry_Whereabouts::Airborne;
        State.LastHome = EMars_Fry_Whereabouts::Oil;

        const auto CookState = Piece.Get_CookState();
        for (int32 Index = 0; Index < utils_searing::k_FaceCount; ++Index)
        {
            const auto Heat = CookState.Batter.IsValidIndex(Index) ? Math::Clamp(CookState.Batter[Index], 0.0f, 2.0f) : 0.0f;
            State.FaceHeat.Add(Heat);
            State.ReportedStage.Add(utils_fry::Get_HeatStage(Heat));
        }

        InState.Pieces.Add(State);
        InState.Tally.TakenOut = Math::Max(0, InState.Tally.TakenOut - 1);
        utils_foodpiece::Stamp_Holder(Piece, InFry);
        utils_world_item::Request_ClaimPickup(Piece, EMars_Interactable_DisableReason::Ledger, ECk_EnableDisable::Disable);
        Watch_Teardown(InFry);
    }

    // Adopted: the released piece (Release.Piece, Ready, held by no other ledger and on no scene node) moves to the release
    // pose with a dynamic body moving at the release's velocities and a Resting on the scoop disc and the basket floor
    // (which tell whether it lies on the scoop); its faces' heat is seeded from its batter (a pan's sear is not batter: a
    // seared face arrives pale and keeps its sear in the ledger); the fryer stamps it with the holder fact and its pickup's
    // Ledger claim. It starts Airborne, its last home the Oil. Rejected: the piece is left as it was; a piece whose ledger is
    // not battered (utils_batter::Get_IsBattered: the batter station's take-out wrote it) is refused NotBattered, the
    // fryer never batters anything itself.
    private FMars_Fry_AdmissionResult Apply_AddPiece(FCk_Handle_Fry& InFry, FMars_Fragment_Fry& InState,
        const FMars_CookingFeed_Release& InRelease)
    {
        auto Result = FMars_Fry_AdmissionResult();
        Result.Id = InRelease.PieceId;

        const auto Spec = InFry.Get_Spec();
        const auto PieceName = utils_cooking_feed::Get_PieceName(InRelease.PieceId);
        auto Piece = InRelease.Piece;
        FCk_Handle Entity = Piece;

        // A piece's Resting needs both bodies, and a piece dropped toward a body not there yet falls through it.
        if (utils_jolt_body::Get_IsBodyAdded(Spec.Nodes.ScoopBody) == false || utils_jolt_body::Get_IsBodyAdded(Spec.Nodes.BasketBody) == false)
        { Result.Reason = "the scoop or basket body is not in the simulation yet"; }
        else if (Get_IsGone(Piece))
        { Result.Reason = "no piece"; }
        else if (Piece.Get_Status() != EMars_FoodPiece_Status::Ready)
        { Result.Reason = "the piece is not ready"; }
        else if (utils_fry::Find_PieceIndexByHandle(InState.Pieces, Piece) >= 0)
        { Result.Reason = "already admitted"; }
        else if (utils_fry::Find_PieceIndex(InState.Pieces, InRelease.PieceId) >= 0)
        { Result.Reason = f"piece {PieceName} is already in play"; }
        else if (ck::IsValid(Piece.TryGet_Holder()))
        { Result.Reason = "another ledger holds it"; }
        else if (Entity.Is_SceneNode())
        { Result.Reason = "still attached"; }
        else if (utils_batter::Get_IsBattered(Piece.Get_CookState()) == false)
        {
            Result.Refusal = EMars_Fry_AdmissionRefusal::NotBattered;
            Result.Reason = "not battered: batter it at the batter station first";
        }
        else if (utils_fry::Get_LivePieceCount(InState.Pieces) >= Spec.Supply.MaxPieces)
        {
            Result.Refusal = EMars_Fry_AdmissionRefusal::Full;
            Result.Reason = f"Supply.MaxPieces [{Spec.Supply.MaxPieces}] pieces are already in play";
        }

        if (Result.Reason.Len() > 0)
        { return Result; }

        const auto Body = Adopt_Body(Piece, InRelease, Spec.Piece);

        TArray<FCk_Handle> Supports;
        Supports.Add(Spec.Nodes.ScoopBody);
        Supports.Add(Spec.Nodes.BasketBody);

        // A piece that rested on another station's supports already tracks them: it is pointed at these instead.
        if (Entity.Is_Resting())
        {
            auto Resting = Entity.As_Resting();
            Resting.Request_Retarget(FMars_Request_Resting_Retarget(Supports, Spec.Receiver.SupportGraceSeconds, k_HopMinSeconds));
        }
        else
        { utils_resting::Add(Entity, FMars_Resting_Spec(Supports, Spec.Receiver.SupportGraceSeconds, k_HopMinSeconds)); }

        const auto Metrics = utils_runtime_mesh::Get_Metrics(Piece.Get_Geometry());
        auto State = FMars_Fry_PieceState();
        State.Id = InRelease.PieceId;
        State.Piece = Piece;
        State.Entity = Entity;
        State.Body = Body;
        State.CentreLocal = utils_searing::Get_BoundsCentre(Metrics);
        State.HalfExtents = utils_searing::Get_BoundsHalfExtents(Metrics);
        State.Arriving = TOptional<FVector>(InRelease.WorldTransform.GetLocation());
        State.Whereabouts = EMars_Fry_Whereabouts::Airborne;
        State.LastHome = EMars_Fry_Whereabouts::Oil;

        // A face fried before arrives at its heat; its stage counts as reported.
        const auto Seed = Piece.Get_CookState();
        for (int32 Index = 0; Index < utils_searing::k_FaceCount; ++Index)
        {
            const auto Heat = Seed.Batter.IsValidIndex(Index) ? Math::Clamp(Seed.Batter[Index], 0.0f, 2.0f) : 0.0f;
            State.FaceHeat.Add(Heat);
            State.ReportedStage.Add(utils_fry::Get_HeatStage(Heat));
        }

        InState.Pieces.Add(State);
        utils_foodpiece::Stamp_Holder(Piece, InFry);
        utils_world_item::Request_ClaimPickup(Piece, EMars_Interactable_DisableReason::Ledger, ECk_EnableDisable::Disable);
        Watch_Teardown(InFry);

        Result.Admission = EMars_CookingFeed_Admission::Accepted;
        Result.Entity = Entity;
        return Result;
    }

    // A piece without a body is posed at the release first (a body reads its entity's pose when it is added) and given a
    // dynamic convex body from its own mesh at its own mass. A piece that left another station keeps its body: switched back
    // to Dynamic and teleported to the release. Either way the release's velocities follow (the body handles its requests
    // once it is set up and added, so these wait for it).
    private FCk_Handle_JoltBody Adopt_Body(FCk_Handle_FoodPiece InPiece, const FMars_CookingFeed_Release& InRelease,
        const FMars_Fry_PieceSpec& InSpec)
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
            BodySpec.Set_GravityFactor(InSpec.GravityFactor);
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
    private void Watch_Teardown(const FCk_Handle_Fry& InFry)
    {
        FCk_Handle Fry = InFry;
        Fry.UnbindFrom_OnBeginDestroy(FCk_Delegate_OnBeginDestroy(this, n"OnFryBeginDestroy"));
        Fry.BindTo_OnBeginDestroy(FCk_Delegate_OnBeginDestroy(this, n"OnFryBeginDestroy"));
    }

    // Unbinding first keeps the watch single across drains: the station's queue wakes this drain.
    private void Watch_Station(const FCk_Handle_Fry& InFry)
    {
        FCk_Handle Station = InFry;
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

    // A live fryer's station: a landing whose fryer is gone has nothing to go back to.
    private bool Get_IsFry(const FCk_Handle& InStation) const
    {
        return ck::IsValid(InStation)
            && utils_entity_lifetime::Get_IsPendingDestroy(InStation, ECk_EntityLifetime_DestructionPhase::BeginDestroy) == false
            && InStation.Is_Fry();
    }

    // The station queued a release or a take-out: the fryer drains it this frame.
    UFUNCTION()
    private void OnStationQueued(FCk_Handle InStation)
    {
        auto Station = InStation;
        if (Station.Is_Fry())
        { Station.AddOrGet_Fragment(FMars_Fragment_Fry_Requests); }
    }

    // A piece the fryer handed to a tray landed there: the tray holds it now, and its pickup's Ledger claim goes.
    UFUNCTION()
    private void OnTrayLoaded(FCk_Handle_Platter InTray, FCk_Handle_FoodPiece InPiece)
    {
        const auto Landing = utils_cooking_feed::TryGet_Landing(InPiece, InTray);
        if (Landing.IsSet() == false || Get_IsFry(Landing.GetValue().Station) == false)
        { return; }

        auto Piece = InPiece;
        utils_cooking_feed::Clear_Landing(Piece);
        utils_world_item::Request_ClaimPickup(Piece, EMars_Interactable_DisableReason::Ledger, ECk_EnableDisable::Enable);
    }

    // A piece the fryer handed to a tray was refused: back in play where it lies.
    UFUNCTION()
    private void OnTrayLoadRefused(FCk_Handle_Platter InTray, FCk_Handle_FoodPiece InPiece, EMars_Platter_LoadRefusal InRefusal)
    {
        const auto Landing = utils_cooking_feed::TryGet_Landing(InPiece, InTray);
        if (Landing.IsSet() == false || Get_IsFry(Landing.GetValue().Station) == false)
        { return; }

        auto Piece = InPiece;
        utils_cooking_feed::Clear_Landing(Piece);
        auto Station = Landing.GetValue().Station;
        auto Fry = Station.As_Fry();
        Fry.Request_Readopt(FMars_Request_Fry_Readopt(Landing.GetValue().PieceId, Piece));
    }

    // The pieces in play end with the station: under the world's transient entity they would outlive it.
    UFUNCTION()
    private void OnFryBeginDestroy(FCk_Handle InFry)
    {
        auto FryEntity = InFry;
        if (FryEntity.Has_Fragment(FMars_Fragment_Fry) == false)
        { return; }

        const auto State = FryEntity.Get_Fragment(FMars_Fragment_Fry);
        for (const auto& Piece : State.Pieces)
        {
            if (Get_IsGone(Piece.Piece))
            { continue; }

            utils_entity_lifetime::Request_DestroyEntity(Piece.Entity);
        }
    }

    // Carry is honoured anywhere. A Dip (or a Pour asked for) dips with the whole scoop inside the pot (and holds the target
    // there, so it cannot carry on out while dipped), pours with the whole bowl over the basket interior (lowering the disc
    // there would press the basket's pieces through its floor), and is refused elsewhere (in the corridor the disc would
    // drop into the counter): the refused skim is returned for OnSkimRefused. Unset when honoured, and while idle.
    private TOptional<EMars_Fry_Skim> Apply_Skim(FCk_Handle_Fry& InFry, FMars_Fragment_Fry& InState, EMars_Fry_Skim InSkim)
    {
        if (InState.Drive != EMars_Implement_Drive::Driven)
        { return TOptional<EMars_Fry_Skim>(); }

        if (InSkim == EMars_Fry_Skim::Carry)
        {
            Set_Skim(InFry, InState, EMars_Fry_Skim::Carry);
            return TOptional<EMars_Fry_Skim>();
        }

        if (InFry.Get_IsScoopInPot())
        {
            Set_Skim(InFry, InState, EMars_Fry_Skim::Dip);
            InState.SkimmerTarget = utils_fry::Clamp_Reach(InState.SkimmerTarget, InFry.Get_Spec(), EMars_Fry_Skim::Dip);
            return TOptional<EMars_Fry_Skim>();
        }

        if (InFry.Get_IsScoopOverBasket())
        {
            Set_Skim(InFry, InState, EMars_Fry_Skim::Pour);
            return TOptional<EMars_Fry_Skim>();
        }

        return TOptional<EMars_Fry_Skim>(InSkim);
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
