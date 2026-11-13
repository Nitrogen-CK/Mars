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

    // A piece moving slower than this (cm/s) lies still: a resting body's contact jitter stays well under it, a hop or a
    // slide does not.
    const float64 k_StillSpeed = 5.0;

    // Whether InBody lies still (its linear speed under k_StillSpeed), whatever it rests on.
    bool Get_IsStill(const FCk_Handle_JoltBody& InBody)
    {
        auto Body = InBody;
        return utils_jolt_body::Get_LinearVelocity(Body).Size() < k_StillSpeed;
    }
    // cm the scoop's centre may sit past the pot disc and still count as in the pot: the slide spring overshoots a target
    // on the disc's edge by a little.
    const float32 k_ReachTolerance = 1.0f;
    // The narrowest square (cm each way) the bowl's centre must have over the basket interior for a pour to be aimed:
    // Validate(FMars_Fry_Spec) rejects a basket that leaves less.
    const float32 k_MinPourWindowCm = 22.0f;
    // How far the skimmer's commanded lift may go past the dip and the carry (its spring's overshoot).
    const float32 k_SkimmerLiftHeadroomCm = 2.0f;
    // How far past the reach's bounding box the skimmer's own slide clamp lies (the kernel's reach clamp is the real one).
    const float64 k_SkimmerSlideMarginCm = 1.0;
    // The ledger's drain progress and face heats step in tenths.
    const int32 k_LedgerSteps = 10;
    // The skimmer ledger's target is sent once it moved this far, at most this often.
    const float64 k_TargetStepCm = 0.1;
    const float32 k_TargetIntervalSeconds = 1.0f / 30.0f;

    // Composes the minigame on InHandle (the station entity, which carries the root transform), and the station's admission
    // inbox and take-out readout. The spec's Nodes are built by the caller and left as composed (the skimmer Idle at its
    // park, carrying): the kernel drives it while Driven, steers its commanded slide within the reach, and sets its lift and
    // tilt by the skim. Nothing is in play until the first release from the station's inbox; an empty first drain starts
    // the watch of the station's queue. A rejected spec, a missing node or a skimmer that cannot do what the kernel asks
    // (tilt to the pour, a Commanded slide, a node axis-aligned with the root) ensures and returns an invalid handle with
    // nothing composed.
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

        // The slide target is in the skimmer node's rest frame: the kernel's root-frame target maps onto it only when the two
        // frames are axis-aligned.
        const auto RootRotation = utils_transform::Get_EntityCurrentTransform(InHandle.As_Transform()).GetRotation();
        const auto NodeRotation = Nodes.Skimmer.Get_NodeWorld().GetRotation();
        const auto IsAxisAligned = (RootRotation.GetForwardVector() - NodeRotation.GetForwardVector()).Size() < 0.001
            && (RootRotation.GetUpVector() - NodeRotation.GetUpVector()).Size() < 0.001;
        if (ck::EnsureIfNot(IsAxisAligned,
            f"[Fry] [{InHandle.ToString()}] needs the skimmer node axis-aligned with the station root (its slide is steered in the root frame)"))
        { return FCk_Handle_Fry(); }

        auto Params = FMars_Fragment_Fry_Params();
        Params.Spec = InSpec;

        InHandle.Add_Fragment(FMars_Feature_Fry());
        InHandle.Add_Fragment(Params);

        auto Fry = InHandle.As_Fry();
        const auto ScoopRoot = Fry.Get_ScoopRoot();
        auto State = FMars_Fragment_Fry();
        State.SkimmerPark = FVector2D(ScoopRoot.X, ScoopRoot.Y) - Nodes.Skimmer.Get_Slide();
        State.SkimmerTarget = State.SkimmerPark;
        InHandle.Add_Fragment(State);
        InHandle.Add_Fragment(FMars_Fragment_Fry_Requests());
        utils_cooking_feed::Add_Admission(InHandle);
        utils_cooking_feed::Add_TakeOut(InHandle);

        // A copy without authority can receive either ledger before it composes: what arrived stands then. A skimmer ledger
        // composed here starts at the park, the authority's own starting command.
        if (InHandle.Has_Fragment(FMars_Fragment_Fry_Net) == false)
        { InHandle.Add_Fragment(FMars_Fragment_Fry_Net(), ECk_Replication::Replicates); }

        if (InHandle.Has_Fragment(FMars_Fragment_Fry_SkimmerNet) == false)
        {
            auto Skimmer = FMars_Fragment_Fry_SkimmerNet();
            Skimmer.Target = State.SkimmerPark;
            InHandle.Add_Fragment(Skimmer, ECk_Replication::Replicates);
        }

        auto Local = FMars_Fragment_Fry_Local();
        Local.Last = TOptional<FMars_Fragment_Fry_Net>(InHandle.Get_Fragment(FMars_Fragment_Fry_Net));
        InHandle.Add_Fragment(Local);
        InHandle.Add_Fragment(FMars_Tag_Fry_NeedsMirror());
        return Fry;
    }

    // The basket's five kinematic boxes under InBasketNode, whose origin is the floor's top centre (the basket frame): the
    // floor (FloorThickness thick, out to the walls' outer faces) centred half its thickness below that origin, and four
    // walls WallHeight tall just outside the interior. Each box is on its own child node (a body needs its own entity).
    // Returns the floor body. A rejected spec ensures and returns an invalid handle.
    FCk_Handle_JoltBody Add_BasketBodies(FCk_Handle_SceneNode& InBasketNode, const FMars_Fry_BasketSpec& InSpec)
    {
        const auto Validation = InSpec.Validate();
        if (ck::EnsureIfNot(Validation.IsValid(), f"[Fry] [{InBasketNode.ToString()}] rejected the basket spec: {Validation.Get_Error()}"))
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
        const auto Validation = InSpec.Validate();
        if (ck::EnsureIfNot(Validation.IsValid(), f"[Fry] [{InScoopNode.ToString()}] rejected the scoop spec: {Validation.Get_Error()}"))
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

    // The carried scoop's reach for a basket whose frame (the floor's top centre) sits at InBasketLocal in the station frame,
    // on the pot's +Y side (the pot disc is Zones.PotRadius's): a corridor as wide as the basket from the pot's axis to the
    // basket interior's near (-Y) edge (overlapping the pot disc, so the two join without a gap), and the basket's interior
    // footprint. InSpec.Reach's look rate is kept.
    FMars_Fry_ReachSpec Make_Reach(const FMars_Fry_Spec& InSpec, FVector InBasketLocal)
    {
        const auto& Basket = InSpec.Basket;
        const auto InteriorNearY = InBasketLocal.Y - float64(Basket.InnerHalfY);

        auto Reach = InSpec.Reach;
        Reach.CorridorCentre = FVector2D(0.0, InteriorNearY * 0.5);
        Reach.CorridorHalfExtent = FVector2D(float64(Basket.InnerHalfX), InteriorNearY * 0.5);
        Reach.BasketCentre = FVector2D(InBasketLocal.X, InBasketLocal.Y);
        Reach.BasketHalfExtent = FVector2D(float64(Basket.InnerHalfX), float64(Basket.InnerHalfY));
        return Reach;
    }

    // The skimmer's Implement as the kernel drives it, from InBase (the assembly's feel: its max tilt, which must reach
    // Scoop.PourPitchDegrees, its lift spring, and its Nodes): never tilted by the look; its slide is the kernel's
    // (Commanded), clamped by the implement only to the box bounding the reach about the skimmer's park at InParkXY (station
    // frame; the kernel's own clamp is the real one); its commanded lift and its pour tilt are the kernel's skim, never the
    // look.
    FMars_Implement_Spec Make_SkimmerImplementSpec(const FMars_Fry_Spec& InSpec, const FMars_Implement_Spec& InBase, FVector2D InParkXY)
    {
        const auto& Scoop = InSpec.Scoop;
        const auto Bounds = Get_ReachBounds(InSpec);
        auto Spec = InBase;
        Spec.Tilt.Axes = EMars_Implement_TiltAxes::None;
        Spec.Tilt.Relax = EMars_Implement_Relax::WhileIdle;
        Spec.Lift.Mode = EMars_Implement_LiftMode::Commanded;
        Spec.Lift.LiftPerLookDegree = 0.0f;
        Spec.Lift.MinLift = Scoop.DipLift - k_SkimmerLiftHeadroomCm;
        Spec.Lift.MaxLift = Scoop.CarryLift + k_SkimmerLiftHeadroomCm;
        Spec.Slide.Mode = EMars_Implement_SlideMode::Commanded;
        Spec.Slide.CmPerLookDegree = 0.0f;
        Spec.Slide.Radius = 0.0f;
        Spec.Slide.Centre = Bounds.Centre - InParkXY;
        Spec.Slide.HalfExtentX = float32(Bounds.HalfExtent.X + k_SkimmerSlideMarginCm);
        Spec.Slide.HalfExtentY = float32(Bounds.HalfExtent.Y + k_SkimmerSlideMarginCm);
        return Spec;
    }

    // Inside the basket interior (basket frame): over the floor within the walls, from the floor's underside up to a
    // piece's height above the wall tops (a piece hopping inside the walls is still in the basket). InHalfHeight is the
    // piece's half height as it lies (utils_foodpiece::Get_WorldHalfExtentZ).
    bool Get_IsInsideBasket(const FMars_Fry_BasketSpec& InBasket, FVector InBasketLocal, float32 InHalfHeight)
    {
        const auto Z = float32(InBasketLocal.Z);
        return Math::Abs(float32(InBasketLocal.X)) <= InBasket.InnerHalfX
            && Math::Abs(float32(InBasketLocal.Y)) <= InBasket.InnerHalfY
            && Z >= -InBasket.FloorThickness
            && Z <= InBasket.WallHeight + 2.0f * InHalfHeight;
    }

    // Over the basket's outer footprint (basket frame XY, walls included), at any height: a piece there is not lost even
    // below the rim (it is in the basket, or on a wall on its way in or out).
    bool Get_IsOverBasketFootprint(const FMars_Fry_BasketSpec& InBasket, FVector InBasketLocal)
    {
        return Math::Abs(float32(InBasketLocal.X)) <= InBasket.InnerHalfX + InBasket.WallThickness
            && Math::Abs(float32(InBasketLocal.Y)) <= InBasket.InnerHalfY + InBasket.WallThickness;
    }

    // Inside the scoop bowl (scoop frame): within BowlRadius of its axis, from the disc's underside up to a piece's height
    // above the lip. InHalfHeight is the piece's half height as it lies.
    bool Get_IsInsideBowl(const FMars_Fry_ScoopSpec& InScoop, FVector InScoopLocal, float32 InHalfHeight)
    {
        const auto Z = float32(InScoopLocal.Z);
        return float32(InScoopLocal.Size2D()) <= InScoop.BowlRadius
            && Z >= -InScoop.DiscThickness
            && Z <= InScoop.LipHeight + 2.0f * InHalfHeight;
    }

    // The whole bowl is over the basket interior: InScoopFromBasket (the scoop frame's origin less the basket frame's, in
    // the station frame's XY) within the interior shrunk by BowlRadius on each side.
    bool Get_IsBowlOverInterior(const FMars_Fry_Spec& InSpec, FVector2D InScoopFromBasket)
    {
        const auto BowlRadius = InSpec.Scoop.BowlRadius;
        return Math::Abs(float32(InScoopFromBasket.X)) <= InSpec.Basket.InnerHalfX - BowlRadius
            && Math::Abs(float32(InScoopFromBasket.Y)) <= InSpec.Basket.InnerHalfY - BowlRadius;
    }

    // 0..1, the share of a piece's height below the oil line (root frame): InCentreZ its middle, InHalfHeight its half height
    // as it lies.
    float32 Get_Immersion(float32 InCentreZ, float32 InHalfHeight, float32 InSurfaceZ)
    {
        return Math::Clamp((InSurfaceZ - (InCentreZ - InHalfHeight)) / (2.0f * InHalfHeight), 0.0f, 1.0f);
    }

    // The height (root frame) of a face's middle: InCentreFrame is the piece's root-relative frame at its middle
    // (utils_foodpiece::Get_CentreFrame).
    float32 Get_FaceCentreZ(const FTransform& InCentreFrame, EMars_FoodPiece_Face InFace, const FVector& InHalfExtents)
    {
        return float32(utils_foodpiece::Get_FaceCentre(InCentreFrame, InFace, InHalfExtents).Z);
    }

    // The cook state InPiece's heat makes of InSeed (the state the piece arrived with): the batter heats are its faces'
    // heat (0 pale, 1 golden, 2 burnt); every other channel is the seed's (its dip, Battered, included: the batter station
    // wrote it, the fryer only admits it).
    FMars_FoodPiece_CookState Get_CookState(const FMars_Fry_PieceState& InPiece, const FMars_FoodPiece_CookState& InSeed)
    {
        auto CookState = InSeed;
        CookState.Batter = InPiece.FaceHeat;
        return CookState;
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

    // The index of the piece whose entity is InPiece (lingering lost ones included); -1 = none.
    int32 Find_PieceIndexByHandle(const TArray<FMars_Fry_PieceState>& InPieces, const FCk_Handle_FoodPiece& InPiece)
    {
        for (int32 Index = 0; Index < InPieces.Num(); ++Index)
        {
            if (InPieces[Index].Piece == InPiece)
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

    //----------------------------------------------------------------------------------------------------------------------
    // The skimmer's commands: the authority's drain gives them from the kernel's state, a copy without authority's mirror
    // from the skimmer ledger.
    //----------------------------------------------------------------------------------------------------------------------

    void Send_SkimmerDrive(FCk_Handle_Fry& InFry, EMars_Implement_Drive InDrive)
    {
        auto Skimmer = InFry.Get_Skimmer();
        Skimmer.Request_SetDrive(FMars_Request_Implement_SetDrive(InDrive));
    }

    // The skim's pose: the skimmer's lift spring lowers or raises the scoop, its tilt tips it toward the operator for the
    // pour (a positive pitch raises the far side, +X, in the skimmer's rest frame, which Add ensures is axis-aligned with the
    // root) or levels it.
    void Send_SkimmerPose(FCk_Handle_Fry& InFry, EMars_Fry_Skim InSkim)
    {
        const auto Scoop = InFry.Get_Spec().Scoop;
        const auto Lift = InSkim == EMars_Fry_Skim::Dip ? Scoop.DipLift : Scoop.CarryLift;
        const auto Pitch = InSkim == EMars_Fry_Skim::Pour ? float64(Scoop.PourPitchDegrees) : 0.0;
        auto Skimmer = InFry.Get_Skimmer();
        Skimmer.Request_SetLiftTarget(FMars_Request_Implement_SetLiftTarget(Lift));
        Skimmer.Request_SetTiltTarget(FMars_Request_Implement_SetTiltTarget(FRotator(Pitch, 0.0, 0.0)));
    }

    // InTarget (root-frame XY) in the skimmer's rest frame: its offset from the park (the rest frame is axis-aligned with the
    // root; Add ensures it).
    void Send_SkimmerSlide(FCk_Handle_Fry& InFry, FVector2D InTarget)
    {
        auto Skimmer = InFry.Get_Skimmer();
        Skimmer.Request_SetSlideTarget(FMars_Request_Implement_SetSlideTarget(InTarget - InFry.Get_SkimmerPark()));
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Replication
    //----------------------------------------------------------------------------------------------------------------------

    // The kernel's ledger a machine without authority reads it through, rebuilt from the live state and what the caller
    // announced: written and marked dirty only when a field or a row differs; then the skimmer's ledger (Publish_Skimmer).
    // Called only by the kernel's processors on the authority: by the drain once after its last apply and by the tick after
    // its readout, each before its first broadcast.
    void Publish(FCk_Handle_Fry& InFry, const FMars_Fry_Answers& InAnswers)
    {
        const auto State = InFry.Get_Fragment(FMars_Fragment_Fry);
        const auto Receiver = InFry.Get_Spec().Receiver;
        const auto Ledger = InFry.Get_Fragment(FMars_Fragment_Fry_Net);
        auto Next = Ledger;
        Next.Counts = Make_Counts(State.Tally);
        Next.Pieces.Empty();
        for (const auto& Piece : State.Pieces)
        { Next.Pieces.Add(Make_PieceRow(Piece, Receiver)); }

        if (InAnswers.RefusedSkims.Num() > 0)
        {
            Next.SkimRefusalSerial += InAnswers.RefusedSkims.Num();
            Next.LastSkimRefused = InAnswers.RefusedSkims.Last();
        }

        if (InAnswers.TakeOutRefusals.Num() > 0)
        {
            Next.TakeOutRefusalSerial += InAnswers.TakeOutRefusals.Num();
            Next.LastTakeOutRefusal = InAnswers.TakeOutRefusals.Last();
        }

        if (InAnswers.AdmissionRefusals.Num() > 0)
        {
            Next.AdmissionRefusalSerial += InAnswers.AdmissionRefusals.Num();
            Next.LastAdmissionRefusal = InAnswers.AdmissionRefusals.Last();
        }

        if (Get_IsSameLedger(Next, Ledger) == false)
        {
            InFry.Get_Fragment(FMars_Fragment_Fry_Net) = Next;
            FCk_Handle Entity = InFry;
            Entity.Request_MarkReplicationDirty(FMars_Fragment_Fry_Net);
        }

        Publish_Skimmer(InFry, State);
    }

    // The skimmer's command: written at once, target included, when its drive or skim differs from the ledger's; the target
    // alone once it moved k_TargetStepCm and k_TargetIntervalSeconds passed since it was last written (the tick advances
    // that clock), so a look sweeping the scoop sends a paced stream.
    void Publish_Skimmer(FCk_Handle_Fry& InFry, const FMars_Fragment_Fry& InState)
    {
        const auto Ledger = InFry.Get_Fragment(FMars_Fragment_Fry_SkimmerNet);
        const auto Seconds = InFry.Get_Fragment(FMars_Fragment_Fry_Local).SecondsSinceTarget;
        const auto IsPoseNew = Ledger.Drive != InState.Drive || Ledger.Skim != InState.Skim;
        const auto IsTargetDue = (InState.SkimmerTarget - Ledger.Target).Size() >= k_TargetStepCm && Seconds >= k_TargetIntervalSeconds;
        if (IsPoseNew == false && IsTargetDue == false)
        { return; }

        auto Next = FMars_Fragment_Fry_SkimmerNet();
        Next.Drive = InState.Drive;
        Next.Skim = InState.Skim;
        Next.Target = InState.SkimmerTarget;
        InFry.Get_Fragment(FMars_Fragment_Fry_SkimmerNet) = Next;
        InFry.Get_Fragment(FMars_Fragment_Fry_Local).SecondsSinceTarget = 0.0f;
        FCk_Handle Entity = InFry;
        Entity.Request_MarkReplicationDirty(FMars_Fragment_Fry_SkimmerNet);
    }

    FMars_Fry_Counts Make_Counts(const FMars_Fry_Tally& InTally)
    {
        auto Counts = FMars_Fry_Counts();
        Counts.Ejections = InTally.Ejections;
        Counts.Catches = InTally.Catches;
        Counts.Retrievals = InTally.Retrievals;
        Counts.Losses = InTally.Losses;
        Counts.TakenOut = InTally.TakenOut;
        return Counts;
    }

    // A piece as the ledger carries it: its drain progress and face heats floored to a tenth (a client reads up to a tenth
    // behind, never ahead; exactly 1 and 2 stay exact).
    FMars_Fry_PieceRow Make_PieceRow(const FMars_Fry_PieceState& InPiece, const FMars_Fry_ReceiverSpec& InReceiver)
    {
        auto Row = FMars_Fry_PieceRow();
        Row.Id = InPiece.Id;
        Row.Piece = InPiece.Entity;
        Row.Whereabouts = InPiece.Whereabouts;
        Row.Drain = InPiece.Drain;
        const auto Progress = InPiece.Drain == EMars_Fry_Drain::Drained ? 1.0f : Math::Clamp(InPiece.DrainSeconds / InReceiver.DrainSeconds, 0.0f, 1.0f);
        Row.DrainProgress = Floor_ToStep(Progress);
        for (const auto Heat : InPiece.FaceHeat)
        { Row.FaceHeat.Add(Floor_ToStep(Heat)); }

        return Row;
    }

    float32 Floor_ToStep(float32 InValue)
    {
        return float32(Math::FloorToInt(InValue * float32(k_LedgerSteps))) / float32(k_LedgerSteps);
    }

    // The summary's rule over InRows and InCounts, with authority or without (Get_Summary).
    FMars_Fry_Summary Make_Summary(const TArray<FMars_Fry_PieceRow>& InRows, const FMars_Fry_Counts& InCounts)
    {
        auto Summary = FMars_Fry_Summary();
        for (const auto& Row : InRows)
        {
            if (Row.Whereabouts == EMars_Fry_Whereabouts::Lost)
            { continue; }

            if (Row.Whereabouts == EMars_Fry_Whereabouts::Oil)
            { Summary.InOil += 1; }
            else if (Row.Whereabouts == EMars_Fry_Whereabouts::Skimmer)
            { Summary.OnSkimmer += 1; }
            else if (Row.Whereabouts == EMars_Fry_Whereabouts::Airborne)
            { Summary.Airborne += 1; }
            else if (Row.Whereabouts == EMars_Fry_Whereabouts::DrainBasket)
            {
                Summary.InBasket += 1;
                if (Row.Drain == EMars_Fry_Drain::Drained)
                { Summary.Drained += 1; }
            }

            for (const auto Heat : Row.FaceHeat)
            {
                if (Heat < 1.0f)
                { Summary.PaleFaces += 1; }

                if (Heat >= 2.0f)
                { Summary.OverdoneFaces += 1; }
            }
        }

        Summary.Lost = InCounts.Losses;
        Summary.TakenOut = InCounts.TakenOut;
        Summary.Admitted = Summary.InOil + Summary.OnSkimmer + Summary.Airborne + Summary.InBasket + Summary.Lost + Summary.TakenOut;
        return Summary;
    }

    bool Get_IsSameLedger(const FMars_Fragment_Fry_Net& InA, const FMars_Fragment_Fry_Net& InB)
    {
        const auto& A = InA.Counts;
        const auto& B = InB.Counts;
        if (A.Ejections != B.Ejections || A.Catches != B.Catches || A.Retrievals != B.Retrievals || A.Losses != B.Losses
            || A.TakenOut != B.TakenOut || InA.Pieces.Num() != InB.Pieces.Num()
            || InA.SkimRefusalSerial != InB.SkimRefusalSerial || InA.LastSkimRefused != InB.LastSkimRefused
            || InA.TakeOutRefusalSerial != InB.TakeOutRefusalSerial || InA.LastTakeOutRefusal != InB.LastTakeOutRefusal
            || InA.AdmissionRefusalSerial != InB.AdmissionRefusalSerial || InA.LastAdmissionRefusal != InB.LastAdmissionRefusal)
        { return false; }

        for (int32 Index = 0; Index < InA.Pieces.Num(); ++Index)
        {
            const auto& RowA = InA.Pieces[Index];
            const auto& RowB = InB.Pieces[Index];
            if (RowA.Id.Get_IsSame(RowB.Id) == false || RowA.Piece != RowB.Piece || RowA.Whereabouts != RowB.Whereabouts
                || RowA.Drain != RowB.Drain || RowA.DrainProgress != RowB.DrainProgress || Get_IsSameHeats(RowA.FaceHeat, RowB.FaceHeat) == false)
            { return false; }
        }

        return true;
    }

    bool Get_IsSameHeats(const TArray<float32>& InA, const TArray<float32>& InB)
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

    // The ledger row carrying InPieceId; -1 = none.
    int32 Find_RowIndex(const TArray<FMars_Fry_PieceRow>& InRows, const FMars_CookingFeed_PieceId& InPieceId)
    {
        for (int32 Index = 0; Index < InRows.Num(); ++Index)
        {
            if (InRows[Index].Id.Get_IsSame(InPieceId))
            { return Index; }
        }

        return -1;
    }
}

//--------------------------------------------------------------------------------------------------------------------------
// Getters
//--------------------------------------------------------------------------------------------------------------------------

mixin FMars_Fry_Spec Get_Spec(const FCk_Handle_Fry& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Fry_Params).Spec;
}

// The kernel's replicated ledger as this machine has it: what a machine without authority reads the kernel through.
mixin FMars_Fragment_Fry_Net Get_Ledger(const FCk_Handle_Fry& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Fry_Net);
}

// The skimmer's replicated command as this machine has it: what a machine without authority commands its skimmer from.
mixin FMars_Fragment_Fry_SkimmerNet Get_SkimmerLedger(const FCk_Handle_Fry& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Fry_SkimmerNet);
}

// Without authority the getters below that read the kernel's state read the replicated ledgers instead (and this machine's
// own copies of the pieces): the live state is the authority's.
mixin bool Get_ReadsLedger(const FCk_Handle_Fry& Self)
{
    return utils_net::Get_HasAuthority(Self) == false;
}

mixin EMars_Implement_Drive Get_Drive(const FCk_Handle_Fry& Self)
{
    if (Self.Get_ReadsLedger())
    { return Self.Get_Fragment(FMars_Fragment_Fry_SkimmerNet).Drive; }

    return Self.Get_Fragment(FMars_Fragment_Fry).Drive;
}

// The skimmer's commanded pose (Carry whenever it is idle).
mixin EMars_Fry_Skim Get_Skim(const FCk_Handle_Fry& Self)
{
    if (Self.Get_ReadsLedger())
    { return Self.Get_Fragment(FMars_Fragment_Fry_SkimmerNet).Skim; }

    return Self.Get_Fragment(FMars_Fragment_Fry).Skim;
}

// Root-frame XY of the scoop's commanded centre; without authority as the skimmer ledger last carried it.
mixin FVector2D Get_SkimmerTarget(const FCk_Handle_Fry& Self)
{
    if (Self.Get_ReadsLedger())
    { return Self.Get_Fragment(FMars_Fragment_Fry_SkimmerNet).Target; }

    return Self.Get_Fragment(FMars_Fragment_Fry).SkimmerTarget;
}

mixin FCk_Handle_Implement Get_Skimmer(const FCk_Handle_Fry& Self)
{
    return Self.Get_Spec().Nodes.Skimmer;
}

// Root-frame XY of the scoop's centre at the skimmer's rest, as this machine's Add measured it.
mixin FVector2D Get_SkimmerPark(const FCk_Handle_Fry& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Fry).SkimmerPark;
}

