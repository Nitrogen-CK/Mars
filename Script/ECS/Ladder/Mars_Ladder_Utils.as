namespace utils_ladder
{
    // Each zone reaches this far past the rails, and the top zone this far past the top exit (uu).
    const float64 k_ZoneSidePadding = 20.0;
    const float64 k_TopZoneOvershoot = 20.0;

    // Composes the ladder on InRoot (its frame is InRoot's transform, see FMars_Ladder_Spec) with its two zones as child
    // trigger nodes that detect the player probe. A rejected spec ensures and returns an invalid handle.
    FCk_Handle_Ladder Add(FCk_Handle_Transform& InRoot, FMars_Ladder_Spec InParams)
    {
        const auto Validation = InParams.Validate();
        if (ck::EnsureIfNot(Validation.IsValid(), f"[Ladder] [{InRoot.ToString()}] rejected the spec: {Validation.Get_Error()}"))
        { return FCk_Handle_Ladder(); }

        const auto PlayerProbe = GameplayTag::MakeContainerFromTag(GameplayTags::Probe_Mars_Player);
        const auto ZoneHalfWidth = float64(InParams.Width) * 0.5 + k_ZoneSidePadding;

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
        const auto TopHalfDepth = (float64(InParams.TopExitDepth) + k_TopZoneOvershoot) * 0.5;
        const auto TopHalfHeight = float64(InParams.ZoneHeightPadding) * 0.5;
        auto TopSpec = FMars_Trigger_Spec();
        TopSpec.Shape = EMars_Trigger_Shape::Box;
        TopSpec.BoxHalfExtents = FVector(TopHalfDepth, ZoneHalfWidth, TopHalfHeight);
        TopSpec.LocalOffset = FTransform(FRotator::ZeroRotator,
            FVector(-TopHalfDepth, 0.0, float64(InParams.Height) + TopHalfHeight), FVector::OneVector);
        TopSpec.DetectionFilter = PlayerProbe;
        auto TopZone = utils_trigger::Add(InRoot, TopSpec);

        auto Params = FMars_Fragment_Ladder_Params();
        Params.Spec = InParams;

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

        return Ladder;
    }
}

//--------------------------------------------------------------------------------------------------------------------------
// Getters
//--------------------------------------------------------------------------------------------------------------------------

mixin float32 Get_Height(const FCk_Handle_Ladder& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Ladder_Params).Spec.Height;
}

mixin FCk_Handle_Trigger Get_FrontZone(const FCk_Handle_Ladder& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Ladder).FrontZone;
}

mixin FCk_Handle_Trigger Get_TopZone(const FCk_Handle_Ladder& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Ladder).TopZone;
}

// The ladder frame in world space (Add composes the ladder on a transform).
mixin FTransform Get_FrameWorld(const FCk_Handle_Ladder& Self)
{
    return utils_transform::Get_EntityCurrentTransform(Self.As_Transform());
}

// The point on the climb line at InAlpha (0 foot .. 1 top), in world space: the climber's feet, not its capsule centre.
mixin FVector Get_LineWorldLocation(const FCk_Handle_Ladder& Self, float32 InAlpha)
{
    const auto& Spec = Self.Get_Fragment(FMars_Fragment_Ladder_Params).Spec;
    return Self.Get_FrameWorld().TransformPosition(FVector(Spec.Standoff, 0.0, float64(InAlpha * Spec.Height)));
}

// Where a top-out puts the climber's feet: TopExitDepth behind the plane, on the platform; rotated as the ladder.
mixin FTransform Get_TopExitWorld(const FCk_Handle_Ladder& Self)
{
    const auto& Spec = Self.Get_Fragment(FMars_Fragment_Ladder_Params).Spec;
    const auto Frame = Self.Get_FrameWorld();
    const auto Location = Frame.TransformPosition(FVector(-Spec.TopExitDepth, 0.0, Spec.Height));
    return FTransform(Frame.GetRotation(), Location, FVector::OneVector);
}

// The direction a climber standing in InZone walks to step onto the ladder: from the front toward the plane (local -X),
// from the platform toward the edge (local +X).
mixin FVector Get_TowardPlaneWorld(const FCk_Handle_Ladder& Self, EMars_Ladder_Zone InZone)
{
    const auto LocalDirection = InZone == EMars_Ladder_Zone::Front ? FVector(-1.0, 0.0, 0.0) : FVector(1.0, 0.0, 0.0);
    return Self.Get_FrameWorld().GetRotation().RotateVector(LocalDirection);
}
