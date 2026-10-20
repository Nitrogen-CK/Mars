// The four attack clips under the crawler's Actions folder load, compile and satisfy the attack definition's clip contract
// inside their shipped parity definitions, so a change to the clip data model never strands the content a crawler plays.
class UMars_AutoTest_CrawlerMelee_ShippedClipsLoad : UCk_AutoTest_Base
{
    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Add_Step("load, compile and validate the four shipped attack clips", n"Step_Check");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_Check(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Presets = TArray<EMars_Crawler_AttackPreset>();
        Presets.Add(EMars_Crawler_AttackPreset::Crawler4);
        Presets.Add(EMars_Crawler_AttackPreset::Spider6);
        auto Ids = TArray<FGameplayTag>();
        Ids.Add(GameplayTags::Attack_Mars_Jab);
        Ids.Add(GameplayTags::Attack_Mars_Pincer);

        for (const auto Preset : Presets)
        {
            for (const auto Id : Ids)
            {
                const auto Path = utils_crawler::Get_AttackReferenceLegacyClipPath(Preset, Id);
                auto Clip = System::LoadAsset_Blocking(TSoftObjectPtr<UCk_ProceduralAction_Data>(FSoftObjectPath(Path)));
                Assert_True(ck::IsValid(Clip), f"[{Path}] loads");
                if (ck::Is_NOT_Valid(Clip))
                { continue; }

                const auto Report = utils_procedural_action::Validate_Data(Clip);
                Assert_True(Report.Get_Status() == ECk_ProceduralAction_ReportStatus::Valid,
                    f"[{Path}] compiles: {utils_crawler::Get_FirstDiagnosticText(Report)}");

                const auto DefinitionPath = utils_crawler::Get_AttackReferenceDefinitionPath(Preset, EMars_AttackReference_Kind::Parity, Id);
                auto Definition = System::LoadAsset_Blocking(TSoftObjectPtr<UMars_AttackDefinition_Data>(FSoftObjectPath(DefinitionPath)));
                Assert_True(ck::IsValid(Definition), f"[{DefinitionPath}] loads");
                if (ck::Is_NOT_Valid(Definition))
                { continue; }

                auto Def = Definition.Def;
                Def.Clip = TSoftObjectPtr<UCk_ProceduralAction_Data>(Clip);
                const auto Validation = utils_attack::Validate_Definition(Def);
                Assert_True(Validation.Get_IsValid(), f"[{Path}] satisfies its {Id.ToString()} definition: {utils_crawler::Get_AttackValidationText(Validation)}");
            }
        }
    }
}
