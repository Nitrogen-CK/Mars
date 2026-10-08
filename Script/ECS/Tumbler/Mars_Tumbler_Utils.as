// One kinematic part of the drum's shell: its shape and the shell's surface.
struct FMars_Tumbler_ShellPart
{
    FCk_Jolt_ShapeDimensions Shape;
    FMars_Tumbler_SurfaceSpec Surface;

    FMars_Tumbler_ShellPart() {}

    FMars_Tumbler_ShellPart(FCk_Jolt_ShapeDimensions InShape, FMars_Tumbler_SurfaceSpec InSurface)
    {
        Shape = InShape;
        Surface = InSurface;
    }
}

namespace utils_tumbler
{
    // A kinematic body's mass only matters to the solver's contact ratios; it never moves under force.
    const float32 k_KinematicMassKg = 1.0f;
    // Each panel is this much longer than its chord so neighbours overlap at the inner corners and nothing slips between.
    const float64 k_PanelOverlap = 1.02;
    const float64 k_BaffleThickness = 1.5;
    // A reseated piece's lowest face starts this far above the shell's floor.
    const float32 k_ReseatLift = 1.0f;

    // Composes the minigame on InStation (the station entity, which carries the root transform). The spec's Nodes are built
    // by the caller (the shell with Add_DrumBodies, the hatch plate with Add_HatchBody): the hand starts Free at the
    // workspace centre, the hatch and the drum in whatever state their Movers are in. Nothing is in the drum until the first
    // AddPiece. A rejected spec, a missing node, a lever that is not a ManuallyCompleted Control with a Mover, or a hand node
    // not on the station root ensures and returns an invalid handle.
    FCk_Handle_Tumbler Add(FCk_Handle& InStation, FMars_Tumbler_Spec InSpec)
    {
        const auto Validation = InSpec.Validate();
        if (ck::EnsureIfNot(Validation.IsValid(), f"[Tumbler] [{InStation.ToString()}] rejected the spec: {Validation.Get_Error()}"))
        { return FCk_Handle_Tumbler(); }

        const auto& Nodes = InSpec.Nodes;
        const auto NodesAreValid = ck::IsValid(Nodes.Hand) && ck::IsValid(Nodes.HatchTab) && ck::IsValid(Nodes.LeverGrip)
            && ck::IsValid(Nodes.Lever) && ck::IsValid(Nodes.Hatch) && ck::IsValid(Nodes.Drum) && ck::IsValid(Nodes.DrumBody)
            && ck::IsValid(Nodes.View);
        if (ck::EnsureIfNot(NodesAreValid,
            f"[Tumbler] [{InStation.ToString()}] needs the hand, hatch tab, lever grip, lever, hatch, drum, drum body and view nodes"))
        { return FCk_Handle_Tumbler(); }

        if (ck::EnsureIfNot(ck::IsValid(Nodes.Lever.Get_Mover()),
            f"[Tumbler] [{InStation.ToString()}] needs a lever Control with a Mover (the drum)"))
        { return FCk_Handle_Tumbler(); }

        if (ck::EnsureIfNot(Nodes.Lever.Get_CompletionPolicy() == ECk_Interaction_CompletionPolicy::ManuallyCompleted,
            f"[Tumbler] [{InStation.ToString()}] needs a ManuallyCompleted lever (it is gripped), not {Nodes.Lever.Get_CompletionPolicy() :n}"))
        { return FCk_Handle_Tumbler(); }

        // The kernel writes the hand's offset in the station frame.
        const FCk_Handle HandParent = utils_scene_node::Get_Parent(Nodes.Hand);
        if (ck::EnsureIfNot(HandParent == InStation,
            f"[Tumbler] [{InStation.ToString()}] needs the hand node on the station root (its offset is the station-frame hand pose)"))
        { return FCk_Handle_Tumbler(); }

        auto Params = FMars_Fragment_Tumbler_Params();
        Params.Spec = InSpec;

        InStation.Add_Fragment(FMars_Feature_Tumbler());
        InStation.Add_Fragment(Params);

        auto Drum = Nodes.Lever.Get_Mover();
        auto State = FMars_Fragment_Tumbler();
        State.Hand.HandLocal = InSpec.Hand.WorkspaceCentreLocal;
        State.Hand.HandRotationLocal = Get_FreeRotation();
        State.Hatch = Get_HatchFromMover(Nodes.Hatch);
        State.Drum = Get_DrumAtRest(Drum) ? EMars_Tumbler_Drum::Home : EMars_Tumbler_Drum::Returning;
        State.DrumDegrees = Drum.Get_Alpha() * InSpec.Drum.ArcDegrees;
        InStation.Add_Fragment(State);

        ck::Trace(f"[Tumbler] [{InStation.ToString()}] composed: hatch {State.Hatch :n}, drum {State.Drum :n}, capacity {InSpec.Drum.Capacity}");
        return InStation.As_Tumbler();
    }

