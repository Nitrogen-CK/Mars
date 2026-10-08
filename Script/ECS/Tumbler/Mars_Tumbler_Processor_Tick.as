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
// it moved while the hatch is shut), the hatch (settled when its Mover rests), the hover (a free hand only) and the hand
// (following the cursor, reaching for the lever and gripping it, or riding the grip). Edges are broadcast last. The pieces
// are dynamic bodies tumbled by the kinematic shell that follows the axle: the simulation moves them, the kernel only reads
// them (and teleports an escaped one).
class UMars_Processor_Tumbler_Tick : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";

    // A hitch must not throw the hand across the reach in one step.
    private const float32 k_MaxStepSeconds = 0.1f;
    // The hand node's offset is rewritten only past this much change (cm, and unit-axis distance for the rotation).
    private const float64 k_HandWriteTolerance = 0.01;

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_Tumbler);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle, FMars_Fragment_Tumbler& InState)
    {
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
        Advance_Hatch(Frame, InState);
        Advance_Hover(Frame, InState);
        Advance_Hand(Frame, InState);

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
                if (Piece.Coverage >= 1.0f)
                { ck::Trace(f"[Tumbler] [{InFrame.Tumbler.ToString()}] piece {utils_cooking_feed::Get_PieceName(Piece.Id)} is fully coated"); }
            }

            InState.Pieces[Index] = Piece;
        }
    }

    // Teleports InPiece (at InLocal in the drum frame) to its slot's reseat point at the drum's world bottom, level with the
    // root and at rest. Returns the reseat point (the next step is measured from it, so the jump coats nothing).
    private FVector Reseat(const FMars_Tumbler_Frame& InFrame, const FMars_Tumbler_PieceState& InPiece, FVector InLocal)
    {
        const auto AxleLocation = InFrame.RootWorld.InverseTransformPosition(InFrame.AxleWorld.GetLocation());
        const auto Offset = utils_tumbler::Get_ReseatOffset(InPiece.Id.StockIndex, InFrame.Spec);
        const auto ReseatWorld = InFrame.RootWorld.TransformPosition(AxleLocation + Offset);

        // The default velocity policy zeroes both velocities.
        auto Body = InPiece.Body;
        utils_jolt_body::Request_Teleport(Body, FCk_Request_JoltBody_Teleport(ReseatWorld, InFrame.RootWorld.Rotator()));

        ck::Trace(f"[Tumbler] [{InFrame.Tumbler.ToString()}] piece {utils_cooking_feed::Get_PieceName(InPiece.Id)} escaped the shell "
            + f"(drum frame {InLocal}): reseated at the bottom");
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
        ck::Trace(f"[Tumbler] [{InFrame.Tumbler.ToString()}] hatch {Settled :n}");
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
                auto Manipulator = InFrame.Tumbler;
                Lever.Request_BeginManipulation(FMars_Request_Control_BeginManipulation(
                    FCk_Handle_Interaction(), Manipulator.H(), EMars_Control_ManipulationCompletion::OnRelease));
                Hand.Mode = EMars_Tumbler_HandMode::Gripped;
                Hand.HandLocal = GripLocal;
                Hand.HandRotationLocal = GripRotationLocal;
                ck::Trace(f"[Tumbler] [{InFrame.Tumbler.ToString()}] grip begins at {InState.DrumDegrees :.1} degrees");
            }
        }
        else
        {
            Hand.HandLocal = GripLocal;
            Hand.HandRotationLocal = GripRotationLocal;
        }

        InState.Hand = Hand;
        Write_HandOffset(InFrame, Hand);
    }

    private void Write_HandOffset(const FMars_Tumbler_Frame& InFrame, const FMars_Tumbler_HandState& InHand)
    {
        auto Node = InFrame.Spec.Nodes.Hand;
        const auto Current = utils_scene_node::Get_Offset(Node);
        const auto CurrentRotation = Current.GetRotation();
        const auto Moved = (Current.GetLocation() - InHand.HandLocal).Size() > k_HandWriteTolerance;
        const auto Turned = (CurrentRotation.GetForwardVector() - InHand.HandRotationLocal.GetForwardVector()).Size() > k_HandWriteTolerance
            || (CurrentRotation.GetUpVector() - InHand.HandRotationLocal.GetUpVector()).Size() > k_HandWriteTolerance;
        if (Moved == false && Turned == false)
        { return; }

        auto Offset = Current;
        Offset.SetLocation(InHand.HandLocal);
        Offset.SetRotation(InHand.HandRotationLocal);
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

        if (Drum != InEdges.StartDrum && Tumbler.Has_Fragment(FMars_Fragment_Tumbler_Signals))
        { Tumbler.Get_Fragment(FMars_Fragment_Tumbler_Signals).OnDrumChanged.Broadcast(Tumbler, Drum); }

        for (int32 Index = 0; Index < InEdges.CoverageIds.Num(); ++Index)
        {
            if (Tumbler.Has_Fragment(FMars_Fragment_Tumbler_Signals) == false)
            { return; }

            Tumbler.Get_Fragment(FMars_Fragment_Tumbler_Signals).OnCoverageChanged.Broadcast(Tumbler, InEdges.CoverageIds[Index], InEdges.Coverages[Index]);
        }

        for (const auto& ReseatId : InEdges.ReseatIds)
        {
            if (Tumbler.Has_Fragment(FMars_Fragment_Tumbler_Signals) == false)
            { return; }

            Tumbler.Get_Fragment(FMars_Fragment_Tumbler_Signals).OnPieceReseated.Broadcast(Tumbler, ReseatId);
        }

        if (Hatch != InEdges.StartHatch && Tumbler.Has_Fragment(FMars_Fragment_Tumbler_Signals))
        { Tumbler.Get_Fragment(FMars_Fragment_Tumbler_Signals).OnHatchChanged.Broadcast(Tumbler, Hatch); }

        if (Hovered != InEdges.StartHovered && Tumbler.Has_Fragment(FMars_Fragment_Tumbler_Signals))
        { Tumbler.Get_Fragment(FMars_Fragment_Tumbler_Signals).OnHoverChanged.Broadcast(Tumbler, Hovered); }

        if (Mode != InEdges.StartMode && Tumbler.Has_Fragment(FMars_Fragment_Tumbler_Signals))
        { Tumbler.Get_Fragment(FMars_Fragment_Tumbler_Signals).OnHandModeChanged.Broadcast(Tumbler, Mode); }
    }
}
