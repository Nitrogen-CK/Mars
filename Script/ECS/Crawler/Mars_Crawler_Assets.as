// The crawler's rig layouts and gait presets. Knobs: gait timing in Mars_CrawlerGait (Radial) and Mars_SpiderGait (Spider);
// leg placement in the constants below.

// Which leg layout a crawler walks on. Radial: the box crawler, N legs spread evenly (4 or 6). Spider: the six legs
// measured off the spider model the Room 5 crawler wears (Tools/Blender/mars_monsters/build_crawler_pieces.py).
// PaleCrawler: the eight legs of the small low pale spider, measured off its authored model
// (Tools/Blender/mars_monsters/pale_crawler_r01/build_pale_crawler.py).
enum EMars_Crawler_Layout
{
    Radial,
    Spider,
    PaleCrawler
}

// One right-side leg of the spider, in the body's frame (cm). The left twin mirrors Y.
struct FMars_Crawler_SpiderLeg
{
    FVector Hip;
    FVector RestFoot;
    FVector Pole;
    float32 UpperLength = 0.0f;
    float32 LowerLength = 0.0f;

    FMars_Crawler_SpiderLeg() {}

    FMars_Crawler_SpiderLeg(FVector InHip, FVector InRestFoot, FVector InPole, float32 InUpperLength, float32 InLowerLength)
    {
        Hip = InHip;
        RestFoot = InRestFoot;
        Pole = InPole;
        UpperLength = InUpperLength;
        LowerLength = InLowerLength;
    }
}

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

    // The radial rig asset for a leg count; null for a count with no rig (only 4 and 6 have one).
    UCk_ProceduralRig_Data Get_RigData(int32 InLegCount)
    {
        if (InLegCount == 4)
        { return utils_crawler::Mars_CrawlerRig4; }

        if (InLegCount == 6)
        { return utils_crawler::Mars_CrawlerRig6; }

        return nullptr;
    }

    // The rig asset of a layout and leg count; null for a pair with no rig (the spider has six legs only, the pale crawler
    // eight).
    UCk_ProceduralRig_Data Get_LayoutRigData(EMars_Crawler_Layout InLayout, int32 InLegCount)
    {
        if (InLayout == EMars_Crawler_Layout::Spider)
        { return InLegCount == 6 ? utils_crawler::Mars_SpiderRig6 : nullptr; }

        if (InLayout == EMars_Crawler_Layout::PaleCrawler)
        { return InLegCount == 8 ? utils_crawler::Mars_PaleCrawlerRig8 : nullptr; }

        return Get_RigData(InLegCount);
    }

    // Whether the legs carry sibling capsules (the rig's knee swivelling to keep neighbouring legs apart). The spider's
    // legs touch in its own rest pose: six hips 5 to 10 cm apart under its head and knees 18 to 20 cm apart, against
    // capsule radii of 10 to 18 cm from its chunky segments, so its capsules overlap in every pose and the selector
    // swivels every knee several times a second chasing an overlap no knee pose removes. Its knees keep the swivel
    // clear of solids and of the body. The pale crawler's eight hips stand 7 cm apart along a 23 cm sternum under 5 cm thick
    // coxae: the same overlap, so it keeps the swivel too.
    bool Get_LayoutSiblingCapsules(EMars_Crawler_Layout InLayout)
    {
        return InLayout == EMars_Crawler_Layout::Radial;
    }

    // How high the body rides over the ground its feet stand on.
    float32 Get_LayoutClearance(EMars_Crawler_Layout InLayout)
    {
        if (InLayout == EMars_Crawler_Layout::Spider)
        { return SpiderClearance; }

        if (InLayout == EMars_Crawler_Layout::PaleCrawler)
        { return PaleCrawlerClearance; }

        return float32(RestDrop);
    }

    // The layout's size against the box crawler's (whose body is 110 cm long), for the lengths that are not measured off its
    // rig: its speeds and the navigator's distances, and its attack's body keys and tolerances.
    float32 Get_LayoutSizeScale(EMars_Crawler_Layout InLayout)
    {
        if (InLayout == EMars_Crawler_Layout::Spider)
        { return SpiderSizeScale; }

        if (InLayout == EMars_Crawler_Layout::PaleCrawler)
        { return PaleCrawlerSizeScale; }

        return 1.0f;
    }

    UCk_ProceduralGait_Data Get_LayoutGaitData(EMars_Crawler_Layout InLayout)
    {
        if (InLayout == EMars_Crawler_Layout::Spider)
        { return utils_crawler::Mars_SpiderGait; }

        if (InLayout == EMars_Crawler_Layout::PaleCrawler)
        { return utils_crawler::Mars_PaleCrawlerGait; }

        return utils_crawler::Mars_CrawlerGait;
    }
}

