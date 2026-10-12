// Game collision policy for a reconstructed accepted limb interval. Probe hits are deliberately ignored:
// the target is an explicit moving sphere, and only static World hits can obstruct it.
struct FMars_Crawler_LongLimbWorldResult
{
    bool Valid = false;
    bool TargetHit = false;
    bool WorldBlocked = false;
    bool EndpointOnlyMissedTarget = false;
    float64 TargetFraction = 1.0;
    float64 WorldFraction = 1.0;
    int32 GeometryOverlapCount = 0;
    int32 WorldQueryCount = 0;
    FString Failure;
}

namespace utils_crawler_long_limb_world
{
    FMars_Crawler_LongLimbWorldResult Resolve(FCk_Handle InQueryOwner,
        const FMars_Crawler_LongLimbResolution& InGeometry, float64 InTargetRadiusCm)
    {
        auto Result = FMars_Crawler_LongLimbWorldResult();
        if (ck::Is_NOT_Valid(InQueryOwner) || InGeometry.Valid == false || InGeometry.SeedOnly ||
            InGeometry.Steps.IsEmpty() || InGeometry.Steps.Num() > 65 ||
            Math::IsFinite(InTargetRadiusCm) == false || InTargetRadiusCm <= 0.0)
        { Result.Failure = "World query requires a bounded accepted interval and explicit sphere target"; return Result; }

        const UWorld World = utils_entity_lifetime::Get_WorldForEntity(InQueryOwner);
        if (IsValid(World) == false)
        { Result.Failure = "World query owner has no live world"; return Result; }

        auto WorldFilter = FCk_Jolt_QueryFilter();
        WorldFilter.Set_BodySelection(ECk_Jolt_QueryBodySelection::StaticNonSensor);
        WorldFilter.Set_CollideWithBackFacesConvex(true);

        auto EarliestTarget = 1.0;
        auto EarliestWorld = 1.0;
        auto HasTarget = false;
        auto HasWorld = false;
        auto StartEndpointOverlapsTarget = false;
        auto EndEndpointOverlapsTarget = false;
        for (auto StepIndex = 0; StepIndex < InGeometry.Steps.Num(); ++StepIndex)
        {
            const auto& Step = InGeometry.Steps[StepIndex];
            for (const auto& Sphere : Step.Spheres)
            {
                ++Result.WorldQueryCount;
                if (Result.WorldQueryCount > 8192 || Math::IsFinite(Sphere.Radius) == false ||
                    Sphere.Radius <= 0.0 || Sphere.Radius > 100000.0 ||
                    utils_crawler::Get_IsFinite(Sphere.From) == false ||
                    utils_crawler::Get_IsFinite(Sphere.To) == false)
                { Result.Failure = "World query geometry exceeds its finite budget"; return Result; }

                if (StepIndex == 0)
                {
                    StartEndpointOverlapsTarget = StartEndpointOverlapsTarget ||
                        (Sphere.From - Step.TargetFrom).Size() <= Sphere.Radius + InTargetRadiusCm;
                }
                if (StepIndex == InGeometry.Steps.Num() - 1)
                {
                    EndEndpointOverlapsTarget = EndEndpointOverlapsTarget ||
                        (Sphere.To - Step.TargetTo).Size() <= Sphere.Radius + InTargetRadiusCm;
                }

                const auto Target = utils_crawler_limb_sweep::Intersect_MovingSphere(Sphere,
                    Step.TargetFrom, Step.TargetTo, InTargetRadiusCm);
                if (Target.Valid == false)
                { Result.Failure = "Target interpolation is malformed"; return Result; }
                if (Target.Hit)
                {
                    ++Result.GeometryOverlapCount;
                    const auto Fraction = (float64(StepIndex) + Target.Fraction) / float64(InGeometry.Steps.Num());
                    EarliestTarget = Math::Min(EarliestTarget, Fraction);
                    HasTarget = true;
                }

                auto Shape = FCk_Jolt_ShapeDimensions(ECk_Jolt_ShapeType::Sphere);
                Shape.Set_Radius(float32(Sphere.Radius));
                const auto Hit = utils_jolt_query::Get_ShapeCast(Sphere.From, Sphere.To,
                    FRotator::ZeroRotator, Shape, WorldFilter);
                if (Hit.Get_HasHit())
                {
                    if (Math::IsFinite(Hit.Get_Fraction()) == false ||
                        Hit.Get_Fraction() < 0.0f || Hit.Get_Fraction() > 1.0f)
                    { Result.Failure = "World trace returned a malformed fraction"; return Result; }
                    const auto Fraction = (float64(StepIndex) + float64(Hit.Get_Fraction())) /
                        float64(InGeometry.Steps.Num());
                    EarliestWorld = Math::Min(EarliestWorld, Fraction);
                    HasWorld = true;
                }
            }
        }

        Result.Valid = true;
        Result.TargetFraction = EarliestTarget;
        Result.WorldFraction = EarliestWorld;
        Result.WorldBlocked = HasWorld && (!HasTarget || EarliestWorld <= EarliestTarget + 1.0e-6);
        Result.TargetHit = HasTarget && !Result.WorldBlocked;
        Result.EndpointOnlyMissedTarget = Result.TargetHit &&
            !StartEndpointOverlapsTarget && !EndEndpointOverlapsTarget;
        return Result;
    }
}
