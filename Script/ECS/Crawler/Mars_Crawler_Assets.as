// The crawler's rig layouts and gait preset. Knobs: gait timing in Mars_CrawlerGait; leg placement in the constants below.

namespace utils_crawler
{
    const float64 HipRadius = 30.0;
    const float64 RestRadius = 100.0;
    const float64 RestDrop = 65.0;
    const float32 UpperSegmentLength = 60.0f;
    const float32 LowerSegmentLength = 80.0f;

    // N legs spread evenly around the body (the first half a slice off +X), hip-first segments 60/80, the rest foot 100 out
    // and 65 down, the pole as far up as the foot is down (knees bend outward and up), alternate legs half a cycle apart.
    TArray<FCk_ProceduralLeg_Spec> Make_RadialLegs(int32 InLegCount)
    {
        auto Lengths = TArray<float32>();
        Lengths.Add(UpperSegmentLength);
        Lengths.Add(LowerSegmentLength);

        auto Legs = TArray<FCk_ProceduralLeg_Spec>();
        for (int32 Index = 0; Index < InLegCount; ++Index)
        {
            const auto Angle = Math::DegreesToRadians(360.0 * (Index + 0.5) / InLegCount);
            const auto Radial = FVector(Math::Cos(Angle), Math::Sin(Angle), 0.0);
            const auto Drop = FVector(0.0, 0.0, RestDrop);

            auto Placement = FCk_ProceduralLeg_Placement(Radial * HipRadius, Radial * RestRadius - Drop);
            Placement.Set_PhaseOffset(Index % 2 == 0 ? 0.0f : 0.5f);

            auto Chain = FCk_ProceduralLeg_ChainGeometry();
            Chain.Set_SegmentLengths(Lengths);
            Chain.Set_PoleLocal(Radial * RestRadius + Drop);

            Legs.Add(FCk_ProceduralLeg_Spec(FName(f"Leg{Index}"), Placement, Chain));
        }
        return Legs;
    }
}

// The data assets bind CK_PROPERTY setters, so a direct property assignment here is an ambiguous write; the blocks fill
// their fields through field method calls instead. Inside the feature's namespace: a global asset literal is not
// referenceable from other files.
namespace utils_crawler
{
    asset Mars_CrawlerRig4 of UCk_ProceduralRig_Data
    {
        _Legs.Append(utils_crawler::Make_RadialLegs(4));
    }

    asset Mars_CrawlerRig6 of UCk_ProceduralRig_Data
    {
        _Legs.Append(utils_crawler::Make_RadialLegs(6));
    }

    // Survivors re-space evenly when a leg is lost.
    asset Mars_CrawlerGait of UCk_ProceduralGait_Data
    {
        _Timing.Set_CycleDuration(FCk_Time(0.8));
        _Timing.Set_StepDuration(FCk_Time(0.22));
        _Timing.Set_LegLossPolicy(ECk_ProceduralGait_LegLossPolicy::RedistributeOffsets);
        _Step.Set_Height(24.0f);
        _Step.Set_Threshold(30.0f);
    }

    // The rig asset for a leg count; null for a count with no rig (only 4 and 6 have one).
    UCk_ProceduralRig_Data Get_RigData(int32 InLegCount)
    {
        if (InLegCount == 4)
        { return utils_crawler::Mars_CrawlerRig4; }

        if (InLegCount == 6)
        { return utils_crawler::Mars_CrawlerRig6; }

        return nullptr;
    }
}
