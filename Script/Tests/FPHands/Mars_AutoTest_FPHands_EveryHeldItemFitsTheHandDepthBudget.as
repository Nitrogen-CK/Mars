// Every held item fits the scene-node depth budget of a first-person hand. A carrier built on the player's hand chain
// (utils_fphands::Create_HandChain) puts a backpack on, holds a lit lantern and hangs it on the pack's hook, then picks
// up, one at a time, a torch, a cookbook, a cleaver, a pan, a potion and a platter. For each held item every node under
// its presentation, read as the depth it would take on the player's own view (the item's depth below the hand attach
// point plus the player's first-person hand mount, depth 5), is at most 10: hand rig 0-5, carrier and slot 2, item root
// and at most 2 levels. No ensure since the row began. Isolated Z band: -133000.
class UMars_AutoTest_FPHands_EveryHeldItemFitsTheHandDepthBudget : UMars_AutoTestRig_Carrier
{
    default _TimeoutSeconds = 30.0f;

    private const FVector k_Origin = FVector(0.0, 0.0, -133000.0);
    private const int32 k_SlowPolls = 900;
    // The player's first-person hand mount (Player.HandPitch 0 .. Player.HandSwing 4, Player.HandMount 5).
    private const int32 k_PlayerHandMountDepth = 5;
    private const int32 k_DepthBudget = 10;

    private TArray<UCk_InventoryItem_Definition> _Definitions;
    private TArray<FCk_Handle> _Spawned;
    private int32 _Cursor = 0;
    private FString _Readout = "";
    private int32 _EnsuresAtStart = 0;

    private FCk_Handle _Pack;
    private FCk_Handle _HungLantern;
    private FCk_Handle_Item _HungLanternItem;
    private FCk_Handle_LanternHook _Hook;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        _EnsuresAtStart = utils_ensure::Get_EnsureCount();
        // A Back for the pack and a Belt for a carried flame's carry point, as the player has.
        auto Body = FMars_AutoTestHelper_CarrierBody(k_Origin);
        Body.ExtraPoints.Add(Get_BackPoint());
        Body.ExtraPoints.Add(FMars_AutoTestHelper_CarrierPoint(GameplayTags::AttachPoint_Mars_Belt, FVector(10.0, 20.0, 0.0)));
        _Carrier = InHandle;
        const auto Nodes = Build_CarrierBody(_Carrier, Body);
        _HandNode = Nodes.Hand;
        _BackNode = Nodes.Extra[0];
        Add_Hotbar(_Carrier, utils_hotbar::k_MaxBagSlotCount);
        _HeldItem = utils_held_item::Add(_Carrier);
        Spawn_StaticSlab(InHandle, k_Origin + FVector(0.0, 0.0, -110.0), FVector(800.0, 800.0, 10.0));

        _Definitions.Add(mars_items::Torch());
        _Definitions.Add(mars_items::Cookbook());
        _Definitions.Add(mars_items::Cleaver());
        _Definitions.Add(mars_items::Pan());
        _Definitions.Add(mars_items::Potion());
        _Definitions.Add(mars_items::Platter());
        for (int32 Index = 0; Index < _Definitions.Num(); ++Index)
        { _Spawned.Add(Spawn_Item(InHandle, _Definitions[Index], FVector(-240.0 + 60.0 * Index, 150.0, -90.0))); }

        _Pack = Spawn_Item(InHandle, mars_items::Backpack(), FVector(0.0, -150.0, -90.0));
        _HungLantern = Spawn_Item(InHandle, mars_items::Lantern(), FVector(100.0, -150.0, -90.0));

