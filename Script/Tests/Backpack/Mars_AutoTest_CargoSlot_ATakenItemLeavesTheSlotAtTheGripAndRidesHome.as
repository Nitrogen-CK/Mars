// An item taken out of a cargo slot by a carrier with gloves leaves the slot only when the gloves close on it, and rides them
// home: every poll before the Grip the slot's cargo visual is drawn and no held visual exists; from the Grip on the held
// visual is drawn, starting where the cargo visual was, and travels to its hold offset in steps no larger than a fraction
// of the way (the slot's task moves the item at the Grip, UMars_SmTask_MoveItemAtGrip). A poll with neither mesh is a
// blink, one with both a double. The rock is put in the slot through the kernel first. A World-mode backpack on a floor
// in front of the carrier. Isolated origin (24400, -17000, -30000).
class UMars_AutoTest_CargoSlot_ATakenItemLeavesTheSlotAtTheGripAndRidesHome : UMars_AutoTestRig_Carrier
{
    default _TimeoutSeconds = 30.0f;

    private const FVector k_Origin = FVector(24400.0, -17000.0, -30000.0);
    private const FVector k_PackOffset = FVector(150.0, 0.0, 0.0);
    // The pack's construction and the gloves' grab outrun the default poll budget at lane frame rate.
    private const int32 k_SlowPolls = 900;
    private const float64 k_SettleCm = 0.5;
    private const float64 k_MaxStepFraction = 0.5;

    private FCk_Handle_Backpack _Backpack;
    private FCk_Handle_CargoSlot _Slot;
    private FVector _SlotVisualWorld = FVector::ZeroVector;

    private int32 _Polls = 0;
    private int32 _BlinkPolls = 0;
    private int32 _DoublePolls = 0;
    private int32 _VisualPolls = 0;
    private int32 _SlotGonePollsBeforeGrip = 0;
    private int32 _VisualPollsBeforeGrip = 0;
    private TOptional<FVector> _FirstVisualWorld;
    private TOptional<FVector> _LastVisualWorld;
    private float64 _MaxStepCm = 0.0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Add_CarrierBodyWithBack(InHandle, k_Origin);
        Add_Hotbar(_Carrier, 2);
        _HeldItem = utils_held_item::Add(_Carrier);

        auto Spec = FMars_FPHands_Spec();
        Spec.Reach.Grab.OutSeconds = 0.3f;
        Spec.Reach.Grab.GripSeconds = 0.3f;
        Spec.Reach.Grab.BackSeconds = 0.3f;
        Add_CarrierHands(Spec);

        // On a floor: a pack in free fall would move the slot between the take's start and the Grip.
        const auto FloorTop = k_Origin + k_PackOffset;
        Spawn_FloorSlab(InHandle, FloorTop);
        auto SpawnParams = UMars_Backpack_EntityScript::Params();
        SpawnParams.Definition = mars_items::Backpack();
        SpawnParams.Mode = EMars_WorldItem_Mode::World;
        SpawnParams.SpawnTransform = FTransform(FRotator::ZeroRotator, FloorTop + FVector(0.0, 0.0, 5.0));
        auto Pending = utils_entity_script::Request_SpawnEntity(InHandle, UMars_Backpack_EntityScript, SpawnParams);
        utils_pending_entity_script::Promise_OnConstructed(Pending, FCk_Delegate_EntityScript_Constructed(this, n"OnBackpackConstructed"));

        _Holders.Add(MakeSeededHolder(InHandle, mars_items::Rock()));

        Add_Step_WaitUntil("the rock holder is seeded", n"Check_HoldersSeeded", 0, 0);
        Add_Step_WaitUntil("the backpack is constructed with its cargo slots", n"Check_Ready", k_SlowPolls, 0);
        Add_Step_WaitUntil("the gloves rest, listening for a reach", n"Check_CarrierHandsRest", 0, 0);
        Add_Step("stow the rock into the carrier's hotbar", n"Step_StowRock");
        Add_Step_WaitUntil("the carrier holds the rock", n"Check_RockHeld", 0, 0);
        Add_Step("put the rock in slot 0 through the kernel", n"Step_StowThroughKernel");
        Add_Step_WaitUntil("slot 0 holds the rock, draws it, and the hands are empty and at rest", n"Check_RockInTheSlot", k_SlowPolls, 0);
        Add_Step("the carrier focuses the slot", n"Step_Focus");
        Add_Step_WaitUntil("the slot's target enters Focused", n"Check_AwaitedFocus", 0, 0);
        Add_Step("the carrier takes the rock through the slot's interaction", n"Step_Take");
        Add_Step_WaitUntil("the grab ran its course and the held visual settled at its hold offset (sampling every poll)", n"Check_TakeDone", k_SlowPolls, 0);
        Add_Step("the rock left the slot at the Grip, was drawn every poll and rode home", n"Step_AssertRodeHome");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void OnBackpackConstructed(FCk_Handle_EntityScript InEntityScriptHandle)
    {
        _Backpack = InEntityScriptHandle.As_Backpack();
    }

    UFUNCTION()
    private void Check_Ready(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const UMars_ItemTrait_Backpack Trait = mars_items::Backpack().Get_ItemTraitByClass(UMars_ItemTrait_Backpack);
        const auto Ready = ck::IsValid(_Backpack) && _Backpack.Get_CargoSlotCount() == Trait.CargoSlots.Num();
        if (Ready && ck::Is_NOT_Valid(_Slot))
        { _Slot = _Backpack.Get_CargoSlot(0); }

        auto Res = OutResult;
        Res.Set(Ready);
    }

    UFUNCTION()
    private void Step_StowRock(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        StowFrom(_Holders[0]);
    }

