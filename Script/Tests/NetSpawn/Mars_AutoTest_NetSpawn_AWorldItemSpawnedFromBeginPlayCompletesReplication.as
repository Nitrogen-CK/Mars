// A rock spawned through the world-item funnel inside the test's own DoBeginPlay (a test entity begins play in the main
// pass after the framework's spawn processor, so the spawn is executed in the script group's settle barrier) completes
// its replication on this world and is let go by the host-side check with no ensure, as a listen host and in
// standalone alike. Isolated location: far -Y.
class UMars_AutoTest_NetSpawn_AWorldItemSpawnedFromBeginPlayCompletesReplication : UCk_AutoTest_Base
{
    default _TimeoutSeconds = 10.0f;

    private const FVector k_Location = FVector(0.0, -56000.0, 0.0);

    private FCk_Handle _Rock;
    private int32 _EnsuresBefore = 0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        _EnsuresBefore = utils_ensure::Get_EnsureCount();

        auto Owner = InHandle;
        auto Spec = FMars_WorldItem_WorldSpec(utils_held_item::Make_DefinitionSoft(mars_items::Rock()), FTransform(FRotator::ZeroRotator, k_Location));
        _Rock = utils_world_item::Request_SpawnWorld(Owner, Spec);
        if (ck::IsValid(_Rock))
        { Track_ForCleanup(_Rock); }

        Add_Step_WaitSeconds("let the rock build, replicate and be let go by the check", 2.0f);
        Add_Step("the rock completed its replication, the check let it go and nothing ensured", n"Step_Record");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_Record(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(ck::IsValid(_Rock), "the funnel built the rock (the replicated spawn owner was published at begin play)");
        if (ck::Is_NOT_Valid(_Rock))
        { return; }

        const auto World = utils_entity_lifetime::Get_WorldForEntity(_Rock);
        const auto HasDriver = utils_entity_replication_driver::Has(_Rock);
        const auto Complete = HasDriver && utils_entity_replication_driver::Get_IsReplicationComplete(_Rock);
        const auto NewEnsures = utils_ensure::Get_EnsureCount() - _EnsuresBefore;
        Log(f"[NetSpawnTest] begin-play rock on {World.GetNetMode() :n}: hasDriver={HasDriver} replicationComplete={Complete} "
            + f"awaiting={_Rock.Has_Fragment(FMars_Fragment_NetSpawn_AwaitingReplication)} worldItem={_Rock.Is_WorldItem()} newEnsures={NewEnsures}");
        Assert_True(HasDriver, "the rock has a replication driver");
        Assert_True(Complete, "the rock completed its replication on this world");
        Assert_False(_Rock.Has_Fragment(FMars_Fragment_NetSpawn_AwaitingReplication), "the check let the rock go");
        Assert_True(_Rock.Is_WorldItem() && ck::IsValid(_Rock.As_WorldItem().Get_HeldItem()), "the rock is a world item holding its item");
        Assert_Equals_Int(NewEnsures, 0, "nothing ensured");
    }
}
