namespace utils_severed_limb
{
    // Composes a severed limb on InLimb, whose root transform is already added and whose pieces are its lifetime
    // children, placed where they were cut. Every machine: the whole limb is raised by Get_BirthLift (every piece by the
    // same height, never sideways) so no piece's body starts below the ground; the feature, the state, the pose ledger
    // seeded with the raised pieces' poses (replicated; one that already arrived stands and this copy has taken it), the
    // mirror state. With authority only: per piece a dynamic box body, shorter than drawn (Get_BodyHalfExtents); a hinge
    // at each knee about the upper piece's Z, k_KneeLimitDegrees either side of the cut, and a point joint at the ankle,
    // each joint's two bodies never colliding with each other; one pending impulse on the first piece. No timer: the
    // caller ends the limb. A rejected spec ensures and returns an invalid handle with nothing composed.
    FCk_Handle_SeveredLimb Add(FCk_Handle& InLimb, FMars_SeveredLimb_Spec InSpec)
    {
        const auto Validation = InSpec.Validate();
        if (ck::EnsureIfNot(Validation.IsValid(), f"[SeveredLimb] [{InLimb.ToString()}] rejected the spec: {Validation.Get_Error()}"))
        { return FCk_Handle_SeveredLimb(); }

        const auto RootTransform = InLimb.As_Transform(ECk_SanityCheck::UnChecked);
        if (ck::EnsureIfNot(ck::IsValid(RootTransform), f"[SeveredLimb] [{InLimb.ToString()}] has no root transform"))
        { return FCk_Handle_SeveredLimb(); }

        const auto Root = utils_transform::Get_EntityCurrentTransform(RootTransform);

        auto State = FMars_Fragment_SeveredLimb();
        State.Pieces = InSpec.Pieces;
        State.BirthLift = Get_BirthLift(InSpec);

        // The pieces move when the transform requests drain, before any body is set up: what Add reads below is the
        // raised pose.
        const auto Lift = FVector::UpVector * State.BirthLift;
        auto Seed = FMars_Fragment_SeveredLimb_Net();
        for (const auto& Piece : InSpec.Pieces)
        {
            auto PieceTransform = Piece.Piece;
            const auto Raised = Get_Raised(utils_transform::Get_EntityCurrentTransform(PieceTransform), Lift);
            if (State.BirthLift > 0.0)
            { utils_transform::Request_SetLocation(PieceTransform, FCk_Request_Transform_SetLocation(Raised.GetLocation())); }

            Seed.Pieces.Add(FMars_SeveredLimb_Pose(Raised.GetRelativeTransform(Root)));
        }

        for (int32 Index = 0; Index + 1 < InSpec.Pieces.Num(); ++Index)
        { State.JointEnds.Add(Make_JointEnds(InSpec.Pieces[Index], InSpec.Pieces[Index + 1])); }

        const auto HasAuthority = utils_net::Get_HasAuthority(InLimb);
        auto Launch = FMars_BodyPart_PendingImpulse();
        if (HasAuthority)
        {
            auto Bodies = TArray<FCk_Handle_JoltBody>();
            for (const auto& Piece : InSpec.Pieces)
            { Bodies.Add(Add_PieceBody(Piece, InSpec.Debris)); }

            for (int32 Index = 0; Index + 1 < Bodies.Num(); ++Index)
            {
                const auto IsAnkle = Index + 2 == Bodies.Num();
                auto JointSpec = Make_JointSpec(Get_Raised(utils_transform::Get_EntityCurrentTransform(InSpec.Pieces[Index].Piece), Lift),
                    InSpec.Pieces[Index].HalfExtents, IsAnkle);
                FCk_Handle Lower = Bodies[Index + 1];
                JointSpec.Set_OtherBody(Lower);
                State.Joints.Add(utils_jolt_constraint::Create(Bodies[Index], JointSpec));
            }

            Launch = FMars_BodyPart_PendingImpulse(Bodies[0], InSpec.LaunchVelocity * InSpec.Debris.MassKg);
        }

        auto Local = FMars_Fragment_SeveredLimb_Local();
        Local.Last = TOptional<FMars_Fragment_SeveredLimb_Net>(Seed);
        if (InLimb.Has_Fragment(FMars_Fragment_SeveredLimb_Net))
        { Local.InitialState = EMars_Net_InitialState::Taken; }
        else
        { InLimb.Add_Fragment(Seed, ECk_Replication::Replicates); }

        InLimb.Add_Fragment(FMars_Feature_SeveredLimb());
        InLimb.Add_Fragment(State);
        InLimb.Add_Fragment(Local);
        InLimb.Add_Fragment(FMars_Tag_SeveredLimb_NeedsMirror());

        if (HasAuthority)
        {
            InLimb.AddOrGet_Fragment(FMars_Fragment_BodyPart_PendingDebris).Impulses.Add(Launch);
            InLimb.Add_Fragment(FMars_Tag_SeveredLimb_Publishing());
        }

        return InLimb.As_SeveredLimb();
    }