// Without authority: the ledger's counts, with Seconds 0 (the clock stays with the authority).
mixin FMars_Fry_Tally Get_Tally(const FCk_Handle_Fry& Self)
{
    if (Self.Get_ReadsLedger() == false)
    { return Self.Get_Fragment(FMars_Fragment_Fry).Tally; }

    const auto& Counts = Self.Get_Fragment(FMars_Fragment_Fry_Net).Counts;
    auto Tally = FMars_Fry_Tally();
    Tally.Ejections = Counts.Ejections;
    Tally.Catches = Counts.Catches;
    Tally.Retrievals = Counts.Retrievals;
    Tally.Losses = Counts.Losses;
    Tally.TakenOut = Counts.TakenOut;
    return Tally;
}

// Admitted = InOil + OnSkimmer + Airborne + InBasket (in play) + Lost + TakenOut (since the last reset; a lost piece stays
// counted after its body is destroyed). Without authority the same rule over the ledger's rows and counts.
mixin FMars_Fry_Summary Get_Summary(const FCk_Handle_Fry& Self)
{
    if (Self.Get_ReadsLedger())
    {
        const auto& Ledger = Self.Get_Fragment(FMars_Fragment_Fry_Net);
        return utils_fry::Make_Summary(Ledger.Pieces, Ledger.Counts);
    }

    const auto& State = Self.Get_Fragment(FMars_Fragment_Fry);
    const auto Receiver = Self.Get_Spec().Receiver;
    TArray<FMars_Fry_PieceRow> Rows;
    for (const auto& Piece : State.Pieces)
    { Rows.Add(utils_fry::Make_PieceRow(Piece, Receiver)); }

    return utils_fry::Make_Summary(Rows, utils_fry::Make_Counts(State.Tally));
}

