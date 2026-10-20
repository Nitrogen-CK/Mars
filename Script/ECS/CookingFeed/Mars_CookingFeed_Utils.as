// What utils_cooking_feed::Get_HandLocal poses the hand from: the geometry, where the transfer is (its phase and the 0..1
// progress through it), and the two points the hand goes to in the hand node's parent frame (the grasped piece's middle,
// unset until sampled, and the release node).
struct FMars_CookingFeed_HandQuery
{
    FMars_CookingFeed_HandGeometry Geometry;
    EMars_CookingFeed_Phase Phase = EMars_CookingFeed_Phase::Idle;
    float32 Progress = 1.0f;
    TOptional<FVector> GraspPoint;
    FVector ReleasePoint = FVector::ZeroVector;
}

namespace utils_cooking_feed
{
    // Composes the feed on InHandle (the station entity; the feature does not need the Station feature). The spec's Nodes are
    // built by the caller: Nodes.Release is sampled at every release, and the reserved piece rides Nodes.Hand from its grasp
    // to its release; with hand geometry in the spec the feed moves that node itself, so it must be a scene node under a
    // parent. Nodes.InputDock, when set, must be a lifetime child of InHandle: the feed's setup binds it, and the feed then
    // draws from the platter that has arrived on it. The feed starts unsourced with the hand idle. A rejected spec, a
    // missing node or a dock InHandle does not own ensures and returns an invalid handle.
    FCk_Handle_CookingFeed Add(FCk_Handle& InHandle, FMars_CookingFeed_Spec InSpec)
    {
        const auto Validation = InSpec.Validate();
        if (ck::EnsureIfNot(Validation.IsValid(), f"[CookingFeed] [{InHandle.ToString()}] rejected the spec: {Validation.Get_Error()}"))
        { return FCk_Handle_CookingFeed(); }

        if (ck::EnsureIfNot(ck::IsValid(InSpec.Nodes.Release), f"[CookingFeed] [{InHandle.ToString()}] needs a release node"))
        { return FCk_Handle_CookingFeed(); }

        if (ck::EnsureIfNot(ck::IsValid(InSpec.Nodes.Hand), f"[CookingFeed] [{InHandle.ToString()}] needs a hand node to carry its pieces"))
        { return FCk_Handle_CookingFeed(); }

        if (InSpec.Hand.IsSet())
        {
            FCk_Handle HandEntity = InSpec.Nodes.Hand;
            const auto HandNode = HandEntity.As_SceneNode(ECk_SanityCheck::UnChecked);
            const auto IsMovable = ck::IsValid(HandNode) && ck::IsValid(utils_scene_node::Get_Parent(HandNode));
            if (ck::EnsureIfNot(IsMovable, f"[CookingFeed] [{InHandle.ToString()}] has hand geometry, so its hand node must be a scene node under a parent"))
            { return FCk_Handle_CookingFeed(); }
        }

        const auto InputDock = InSpec.Nodes.InputDock;
        if (ck::EnsureIfNot(ck::Is_NOT_Valid(InputDock) || utils_entity_lifetime::Get_LifetimeOwner(InputDock) == InHandle,
            f"[CookingFeed] [{InHandle.ToString()}] has an input dock [{InputDock.ToString()}] it does not own"))
        { return FCk_Handle_CookingFeed(); }

        auto Params = FMars_Fragment_CookingFeed_Params();
        Params.Spec = InSpec;

        InHandle.Add_Fragment(FMars_Feature_CookingFeed());
        InHandle.Add_Fragment(Params);
        InHandle.Add_Fragment(FMars_Fragment_CookingFeed());
        InHandle.Add_Fragment(FMars_Tag_CookingFeed_NeedsSetup());
        return InHandle.As_CookingFeed();
    }

    // What the source holds (frozen, settling or about to drop: a pile re-settling after a piece left is still stock) less a
    // reserved piece still on it; 0 without a source. Once the feed has unloaded the reserved piece at its grasp it is
    // already off the count.
    int32 Get_Available(const FMars_Fragment_CookingFeed& InState)
    {
        if (ck::Is_NOT_Valid(InState.Source))
        { return 0; }

        const auto Reserved = InState.Active.IsSet() && Get_IsOnSource(InState.Active.GetValue().Piece, InState.Source) ? 1 : 0;
        return InState.Source.Get_Occupancy() - Reserved;
    }

    // The source has stock but its pile is settling: nothing is frozen to reach for, so a press is refused Busy until a
    // piece freezes.
    bool Get_IsSettling(const FMars_Fragment_CookingFeed& InState)
    {
        return Get_Available(InState) > 0 && InState.Source.Get_HeldCount() == 0;
    }

