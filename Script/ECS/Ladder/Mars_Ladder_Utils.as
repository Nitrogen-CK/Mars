namespace utils_ladder
{
    // Composes the ladder on InRoot (its frame is InRoot's transform, see FMars_Ladder_Spec) with its two zones as child
    // trigger nodes that detect the player probe. A rejected spec ensures and returns an invalid handle.
    FCk_Handle_Ladder Add(FCk_Handle_Transform& InRoot, FMars_Ladder_Spec InParams)
    {
        const auto Validation = InParams.Validate();
        if (ck::EnsureIfNot(Validation.IsValid, f"[Ladder] [{InRoot.ToString()}] rejected the spec: {Validation.Get_Error()}"))
        { return FCk_Handle_Ladder(); }

        const auto PlayerProbe = GameplayTag::MakeContainerFromTag(GameplayTags::ResolveGameplayTag(n"Probe.Mars.Player"));
        const auto ZoneHalfWidth = float64(InParams.Width) * 0.5 + 20.0;

        // In front of the plane, MountDepth deep, over the whole height plus a capsule.
        const auto FrontHalfHeight = float64(InParams.Height + InParams.ZoneHeightPadding) * 0.5;
        auto FrontSpec = FMars_Trigger_Spec();
        FrontSpec.Shape = EMars_Trigger_Shape::Box;
        FrontSpec.BoxHalfExtents = FVector(float64(InParams.MountDepth) * 0.5, ZoneHalfWidth, FrontHalfHeight);
        FrontSpec.LocalOffset = FTransform(FRotator::ZeroRotator,
            FVector(float64(InParams.MountDepth) * 0.5, 0.0, FrontHalfHeight), FVector::OneVector);
        FrontSpec.DetectionFilter = PlayerProbe;
        auto FrontZone = utils_trigger::Add(InRoot, FrontSpec);

        // Behind the plane at the top, on the platform, reaching just past the top exit.
        const auto TopHalfDepth = float64(InParams.TopExitDepth + 20.0f) * 0.5;
        const auto TopHalfHeight = float64(InParams.ZoneHeightPadding) * 0.5;
        auto TopSpec = FMars_Trigger_Spec();
        TopSpec.Shape = EMars_Trigger_Shape::Box;
        TopSpec.BoxHalfExtents = FVector(TopHalfDepth, ZoneHalfWidth, TopHalfHeight);
        TopSpec.LocalOffset = FTransform(FRotator::ZeroRotator,
            FVector(-TopHalfDepth, 0.0, float64(InParams.Height) + TopHalfHeight), FVector::OneVector);
        TopSpec.DetectionFilter = PlayerProbe;
        auto TopZone = utils_trigger::Add(InRoot, TopSpec);

        auto Params = FMars_Fragment_Ladder_Params();
        Params.Height = InParams.Height;
        Params.Width = InParams.Width;
        Params.Standoff = InParams.Standoff;
        Params.MountDepth = InParams.MountDepth;
        Params.TopExitDepth = InParams.TopExitDepth;
        Params.ZoneHeightPadding = InParams.ZoneHeightPadding;

        auto State = FMars_Fragment_Ladder();
        State.FrontZone = FrontZone;
        State.TopZone = TopZone;

        InRoot.Add_Fragment(FMars_Feature_Ladder());
        InRoot.Add_Fragment(Params);
        InRoot.Add_Fragment(State);
        InRoot.Add_Fragment(FMars_Tag_Ladder_NeedsSetup());
        auto Ladder = InRoot.As_Ladder();

        auto FrontLink = FMars_Fragment_Ladder_TriggerLink();
        FrontLink.Ladder = Ladder;
        FrontLink.Zone = EMars_Ladder_Zone::Front;
        FrontZone.Add_Fragment(FrontLink);

        auto TopLink = FMars_Fragment_Ladder_TriggerLink();
        TopLink.Ladder = Ladder;
        TopLink.Zone = EMars_Ladder_Zone::Top;
        TopZone.Add_Fragment(TopLink);

        // Composition is synchronous, so the ladder is bindable the moment the tag lands.
        utils_entity_tag::Add(InRoot, n"TAG_MarsLadder");

        return Ladder;
    }
}

//--------------------------------------------------------------------------------------------------------------------------
// Getters
//--------------------------------------------------------------------------------------------------------------------------

mixin float32 Get_Height(const FCk_Handle_Ladder& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Ladder_Params).Height;
}

mixin float32 Get_Standoff(const FCk_Handle_Ladder& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Ladder_Params).Standoff;
}

mixin float32 Get_TopExitDepth(const FCk_Handle_Ladder& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Ladder_Params).TopExitDepth;
}

mixin FCk_Handle_Trigger Get_FrontZone(const FCk_Handle_Ladder& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Ladder).FrontZone;
}

mixin FCk_Handle_Trigger Get_TopZone(const FCk_Handle_Ladder& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Ladder).TopZone;
}

// The ladder frame in world space (identity when the ladder entity has no Transform).
mixin FTransform Get_FrameWorld(const FCk_Handle_Ladder& Self)
{
    const auto Transform = FCk_Handle(Self).As_Transform(ECk_SanityCheck::UnChecked);
    if (ck::Is_NOT_Valid(Transform))
    { return FTransform::Identity; }

    return utils_transform::Get_EntityCurrentTransform(Transform);
}

// The point on the climb line at InAlpha (0 foot .. 1 top), in world space: the climber's feet, not its capsule centre.
mixin FVector Get_LineWorldLocation(const FCk_Handle_Ladder& Self, float32 InAlpha)
{
    const auto& Params = Self.Get_Fragment(FMars_Fragment_Ladder_Params);
    return Self.Get_FrameWorld().TransformPosition(FVector(Params.Standoff, 0.0, float64(InAlpha * Params.Height)));
}

// Where a top-out puts the climber's feet: TopExitDepth behind the plane, on the platform; rotated as the ladder.
mixin FTransform Get_TopExitWorld(const FCk_Handle_Ladder& Self)
{
    const auto& Params = Self.Get_Fragment(FMars_Fragment_Ladder_Params);
    const auto Frame = Self.Get_FrameWorld();
    const auto Location = Frame.TransformPosition(FVector(-Params.TopExitDepth, 0.0, Params.Height));
    return FTransform(Frame.GetRotation(), Location, FVector::OneVector);
}

// The direction a climber standing in InZone walks to step onto the ladder: from the front toward the plane (local -X),
// from the platform toward the edge (local +X).
mixin FVector Get_TowardPlaneWorld(const FCk_Handle_Ladder& Self, EMars_Ladder_Zone InZone)
{
    const auto LocalDirection = InZone == EMars_Ladder_Zone::Front ? FVector(-1.0, 0.0, 0.0) : FVector(1.0, 0.0, 0.0);
    return Self.Get_FrameWorld().GetRotation().RotateVector(LocalDirection);
}
