// The kinematic box or cylinder Add_BasketBodies / Add_ScoopBodies put on one child node: its shape and surface.
struct FMars_Fry_KinematicPart
{
    FCk_Jolt_ShapeDimensions Shape;
    float32 Friction = 0.5f;
    float32 Restitution = 0.1f;

    FMars_Fry_KinematicPart() {}

    FMars_Fry_KinematicPart(FCk_Jolt_ShapeDimensions InShape, float32 InFriction, float32 InRestitution)
    {
        Shape = InShape;
        Friction = InFriction;
        Restitution = InRestitution;
    }
}

// A root-frame XY box: the bounds of the whole reach, which the placing script gives the skimmer's own slide clamp.
struct FMars_Fry_ReachBox
{
    FVector2D Centre = FVector2D::ZeroVector;
    FVector2D HalfExtent = FVector2D::ZeroVector;
}

namespace utils_fry
{
    // A kinematic body's mass: Jolt asserts a positive mass even on a kinematic body; the value is never used.
    const float32 k_KinematicMassKg = 1.0f;
    const int32 k_LipSegments = 8;
    // A lip segment is the rim's arc length plus this much, so neighbouring segments overlap at their corners.
    const float32 k_LipOverlap = 1.05f;
    // cm the scoop's centre may sit past the pot disc and still count as in the pot: the slide spring overshoots a target
    // on the disc's edge by a little.
    const float32 k_ReachTolerance = 1.0f;

    // Composes the minigame on InHandle (the station entity, which carries the root transform). The spec's Nodes are built
    // by the caller and left as composed (the skimmer Idle at its park, carrying): the kernel drives it while Driven,
    // steers its commanded slide within the reach, and sets its lift and tilt by the skim. Nothing is in play until the
    // first AddPiece. A rejected spec, a missing node or a skimmer that cannot do what the kernel asks ensures and returns
    // an invalid handle.
    FCk_Handle_Fry Add(FCk_Handle& InHandle, FMars_Fry_Spec InSpec)
    {
        const auto Validation = InSpec.Validate();
        if (ck::EnsureIfNot(Validation.IsValid(), f"[Fry] [{InHandle.ToString()}] rejected the spec: {Validation.Get_Error()}"))
        { return FCk_Handle_Fry(); }

        const auto& Nodes = InSpec.Nodes;
        if (ck::EnsureIfNot(ck::IsValid(Nodes.Skimmer) && ck::IsValid(Nodes.ScoopBody) && ck::IsValid(Nodes.BasketBody),
            f"[Fry] [{InHandle.ToString()}] needs the skimmer implement, the scoop body and the basket body"))
        { return FCk_Handle_Fry(); }

        // The implement clamps a tilt target to its MaxTiltDegrees: a shallower skimmer would pour at less than the spec says.
        const auto SkimmerSpec = Nodes.Skimmer.Get_Spec();
        if (ck::EnsureIfNot(SkimmerSpec.Tilt.MaxTiltDegrees >= InSpec.Scoop.PourPitchDegrees,
            f"[Fry] [{InHandle.ToString()}] needs a skimmer that tilts to the pour's {InSpec.Scoop.PourPitchDegrees} degrees (it tilts at most {SkimmerSpec.Tilt.MaxTiltDegrees})"))
        { return FCk_Handle_Fry(); }

        if (ck::EnsureIfNot(SkimmerSpec.Slide.Mode == EMars_Implement_SlideMode::Commanded,
            f"[Fry] [{InHandle.ToString()}] needs a skimmer whose slide is Commanded (the reach is the kernel's), not {SkimmerSpec.Slide.Mode :n}"))
        { return FCk_Handle_Fry(); }

        auto Params = FMars_Fragment_Fry_Params();
        Params.Spec = InSpec;

        InHandle.Add_Fragment(FMars_Feature_Fry());
        InHandle.Add_Fragment(Params);

        auto Fry = InHandle.As_Fry();

        // The slide target is in the skimmer node's rest frame: the kernel's root-frame target maps onto it only when the two
        // frames are axis-aligned.
        const auto RootRotation = Fry.Get_RootWorld().GetRotation();
        const auto NodeRotation = Nodes.Skimmer.Get_NodeWorld().GetRotation();
        ck::EnsureIfNot((RootRotation.GetForwardVector() - NodeRotation.GetForwardVector()).Size() < 0.001
            && (RootRotation.GetUpVector() - NodeRotation.GetUpVector()).Size() < 0.001,
            f"[Fry] [{InHandle.ToString()}] needs the skimmer node axis-aligned with the station root (its slide is steered in the root frame)");

        const auto ScoopRoot = Fry.Get_ScoopRoot();
        auto State = FMars_Fragment_Fry();
        State.SkimmerPark = FVector2D(ScoopRoot.X, ScoopRoot.Y) - Nodes.Skimmer.Get_Slide();
        State.SkimmerTarget = State.SkimmerPark;
        InHandle.Add_Fragment(State);

        ck::Trace(f"[Fry] [{InHandle.ToString()}] composed: skimmer park at root XY {State.SkimmerPark}, pot reach radius {Get_PotReachRadius(InSpec) :.2}");
        return Fry;
    }