    // InPiece is alive and InSource (a valid platter) holds it, landed or pending.
    bool Get_IsOnSource(const FCk_Handle_FoodPiece& InPiece, const FCk_Handle_Platter& InSource)
    {
        if (ck::Is_NOT_Valid(InPiece) || ck::Is_NOT_Valid(InSource))
        { return false; }

        if (utils_entity_lifetime::Get_IsPendingDestroy(InPiece, ECk_EntityLifetime_DestructionPhase::BeginDestroy))
        { return false; }

        return InPiece.TryGet_Platter() == InSource;
    }

    // The one put-back: a reserved piece the feed took (unloading, riding InHand, or released and not admitted) goes back onto
    // the platter it was reserved from, else onto the current source (Returned); with neither alive it is let go where it
    // lies, detached and its body Dynamic (LetGo: the calling processor broadcasts OnPieceLetGo). A piece riding the hand is
    // detached in this call, before its load (a platter forgets a queued piece that has a scene parent). A piece still coming
    // off its platter is loaded behind that unload, which lands it back. A piece that is gone, never left the source, was
    // taken off the hand or out of the release by someone else (it has a scene parent), or that another ledger holds (its
    // holder fact names anything but the platter it came from: a pan that admitted it while this answer was in flight
    // included), stays as it is (Kept). Issues requests only: the caller drops the reservation.
    EMars_CookingFeed_PieceReturn Return_Piece(const FMars_Fragment_CookingFeed& InState, const FCk_Handle_Transform& InHand)
    {
        if (InState.Active.IsSet() == false)
        { return EMars_CookingFeed_PieceReturn::Kept; }

        const auto Reservation = InState.Active.GetValue();
        auto Piece = Reservation.Piece;
        if (Reservation.Hold == EMars_CookingFeed_PieceHold::OnSource || Piece.Get_IsGone())
        { return EMars_CookingFeed_PieceReturn::Kept; }

        FCk_Handle Entity = Piece;
        auto Node = Entity.As_SceneNode(ECk_SanityCheck::UnChecked);
        const auto Holder = Piece.TryGet_Holder();
        if (Reservation.Hold == EMars_CookingFeed_PieceHold::InHand)
        {
            if (Get_IsUnderHand(Piece, InHand) == false)
            { return EMars_CookingFeed_PieceReturn::Kept; }

            utils_scene_node::Request_Detach(Node);
        }
        else if (ck::IsValid(Node) && Holder != Reservation.From)
        { return EMars_CookingFeed_PieceReturn::Kept; }

        if (ck::IsValid(Holder) && Holder != Reservation.From)
        { return EMars_CookingFeed_PieceReturn::Kept; }

        FCk_Handle_Platter Target = InState.Source;
        if (Get_IsAlive(Reservation.From))
        { Target = Reservation.From; }

        if (Get_IsAlive(Target) == false)
        {
            Release_WhereItLies(Piece);
            return EMars_CookingFeed_PieceReturn::LetGo;
        }

        Target.Request_Load(FMars_Request_Platter_Load(Piece));
        return EMars_CookingFeed_PieceReturn::Returned;
    }

    // The declared give-up: no platter is left to take the piece back, so it falls where it is.
    void Release_WhereItLies(FCk_Handle_FoodPiece& InPiece)
    {
        FCk_Handle Entity = InPiece;
        auto Node = Entity.As_SceneNode(ECk_SanityCheck::UnChecked);
        if (ck::IsValid(Node))
        { utils_scene_node::Request_Detach(Node); }

        auto Body = Entity.As_JoltBody(ECk_SanityCheck::UnChecked);
        if (ck::IsValid(Body))
        { utils_jolt_body::Request_SetMotionType(Body, FCk_Request_JoltBody_SetMotionType(ECk_MotionType::Dynamic)); }
    }

    // InPiece is scene-node attached directly under InHand.
    bool Get_IsUnderHand(const FCk_Handle_FoodPiece& InPiece, const FCk_Handle_Transform& InHand)
    {
        FCk_Handle Entity = InPiece;
        auto Node = Entity.As_SceneNode(ECk_SanityCheck::UnChecked);
        return ck::IsValid(Node) && ck::IsValid(InHand) && utils_scene_node::Get_Parent(Node) == InHand;
    }

    bool Get_IsAlive(const FCk_Handle_Platter& InPlatter)
    {
        return ck::IsValid(InPlatter) && utils_entity_lifetime::Get_IsPendingDestroy(InPlatter, ECk_EntityLifetime_DestructionPhase::BeginDestroy) == false;
    }

    // A transfer past its grasp is committed: it lands through the station's admission inbox, so a Cancel or a Reset leaves
    // it be.
    bool Get_IsCommitted(EMars_CookingFeed_Phase InPhase)
    {
        return InPhase == EMars_CookingFeed_Phase::Carry || InPhase == EMars_CookingFeed_Phase::AwaitAdmission;
    }