        Add_Step_WaitUntil("every item is composed and the hotbar is ready", n"Check_AllReady", k_SlowPolls, 0);
        Add_Step("light the lantern", n"Step_LightLantern");
        Add_Step("pick the backpack up (it goes on the back)", n"Step_GivePack");
        Add_Step_WaitUntil("the carrier wears the backpack", n"Check_Wearing", k_SlowPolls, 0);
        Add_Step("empty the hands and pick the lit lantern up", n"Step_GiveHungLantern");
        Add_Step_WaitUntil("the lantern is held", n"Check_HungLanternHeld", k_SlowPolls, 0);
        Add_Step("the held lantern's nodes fit the budget", n"Step_MeasureLantern");
        Add_Step("hang it on the pack's hook", n"Step_Hang");
        Add_Step_WaitUntil("it hangs on the hook, settled", n"Check_Hung", k_SlowPolls, 0);
        for (int32 Index = 0; Index < _Definitions.Num(); ++Index)
        {
            Add_Step("empty the hands and pick the next item up", n"Step_GiveNext");
            Add_Step_WaitUntil("the next item is held, settled in the hand", n"Check_NextHeld", k_SlowPolls, 0);
            Add_Step("its nodes fit the budget", n"Step_MeasureNext");
        }

        Add_Step("the readout; no ensure", n"Step_Finish");
        Run_Steps(InHandle);
    }

    private FCk_Handle Spawn_Item(FCk_Handle InHandle, UCk_InventoryItem_Definition InDefinition, FVector InOffset)
    {
        auto Owner = InHandle;
        const auto Spec = FMars_WorldItem_WorldSpec(utils_held_item::Make_DefinitionSoft(InDefinition), FTransform(FRotator::ZeroRotator, k_Origin + InOffset));
        auto Entity = utils_world_item::Request_SpawnWorld(Owner, Spec);
        Track_ForCleanup(Entity);
        return Entity;
    }

    private bool Get_IsComposed(FCk_Handle InEntity) const
    {
        const auto WorldItem = InEntity.As_WorldItem(ECk_SanityCheck::UnChecked);
        return ck::IsValid(WorldItem) && ck::IsValid(WorldItem.Get_HeldItem())
            && (WorldItem.Get_Persistence() != EMars_WorldItem_Persistence::Persistent || WorldItem.Get_IsLinked());
    }

    private int32 _ReadyPolls = 0;

    // Fails naming what is not ready past 600 polls.
    UFUNCTION()
    private void Check_AllReady(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        FString Missing = "";
        if (_Hotbar.Get_IsReady() == false)
        { Missing += "hotbar,"; }

        if (Get_IsComposed(_Pack) == false)
        { Missing += "backpack,"; }

        if (Get_IsComposed(_HungLantern) == false)
        { Missing += "second lantern,"; }

        for (int32 Index = 0; Index < _Spawned.Num(); ++Index)
        {
            if (Get_IsComposed(_Spawned[Index]) == false)
            { Missing += f"{_Definitions[Index].GetName()},"; }
        }

        _ReadyPolls += 1;
        if (Missing.IsEmpty() == false && _ReadyPolls == 600)
        { FinishFailure(f"not composed after 600 polls: {Missing}"); }

        auto Result = OutResult;
        Result.Set(Missing.IsEmpty());
    }

    UFUNCTION()
    private void Step_LightLantern(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Hung = _HungLantern.As_Flame();
        Hung.Request_SetIgnition(FMars_Request_Flame_SetIgnition(EMars_Flame_Ignition::Lit));
        _HungLanternItem = _HungLantern.As_WorldItem().Get_HeldItem();
    }

    // Nothing selected, then the carrier picks InEntity up: it lands in the first empty slot and, the hands being
    // empty, is held (a pack goes on the back).
    private void Give(FCk_Handle InEntity)
    {
        _Hotbar.Request_SetSelection(FMars_Request_Hotbar_SetSelection(TOptional<int32>()));
        auto WorldItem = InEntity.As_WorldItem();
        WorldItem.Request_PickUp(FMars_Request_WorldItem_PickUp(_Carrier));
    }

    private FCk_Handle_Item _NextItem;

    UFUNCTION()
    private void Step_GiveNext(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _NextItem = _Spawned[_Cursor].As_WorldItem().Get_HeldItem();
        Give(_Spawned[_Cursor]);
    }

    private bool Get_IsHeldAndSettled(FCk_Handle_Item InItem)
    {
        return ck::IsValid(InItem) && _HeldItem.Get_CurrentItem() == InItem && _HeldItem.Get_IsPresentationInHand()
            && _HeldItem.Get_IsPresentationSettled();
    }

    UFUNCTION()
    private void Check_NextHeld(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsHeldAndSettled(_NextItem));
    }

    // The deepest node of InRoot's tree as the player's own view would layer it; -1 without a layered node.
    private int32 Get_PlayerDepth(FCk_Handle InRoot)
    {
        const auto Deepest = mars_test_scene_depth::Get_Deepest(InRoot);
        const auto Hand = mars_test_scene_depth::Get_Depth(_HandNode.H());
        return Deepest < 0 || Hand < 0 ? -1 : Deepest - Hand + k_PlayerHandMountDepth;
    }

    UFUNCTION()
    private void Step_MeasureNext(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Name = _Definitions[_Cursor].GetName();
        const auto Root = _HeldItem.Get_PresentationEntity();
        const auto Depth = Get_PlayerDepth(Root);
        _Readout += f"{Name}:{Depth} [{mars_test_scene_depth::Describe(Root)}] ";
        Assert_True(Depth >= 0 && Depth <= k_DepthBudget, f"{Name} held on the player's view reaches depth {Depth} (at most {k_DepthBudget})");
        _Cursor += 1;
    }

    UFUNCTION()
    private void Step_GivePack(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto WorldItem = _Pack.As_WorldItem();
        WorldItem.Request_PickUp(FMars_Request_WorldItem_PickUp(_Carrier));
    }

    UFUNCTION()
    private void Check_Wearing(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_Hotbar.Get_IsWearingBackpack());
    }

    UFUNCTION()
    private void Step_GiveHungLantern(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Give(_HungLantern);
    }

    private int32 _LanternPolls = 0;

    // Fails with the hold's state past 600 polls.
    UFUNCTION()
    private void Check_HungLanternHeld(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        _LanternPolls += 1;
        const auto Held = Get_IsHeldAndSettled(_HungLanternItem);
        if (Held == false && _LanternPolls == 600)
        {
            const auto WorldItem = _HungLantern.As_WorldItem(ECk_SanityCheck::UnChecked);
            const auto Current = _HeldItem.Get_CurrentItem();
            const auto Selected = _Hotbar.Get_SelectedIndex();
            const auto SelectedIndex = Selected.IsSet() ? Selected.GetValue() : -1;
            FString Mount = "none";
            if (ck::IsValid(WorldItem))
            { Mount = f"{WorldItem.Get_Mount() :n}"; }

            FinishFailure(f"the lantern was not held: item valid {ck::IsValid(_HungLanternItem)} current {Current == _HungLanternItem} "
                + f"currentValid {ck::IsValid(Current)} inHand {_HeldItem.Get_IsPresentationInHand()} settled {_HeldItem.Get_IsPresentationSettled()} "
                + f"mount {Mount} selected {SelectedIndex}");
        }

        auto Result = OutResult;
        Result.Set(Held);
    }

    UFUNCTION()
    private void Step_MeasureLantern(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Depth = Get_PlayerDepth(_HungLantern);
        _Readout += f"Lantern:{Depth} [{mars_test_scene_depth::Describe(_HungLantern)}] ";
        Assert_True(Depth >= 0 && Depth <= k_DepthBudget, f"the held lit lantern on the player's view reaches depth {Depth} (at most {k_DepthBudget})");
    }

    UFUNCTION()
    private void Step_Hang(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Hook = _Pack.As_Backpack().TryGet_LanternHook();
        if (ck::Is_NOT_Valid(_Hook))
        {
            FinishFailure("the backpack has no lantern hook");
            return;
        }

        _Hook.Request_Hang(FMars_Request_LanternHook_Hang(_HungLanternItem));
    }

    UFUNCTION()
    private void Check_Hung(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_Hook.Get_Item() == _HungLanternItem && _Hook.Get_HasArrived());
    }

    UFUNCTION()
    private void Step_Finish(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto NewEnsures = utils_ensure::Get_EnsureCount() - _EnsuresAtStart;
        const auto HandDepth = mars_test_scene_depth::Get_Depth(_HandNode.H());
        Log(f"[HandDepthBudget] hand={HandDepth} ensures={NewEnsures} {_Readout}");
        Assert_Equals_Int(NewEnsures, 0, "no ensure since the row began");
    }
}

