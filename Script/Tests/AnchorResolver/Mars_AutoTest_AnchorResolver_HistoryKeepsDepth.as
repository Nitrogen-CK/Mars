class UMars_AutoTest_AnchorResolver_HistoryKeepsDepth : UMars_AutoTestRig_AnchorResolverPure
{
    default _TimeoutSeconds = 10.0f;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Add_Step("history keeps the newest records first and never more than its depth", n"Step_Depth");
        Run_Steps(InHandle);
    }

    private FMars_AnchorRun_Record Make_Record(FGameplayTag InEntrance) const
    {
        auto Record = FMars_AnchorRun_Record();
        Record.Entrance = InEntrance;
        return Record;
    }

    UFUNCTION()
    private void Step_Depth(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto History = FMars_AnchorRun_History();
        History.Push(Make_Record(GameplayTags::Anchor_Mars_Test_A), 3);
        History.Push(Make_Record(GameplayTags::Anchor_Mars_Test_B), 3);
        History.Push(Make_Record(GameplayTags::Anchor_Mars_Test_C), 3);
        History.Push(Make_Record(GameplayTags::Anchor_Mars_Test_Fixture_X1), 3);
        History.Push(Make_Record(GameplayTags::Anchor_Mars_Test_Fixture_X2), 3);
        Assert_Equals_Int(History.Records.Num(), 3, "five pushes at depth 3 keep three");
        Assert_True(History.Records[0].Entrance == GameplayTags::Anchor_Mars_Test_Fixture_X2, "the newest is first");
        Assert_True(History.Records[1].Entrance == GameplayTags::Anchor_Mars_Test_Fixture_X1, "then the one before");
        Assert_True(History.Records[2].Entrance == GameplayTags::Anchor_Mars_Test_C, "the oldest kept is third");

        auto Empty = FMars_AnchorRun_History();
        Empty.Push(Make_Record(GameplayTags::Anchor_Mars_Test_A), 0);
        Assert_Equals_Int(Empty.Records.Num(), 0, "depth 0 keeps nothing");
    }
}
