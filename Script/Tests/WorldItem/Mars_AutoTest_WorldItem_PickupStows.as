// A World-mode item seeds its holder from its definition; stowing that item the way the pickup task does lands it in
// the hotbar (auto-held, hands were empty), and the emptied world item destroys itself. Isolated Z band: -50000.
class UMars_AutoTest_WorldItem_PickupStows : UCk_AutoTest_Base
{
    private FCk_Handle_Hotbar _Hotbar;
    private FCk_Handle_WorldItem _WorldItem;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto LocalHandle = InHandle;
        auto HotbarSpec = FMars_Hotbar_Spec();
        HotbarSpec.BagSlotCount = 1;
        _Hotbar = utils_hotbar::Add(LocalHandle, HotbarSpec);

        auto SpawnParams = UMars_WorldItem_EntityScript::Params();
        SpawnParams.Definition = mars_items::Rock();
        SpawnParams.Mode = EMars_WorldItem_Mode::World;
        SpawnParams.SpawnTransform = FTransform(FRotator::ZeroRotator, FVector(0.0, 0.0, -50000.0));

        auto Pending = utils_entity_script::Request_SpawnEntity(InHandle, UMars_WorldItem_EntityScript, SpawnParams);
        utils_pending_entity_script::Promise_OnConstructed(
            Pending,
            FCk_Delegate_EntityScript_Constructed(this, n"OnWorldItemConstructed"));

        Add_Step_WaitUntil("the world item's holder holds its seeded rock", n"Check_HolderSeeded");
        Add_Step("stow the rock the way the pickup task does", n"Step_Stow");
        Add_Step_WaitUntil("slot 0 holds the rock and is auto-held", n"Check_Stowed");
        Add_Step_WaitUntil("the emptied world item destroyed itself", n"Check_WorldItemDestroyed");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void OnWorldItemConstructed(FCk_Handle_EntityScript InEntityScriptHandle)
    {
        auto Entity = FCk_Handle(InEntityScriptHandle);
        _WorldItem = Entity.As_WorldItem(ECk_SanityCheck::UnChecked);
    }

    UFUNCTION()
    private void Check_HolderSeeded(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(ck::IsValid(_WorldItem) && ck::IsValid(_WorldItem.Get_HeldItem()));
    }

    UFUNCTION()
    private void Step_Stow(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Item = _WorldItem.Get_HeldItem();
        auto Target = _Hotbar.TryGet_StowTarget(Item);
        if (ck::Is_NOT_Valid(Target) || ck::Is_NOT_Valid(Item))
        {
            FinishFailure("stow precondition: a valid stow target and a world item holding one item");
            return;
        }

        auto Holder = _WorldItem.Get_Holder();
        Holder.Request_TransferItem_ToDataOnly(FCk_Request_Inventory_TransferItem_ToDataOnly(Item, Target),
            FCk_Delegate_Inventory_OnOperationResult_Transfer());
    }

    UFUNCTION()
    private void Check_Stowed(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(ck::IsValid(_Hotbar.Get_ItemAt(0)) && _Hotbar.Get_SelectedIndex() == 0);
    }

    UFUNCTION()
    private void Check_WorldItemDestroyed(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(ck::Is_NOT_Valid(_WorldItem));
    }
}
