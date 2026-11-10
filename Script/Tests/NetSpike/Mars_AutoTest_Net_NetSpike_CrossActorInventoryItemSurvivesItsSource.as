// Probe C of the handle spike: an item seeded into a replicated one-slot inventory on R (under the spawn owner, the relay
// actor) is transferred into a replicated one-slot inventory S on the test SUBJECT (another replicated actor), then R is
// destroyed: the geometry of a pickup from a world item into a pawn's hotbar slot. The client records whether S received
// a valid item, and whether S still holds a valid item, the same one, once R's destroy has replicated. It passes by
// recording: it logs one [NetSpike] C line and asserts only that it ran to the end.
// Surface: Ck.NetSpike.Net.AS_NetSpike_CrossActorInventoryItemSurvivesItsSource
class UCk_AutoTest_Net_NetSpike_CrossActorInventoryItemSurvivesItsSource : UCk_AutoTest_NetBase
{
    default _TimeoutSeconds = 22.0f;

    private const int32 k_PayloadR = 3301;
    // Long enough for the client to see R holding the item before it moves.
    private const float32 k_HoldBeforeTransferSeconds = 1.5f;
    private const float32 k_ServerHoldSeconds = 6.0f;
    private const float32 k_ClientSettleSeconds = 2.0f;
    private const int32 k_SlowPolls = 5000;
    // The client's window for S to receive the item, then for R to leave (12 s each at the pinned 60 fps).
    private const int32 k_MaxFrames = 720;

    private FCk_Handle_Inventory_DataOnly _S;
    private FCk_Handle _R;

    private int32 _Frame = 0;
    private bool _RSeen = false;
    private int32 _RItemsSeen = 0;
    private TOptional<int32> _SItemFrame;
    private FCk_Handle_Item _SItemAtArrival;
    private TOptional<int32> _RGoneFrame;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Subject = Get_SubjectEntity();
        if (ck::Is_NOT_Valid(Subject))
        { FinishFailure("subject entity not found"); return; }

        // Composed on both machines, as a pawn composes its slots.
        _S = utils_net_spike::Add_OneSlotInventory(Subject, utils_gameplay_tag::ResolveGameplayTag(n"Inventory.Mars.Slot.0"));

        if (utils_net::Get_HasAuthority(Subject) == false)
        {
            WaitUntil(n"Poll_ClientUntilSHasItem", n"OnClientSReceived", k_MaxFrames + 10);
            return;
        }

