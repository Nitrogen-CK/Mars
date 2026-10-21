// Destroying the lock mid-pulse takes its vent source with it: nothing sources K afterwards and the pulse's timer ends
// quietly (no ensure from a request on a dead lock).
class UMars_AutoTest_Bellkeeper_TeardownMidPulseLeavesNoVent : UMars_AutoTestRig_Bellkeeper
{
    default _TimeoutSeconds = 10.0f;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        AddLock(InHandle);

        Add_Step("commit wrong", n"Step_WrongCommit");
        Add_Step_WaitUntil("the vent pulse starts", n"Check_Venting", k_SlowPolls, 0);
        Add_Step("destroy the lock mid-pulse", n"Step_Destroy");
        Add_Step_WaitUntil("the lock and its children are gone", n"Check_Gone", k_SlowPolls, 0);
        Add_Step_WaitSeconds("outlast the pulse", 0.6f);
        Add_Step("nothing sources K", n"Step_AssertNoVent");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_WrongCommit(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_NothingSourcesTheRigChannels(InHandle);
        _Bellkeeper.Request_Commit(FMars_Request_Bellkeeper_Commit());
    }

    UFUNCTION()
    private void Check_Venting(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_VentSource.Get_IsAsserted());
    }

    UFUNCTION()
    private void Step_Destroy(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        utils_entity_lifetime::Request_DestroyEntity(_Entity);
    }

    UFUNCTION()
    private void Check_Gone(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(ck::Is_NOT_Valid(_Entity) && ck::Is_NOT_Valid(_VentSource));
    }

    UFUNCTION()
    private void Step_AssertNoVent(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(utils_mechanism_source::Get_SourcesOn(InHandle, GameplayTags::Mechanism_Channel_K).Num(), 0, "the vent source went with the lock");
    }
}
