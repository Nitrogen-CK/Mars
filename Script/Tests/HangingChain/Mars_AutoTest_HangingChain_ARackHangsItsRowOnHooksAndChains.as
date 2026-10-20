// A hanging rack lays its row from its fields alone, in its construction script (as the editor builds a placed rack: its
// components are Static, so they are configured before the spawn finishes). A Ceiling rack with the engine cube as its
// link (100 cm along X less the 6 cm overlap: a 94 cm pitch), its hook and its one item, ItemCount 3 and no extra drops,
// hangs one item on one hook per place, and each of its two chains carries as many whole links as fit between the plate's
// eye and the bar (300 - 14 = 286 cm: 3 links). A second Rebuild lays the same rack again instead of doubling it. The
// same rack mounted on a Wall keeps its three items and hooks and lays no chain.
class UMars_AutoTest_HangingChain_ARackHangsItsRowOnHooksAndChains : UCk_AutoTest_Base
{
    private AMars_HangingRack _Ceiling;
    private AMars_HangingRack _Wall;

    private const int32 k_Places = 3;
    // Two chains of floor(286 / 94) links each.
    private const int32 k_ChainLinks = 6;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        _Ceiling = Spawn_Rack(FVector(1000.0, 0.0, 5000.0), EMars_RackMount::Ceiling);
        _Wall = Spawn_Rack(FVector(1000.0, 1000.0, 5000.0), EMars_RackMount::Wall);

        Add_Step("the ceiling rack hangs one item on one hook per place, and two chains", n"Step_AssertCeiling");
        Add_Step("a second rebuild lays the same rack", n"Step_AssertRebuildIdempotent");
        Add_Step("a wall rack keeps the row and lays no chain", n"Step_AssertWall");
        Add_Step("cleanup", n"Step_Cleanup");
        Run_Steps(InHandle);
    }

    private AMars_HangingRack Spawn_Rack(FVector InLocation, EMars_RackMount InMount)
    {
        auto Rack = Cast<AMars_HangingRack>(SpawnActor(AMars_HangingRack, InLocation, FRotator::ZeroRotator, NAME_None, true));
        if (ck::Is_NOT_Valid(Rack))
        { return nullptr; }

        auto Cube = engine::load::Cube();
        Rack.Mount = InMount;
        Rack.Drop = 300.0f;
        Rack.PlateDrop = 14.0f;
        Rack.LinkMesh = Cube;
        Rack.LinkOverlap = 6.0f;
        Rack.HookMesh = Cube;
        Rack.BarMesh = Cube;
        Rack.ItemMeshes.Empty();
        Rack.ItemMeshes.Add(Cube);
        Rack.ItemCount = k_Places;
        Rack.ExtraDropMax = 0.0f;
        FinishSpawningActor(Rack);
        return Rack;
    }

    UFUNCTION()
    private void Step_AssertCeiling(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(ck::IsValid(_Ceiling), "the ceiling rack spawned");
        if (ck::Is_NOT_Valid(_Ceiling))
        { return; }

        Assert_Equals_Int(_Ceiling.Get_PlaceCount(), k_Places, "ItemCount sets the places");
        Assert_Equals_Int(_Ceiling.Get_ItemCount(), k_Places, "one item per place");
        Assert_Equals_Int(_Ceiling.Get_HookCount(), k_Places, "one hook per place");
        Assert_Equals_Int(_Ceiling.Get_LinkCount(), k_ChainLinks, "two chains of whole links between the plate and the bar");
    }

    UFUNCTION()
    private void Step_AssertRebuildIdempotent(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        if (ck::Is_NOT_Valid(_Ceiling))
        { return; }

        // A rebuild after begin play re-places the bar, which a Static component refuses (the editor rebuilds before play).
        _Ceiling.Bar.SetMobility(EComponentMobility::Movable);
        _Ceiling.Rebuild();
        Assert_Equals_Int(_Ceiling.Get_ItemCount(), k_Places, "the rebuild hangs the same items");
        Assert_Equals_Int(_Ceiling.Get_HookCount(), k_Places, "the rebuild hangs the same hooks");
        Assert_Equals_Int(_Ceiling.Get_LinkCount(), k_ChainLinks, "the rebuild lays the same chains");
    }

    UFUNCTION()
    private void Step_AssertWall(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(ck::IsValid(_Wall), "the wall rack spawned");
        if (ck::Is_NOT_Valid(_Wall))
        { return; }

        Assert_Equals_Int(_Wall.Get_ItemCount(), k_Places, "the wall rail hangs the same items");
        Assert_Equals_Int(_Wall.Get_HookCount(), k_Places, "the wall rail hangs the same hooks");
        Assert_Equals_Int(_Wall.Get_LinkCount(), 0, "a wall rail lays no chain");
    }

    UFUNCTION()
    private void Step_Cleanup(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        if (ck::IsValid(_Ceiling))
        { _Ceiling.DestroyActor(); }

        if (ck::IsValid(_Wall))
        { _Wall.DestroyActor(); }
    }
}
