// The pale crawler layout, spawned through the real entity script onto a runtime static Jolt floor: once the gait is
// Ready the crawler has 8 legs and 8 leg parts, its rig data carries the four right legs measured off the Pale Crawler R01
// model (utils_crawler::Get_PaleCrawlerRightLegs) mirrored onto the left in rig order, every rest foot sits one clearance
// under the body and within the chain's reach, and the two tetrapod groups are half a cycle apart. The spec rejects the
// layout with 6 legs.
class UMars_AutoTest_Crawler_PaleCrawlerComposesEightLegs : UMars_AutoTestRig_Crawler
{
    default _TimeoutSeconds = 15.0f;
    default _Origin = FVector(130000.0, 110000.0, 600.0);

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Spec = FMars_Crawler_Spec(8, FBox(_Origin - FVector(400.0, 400.0, 200.0), _Origin + FVector(400.0, 400.0, 200.0)));
        Spec.Layout = EMars_Crawler_Layout::PaleCrawler;
        SpawnFloorAndCrawler(InHandle, Spec);

        Add_Step_WaitUntil("the crawler is composed, its gait Ready and its 8 parts registered", n"Check_Ready", k_SlowPolls, 0);
        Add_Step("eight legs, eight parts, the measured rig", n"Step_AssertRig");
        Add_Step("the spec rules hold", n"Step_AssertValidation");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_AssertRig(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Crawler.Get_Legs().Num(), 8, "the walker created 8 legs");
        Assert_Equals_Int(_Crawler.Get_LegParts().Num(), 8, "one part per leg");
        Assert_Equals_Int(_Crawler.Get_Monster().Get_Parts().Num(), 8, "the monster's roster holds the 8 parts");

        const TArray<FCk_ProceduralLeg_Spec> LegSpecs = _Crawler.Get_Spec().Get_RigData().Get_Legs();
        const auto Right = utils_crawler::Get_PaleCrawlerRightLegs();
        Assert_Equals_Int(LegSpecs.Num(), 8, "the rig data has 8 legs");
        Assert_Equals_Int(Right.Num(), 4, "four measured right legs");
        const auto Clearance = utils_crawler::Get_LayoutClearance(EMars_Crawler_Layout::PaleCrawler);

        for (int32 Index = 0; Index < LegSpecs.Num(); ++Index)
        {
            // rig order: right front to back, then left back to front
            const auto RightIndex = Index < 4 ? Index : 7 - Index;
            const auto Side = Index < 4 ? 1.0 : -1.0;
            const auto& Measured = Right[RightIndex];
            const auto Placement = LegSpecs[Index].Get_Placement();
            const auto Hip = Placement.Get_HipLocal();
            const auto Foot = Placement.Get_RestFootLocal();
            const auto Lengths = LegSpecs[Index].Get_Chain().Get_SegmentLengths();

            Assert_True(Hip.Equals(FVector(Measured.Hip.X, Measured.Hip.Y * Side, Measured.Hip.Z), 0.01),
                f"leg {Index} hip is the measured hip (got {Hip.ToString()})");
            Assert_True(Foot.Equals(FVector(Measured.RestFoot.X, Measured.RestFoot.Y * Side, Measured.RestFoot.Z), 0.01),
                f"leg {Index} rest foot is the measured foot tip (got {Foot.ToString()})");
            Assert_Equals_Float(Foot.Z, -Clearance, 0.01, f"leg {Index} rest foot sits one clearance under the body");
            Assert_Equals_Int(Lengths.Num(), 2, f"leg {Index} has two segments");
            Assert_True(Foot.Distance(Hip) < 0.8 * utils_crawler::Get_ChainReach(LegSpecs[Index]),
                f"leg {Index} rests within 0.8 of its reach ({Foot.Distance(Hip)} of {utils_crawler::Get_ChainReach(LegSpecs[Index])})");
            Assert_True(Side * Hip.Y > 0.0 && Side * Foot.Y > 0.0, f"leg {Index} stands on its own side");
        }

        // alternating tetrapod: neighbours along a side and the two legs of a pair swing half a cycle apart
        for (int32 Index = 0; Index < 3; ++Index)
        {
            const auto A = LegSpecs[Index].Get_Placement().Get_PhaseOffset();
            const auto B = LegSpecs[Index + 1].Get_Placement().Get_PhaseOffset();
            Assert_Equals_Float(Math::Abs(A - B), 0.5f, 0.001f, f"right legs {Index} and {Index + 1} are half a cycle apart");
        }

        Assert_Equals_Float(Math::Abs(LegSpecs[0].Get_Placement().Get_PhaseOffset() - LegSpecs[7].Get_Placement().Get_PhaseOffset()), 0.5f, 0.001f,
            "the front pair swings half a cycle apart");
    }

    UFUNCTION()
    private void Step_AssertValidation(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Composed = _Crawler.Get_Spec();
        Assert_True(Composed.Validate().IsValid(), "the composed 8-leg pale crawler spec is valid");

        auto SixLegs = Composed;
        SixLegs.LegCount = 6;
        Assert_False(SixLegs.Validate().IsValid(), "a 6-leg pale crawler is rejected (its rig has eight)");

        Assert_False(utils_crawler::Get_LayoutSiblingCapsules(EMars_Crawler_Layout::PaleCrawler), "its crowded hips keep no sibling capsules");
        Assert_Equals_Float(utils_crawler::Get_LayoutSizeScale(EMars_Crawler_Layout::PaleCrawler), 0.8f, 0.001f, "its size scale is 0.8 (it roams at 96 cm/s)");
    }
}
