// The hash is FNV-1a over the lowercased tag string, so it is stable across processes.
class UMars_AutoTest_AnchorResolver_StableHash : UMars_AutoTestRig_AnchorResolverPure
{
    default _TimeoutSeconds = 10.0f;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Add_Step("FNV-1a over the lowercased tag string matches the precomputed values", n"Step_Hash");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_Hash(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(utils_anchor_resolver::Get_StableHash(GameplayTags::Anchor_Mars_Warrens_R1) == uint32(575394972), "Anchor.Mars.Warrens.R1 hashes to 575394972");
        Assert_True(utils_anchor_resolver::Get_StableHash(GameplayTags::Anchor_Mars_Warrens_H2) == uint32(629273423), "Anchor.Mars.Warrens.H2 hashes to 629273423");
        Assert_True(utils_anchor_resolver::Get_StableHash(GameplayTags::Anchor_Mars_Warrens_S3) == uint32(2622014227), "Anchor.Mars.Warrens.S3 hashes to 2622014227");
        Assert_True(utils_anchor_resolver::Get_StableHash(GameplayTags::Anchor_Mars_Test_A) == uint32(1591174758), "Anchor.Mars.Test.A hashes to 1591174758");
    }
}