    // The shell's kinematic bodies under InAxle (the drum frame: the axis along Y, 0 degrees = the bottom at home, -90 = the
    // operator's side): two end discs, Shell.PanelCount tangent panels around the closed arc (their inner faces at
    // Drum.InnerRadius, leaving the hatch gap) and Shell.Baffles.Count ribs on them. Each part is on its own child node (a
    // body needs its own entity) and follows the axle every step, so the axle Mover drives the shell. Returns the first
    // panel. A rejected spec ensures and returns an invalid handle.
    FCk_Handle_JoltBody Add_DrumBodies(FCk_Handle_SceneNode& InAxle, const FMars_Tumbler_Spec& InSpec)
    {
        const auto Validation = InSpec.Validate();
        if (ck::EnsureIfNot(Validation.IsValid(), f"[Tumbler] [{InAxle.ToString()}] rejected the shell's spec: {Validation.Get_Error()}"))
        { return FCk_Handle_JoltBody(); }

        auto Parent = InAxle.As_Transform();
        const auto& Shell = InSpec.Shell;
        const auto Wall = float64(Shell.WallThickness);
        const auto WallRadius = float64(InSpec.Drum.InnerRadius) + Wall * 0.5;
        const auto PanelHalfLength = float64(InSpec.Drum.HalfLength + Shell.DiscGap);

        // Cylinder shapes run along their Z: rolled 90, each disc's axis lies along the axle (Y).
        auto DiscShape = FCk_Jolt_ShapeDimensions(ECk_Jolt_ShapeType::Cylinder);
        DiscShape.Set_Radius(InSpec.Drum.InnerRadius + Shell.WallThickness);
        DiscShape.Set_HalfHeight(Shell.WallThickness * 0.5f);
        const auto Disc = FMars_Tumbler_ShellPart(DiscShape, Shell.Surface);
        for (int32 Side = -1; Side <= 1; Side += 2)
        {
            const auto DiscY = float64(Side) * (PanelHalfLength + Wall * 0.5);
            Add_ShellPart(Parent, FTransform(FRotator(0.0, 0.0, 90.0), FVector(0.0, DiscY, 0.0)), Disc);
        }

        // The closed arc runs from the gap's lower edge round the back to its upper edge.
        const auto GapEnd = float64(Shell.Gap.CentreDegrees + Shell.Gap.HalfDegrees);
        const auto PanelDegrees = Get_ClosedArcDegrees(InSpec) / float64(Shell.PanelCount);
        const auto Panel = Make_ShellBox(FVector(Get_ChordHalfLength(PanelDegrees, WallRadius), PanelHalfLength, Wall * 0.5), Shell.Surface);
        auto FirstPanel = FCk_Handle_JoltBody();
        for (int32 Index = 0; Index < Shell.PanelCount; ++Index)
        {
            const auto Degrees = GapEnd + (float64(Index) + 0.5) * PanelDegrees;
            const auto Body = Add_ShellPart(Parent, Get_RingPose(float32(Degrees), float32(WallRadius)), Panel);
            if (Index == 0)
            { FirstPanel = Body; }
        }

        // Pitched by their angle, so each rib's local Z runs radially (inward) and it stands on the panels' inner faces.
        const auto BaffleHalfHeight = float64(Shell.Baffles.Height) * 0.5;
        const auto BaffleRadius = float32(float64(InSpec.Drum.InnerRadius) - BaffleHalfHeight);
        const auto Baffle = Make_ShellBox(FVector(k_BaffleThickness * 0.5, float64(InSpec.Drum.HalfLength), BaffleHalfHeight), Shell.Surface);
        for (int32 Index = 0; Index < Shell.Baffles.Count; ++Index)
        { Add_ShellPart(Parent, Get_RingPose(Get_BaffleDegrees(InSpec, Index), BaffleRadius), Baffle); }

        ck::Trace(f"[Tumbler] [{InAxle.ToString()}] shell built: {Shell.PanelCount} panels, {Shell.Baffles.Count} baffles, gap "
            + f"{Shell.Gap.CentreDegrees :.1} +/- {Shell.Gap.HalfDegrees :.1} degrees");
        return FirstPanel;
    }

