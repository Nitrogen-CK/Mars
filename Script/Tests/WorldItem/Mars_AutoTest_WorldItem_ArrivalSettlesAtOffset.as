// A Visual-mode world item spawned with ArriveFrom starts at that world pose (100 uu from its rest offset) and the Arrive
// processor lerps its scene-node offset to AttachOffset, then drops the Arrival fragment. Isolated Z band: -52000.
class UMars_AutoTest_WorldItem_ArrivalSettlesAtOffset : UCk_AutoTest_Base
{
    private FCk_Handle _Visual;
    // The Arrival's start offset at construction; unset when the visual was constructed without an Arrival.
    private TOptional<FVector> _ConstructedArrivalFrom;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto RootEntity = utils_entity_lifetime::Request_CreateEntity(InHandle);
        const auto RootWorld = FTransform(FRotator::ZeroRotator, FVector(0.0, 0.0, -52000.0));
        auto Root = utils_transform::Add(RootEntity, RootWorld, ECk_Replication::DoesNotReplicate);

        auto SpawnParams = UMars_WorldItem_EntityScript::Params();
        SpawnParams.Definition = mars_items::Rock();
        SpawnParams.Mode = EMars_WorldItem_Mode::Visual;
        SpawnParams.AttachTo = Root;
        SpawnParams.AttachOffset = FTransform(FRotator::ZeroRotator, FVector(10.0, 0.0, 0.0));
        SpawnParams.ArriveFrom = FMars_WorldItem_Arrival(
            FTransform(FRotator::ZeroRotator, RootWorld.GetLocation() + FVector(110.0, 0.0, 0.0)));

        auto Pending = utils_entity_script::Request_SpawnEntity(InHandle, UMars_WorldItem_EntityScript, SpawnParams);
        utils_pending_entity_script::Promise_OnConstructed(
            Pending,
            FCk_Delegate_EntityScript_Constructed(this, n"OnVisualConstructed"));

        Add_Step_WaitUntil("the visual is constructed", n"Check_Constructed");
        Add_Step("the visual was constructed arriving from 100 uu away", n"Step_AssertArriving");
        Add_Step_WaitUntil("the Arrival fragment is gone", n"Check_Arrived");
        Add_Step("the offset settled at AttachOffset", n"Step_AssertSettled");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void OnVisualConstructed(FCk_Handle_EntityScript InEntityScriptHandle)
    {
        _Visual = InEntityScriptHandle;
        if (_Visual.Is_SceneNode() == false)
        {
            FinishFailure("the Visual world item was constructed without a scene node");
            return;
        }

        if (_Visual.Has_Fragment(FMars_Fragment_WorldItem_Arrival))
        { _ConstructedArrivalFrom = TOptional<FVector>(_Visual.Get_Fragment(FMars_Fragment_WorldItem_Arrival).FromOffset.GetLocation()); }
    }

    UFUNCTION()
    private void Check_Constructed(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(ck::IsValid(_Visual));
    }

    UFUNCTION()
    private void Step_AssertArriving(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_ConstructedArrivalFrom.IsSet(), "a Visual spawned with ArriveFrom carries an Arrival fragment");
        if (_ConstructedArrivalFrom.IsSet() == false)
        { return; }

        const auto ArrivalFrom = _ConstructedArrivalFrom.GetValue();
        Assert_True(ArrivalFrom.Equals(FVector(110.0, 0.0, 0.0), 0.01),
            f"the Arrival starts at the ArriveFrom pose relative to the root (got [{ArrivalFrom.ToString()}])");
    }

    UFUNCTION()
    private void Check_Arrived(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(ck::IsValid(_Visual) && _Visual.Has_Fragment(FMars_Fragment_WorldItem_Arrival) == false);
    }

    UFUNCTION()
    private void Step_AssertSettled(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Offset = utils_scene_node::Get_Offset(_Visual.As_SceneNode()).GetLocation();
        Assert_True(Offset.Equals(FVector(10.0, 0.0, 0.0), 0.01),
            f"the settled offset is AttachOffset (got [{Offset.ToString()}])");
    }
}