    // The basket's five kinematic boxes under InBasketNode, whose origin is the floor's top centre (the basket frame): the
    // floor (FloorThickness thick, out to the walls' outer faces) centred half its thickness below that origin, and four
    // walls WallHeight tall just outside the interior. Each box is on its own child node (a body needs its own entity).
    // Returns the floor body. A rejected spec ensures and returns an invalid handle.
    FCk_Handle_JoltBody Add_BasketBodies(FCk_Handle_SceneNode& InBasketNode, const FMars_Fry_BasketSpec& InSpec)
    {
        if (ck::EnsureIfNot(InSpec.InnerHalfX > 0.0f && InSpec.InnerHalfY > 0.0f && InSpec.WallHeight > 0.0f
            && InSpec.WallThickness > 0.0f && InSpec.FloorThickness > 0.0f,
            f"[Fry] [{InBasketNode.ToString()}] rejected a basket with a non-positive size"))
        { return FCk_Handle_JoltBody(); }

        auto Parent = InBasketNode.As_Transform();
        const auto OuterHalfX = float64(InSpec.InnerHalfX + InSpec.WallThickness);
        const auto OuterHalfY = float64(InSpec.InnerHalfY + InSpec.WallThickness);
        const auto HalfWall = float64(InSpec.WallThickness) * 0.5;
        const auto HalfHeight = float64(InSpec.WallHeight) * 0.5;

        auto Floor = Make_Box(FVector(OuterHalfX, OuterHalfY, float64(InSpec.FloorThickness) * 0.5), InSpec);
        const auto FloorBody = Add_KinematicPart(Parent, FTransform(FVector(0.0, 0.0, -float64(InSpec.FloorThickness) * 0.5)), Floor);

        // The X walls span the full outer width; the Y walls fit between them.
        auto WallX = Make_Box(FVector(HalfWall, OuterHalfY, HalfHeight), InSpec);
        auto WallY = Make_Box(FVector(float64(InSpec.InnerHalfX), HalfWall, HalfHeight), InSpec);
        const auto WallXOffset = float64(InSpec.InnerHalfX) + HalfWall;
        const auto WallYOffset = float64(InSpec.InnerHalfY) + HalfWall;
        Add_KinematicPart(Parent, FTransform(FVector(WallXOffset, 0.0, HalfHeight)), WallX);
        Add_KinematicPart(Parent, FTransform(FVector(-WallXOffset, 0.0, HalfHeight)), WallX);
        Add_KinematicPart(Parent, FTransform(FVector(0.0, WallYOffset, HalfHeight)), WallY);
        Add_KinematicPart(Parent, FTransform(FVector(0.0, -WallYOffset, HalfHeight)), WallY);

        return FloorBody;
    }

