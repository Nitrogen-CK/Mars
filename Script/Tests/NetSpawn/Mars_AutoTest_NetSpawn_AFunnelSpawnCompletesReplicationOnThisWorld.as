// A rock spawned through the world-item funnel from a step (a timer continuation) has a replication driver and has
// completed its replication two seconds later, and the host-side check has let it go, on whatever authority world the
// lane runs (a listen host or a standalone world alike: a standalone world completes replication too, which is why
// utils_net_spawn::Expect_Replicated checks there as well). Isolated location: far -Y.
class UMars_AutoTest_NetSpawn_AFunnelSpawnCompletesReplicationOnThisWorld : UCk_AutoTest_Base
{
    default _TimeoutSeconds = 10.0f;

    private const FVector k_Location = FVector(0.0, -52000.0, 0.0);

    private FCk_Handle _Rock;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Add_Step_WaitUntil("this world's replicated spawn owner is published", n"Check_SpawnOwnerReady");
        Add_Step("spawn a rock through the funnel", n"Step_SpawnRock");
        Add_Step_WaitSeconds("let the rock build and replicate", 2.0f);
        Add_Step("the rock completed its replication and the check let it go", n"Step_Record");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Check_SpawnOwnerReady(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(utils_mars_net::Get_HasReplicatedSpawnOwner(InHandle));
    }

    UFUNCTION()
    private void Step_SpawnRock(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Owner = InHandle;
        auto Spec = FMars_WorldItem_WorldSpec(utils_held_item::Make_DefinitionSoft(mars_items::Rock()), FTransform(FRotator::ZeroRotator, k_Location));
        _Rock = utils_world_item::Request_SpawnWorld(Owner, Spec);
        Track_ForCleanup(_Rock);
    }

    UFUNCTION()
    private void Step_Record(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(ck::IsValid(_Rock), "the funnel built the rock");
        if (ck::Is_NOT_Valid(_Rock))
        { return; }

        const auto World = utils_entity_lifetime::Get_WorldForEntity(_Rock);
        const auto HasDriver = utils_entity_replication_driver::Has(_Rock);
        const auto Complete = HasDriver && utils_entity_replication_driver::Get_IsReplicationComplete(_Rock);
        Log(f"[NetSpawnTest] funnel rock on {World.GetNetMode() :n}: hasDriver={HasDriver} replicationComplete={Complete} "
            + f"awaiting={_Rock.Has_Fragment(FMars_Fragment_NetSpawn_AwaitingReplication)}");
        Assert_True(HasDriver, "the rock has a replication driver");
        Assert_True(Complete, "the rock completed its replication on this world");
        Assert_False(_Rock.Has_Fragment(FMars_Fragment_NetSpawn_AwaitingReplication), "the check let the rock go");
    }
}
