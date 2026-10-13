// The attack-clip check (utils_crawler::Validate_AttackClip, which the combat profile's Validate runs on each clip it
// names): every reference clip passes as its kind; a pincer clip missing its ClawLeft slot, a jab missing its Offense
// window and a jab whose strike end key is rotated are each rejected, naming the broken rule and the clip; and a combat
// profile whose PincerClip breaks a rule is rejected naming PincerClip. The derived clips compile (the clip compiler has
// no objection to any of them): the rules are the crawler's, not the clip format's. Pure: nothing is spawned.
//
// This row replaced the pincer-key row when the claw keys moved out of the combat profile into the authored clip: the
// reach and side rules it checked belonged to profile keys that no longer exist.
class UMars_AutoTest_CrawlerMelee_PincerKeyValidation : UMars_AutoTestRig_CrawlerMelee
{
    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Add_Step("the clip check admits the reference clips and names the broken rule of a derived one", n"Step_Assert");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_Assert(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Layouts = TArray<EMars_Crawler_Layout>();
        Layouts.Add(EMars_Crawler_Layout::Radial);
        Layouts.Add(EMars_Crawler_Layout::Spider);
        for (const auto Layout : Layouts)
        {
            const auto Jab = utils_crawler::Validate_AttackClip(Get_ReferenceClip(Layout, EMars_Crawler_AttackClipKind::Jab), EMars_Crawler_AttackClipKind::Jab);
            const auto Pincer = utils_crawler::Validate_AttackClip(Get_ReferenceClip(Layout, EMars_Crawler_AttackClipKind::Pincer), EMars_Crawler_AttackClipKind::Pincer);
            Assert_True(Jab.IsValid() && Pincer.IsValid(),
                f"the {Layout :n} reference clips pass as their kind (jab [{Jab.Get_Error()}], pincer [{Pincer.Get_Error()}])");
        }

        auto RadialJab = Get_ReferenceClip(EMars_Crawler_Layout::Radial, EMars_Crawler_AttackClipKind::Jab);
        auto RadialPincer = Get_ReferenceClip(EMars_Crawler_Layout::Radial, EMars_Crawler_AttackClipKind::Pincer);

        const auto AsPincer = utils_crawler::Validate_AttackClip(RadialJab, EMars_Crawler_AttackClipKind::Pincer);
        Assert_True(AsPincer.IsValid() == false && AsPincer.Get_Error().Contains("PincerClip") && AsPincer.Get_Error().Contains("ClawRight and ClawLeft"),
            f"a clip with no claw slots is rejected as a pincer (got [{AsPincer.Get_Error()}])");

        auto OneClaw = Build_DerivedClip(Make_DraftWithoutSlot(RadialPincer, utils_crawler::Get_LeftClawSlotId()));
        const auto OneClawValidation = utils_crawler::Validate_AttackClip(OneClaw, EMars_Crawler_AttackClipKind::Pincer);
        Assert_True(OneClawValidation.IsValid() == false && OneClawValidation.Get_Error().Contains("ClawRight and ClawLeft") &&
            OneClawValidation.Get_Error().Contains(OneClaw.GetName().ToString()),
            f"a pincer clip missing its ClawLeft slot is rejected by name (got [{OneClawValidation.Get_Error()}])");

        auto NoWindowDraft = Make_DraftOf(RadialJab);
        NoWindowDraft.Set_Windows(TArray<FCk_ProceduralAction_Window>());
        const auto NoOffense = utils_crawler::Validate_AttackClip(Build_DerivedClip(NoWindowDraft), EMars_Crawler_AttackClipKind::Jab);
        Assert_True(NoOffense.IsValid() == false && NoOffense.Get_Error().Contains("no Offense window"),
            f"a clip without the Offense window is rejected by name (got [{NoOffense.Get_Error()}])");

        const auto Rotated = utils_crawler::Validate_AttackClip(Build_DerivedClip(Make_DraftWithRotatedStrike(RadialJab)), EMars_Crawler_AttackClipKind::Jab);
        Assert_True(Rotated.IsValid() == false && Rotated.Get_Error().Contains("translation-only Strike end key"),
            f"a clip whose strike end key is rotated is rejected by name (got [{Rotated.Get_Error()}])");

        auto Combat = Make_ArmedCrawlerSpec(4).Combat;
        Combat.Prepare.StartDistance = 110.0f;
        Assert_True(Combat.Validate().IsValid(), f"the armed profile with the reference jab passes (got [{Combat.Validate().Get_Error()}])");
        Combat.PincerClip = Make_SoftClip(OneClaw);
        const auto CombatValidation = Combat.Validate();
        Assert_True(CombatValidation.IsValid() == false && CombatValidation.Get_Error().Contains("PincerClip"),
            f"a combat profile whose PincerClip breaks a rule is rejected naming it (got [{CombatValidation.Get_Error()}])");
    }

    // InSource without InSlot: the slot and every track that keys it.
    private FCk_ProceduralAction_ClipDraft Make_DraftWithoutSlot(UCk_ProceduralAction_Data InSource, FName InSlot)
    {
        auto Draft = Make_DraftOf(InSource);
        auto Slots = TArray<FCk_ProceduralAction_Slot>();
        for (const auto& Slot : Draft.Get_Slots())
        {
            if (Slot.Get_Id() != InSlot)
            { Slots.Add(Slot); }
        }
        Draft.Set_Slots(Slots);

        auto Phases = Draft.Get_Phases();
        for (auto& Phase : Phases)
        {
            auto Tracks = TArray<FCk_ProceduralAction_LimbTrack>();
            for (const auto& Track : Phase.Get_LimbTracks())
            {
                if (Track.Get_Slot() != InSlot)
                { Tracks.Add(Track); }
            }
            Phase.Set_LimbTracks(Tracks);
        }
        Draft.Set_Phases(Phases);
        return Draft;
    }
}