    // The scoop's kinematic bodies under InScoopNode, whose origin is the disc's top centre (the scoop frame): a cylinder
    // disc (out to the lip's outer face) centred half its thickness below that origin, and eight tangent lip boxes around
    // the bowl. Returns the disc body. A rejected spec ensures and returns an invalid handle.
    FCk_Handle_JoltBody Add_ScoopBodies(FCk_Handle_SceneNode& InScoopNode, const FMars_Fry_ScoopSpec& InSpec)
    {
        if (ck::EnsureIfNot(InSpec.BowlRadius > 0.0f && InSpec.LipHeight > 0.0f && InSpec.LipThickness > 0.0f && InSpec.DiscThickness > 0.0f,
            f"[Fry] [{InScoopNode.ToString()}] rejected a scoop with a non-positive size"))
        { return FCk_Handle_JoltBody(); }

        auto Parent = InScoopNode.As_Transform();

        auto DiscShape = FCk_Jolt_ShapeDimensions(ECk_Jolt_ShapeType::Cylinder);
        DiscShape.Set_Radius(InSpec.BowlRadius + InSpec.LipThickness);
        DiscShape.Set_HalfHeight(InSpec.DiscThickness * 0.5f);
        const auto DiscBody = Add_KinematicPart(Parent, FTransform(FVector(0.0, 0.0, -float64(InSpec.DiscThickness) * 0.5)),
            FMars_Fry_KinematicPart(DiscShape, InSpec.Friction, InSpec.Restitution));

        // Each lip box is tangent to the rim at the middle of the lip's thickness.
        const auto LipRadius = float64(InSpec.BowlRadius + InSpec.LipThickness * 0.5f);
        const auto FullTurn = 2.0 * Math::DegreesToRadians(180.0);
        const auto SegmentHalfLength = FullTurn * LipRadius / float64(k_LipSegments) * float64(k_LipOverlap) * 0.5;
        auto LipShape = FCk_Jolt_ShapeDimensions(ECk_Jolt_ShapeType::Box);
        LipShape.Set_HalfExtents(FVector(float64(InSpec.LipThickness) * 0.5, SegmentHalfLength, float64(InSpec.LipHeight) * 0.5));
        const auto Lip = FMars_Fry_KinematicPart(LipShape, InSpec.Friction, InSpec.Restitution);

        for (int32 Index = 0; Index < k_LipSegments; ++Index)
        {
            const auto AngleDegrees = 360.0 * float64(Index) / float64(k_LipSegments);
            const auto Angle = Math::DegreesToRadians(AngleDegrees);
            const auto Location = FVector(Math::Cos(Angle) * LipRadius, Math::Sin(Angle) * LipRadius, float64(InSpec.LipHeight) * 0.5);
            Add_KinematicPart(Parent, FTransform(FRotator(0.0, AngleDegrees, 0.0), Location), Lip);
        }

        return DiscBody;
    }

    // The radius about the root's axis the scoop's centre stays within so the whole scoop (bowl and lip) is inside the pot.
    float32 Get_PotReachRadius(const FMars_Fry_Spec& InSpec)
    {
        return InSpec.Zones.PotRadius - InSpec.Scoop.BowlRadius - InSpec.Scoop.LipThickness;
    }

    // InTarget (root-frame XY of the scoop's centre) held inside the reach: Dip, the pot disc only (a dipped scoop cannot
    // leave the pot); Carry and Pour, the nearest point of the union of the pot disc, the corridor box and the basket box.
    FVector2D Clamp_Reach(FVector2D InTarget, const FMars_Fry_Spec& InSpec, EMars_Fry_Skim InSkim)
    {
        const auto InPot = Clamp_ToDisc(InTarget, Get_PotReachRadius(InSpec));
        if (InSkim == EMars_Fry_Skim::Dip)
        { return InPot; }

        const auto& Reach = InSpec.Reach;
        const auto InCorridor = Clamp_ToBox(InTarget, Reach.CorridorCentre, Reach.CorridorHalfExtent);
        const auto InBasket = Clamp_ToBox(InTarget, Reach.BasketCentre, Reach.BasketHalfExtent);

        auto Best = InPot;
        if ((InCorridor - InTarget).Size() < (Best - InTarget).Size())
        { Best = InCorridor; }

        if ((InBasket - InTarget).Size() < (Best - InTarget).Size())
        { Best = InBasket; }

        return Best;
    }

    FVector2D Clamp_ToDisc(FVector2D InPoint, float32 InRadius)
    {
        const auto Distance = InPoint.Size();
        if (Distance <= float64(InRadius) || Distance <= 0.0)
        { return InPoint; }

        return InPoint * (float64(InRadius) / Distance);
    }

    FVector2D Clamp_ToBox(FVector2D InPoint, FVector2D InCentre, FVector2D InHalfExtent)
    {
        return FVector2D(
            Math::Clamp(InPoint.X, InCentre.X - InHalfExtent.X, InCentre.X + InHalfExtent.X),
            Math::Clamp(InPoint.Y, InCentre.Y - InHalfExtent.Y, InCentre.Y + InHalfExtent.Y));
    }