    // How a severed part's limb is thrown: away from its monster's root in the horizontal plane at the debris's outward
    // speed, plus its up speed. InLimbCentre is where the limb is.
    FVector Get_Velocity(const FCk_Handle_BodyPart& InPart, FVector InLimbCentre)
    {
        const auto Debris = InPart.Get_Spec().Severance.Debris;

        FCk_Handle MonsterEntity = InPart.Get_Monster();
        const auto Body = MonsterEntity.As_Transform(ECk_SanityCheck::UnChecked);
        auto Outward = ck::IsValid(Body) ? InLimbCentre - utils_transform::Get_EntityCurrentLocation(Body) : FVector::ZeroVector;
        Outward.Z = 0.0;
        return Outward.GetSafeNormal() * Debris.OutwardSpeed + FVector::UpVector * Debris.UpSpeed;
    }

    // A piece's body: its drawn box less its cross-section half thickness at each jointed end, never shorter than half
    // of it, so a bent knee does not bury one piece's end in the other's. Every piece of a limb is jointed at one end at
    // least; the box is centred on the piece, so its free end gives up the same.
    FVector Get_BodyHalfExtents(FVector InHalfExtents)
    {
        const auto HalfThickness = Math::Max(InHalfExtents.Y, InHalfExtents.Z);
        return FVector(Math::Max(InHalfExtents.X - HalfThickness, InHalfExtents.X * 0.5), InHalfExtents.Y, InHalfExtents.Z);
    }

    // How far the whole limb must rise so that no piece's body starts below the static ground under it: for each piece
    // the lowest corner of its body box, against a ray straight down from the top of that box onto static, non-sensor
    // ground at the corner, plus k_BirthClearanceCm. Zero when every piece is clear or nothing is under it. Read from the
    // world, not from the leg, so it holds for any cut and on every machine, headless.
    float64 Get_BirthLift(const FMars_SeveredLimb_Spec& InSpec)
    {
        auto Filter = FCk_Jolt_QueryFilter();
        Filter.Set_BodySelection(ECk_Jolt_QueryBodySelection::StaticNonSensor);

        auto Lift = 0.0;
        for (const auto& Piece : InSpec.Pieces)
        {
            const auto Pose = utils_transform::Get_EntityCurrentTransform(Piece.Piece);
            const auto HalfExtents = Get_BodyHalfExtents(Piece.HalfExtents);
            const auto Corner = Get_LowestCorner(Pose, HalfExtents);
            const auto From = FVector(Corner.X, Corner.Y, Pose.GetLocation().Z + HalfExtents.Size());
            const auto Hit = utils_jolt_query::Get_RayCast(From, Corner - FVector::UpVector * HalfExtents.Size(), Filter);
            if (Hit.Get_HasHit())
            { Lift = Math::Max(Lift, Hit.Get_Position().Z + constants_severed_limb::k_BirthClearanceCm - Corner.Z); }
        }

        return Lift;
    }

    // The lowest of the eight corners of a box of InHalfExtents at InPose.
    FVector Get_LowestCorner(FTransform InPose, FVector InHalfExtents)
    {
        auto Lowest = InPose.TransformPosition(InHalfExtents);
        for (int32 Index = 1; Index < 8; ++Index)
        {
            const auto Signs = FVector((Index & 1) != 0 ? -1.0 : 1.0, (Index & 2) != 0 ? -1.0 : 1.0, (Index & 4) != 0 ? -1.0 : 1.0);
            const auto Corner = InPose.TransformPosition(InHalfExtents * Signs);
            if (Corner.Z < Lowest.Z)
            { Lowest = Corner; }
        }

        return Lowest;
    }

    FTransform Get_Raised(FTransform InPose, FVector InLift)
    {
        auto Raised = InPose;
        Raised.SetLocation(InPose.GetLocation() + InLift);
        return Raised;
    }

    // The ledger's only writer, on the authority.
    void Publish(FCk_Handle_SeveredLimb& InLimb, const FMars_Fragment_SeveredLimb_Net& InLedger)
    {
        FCk_Handle Entity = InLimb;
        auto& Ledger = Entity.Get_Fragment(FMars_Fragment_SeveredLimb_Net);
        Ledger = InLedger;
        Entity.Request_MarkReplicationDirty(FMars_Fragment_SeveredLimb_Net);
    }

