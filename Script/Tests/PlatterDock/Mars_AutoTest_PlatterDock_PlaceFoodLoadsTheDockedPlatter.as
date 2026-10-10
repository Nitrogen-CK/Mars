// Food goes into a docked platter by hand. An empty large platter docks on a whole-food dock; the carrier (with gloves)
// picks the meat slab up into its bag slot and focuses the dock: the dock offers PlaceFood, its prompt reads "Place Meat
// slab on prep tray" and its target is enabled. The dock's interaction has the gloves carry the slab over the docked
// platter and releases it only at their Grip (still Held the frame after the interaction began); the docked platter loads
// the joint (OnLoaded within 5 s), the joint rides the platter root and the bag slot is empty. Isolated origin
// (28000, -21000, -30000).
class UMars_AutoTest_PlatterDock_PlaceFoodLoadsTheDockedPlatter : UMars_AutoTestRig_PlatterDock
{
    default _TimeoutSeconds = 30.0f;

    private const FVector k_Origin = FVector(28000.0, -21000.0, -30000.0);
    private const FVector k_FoodOffset = FVector(200.0, 200.0, 0.0);

    private FCk_Handle_PlatterDock _Dock;
    private FCk_Handle _FoodEntity;
    private FCk_Handle_WorldItem _Food;
    private FCk_Handle_Item _FoodItem;
    private FCk_Handle_FoodPiece _Joint;

    private TArray<FCk_Handle_FoodPiece> _Loaded;
    private TArray<EMars_FPHands_Phase> _PhasesAtRelease;
    private bool _Released = false;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Add_CarrierBodyWithBack(InHandle, k_Origin);
        Add_Hotbar(_Carrier, 1);
        _HeldItem = utils_held_item::Add(_Carrier);
        Add_CarrierHands();
        Bind_PushSelection();

        auto Root = Build_StationRoot(InHandle, k_Origin);
        _Dock = Build_Dock(Root, Make_DockSpec(Make_Policy(TOptional<FGameplayTag>(), true),
            FTransform(FRotator::ZeroRotator, FVector(0.0, 60.0, 70.0)), "prep tray"));
        Spawn_Platter(InHandle, FMars_Platter_SpawnSpec(FTransform(FRotator::ZeroRotator, k_Origin + FVector(200.0, 0.0, 0.0)),
            mars_items::Platter_Large()));

        Spawn_FoodFloor(InHandle, k_Origin + k_FoodOffset);
        auto SpawnParams = UMars_FoodItem_EntityScript::Params();
        SpawnParams.SpawnTransform = FTransform(FRotator::ZeroRotator, k_Origin + k_FoodOffset + FVector(0.0, 0.0, 5.0));
        SpawnParams.Definition = utils_held_item::Make_DefinitionSoft(mars_items::Food_MeatSlab());
        SpawnParams.Mode = EMars_WorldItem_Mode::World;

        // A piece outlives its spawner: under the world's transient entity, tracked for cleanup.
        auto PieceOwner = ck::TransientEntity();
        _FoodEntity = utils_entity_script::Request_SpawnEntity(PieceOwner, UMars_FoodItem_EntityScript, SpawnParams).Get_EntityUnderConstruction();
        Track_ForCleanup(_FoodEntity);

