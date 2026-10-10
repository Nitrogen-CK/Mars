// What every step of one feed's tick reads: the feed, its spec and the frame's real time.
struct FMars_CookingFeed_Frame
{
    FCk_Handle_CookingFeed Feed;
    FMars_CookingFeed_Spec Spec;
    float32 DeltaSeconds = 0.0f;
}

// The one clock of the transfer, and the hand that carries the real piece. First it guards the reservation: before the
// release, a reserved piece that is gone or was taken by someone else (unloaded from the source by another hand, the platter
// swapped under it, lifted off the glove) cancels the transfer as a Cancel would. Every positive-dt frame it measures the
// release node's world velocity; an admission no kernel has answered within Timing.AdmissionBudgetSeconds settles
// Rejected, its piece goes back to the platter it came from (or, with none left, is let go where it lies: OnPieceLetGo)
// and the hand turns home; while the hand is in a timed phase it advances the phase time and crosses every boundary the
// frame reaches, each once and in order (a long frame crosses several, a zero-length phase passes through), carrying the
// remainder into the next phase. Entering Grasp asks the source to unload the reserved piece; Carry's end lets the piece go
// where the hand holds it (detached at its world pose) and samples the release (that pose, or the release node's when no
// piece rode the hand; the spec's local velocity rotated to the node plus the inherited node velocity) and waits for the
// admission answer; Return's end idles the hand. With hand geometry in the spec the hand node then takes this frame's pose
// (utils_cooking_feed::Get_HandLocal: rest, the reserved piece's middle as it last lay on its own, the release node), so
// the carry never depends on who draws the glove. Then the piece follows the hand: once its unload has landed (off the
// source, its body Kinematic) it is attached under Nodes.Hand where it is, and through Grasp its offset lerps to
// Motion.HeldOffset. Last, the stock is compared with what was last broadcast: the source changes under the feed without a
// request, so its edges are found here. A feed torn down while it holds a piece (from the grasp until the admission
// answer) ends that piece with it.
class UMars_Processor_CookingFeed_Tick : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _RunAfter.Add(n"/Script/Angelscript.Mars_Processor_CookingFeed_HandleRequests");

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_CookingFeed);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle, FMars_Fragment_CookingFeed& InState)
    {
        auto Frame = FMars_CookingFeed_Frame();
        Frame.Feed = InHandle.As_CookingFeed();
        Frame.Spec = Frame.Feed.Get_Spec();
        Frame.DeltaSeconds = float32(InDeltaT.Get_Seconds());

        Guard_Reservation(Frame, InState);
        Measure_Release(Frame, InState);
        Expire_Admission(Frame, InState);
        Advance_Phase(Frame, InState);
        Move_Hand(Frame, InState);
        Carry_Piece(Frame, InState);
        Broadcast_StockIfChanged(Frame, InState);
    }

    // From Reach through Carry the reserved piece must be where the feed left it: on the source while the hand reaches, on
    // the source or off every platter while it unloads, under the hand once attached. In AwaitAdmission it is released by
    // design and only an answer, a SetSource or the admission budget ends the transfer.
    private void Guard_Reservation(FMars_CookingFeed_Frame& InFrame, FMars_Fragment_CookingFeed& InState)
    {
        const auto IsBeforeRelease = InState.Phase == EMars_CookingFeed_Phase::Reach || InState.Phase == EMars_CookingFeed_Phase::Grasp
            || InState.Phase == EMars_CookingFeed_Phase::Carry;
        if (InState.Active.IsSet() == false || IsBeforeRelease == false)
        { return; }

        const auto Reservation = InState.Active.GetValue();
        if (Get_IsWhereTheFeedLeftIt(InFrame, InState, Reservation))
        { return; }

        utils_cooking_feed::Cancel_Active(InState);

        auto Feed = InFrame.Feed;
        if (Feed.Has_Fragment(FMars_Fragment_CookingFeed_Signals))
        { Feed.Get_Fragment(FMars_Fragment_CookingFeed_Signals).OnTransferSettled.Broadcast(Feed, Reservation.Id, EMars_CookingFeed_Settle::Cancelled); }

        if (Feed.Has_Fragment(FMars_Fragment_CookingFeed_Signals))
        { Feed.Get_Fragment(FMars_Fragment_CookingFeed_Signals).OnPhaseChanged.Broadcast(Feed, EMars_CookingFeed_Phase::Idle); }
    }

    private bool Get_IsWhereTheFeedLeftIt(const FMars_CookingFeed_Frame& InFrame, const FMars_Fragment_CookingFeed& InState,
                                          const FMars_CookingFeed_Reservation& InReservation) const
    {
        const auto& Piece = InReservation.Piece;
        if (InReservation.Hold == EMars_CookingFeed_PieceHold::OnSource)
        { return utils_cooking_feed::Get_IsOnSource(Piece, InState.Source); }

        if (utils_cooking_feed::Get_IsGone(Piece))
        { return false; }

        if (InReservation.Hold == EMars_CookingFeed_PieceHold::Unloading)
        {
            const auto Holder = Piece.TryGet_Holder();
            return ck::Is_NOT_Valid(Holder) || Holder == InState.Source;
        }

        return utils_cooking_feed::Get_IsUnderHand(Piece, InFrame.Spec.Nodes.Hand);
    }

    // A zero-dt frame cannot estimate motion: it leaves the last velocity and pose.
    private void Measure_Release(FMars_CookingFeed_Frame& InFrame, FMars_Fragment_CookingFeed& InState)
    {
        if (InFrame.DeltaSeconds <= 0.0f || ck::Is_NOT_Valid(InFrame.Spec.Nodes.Release))
        { return; }

        const auto Now = utils_transform::Get_EntityCurrentTransform(InFrame.Spec.Nodes.Release);
        if (InState.ReleasePrevWorld.IsSet())
        {
            const auto Previous = InState.ReleasePrevWorld.GetValue();
            InState.ReleaseVelocity = (Now.GetLocation() - Previous.GetLocation()) / float64(InFrame.DeltaSeconds);
        }

        InState.ReleasePrevWorld = TOptional<FTransform>(Now);
    }

    // AwaitAdmission against Timing.AdmissionBudgetSeconds (0 = unbounded): past it the release settles Rejected as an
    // answer would, its piece goes back (or is let go where it lies, broadcast after the settle), and the hand turns home
    // (its Return clock starts this frame, as after an answer).
    private void Expire_Admission(FMars_CookingFeed_Frame& InFrame, FMars_Fragment_CookingFeed& InState)
    {
        const auto Budget = InFrame.Spec.Timing.AdmissionBudgetSeconds;
        if (InState.Phase != EMars_CookingFeed_Phase::AwaitAdmission || Budget <= 0.0f)
        { return; }

        if (ck::EnsureIfNot(InState.Active.IsSet(), f"[CookingFeed] [{InFrame.Feed.ToString()}] awaits an admission with no reserved piece"))
        {
            utils_cooking_feed::Cancel_Active(InState);
            return;
        }

        InState.PhaseSeconds += InFrame.DeltaSeconds;
        if (InState.PhaseSeconds < Budget)
        { return; }

        const auto PieceId = InState.Active.GetValue().Id;
        const auto Piece = InState.Active.GetValue().Piece;
        const auto Returned = utils_cooking_feed::Return_Piece(InState, InFrame.Spec.Nodes.Hand);
        InState.Active.Reset();
        InState.Phase = EMars_CookingFeed_Phase::Return;
        InState.PhaseSeconds = 0.0f;

        auto Feed = InFrame.Feed;
        if (Feed.Has_Fragment(FMars_Fragment_CookingFeed_Signals))
        { Feed.Get_Fragment(FMars_Fragment_CookingFeed_Signals).OnTransferSettled.Broadcast(Feed, PieceId, EMars_CookingFeed_Settle::Rejected); }

        if (Returned == EMars_CookingFeed_PieceReturn::LetGo && Feed.Has_Fragment(FMars_Fragment_CookingFeed_Signals))
        { Feed.Get_Fragment(FMars_Fragment_CookingFeed_Signals).OnPieceLetGo.Broadcast(Feed, Piece); }

        if (Feed.Has_Fragment(FMars_Fragment_CookingFeed_Signals))
        { Feed.Get_Fragment(FMars_Fragment_CookingFeed_Signals).OnPhaseChanged.Broadcast(Feed, EMars_CookingFeed_Phase::Return); }
    }

    private void Advance_Phase(FMars_CookingFeed_Frame& InFrame, FMars_Fragment_CookingFeed& InState)
    {
        if (utils_cooking_feed::Get_IsTimed(InState.Phase) == false)
        { return; }

        InState.PhaseSeconds += InFrame.DeltaSeconds;

        auto Entered = TArray<EMars_CookingFeed_Phase>();
        auto Released = false;
        while (utils_cooking_feed::Get_IsTimed(InState.Phase))
        {
            const auto Duration = utils_cooking_feed::Get_PhaseDuration(InFrame.Spec.Timing, InState.Phase);
            if (InState.PhaseSeconds < Duration)
            { break; }

            InState.PhaseSeconds -= Duration;
            if (InState.Phase == EMars_CookingFeed_Phase::Carry)
            { Released = Sample_Release(InFrame, InState); }

            InState.Phase = Get_NextPhase(InState.Phase);
            Entered.Add(InState.Phase);

            if (InState.Phase == EMars_CookingFeed_Phase::Grasp)
            { Begin_Unload(InFrame, InState); }
        }

        if (utils_cooking_feed::Get_IsTimed(InState.Phase) == false)
        { InState.PhaseSeconds = 0.0f; }

        if (Entered.Num() == 0)
        { return; }

        const auto Release = InState.PendingRelease;

        auto Feed = InFrame.Feed;
        for (const auto Phase : Entered)
        {
            if (Feed.Has_Fragment(FMars_Fragment_CookingFeed_Signals))
            { Feed.Get_Fragment(FMars_Fragment_CookingFeed_Signals).OnPhaseChanged.Broadcast(Feed, Phase); }
        }

        if (Released && Feed.Has_Fragment(FMars_Fragment_CookingFeed_Signals))
        { Feed.Get_Fragment(FMars_Fragment_CookingFeed_Signals).OnReleaseRequested.Broadcast(Feed, Release); }
    }

    // The hand node's pose this frame (with hand geometry only), written on change. The reserved piece's middle is sampled
    // while it lies on its own and is Ready (on the source, or coming off it), so the hand reaches where it lies and never
    // chases itself once the piece rides it; idle forgets it.
    private void Move_Hand(FMars_CookingFeed_Frame& InFrame, FMars_Fragment_CookingFeed& InState)
    {
        if (InFrame.Spec.Hand.IsSet() == false)
        { return; }

        FCk_Handle HandEntity = InFrame.Spec.Nodes.Hand;
        auto HandNode = HandEntity.As_SceneNode();
        const auto ParentWorld = utils_transform::Get_EntityCurrentTransform(utils_scene_node::Get_Parent(HandNode));
        Track_Grasp(InState, ParentWorld);

        auto Query = FMars_CookingFeed_HandQuery();
        Query.Geometry = InFrame.Spec.Hand.GetValue();
        Query.Phase = InState.Phase;
        Query.Progress = InFrame.Feed.Get_PhaseProgress();
        Query.GraspPoint = InState.GraspPoint;
        Query.ReleasePoint = ParentWorld.InverseTransformPosition(utils_transform::Get_EntityCurrentLocation(InFrame.Spec.Nodes.Release));

        const auto HandLocal = utils_cooking_feed::Get_HandLocal(Query);
        if (HandLocal.Equals(utils_scene_node::Get_Offset(HandNode), 0.01))
        { return; }

        utils_scene_node::Request_UpdateOffset(HandNode, FCk_Request_SceneNode_UpdateRelativeTransform(HandLocal));
    }

    private void Track_Grasp(FMars_Fragment_CookingFeed& InState, const FTransform& InParentWorld)
    {
        if (InState.Active.IsSet() == false)
        {
            InState.GraspPoint.Reset();
            return;
        }

        const auto Reservation = InState.Active.GetValue();
        const auto LiesOnItsOwn = Reservation.Hold == EMars_CookingFeed_PieceHold::OnSource || Reservation.Hold == EMars_CookingFeed_PieceHold::Unloading;
        const auto& Piece = Reservation.Piece;
        if (LiesOnItsOwn == false || utils_cooking_feed::Get_IsGone(Piece) || Piece.Get_Status() != EMars_FoodPiece_Status::Ready)
        { return; }

        FCk_Handle Entity = Piece;
        const auto PieceWorld = utils_transform::Get_EntityCurrentTransform(Entity.As_Transform());
        const auto Centre = PieceWorld.TransformPosition(utils_foodpiece::Get_BoundsCentre(utils_runtime_mesh::Get_Metrics(Piece.Get_Geometry())));
        InState.GraspPoint = TOptional<FVector>(InParentWorld.InverseTransformPosition(Centre));
    }

    // The grasp takes the reserved piece off the source; it rides the hand once the unload lands (Carry_Piece). The feed
    // watches its own teardown from here on, so a piece it holds ends with it.
    private void Begin_Unload(FMars_CookingFeed_Frame& InFrame, FMars_Fragment_CookingFeed& InState)
    {
        if (ck::EnsureIfNot(InState.Active.IsSet(), f"[CookingFeed] [{InFrame.Feed.ToString()}] grasped with no reserved piece"))
        { return; }

        auto Reservation = InState.Active.GetValue();
        auto Source = InState.Source;
        if (ck::IsValid(Source) && Reservation.Piece.TryGet_Platter() == Source)
        { Source.Request_Unload(FMars_Request_Platter_Unload(Reservation.Piece)); }

        Reservation.Hold = EMars_CookingFeed_PieceHold::Unloading;
        InState.Active = TOptional<FMars_CookingFeed_Reservation>(Reservation);
        Watch_Teardown(InFrame.Feed);
    }

    // The release at Carry's end, kept in PendingRelease. A piece riding the hand is let go there (detached, keeping its
    // world pose) and released at that pose; one whose unload has not landed yet is released at the release node, as a
    // release built by hand is. False (and nothing kept) without a reservation, which Carry always has.
    private bool Sample_Release(FMars_CookingFeed_Frame& InFrame, FMars_Fragment_CookingFeed& InState)
    {
        if (ck::EnsureIfNot(InState.Active.IsSet(), f"[CookingFeed] [{InFrame.Feed.ToString()}] reached the release with no reserved piece"))
        { return false; }

        auto Reservation = InState.Active.GetValue();
        const auto ReleaseWorld = utils_transform::Get_EntityCurrentTransform(InFrame.Spec.Nodes.Release);
        const auto& Motion = InFrame.Spec.Motion;
        const auto Velocity = ReleaseWorld.GetRotation().RotateVector(Motion.ReleaseVelocityLocal)
            + InState.ReleaseVelocity * float64(Motion.VelocityInheritance);

        auto PieceWorld = ReleaseWorld;
        if (Reservation.Hold == EMars_CookingFeed_PieceHold::InHand)
        {
            FCk_Handle Entity = Reservation.Piece;
            auto Node = Entity.As_SceneNode();
            utils_scene_node::Request_Detach(Node);
            PieceWorld = utils_transform::Get_EntityCurrentTransform(Entity.As_Transform());
        }

        Reservation.Hold = EMars_CookingFeed_PieceHold::Released;
        InState.Active = TOptional<FMars_CookingFeed_Reservation>(Reservation);

        InState.PendingRelease = FMars_CookingFeed_Release(Reservation.Id, PieceWorld, Velocity);
        InState.PendingRelease.Piece = Reservation.Piece;

        return true;
    }

    // Unloading: once the piece is off the source and its body (if any) reads Kinematic, it is attached under the hand where
    // it is (a Dynamic body would fight the attach). InHand, through Grasp: its offset lerps from where it was attached to
    // Motion.HeldOffset (its bounds centre there), and holds there through Carry. One offset request per frame, on change.
    private void Carry_Piece(FMars_CookingFeed_Frame& InFrame, FMars_Fragment_CookingFeed& InState)
    {
        const auto IsCarrying = InState.Phase == EMars_CookingFeed_Phase::Grasp || InState.Phase == EMars_CookingFeed_Phase::Carry;
        if (InState.Active.IsSet() == false || IsCarrying == false)
        { return; }

        auto Reservation = InState.Active.GetValue();
        if (Reservation.Hold == EMars_CookingFeed_PieceHold::Unloading)
        {
            if (Get_HasUnloadLanded(Reservation.Piece) == false)
            { return; }

            Attach_ToHand(InFrame, Reservation);
            InState.Active = TOptional<FMars_CookingFeed_Reservation>(Reservation);
            return;
        }

        if (Reservation.Hold != EMars_CookingFeed_PieceHold::InHand)
        { return; }

        const auto Alpha = InState.Phase == EMars_CookingFeed_Phase::Grasp ? InFrame.Feed.Get_PhaseProgress() : 1.0f;
        const auto Held = Get_HeldRootOffset(InFrame, Reservation.Piece);
        auto Offset = Reservation.HeldFrom;
        Offset.SetLocation(Math::Lerp(Reservation.HeldFrom.GetLocation(), Held.GetLocation(), float64(Alpha)));
        Offset.SetRotation(FQuat::Slerp(Reservation.HeldFrom.GetRotation(), Held.GetRotation(), float64(Alpha)));

        FCk_Handle Entity = Reservation.Piece;
        auto Node = Entity.As_SceneNode();
        if (Offset.Equals(utils_scene_node::Get_Offset(Node), 0.01))
        { return; }

        utils_scene_node::Request_UpdateOffset(Node, FCk_Request_SceneNode_UpdateRelativeTransform(Offset));
    }

    private bool Get_HasUnloadLanded(const FCk_Handle_FoodPiece& InPiece) const
    {
        if (ck::IsValid(InPiece.TryGet_Platter()))
        { return false; }

        FCk_Handle Entity = InPiece;
        auto Body = Entity.As_JoltBody(ECk_SanityCheck::UnChecked);
        return ck::Is_NOT_Valid(Body) || utils_jolt_body::Get_MotionType(Body) == ECk_MotionType::Kinematic;
    }

    // utils_scene_node::Add never re-parents an attached node: a piece still attached somewhere is detached first
    // (immediate, keeps the world pose).
    private void Attach_ToHand(const FMars_CookingFeed_Frame& InFrame, FMars_CookingFeed_Reservation& InOutReservation)
    {
        FCk_Handle Entity = InOutReservation.Piece;
        auto Node = Entity.As_SceneNode(ECk_SanityCheck::UnChecked);
        if (ck::IsValid(Node))
        { utils_scene_node::Request_Detach(Node); }

        auto PieceTransform = Entity.As_Transform();
        auto Hand = InFrame.Spec.Nodes.Hand;
        const auto PieceWorld = utils_transform::Get_EntityCurrentTransform(PieceTransform);
        const auto HandWorld = utils_transform::Get_EntityCurrentTransform(Hand);
        const auto FromOffset = PieceWorld.GetRelativeTransform(HandWorld);
        utils_scene_node::Add(PieceTransform, Hand, FromOffset);

        InOutReservation.Hold = EMars_CookingFeed_PieceHold::InHand;
        InOutReservation.HeldFrom = FromOffset;
    }

    // The piece root's offset under the hand that puts its bounds centre at Motion.HeldOffset's location, in its rotation.
    private FTransform Get_HeldRootOffset(const FMars_CookingFeed_Frame& InFrame, const FCk_Handle_FoodPiece& InPiece) const
    {
        const auto& HeldOffset = InFrame.Spec.Motion.HeldOffset;
        const auto Centre = utils_searing::Get_BoundsCentre(utils_runtime_mesh::Get_Metrics(InPiece.Get_Geometry()));
        return FTransform(HeldOffset.GetRotation(), HeldOffset.GetLocation() - HeldOffset.GetRotation().RotateVector(Centre));
    }

    // One broadcast per edge of (Available, Admitted, settling), after every other step of the frame: a pile that finishes
    // settling changes no count, but the operator's row has to stop saying so.
    private void Broadcast_StockIfChanged(FMars_CookingFeed_Frame& InFrame, FMars_Fragment_CookingFeed& InState)
    {
        const auto Available = utils_cooking_feed::Get_Available(InState);
        const auto Admitted = InState.Admitted;
        const auto IsSettling = utils_cooking_feed::Get_IsSettling(InState);
        if (Available == InState.LastStockAvailable && Admitted == InState.LastStockAdmitted && IsSettling == InState.LastStockSettling)
        { return; }

        InState.LastStockAvailable = Available;
        InState.LastStockAdmitted = Admitted;
        InState.LastStockSettling = IsSettling;

        auto Feed = InFrame.Feed;
        if (Feed.Has_Fragment(FMars_Fragment_CookingFeed_Signals))
        { Feed.Get_Fragment(FMars_Fragment_CookingFeed_Signals).OnStockChanged.Broadcast(Feed, Available, Admitted); }
    }

    private EMars_CookingFeed_Phase Get_NextPhase(EMars_CookingFeed_Phase InPhase) const
    {
        switch (InPhase)
        {
            case EMars_CookingFeed_Phase::Reach: return EMars_CookingFeed_Phase::Grasp;
            case EMars_CookingFeed_Phase::Grasp: return EMars_CookingFeed_Phase::Carry;
            case EMars_CookingFeed_Phase::Carry: return EMars_CookingFeed_Phase::AwaitAdmission;
            default: return EMars_CookingFeed_Phase::Idle;
        }
    }

    private void Watch_Teardown(const FCk_Handle_CookingFeed& InFeed)
    {
        FCk_Handle Feed = InFeed;
        Feed.UnbindFrom_OnBeginDestroy(FCk_Delegate_OnBeginDestroy(this, n"OnFeedBeginDestroy"));
        Feed.BindTo_OnBeginDestroy(FCk_Delegate_OnBeginDestroy(this, n"OnFeedBeginDestroy"));
    }

    // A piece the feed holds (coming off the source, riding the hand, or released and not yet admitted) ends with the station:
    // the platter it came from goes in the same teardown, so nothing could take it back.
    UFUNCTION()
    private void OnFeedBeginDestroy(FCk_Handle InFeed)
    {
        auto FeedEntity = InFeed;
        if (FeedEntity.Has_Fragment(FMars_Fragment_CookingFeed) == false)
        { return; }

        const auto Active = FeedEntity.Get_Fragment(FMars_Fragment_CookingFeed).Active;
        if (Active.IsSet() == false || Active.GetValue().Hold == EMars_CookingFeed_PieceHold::OnSource)
        { return; }

        auto Piece = Active.GetValue().Piece;
        if (utils_cooking_feed::Get_IsGone(Piece))
        { return; }

        utils_entity_lifetime::Request_DestroyEntity(Piece);
    }
}