    // The hatch plate's kinematic bodies under InHinge, which the caller placed at Get_HatchHingeLocal (the gap's upper edge)
    // under the axle: Shell.Gap.PlateSegments boxes across the gap on the panels' ring, each positioned relative to the
    // hinge, so the hinge Mover swings the plate. Returns the first segment. A rejected spec ensures and returns an invalid
    // handle.
    FCk_Handle_JoltBody Add_HatchBody(FCk_Handle_SceneNode& InHinge, const FMars_Tumbler_Spec& InSpec)
    {
        const auto Validation = InSpec.Validate();
        if (ck::EnsureIfNot(Validation.IsValid(), f"[Tumbler] [{InHinge.ToString()}] rejected the hatch's spec: {Validation.Get_Error()}"))
        { return FCk_Handle_JoltBody(); }

        auto Parent = InHinge.As_Transform();
        const auto& Shell = InSpec.Shell;
        const auto Wall = float64(Shell.WallThickness);
        const auto WallRadius = float32(float64(InSpec.Drum.InnerRadius) + Wall * 0.5);
        const auto HingeLocal = Get_HatchHingeLocal(InSpec);
        const auto TopDegrees = float64(Shell.Gap.CentreDegrees - Shell.Gap.HalfDegrees);
        const auto SegmentDegrees = 2.0 * float64(Shell.Gap.HalfDegrees) / float64(Shell.Gap.PlateSegments);
        const auto Segment = Make_ShellBox(FVector(Get_ChordHalfLength(SegmentDegrees, float64(WallRadius)),
            float64(InSpec.Drum.HalfLength + Shell.DiscGap), Wall * 0.5), Shell.Surface);

        auto FirstSegment = FCk_Handle_JoltBody();
        for (int32 Index = 0; Index < Shell.Gap.PlateSegments; ++Index)
        {
            const auto Degrees = float32(TopDegrees + (float64(Index) + 0.5) * SegmentDegrees);
            auto Pose = Get_RingPose(Degrees, WallRadius);
            Pose.SetLocation(Pose.GetLocation() - HingeLocal);
            const auto Body = Add_ShellPart(Parent, Pose, Segment);
            if (Index == 0)
            { FirstSegment = Body; }
        }

        return FirstSegment;
    }

    // A point on the circle of InRadius round the axle (drum frame), InDegrees from the bottom: 0 = the bottom at home,
    // -90 = the operator's side.
    FVector Get_RingPoint(float32 InDegrees, float32 InRadius)
    {
        const auto Angle = Math::DegreesToRadians(float64(InDegrees));
        const auto Radius = float64(InRadius);
        return FVector(Radius * Math::Sin(Angle), 0.0, -Radius * Math::Cos(Angle));
    }

    // The hatch hinge in the drum frame: the gap's upper edge, on the panels' ring.
    FVector Get_HatchHingeLocal(const FMars_Tumbler_Spec& InSpec)
    {
        const auto& Gap = InSpec.Shell.Gap;
        return Get_RingPoint(Gap.CentreDegrees - Gap.HalfDegrees, InSpec.Drum.InnerRadius + InSpec.Shell.WallThickness * 0.5f);
    }

    // The hatch tab (the hover anchor) under the hinge: the gap's lower edge on the panels' ring, relative to the hinge. The
    // assembly adds its own outward offset for the handle it shows.
    FVector Get_HatchTabLocal(const FMars_Tumbler_Spec& InSpec)
    {
        const auto& Gap = InSpec.Shell.Gap;
        const auto Edge = Get_RingPoint(Gap.CentreDegrees + Gap.HalfDegrees, InSpec.Drum.InnerRadius + InSpec.Shell.WallThickness * 0.5f);
        return Edge - Get_HatchHingeLocal(InSpec);
    }

