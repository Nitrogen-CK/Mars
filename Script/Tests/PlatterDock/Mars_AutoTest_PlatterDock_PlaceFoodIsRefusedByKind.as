// A dock judges the food a focuser would place by the piece it would add, and a press on the refusing dock does nothing. An
// empty large platter docks on a meat-only dock ("Meat only"); the carrier picks a mushroom slice up into its bag slot and
// focuses the dock: the dock refuses the piece (Blocked_Policy, KindRejected, as the pure Get_PieceRefusal says), the
// prompt reads "Meat only" and the dock's target is disabled. The carrier then starts an interaction on that disabled
// target, as a press on a stale best target would: the framework refuses it (no interaction begins), the slice stays in
// the hands and the platter's books are unchanged. Isolated origin (28000, -23000, -30000).
class UMars_AutoTest_PlatterDock_PlaceFoodIsRefusedByKind : UMars_AutoTestRig_PlatterDock
{
    default _TimeoutSeconds = 30.0f;

    private const FVector k_Origin = FVector(28000.0, -23000.0, -30000.0);
    private const FVector k_FoodOffset = FVector(200.0, 200.0, 0.0);
    // Item constructions, mount arrivals and the gloves' reaches outrun the default poll budget at lane frame rate.
    private const int32 k_SlowPolls = 900;

    private FCk_Handle_PlatterDock _Dock;
    private FCk_Handle _FoodEntity;
    private FCk_Handle_WorldItem _Food;
    private FCk_Handle_FoodPiece _Slice;

    // What the carrier held, and the docked platter's books, when it pressed on the disabled dock.
    private FCk_Handle_Item _HeldBeforePress;
    private int32 _PlatterHeldBeforePress = 0;
    private int32 _PlatterPendingBeforePress = 0;
    // Every interaction the dock's target began since the press.
    private int32 _InteractionsSincePress = 0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Add_CarrierBodyWithBack(InHandle, k_Origin);
        Add_Hotbar(_Carrier, 1);
        _HeldItem = utils_held_item::Add(_Carrier);
        Add_CarrierHands();

        auto Root = Build_StationRoot(InHandle, k_Origin);
        auto Spec = Make_DockSpec(Make_Policy(TOptional<FGameplayTag>(GameplayTags::Food_Meat), true),
            FTransform(FRotator::ZeroRotator, FVector(0.0, 60.0, 70.0)), "searing input");
        Spec.KindRejectedText = FText::FromString("Meat only");
        _Dock = Build_Dock(Root, Spec);
        Spawn_Platter(InHandle, FMars_Platter_SpawnSpec(FTransform(FRotator::ZeroRotator, k_Origin + FVector(200.0, 0.0, 0.0)),
            mars_items::Platter_Large()));

        Spawn_FoodFloor(InHandle, k_Origin + k_FoodOffset);
        auto SpawnParams = UMars_FoodItem_EntityScript::Params();
        SpawnParams.SpawnTransform = FTransform(FRotator::ZeroRotator, k_Origin + k_FoodOffset + FVector(0.0, 0.0, 5.0));
        SpawnParams.Definition = utils_held_item::Make_DefinitionSoft(mars_items::Food_MushroomSlice());
        SpawnParams.Mode = EMars_WorldItem_Mode::World;

        // A piece outlives its spawner: under the world's transient entity, tracked for cleanup.
        auto PieceOwner = ck::TransientEntity();
        _FoodEntity = utils_entity_script::Request_SpawnEntity(PieceOwner, UMars_FoodItem_EntityScript, SpawnParams).Get_EntityUnderConstruction();
        Track_ForCleanup(_FoodEntity);

