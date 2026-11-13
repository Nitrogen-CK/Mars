// What every step of one Tumbler's tick reads: the kernel, its spec, the frame's clamped time, and the station and drum
// frames as of the last transform update.
struct FMars_Tumbler_Frame
{
    FCk_Handle_Tumbler Tumbler;
    FMars_Tumbler_Spec Spec;
    float32 DeltaSeconds = 0.0f;
    FTransform RootWorld;
    FTransform AxleWorld;
}

// The tick's edges, broadcast once the whole tick applied (so a handler reads the written state).
struct FMars_Tumbler_TickEdges
{
    EMars_Tumbler_HandMode StartMode = EMars_Tumbler_HandMode::Free;
    EMars_Tumbler_Target StartHovered = EMars_Tumbler_Target::None;
    EMars_Tumbler_Hatch StartHatch = EMars_Tumbler_Hatch::Closed;
    EMars_Tumbler_Drum StartDrum = EMars_Tumbler_Drum::Home;
    // In parallel: each piece whose coverage grew this frame and its new coverage.
    TArray<FMars_CookingFeed_PieceId> CoverageIds;
    TArray<float32> Coverages;
    // Each piece reseated this frame.
    TArray<FMars_CookingFeed_PieceId> ReseatIds;
}

// Every frame, in order: the drum (its turn from the axle Mover and its state from the lever's grip and the Mover's rest),
// the pieces (each read back from its body: an escaped one is reseated at the drum's bottom, any other coats by the distance
// it moved while the hatch is shut), the station's take-out readout (every tumbled piece, written on change), the hatch
// (settled when its Mover rests), the hover (a free hand only) and the hand (following the cursor, reaching for the lever
// and gripping it, or riding the grip). With authority it then publishes the kernel's ledger and, paced (at once on a hand
// mode or drum edge), the motion ledger; edges are broadcast last. The pieces are dynamic bodies tumbled by the kinematic
// shell that follows the axle: the simulation moves them, the kernel only reads them (and teleports an escaped one).
//
// Without authority it only follows, from the ledgers: this copy's axle Mover is scrubbed toward the motion ledger's alpha
// (eased) and asked to settle once the kernel's ledger reads Home and the eased alpha has arrived; the hand node's offset is
// written from the motion ledger's pose by the same rule; a row this copy has not announced is announced once its piece is a
// food piece here (OnPieceAdded, so the station dresses it), and a row the ledger dropped is forgotten. It reads no body,
// coats, reseats, judges or writes the readout; its hinge follows the commands the mirror gives it.
class UMars_Processor_Tumbler_Tick : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _RunAfter.Add(n"/Script/Angelscript.Mars_Processor_Tumbler_HandleRequests");

    // A hitch must not throw the hand across the reach in one step.
    private const float32 k_MaxStepSeconds = 0.1f;
    // Without authority: per second, the shown drum eases toward the motion ledger's alpha with 1 - exp(-rate * dt); it is
    // scrubbed into the axle Mover once it moved more than k_DrumScrubAlpha, and settled once within k_DrumSettleAlpha of
    // the ledger's alpha while the kernel's ledger reads Home.
    private const float64 k_DrumFollowRate = 20.0;
    private const float32 k_DrumScrubAlpha = 0.0005f;
    private const float32 k_DrumSettleAlpha = 0.002f;

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_Tumbler);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle, FMars_Fragment_Tumbler& InState)
    {
        if (utils_net::Get_HasAuthority(InHandle) == false)
        {
            auto Tumbler = InHandle.As_Tumbler();
            const auto DeltaSeconds = Math::Min(float32(InDeltaT.Get_Seconds()), k_MaxStepSeconds);
            Follow_Drum(Tumbler, DeltaSeconds);
            Follow_Hand(Tumbler);
            Announce(Tumbler);
            return;
        }

        auto Frame = FMars_Tumbler_Frame();
        Frame.Tumbler = InHandle.As_Tumbler();
        Frame.Spec = Frame.Tumbler.Get_Spec();
        Frame.DeltaSeconds = Math::Min(float32(InDeltaT.Get_Seconds()), k_MaxStepSeconds);
        Frame.RootWorld = Frame.Tumbler.Get_RootWorld();
        Frame.AxleWorld = Frame.Tumbler.Get_AxleWorld();

        auto Edges = FMars_Tumbler_TickEdges();
        Edges.StartMode = InState.Hand.Mode;
        Edges.StartHovered = InState.Hovered;
        Edges.StartHatch = InState.Hatch;
        Edges.StartDrum = InState.Drum;

        Advance_Drum(Frame, InState);
        Advance_Pieces(Frame, InState, Edges);
        utils_cooking_feed::Write_Takeable(InHandle, utils_tumbler::Get_Takeable(InState.Pieces, Frame.Spec.Coating));
        Advance_Hatch(Frame, InState);
        Advance_Hover(Frame, InState);
        Advance_Hand(Frame, InState);

        InHandle.Get_Fragment(FMars_Fragment_Tumbler_Local).SecondsSinceMotion += Frame.DeltaSeconds;
        utils_tumbler::Publish(Frame.Tumbler, FMars_Tumbler_Answers());
        const auto IsEdge = InState.Hand.Mode != Edges.StartMode || InState.Drum != Edges.StartDrum;
        utils_tumbler::Publish_Motion(Frame.Tumbler, InState, IsEdge ? EMars_Tumbler_MotionWrite::AtOnce : EMars_Tumbler_MotionWrite::Paced);
        Broadcast(Frame, InState, Edges);
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Drum
    //----------------------------------------------------------------------------------------------------------------------

    // Gripped needs both the kernel's grip and the Control's: a release the Control has not drained yet must not read as a
    // grip again, and a grip the Control has not begun yet is not one.
    private void Advance_Drum(const FMars_Tumbler_Frame& InFrame, FMars_Fragment_Tumbler& InState)
    {
        const auto& Lever = InFrame.Spec.Nodes.Lever;
        const auto Mover = Lever.Get_Mover();
        InState.DrumDegrees = Mover.Get_Alpha() * InFrame.Spec.Drum.ArcDegrees;

        if (InState.Hand.Mode == EMars_Tumbler_HandMode::Gripped && Lever.Get_IsManipulating())
        { InState.Drum = EMars_Tumbler_Drum::Gripped; }
        else if (utils_tumbler::Get_DrumAtRest(Mover))
        { InState.Drum = EMars_Tumbler_Drum::Home; }
        else
        { InState.Drum = EMars_Tumbler_Drum::Returning; }
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Pieces
    //----------------------------------------------------------------------------------------------------------------------

    // Each piece is read back from its body. One whose centre (in the drum frame) is past the shell's inner radius or its
    // end discs by more than Drum.EscapeMarginCm is reseated (no failure state); any other coats by the distance its centre
    // moved since the last tick while the hatch is shut, a step under Coating.MinStepCm being solver jitter, not tumbling.
    // Only a piece that actually tumbles coats: one jammed against a baffle stays pale.
    private void Advance_Pieces(const FMars_Tumbler_Frame& InFrame, FMars_Fragment_Tumbler& InState, FMars_Tumbler_TickEdges& OutEdges)
    {
        const auto& Spec = InFrame.Spec;
        const auto Coating = InState.Hatch == EMars_Tumbler_Hatch::Closed;
        const auto MaxRadius = float64(Spec.Drum.InnerRadius + Spec.Drum.EscapeMarginCm);
        const auto MaxAxial = float64(Spec.Drum.HalfLength + Spec.Shell.DiscGap + Spec.Drum.EscapeMarginCm);
        for (int32 Index = 0; Index < InState.Pieces.Num(); ++Index)
        {
            auto Piece = InState.Pieces[Index];

            // A piece whose entity is gone is going with a station torn down around it.
            if (ck::Is_NOT_Valid(Piece.Entity))
            { continue; }

            // An adopted piece is read only once its body is in the simulation: until then its entity may still stand where
            // it waited before the release pose reached it.
            if (utils_jolt_body::Get_IsBodyAdded(Piece.Body) == false)
            { continue; }

            const auto PieceWorld = utils_transform::Get_EntityCurrentLocation(Piece.Entity.As_Transform());
            const auto Local = InFrame.AxleWorld.InverseTransformPosition(PieceWorld);
            const auto Radial = FVector2D(Local.X, Local.Z).Size();
            if (Radial > MaxRadius || Math::Abs(Local.Y) > MaxAxial)
            {
                Piece.LastWorld = Reseat(InFrame, Piece, Local);
                InState.Pieces[Index] = Piece;
                InState.Reseats += 1;
                OutEdges.ReseatIds.Add(Piece.Id);
                continue;
            }

            const auto Step = (PieceWorld - Piece.LastWorld).Size();
            Piece.LastWorld = PieceWorld;
            if (Coating && Step >= float64(Spec.Coating.MinStepCm) && Piece.Coverage < 1.0f)
            {
                Piece.Coverage = Math::Min(1.0f, Piece.Coverage + float32(Step) * Spec.Coating.CoveragePerCm);
                OutEdges.CoverageIds.Add(Piece.Id);
                OutEdges.Coverages.Add(Piece.Coverage);
            }

            InState.Pieces[Index] = Piece;
        }
    }

    // Teleports InPiece (at InLocal in the drum frame) to the reseat point at the drum's world bottom in line with where it
    // escaped along the axle, level with the root and at rest. Returns the reseat point (the next step is measured from it,
    // so the jump coats nothing).
    private FVector Reseat(const FMars_Tumbler_Frame& InFrame, const FMars_Tumbler_PieceState& InPiece, FVector InLocal)
    {
        const auto AxleLocation = InFrame.RootWorld.InverseTransformPosition(InFrame.AxleWorld.GetLocation());
        const auto Offset = utils_tumbler::Get_ReseatOffset(InLocal.Y, InFrame.Spec);
        const auto ReseatWorld = InFrame.RootWorld.TransformPosition(AxleLocation + Offset);

        // The default velocity policy zeroes both velocities.
        auto Body = InPiece.Body;
        utils_jolt_body::Request_Teleport(Body, FCk_Request_JoltBody_Teleport(ReseatWorld, InFrame.RootWorld.Rotator()));

        return ReseatWorld;
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Hatch
    //----------------------------------------------------------------------------------------------------------------------

    private void Advance_Hatch(const FMars_Tumbler_Frame& InFrame, FMars_Fragment_Tumbler& InState)
    {
        if (InState.Hatch != EMars_Tumbler_Hatch::Opening && InState.Hatch != EMars_Tumbler_Hatch::Closing)
        { return; }

        const auto& Hatch = InFrame.Spec.Nodes.Hatch;
        if (Hatch.Get_IsResting() == false)
        { return; }

        const auto Settled = utils_tumbler::Get_HatchFromMover(Hatch);
        const auto Expected = InState.Hatch == EMars_Tumbler_Hatch::Opening ? EMars_Tumbler_Hatch::Open : EMars_Tumbler_Hatch::Closed;
        if (Settled != Expected)
        { return; }

        InState.Hatch = Settled;
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Hover and hand
    //----------------------------------------------------------------------------------------------------------------------

    // Free: the target whose anchor's YZ projection lies within its radius of the cursor's plane point, nearest first, a tie
    // to the hatch. Reaching and Gripped stay on the lever.
    private void Advance_Hover(const FMars_Tumbler_Frame& InFrame, FMars_Fragment_Tumbler& InState)
    {
        if (InState.Hand.Mode != EMars_Tumbler_HandMode::Free)
        {
            InState.Hovered = EMars_Tumbler_Target::Lever;
            return;
        }

        const auto Point = utils_tumbler::Get_PlanePoint(InFrame.Spec.Hand, InState.Hand.Cursor);
        const auto& Targets = InFrame.Spec.Targets;
        const auto HatchDistance = Get_PlaneDistance(Point, Get_AnchorLocal(InFrame, InFrame.Spec.Nodes.HatchTab));
        const auto LeverDistance = Get_PlaneDistance(Point, Get_AnchorLocal(InFrame, InFrame.Spec.Nodes.LeverGrip));
        const auto OnHatch = HatchDistance <= float64(Targets.HatchRadius);
        const auto OnLever = LeverDistance <= float64(Targets.LeverRadius);

        if (OnHatch && (OnLever == false || HatchDistance <= LeverDistance))
        { InState.Hovered = EMars_Tumbler_Target::Hatch; }
        else if (OnLever)
        { InState.Hovered = EMars_Tumbler_Target::Lever; }
        else
        { InState.Hovered = EMars_Tumbler_Target::None; }
    }

    // Free: eases toward the cursor's plane point, or the hovered anchor (depth included), in the pointing frame. Reaching:
    // eased travel to the lever grip, gripping it (OnRelease: a held crank never engages) when it arrives. Gripped: on the
    // grip.
    private void Advance_Hand(const FMars_Tumbler_Frame& InFrame, FMars_Fragment_Tumbler& InState)
    {
        auto Hand = InState.Hand;
        const auto& Nodes = InFrame.Spec.Nodes;
        const auto GripWorld = utils_transform::Get_EntityCurrentTransform(Nodes.LeverGrip);
        const auto GripLocal = InFrame.RootWorld.InverseTransformPosition(GripWorld.GetLocation());
        const auto GripRotationLocal = InFrame.RootWorld.InverseTransformRotation(GripWorld.GetRotation());

        if (Hand.Mode == EMars_Tumbler_HandMode::Free)
        {
            auto Target = utils_tumbler::Get_PlanePoint(InFrame.Spec.Hand, Hand.Cursor);
            if (InState.Hovered == EMars_Tumbler_Target::Hatch)
            { Target = Get_AnchorLocal(InFrame, Nodes.HatchTab); }
            else if (InState.Hovered == EMars_Tumbler_Target::Lever)
            { Target = GripLocal; }

            const auto Follow = 1.0 - Math::Exp(-float64(InFrame.Spec.Hand.FollowRate) * float64(InFrame.DeltaSeconds));
            Hand.HandLocal = Hand.HandLocal + (Target - Hand.HandLocal) * Follow;
            Hand.HandRotationLocal = FQuat::Slerp(Hand.HandRotationLocal, utils_tumbler::Get_FreeRotation(), Follow);
        }
        else if (Hand.Mode == EMars_Tumbler_HandMode::Reaching)
        {
            Hand.ReachElapsed += InFrame.DeltaSeconds;
            const auto ReachSeconds = InFrame.Spec.Hand.ReachSeconds;
            const auto Linear = ReachSeconds > 0.0f ? Hand.ReachElapsed / ReachSeconds : 1.0f;
            const auto Alpha = utils_tumbler::Get_InOutSine(Linear);
            Hand.HandLocal = Hand.ReachFrom + (GripLocal - Hand.ReachFrom) * float64(Alpha);
            Hand.HandRotationLocal = FQuat::Slerp(Hand.ReachFromRotation, GripRotationLocal, float64(Alpha));

            if (Linear >= 1.0f)
            {
                auto Lever = Nodes.Lever;
                Lever.Request_BeginManipulation(FMars_Request_Control_BeginManipulation(
                    FCk_Handle_Interaction(), EMars_Control_ManipulationCompletion::OnRelease));
                Hand.Mode = EMars_Tumbler_HandMode::Gripped;
                Hand.HandLocal = GripLocal;
                Hand.HandRotationLocal = GripRotationLocal;
            }
        }
        else
        {
            Hand.HandLocal = GripLocal;
            Hand.HandRotationLocal = GripRotationLocal;
        }

        InState.Hand = Hand;
        Write_HandOffset(InFrame.Spec.Nodes.Hand, Hand.HandLocal, Hand.HandRotationLocal);
    }

    // The one write rule for the hand node's offset, with authority (from the kernel's hand) and without (from the motion
    // ledger): rewritten only past utils_tumbler::k_HandWriteTolerance of change.
    private void Write_HandOffset(FCk_Handle_SceneNode InNode, FVector InHandLocal, FQuat InHandRotationLocal)
    {
        auto Node = InNode;
        const auto Current = utils_scene_node::Get_Offset(Node);
        const auto Moved = (Current.GetLocation() - InHandLocal).Size() > utils_tumbler::k_HandWriteTolerance;
        const auto Turned = utils_tumbler::Get_IsTurned(Current.GetRotation(), InHandRotationLocal);
        if (Moved == false && Turned == false)
        { return; }

        auto Offset = Current;
        Offset.SetLocation(InHandLocal);
        Offset.SetRotation(InHandRotationLocal);
        utils_scene_node::Request_UpdateOffset(Node, FCk_Request_SceneNode_UpdateRelativeTransform(Offset));
    }

    // InAnchor's location in the station frame.
    private FVector Get_AnchorLocal(const FMars_Tumbler_Frame& InFrame, const FCk_Handle_Transform& InAnchor) const
    {
        return InFrame.RootWorld.InverseTransformPosition(utils_transform::Get_EntityCurrentLocation(InAnchor));
    }

    // Distance on the reach plane: depth (X) ignored.
    private float64 Get_PlaneDistance(FVector InA, FVector InB) const
    {
        return FVector2D(InA.Y - InB.Y, InA.Z - InB.Z).Size();
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Without authority
    //----------------------------------------------------------------------------------------------------------------------

    // The shown alpha eases toward the motion ledger's; this machine's axle Mover is scrubbed to it once it moved more than
    // k_DrumScrubAlpha (or, while following, once the Mover stands that far from it), and asked to settle once when the
    // kernel's ledger reads Home and the shown alpha has arrived. The local state is written back before any request.
    private void Follow_Drum(FCk_Handle_Tumbler& InTumbler, float32 InDeltaSeconds)
    {
        const auto TargetAlpha = InTumbler.Get_Fragment(FMars_Fragment_Tumbler_MotionNet).DrumAlpha;
        const auto IsHome = InTumbler.Get_Fragment(FMars_Fragment_Tumbler_Net).Drum == EMars_Tumbler_Drum::Home;
        auto Local = InTumbler.Get_Fragment(FMars_Fragment_Tumbler_Local);
        auto Axle = InTumbler.Get_Spec().Nodes.Lever.Get_Mover();

        const auto Follow = float32(1.0 - Math::Exp(-k_DrumFollowRate * float64(InDeltaSeconds)));
        const auto Step = (TargetAlpha - Local.ShownDrumAlpha) * Follow;
        Local.ShownDrumAlpha += Step;
        const auto IsFollowing = Local.DrumShown == EMars_Tumbler_DrumShown::Following;
        const auto IsScrub = Math::Abs(Step) > k_DrumScrubAlpha
            || (IsFollowing && Math::Abs(Local.ShownDrumAlpha - Axle.Get_Alpha()) > k_DrumScrubAlpha);
        if (IsScrub)
        { Local.DrumShown = EMars_Tumbler_DrumShown::Following; }

        const auto IsSettle = IsHome && Local.DrumShown == EMars_Tumbler_DrumShown::Following
            && Math::Abs(Local.ShownDrumAlpha - TargetAlpha) <= k_DrumSettleAlpha;
        if (IsSettle)
        { Local.DrumShown = EMars_Tumbler_DrumShown::Settled; }

        auto& Stored = InTumbler.Get_Fragment(FMars_Fragment_Tumbler_Local);
        Stored.ShownDrumAlpha = Local.ShownDrumAlpha;
        Stored.DrumShown = Local.DrumShown;

        if (IsScrub)
        { Axle.Request_Scrub(FMars_Request_Mover_Scrub(Local.ShownDrumAlpha)); }

        if (IsSettle)
        { Axle.Request_Settle(FMars_Request_Mover_Settle()); }
    }

    // The hand node's offset from the motion ledger's pose, by the authority's own write rule.
    private void Follow_Hand(FCk_Handle_Tumbler& InTumbler)
    {
        const auto Motion = InTumbler.Get_Fragment(FMars_Fragment_Tumbler_MotionNet);
        Write_HandOffset(InTumbler.Get_Spec().Nodes.Hand, Motion.HandLocal, Motion.HandRotationLocal);
    }

    // The announcements written back before anything is raised: no fragment reference is held across a broadcast.
    private void Announce(FCk_Handle_Tumbler& InTumbler)
    {
        const auto Ledger = InTumbler.Get_Fragment(FMars_Fragment_Tumbler_Net);
        const auto Previous = InTumbler.Get_Fragment(FMars_Fragment_Tumbler_Local).Announced;

        TArray<FMars_CookingFeed_PieceId> Announced;
        for (const auto& Id : Previous)
        {
            if (utils_tumbler::Find_RowIndex(Ledger.Pieces, Id).IsSet())
            { Announced.Add(Id); }
        }

        TArray<FMars_CookingFeed_PieceId> AddedIds;
        TArray<FCk_Handle> AddedPieces;
        for (const auto& Row : Ledger.Pieces)
        {
            if (Get_IsAnnounced(Announced, Row.Id) || Get_IsShownHere(Row.Piece) == false)
            { continue; }

            Announced.Add(Row.Id);
            AddedIds.Add(Row.Id);
            AddedPieces.Add(Row.Piece);
        }

        InTumbler.Get_Fragment(FMars_Fragment_Tumbler_Local).Announced = Announced;
        if (AddedIds.Num() == 0 || InTumbler.Has_Fragment(FMars_Fragment_Tumbler_Signals) == false)
        { return; }

        // Handlers keep the station's piece records: scope the script world to the station's, and read the signals fragment
        // again for every broadcast.
        const auto WorldContext = FAngelscriptGameThreadScopeWorldContext(utils_entity_lifetime::Get_WorldForEntity(InTumbler));
        for (int32 Index = 0; Index < AddedIds.Num(); ++Index)
        {
            if (InTumbler.Has_Fragment(FMars_Fragment_Tumbler_Signals))
            { InTumbler.Get_Fragment(FMars_Fragment_Tumbler_Signals).OnPieceAdded.Broadcast(InTumbler, AddedIds[Index], AddedPieces[Index]); }
        }
    }

    private bool Get_IsAnnounced(const TArray<FMars_CookingFeed_PieceId>& InAnnounced, const FMars_CookingFeed_PieceId& InId) const
    {
        for (const auto& Id : InAnnounced)
        {
            if (Id.Get_IsSame(InId))
            { return true; }
        }

        return false;
    }

    // A row's piece is shown on this machine once its entity replicated here as a food piece that is not gone.
    private bool Get_IsShownHere(const FCk_Handle& InPiece) const
    {
        if (utils_foodpiece::Get_IsLiveEntity(InPiece) == false || InPiece.Is_FoodPiece() == false)
        { return false; }

        return InPiece.As_FoodPiece().Get_IsGone() == false;
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Signals
    //----------------------------------------------------------------------------------------------------------------------

    private void Broadcast(const FMars_Tumbler_Frame& InFrame, const FMars_Fragment_Tumbler& InState, const FMars_Tumbler_TickEdges& InEdges)
    {
        auto Tumbler = InFrame.Tumbler;
        if (Tumbler.Has_Fragment(FMars_Fragment_Tumbler_Signals) == false)
        { return; }

        const auto Mode = InState.Hand.Mode;
        const auto Hovered = InState.Hovered;
        const auto Hatch = InState.Hatch;
        const auto Drum = InState.Drum;

        // Each broadcast re-reads the fragment: a listener may grow the signal storage under a held reference.
        if (Drum != InEdges.StartDrum)
        { Tumbler.Get_Fragment(FMars_Fragment_Tumbler_Signals).OnDrumChanged.Broadcast(Tumbler, Drum); }

        for (int32 Index = 0; Index < InEdges.CoverageIds.Num(); ++Index)
        { Tumbler.Get_Fragment(FMars_Fragment_Tumbler_Signals).OnCoverageChanged.Broadcast(Tumbler, InEdges.CoverageIds[Index], InEdges.Coverages[Index]); }

        for (const auto& ReseatId : InEdges.ReseatIds)
        { Tumbler.Get_Fragment(FMars_Fragment_Tumbler_Signals).OnPieceReseated.Broadcast(Tumbler, ReseatId); }

        if (Hatch != InEdges.StartHatch)
        { Tumbler.Get_Fragment(FMars_Fragment_Tumbler_Signals).OnHatchChanged.Broadcast(Tumbler, Hatch); }

        if (Hovered != InEdges.StartHovered)
        { Tumbler.Get_Fragment(FMars_Fragment_Tumbler_Signals).OnHoverChanged.Broadcast(Tumbler, Hovered); }

        if (Mode != InEdges.StartMode)
        { Tumbler.Get_Fragment(FMars_Fragment_Tumbler_Signals).OnHandModeChanged.Broadcast(Tumbler, Mode); }
    }
}
