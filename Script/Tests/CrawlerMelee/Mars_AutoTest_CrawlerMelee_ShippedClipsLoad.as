// The four attack clips under the crawler's Actions folder load, compile and satisfy the attack kernel's clip rules, so a
// change to the clip data model never strands the content a crawler plays.
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
        auto Prefixes = TArray<FString>();
        Prefixes.Add("Crawler");
        Prefixes.Add("Spider");
        auto Kinds = TArray<EMars_Crawler_AttackClipKind>();
        Kinds.Add(EMars_Crawler_AttackClipKind::Jab);
        Kinds.Add(EMars_Crawler_AttackClipKind::Pincer);

        for (const auto& Prefix : Prefixes)
        {
            for (const auto Kind : Kinds)
            {
                const FString Name = f"{Prefix}_{utils_crawler::Get_ClipKindName(Kind)}_Mars_DA";
                const auto Path = TSoftObjectPtr<UCk_ProceduralAction_Data>(
                    FSoftObjectPath(f"/Game/Mars/Gameplay/Monsters/Crawler/Actions/{Name}.{Name}"));
                auto Clip = System::LoadAsset_Blocking(Path);
                Assert_True(ck::IsValid(Clip), f"[{Name}] loads");
                if (ck::Is_NOT_Valid(Clip))
                { continue; }

                const auto Report = utils_procedural_action::Validate_Data(Clip);
                Assert_True(Report.Get_Status() == ECk_ProceduralAction_ReportStatus::Valid,
                    f"[{Name}] compiles: {utils_crawler::Get_FirstDiagnosticText(Report)}");
                const auto Validation = utils_crawler::Validate_AttackClip(Clip, Kind);
                Assert_True(Validation.IsValid(), f"[{Name}] is a valid {Kind :n} clip: {Validation.Get_Error()}");
            }
        }
    }
}