    // Drops the reservation (if any) and idles the hand at once: the one cancel path (Cancel and Reset before the grasp,
    // SetSource, a reservation whose piece left the source). True when a reservation was dropped; the caller read its id
    // first and settles it Cancelled (and, for a piece the feed took itself, Return_Piece first).
    bool Cancel_Active(FMars_Fragment_CookingFeed& InState)
    {
        const auto HadReservation = InState.Active.IsSet();
        InState.Active.Reset();
        InState.Phase = EMars_CookingFeed_Phase::Idle;
        InState.PhaseSeconds = 0.0f;
        return HadReservation;
    }

    // A phase length the Tick can advance through: finite and not negative.
    bool Get_IsValidSeconds(float32 InSeconds)
    {
        return Math::IsFinite(InSeconds) && InSeconds >= 0.0f;
    }

    // The timed length of InPhase; zero for Idle and AwaitAdmission (its budget is not a phase length).
    float32 Get_PhaseDuration(const FMars_CookingFeed_TimingSpec& InTiming, EMars_CookingFeed_Phase InPhase)
    {
        switch (InPhase)
        {
            case EMars_CookingFeed_Phase::Reach: return InTiming.ReachSeconds;
            case EMars_CookingFeed_Phase::Grasp: return InTiming.GraspSeconds;
            case EMars_CookingFeed_Phase::Carry: return InTiming.CarrySeconds;
            case EMars_CookingFeed_Phase::Return: return InTiming.ReturnSeconds;
            default: return 0.0f;
        }
    }

    // The phases the hand moves through on a clock.
    bool Get_IsTimed(EMars_CookingFeed_Phase InPhase)
    {
        return InPhase == EMars_CookingFeed_Phase::Reach || InPhase == EMars_CookingFeed_Phase::Grasp
            || InPhase == EMars_CookingFeed_Phase::Carry || InPhase == EMars_CookingFeed_Phase::Return;
    }

    FString Get_PieceName(const FMars_CookingFeed_PieceId& InPieceId)
    {
        return f"g{InPieceId.Generation}#{InPieceId.TransferIndex}";
    }

    // The hand node's offset in its parent's frame for InQuery: the legs FMars_CookingFeed_HandGeometry describes, each eased
    // in and out over its phase (0.5 - 0.5 cos(pi t)), the reach, the carry and the return arcing up by sin(pi eased).
    FTransform Get_HandLocal(const FMars_CookingFeed_HandQuery& InQuery)
    {
        const auto& Geometry = InQuery.Geometry;
        const auto Alpha = float64(InQuery.Progress);
        const auto Eased = 0.5 - 0.5 * Math::Cos(PI * Alpha);
        const auto Arc = Math::Sin(PI * Eased);
        const auto Up = FVector::UpVector;
        const auto Clearance = float64(Geometry.ClearanceCm);

        const auto Rest = Geometry.RestLocal.GetLocation();
        const auto GraspAt = InQuery.GraspPoint.IsSet() ? InQuery.GraspPoint.GetValue() : Rest;
        const auto Grasp = GraspAt + Geometry.GraspLocal.GetLocation();
        const auto Lifted = Grasp + Up * Clearance;
        const auto Release = InQuery.ReleasePoint + Geometry.ReleaseLocal.GetLocation();

        const auto RestRotation = Geometry.RestLocal.GetRotation();
        const auto GraspRotation = Geometry.GraspLocal.GetRotation();
        const auto ReleaseRotation = Geometry.ReleaseLocal.GetRotation();

        if (InQuery.Phase == EMars_CookingFeed_Phase::Reach)
        { return FTransform(FQuat::Slerp(RestRotation, GraspRotation, Eased), Math::Lerp(Rest, Grasp, Eased) + Up * (Clearance * Arc)); }

        if (InQuery.Phase == EMars_CookingFeed_Phase::Grasp)
        { return FTransform(GraspRotation, Math::Lerp(Grasp, Lifted, Eased)); }

        if (InQuery.Phase == EMars_CookingFeed_Phase::Carry)
        {
            return FTransform(FQuat::Slerp(GraspRotation, ReleaseRotation, Eased),
                Math::Lerp(Lifted, Release, Eased) + Up * (float64(Geometry.CarryArcCm) * Arc));
        }

        if (InQuery.Phase == EMars_CookingFeed_Phase::AwaitAdmission)
        { return FTransform(ReleaseRotation, Release); }

        if (InQuery.Phase == EMars_CookingFeed_Phase::Return)
        { return FTransform(FQuat::Slerp(ReleaseRotation, RestRotation, Eased), Math::Lerp(Release, Rest, Eased) + Up * (Clearance * Arc)); }

        return Geometry.RestLocal;
    }

    //----------------------------------------------------------------------------------------------------------------------
    // The station contract: the sender's requests, and the helpers a receiving kernel's processors use
    //----------------------------------------------------------------------------------------------------------------------