        WaitUntil(n"Is_ReplicatedSpawnOwnerPublished", n"OnServerOwnerPublished", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ReplicatedSpawnOwnerPublished(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(utils_mars_net::Get_HasReplicatedSpawnOwner(Get_SubjectEntity()));
    }

    UFUNCTION()
    private void OnServerOwnerPublished(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        auto Owner = utils_mars_net::Get_ReplicatedSpawnOwner(Get_SubjectEntity());
        auto Params = FMars_NetSpike_SpawnParams(FVector(16000.0, 0.0, 0.0), k_PayloadR);
        Params.WithInventory = true;
        auto Pending = utils_entity_script::Request_SpawnEntity(Owner, UMars_NetSpike_EntityScript, Params);
        utils_pending_entity_script::Promise_OnConstructed(Pending, FCk_Delegate_EntityScript_Constructed(this, n"OnServerRConstructed"));
    }

    UFUNCTION()
    private void OnServerRConstructed(FCk_Handle_EntityScript InEntityScriptHandle)
    {
        _R = FCk_Handle(InEntityScriptHandle);
        Track_ForCleanup(_R);

        auto Request = FCk_Request_Inventory_AddItemByDefinition(mars_items::Rock(), 1);
        Request.Set_Policy(ECk_Inventory_AddPolicy::ForceNewItem);
        auto Inventory = utils_net_spike::Get_Local(_R).Inventory;
        Inventory.Request_AddItemByDefinition(Request, FCk_Delegate_Inventory_OnOperationResult_AddByDefinition(this, n"OnServerSeeded"));
    }

    UFUNCTION()
    private void OnServerSeeded(FCk_Handle_Inventory InInventory, ECk_Inventory_OperationResult_AddByDefinition InResult,
                                int InAmountAdded, const TArray<FCk_Handle_Item>&in InItemsCreated)
    {
        if (InResult != ECk_Inventory_OperationResult_AddByDefinition::Success_AllAdded)
        { FinishFailure(f"seeding R failed with [{InResult :n}]"); return; }

        WaitSeconds(k_HoldBeforeTransferSeconds, n"OnServerTransfer");
    }

    UFUNCTION()
    private void OnServerTransfer(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        auto Inventory = utils_net_spike::Get_Local(_R).Inventory;
        auto Items = Inventory.Get_Items();
        if (Items.Num() != 1)
        { FinishFailure(f"R holds {Items.Num()} items before the transfer"); return; }

        Inventory.Request_TransferItem_ToDataOnly(FCk_Request_Inventory_TransferItem_ToDataOnly(Items[0], _S),
            FCk_Delegate_Inventory_OnOperationResult_Transfer(this, n"OnServerTransferred"));
    }

    UFUNCTION()
    private void OnServerTransferred(FCk_Handle_Inventory InSource, FCk_Handle_Item InItem, FCk_Handle_Inventory InTarget,
                                     int32 InCount, FCk_Handle_Item InNewItemInTarget, ECk_Inventory_OperationResult_Transfer InResult)
    {
        if (InResult != ECk_Inventory_OperationResult_Transfer::Success)
        { FinishFailure(f"the transfer R -> S failed with [{InResult :n}]"); return; }

        utils_entity_lifetime::Request_DestroyEntity(_R);
        WaitSeconds(k_ServerHoldSeconds, n"OnServerHeld");
    }

    UFUNCTION()
    private void OnServerHeld(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        FinishSuccess();
    }

    UFUNCTION()
    private void Poll_ClientUntilSHasItem(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        _Frame += 1;
        Observe_R();

        const auto Item = Get_SItem();
        if (ck::IsValid(Item) && _SItemFrame.IsSet() == false)
        {
            _SItemFrame = TOptional<int32>(_Frame);
            _SItemAtArrival = Item;
        }

        auto Result = OutResult;
        Result.Set(_SItemFrame.IsSet() || _Frame >= k_MaxFrames);
    }

    UFUNCTION()
    private void OnClientSReceived(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _Frame = 0;
        WaitUntil(n"Poll_ClientUntilRGone", n"OnClientRGone", k_MaxFrames + 10);
    }

    UFUNCTION()
    private void Poll_ClientUntilRGone(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        _Frame += 1;
        Observe_R();
        if (_RSeen && ck::Is_NOT_Valid(utils_net_spike::Find(Get_SubjectEntity(), k_PayloadR)) && _RGoneFrame.IsSet() == false)
        { _RGoneFrame = TOptional<int32>(_Frame); }

        auto Result = OutResult;
        Result.Set(_RGoneFrame.IsSet() || _Frame >= k_MaxFrames);
    }

    UFUNCTION()
    private void OnClientRGone(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_ClientSettleSeconds, n"OnClientSettled");
    }

    UFUNCTION()
    private void OnClientSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Item = Get_SItem();
        const auto SReceived = _SItemFrame.IsSet() ? f"frame{_SItemFrame.GetValue()}" : "never";
        const auto RGone = _RGoneFrame.IsSet() ? f"frame{_RGoneFrame.GetValue()}" : "no";
        const auto SCount = _S.Get_NumItems();
        const auto SValid = ck::IsValid(Item);
        const auto SameItem = SValid && Item == _SItemAtArrival;
        const auto ParentIsS = Get_IsParentS(Item);
        Log(f"[NetSpike] C rSeen={_RSeen} rItemsSeen={_RItemsSeen} sReceived={SReceived} rGoneAfterS={RGone} sCountAfterRGone+2s={SCount} sItemValidAfter={SValid} sameItemAsArrival={SameItem} itemParentIsS={ParentIsS}");
        FinishSuccess();
    }

    private void Observe_R()
    {
        const auto R = utils_net_spike::Find(Get_SubjectEntity(), k_PayloadR);
        if (ck::Is_NOT_Valid(R))
        { return; }

        _RSeen = true;
        auto Inventory = utils_net_spike::Get_Local(R).Inventory;
        if (ck::IsValid(Inventory))
        { _RItemsSeen = Math::Max(_RItemsSeen, Inventory.Get_NumItems()); }
    }

    private FCk_Handle_Item Get_SItem()
    {
        auto Items = _S.Get_Items();
        if (Items.Num() == 0)
        { return FCk_Handle_Item(); }

        return Items[0];
    }

    private bool Get_IsParentS(FCk_Handle_Item InItem)
    {
        if (ck::Is_NOT_Valid(InItem))
        { return false; }

        FCk_Handle Parent = InItem.Get_ParentInventory();
        FCk_Handle SEntity = _S;
        return Parent == SEntity;
    }
}
