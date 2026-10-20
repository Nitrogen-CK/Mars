// The attack definition's clip contract (utils_attack::Validate_Definition) over the crawler's reference clips: each
// layout's reference jab and pincer pass inside their shipped definitions; a pincer definition playing the slotless jab,
// a pincer clip missing its ClawLeft slot, a jab without its Offense window and a jab whose strike end key is rotated are
// each rejected with the broken rule's diagnostic code. The derived clips compile (the clip compiler has no objection to
// any of them): the rules are the attack catalog's, not the clip format's. A combat profile that still names a retired
// clip is rejected asking for a Loadout. Pure: nothing is spawned.
class UMars_AutoTest_CrawlerMelee_PincerKeyValidation : UMars_AutoTestRig_CrawlerMelee
{
    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Add_Step("the clip contract admits the reference clips and names the broken rule of a derived one", n"Step_Assert");
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
            auto Spec = Make_ArmedCrawlerSpec(6);
            Spec.Layout = Layout;
            Wear_ReferenceLoadout(Spec, EMars_Crawler_AttackClipKind::Pincer);
            const auto Jab = utils_attack::Validate_Definition(Get_LoadoutDefinition(Spec, GameplayTags::Attack_Mars_Jab));
            const auto Pincer = utils_attack::Validate_Definition(Get_LoadoutDefinition(Spec, GameplayTags::Attack_Mars_Pincer));
            Assert_True(Jab.Get_IsValid() && Pincer.Get_IsValid(),
                f"the {Layout :n} reference clips pass inside their definitions (jab [{utils_crawler::Get_AttackValidationText(Jab)}], pincer [{utils_crawler::Get_AttackValidationText(Pincer)}])");
        }

        auto Spec = Make_ArmedCrawlerSpec(4);
        Wear_ReferenceLoadout(Spec, EMars_Crawler_AttackClipKind::Pincer);
        const auto JabDefinition = Get_LoadoutDefinition(Spec, GameplayTags::Attack_Mars_Jab);
        const auto PincerDefinition = Get_LoadoutDefinition(Spec, GameplayTags::Attack_Mars_Pincer);
        auto RadialJab = Get_ReferenceClip(EMars_Crawler_Layout::Radial, EMars_Crawler_AttackClipKind::Jab);
        auto RadialPincer = Get_ReferenceClip(EMars_Crawler_Layout::Radial, EMars_Crawler_AttackClipKind::Pincer);

        Assert_Rejects(With_Clip(PincerDefinition, RadialJab), n"ClipSlotCoverage", "a pincer definition playing the slotless jab");

        auto OneClaw = Build_DerivedClip(Make_DraftWithoutSlot(RadialPincer, utils_crawler::Get_LeftClawSlotId()));
        Assert_Rejects(With_Clip(PincerDefinition, OneClaw), n"ClipSlotCoverage", "a pincer clip missing its ClawLeft slot");

        auto NoWindowDraft = Make_DraftOf(RadialJab);
        NoWindowDraft.Set_Windows(TArray<FCk_ProceduralAction_Window>());
        Assert_Rejects(With_Clip(JabDefinition, Build_DerivedClip(NoWindowDraft)), n"ObstructionWindowMissing", "a jab without the Offense window");

        Assert_Rejects(With_Clip(JabDefinition, Build_DerivedClip(Make_DraftWithRotatedStrike(RadialJab))), n"StrikeEndRotation", "a jab whose strike end key is rotated");

        auto Combat = Spec.Combat;
        Assert_True(Combat.Validate().IsValid(), f"the armed profile with its reference loadout passes (got [{Combat.Validate().Get_Error()}])");
        Combat.PincerClip = Make_SoftClip(RadialPincer);
        const auto CombatValidation = Combat.Validate();
        Assert_True(CombatValidation.IsValid() == false && CombatValidation.Get_Error().Contains("PincerClip") && CombatValidation.Get_Error().Contains("author a Loadout"),
            f"a combat profile that names a retired clip is rejected asking for a Loadout (got [{CombatValidation.Get_Error()}])");
    }

    // InId's definition in InSpec's loadout.
    private FMars_Attack_Definition Get_LoadoutDefinition(const FMars_Crawler_Spec& InSpec, FGameplayTag InId) const
    {
        for (const auto& Entry : InSpec.Combat.Loadout.Get().Spec.Entries)
        {
            if (Entry.Id == InId)
            { return Entry.Definition.Get().Def; }
        }

        return FMars_Attack_Definition();
    }

    // InDefinition playing InClip instead.
    private FMars_Attack_Definition With_Clip(FMars_Attack_Definition InDefinition, UCk_ProceduralAction_Data InClip) const
    {
        auto Definition = InDefinition;
        Definition.Clip = Make_SoftClip(InClip);
        return Definition;
    }

    // InDefinition is rejected with a diagnostic of InCode.
    private void Assert_Rejects(const FMars_Attack_Definition& InDefinition, FName InCode, FString InWhat)
    {
        const auto Report = utils_attack::Validate_Definition(InDefinition);
        auto Named = false;
        for (const auto& Diagnostic : Report.Diagnostics)
        { Named = Named || Diagnostic.Code == InCode; }

        Assert_True(Report.Get_IsValid() == false && Named, f"{InWhat} is rejected as {InCode} (got [{utils_crawler::Get_AttackValidationText(Report)}])");
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