    // A receiving kernel's Add composes the station's inbox (and, for a kernel that hands pieces back, Add_TakeOut its
    // take-out readout): the station is a receiver from then on.
    void Add_Admission(FCk_Handle& InStation)
    {
        InStation.AddOrGet_Fragment(FMars_Fragment_StationAdmission);
    }

    void Add_TakeOut(FCk_Handle& InStation)
    {
        InStation.AddOrGet_Fragment(FMars_Fragment_StationTakeOut);
    }

    // A kernel on InStation receives releases.
    bool Get_IsAdmitting(const FCk_Handle& InStation)
    {
        return ck::IsValid(InStation) && InStation.Has_Fragment(FMars_Fragment_StationAdmission);
    }

    // A kernel on InStation hands pieces back (it keeps the take-out readout).
    bool Get_HasTakeOut(const FCk_Handle& InStation)
    {
        return ck::IsValid(InStation) && InStation.Has_Fragment(FMars_Fragment_StationTakeOut);
    }

    // What a take-out would hand back now; empty on a station whose kernel hands nothing back.
    TArray<FCk_Handle_FoodPiece> Get_Takeable(const FCk_Handle& InStation)
    {
        if (Get_HasTakeOut(InStation) == false)
        { return TArray<FCk_Handle_FoodPiece>(); }

        return InStation.Get_Fragment(FMars_Fragment_StationTakeOut).Takeable;
    }

    // InRelease into InStation's inbox, and the kernel woken: it answers on OnAdmission. False (nothing queued) for a station
    // no kernel receives at.
    bool Request_Admit(FCk_Handle& InStation, const FMars_CookingFeed_Release& InRelease)
    {
        if (Get_IsAdmitting(InStation) == false)
        { return false; }

        InStation.Get_Fragment(FMars_Fragment_StationAdmission).Inbox.Add(InRelease);
        Broadcast_Queued(InStation);
        return true;
    }

    // A take-out for InStation's kernel, which answers by handing pieces onto InRequest.Tray or by refusing.
    void Request_StationTakeOut(FCk_Handle& InStation, const FMars_Request_StationTakeOut& InRequest)
    {
        if (ck::EnsureIfNot(Get_IsAdmitting(InStation), f"[CookingFeed] [{InStation.ToString()}] has no receiving kernel to take out of"))
        { return; }

        InStation.AddOrGet_Fragment(FMars_Fragment_StationTakeOut_Requests).TakeOutRequests.Add(InRequest);
        Broadcast_Queued(InStation);
    }

    void Broadcast_Queued(FCk_Handle& InStation)
    {
        if (InStation.Has_Fragment(FMars_Fragment_StationAdmission_Signals))
        { InStation.Get_Fragment(FMars_Fragment_StationAdmission_Signals).OnQueued.Broadcast(InStation); }
    }

    // The receiving kernel's drain takes the whole inbox (empty after), in arrival order.
    TArray<FMars_CookingFeed_Release> Take_Inbox(FCk_Handle& InStation)
    {
        if (Get_IsAdmitting(InStation) == false)
        { return TArray<FMars_CookingFeed_Release>(); }

        auto& Admission = InStation.Get_Fragment(FMars_Fragment_StationAdmission);
        TArray<FMars_CookingFeed_Release> Inbox = Admission.Inbox;
        Admission.Inbox.Empty();
        return Inbox;
    }

    // The receiving kernel's drain takes every queued take-out, in arrival order.
    TArray<FMars_Request_StationTakeOut> Take_TakeOutRequests(FCk_Handle& InStation)
    {
        if (InStation.Has_Fragment(FMars_Fragment_StationTakeOut_Requests) == false)
        { return TArray<FMars_Request_StationTakeOut>(); }

        TArray<FMars_Request_StationTakeOut> Requests = InStation.Get_Fragment(FMars_Fragment_StationTakeOut_Requests).TakeOutRequests;
        InStation.Request_TryRemove(FMars_Fragment_StationTakeOut_Requests);
        return Requests;
    }

    // The receiving kernel's answer to one release from the inbox, broadcast once its drain applied.
    void Broadcast_Admission(FCk_Handle& InStation, const FMars_CookingFeed_AdmissionAnswer& InAnswer)
    {
        if (InStation.Has_Fragment(FMars_Fragment_StationAdmission_Signals))
        { InStation.Get_Fragment(FMars_Fragment_StationAdmission_Signals).OnAdmission.Broadcast(InStation, InAnswer.PieceId, InAnswer.Admission, InAnswer.Reason); }
    }

    // The kernel's Tick writes what a take-out would hand back, only on change.
    void Write_Takeable(FCk_Handle& InStation, const TArray<FCk_Handle_FoodPiece>& InTakeable)
    {
        if (Get_HasTakeOut(InStation) == false)
        { return; }

        auto& TakeOut = InStation.Get_Fragment(FMars_Fragment_StationTakeOut);
        if (Get_IsSamePieces(TakeOut.Takeable, InTakeable))
        { return; }

        TakeOut.Takeable = InTakeable;
    }