    // The root-frame box bounding the whole reach (the pot disc, the corridor and the basket box).
    FMars_Fry_ReachBox Get_ReachBounds(const FMars_Fry_Spec& InSpec)
    {
        const auto Radius = float64(Get_PotReachRadius(InSpec));
        const auto& Reach = InSpec.Reach;
        const auto MinX = Math::Min(-Radius, Math::Min(Reach.CorridorCentre.X - Reach.CorridorHalfExtent.X, Reach.BasketCentre.X - Reach.BasketHalfExtent.X));
        const auto MaxX = Math::Max(Radius, Math::Max(Reach.CorridorCentre.X + Reach.CorridorHalfExtent.X, Reach.BasketCentre.X + Reach.BasketHalfExtent.X));
        const auto MinY = Math::Min(-Radius, Math::Min(Reach.CorridorCentre.Y - Reach.CorridorHalfExtent.Y, Reach.BasketCentre.Y - Reach.BasketHalfExtent.Y));
        const auto MaxY = Math::Max(Radius, Math::Max(Reach.CorridorCentre.Y + Reach.CorridorHalfExtent.Y, Reach.BasketCentre.Y + Reach.BasketHalfExtent.Y));

        auto Bounds = FMars_Fry_ReachBox();
        Bounds.Centre = FVector2D((MinX + MaxX) * 0.5, (MinY + MaxY) * 0.5);
        Bounds.HalfExtent = FVector2D((MaxX - MinX) * 0.5, (MaxY - MinY) * 0.5);
        return Bounds;
    }

    // Inside the basket interior (basket frame): over the floor within the walls, from the floor's underside up to a
    // piece's height above the wall tops (a piece hopping inside the walls is still in the basket).
    bool Get_IsInsideBasket(const FMars_Fry_BasketSpec& InBasket, FVector InBasketLocal, float32 InHalfSize)
    {
        const auto Z = float32(InBasketLocal.Z);
        return Math::Abs(float32(InBasketLocal.X)) <= InBasket.InnerHalfX
            && Math::Abs(float32(InBasketLocal.Y)) <= InBasket.InnerHalfY
            && Z >= -InBasket.FloorThickness
            && Z <= InBasket.WallHeight + 2.0f * InHalfSize;
    }

    // Over the basket's outer footprint (basket frame XY, walls included), at any height: a piece there is not lost even
    // below the rim (it is in the basket, or on a wall on its way in or out).
    bool Get_IsOverBasketFootprint(const FMars_Fry_BasketSpec& InBasket, FVector InBasketLocal)
    {
        return Math::Abs(float32(InBasketLocal.X)) <= InBasket.InnerHalfX + InBasket.WallThickness
            && Math::Abs(float32(InBasketLocal.Y)) <= InBasket.InnerHalfY + InBasket.WallThickness;
    }

    // Inside the scoop bowl (scoop frame): within BowlRadius of its axis, from the disc's underside up to a piece's height
    // above the lip.
    bool Get_IsInsideBowl(const FMars_Fry_ScoopSpec& InScoop, FVector InScoopLocal, float32 InHalfSize)
    {
        const auto Z = float32(InScoopLocal.Z);
        return float32(InScoopLocal.Size2D()) <= InScoop.BowlRadius
            && Z >= -InScoop.DiscThickness
            && Z <= InScoop.LipHeight + 2.0f * InHalfSize;
    }

    // The whole bowl is over the basket interior: InScoopFromBasket (the scoop frame's origin less the basket frame's, in
    // the station frame's XY) within the interior shrunk by BowlRadius on each side.
    bool Get_IsBowlOverInterior(const FMars_Fry_Spec& InSpec, FVector2D InScoopFromBasket)
    {
        const auto BowlRadius = InSpec.Scoop.BowlRadius;
        return Math::Abs(float32(InScoopFromBasket.X)) <= InSpec.Basket.InnerHalfX - BowlRadius
            && Math::Abs(float32(InScoopFromBasket.Y)) <= InSpec.Basket.InnerHalfY - BowlRadius;
    }

    // 0..1, the share of a piece's height below the oil line (root frame), treating the box as upright.
    float32 Get_Immersion(float32 InCentreZ, float32 InHalfSize, float32 InSurfaceZ)
    {
        return Math::Clamp((InSurfaceZ - (InCentreZ - InHalfSize)) / (2.0f * InHalfSize), 0.0f, 1.0f);
    }

    // The height (root frame) of a face's centre: InPiece is the piece's root-relative transform.
    float32 Get_FaceCentreZ(const FTransform& InPiece, EMars_Searing_Face InFace, float32 InHalfSize)
    {
        const auto Normal = InPiece.GetRotation().RotateVector(utils_searing::Get_FaceNormal(InFace));
        return float32(InPiece.GetLocation().Z + Normal.Z * float64(InHalfSize));
    }

    EMars_Fry_HeatStage Get_HeatStage(float32 InHeat)
    {
        if (InHeat >= 2.0f)
        { return EMars_Fry_HeatStage::Overdone; }

        if (InHeat >= 1.0f)
        { return EMars_Fry_HeatStage::Golden; }

        return EMars_Fry_HeatStage::Pale;
    }