    // The arc the shell closes: the full turn less the hatch gap.
    float64 Get_ClosedArcDegrees(const FMars_Tumbler_Spec& InSpec)
    {
        return 360.0 - 2.0 * float64(InSpec.Shell.Gap.HalfDegrees);
    }

    // Baffle InIndex's angle (drum frame): the baffles split the closed arc evenly, each centred in its share.
    float32 Get_BaffleDegrees(const FMars_Tumbler_Spec& InSpec, int32 InIndex)
    {
        const auto& Shell = InSpec.Shell;
        if (Shell.Baffles.Count <= 0)
        { return 0.0f; }

        const auto GapEnd = float64(Shell.Gap.CentreDegrees + Shell.Gap.HalfDegrees);
        return float32(GapEnd + (float64(InIndex) + 0.5) * Get_ClosedArcDegrees(InSpec) / float64(Shell.Baffles.Count));
    }

    // Where an escaped piece in InSlot is put back, from the axle in the station frame: in its lane along the axle, its
    // lowest face just above the shell's floor at the drum's world bottom.
    FVector Get_ReseatOffset(int32 InSlot, const FMars_Tumbler_Spec& InSpec)
    {
        const auto Depth = InSpec.Drum.InnerRadius - InSpec.Piece.HalfSize - k_ReseatLift;
        return FVector(0.0, float64(Get_AxialCm(InSlot, InSpec.Drum.HalfLength)), -float64(Depth));
    }

    // The cursor's point on the reach plane, station frame.
    FVector Get_PlanePoint(const FMars_Tumbler_HandSpec& InHand, FVector2D InCursor)
    {
        return InHand.WorkspaceCentreLocal + FVector(0.0, InCursor.X, InCursor.Y);
    }

    // Three lanes along the axle, by slot.
    float32 Get_AxialCm(int32 InSlot, float32 InHalfLength)
    {
        return float32(Get_Wrapped(InSlot, 3) - 1) * InHalfLength * 0.8f;
    }

    // The free right hand (station frame): fingers toward the station (+X), palm down over the reach plane.
    FQuat Get_FreeRotation()
    { return utils_fphands::Make_GripRotation(EMars_Hand::Right, FVector::ForwardVector, -FVector::UpVector); }

    // 0..1 eased in and out.
    float32 Get_InOutSine(float32 InAlpha)
    {
        const auto Alpha = Math::Clamp(float64(InAlpha), 0.0, 1.0);
        return float32(0.5 - 0.5 * Math::Cos(Alpha * Math::DegreesToRadians(180.0)));
    }

    // The index of the piece carrying InPieceId; -1 = none. Internal to the kernel: callers outside it address pieces by
    // identity through the getters.
    int32 Find_PieceIndex(const TArray<FMars_Tumbler_PieceState>& InPieces, const FMars_CookingFeed_PieceId& InPieceId)
    {
        for (int32 Index = 0; Index < InPieces.Num(); ++Index)
        {
            if (InPieces[Index].Id.Get_IsSame(InPieceId))
            { return Index; }
        }

        return -1;
    }

    // The hatch state its Mover shows: resting at a pose, or moving toward one.
    EMars_Tumbler_Hatch Get_HatchFromMover(const FCk_Handle_Mover& InHatch)
    {
        const auto ToOpen = InHatch.Get_Target() == EMars_Mover_Pose::End;
        if (InHatch.Get_IsResting())
        { return ToOpen ? EMars_Tumbler_Hatch::Open : EMars_Tumbler_Hatch::Closed; }

        return ToOpen ? EMars_Tumbler_Hatch::Opening : EMars_Tumbler_Hatch::Closing;
    }

    // The axle Mover rests at its start pose (home).
    bool Get_DrumAtRest(const FCk_Handle_Mover& InDrum)
    {
        return InDrum.Get_IsResting() && InDrum.Get_Target() == EMars_Mover_Pose::Start;
    }