    bool Get_IsSamePieces(const TArray<FCk_Handle_FoodPiece>& InA, const TArray<FCk_Handle_FoodPiece>& InB)
    {
        if (InA.Num() != InB.Num())
        { return false; }

        for (int32 Index = 0; Index < InA.Num(); ++Index)
        {
            if (InA[Index] != InB[Index])
            { return false; }
        }

        return true;
    }

    // A kernel hands InPiece to InLanding.Tray: detached first if anything holds it attached (a platter forgets a queued
    // piece that has a scene parent), stamped with its landing, then loaded. The kernel's processor watches the tray's
    // answer and finds its own pieces by TryGet_Landing.
    void Send_ToTray(FCk_Handle_FoodPiece& InPiece, const FMars_Fragment_StationLanding& InLanding)
    {
        FCk_Handle Entity = InPiece;
        auto Node = Entity.As_SceneNode(ECk_SanityCheck::UnChecked);
        if (ck::IsValid(Node))
        { utils_scene_node::Request_Detach(Node); }

        auto& Landing = InPiece.AddOrGet_Fragment(FMars_Fragment_StationLanding);
        Landing = InLanding;
        auto Tray = InLanding.Tray;
        Tray.Request_Load(FMars_Request_Platter_Load(InPiece));
    }

    // Every piece a heat kernel's take-out handed back goes onto InTray (detached first, its landing watched by the kernel:
    // its pickup's Ledger claim stays the kernel's until it lands), else to the caller, its claim released. The kernel's
    // processor watches the tray itself (its handlers are the processor's).
    void Land_OnTray(const FCk_Handle& InStation, const FCk_Handle_Platter& InTray, const TArray<FMars_CookingFeed_TakeOutResult>& InTaken)
    {
        for (const auto& Result : InTaken)
        {
            auto Piece = Result.Piece;
            if (ck::IsValid(InTray))
            { Send_ToTray(Piece, FMars_Fragment_StationLanding(InStation, Result.Id, InTray)); }
            else
            { utils_world_item::Request_ClaimPickup(Piece, EMars_Interactable_DisableReason::Ledger, ECk_EnableDisable::Enable); }
        }
    }

    // InPiece's landing while it is on its way onto InTray; unset for any other piece or tray.
    TOptional<FMars_Fragment_StationLanding> TryGet_Landing(const FCk_Handle_FoodPiece& InPiece, const FCk_Handle_Platter& InTray)
    {
        if (ck::Is_NOT_Valid(InPiece) || InPiece.Has_Fragment(FMars_Fragment_StationLanding) == false)
        { return TOptional<FMars_Fragment_StationLanding>(); }

        const auto Landing = InPiece.Get_Fragment(FMars_Fragment_StationLanding);
        if (Landing.Tray != InTray)
        { return TOptional<FMars_Fragment_StationLanding>(); }

        return TOptional<FMars_Fragment_StationLanding>(Landing);
    }

    // The tray answered: the piece is no longer on its way.
    void Clear_Landing(FCk_Handle_FoodPiece& InPiece)
    {
        InPiece.Request_TryRemove(FMars_Fragment_StationLanding);
    }

    //----------------------------------------------------------------------------------------------------------------------
    // What the receiving heat kernels (Searing, Fry, Batter) share: the take-out cap and refusal, the readopt gate, a piece's
    // body and Resting at adoption, its face seed, and its arrival
    //----------------------------------------------------------------------------------------------------------------------

    // A piece's Resting counts a landing after this long apart as a hop (the Resting's own default; the heat kernels read no
    // hops).
    const float32 k_PieceHopMinSeconds = 0.12f;

    // The cap a station take-out runs under: the room the press read, none without a tray.
    int32 Get_StationTakeOutCap(const FMars_Request_StationTakeOut& InTakeOut)
    {
        return ck::IsValid(InTakeOut.Tray) ? InTakeOut.MaxPieces : 0;
    }

    // Why a take-out took nothing: a cap of zero left no room (no tray docked, or a full one), else nothing was takeable.
    EMars_CookingFeed_TakeOutRefusal Get_TakeOutRefusal(TOptional<int32> InMaxPieces)
    {
        if (InMaxPieces.IsSet() && InMaxPieces.GetValue() <= 0)
        { return EMars_CookingFeed_TakeOutRefusal::NoRoom; }

        return EMars_CookingFeed_TakeOutRefusal::NothingReady;
    }