    // The index of the piece carrying InPieceId (lingering lost ones included); -1 = none. Internal to the kernel: callers
    // outside it address pieces by identity through the getters.
    int32 Find_PieceIndex(const TArray<FMars_Fry_PieceState>& InPieces, const FMars_CookingFeed_PieceId& InPieceId)
    {
        for (int32 Index = 0; Index < InPieces.Num(); ++Index)
        {
            if (InPieces[Index].Id.Get_IsSame(InPieceId))
            { return Index; }
        }

        return -1;
    }

    // Pieces not Lost.
    int32 Get_LivePieceCount(const TArray<FMars_Fry_PieceState>& InPieces)
    {
        auto Count = 0;
        for (const auto& Piece : InPieces)
        {
            if (Piece.Whereabouts != EMars_Fry_Whereabouts::Lost)
            { Count += 1; }
        }

        return Count;
    }

    // Faces still below golden.
    int32 Get_PaleFaceCount(const TArray<float32>& InFaceHeat)
    {
        auto Count = 0;
        for (const auto Heat : InFaceHeat)
        {
            if (Heat < 1.0f)
            { Count += 1; }
        }

        return Count;
    }

    FMars_Fry_KinematicPart Make_Box(FVector InHalfExtents, const FMars_Fry_BasketSpec& InSurface)
    {
        auto Shape = FCk_Jolt_ShapeDimensions(ECk_Jolt_ShapeType::Box);
        Shape.Set_HalfExtents(InHalfExtents);
        return FMars_Fry_KinematicPart(Shape, InSurface.Friction, InSurface.Restitution);
    }

    // One kinematic body on its own child node of InParent at InOffset; CkJolt pushes it to the node's world pose every step.
    FCk_Handle_JoltBody Add_KinematicPart(FCk_Handle_Transform& InParent, FTransform InOffset, const FMars_Fry_KinematicPart& InPart)
    {
        auto BodyNode = utils_scene_node::Create(InParent, InOffset);

        auto BodySpec = FCk_JoltBody_Spec(ECk_JoltBody_ShapeSource::ExplicitShape);
        BodySpec.Set_ShapeDimensions(InPart.Shape);
        BodySpec.Set_MotionType(ECk_MotionType::Kinematic);
        BodySpec.Set_MassSource(ECk_JoltBody_MassSource::Explicit);
        BodySpec.Set_MassKg(k_KinematicMassKg);
        BodySpec.Set_SurfaceSource(ECk_JoltBody_SurfaceSource::Explicit);
        BodySpec.Set_Friction(InPart.Friction);
        BodySpec.Set_Restitution(InPart.Restitution);
        BodySpec.Set_CollisionProfileName(n"BlockAll");
        return utils_jolt_body::Add(BodyNode.H(), BodySpec);
    }
}

//--------------------------------------------------------------------------------------------------------------------------
// Getters
//--------------------------------------------------------------------------------------------------------------------------

mixin FMars_Fry_Spec Get_Spec(const FCk_Handle_Fry& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Fry_Params).Spec;
}

mixin EMars_Implement_Drive Get_Drive(const FCk_Handle_Fry& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Fry).Drive;
}

// The skimmer's commanded pose (Carry whenever it is idle).
mixin EMars_Fry_Skim Get_Skim(const FCk_Handle_Fry& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Fry).Skim;
}

// Root-frame XY of the scoop's commanded centre.
mixin FVector2D Get_SkimmerTarget(const FCk_Handle_Fry& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Fry).SkimmerTarget;
}

mixin FCk_Handle_Implement Get_Skimmer(const FCk_Handle_Fry& Self)
{
    return Self.Get_Spec().Nodes.Skimmer;
}

mixin FMars_Fry_Tally Get_Tally(const FCk_Handle_Fry& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Fry).Tally;
}