// The Drained pieces a TakeOut without a named piece would hand back: the station's take-out readout as the Tick last
// wrote it, or its replicated count without authority.
mixin int32 Get_TakeableCount(const FCk_Handle_Fry& Self)
{
    return utils_cooking_feed::Get_TakeableCount(Self);
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
    if (Self.Get_ReadsLedger())
    {
        for (const auto& Row : Self.Get_Fragment(FMars_Fragment_Fry_Net).Pieces)
        { Ids.Add(Row.Id); }

        return Ids;
    }

    for (const auto& Piece : Self.Get_Fragment(FMars_Fragment_Fry).Pieces)
    { Ids.Add(Piece.Id); }

    return Ids;
}

// From admission until the piece is taken out or destroyed (a lost one, at the end of its linger).
mixin bool Get_HasPiece(const FCk_Handle_Fry& Self, const FMars_CookingFeed_PieceId& InPieceId)
{
    if (Self.Get_ReadsLedger())
    { return utils_fry::Find_RowIndex(Self.Get_Fragment(FMars_Fragment_Fry_Net).Pieces, InPieceId) >= 0; }

    return utils_fry::Find_PieceIndex(Self.Get_Fragment(FMars_Fragment_Fry).Pieces, InPieceId) >= 0;
}

// A copy of the piece's state; an unknown Id ensures and answers a default state. Without authority it is built from the
// ledger's row (Get_LedgerPieceState).
mixin FMars_Fry_PieceState Get_PieceState(const FCk_Handle_Fry& Self, const FMars_CookingFeed_PieceId& InPieceId)
{
    if (Self.Get_ReadsLedger())
    { return Self.Get_LedgerPieceState(InPieceId); }

    const auto& Pieces = Self.Get_Fragment(FMars_Fragment_Fry).Pieces;
    const auto Index = utils_fry::Find_PieceIndex(Pieces, InPieceId);
    if (ck::EnsureIfNot(Index >= 0,
        f"[Fry] [{Self.ToString()}] has no piece {utils_cooking_feed::Get_PieceName(InPieceId)} ({Pieces.Num()} in play)"))
    { return FMars_Fry_PieceState(); }

    return Pieces[Index];
}