    // Whether InStation's kernel takes back InPiece, which its tray refused: not a piece gone, one another ledger holds by
    // now, or one attached somewhere.
    EMars_CookingFeed_ReadoptGate Get_ReadoptGate(const FCk_Handle& InStation, const FCk_Handle_FoodPiece& InPiece)
    {
        if (InPiece.Get_IsGone())
        { return EMars_CookingFeed_ReadoptGate::Gone; }

        const auto Holder = InPiece.TryGet_Holder();
        if (ck::IsValid(Holder) && Holder != InStation)
        { return EMars_CookingFeed_ReadoptGate::HeldElsewhere; }

        FCk_Handle Entity = InPiece;
        if (Entity.Is_SceneNode())
        { return EMars_CookingFeed_ReadoptGate::Attached; }

        return EMars_CookingFeed_ReadoptGate::Readopt;
    }

    // InEntity rests on InSpec's targets: a piece that rested on another station's supports already tracks them and is
    // pointed at these instead.
    void Rest_On(FCk_Handle& InEntity, const FMars_Resting_Spec& InSpec)
    {
        if (InEntity.Is_Resting() == false)
        {
            utils_resting::Add(InEntity, InSpec);
            return;
        }

        auto Resting = InEntity.As_Resting();
        Resting.Request_Retarget(FMars_Request_Resting_Retarget(InSpec));
    }

    // Six face values seeded from InSeed (one cook state channel), each clamped to [0, InMax]; a face the seed lacks is 0.
    TArray<float32> Seed_Faces(const TArray<float32>& InSeed, float32 InMax)
    {
        TArray<float32> Faces;
        for (int32 Index = 0; Index < utils_foodpiece::k_FaceCount; ++Index)
        { Faces.Add(InSeed.IsValidIndex(Index) ? Math::Clamp(InSeed[Index], 0.0f, InMax) : 0.0f); }

        return Faces;
    }

    // A piece without a body is posed at the release first (a body reads its entity's pose when it is added) and given a
    // dynamic convex body from its own mesh at its own mass with InSurface. A piece that left another station keeps its body
    // and its surface: switched back to Dynamic and teleported to the release. Either way the release's velocities follow
    // (the body handles its requests once it is set up and added, so these wait for it).
    FCk_Handle_JoltBody Adopt_Body(FCk_Handle_FoodPiece& InPiece, const FMars_CookingFeed_Release& InRelease,
        const FMars_CookingFeed_BodySurface& InSurface)
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
            BodySpec.Set_Friction(InSurface.Friction);
            BodySpec.Set_Restitution(InSurface.Restitution);
            BodySpec.Set_LinearDamping(InSurface.LinearDamping);
            BodySpec.Set_AngularDamping(InSurface.AngularDamping);
            BodySpec.Set_GravityFactor(InSurface.GravityFactor);
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

    // An adopted piece is judged only once it is where it was released, or once it has taken too long to get there.
    EMars_CookingFeed_Arrival Get_ArrivalVerdict(const FMars_CookingFeed_ArrivalQuery& InQuery)
    {
        if (utils_foodpiece::Get_HasArrived(InQuery.Body, InQuery.Entity, InQuery.ReleaseLocation))
        { return EMars_CookingFeed_Arrival::Arrived; }

        if (InQuery.Seconds < utils_foodpiece::k_ArrivalMaxSeconds)
        { return EMars_CookingFeed_Arrival::OnItsWay; }

        return EMars_CookingFeed_Arrival::Overdue;
    }

    void BindTo_OnAdmission(FCk_Handle& InStation, FMars_Delegate_StationAdmission_OnAdmission InDelegate)
    {
        auto& Fragment = InStation.AddOrGet_Fragment(FMars_Fragment_StationAdmission_Signals);
        Fragment.OnAdmission.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
    }

    void UnbindFrom_OnAdmission(FCk_Handle& InStation, FMars_Delegate_StationAdmission_OnAdmission InDelegate)
    {
        if (InStation.Has_Fragment(FMars_Fragment_StationAdmission_Signals) == false)
        { return; }

        InStation.Get_Fragment(FMars_Fragment_StationAdmission_Signals).OnAdmission.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
    }

    void BindTo_OnQueued(FCk_Handle& InStation, FMars_Delegate_StationAdmission_OnQueued InDelegate)
    {
        auto& Fragment = InStation.AddOrGet_Fragment(FMars_Fragment_StationAdmission_Signals);
        Fragment.OnQueued.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
    }

    void UnbindFrom_OnQueued(FCk_Handle& InStation, FMars_Delegate_StationAdmission_OnQueued InDelegate)
    {
        if (InStation.Has_Fragment(FMars_Fragment_StationAdmission_Signals) == false)
        { return; }

        InStation.Get_Fragment(FMars_Fragment_StationAdmission_Signals).OnQueued.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
    }
}

//--------------------------------------------------------------------------------------------------------------------------
// Getters
//--------------------------------------------------------------------------------------------------------------------------

mixin FMars_CookingFeed_Spec Get_Spec(const FCk_Handle_CookingFeed& Self)
{
    return Self.Get_Fragment(FMars_Fragment_CookingFeed_Params).Spec;
}

