// A hotbar on a carrier that has a replication driver (a Replicates script under the replicated spawn owner, requested from
// a continuation) gets the replicated slot class at every index; every slot root completes replication on this world, and
// an item seeded into slot 0 lands there. Run as a listen host and in standalone: the same class either way.
class UMars_AutoTest_Hotbar_ADriverBearingCarrierGetsReplicatedSlots : UMars_AutoTestRig_ReplicatedHotbarCarrier
{
    private int32 _EnsuresBefore = 0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        _EnsuresBefore = utils_ensure::Get_EnsureCount();
        Add_CarrierSteps();
        Add_Step("every slot root is the replicated class", n"Step_AssertClasses");
        Add_Step_WaitUntil("every slot root completed replication", n"Check_SlotsReplicated");
        Add_Step("seed a rock into slot 0", n"Step_Seed");
        Add_Step_WaitUntil("slot 0 holds the rock", n"Check_Seeded");
        Add_Step("no ensure fired", n"Step_AssertNoEnsure");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_AssertClasses(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(utils_entity_replication_driver::Has(_Carrier), "the carrier has a replication driver");

        auto Hotbar = Get_CarrierHotbar();
        for (int32 Index = 0; Index <= Hotbar.Get_LastIndex(); ++Index)
        {
            auto Root = Get_SlotRoot(Index);
            Assert_True(ck::IsValid(Root) && utils_entity_script::Has(Root)
                && utils_entity_script::Get_ScriptClass(Root.As_EntityScript()) == UMars_HotbarSlot_EntityScript,
                f"slot [{Index}]'s root is the replicated slot class");
            Assert_True(ck::IsValid(Root) && utils_entity_replication_driver::Has(Root), f"slot [{Index}]'s root has a replication driver");
        }
    }

    UFUNCTION()
    private void Check_SlotsReplicated(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Hotbar = Get_CarrierHotbar();
        auto AllComplete = true;
        for (int32 Index = 0; Index <= Hotbar.Get_LastIndex(); ++Index)
        {
            auto Root = Get_SlotRoot(Index);
            AllComplete = AllComplete && ck::IsValid(Root) && utils_entity_replication_driver::Has(Root)
                && utils_entity_replication_driver::Get_IsReplicationComplete(Root);
        }

        auto Result = OutResult;
        Result.Set(AllComplete);
    }

    UFUNCTION()
    private void Step_Seed(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Slot = Get_CarrierHotbar().Get_Slot(0);
        auto Request = FCk_Request_Inventory_AddItemByDefinition(mars_items::Rock(), 1);
        Request.Set_Policy(ECk_Inventory_AddPolicy::ForceNewItem);
        Slot.Request_AddItemByDefinition(Request, FCk_Delegate_Inventory_OnOperationResult_AddByDefinition());
    }

    UFUNCTION()
    private void Check_Seeded(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(ck::IsValid(Get_CarrierHotbar().Get_ItemAt(0)));
    }

    UFUNCTION()
    private void Step_AssertNoEnsure(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(utils_ensure::Get_EnsureCount() - _EnsuresBefore, 0, "no ensure fired");
    }
}