    // Whether any piece of InTo moved more than k_MoveCm or k_MoveDegrees from the same piece of InFrom.
    bool Get_HasMoved(const TArray<FMars_SeveredLimb_Pose>& InFrom, const TArray<FMars_SeveredLimb_Pose>& InTo)
    {
        if (InFrom.Num() != InTo.Num())
        { return true; }

        for (int32 Index = 0; Index < InTo.Num(); ++Index)
        {
            const auto Distance = (InTo[Index].Location - InFrom[Index].Location).Size();
            const auto Degrees = Math::RadiansToDegrees(InTo[Index].Rotation.AngularDistance(InFrom[Index].Rotation));
            if (Distance > constants_severed_limb::k_MoveCm || Degrees > constants_severed_limb::k_MoveDegrees)
            { return true; }
        }

        return false;
    }

    bool Get_IsFinite(FVector InVector)
    {
        return Math::IsFinite(InVector.X) && Math::IsFinite(InVector.Y) && Math::IsFinite(InVector.Z);
    }

    // The world pose InPose takes under InRoot.
    FTransform Get_WorldTransform(const FMars_SeveredLimb_Pose& InPose, FTransform InRoot)
    {
        return FTransform(InPose.Rotation, InPose.Location) * InRoot;
    }

    FCk_Handle_JoltBody Add_PieceBody(FMars_SeveredLimb_PieceSpec InPiece, const FMars_BodyPart_Debris& InDebris)
    {
        auto Shape = FCk_Jolt_ShapeDimensions(ECk_Jolt_ShapeType::Box);
        Shape.Set_HalfExtents(Get_BodyHalfExtents(InPiece.HalfExtents));
        auto BodySpec = FCk_JoltBody_Spec(ECk_JoltBody_ShapeSource::ExplicitShape);
        BodySpec.Set_ShapeDimensions(Shape);
        BodySpec.Set_MotionType(ECk_MotionType::Dynamic);
        BodySpec.Set_MassSource(ECk_JoltBody_MassSource::Explicit);
        BodySpec.Set_MassKg(InDebris.MassKg);
        BodySpec.Set_CollisionProfileName(InDebris.CollisionProfile);

        auto Piece = InPiece.Piece;
        return utils_jolt_body::Add(Piece, BodySpec);
    }

    // The joint at the end of the upper piece's drawn box: a hinge about its Z (the knee bends in its XY plane), or, at
    // the ankle, a point joint. Its two bodies never collide with each other: neighbours overlap at the joint and would
    // push each other apart.
    FCk_JoltConstraint_Spec Make_JointSpec(FTransform InUpper, FVector InUpperHalfExtents, bool InIsAnkle)
    {
        const auto Anchor = InUpper.TransformPosition(FVector(InUpperHalfExtents.X, 0.0, 0.0));
        if (InIsAnkle)
        {
            auto Point = FCk_JoltConstraint_Spec(ECk_JoltConstraint_Type::Point);
            Point.Set_WorldAnchorA(Anchor);
            Point.Set_WorldAnchorB(Anchor);
            Point.Set_ConnectedBodiesCollide(ECk_EnableDisable::Disable);
            return Point;
        }

        auto Hinge = FCk_JoltConstraint_Spec(ECk_JoltConstraint_Type::Hinge);
        Hinge.Set_WorldAnchorA(Anchor);
        Hinge.Set_WorldAnchorB(Anchor);
        Hinge.Set_HingeAxis(InUpper.GetRotation().GetAxisZ());
        Hinge.Set_LimitsMinDegrees(-constants_severed_limb::k_KneeLimitDegrees);
        Hinge.Set_LimitsMaxDegrees(constants_severed_limb::k_KneeLimitDegrees);
        Hinge.Set_MaxFrictionTorque(constants_severed_limb::k_KneeFrictionTorque);
        Hinge.Set_ConnectedBodiesCollide(ECk_EnableDisable::Disable);
        return Hinge;
    }

    FMars_SeveredLimb_JointEnds Make_JointEnds(FMars_SeveredLimb_PieceSpec InUpper, FMars_SeveredLimb_PieceSpec InLower)
    {
        const auto OnUpper = FVector(InUpper.HalfExtents.X, 0.0, 0.0);
        const auto Joint = utils_transform::Get_EntityCurrentTransform(InUpper.Piece).TransformPosition(OnUpper);

        auto Ends = FMars_SeveredLimb_JointEnds();
        Ends.OnUpper = OnUpper;
        Ends.OnLower = utils_transform::Get_EntityCurrentTransform(InLower.Piece).InverseTransformPosition(Joint);
        return Ends;
    }
}