// The row's id, whereabouts, drain and face heats (a tenth behind at most); DrainSeconds its progress of the spec's drain;
// its Entity and Piece the row's handle (invalid while it has not replicated here); its CentreLocal and HalfExtents from
// this copy's mesh metrics, as the authority reads them at admission, once it is a Ready food piece here (zero before); no
// body.
mixin FMars_Fry_PieceState Get_LedgerPieceState(const FCk_Handle_Fry& Self, const FMars_CookingFeed_PieceId& InPieceId)
{
    const auto& Rows = Self.Get_Fragment(FMars_Fragment_Fry_Net).Pieces;
    const auto Index = utils_fry::Find_RowIndex(Rows, InPieceId);
    if (ck::EnsureIfNot(Index >= 0,
        f"[Fry] [{Self.ToString()}] has no piece {utils_cooking_feed::Get_PieceName(InPieceId)} in its ledger ({Rows.Num()} in play)"))
    { return FMars_Fry_PieceState(); }

    const auto Row = Rows[Index];
    auto State = FMars_Fry_PieceState();
    State.Id = Row.Id;
    State.Entity = Row.Piece;
    State.Whereabouts = Row.Whereabouts;
    State.Drain = Row.Drain;
    State.FaceHeat = Row.FaceHeat;
    State.DrainSeconds = Row.DrainProgress * Self.Get_Spec().Receiver.DrainSeconds;
    if (ck::IsValid(Row.Piece))
    { State.Piece = Row.Piece.As_FoodPiece(ECk_SanityCheck::UnChecked); }

    if (ck::IsValid(State.Piece) && utils_foodpiece::Get_IsLiveEntity(Row.Piece) && State.Piece.Get_Status() == EMars_FoodPiece_Status::Ready)
    {
        const auto Metrics = utils_runtime_mesh::Get_Metrics(State.Piece.Get_Geometry());
        State.CentreLocal = utils_foodpiece::Get_BoundsCentre(Metrics);
        State.HalfExtents = utils_foodpiece::Get_BoundsHalfExtents(Metrics);
    }

    return State;
}