// The spider: every number measured off the model at one uniform scale (216.5 cm per model metre, the body 198 cm nose
// to tail, 1.8 times the box crawler's 110) by Tools/Blender/mars_monsters/build_crawler_pieces.py, which prints them
// (SPIDER_RIG, export/Crawler_SpiderRig.json). The hips are the roots of the coxae, under the head and close together;
// each rest foot is the claw tip dropped onto the ground the body stands SpiderClearance over; each pole lies as far past
// the model's knee as the knee stands off the hip-to-foot midpoint, so the rig bends the knee in the model's leg plane.
// Re-run the build and copy its numbers here after the model or the scale changes.
// A side of the body, as the crawler faces.
enum EMars_Crawler_Side
{
    Right,
    Left
}

namespace utils_crawler
{
    const float32 SpiderClearance = 79.6f;
    const float32 SpiderSizeScale = 1.8f;

    // The spider's right legs, front to back.
    TArray<FMars_Crawler_SpiderLeg> Get_SpiderRightLegs()
    {
        auto Legs = TArray<FMars_Crawler_SpiderLeg>();
        Legs.Add(FMars_Crawler_SpiderLeg(FVector(32.48, 12.15, -48.86), FVector(65.62, 96.05, -79.6), FVector(60.42, 63.87, 60.98), 70.14f, 83.57f));
        Legs.Add(FMars_Crawler_SpiderLeg(FVector(25.09, 5.64, -54.32), FVector(5.56, 101.45, -79.6), FVector(23.56, 79.21, 70.8), 82.97f, 89.43f));
        Legs.Add(FMars_Crawler_SpiderLeg(FVector(13.88, 14.8, -51.89), FVector(-72.42, 83.99, -79.6), FVector(10.2, 73.07, 83.22), 79.87f, 106.98f));
        return Legs;
    }

    // A spider walks in a wave, not a tripod: along each side the back leg lifts first, the middle a third of a cycle
    // later and the front a third after that, so its steps ripple forward. The left side runs a third of a cycle behind
    // the right, so the six legs fall into three pairs (right back with left front, right middle with left back, right
    // front with left middle), each pair one phase group: the gait swings one group at a time, so three groups leave four
    // feet down through every swing where six (a half-cycle offset between the sides) would lift one leg at a time.
    // Index into Get_SpiderRightLegs (front to back).
    float32 Get_SpiderWavePhase(int32 InRightLegIndex, EMars_Crawler_Side InSide)
    {
        const auto Right = float32(Get_SpiderRightLegs().Num() - 1 - InRightLegIndex) / 3.0f;
        if (InSide == EMars_Crawler_Side::Right)
        { return Right; }

        const auto Left = Right + 1.0f / 3.0f;
        return Left >= 1.0f - 1.0e-4f ? Left - 1.0f : Left;
    }

    // In the radial rig's order, which the pincer and the leg parts rely on: front right first, then round the right side
    // to the back, and back up the left side to the front left last; each leg's phase from Get_SpiderWavePhase.
    TArray<FCk_ProceduralLeg_Spec> Make_SpiderLegs()
    {
        const auto Right = Get_SpiderRightLegs();
        auto Ordered = TArray<FMars_Crawler_SpiderLeg>();
        auto Phases = TArray<float32>();
        for (int32 Index = 0; Index < Right.Num(); ++Index)
        {
            Ordered.Add(Right[Index]);
            Phases.Add(Get_SpiderWavePhase(Index, EMars_Crawler_Side::Right));
        }

        for (int32 Index = Right.Num() - 1; Index >= 0; --Index)
        {
            auto Left = Right[Index];
            Left.Hip.Y = -Left.Hip.Y;
            Left.RestFoot.Y = -Left.RestFoot.Y;
            Left.Pole.Y = -Left.Pole.Y;
            Ordered.Add(Left);
            Phases.Add(Get_SpiderWavePhase(Index, EMars_Crawler_Side::Left));
        }

        auto Legs = TArray<FCk_ProceduralLeg_Spec>();
        for (int32 Index = 0; Index < Ordered.Num(); ++Index)
        {
            const auto& Leg = Ordered[Index];
            auto Lengths = TArray<float32>();
            Lengths.Add(Leg.UpperLength);
            Lengths.Add(Leg.LowerLength);

            auto Placement = FCk_ProceduralLeg_Placement(Leg.Hip, Leg.RestFoot);
            Placement.Set_PhaseOffset(Phases[Index]);

            auto Chain = FCk_ProceduralLeg_ChainGeometry();
            Chain.Set_SegmentLengths(Lengths);
            Chain.Set_PoleLocal(Leg.Pole);

            Legs.Add(FCk_ProceduralLeg_Spec(FName(f"Leg{Index}"), Placement, Chain));
        }

        return Legs;
    }

