// A dock judges the food a focuser would place by the piece it would add. An empty large platter docks on a meat-only dock
// ("Meat only"); the carrier picks a mushroom slice up into its bag slot and focuses the dock: the dock refuses the piece
// (Blocked_Policy, KindRejected, as the pure Get_PieceRefusal says), the prompt reads "Meat only" and the dock's target
// is disabled; the platter stays empty and the slice stays in the hands. Isolated origin (28000, -23000, -30000).
class UMars_AutoTest_PlatterDock_PlaceFoodIsRefusedByKind : UMars_AutoTestRig_PlatterDock
{
    default _TimeoutSeconds = 30.0f;

    private const FVector k_Origin = FVector(28000.0, -23000.0, -30000.0);
    private const FVector k_FoodOffset = FVector(200.0, 200.0, 0.0);

    private FCk_Handle_PlatterDock _Dock;
    private FCk_Handle _FoodEntity;
    private FCk_Handle_WorldItem _Food;
    private FCk_Handle_FoodPiece _Slice;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Add_CarrierBodyWithBack(InHandle, k_Origin);
        Add_Hotbar(_Carrier, 1);
        _HeldItem = utils_held_item::Add(_Carrier);
        Add_CarrierHands();
        Bind_PushSelection();

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

        Add_Step_WaitUntil("the platter is constructed", n"Check_PlattersConstructed", 0, 10.0f);
        Add_Step_WaitUntil("the food item is constructed", n"Check_FoodConstructed", 0, 10.0f);
        Add_Step("dock the empty platter", n"Step_Dock");
        Add_Step_WaitUntil("the empty platter arrived on the dock", n"Check_Arrived", 0, 5.0f);
        Add_Step("the carrier focuses the slice's pickup", n"Step_FocusFood");
        Add_Step_WaitFrames("the slice's target enters Focused", 3);
        Add_Step("the carrier picks the slice up", n"Step_PickUpFood");
        Add_Step_WaitUntil("the slice is Held", n"Check_FoodHeld", 0, 5.0f);
        Add_Step("the carrier unfocuses the slice and focuses the dock", n"Step_FocusDock");
        Add_Step_WaitFrames("the dock's prompt follows the focuser", 3);
        Add_Step("the dock refuses the slice by its kind", n"Step_AssertRefused");
        Add_Step("the platter is empty and the slice stays in the hands", n"Step_AssertNothingMoved");
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
    }

    UFUNCTION()
    private void Step_AssertRefused(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Action = _Dock.Get_ActionFor(_Carrier);
        Assert_True(Action == EMars_PlatterDock_Action::Blocked_Policy, f"Get_ActionFor(carrier holding a mushroom) on a meat dock (got [{Action :n}])");

        const auto Refusal = _Dock.TryGet_Refusal(_Carrier);
        Assert_True(Refusal.IsSet() && Refusal.GetValue() == EMars_PlatterDock_Refusal::KindRejected, "the dock refuses the slice for its kind");

        const auto PieceRefusal = utils_platter_dock::Get_PieceRefusal(_Dock.Get_Spec().Policy, _Platters[0], _Slice);
        Assert_True(PieceRefusal.IsSet() && PieceRefusal.GetValue() == EMars_PlatterDock_Refusal::KindRejected, "the pure rule agrees");

        const auto Target = Get_DockTarget();
        Assert_Equals_String(Target.As_InteractPrompt().Get_PromptText().ToString(), "Meat only", "the prompt gives the dock's reason");
        Assert_True(utils_interact_target::Get_Enabled(Target) == ECk_EnableDisable::Disable, "the dock's target is disabled");
    }

    UFUNCTION()
    private void Step_AssertNothingMoved(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Platters[0].Get_Occupancy(), 0, "the docked platter is empty");
        Assert_True(_Food.Get_Mount() == EMars_WorldItem_Mount::Held, "the slice is still Held");
        Assert_True(ck::Is_NOT_Valid(_Slice.TryGet_Platter()), "the slice is on no platter's books");
    }

    private FCk_Handle_InteractTarget Get_DockTarget() const
    {
        auto DockInteractable = _Dock.Get_Interactable();
        return DockInteractable.Get_InteractTarget(GameplayTags::InteractionChannel_Mars_Use);
    }
}
