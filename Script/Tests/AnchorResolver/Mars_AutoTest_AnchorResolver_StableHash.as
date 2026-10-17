class UMars_AutoTest_AnchorResolver_StableHash : UMars_AutoTestRig_AnchorResolverPure
{
    default _TimeoutSeconds = 10.0f;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Add_Step("FNV-1a over the lowercase id matches the precomputed values and ignores case", n"Step_Hash");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_Hash(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(utils_anchor_resolver::Get_StableHash(n"B-R1") == uint32(47340925), "B-R1 hashes to 47340925");
        Assert_True(utils_anchor_resolver::Get_StableHash(n"B-H2") == uint32(3890298246), "B-H2 hashes to 3890298246");
        Assert_True(utils_anchor_resolver::Get_StableHash(n"B-S3") == uint32(3906237222), "B-S3 hashes to 3906237222");
        Assert_True(utils_anchor_resolver::Get_StableHash(n"Anchor") == uint32(1122880180), "Anchor hashes to 1122880180");
        Assert_True(utils_anchor_resolver::Get_StableHash(n"b-r1") == utils_anchor_resolver::Get_StableHash(n"B-R1"),
            "the hash ignores case");
    }
}