mixin FCk_Handle Get_PieceEntity(const FCk_Handle_Fry& Self, const FMars_CookingFeed_PieceId& InPieceId)
{
    return Self.Get_PieceState(InPieceId).Entity;
}

mixin FCk_Handle_JoltBody Get_PieceBody(const FCk_Handle_Fry& Self, const FMars_CookingFeed_PieceId& InPieceId)
{
    return Self.Get_PieceState(InPieceId).Body;
}

mixin FCk_Handle_FoodPiece Get_PieceHandle(const FCk_Handle_Fry& Self, const FMars_CookingFeed_PieceId& InPieceId)
{
    return Self.Get_PieceState(InPieceId).Piece;
}

// Half the piece's bounds along its own axes, as read at admission.
mixin FVector Get_PieceHalfExtents(const FCk_Handle_Fry& Self, const FMars_CookingFeed_PieceId& InPieceId)
{
    return Self.Get_PieceState(InPieceId).HalfExtents;
}

// The middle of the piece's bounds in the world; zero once its entity is gone.
mixin FVector Get_PieceCentre(const FCk_Handle_Fry& Self, const FMars_CookingFeed_PieceId& InPieceId)
{
    const auto Piece = Self.Get_PieceState(InPieceId);
    if (ck::Is_NOT_Valid(Piece.Entity))
    { return FVector::ZeroVector; }

    const auto PieceWorld = utils_transform::Get_EntityCurrentTransform(Piece.Entity.As_Transform());
    return PieceWorld.TransformPosition(Piece.CentreLocal);
}