    // The hatch toggles only at home, settled, with a free hand, and not shut on a piece in flight.
    bool Get_CanToggleHatch(const FMars_Fragment_Tumbler& InState)
    {
        const auto Settled = InState.Hatch == EMars_Tumbler_Hatch::Closed || InState.Hatch == EMars_Tumbler_Hatch::Open;
        const auto ClosingOnTransfer = InState.Hatch == EMars_Tumbler_Hatch::Open && InState.Loading == EMars_Tumbler_Loading::InFlight;
        return InState.Drum == EMars_Tumbler_Drum::Home && Settled && ClosingOnTransfer == false
            && InState.Hand.Mode == EMars_Tumbler_HandMode::Free;
    }

    // A regrip while Returning is allowed: BeginManipulation scrubs from the current alpha.
    bool Get_CanGrip(const FMars_Fragment_Tumbler& InState)
    {
        return InState.Hatch == EMars_Tumbler_Hatch::Closed && InState.Loading == EMars_Tumbler_Loading::Idle
            && InState.Hand.Mode == EMars_Tumbler_HandMode::Free;
    }

    bool Get_CanLoad(const FMars_Fragment_Tumbler& InState, int32 InCapacity)
    {
        return InState.Hatch == EMars_Tumbler_Hatch::Open && InState.Drum == EMars_Tumbler_Drum::Home
            && InState.Loading == EMars_Tumbler_Loading::Idle && InState.Pieces.Num() < InCapacity;
    }

    // Why a hatch press is refused; only meaningful when Get_CanToggleHatch is false.
    EMars_Tumbler_Refusal Get_HatchRefusal(const FMars_Fragment_Tumbler& InState)
    {
        if (InState.Hand.Mode != EMars_Tumbler_HandMode::Free)
        { return EMars_Tumbler_Refusal::HandBusy; }

        if (InState.Drum != EMars_Tumbler_Drum::Home)
        { return EMars_Tumbler_Refusal::NotHome; }

        if (InState.Hatch == EMars_Tumbler_Hatch::Opening || InState.Hatch == EMars_Tumbler_Hatch::Closing)
        { return EMars_Tumbler_Refusal::HatchMoving; }

        return EMars_Tumbler_Refusal::LoadingInFlight;
    }

    // Why a lever press is refused; only meaningful when Get_CanGrip is false.
    EMars_Tumbler_Refusal Get_GripRefusal(const FMars_Fragment_Tumbler& InState)
    {
        if (InState.Hand.Mode != EMars_Tumbler_HandMode::Free)
        { return EMars_Tumbler_Refusal::HandBusy; }

        if (InState.Hatch == EMars_Tumbler_Hatch::Opening || InState.Hatch == EMars_Tumbler_Hatch::Closing)
        { return EMars_Tumbler_Refusal::HatchMoving; }

        if (InState.Hatch == EMars_Tumbler_Hatch::Open)
        { return EMars_Tumbler_Refusal::HatchOpen; }

        return EMars_Tumbler_Refusal::LoadingInFlight;
    }

    // InValue wrapped into [0, InCount): a slot index past the capacity reuses the lanes.
    int32 Get_Wrapped(int32 InValue, int32 InCount)
    {
        if (InCount <= 0)
        { return 0; }

        return ((InValue % InCount) + InCount) % InCount;
    }

    // A part's pose on the ring (drum frame): at InDegrees on the circle of InRadius, pitched by the same angle so its local
    // X runs along the tangent and its local Z points at the axis.
    FTransform Get_RingPose(float32 InDegrees, float32 InRadius)
    {
        return FTransform(FRotator(float64(InDegrees), 0.0, 0.0), Get_RingPoint(InDegrees, InRadius));
    }

    // Half of the overlapped chord an arc of InDegrees cuts on the circle of InRadius.
    float64 Get_ChordHalfLength(float64 InDegrees, float64 InRadius)
    {
        return InRadius * Math::Sin(Math::DegreesToRadians(InDegrees * 0.5)) * k_PanelOverlap;
    }

    FMars_Tumbler_ShellPart Make_ShellBox(FVector InHalfExtents, const FMars_Tumbler_SurfaceSpec& InSurface)
    {
        auto Shape = FCk_Jolt_ShapeDimensions(ECk_Jolt_ShapeType::Box);
        Shape.Set_HalfExtents(InHalfExtents);
        return FMars_Tumbler_ShellPart(Shape, InSurface);
    }