//--------------------------------------------------------------------------------------------------------------------------
// Getters
//--------------------------------------------------------------------------------------------------------------------------

// In chain order, the foot last.
mixin TArray<FCk_Handle_Transform> Get_Pieces(const FCk_Handle_SeveredLimb& Self)
{
    auto Pieces = TArray<FCk_Handle_Transform>();
    for (const auto& Piece : Self.Get_Fragment(FMars_Fragment_SeveredLimb).Pieces)
    { Pieces.Add(Piece.Piece); }

    return Pieces;
}

mixin FVector Get_PieceHalfExtents(const FCk_Handle_SeveredLimb& Self, int32 InIndex)
{
    const auto& Pieces = Self.Get_Fragment(FMars_Fragment_SeveredLimb).Pieces;
    if (ck::EnsureIfNot(Pieces.IsValidIndex(InIndex), f"[SeveredLimb] [{Self.ToString()}] has no piece [{InIndex}] (it has [{Pieces.Num()}])"))
    { return FVector::ZeroVector; }

    return Pieces[InIndex].HalfExtents;
}

// The ledger's flag: the authority's final write.
mixin bool Get_IsAtRest(const FCk_Handle_SeveredLimb& Self)
{
    return Self.Get_Fragment(FMars_Fragment_SeveredLimb_Net).AtRest;
}

// The authority's constraints, one per neighbouring pair; empty on a copy.
mixin TArray<FCk_Handle_JoltConstraint> Get_Joints(const FCk_Handle_SeveredLimb& Self)
{
    return Self.Get_Fragment(FMars_Fragment_SeveredLimb).Joints;
}

// How far Add raised the limb so its pieces were born clear of the ground (cm).
mixin float64 Get_BirthLift(const FCk_Handle_SeveredLimb& Self)
{
    return Self.Get_Fragment(FMars_Fragment_SeveredLimb).BirthLift;
}

mixin int32 Get_JointCount(const FCk_Handle_SeveredLimb& Self)
{
    return Self.Get_Fragment(FMars_Fragment_SeveredLimb).JointEnds.Num();
}

// The distance between pieces InIndex and InIndex + 1 where they met at the cut, from their transforms now: readable on
// every machine. -1 while either piece is gone.
mixin float64 Get_JointGap(const FCk_Handle_SeveredLimb& Self, int32 InIndex)
{
    const auto& State = Self.Get_Fragment(FMars_Fragment_SeveredLimb);
    if (ck::EnsureIfNot(State.JointEnds.IsValidIndex(InIndex), f"[SeveredLimb] [{Self.ToString()}] has no joint [{InIndex}] (it has [{State.JointEnds.Num()}])"))
    { return -1.0; }

    const auto Upper = State.Pieces[InIndex].Piece;
    const auto Lower = State.Pieces[InIndex + 1].Piece;
    if (ck::Is_NOT_Valid(Upper) || ck::Is_NOT_Valid(Lower))
    { return -1.0; }

    const auto& Ends = State.JointEnds[InIndex];
    const auto OnUpper = utils_transform::Get_EntityCurrentTransform(Upper).TransformPosition(Ends.OnUpper);
    const auto OnLower = utils_transform::Get_EntityCurrentTransform(Lower).TransformPosition(Ends.OnLower);
    return (OnUpper - OnLower).Size();
}

mixin FTransform Get_RootTransform(const FCk_Handle_SeveredLimb& Self)
{
    return utils_transform::Get_EntityCurrentTransform(Self.As_Transform());
}

// Every piece's pose in the root's frame now; a piece that is gone reads its last written pose.
mixin TArray<FMars_SeveredLimb_Pose> Get_PiecePoses(const FCk_Handle_SeveredLimb& Self)
{
    const auto Root = Self.Get_RootTransform();
    const auto& Written = Self.Get_Fragment(FMars_Fragment_SeveredLimb_Net).Pieces;
    const auto& Pieces = Self.Get_Fragment(FMars_Fragment_SeveredLimb).Pieces;

    auto Poses = TArray<FMars_SeveredLimb_Pose>();
    for (int32 Index = 0; Index < Pieces.Num(); ++Index)
    {
        const auto Piece = Pieces[Index].Piece;
        if (ck::IsValid(Piece))
        { Poses.Add(FMars_SeveredLimb_Pose(utils_transform::Get_EntityCurrentTransform(Piece).GetRelativeTransform(Root))); }
        else if (Written.IsValidIndex(Index))
        { Poses.Add(Written[Index]); }
        else
        { Poses.Add(FMars_SeveredLimb_Pose()); }
    }

    return Poses;
}