    asset Mars_SpiderRig6 of UCk_ProceduralRig_Data
    {
        _Legs.Append(utils_crawler::Make_SpiderLegs());
    }

    // Quick, high, short steps: a 0.45 s cycle (the box crawler's 0.8) whose swings last 0.12 s, so the wave's three
    // groups fit in a cycle with a beat between them, the feet lifted 45 cm (a quarter of a leg); at its 216 cm/s roam it
    // takes 2.2 steps a second per leg and strides 97 cm, half a body length (the box crawler two thirds of one). The step
    // threshold (50 cm, under the box crawler's 30 scaled by the size) is held above what a foot falls behind its target
    // over one stance (about 70 cm at roaming speed) over the emergency factor (1.75): a leg that turns Emergency before
    // its window holds back every other group's take-off and breaks the wave's order. The cadence reference is the
    // roaming speed, so it walks at its authored cycle there (at the box crawler's 120 it would run the cycle 1.8 times
    // faster). The lead scales with the size. Survivors re-space evenly when a leg is lost.
    asset Mars_SpiderGait of UCk_ProceduralGait_Data
    {
        _Timing.Set_CycleDuration(FCk_Time(0.45));
        _Timing.Set_StepDuration(FCk_Time(0.12));
        _Timing.Set_CadenceSpeedRef(216.0f);
        _Timing.Set_LegLossPolicy(ECk_ProceduralGait_LegLossPolicy::RedistributeOffsets);
        _Step.Set_Height(45.0f);
        _Step.Set_Threshold(50.0f);
        _Step.Set_MaxVelocityLead(108.0f);
    }
}

// The pale crawler: eight legs, every number measured off the authored Pale Crawler R01 model in the body's frame
// (Tools/Blender/mars_monsters/pale_crawler_r01/build_pale_crawler.py -> export/PaleCrawler_R01_Assembly.json, the
// `*_body` joints): a 50 cm body (nose to abdomen tip) whose bounds centre rides PaleCrawlerClearance over the ground,
// four hip sockets a side on the sternum's flanks, feet 180 cm apart at the widest pair, the highest knee 60 cm up (the
// mid-back and back pairs share that ridge; the back pair rests 6 cm closer in than the first cut, R01.1, for gait slack).
// Each pole lies as far past the authored knee as the knee stands off the hip-to-foot midpoint, so the rig bends every
// knee in the model's leg plane. Its size scale is 1: its body is half the box crawler's but its 180 cm footprint and
// 128 cm legs match it, and the speeds and distances the scale sets follow the legs. Re-run the builder and copy its
// numbers here after the model changes. The gameplay rig is two segments a leg (hip -> knee, knee -> foot tip); the
// model's coxa rides in the upper piece and its tarsus in the lower one.
namespace utils_crawler
{
    const float32 PaleCrawlerClearance = 24.2f;
    // 0.8: it roams at 96 cm/s (two body lengths a second) and tops out at 144. Its 180 cm footprint matches the box
    // crawler's, but its chains are shorter than that footprint asks: at the box crawler's 120 cm/s a 0.3 s cycle dragged
    // its back feet from 0.72 to 0.99 of their chains every stance (Mars_AutoTest_Crawler_PaleCrawlerRoamsWithinReach).
    const float32 PaleCrawlerSizeScale = 0.8f;

    // The pale crawler's right legs, front to back: Front, MidFront, MidBack, Back.
    TArray<FMars_Crawler_SpiderLeg> Get_PaleCrawlerRightLegs()
    {
        auto Legs = TArray<FMars_Crawler_SpiderLeg>();
        Legs.Add(FMars_Crawler_SpiderLeg(FVector(17.0, 11.5, -6.2), FVector(84.769, 64.447, -24.2), FVector(37.331, 27.384, 76.8), 50.521f, 75.416f));
        Legs.Add(FMars_Crawler_SpiderLeg(FVector(10.0, 11.5, -6.2), FVector(35.506, 90.0, -24.2), FVector(17.652, 35.05, 84.8), 52.641f, 77.03f));
        Legs.Add(FMars_Crawler_SpiderLeg(FVector(2.0, 11.5, -6.2), FVector(-23.339, 89.487, -24.2), FVector(-5.602, 34.896, 86.8), 53.29f, 77.593f));
        Legs.Add(FMars_Crawler_SpiderLeg(FVector(-5.0, 11.5, -6.2), FVector(-71.193, 63.216, -24.2), FVector(-24.858, 27.015, 86.8), 53.786f, 78.359f));
        return Legs;
    }