mixin EMars_CookingFeed_Phase Get_Phase(const FCk_Handle_CookingFeed& Self)
{
    return Self.Get_Fragment(FMars_Fragment_CookingFeed).Phase;
}

// Seconds into the current timed phase, or into AwaitAdmission.
mixin float32 Get_PhaseSeconds(const FCk_Handle_CookingFeed& Self)
{
    return Self.Get_Fragment(FMars_Fragment_CookingFeed).PhaseSeconds;
}

// 0..1 within the current timed phase; 1 while idle or awaiting admission, and for a zero-length phase.
mixin float32 Get_PhaseProgress(const FCk_Handle_CookingFeed& Self)
{
    const auto& State = Self.Get_Fragment(FMars_Fragment_CookingFeed);
    if (utils_cooking_feed::Get_IsTimed(State.Phase) == false)
    { return 1.0f; }

    const auto Duration = utils_cooking_feed::Get_PhaseDuration(Self.Get_Spec().Timing, State.Phase);
    if (Duration <= 0.0f)
    { return 1.0f; }

    return Math::Clamp(State.PhaseSeconds / Duration, 0.0f, 1.0f);
}

mixin int32 Get_Generation(const FCk_Handle_CookingFeed& Self)
{
    return Self.Get_Fragment(FMars_Fragment_CookingFeed).Generation;
}

// Unreserved stock on the source: what a hint calls "left". Derived, never stored (utils_cooking_feed::Get_Available).
mixin int32 Get_Available(const FCk_Handle_CookingFeed& Self)
{
    return utils_cooking_feed::Get_Available(Self.Get_Fragment(FMars_Fragment_CookingFeed));
}

// Admissions since the last SetSource (or a Reset the feed honoured).
mixin int32 Get_Admitted(const FCk_Handle_CookingFeed& Self)
{
    return Self.Get_Fragment(FMars_Fragment_CookingFeed).Admitted;
}

// The platter the stock is drawn from; invalid while unsourced.
mixin FCk_Handle_Platter Get_Source(const FCk_Handle_CookingFeed& Self)
{
    return Self.Get_Fragment(FMars_Fragment_CookingFeed).Source;
}

mixin bool Get_IsSourced(const FCk_Handle_CookingFeed& Self)
{
    return ck::IsValid(Self.Get_Source());
}

mixin bool Get_IsSettling(const FCk_Handle_CookingFeed& Self)
{
    return utils_cooking_feed::Get_IsSettling(Self.Get_Fragment(FMars_Fragment_CookingFeed));
}

mixin bool Get_IsBusy(const FCk_Handle_CookingFeed& Self)
{
    return Self.Get_Fragment(FMars_Fragment_CookingFeed).Phase != EMars_CookingFeed_Phase::Idle;
}

// Set from BeginTransfer until the transfer settles.
mixin TOptional<FMars_CookingFeed_PieceId> TryGet_ActivePiece(const FCk_Handle_CookingFeed& Self)
{
    const auto& Active = Self.Get_Fragment(FMars_Fragment_CookingFeed).Active;
    if (Active.IsSet() == false)
    { return TOptional<FMars_CookingFeed_PieceId>(); }

    return TOptional<FMars_CookingFeed_PieceId>(Active.GetValue().Id);
}

// The reserved piece; invalid while idle.
mixin FCk_Handle_FoodPiece TryGet_ActiveFoodPiece(const FCk_Handle_CookingFeed& Self)
{
    const auto& Active = Self.Get_Fragment(FMars_Fragment_CookingFeed).Active;
    if (Active.IsSet() == false)
    { return FCk_Handle_FoodPiece(); }

    return Active.GetValue().Piece;
}

// The release in flight is still the one the feed awaits an answer for: AwaitAdmission under exactly InPieceId.
mixin bool Get_IsAwaiting(const FCk_Handle_CookingFeed& Self, const FMars_CookingFeed_PieceId& InPieceId)
{
    const auto& State = Self.Get_Fragment(FMars_Fragment_CookingFeed);
    return State.Phase == EMars_CookingFeed_Phase::AwaitAdmission && State.Active.IsSet() && State.Active.GetValue().Id.Get_IsSame(InPieceId);
}

// The last release sampled (valid through AwaitAdmission; stale afterwards).
mixin FMars_CookingFeed_Release Get_PendingRelease(const FCk_Handle_CookingFeed& Self)
{
    return Self.Get_Fragment(FMars_Fragment_CookingFeed).PendingRelease;
}

mixin FCk_Handle_Transform Get_ReleaseNode(const FCk_Handle_CookingFeed& Self)
{
    return Self.Get_Fragment(FMars_Fragment_CookingFeed_Params).Spec.Nodes.Release;
}

mixin FCk_Handle_Transform Get_HandNode(const FCk_Handle_CookingFeed& Self)
{
    return Self.Get_Fragment(FMars_Fragment_CookingFeed_Params).Spec.Nodes.Hand;
}