    // One kinematic body on its own child node of InParent at InOffset; CkJolt pushes it to the node's world pose every step.
    FCk_Handle_JoltBody Add_ShellPart(FCk_Handle_Transform& InParent, FTransform InOffset, const FMars_Tumbler_ShellPart& InPart)
    {
        auto BodyNode = utils_scene_node::Create(InParent, InOffset);

        auto BodySpec = FCk_JoltBody_Spec(ECk_JoltBody_ShapeSource::ExplicitShape);
        BodySpec.Set_ShapeDimensions(InPart.Shape);
        BodySpec.Set_MotionType(ECk_MotionType::Kinematic);
        BodySpec.Set_MassSource(ECk_JoltBody_MassSource::Explicit);
        BodySpec.Set_MassKg(k_KinematicMassKg);
        BodySpec.Set_SurfaceSource(ECk_JoltBody_SurfaceSource::Explicit);
        BodySpec.Set_Friction(InPart.Surface.Friction);
        BodySpec.Set_Restitution(InPart.Surface.Restitution);
        BodySpec.Set_CollisionProfileName(n"BlockAll");
        return utils_jolt_body::Add(BodyNode.H(), BodySpec);
    }
}

//--------------------------------------------------------------------------------------------------------------------------
// Getters
//--------------------------------------------------------------------------------------------------------------------------

mixin FMars_Tumbler_Spec Get_Spec(const FCk_Handle_Tumbler& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Tumbler_Params).Spec;
}

mixin EMars_Tumbler_HandMode Get_HandMode(const FCk_Handle_Tumbler& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Tumbler).Hand.Mode;
}

// Station frame.
mixin FVector Get_HandLocal(const FCk_Handle_Tumbler& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Tumbler).Hand.HandLocal;
}

// (Y, Z) on the reach plane relative to the workspace centre, clamped to the half extents.
mixin FVector2D Get_Cursor(const FCk_Handle_Tumbler& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Tumbler).Hand.Cursor;
}

mixin EMars_Tumbler_Target Get_Hovered(const FCk_Handle_Tumbler& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Tumbler).Hovered;
}

mixin EMars_Tumbler_Hatch Get_Hatch(const FCk_Handle_Tumbler& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Tumbler).Hatch;
}

mixin EMars_Tumbler_Drum Get_Drum(const FCk_Handle_Tumbler& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Tumbler).Drum;
}

mixin EMars_Tumbler_Loading Get_Loading(const FCk_Handle_Tumbler& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Tumbler).Loading;
}

mixin float32 Get_DrumDegrees(const FCk_Handle_Tumbler& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Tumbler).DrumDegrees;
}

mixin int32 Get_PieceCount(const FCk_Handle_Tumbler& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Tumbler).Pieces.Num();
}

// Escaped pieces put back since the last Reset.
mixin int32 Get_Reseats(const FCk_Handle_Tumbler& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Tumbler).Reseats;
}

mixin bool Get_CanToggleHatch(const FCk_Handle_Tumbler& Self)
{
    return utils_tumbler::Get_CanToggleHatch(Self.Get_Fragment(FMars_Fragment_Tumbler));
}

mixin bool Get_CanGrip(const FCk_Handle_Tumbler& Self)
{
    return utils_tumbler::Get_CanGrip(Self.Get_Fragment(FMars_Fragment_Tumbler));
}

mixin bool Get_CanLoad(const FCk_Handle_Tumbler& Self)
{
    return utils_tumbler::Get_CanLoad(Self.Get_Fragment(FMars_Fragment_Tumbler), Self.Get_Spec().Drum.Capacity);
}

// The station root's world transform (the station frame).
mixin FTransform Get_RootWorld(const FCk_Handle_Tumbler& Self)
{
    return utils_transform::Get_EntityCurrentTransform(Self.As_Transform());
}

// The axle node's world transform (the drum frame: the axis along its Y).
mixin FTransform Get_AxleWorld(const FCk_Handle_Tumbler& Self)
{
    return utils_transform::Get_EntityCurrentTransform(Self.Get_Spec().Nodes.Drum);
}

//--------------------------------------------------------------------------------------------------------------------------
// Piece getters (by identity). An unknown Id ensures and answers the zero value; Get_HasPiece asks first.
//--------------------------------------------------------------------------------------------------------------------------