// The piece's cook state as the fryer would hand it back now: its batter the faces' heat so far, every other channel the
// piece's own (a default state while this machine has no live copy of it).
mixin FMars_FoodPiece_CookState Get_PieceCookState(const FCk_Handle_Fry& Self, const FMars_CookingFeed_PieceId& InPieceId)
{
    const auto Piece = Self.Get_PieceState(InPieceId);
    auto Seed = FMars_FoodPiece_CookState();
    if (ck::IsValid(Piece.Piece) && utils_foodpiece::Get_IsLiveEntity(Piece.Entity))
    { Seed = Piece.Piece.Get_CookState(); }

    return utils_fry::Get_CookState(Piece, Seed);
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
mixin float32 Get_FaceHeat(const FCk_Handle_Fry& Self, const FMars_CookingFeed_PieceId& InPieceId, EMars_FoodPiece_Face InFace)
{
    const auto Piece = Self.Get_PieceState(InPieceId);
    const auto Index = int32(InFace);
    if (Piece.FaceHeat.IsValidIndex(Index) == false)
    { return 0.0f; }

    return Piece.FaceHeat[Index];
}

mixin EMars_Fry_HeatStage Get_PieceStage(const FCk_Handle_Fry& Self, const FMars_CookingFeed_PieceId& InPieceId, EMars_FoodPiece_Face InFace)
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

mixin void Request_Reset(FCk_Handle_Fry& Self, const FMars_Request_Fry_Reset& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_Fry_Requests);
    Requests.ResetRequests.Add(InRequest);
}