// The station's input dock the feed draws from; invalid for a feed whose caller sets the source.
mixin FCk_Handle_PlatterDock Get_InputDock(const FCk_Handle_CookingFeed& Self)
{
    return Self.Get_Fragment(FMars_Fragment_CookingFeed_Params).Spec.Nodes.InputDock;
}

// Where the reserved piece is; unset while idle.
mixin TOptional<EMars_CookingFeed_PieceHold> TryGet_PieceHold(const FCk_Handle_CookingFeed& Self)
{
    const auto& Active = Self.Get_Fragment(FMars_Fragment_CookingFeed).Active;
    if (Active.IsSet() == false)
    { return TOptional<EMars_CookingFeed_PieceHold>(); }

    return TOptional<EMars_CookingFeed_PieceHold>(Active.GetValue().Hold);
}

//--------------------------------------------------------------------------------------------------------------------------
// Requests
//--------------------------------------------------------------------------------------------------------------------------

mixin void Request_BeginTransfer(FCk_Handle_CookingFeed& Self, const FMars_Request_CookingFeed_BeginTransfer& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_CookingFeed_Requests);
    Requests.BeginTransferRequests.Add(InRequest);
}

mixin void Request_Cancel(FCk_Handle_CookingFeed& Self, const FMars_Request_CookingFeed_Cancel& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_CookingFeed_Requests);
    Requests.CancelRequests.Add(InRequest);
}

mixin void Request_Reset(FCk_Handle_CookingFeed& Self, const FMars_Request_CookingFeed_Reset& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_CookingFeed_Requests);
    Requests.ResetRequests.Add(InRequest);
}

mixin void Request_SetSource(FCk_Handle_CookingFeed& Self, const FMars_Request_CookingFeed_SetSource& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_CookingFeed_Requests);
    Requests.SetSourceRequests.Add(InRequest);
}

mixin void Request_ResolveAdmission(FCk_Handle_CookingFeed& Self, const FMars_Request_CookingFeed_ResolveAdmission& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_CookingFeed_Requests);
    Requests.ResolveAdmissionRequests.Add(InRequest);
}

//--------------------------------------------------------------------------------------------------------------------------
// Signal Binding
//--------------------------------------------------------------------------------------------------------------------------

mixin void BindTo_OnStockChanged(FCk_Handle_CookingFeed& Self, FMars_Delegate_CookingFeed_OnStockChanged InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_CookingFeed_Signals);
    Fragment.OnStockChanged.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnStockChanged(FCk_Handle_CookingFeed& Self, FMars_Delegate_CookingFeed_OnStockChanged InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_CookingFeed_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_CookingFeed_Signals).OnStockChanged.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void BindTo_OnPhaseChanged(FCk_Handle_CookingFeed& Self, FMars_Delegate_CookingFeed_OnPhaseChanged InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_CookingFeed_Signals);
    Fragment.OnPhaseChanged.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnPhaseChanged(FCk_Handle_CookingFeed& Self, FMars_Delegate_CookingFeed_OnPhaseChanged InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_CookingFeed_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_CookingFeed_Signals).OnPhaseChanged.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void BindTo_OnReleaseRequested(FCk_Handle_CookingFeed& Self, FMars_Delegate_CookingFeed_OnReleaseRequested InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_CookingFeed_Signals);
    Fragment.OnReleaseRequested.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnReleaseRequested(FCk_Handle_CookingFeed& Self, FMars_Delegate_CookingFeed_OnReleaseRequested InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_CookingFeed_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_CookingFeed_Signals).OnReleaseRequested.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void BindTo_OnTransferSettled(FCk_Handle_CookingFeed& Self, FMars_Delegate_CookingFeed_OnTransferSettled InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_CookingFeed_Signals);
    Fragment.OnTransferSettled.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnTransferSettled(FCk_Handle_CookingFeed& Self, FMars_Delegate_CookingFeed_OnTransferSettled InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_CookingFeed_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_CookingFeed_Signals).OnTransferSettled.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void BindTo_OnTransferRefused(FCk_Handle_CookingFeed& Self, FMars_Delegate_CookingFeed_OnTransferRefused InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_CookingFeed_Signals);
    Fragment.OnTransferRefused.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnTransferRefused(FCk_Handle_CookingFeed& Self, FMars_Delegate_CookingFeed_OnTransferRefused InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_CookingFeed_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_CookingFeed_Signals).OnTransferRefused.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void BindTo_OnPieceLetGo(FCk_Handle_CookingFeed& Self, FMars_Delegate_CookingFeed_OnPieceLetGo InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_CookingFeed_Signals);
    Fragment.OnPieceLetGo.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnPieceLetGo(FCk_Handle_CookingFeed& Self, FMars_Delegate_CookingFeed_OnPieceLetGo InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_CookingFeed_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_CookingFeed_Signals).OnPieceLetGo.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}