// Admitted = InOil + OnSkimmer + Airborne + InBasket + Lost since the last reset (a lost piece stays counted after its body
// is destroyed).
mixin FMars_Fry_Summary Get_Summary(const FCk_Handle_Fry& Self)
{
    const auto& State = Self.Get_Fragment(FMars_Fragment_Fry);
    auto Summary = FMars_Fry_Summary();
    for (const auto& Piece : State.Pieces)
    {
        if (Piece.Whereabouts == EMars_Fry_Whereabouts::Lost)
        { continue; }

        if (Piece.Whereabouts == EMars_Fry_Whereabouts::Oil)
        { Summary.InOil += 1; }
        else if (Piece.Whereabouts == EMars_Fry_Whereabouts::Skimmer)
        { Summary.OnSkimmer += 1; }
        else if (Piece.Whereabouts == EMars_Fry_Whereabouts::Airborne)
        { Summary.Airborne += 1; }
        else if (Piece.Whereabouts == EMars_Fry_Whereabouts::DrainBasket)
        {
            Summary.InBasket += 1;
            if (Piece.Drain == EMars_Fry_Drain::Drained)
            { Summary.Drained += 1; }
        }

        for (const auto Heat : Piece.FaceHeat)
        {
            if (Heat < 1.0f)
            { Summary.PaleFaces += 1; }

            if (Heat >= 2.0f)
            { Summary.OverdoneFaces += 1; }
        }
    }

    Summary.Lost = State.Tally.Lost;
    Summary.Admitted = Summary.InOil + Summary.OnSkimmer + Summary.Airborne + Summary.InBasket + Summary.Lost;
    return Summary;
}

// The station root's world transform (the station frame).
mixin FTransform Get_RootWorld(const FCk_Handle_Fry& Self)
{
    return utils_transform::Get_EntityCurrentTransform(Self.As_Transform());
}

// The basket frame in world space: the floor body's node frame raised to the floor's top centre.
mixin FTransform Get_BasketWorld(const FCk_Handle_Fry& Self)
{
    const auto Spec = Self.Get_Spec();
    const auto FloorWorld = utils_transform::Get_EntityCurrentTransform(Spec.Nodes.BasketBody.As_Transform());
    const auto Top = FloorWorld.TransformPosition(FVector(0.0, 0.0, float64(Spec.Basket.FloorThickness) * 0.5));
    return FTransform(FloorWorld.GetRotation(), Top, FloorWorld.GetScale3D());
}

// The basket floor's top centre height in the station frame.
mixin float32 Get_BasketFloorTopZ(const FCk_Handle_Fry& Self)
{
    return float32(Self.Get_RootWorld().InverseTransformPosition(Self.Get_BasketWorld().GetLocation()).Z);
}

// The scoop frame in world space: the disc body's node frame raised to the disc's top centre.
mixin FTransform Get_ScoopWorld(const FCk_Handle_Fry& Self)
{
    const auto Spec = Self.Get_Spec();
    const auto DiscWorld = utils_transform::Get_EntityCurrentTransform(Spec.Nodes.ScoopBody.As_Transform());
    const auto Top = DiscWorld.TransformPosition(FVector(0.0, 0.0, float64(Spec.Scoop.DiscThickness) * 0.5));
    return FTransform(DiscWorld.GetRotation(), Top, DiscWorld.GetScale3D());
}

// The scoop's top centre (the scoop frame's origin) in the station frame.
mixin FVector Get_ScoopRoot(const FCk_Handle_Fry& Self)
{
    return Self.Get_RootWorld().InverseTransformPosition(Self.Get_ScoopWorld().GetLocation());
}

// The whole bowl is over the basket interior (station-frame XY, the scoop's centre against the basket frame's origin):
// where a carried piece can be poured into the basket.
mixin bool Get_IsScoopOverBasket(const FCk_Handle_Fry& Self)
{
    const auto RootWorld = Self.Get_RootWorld();
    const auto BasketRoot = RootWorld.InverseTransformPosition(Self.Get_BasketWorld().GetLocation());
    const auto Offset = Self.Get_ScoopRoot() - BasketRoot;
    return utils_fry::Get_IsBowlOverInterior(Self.Get_Spec(), FVector2D(Offset.X, Offset.Y));
}

// The whole scoop is inside the pot (its centre on the pot reach disc, give or take the slide spring's overshoot): where a
// dip is honoured.
mixin bool Get_IsScoopInPot(const FCk_Handle_Fry& Self)
{
    const auto ScoopRoot = Self.Get_ScoopRoot();
    return float32(ScoopRoot.Size2D()) <= utils_fry::Get_PotReachRadius(Self.Get_Spec()) + utils_fry::k_ReachTolerance;
}

// The disc's underside is above the pot's rim: the scoop may cross it. A scoop still below it (dipped, or rising from a dip)
// is held to the pot as a dipped one.
mixin bool Get_IsScoopClearOfRim(const FCk_Handle_Fry& Self)
{
    const auto Spec = Self.Get_Spec();
    return float32(Self.Get_ScoopRoot().Z) - Spec.Scoop.DiscThickness >= Spec.Zones.RimZ;
}