    UFUNCTION()
    private void Check_RockHeld(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_HeldItem.Get_CurrentItem() == _Items[0]);
    }

    UFUNCTION()
    private void Step_StowThroughKernel(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Slot.Get_ActionFor(_Carrier) == EMars_CargoSlot_Action::Stow, "a carrier holding a rock reads Stow on an empty slot");
        _Slot.Request_Stow(FMars_Request_CargoSlot_Stow(_Items[0]));
    }

    UFUNCTION()
    private void Check_RockInTheSlot(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Slot.Get_Item() == _Items[0] && Get_HasDrawnMesh(_Slot.Get_Visual())
            && ck::Is_NOT_Valid(_HeldItem.Get_CurrentItem()) && _Hands.Get_Hold().Kind == EMars_FPHands_HoldKind::Empty
            && _Hands.Get_Phase() == EMars_FPHands_Phase::None);
    }

    UFUNCTION()
    private void Step_Focus(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Interactable = _Slot.Get_Interactable();
        Interactable.Request_Focus(FMars_Request_Interactable_Focus(_Carrier));
        Await_FocusOf(Interactable);
    }

    // What the player's resolver does on a press: the interaction starts, and its task asks the gloves for the reach.
    UFUNCTION()
    private void Step_Take(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Slot.Get_ActionFor(_Carrier) == EMars_CargoSlot_Action::Take, "an empty-handed carrier reads Take on the occupied slot");
        _SlotVisualWorld = utils_world_item::Get_WorldOf(_Slot.Get_Visual(), _Slot).GetLocation();
        _HandPhases.Empty();

        auto Target = _Slot.Get_Interactable().Get_InteractTarget(GameplayTags::InteractionChannel_Mars_Use);
        Target.Request_StartInteraction(FCk_Try_InteractTarget_StartInteraction(_Carrier, _Carrier));
    }

    UFUNCTION()
    private void Check_TakeDone(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        Sample();

        const auto Gripped = _HandPhases.Contains(EMars_FPHands_Phase::Grip);
        const auto AtRest = _Hands.Get_Phase() == EMars_FPHands_Phase::None;
        const auto Held = _HeldItem.Get_CurrentItem() == _Items[0];

        auto Settled = false;
        auto Node = _HeldItem.Get_PresentationEntity().As_SceneNode(ECk_SanityCheck::UnChecked);
        if (Held && ck::IsValid(Node))
        {
            const auto HeldOffset = _Items[0].Get_Presentation().Mounting.HeldOffset.GetLocation();
            Settled = utils_scene_node::Get_Offset(Node).GetLocation().Equals(HeldOffset, k_SettleCm);
        }

        auto Res = OutResult;
        Res.Set(Gripped && AtRest && Held && Settled);
    }

    private void Sample()
    {
        ++_Polls;
        const auto Gripped = _HandPhases.Contains(EMars_FPHands_Phase::Grip);
        const auto SlotDrawn = Get_HasDrawnMesh(_Slot.Get_Visual());
        const auto VisualEntity = _HeldItem.Get_PresentationEntity();
        const auto VisualDrawn = Get_HasDrawnMesh(VisualEntity);

        if (SlotDrawn == false && VisualDrawn == false)
        { ++_BlinkPolls; }

        if (SlotDrawn && VisualDrawn)
        { ++_DoublePolls; }

        if (Gripped == false && SlotDrawn == false)
        { ++_SlotGonePollsBeforeGrip; }

        if (Gripped == false && VisualDrawn)
        { ++_VisualPollsBeforeGrip; }

        if (VisualDrawn == false)
        { return; }

        ++_VisualPolls;
        const auto VisualWorld = utils_transform::Get_EntityCurrentTransform(VisualEntity.As_Transform()).GetLocation();
        if (_FirstVisualWorld.IsSet() == false)
        { _FirstVisualWorld = TOptional<FVector>(VisualWorld); }

        if (_LastVisualWorld.IsSet())
        { _MaxStepCm = Math::Max(_MaxStepCm, _LastVisualWorld.GetValue().Distance(VisualWorld)); }

        _LastVisualWorld = TOptional<FVector>(VisualWorld);
    }

    UFUNCTION()
    private void Step_AssertRodeHome(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_VisualPolls > 1, f"the held visual was sampled over several polls (got {_VisualPolls} of {_Polls})");
        Assert_Equals_Int(_SlotGonePollsBeforeGrip, 0, "before the Grip the rock stayed drawn in the slot");
        Assert_Equals_Int(_VisualPollsBeforeGrip, 0, "before the Grip no held visual existed");
        Assert_Equals_Int(_BlinkPolls, 0, "no poll of the take drew neither the slot's rock nor the held visual");
        Assert_Equals_Int(_DoublePolls, 0, "no poll of the take drew both");

        const auto FirstVisual = _FirstVisualWorld.IsSet() ? _FirstVisualWorld.GetValue() : FVector::ZeroVector;
        Assert_True(FirstVisual.Equals(_SlotVisualWorld, 5.0), f"the held visual started where the cargo visual was {_SlotVisualWorld} (got {FirstVisual})");

        const auto HandWorld = utils_transform::Get_EntityCurrentTransform(_HandNode);
        const auto HoldWorld = (_Items[0].Get_Presentation().Mounting.HeldOffset * HandWorld).GetLocation();
        const auto Travel = _SlotVisualWorld.Distance(HoldWorld);
        Assert_True(_MaxStepCm < Travel * k_MaxStepFraction,
            f"the visual's largest single-poll step ({_MaxStepCm} cm) is a fraction of the {Travel} cm from the slot to the hold: a ride, not a jump");
        Assert_True(ck::Is_NOT_Valid(_Slot.Get_Item()) && ck::Is_NOT_Valid(_Slot.Get_Visual()), "the slot is empty and draws nothing");
    }
}