        Add_Step_WaitUntil("the platter is constructed", n"Check_PlattersConstructed", 0, 10.0f);
        Add_Step_WaitUntil("the food item is constructed", n"Check_FoodConstructed", 0, 10.0f);
        Add_Step_WaitUntil("the gloves rest, listening for a reach", n"Check_CarrierHandsRest", 0, 5.0f);
        Add_Step("dock the empty platter", n"Step_Dock");
        Add_Step_WaitUntil("the empty platter arrived on the dock", n"Check_Arrived", 0, 5.0f);
        Add_Step("the carrier focuses the food's pickup", n"Step_FocusFood");
        Add_Step_WaitFrames("the food's target enters Focused", 3);
        Add_Step("the carrier picks the food up", n"Step_PickUpFood");
        Add_Step_WaitUntil("the food is Held", n"Check_FoodHeld", 0, 5.0f);
        Add_Step_WaitSeconds("the hold's arrival settles", 0.5f);
        Add_Step("the carrier unfocuses the food and focuses the dock", n"Step_FocusDock");
        Add_Step_WaitFrames("the dock's prompt follows the focuser", 3);
        Add_Step("the dock offers to place the food on its platter", n"Step_AssertPlaceFoodOffered");
        Add_Step("the carrier interacts with the dock", n"Step_InteractWithDock");
        Add_Step_WaitFrames("the interaction has begun", 1);
        Add_Step("the food is still in the hands", n"Step_AssertStillHeld");
        Add_Step_WaitUntil("the docked platter loaded the joint", n"Check_Loaded", 0, 5.0f);
        Add_Step_WaitFrames("the attach composes the world pose", 2);
        Add_Step("the joint rides the docked platter; it left the hands at the Grip", n"Step_AssertLoaded");
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
            _FoodItem = _Food.Get_HeldItem();
            _Joint = _FoodEntity.As_FoodPiece();
            _Food.BindTo_OnMountChanged(FMars_Delegate_WorldItem_OnMountChanged(this, n"OnFoodMountChanged"));
        }

        auto Res = OutResult;
        Res.Set(IsConstructed);
    }

    UFUNCTION()
    private void Step_Dock(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Platters[0].BindTo_OnLoaded(FMars_Delegate_Platter_OnLoaded(this, n"OnLoaded"));
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
    private void Step_AssertPlaceFoodOffered(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Action = _Dock.Get_ActionFor(_Carrier);
        Assert_True(Action == EMars_PlatterDock_Action::PlaceFood, f"Get_ActionFor(carrier holding food) on an occupied dock (got [{Action :n}])");
        Assert_False(_Dock.TryGet_Refusal(_Carrier).IsSet(), "the dock refuses nothing about the slab");

        const auto Target = Get_DockTarget();
        Assert_Equals_String(Target.As_InteractPrompt().Get_PromptText().ToString(), "Place Meat slab on prep tray", "the prompt names the food and the dock");
        Assert_True(utils_interact_target::Get_Enabled(Target) == ECk_EnableDisable::Enable, "the dock's target is enabled");
    }

    UFUNCTION()
    private void Step_InteractWithDock(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Target = Get_DockTarget();
        Target.Request_StartInteraction(FCk_Try_InteractTarget_StartInteraction(_Carrier, _Carrier));
    }

    UFUNCTION()
    private void Step_AssertStillHeld(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Food.Get_Mount() == EMars_WorldItem_Mount::Held, "the food is still Held the frame after the interaction began");
        Assert_Equals_Int(_Loaded.Num(), 0, "nothing is loaded on enter");
    }

    UFUNCTION()
    private void Check_Loaded(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Loaded.Contains(_Joint));
    }

    UFUNCTION()
    private void Step_AssertLoaded(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Platter = _Platters[0];
        Assert_True(_Dock.Get_Platter() == Platter, "the platter is still docked");
        Assert_Equals_Int(Platter.Get_HeldCount(), 1, "the docked platter holds one piece");
        Assert_True(_Joint.TryGet_Platter() == Platter, "the joint's membership names the docked platter");

        FCk_Handle JointEntity = _Joint;
        FCk_Handle PlatterEntity = Platter;
        auto JointNode = JointEntity.As_SceneNode(ECk_SanityCheck::UnChecked);
        Assert_True(ck::IsValid(JointNode) && utils_scene_node::Get_Parent(JointNode) == PlatterEntity.As_Transform(), "the joint rides the platter root");
        Assert_True(ck::Is_NOT_Valid(_Hotbar.Get_ItemAt(0)), "the bag slot is empty");
        Assert_True(_Food.Get_HeldItem() == _FoodItem, "the food item is back in its holder");

        Assert_True(_Released, "the food left the hands once");
        Assert_True(_PhasesAtRelease.Contains(EMars_FPHands_Phase::Reach), "the gloves reached before the food left them");
        Assert_True(_PhasesAtRelease.Num() > 0 && _PhasesAtRelease.Last() == EMars_FPHands_Phase::Grip, "the food left the hands in the Grip phase");
    }

    UFUNCTION()
    private void OnFoodMountChanged(FCk_Handle_WorldItem InWorldItem, EMars_WorldItem_Mount InPrev, EMars_WorldItem_Mount InNew)
    {
        if (InNew != EMars_WorldItem_Mount::World || _Released || InPrev != EMars_WorldItem_Mount::Held)
        { return; }

        _Released = true;
        _PhasesAtRelease = _HandPhases;
    }

    UFUNCTION()
    private void OnLoaded(FCk_Handle_Platter InPlatter, FCk_Handle_FoodPiece InPiece)
    {
        _Loaded.Add(InPiece);
    }

    private FCk_Handle_InteractTarget Get_DockTarget() const
    {
        auto DockInteractable = _Dock.Get_Interactable();
        return DockInteractable.Get_InteractTarget(GameplayTags::InteractionChannel_Mars_Use);
    }
}