mixin void Request_TakeOut(FCk_Handle_Fry& Self, const FMars_Request_Fry_TakeOut& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_Fry_Requests);
    Requests.TakeOutRequests.Add(InRequest);
}

mixin void Request_Readopt(FCk_Handle_Fry& Self, const FMars_Request_Fry_Readopt& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_Fry_Requests);
    Requests.ReadoptRequests.Add(InRequest);
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

mixin void BindTo_OnSkimRefused(FCk_Handle_Fry& Self, FMars_Delegate_Fry_OnSkimRefused InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_Fry_Signals);
    Fragment.OnSkimRefused.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnSkimRefused(FCk_Handle_Fry& Self, FMars_Delegate_Fry_OnSkimRefused InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_Fry_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_Fry_Signals).OnSkimRefused.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void BindTo_OnPieceTakenOut(FCk_Handle_Fry& Self, FMars_Delegate_Fry_OnPieceTakenOut InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_Fry_Signals);
    Fragment.OnPieceTakenOut.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnPieceTakenOut(FCk_Handle_Fry& Self, FMars_Delegate_Fry_OnPieceTakenOut InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_Fry_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_Fry_Signals).OnPieceTakenOut.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void BindTo_OnAdmissionRefused(FCk_Handle_Fry& Self, FMars_Delegate_Fry_OnAdmissionRefused InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_Fry_Signals);
    Fragment.OnAdmissionRefused.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnAdmissionRefused(FCk_Handle_Fry& Self, FMars_Delegate_Fry_OnAdmissionRefused InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_Fry_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_Fry_Signals).OnAdmissionRefused.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void BindTo_OnTakeOutRefused(FCk_Handle_Fry& Self, FMars_Delegate_Fry_OnTakeOutRefused InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_Fry_Signals);
    Fragment.OnTakeOutRefused.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnTakeOutRefused(FCk_Handle_Fry& Self, FMars_Delegate_Fry_OnTakeOutRefused InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_Fry_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_Fry_Signals).OnTakeOutRefused.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}