// Every piece in the drum, in admission order.
mixin TArray<FMars_CookingFeed_PieceId> Get_PieceIds(const FCk_Handle_Tumbler& Self)
{
    TArray<FMars_CookingFeed_PieceId> Ids;
    for (const auto& Piece : Self.Get_Fragment(FMars_Fragment_Tumbler).Pieces)
    { Ids.Add(Piece.Id); }

    return Ids;
}

mixin bool Get_HasPiece(const FCk_Handle_Tumbler& Self, const FMars_CookingFeed_PieceId& InPieceId)
{
    return utils_tumbler::Find_PieceIndex(Self.Get_Fragment(FMars_Fragment_Tumbler).Pieces, InPieceId) >= 0;
}

// A copy of the piece's state; an unknown Id ensures and answers a default state.
mixin FMars_Tumbler_PieceState Get_PieceState(const FCk_Handle_Tumbler& Self, const FMars_CookingFeed_PieceId& InPieceId)
{
    const auto& Pieces = Self.Get_Fragment(FMars_Fragment_Tumbler).Pieces;
    const auto Index = utils_tumbler::Find_PieceIndex(Pieces, InPieceId);
    if (ck::EnsureIfNot(Index >= 0,
        f"[Tumbler] [{Self.ToString()}] has no piece {utils_cooking_feed::Get_PieceName(InPieceId)} ({Pieces.Num()} in the drum)"))
    { return FMars_Tumbler_PieceState(); }

    return Pieces[Index];
}

mixin float32 Get_PieceCoverage(const FCk_Handle_Tumbler& Self, const FMars_CookingFeed_PieceId& InPieceId)
{
    return Self.Get_PieceState(InPieceId).Coverage;
}

mixin int32 Get_PiecePresetIndex(const FCk_Handle_Tumbler& Self, const FMars_CookingFeed_PieceId& InPieceId)
{
    return Self.Get_PieceState(InPieceId).PresetIndex;
}

mixin FCk_Handle Get_PieceEntity(const FCk_Handle_Tumbler& Self, const FMars_CookingFeed_PieceId& InPieceId)
{
    return Self.Get_PieceState(InPieceId).Entity;
}

mixin FCk_Handle_JoltBody Get_PieceBody(const FCk_Handle_Tumbler& Self, const FMars_CookingFeed_PieceId& InPieceId)
{
    return Self.Get_PieceState(InPieceId).Body;
}

// The piece's centre in the drum frame (the axis along Y); zero once its entity is gone.
mixin FVector Get_PieceAxleLocal(const FCk_Handle_Tumbler& Self, const FMars_CookingFeed_PieceId& InPieceId)
{
    const auto Entity = Self.Get_PieceEntity(InPieceId);
    if (ck::Is_NOT_Valid(Entity))
    { return FVector::ZeroVector; }

    return Self.Get_AxleWorld().InverseTransformPosition(utils_transform::Get_EntityCurrentLocation(Entity.As_Transform()));
}

//--------------------------------------------------------------------------------------------------------------------------
// Requests
//--------------------------------------------------------------------------------------------------------------------------

mixin void Request_Reset(FCk_Handle_Tumbler& Self, const FMars_Request_Tumbler_Reset& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_Tumbler_Requests);
    Requests.ResetRequests.Add(InRequest);
}

mixin void Request_Cancel(FCk_Handle_Tumbler& Self, const FMars_Request_Tumbler_Cancel& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_Tumbler_Requests);
    Requests.CancelRequests.Add(InRequest);
}

mixin void Request_SetLoading(FCk_Handle_Tumbler& Self, const FMars_Request_Tumbler_SetLoading& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_Tumbler_Requests);
    Requests.SetLoadingRequests.Add(InRequest);
}

mixin void Request_AddPiece(FCk_Handle_Tumbler& Self, const FMars_Request_Tumbler_AddPiece& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_Tumbler_Requests);
    Requests.AddPieceRequests.Add(InRequest);
}

mixin void Request_Press(FCk_Handle_Tumbler& Self, const FMars_Request_Tumbler_Press& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_Tumbler_Requests);
    Requests.PressRequests.Add(InRequest);
}