    // An eight-legged spider walks an alternating tetrapod: legs 1 and 3 of one side swing with legs 2 and 4 of the other,
    // the two groups half a cycle apart, so four feet (two a side, never two neighbours) stay down through every swing.
    // Index into Get_PaleCrawlerRightLegs (front to back).
    float32 Get_PaleCrawlerTetrapodPhase(int32 InRightLegIndex, EMars_Crawler_Side InSide)
    {
        const auto FirstGroup = (InRightLegIndex % 2 == 0) == (InSide == EMars_Crawler_Side::Right);
        return FirstGroup ? 0.0f : 0.5f;
    }

    // In the radial rig's order: front right first, round the right side to the back, and back up the left side to the
    // front left last; each leg's phase from Get_PaleCrawlerTetrapodPhase.
    TArray<FCk_ProceduralLeg_Spec> Make_PaleCrawlerLegs()
    {
        const auto Right = Get_PaleCrawlerRightLegs();
        auto Ordered = TArray<FMars_Crawler_SpiderLeg>();
        auto Phases = TArray<float32>();
        for (int32 Index = 0; Index < Right.Num(); ++Index)
        {
            Ordered.Add(Right[Index]);
            Phases.Add(Get_PaleCrawlerTetrapodPhase(Index, EMars_Crawler_Side::Right));
        }

        for (int32 Index = Right.Num() - 1; Index >= 0; --Index)
        {
            auto Left = Right[Index];
            Left.Hip.Y = -Left.Hip.Y;
            Left.RestFoot.Y = -Left.RestFoot.Y;
            Left.Pole.Y = -Left.Pole.Y;
            Ordered.Add(Left);
            Phases.Add(Get_PaleCrawlerTetrapodPhase(Index, EMars_Crawler_Side::Left));
        }

        auto Legs = TArray<FCk_ProceduralLeg_Spec>();
        for (int32 Index = 0; Index < Ordered.Num(); ++Index)
        {
            const auto& Leg = Ordered[Index];
            auto Lengths = TArray<float32>();
            Lengths.Add(Leg.UpperLength);
            Lengths.Add(Leg.LowerLength);

            auto Placement = FCk_ProceduralLeg_Placement(Leg.Hip, Leg.RestFoot);
            Placement.Set_PhaseOffset(Phases[Index]);

            auto Chain = FCk_ProceduralLeg_ChainGeometry();
            Chain.Set_SegmentLengths(Lengths);
            Chain.Set_PoleLocal(Leg.Pole);

            Legs.Add(FCk_ProceduralLeg_Spec(FName(f"Leg{Index}"), Placement, Chain));
        }

        return Legs;
    }

    asset Mars_PaleCrawlerRig8 of UCk_ProceduralRig_Data
    {
        _Legs.Append(utils_crawler::Make_PaleCrawlerLegs());
    }

    // Quick, short skitters: a 0.3 s cycle whose swings last 0.08 s, so the tetrapod's two groups alternate with a beat down
    // between them; the feet lifted 25 cm (a fifth of a leg). The cadence reference is its ROAMING speed, the navigator's
    // 120 cm/s times PaleCrawlerSizeScale (Make_NavigatorSpec), as the spider's is its own: the gait runs its authored cycle
    // there and faster above it. The cycle and the size are set by the back pair: each group steps once a cycle, so a
    // planted foot is dragged a whole cycle of travel before it steps again; the back feet rest along the travel (86 cm
    // from their hips, 0.65 of their 132 cm chains since R01.1; 92 cm and 0.72 of 127 before) and land only the lead (speed
    // x step duration, 8 cm) ahead of rest, so the drag goes into the chain. The first cut (0.4 s cycle, reference 180,
    // size 1) dragged them to the full chain every cycle (max stretch 1.00 in
    // Mars_AutoTest_Crawler_PaleCrawlerRoamsWithinReach, 2026-10-30): the legs straightened as it walked; a 0.3 s cycle at
    // 120 cm/s still reached 0.99, size 0.8 brought it to 0.93, the R01.1 rear pair adds the rest of the margin. The step threshold (30) sits above the stance travel over the emergency factor; landings
    // stay within 0.78 of the chain and a planted foot past 0.86 is an Emergency, tighter than the defaults (0.8, 0.92) so
    // a foot the schedule misses bails out before the chain is straight. Survivors re-space evenly when a leg is lost.
    asset Mars_PaleCrawlerGait of UCk_ProceduralGait_Data
    {
        _Timing.Set_CycleDuration(FCk_Time(0.3));
        _Timing.Set_StepDuration(FCk_Time(0.08));
        _Timing.Set_CadenceSpeedRef(96.0f);
        _Timing.Set_LegLossPolicy(ECk_ProceduralGait_LegLossPolicy::RedistributeOffsets);
        _Step.Set_Height(25.0f);
        _Step.Set_Threshold(30.0f);
        _Step.Set_MaxVelocityLead(60.0f);
        _Step.Set_TargetReachFraction(0.78f);
        _Step.Set_ForceStepReachFraction(0.86f);
    }
}
