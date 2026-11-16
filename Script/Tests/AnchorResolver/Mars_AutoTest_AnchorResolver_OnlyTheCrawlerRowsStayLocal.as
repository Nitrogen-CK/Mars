// Every candidate an anchor can draw reaches every machine where the anchor stands: a scripted row that stays local
// would be a candidate with a body that only the host would have. The crawlers do not replicate, so their two rows are
// the only local ones.
class UMars_AutoTest_AnchorResolver_OnlyTheCrawlerRowsStayLocal : UMars_AutoTestRig_AnchorResolverPure
{
    default _TimeoutSeconds = 10.0f;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Add_Step("every scripted row replicates but the two crawler rows", n"Step_Rows");
        Run_Steps(InHandle);
    }

    private bool Get_IsCrawlerScript(TSubclassOf<UCk_EntityScript_UE> InScript) const
    {
        return InScript == UMars_Anchor_SentryCrawler4_EntityScript || InScript == UMars_Anchor_QuarryCrawler4_EntityScript;
    }

    UFUNCTION()
    private void Step_Rows(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Tables = TArray<UMars_AnchorTable_Def>();
        Tables.Add(utils_anchor::Table_Route());
        Tables.Add(utils_anchor::Table_Hunt());
        Tables.Add(utils_anchor::Table_Spawn());
        Tables.Add(utils_anchor::Table_Forage());
        Tables.Add(utils_anchor::Table_Cache());
        Tables.Add(utils_anchor::Table_Omen());
        Tables.Add(utils_anchor::Table_Threat());
        Tables.Add(utils_anchor::Table_Trap());
        Tables.Add(utils_anchor::Table_Rest());
        Tables.Add(utils_anchor::Table_Pack());

        auto LocalRows = 0;
        for (auto Table : Tables)
        {
            for (int32 Index = 0; Index < Table.Rows.Num(); ++Index)
            {
                const auto& Row = Table.Rows[Index];
                if (Row.Script == nullptr)
                { continue; }

                if (Row.Net == EMars_AnchorRow_Net::Local)
                { LocalRows += 1; }

                const auto Expected = Get_IsCrawlerScript(Row.Script) ? EMars_AnchorRow_Net::Local : EMars_AnchorRow_Net::Replicated;
                Assert_True(Row.Net == Expected,
                    f"{Table.GetName()} row {Index} ({Row.Script.Get().GetName()}) is {Expected :n}, not {Row.Net :n}");
            }
        }

        Assert_Equals_Int(LocalRows, 2, "exactly two scripted rows stay local");
    }
}
