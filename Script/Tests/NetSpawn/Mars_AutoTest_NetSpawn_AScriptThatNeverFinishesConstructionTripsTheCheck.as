// A Replicates script under the replicated spawn owner that returns Continue and never finishes its construction is never
// replicated. utils_net_spawn::Expect_Replicated catches it: past the frame budget the verify processor ensures once (the
// expected error below) and stops checking it, and a second budget later it has not ensured again. Single world: as a
// listen host and in standalone alike. The script has no transform or body.
class UMars_AutoTest_NetSpawn_AScriptThatNeverFinishesConstructionTripsTheCheck : UCk_AutoTest_Base
{
    default _TimeoutSeconds = 8.0f;

    private FCk_Handle _Script;
    private int32 _EnsuresBefore = 0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Add_Step_WaitUntil("this world's replicated spawn owner is published", n"Check_SpawnOwnerReady");
        Add_Step("spawn the never-finishing script and stamp the check", n"Step_Spawn");
        Add_Step_WaitUntil("the check fired and let it go", n"Check_Released");
        Add_Step_WaitSeconds("let a second budget pass", 1.0f);
        Add_Step("the check ensured once and the script never replicated", n"Step_Record");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Check_SpawnOwnerReady(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(utils_mars_net::Get_HasReplicatedSpawnOwner(InHandle));
    }

    UFUNCTION()
    private void Step_Spawn(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Owner = utils_mars_net::Get_ReplicatedSpawnOwner(InHandle);
        _EnsuresBefore = utils_ensure::Get_EnsureCount();
        _Script = utils_entity_script::Request_SpawnEntity(Owner, UMars_TESTONLY_NetSpawn_NeverFinishes_EntityScript, FInstancedStruct()).Get_EntityUnderConstruction();
        utils_net_spawn::Expect_Replicated(_Script);
        Track_ForCleanup(_Script);
    }

    UFUNCTION()
    private void Check_Released(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(ck::IsValid(_Script) && _Script.Has_Fragment(FMars_Fragment_NetSpawn_AwaitingReplication) == false);
    }

    UFUNCTION()
    private void Step_Record(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(ck::IsValid(_Script), "the script was built");
        if (ck::Is_NOT_Valid(_Script))
        { return; }

        const auto HasDriver = utils_entity_replication_driver::Has(_Script);
        const auto Complete = HasDriver && utils_entity_replication_driver::Get_IsReplicationComplete(_Script);
        const auto NewEnsures = utils_ensure::Get_EnsureCount() - _EnsuresBefore;
        Log(f"[NetSpawnTest] never-finishing script: hasDriver={HasDriver} replicationComplete={Complete} newEnsures={NewEnsures}");
        Assert_True(HasDriver, "the script has a replication driver (so the check reached its budget, not the no-driver ensure)");
        Assert_False(Complete, "the script never completed replication");
        Assert_False(_Script.Has_Fragment(FMars_Fragment_NetSpawn_AwaitingReplication), "the check let it go");
        Assert_Equals_Int(NewEnsures, 1, "the check ensured exactly once");
    }
}

// Hand-authored so the check's ensure is an expected error rather than a failure.
class AMars_AutoTest_NetSpawn_AScriptThatNeverFinishesConstructionTripsTheCheck_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 8.0f;
    default _TestEntityScriptClass = UMars_AutoTest_NetSpawn_AScriptThatNeverFinishesConstructionTripsTheCheck;

    UFUNCTION(BlueprintOverride)
    TArray<FString> Get_ExpectedLogErrors() const
    {
        TArray<FString> Out;
        Out.Add("was expected to replicate and has not");
        return Out;
    }
}