        Add_Step_WaitUntil("the platter is constructed", n"Check_PlattersConstructed", k_SlowPolls, 0);
        Add_Step_WaitUntil("the food item is constructed", n"Check_FoodConstructed", k_SlowPolls, 0);
        Add_Step("dock the empty platter", n"Step_Dock");
        Add_Step_WaitUntil("the empty platter arrived on the dock", n"Check_Arrived", k_SlowPolls, 0);
        Add_Step("the carrier focuses the slice's pickup", n"Step_FocusFood");
        Add_Step_WaitUntil("the slice's target enters Focused", n"Check_AwaitedFocus", 0, 0);
        Add_Step("the carrier picks the slice up", n"Step_PickUpFood");
        Add_Step_WaitUntil("the slice is Held", n"Check_FoodHeld", k_SlowPolls, 0);
        Add_Step("the carrier unfocuses the slice and focuses the dock", n"Step_FocusDock");
        Add_Step_WaitUntil("the dock's targets enter Focused", n"Check_AwaitedFocus", 0, 0);
        Add_Step_WaitUntil("the dock's prompt follows the focuser", n"Check_DockPromptWritten", 0, 0);
        Add_Step("the dock refuses the slice by its kind", n"Step_AssertRefused");
        Add_Step("the carrier starts an interaction on the dock's disabled target, as a stale best target would", n"Step_PressTheDisabledDock");
        Add_Step_WaitSeconds("an interaction the press began would show here", 0.25f);
        Add_Step("the framework refused the press: the slice stays in the hands and the platter's books are unchanged", n"Step_AssertPressRefused");
        Run_Steps(InHandle);
    }

    // A static slab whose top is at InTop.
    private void Spawn_FoodFloor(FCk_Handle InOwner, FVector InTop)
    {
        auto Owner = InOwner;
        auto Floor = utils_entity_lifetime::Request_CreateEntity(Owner);
        utils_transform::Add(Floor, FTransform(FRotator::ZeroRotator, InTop - FVector(0.0, 0.0, 1.0)), ECk_Replication::DoesNotReplicate);
        auto Shape = FCk_Jolt_ShapeDimensions(ECk_Jolt_ShapeType::Box);
        Shape.Set_HalfExtents(FVector(60.0, 60.0, 1.0));
        auto FloorSpec = FCk_JoltBody_Spec(ECk_JoltBody_ShapeSource::ExplicitShape);
        FloorSpec.Set_ShapeDimensions(Shape);
        FloorSpec.Set_MotionType(ECk_MotionType::Static);
        FloorSpec.Set_CollisionProfileName(n"BlockAll");
        utils_jolt_body::Add(Floor, FloorSpec);
    }

    UFUNCTION()
    private void Check_FoodConstructed(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto IsConstructed = ck::IsValid(_FoodEntity) && _FoodEntity.Is_WorldItem() && ck::IsValid(_FoodEntity.As_WorldItem().Get_HeldItem());
        if (IsConstructed && ck::Is_NOT_Valid(_Food))
        {
            _Food = _FoodEntity.As_WorldItem();
            _Slice = _FoodEntity.As_FoodPiece();
        }

        auto Res = OutResult;
        Res.Set(IsConstructed);
    }

    UFUNCTION()
    private void Step_Dock(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Dock(_Dock, _PlatterItems[0]);
    }

    UFUNCTION()
    private void Check_Arrived(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Dock.Get_HasArrived() && _Dock.Get_Platter() == _Platters[0]);
    }

    UFUNCTION()
    private void Step_FocusFood(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Pickup = _Food.Get_Pickup();
        Pickup.Request_Focus(FMars_Request_Interactable_Focus(_Carrier));
        Await_FocusOf(Pickup);
    }

    UFUNCTION()
    private void Step_PickUpFood(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Pickup = _Food.Get_Pickup();
        auto Target = Pickup.Get_InteractTarget(GameplayTags::InteractionChannel_Mars_Use);
        Target.Request_StartInteraction(FCk_Try_InteractTarget_StartInteraction(_Carrier, _Carrier));
    }

    UFUNCTION()
    private void Check_FoodHeld(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Food.Get_Mount() == EMars_WorldItem_Mount::Held && Get_MountParent(_Food) == _HandNode);
    }

    UFUNCTION()
    private void Step_FocusDock(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto FoodPickup = _Food.Get_Pickup();
        FoodPickup.Request_Unfocus(FMars_Request_Interactable_Unfocus(_Carrier));

        auto DockInteractable = _Dock.Get_Interactable();
        DockInteractable.Request_Focus(FMars_Request_Interactable_Focus(_Carrier));
        Await_FocusOf(DockInteractable);
    }

    UFUNCTION()
    private void Step_AssertRefused(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Action = _Dock.Get_ActionFor(_Carrier);
        Assert_True(Action == EMars_PlatterDock_Action::Blocked_Policy, f"Get_ActionFor(carrier holding a mushroom) on a meat dock (got [{Action :n}])");

        const auto Refusal = _Dock.TryGet_Refusal(_Carrier);
        Assert_True(Refusal.IsSet() && Refusal.GetValue() == EMars_PlatterDock_Refusal::KindRejected, "the dock refuses the slice for its kind");

        const auto PieceRefusal = utils_platter_dock::Get_PieceRefusal(_Dock.Get_Spec(), _Platters[0], _Slice);
        Assert_True(PieceRefusal.IsSet() && PieceRefusal.GetValue() == EMars_PlatterDock_Refusal::KindRejected, "the pure rule agrees");

        const auto Target = Get_DockTarget();
        Assert_Equals_String(Target.As_InteractPrompt().Get_PromptText().ToString(), "Meat only", "the prompt gives the dock's reason");
    }

    UFUNCTION()
    private void Step_PressTheDisabledDock(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Target = Get_DockTarget();
        Assert_True(utils_interact_target::Get_Enabled(Target) == ECk_EnableDisable::Disable, "the dock's target is disabled before the press");

        _HeldBeforePress = _HeldItem.Get_CurrentItem();
        Assert_True(ck::IsValid(_HeldBeforePress) && _Hotbar.Get_ItemAt(0) == _HeldBeforePress, "the carrier holds the slice from its bag slot before the press");
        _PlatterHeldBeforePress = _Platters[0].Get_HeldCount();
        _PlatterPendingBeforePress = _Platters[0].Get_PendingCount();

        Target.BindTo_OnNewInteraction(FCk_Delegate_InteractTarget_OnNewInteraction(this, n"OnDockTargetNewInteraction"));
        Target.Request_StartInteraction(FCk_Try_InteractTarget_StartInteraction(_Carrier, _Carrier));
    }

    UFUNCTION()
    private void Step_AssertPressRefused(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Target = Get_DockTarget();
        Assert_Equals_Int(_InteractionsSincePress, 0, "the dock's disabled target began no interaction");
        Assert_True(ck::Is_NOT_Valid(utils_interact_target::TryGet_Interaction(Target, _Carrier)), "the carrier has no interaction on the dock's target");

        Assert_True(_HeldItem.Get_CurrentItem() == _HeldBeforePress, "the carrier still holds the slice");
        Assert_True(_Hotbar.Get_ItemAt(0) == _HeldBeforePress, "the bag slot still holds the slice");
        Assert_True(_Food.Get_Mount() == EMars_WorldItem_Mount::Held, "the slice is still Held");

        Assert_Equals_Int(_Platters[0].Get_HeldCount(), _PlatterHeldBeforePress, "the docked platter holds what it held before the press");
        Assert_Equals_Int(_Platters[0].Get_PendingCount(), _PlatterPendingBeforePress, "nothing waits to drop on the docked platter");
        Assert_Equals_Int(_Platters[0].Get_Occupancy(), 0, "the docked platter is empty");
        Assert_True(ck::Is_NOT_Valid(_Slice.TryGet_Platter()), "the slice is on no platter's books");
    }

    UFUNCTION()
    private void OnDockTargetNewInteraction(FCk_Handle_InteractTarget InTarget, FCk_Handle_Interaction InInteraction)
    {
        ++_InteractionsSincePress;
    }

    // The dock's prompt left its placeholder ("Dock", utils_platter_dock::DoCreate_Interactable): the dock's prompt processor
    // wrote what the focuser can do there.
    UFUNCTION()
    private void Check_DockPromptWritten(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_DockTarget().As_InteractPrompt().Get_PromptText().ToString() != "Dock");
    }

    private FCk_Handle_InteractTarget Get_DockTarget() const
    {
        auto DockInteractable = _Dock.Get_Interactable();
        return DockInteractable.Get_InteractTarget(GameplayTags::InteractionChannel_Mars_Use);
    }
}
