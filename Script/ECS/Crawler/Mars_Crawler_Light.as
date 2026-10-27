// How a crawler answers flame light. The kernel never looks for light itself: its Spec.Light.Sense is a Trigger the
// entity script composes on the root, filtering Probe.Mars.Light, so what is "in the light" is whichever lit flames'
// pools overlap the crawler's body. Shun is a ward, never a flee: the attack admission refuses a start at a target that
// holds a lit flame (lantern or torch) in its hand within ShunRadius (EMars_Crawler_AttackReject::Warded), and Engage
// hesitates in Prepare until the flame is lowered (belt, hook) or put out. Seek is a lure: a roaming crawler with no
// target walks to the nearest lit flame whose pool it stands in (a lantern on a belt included).

enum EMars_Crawler_LightResponse
{
    Ignore,
    // Will not lunge at a target holding a lit flame; engages once it is lowered.
    Shun,
    // Roams toward the light it stands in.
    Seek
}

struct FMars_Crawler_Light
{
    UPROPERTY()
    EMars_Crawler_LightResponse Response = EMars_Crawler_LightResponse::Shun;

    // Shun: a held lit flame wards only while its bearer is within this horizontal distance of the root.
    UPROPERTY()
    float32 ShunRadius = 400.0f;

    // The volume that feels flame light at the crawler (a Trigger filtering Probe.Mars.Light), built by the entity script;
    // required unless Response is Ignore.
    UPROPERTY()
    FCk_Handle_Trigger Sense;
}

mixin FMars_Validation Validate(const FMars_Crawler_Light& Self)
{
    if (utils_crawler::Get_IsPositiveFinite(Self.ShunRadius) == false)
    { return FMars_Validation(f"Crawler light has a non-positive ShunRadius [{Self.ShunRadius}]"); }

    if (Self.Response != EMars_Crawler_LightResponse::Ignore && ck::Is_NOT_Valid(Self.Sense))
    { return FMars_Validation(f"Crawler light response [{Self.Response :n}] has no Sense trigger"); }

    return FMars_Validation();
}

//--------------------------------------------------------------------------------------------------------------------------
// Getters
//--------------------------------------------------------------------------------------------------------------------------

// The lit flames whose pools the crawler stands in; empty for an Ignore crawler.
mixin TArray<FCk_Handle_Flame> Get_LightsOn(const FCk_Handle_Crawler& Self)
{
    const auto& Light = Self.Get_Fragment(FMars_Fragment_Crawler_Params).Spec.Light;
    if (Light.Response == EMars_Crawler_LightResponse::Ignore)
    { return TArray<FCk_Handle_Flame>(); }

    return utils_flame::Get_LitFlamesIn(Light.Sense);
}

// A Shun crawler stands in the light of a flame InTarget holds in its hand, with InTarget within ShunRadius
// (horizontal): the attack admission refuses it (Warded).
mixin bool Get_IsWarded(const FCk_Handle_Crawler& Self, FCk_Handle InTarget)
{
    const auto& Light = Self.Get_Fragment(FMars_Fragment_Crawler_Params).Spec.Light;
    if (Light.Response != EMars_Crawler_LightResponse::Shun || ck::Is_NOT_Valid(InTarget))
    { return false; }

    const auto TargetTransform = InTarget.As_Transform(ECk_SanityCheck::UnChecked);
    if (ck::Is_NOT_Valid(TargetTransform))
    { return false; }

    const auto Root = utils_transform::Get_EntityCurrentLocation(Self.As_Transform());
    if ((utils_transform::Get_EntityCurrentLocation(TargetTransform) - Root).Size2D() > Light.ShunRadius)
    { return false; }

    for (const auto& Flame : Self.Get_LightsOn())
    {
        if (Flame.Get_IsHeldBy(InTarget))
        { return true; }
    }

    return false;
}

// Seek: where the nearest lit flame whose pool the crawler stands in is, inside RoamBounds (a lure never draws it out of
// its territory); unset for any other response or in the dark.
mixin TOptional<FVector> TryGet_LightLure(const FCk_Handle_Crawler& Self)
{
    const auto& Spec = Self.Get_Fragment(FMars_Fragment_Crawler_Params).Spec;
    if (Spec.Light.Response != EMars_Crawler_LightResponse::Seek)
    { return TOptional<FVector>(); }

    const auto Root = utils_transform::Get_EntityCurrentLocation(Self.As_Transform());
    auto Nearest = TOptional<FVector>();
    auto NearestDistance = 0.0;
    for (const auto& Flame : Self.Get_LightsOn())
    {
        const auto FlameTransform = Flame.H().As_Transform(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(FlameTransform))
        { continue; }

        const auto Location = utils_transform::Get_EntityCurrentLocation(FlameTransform);
        const auto Distance = (Location - Root).Size();
        if (Nearest.IsSet() == false || Distance < NearestDistance)
        {
            Nearest = TOptional<FVector>(Location);
            NearestDistance = Distance;
        }
    }

    if (Nearest.IsSet() == false)
    { return Nearest; }

    const auto Bounds = Spec.RoamBounds;
    const auto Lure = Nearest.GetValue();
    return TOptional<FVector>(FVector(
        Math::Clamp(Lure.X, Bounds.Min.X, Bounds.Max.X),
        Math::Clamp(Lure.Y, Bounds.Min.Y, Bounds.Max.Y),
        Math::Clamp(Lure.Z, Bounds.Min.Z, Bounds.Max.Z)));
}
