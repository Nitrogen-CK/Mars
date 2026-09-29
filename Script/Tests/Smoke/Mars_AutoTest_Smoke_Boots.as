// Proves the Mars autotest pipeline: wrapper generated, placed in AutoTests_Mars_MAP, discovered by the toolbox.
class UMars_AutoTest_Smoke_Boots : UCk_AutoTest_Base
{
    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Add_Step("entity is valid", n"Step_CheckHandle");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_CheckHandle(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(ck::IsValid(InHandle), "test entity should be valid");
    }
}
