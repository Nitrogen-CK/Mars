// Every candidate an anchor can draw reaches every machine where the anchor stands: a scripted row that stays local
// would be a candidate with a body that only the host would have.
class UMars_AutoTest_AnchorResolver_EveryScriptedRowReplicates : UMars_AutoTestRig_AnchorResolverPure
{
    default _TimeoutSeconds = 10.0f;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Add_Step("every scripted row replicates", n"Step_Rows");
        Run_Steps(InHandle);
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

                Assert_True(Row.Net == EMars_AnchorRow_Net::Replicated,
                    f"{Table.GetName()} row {Index} ({Row.Script.Get().GetName()}) is Replicated, not {Row.Net :n}");
            }
        }

        Assert_Equals_Int(LocalRows, 0, "no scripted row stays local");
    }
}
