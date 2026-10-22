class UMars_AutoTest_Bellkeeper_TeardownCancelsADedicatedRestart : UMars_AutoTestRig_BellkeeperDedicatedVent
{
    default _TimeoutSeconds = 10.0f;
    private bool _SawRestart = false;
    private FCk_Handle_Timer _Timer;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        AddDedicatedLock(InHandle);
        _Bellkeeper.BindTo_OnCommitFailed(FMars_Delegate_Bellkeeper_OnCommitFailed(this, n"OnWrongCommit"));
        Add_Step("wrong commit", n"Step_Commit");
        Add_Step_WaitUntil("actual Fire", n"Check_Fire", k_SlowPolls, 0);
        Add_Step("restart; destroy its owner before acknowledgement", n"Step_Commit");
        Add_Step_WaitUntil("all owned work gone", n"Check_Gone", k_SlowPolls, 0);
        Add_Step_WaitSeconds("outlast old clock", 2.2f);
        Add_Step("no work can restart the vent", n"Step_Assert");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_Commit(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Timer = _Bellkeeper.Get_Fragment(FMars_Fragment_Bellkeeper).VentTimer;
        _Bellkeeper.Request_Commit(FMars_Request_Bellkeeper_Commit());
    }

    UFUNCTION()
    private void Check_Fire(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsFiring());
    }

    UFUNCTION()
    private void OnWrongCommit(FCk_Handle_Bellkeeper InLock, int32 InRemaining)
    {
        if (InLock.Get_FailedCommits() == 2)
        {
            _SawRestart = InLock.Get_Fragment(FMars_Fragment_Bellkeeper).VentTransition == EMars_Bellkeeper_VentTransition::AwaitStopped;
            utils_entity_lifetime::Request_DestroyEntity(_Entity);
        }
    }

    UFUNCTION()
    private void Check_Gone(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(ck::Is_NOT_Valid(_Entity) && ck::Is_NOT_Valid(_VentSource) && ck::Is_NOT_Valid(_VentCycle)
            && ck::Is_NOT_Valid(_Hazard) && ck::Is_NOT_Valid(_Timer));
    }

    UFUNCTION()
    private void Step_Assert(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_SawRestart, "teardown interrupted real pending restart");
        Assert_Equals_Int(utils_mechanism_source::Get_SourcesOn(InHandle, GameplayTags::Mechanism_Channel_K).Num(), 0, "no source survived");
        Assert_False(ck::IsValid(_VentCycle), "no Cycle survived");
        Assert_False(ck::IsValid(_Timer), "no old timer survived");
    }
}