//--------------------------------------------------------------------------------------------------------------------------
// Piece getters (by identity). An unknown Id ensures and answers the zero value; Get_HasPiece asks first.
//--------------------------------------------------------------------------------------------------------------------------

// Every piece in play in admission order, the lingering lost ones included.
mixin TArray<FMars_CookingFeed_PieceId> Get_PieceIds(const FCk_Handle_Fry& Self)
{
    TArray<FMars_CookingFeed_PieceId> Ids;
    for (const auto& Piece : Self.Get_Fragment(FMars_Fragment_Fry).Pieces)
    { Ids.Add(Piece.Id); }

    return Ids;
}

// From admission until the piece is destroyed (a lost one, at the end of its linger) or reset.
mixin bool Get_HasPiece(const FCk_Handle_Fry& Self, const FMars_CookingFeed_PieceId& InPieceId)
{
    return utils_fry::Find_PieceIndex(Self.Get_Fragment(FMars_Fragment_Fry).Pieces, InPieceId) >= 0;
}

// A copy of the piece's state; an unknown Id ensures and answers a default state.
mixin FMars_Fry_PieceState Get_PieceState(const FCk_Handle_Fry& Self, const FMars_CookingFeed_PieceId& InPieceId)
{
    const auto& Pieces = Self.Get_Fragment(FMars_Fragment_Fry).Pieces;
    const auto Index = utils_fry::Find_PieceIndex(Pieces, InPieceId);
    if (ck::EnsureIfNot(Index >= 0,
        f"[Fry] [{Self.ToString()}] has no piece {utils_cooking_feed::Get_PieceName(InPieceId)} ({Pieces.Num()} in play)"))
    { return FMars_Fry_PieceState(); }

    return Pieces[Index];
}

mixin FCk_Handle Get_PieceEntity(const FCk_Handle_Fry& Self, const FMars_CookingFeed_PieceId& InPieceId)
{
    return Self.Get_PieceState(InPieceId).Entity;
}

mixin FCk_Handle_JoltBody Get_PieceBody(const FCk_Handle_Fry& Self, const FMars_CookingFeed_PieceId& InPieceId)
{
    return Self.Get_PieceState(InPieceId).Body;
}

// The release's preset index the piece arrived with.
mixin int32 Get_PiecePresetIndex(const FCk_Handle_Fry& Self, const FMars_CookingFeed_PieceId& InPieceId)
{
    return Self.Get_PieceState(InPieceId).PresetIndex;
}

mixin EMars_Fry_Whereabouts Get_PieceWhereabouts(const FCk_Handle_Fry& Self, const FMars_CookingFeed_PieceId& InPieceId)
{
    return Self.Get_PieceState(InPieceId).Whereabouts;
}

mixin EMars_Fry_Drain Get_PieceDrain(const FCk_Handle_Fry& Self, const FMars_CookingFeed_PieceId& InPieceId)
{
    return Self.Get_PieceState(InPieceId).Drain;
}

// 0..1: the drain's share of Receiver.DrainSeconds (1 once Drained, 0 while not draining).
mixin float32 Get_PieceDrainProgress(const FCk_Handle_Fry& Self, const FMars_CookingFeed_PieceId& InPieceId)
{
    const auto Piece = Self.Get_PieceState(InPieceId);
    if (Piece.Drain == EMars_Fry_Drain::Drained)
    { return 1.0f; }

    return Math::Clamp(Piece.DrainSeconds / Self.Get_Spec().Receiver.DrainSeconds, 0.0f, 1.0f);
}

// 0 pale .. 1 golden .. 2 overdone.
mixin float32 Get_FaceHeat(const FCk_Handle_Fry& Self, const FMars_CookingFeed_PieceId& InPieceId, EMars_Searing_Face InFace)
{
    const auto Piece = Self.Get_PieceState(InPieceId);
    const auto Index = int32(InFace);
    if (Piece.FaceHeat.IsValidIndex(Index) == false)
    { return 0.0f; }

    return Piece.FaceHeat[Index];
}

mixin EMars_Fry_HeatStage Get_PieceStage(const FCk_Handle_Fry& Self, const FMars_CookingFeed_PieceId& InPieceId, EMars_Searing_Face InFace)
{
    return utils_fry::Get_HeatStage(Self.Get_FaceHeat(InPieceId, InFace));
}

// The piece's faces still below golden.
mixin int32 Get_PaleFaceCount(const FCk_Handle_Fry& Self, const FMars_CookingFeed_PieceId& InPieceId)
{
    return utils_fry::Get_PaleFaceCount(Self.Get_PieceState(InPieceId).FaceHeat);
}