mixin void Request_Release(FCk_Handle_Tumbler& Self, const FMars_Request_Tumbler_Release& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_Tumbler_Requests);
    Requests.ReleaseRequests.Add(InRequest);
}

mixin void Request_Look(FCk_Handle_Tumbler& Self, const FMars_Request_Tumbler_Look& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_Tumbler_Requests);
    Requests.LookRequests.Add(InRequest);
}

//--------------------------------------------------------------------------------------------------------------------------
// Signal Binding
//--------------------------------------------------------------------------------------------------------------------------

mixin void BindTo_OnHandModeChanged(FCk_Handle_Tumbler& Self, FMars_Delegate_Tumbler_OnHandModeChanged InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_Tumbler_Signals);
    Fragment.OnHandModeChanged.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnHandModeChanged(FCk_Handle_Tumbler& Self, FMars_Delegate_Tumbler_OnHandModeChanged InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_Tumbler_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_Tumbler_Signals).OnHandModeChanged.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void BindTo_OnHoverChanged(FCk_Handle_Tumbler& Self, FMars_Delegate_Tumbler_OnHoverChanged InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_Tumbler_Signals);
    Fragment.OnHoverChanged.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnHoverChanged(FCk_Handle_Tumbler& Self, FMars_Delegate_Tumbler_OnHoverChanged InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_Tumbler_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_Tumbler_Signals).OnHoverChanged.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void BindTo_OnHatchChanged(FCk_Handle_Tumbler& Self, FMars_Delegate_Tumbler_OnHatchChanged InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_Tumbler_Signals);
    Fragment.OnHatchChanged.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnHatchChanged(FCk_Handle_Tumbler& Self, FMars_Delegate_Tumbler_OnHatchChanged InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_Tumbler_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_Tumbler_Signals).OnHatchChanged.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void BindTo_OnDrumChanged(FCk_Handle_Tumbler& Self, FMars_Delegate_Tumbler_OnDrumChanged InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_Tumbler_Signals);
    Fragment.OnDrumChanged.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnDrumChanged(FCk_Handle_Tumbler& Self, FMars_Delegate_Tumbler_OnDrumChanged InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_Tumbler_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_Tumbler_Signals).OnDrumChanged.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void BindTo_OnPressRefused(FCk_Handle_Tumbler& Self, FMars_Delegate_Tumbler_OnPressRefused InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_Tumbler_Signals);
    Fragment.OnPressRefused.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnPressRefused(FCk_Handle_Tumbler& Self, FMars_Delegate_Tumbler_OnPressRefused InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_Tumbler_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_Tumbler_Signals).OnPressRefused.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void BindTo_OnPieceAdmission(FCk_Handle_Tumbler& Self, FMars_Delegate_Tumbler_OnPieceAdmission InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_Tumbler_Signals);
    Fragment.OnPieceAdmission.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnPieceAdmission(FCk_Handle_Tumbler& Self, FMars_Delegate_Tumbler_OnPieceAdmission InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_Tumbler_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_Tumbler_Signals).OnPieceAdmission.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void BindTo_OnPieceAdded(FCk_Handle_Tumbler& Self, FMars_Delegate_Tumbler_OnPieceAdded InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_Tumbler_Signals);
    Fragment.OnPieceAdded.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnPieceAdded(FCk_Handle_Tumbler& Self, FMars_Delegate_Tumbler_OnPieceAdded InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_Tumbler_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_Tumbler_Signals).OnPieceAdded.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void BindTo_OnCoverageChanged(FCk_Handle_Tumbler& Self, FMars_Delegate_Tumbler_OnCoverageChanged InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_Tumbler_Signals);
    Fragment.OnCoverageChanged.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnCoverageChanged(FCk_Handle_Tumbler& Self, FMars_Delegate_Tumbler_OnCoverageChanged InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_Tumbler_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_Tumbler_Signals).OnCoverageChanged.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void BindTo_OnPieceReseated(FCk_Handle_Tumbler& Self, FMars_Delegate_Tumbler_OnPieceReseated InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_Tumbler_Signals);
    Fragment.OnPieceReseated.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnPieceReseated(FCk_Handle_Tumbler& Self, FMars_Delegate_Tumbler_OnPieceReseated InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_Tumbler_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_Tumbler_Signals).OnPieceReseated.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}
