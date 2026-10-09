// A dock torn down under a docked platter ends it: the platter's item lives in the dock's inventory and dies with it, so
// the platter cannot be released into the world. A platter carrying one box docks and settles on its dock, then the station
// root (the dock's lifetime owner) is destroyed. Within three frames the dock, the platter and the box on it are all going
// (invalid or pending destroy), and nothing ensures: no platter rides a dead node, none is left without its item.
// Isolated Z band: -60500.
class UMars_AutoTest_PlatterDock_DestroyedDockEndsItsPlatter : UMars_AutoTestRig_PlatterDock
{
    private const FVector k_Origin = FVector(0.0, 0.0, -60500.0);

    private FCk_Handle_Transform _Root;
    private FCk_Handle_PlatterDock _Dock;
    private FCk_Handle_FoodPiece _Box;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        _Root = Build_StationRoot(InHandle, k_Origin);
        _Dock = Build_Dock(_Root, Make_DockSpec(Make_Policy(TOptional<FGameplayTag>(), false),
            FTransform(FRotator::ZeroRotator, FVector(0.0, 60.0, 70.0)), "input platter"));
        Spawn_Platter(InHandle, FTransform(FRotator::ZeroRotator, k_Origin + FVector(200.0, 0.0, 0.0)), nullptr);
        _Box = Build_Box(FTransform(FRotator::ZeroRotator, k_Origin + FVector(300.0, 0.0, 0.0)));

        Add_Step_WaitUntil("the platter is constructed and the box is Ready", n"Check_Ready");
        Add_Step("load the box onto the platter", n"Step_Load");
        Add_Step_WaitUntil("the box landed", n"Check_BoxLanded");
        Add_Step("dock the platter", n"Step_Dock");
        Add_Step_WaitUntil("the platter is docked and has arrived on the dock", n"Check_DockedAndArrived");
        Add_Step("destroy the station root", n"Step_DestroyRoot");
        Add_Step_WaitFrames("the dock's teardown ends its platter", 3);
        Add_Step("the dock, the platter and its box are all going", n"Step_AssertEnded");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Check_Ready(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        // Resolves the platter's handles once it is constructed; the box decides the rest.
        Check_PlattersConstructed(InHandle, OutResult, InPayload);

        auto Res = OutResult;
        Res.Set(_Platters.Num() == 1 && _Box.Get_Status() == EMars_FoodPiece_Status::Ready);
    }

    UFUNCTION()
    private void Step_Load(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Platter = _Platters[0];
        Platter.Request_Load(FMars_Request_Platter_Load(_Box));
    }

    UFUNCTION()
    private void Check_BoxLanded(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Platters[0].Get_HeldCount() == 1);
    }

    UFUNCTION()
    private void Step_Dock(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Dock(_Dock, _PlatterItems[0]);
    }

    UFUNCTION()
    private void Check_DockedAndArrived(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        FCk_Handle PlatterEntity = _WorldItems[0];
        const auto IsDocked = _Dock.Get_Platter() == _Platters[0] && _WorldItems[0].Get_Mount() == EMars_WorldItem_Mount::Carried;

        auto Res = OutResult;
        Res.Set(IsDocked && PlatterEntity.Has_Fragment(FMars_Fragment_WorldItem_Arrival) == false);
    }

    UFUNCTION()
    private void Step_DestroyRoot(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(Get_MountParent(_WorldItems[0]) == _Dock.Get_Node(), "the docked platter hangs off the dock's node");
        Assert_True(_Box.TryGet_Platter() == _Platters[0], "the box rides the docked platter");

        FCk_Handle Root = _Root;
        utils_entity_lifetime::Request_DestroyEntity(Root);
    }

    UFUNCTION()
    private void Step_AssertEnded(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(Get_IsGoing(_Dock), "the dock is torn down");
        Assert_True(Get_IsGoing(_WorldItems[0]), "the docked platter ended with its dock");
        Assert_True(Get_IsGoing(_Box), "the box on the platter ended with it");
    }

    private bool Get_IsGoing(FCk_Handle InEntity) const
    {
        return ck::Is_NOT_Valid(InEntity) || utils_entity_lifetime::Get_IsPendingDestroy(InEntity, ECk_EntityLifetime_DestructionPhase::BeginDestroy);
    }
}