//--------------------------------------------------------------------------------------------------------------------------
// Requests
//--------------------------------------------------------------------------------------------------------------------------

mixin void Request_Look(FCk_Handle_Fry& Self, const FMars_Request_Fry_Look& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_Fry_Requests);
    Requests.LookRequests.Add(InRequest);
}

mixin void Request_SetDrive(FCk_Handle_Fry& Self, const FMars_Request_Fry_SetDrive& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_Fry_Requests);
    Requests.SetDriveRequests.Add(InRequest);
}

mixin void Request_Skim(FCk_Handle_Fry& Self, const FMars_Request_Fry_Skim& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_Fry_Requests);
    Requests.SkimRequests.Add(InRequest);
}

mixin void Request_AddPiece(FCk_Handle_Fry& Self, const FMars_Request_Fry_AddPiece& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_Fry_Requests);
    Requests.AddPieceRequests.Add(InRequest);
}

mixin void Request_Reset(FCk_Handle_Fry& Self, const FMars_Request_Fry_Reset& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_Fry_Requests);
    Requests.ResetRequests.Add(InRequest);
}

//--------------------------------------------------------------------------------------------------------------------------
// Signal Binding
//--------------------------------------------------------------------------------------------------------------------------

mixin void BindTo_OnDriveChanged(FCk_Handle_Fry& Self, FMars_Delegate_Fry_OnDriveChanged InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_Fry_Signals);
    Fragment.OnDriveChanged.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnDriveChanged(FCk_Handle_Fry& Self, FMars_Delegate_Fry_OnDriveChanged InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_Fry_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_Fry_Signals).OnDriveChanged.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void BindTo_OnPieceAdmission(FCk_Handle_Fry& Self, FMars_Delegate_Fry_OnPieceAdmission InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_Fry_Signals);
    Fragment.OnPieceAdmission.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnPieceAdmission(FCk_Handle_Fry& Self, FMars_Delegate_Fry_OnPieceAdmission InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_Fry_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_Fry_Signals).OnPieceAdmission.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void BindTo_OnPieceAdded(FCk_Handle_Fry& Self, FMars_Delegate_Fry_OnPieceAdded InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_Fry_Signals);
    Fragment.OnPieceAdded.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnPieceAdded(FCk_Handle_Fry& Self, FMars_Delegate_Fry_OnPieceAdded InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_Fry_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_Fry_Signals).OnPieceAdded.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void BindTo_OnPieceWhereaboutsChanged(FCk_Handle_Fry& Self, FMars_Delegate_Fry_OnPieceWhereaboutsChanged InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_Fry_Signals);
    Fragment.OnPieceWhereaboutsChanged.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnPieceWhereaboutsChanged(FCk_Handle_Fry& Self, FMars_Delegate_Fry_OnPieceWhereaboutsChanged InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_Fry_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_Fry_Signals).OnPieceWhereaboutsChanged.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void BindTo_OnFaceHeatStage(FCk_Handle_Fry& Self, FMars_Delegate_Fry_OnFaceHeatStage InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_Fry_Signals);
    Fragment.OnFaceHeatStage.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnFaceHeatStage(FCk_Handle_Fry& Self, FMars_Delegate_Fry_OnFaceHeatStage InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_Fry_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_Fry_Signals).OnFaceHeatStage.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void BindTo_OnPieceDrained(FCk_Handle_Fry& Self, FMars_Delegate_Fry_OnPieceDrained InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_Fry_Signals);
    Fragment.OnPieceDrained.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnPieceDrained(FCk_Handle_Fry& Self, FMars_Delegate_Fry_OnPieceDrained InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_Fry_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_Fry_Signals).OnPieceDrained.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void BindTo_OnPieceLost(FCk_Handle_Fry& Self, FMars_Delegate_Fry_OnPieceLost InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_Fry_Signals);
    Fragment.OnPieceLost.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnPieceLost(FCk_Handle_Fry& Self, FMars_Delegate_Fry_OnPieceLost InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_Fry_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_Fry_Signals).OnPieceLost.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void BindTo_OnSkimChanged(FCk_Handle_Fry& Self, FMars_Delegate_Fry_OnSkimChanged InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_Fry_Signals);
    Fragment.OnSkimChanged.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnSkimChanged(FCk_Handle_Fry& Self, FMars_Delegate_Fry_OnSkimChanged InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_Fry_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_Fry_Signals).OnSkimChanged.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}
