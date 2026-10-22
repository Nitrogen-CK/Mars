// The real Mushroom and real Pocket1 of a supported, side-resting world pack.
// Stowing through the normal inventory request must not turn its mounted body into a motor.
class UMars_AutoTest_CargoSlot_FoodDoesNotDriveADroppedPack : UMars_AutoTestRig_Carrier
{
    default _TimeoutSeconds = 30.0f;

    private const FVector k_Origin = FVector(32000.0, -35000.0, -32000.0);
    private FCk_Handle _PackEntity;
    private FCk_Handle _FoodEntity;
    private FCk_Handle_WorldItem _Pack;
    private FCk_Handle_WorldItem _Food;
    private FCk_Handle_CargoSlot _Slot;
    private FCk_Handle_Item _FoodItem;
    private FVector _Baseline;
    private float64 _MaxDisplacement = 0.0;
    private float64 _MaxSpeed = 0.0;
    private bool _Watching = false;
    private int32 _FoodContacts = 0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Add_CarrierBodyWithBack(InHandle, k_Origin);
        Add_Hotbar(_Carrier, 1);
        _HeldItem = utils_held_item::Add(_Carrier);
        Spawn_StaticSlab(InHandle, k_Origin + FVector(260.0, -150.0, -10.0), FVector(250.0, 250.0, 10.0));

        auto Params = UMars_Backpack_EntityScript::Params();
        Params.Definition = mars_items::Backpack();
        Params.Mode = EMars_WorldItem_Mode::World;
        Params.SpawnTransform = FTransform(FRotator(90.0, 0.0, 0.0), k_Origin + FVector(200.0, -150.0, 50.0));
        _PackEntity = utils_entity_script::Request_SpawnEntity(InHandle, UMars_Backpack_EntityScript, Params).Get_EntityUnderConstruction();
        _FoodEntity = Spawn_FoodItemOnFloor(InHandle, mars_items::Food_Mushroom(), k_Origin + FVector(200.0, 250.0, 0.0));
        utils_timer::Create_Tick(InHandle, FCk_Delegate_Timer(this, n"OnWatch"));

        Add_Step_WaitUntil("real pack and Mushroom bodies are constructed", n"Check_Ready", 900, 0);
        Add_Step("pick the actual Mushroom into the selected bag slot", n"Step_PickFood");
        Add_Step_WaitUntil("food is held and its arrival settled", n"Check_Held", 900, 0);
        Add_Step_WaitUntil("world pack rests asleep on its floor before loading", n"Check_PackAsleep", 900, 0);
        Add_Step("record the resting body and stow through Pocket1", n"Step_Stow");
        Add_Step_WaitUntil("same food is mounted on the real cargo node", n"Check_Loaded", 900, 0);
        Add_Step_WaitSeconds("observe a full second after the mount settles", 1.0f);
        Add_Step("loaded pack did not move; pick up that loaded pack", n"Step_AssertAndWear");
        Add_Step_WaitUntil("same loaded pack is worn and settled", n"Check_Worn", 900, 0);
        Add_Step("take the same Mushroom from Pocket1", n"Step_Take");
        Add_Step_WaitUntil("Mushroom is held again", n"Check_Held", 900, 0);
        Add_Step("cargo is empty after taking the same food", n"Step_AssertTaken");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Check_Ready(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        _Pack = TryGet_ConstructedWorldItem(_PackEntity);
        _Food = TryGet_ConstructedWorldItem(_FoodEntity);
        bool Ready = ck::IsValid(_Pack) && ck::IsValid(_Food);
        if (Ready)
        {
            Ready = utils_jolt_body::Get_IsBodyAdded(_Pack.Get_Body()) && utils_jolt_body::Get_IsBodyAdded(_Food.Get_Body());
            if (Ready && ck::Is_NOT_Valid(_Slot))
            {
                _Slot = _PackEntity.As_Backpack().Get_CargoSlot(0);
                _FoodItem = _Food.Get_HeldItem();
                utils_jolt_body::BindTo_OnJoltBodyContactAdded(_Pack.Get_Body(), FCk_Delegate_JoltBody_OnContact(this, n"OnPackContact"));
            }
        }
        auto Result = OutResult;
        Result.Set(Ready);
    }

    UFUNCTION()
    private void Step_PickFood(FCk_Handle InHandle, FInstancedStruct InPayload)
    { StowFrom(_Food.Get_Holder()); }

    UFUNCTION()
    private void Check_Held(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_Food.Get_Mount() == EMars_WorldItem_Mount::Held && _Food.Get_IsSettled()
            && _HeldItem.Get_CurrentItem() == _FoodItem);
    }

    UFUNCTION()
    private void Check_PackAsleep(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_Pack.Get_Mount() == EMars_WorldItem_Mount::World
            && utils_jolt_body::Get_SleepState(_Pack.Get_Body()) == ECk_Jolt_SleepState::Asleep
            && utils_jolt_body::Get_LinearVelocity(_Pack.Get_Body()).Size() < 0.1);
    }

    UFUNCTION()
    private void Step_Stow(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Baseline = utils_transform::Get_EntityCurrentLocation(_PackEntity.As_Transform());
        Assert_True(_Slot.Get_ActionFor(_Carrier) == EMars_CargoSlot_Action::Stow, "real Pocket1 offers Stow to the food holder");
        _FoodContacts = 0;
        _Watching = true;
        _Slot.Request_Stow(FMars_Request_CargoSlot_Stow(_FoodItem));
    }

    UFUNCTION()
    private void Check_Loaded(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        FCk_Handle SlotEntity = _Slot;
        auto Result = OutResult;
        Result.Set(_Slot.Get_Item() == _FoodItem && _Food.Get_Mount() == EMars_WorldItem_Mount::Carried
            && _Food.Get_Carrier() == SlotEntity && _Food.Get_IsSettled());
    }

    UFUNCTION()
    private void OnWatch(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        if (IsFinished() || _Watching == false) { return; }
        _MaxDisplacement = Math::Max(_MaxDisplacement, (utils_transform::Get_EntityCurrentLocation(_PackEntity.As_Transform()) - _Baseline).Size());
        _MaxSpeed = Math::Max(_MaxSpeed, float64(utils_jolt_body::Get_LinearVelocity(_Pack.Get_Body()).Size()));
    }

    UFUNCTION()
    private void OnPackContact(FCk_Handle_JoltBody InBody, FCk_JoltBody_Payload_OnContact InPayload)
    {
        if (InPayload.Get_OtherEntity() != _FoodEntity) { return; }
        _FoodContacts += 1;
        Assert_True(InPayload.Get_OtherIsSensor() == ECk_EnableDisable::Disable, "mounted food remains an ordinary body, not a global sensor");
    }

    UFUNCTION()
    private void Step_AssertAndWear(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Watching = false;
        Assert_True(_Food.Get_AppliedBodyProfile() == TOptional<FName>(constants_world_item::k_MountedBodyProfile),
            "ordinary mounted cargo acknowledged its default QueryOnly profile");
        Log(f"[GroundPack] contacts={_FoodContacts} maxDisplacement={_MaxDisplacement}cm limit<1 maxSpeed={_MaxSpeed}cm/s limit<5");
        Assert_True(_FoodContacts > 0, "actual food/pack pair must contact, so a missing overlap cannot make this pass");
        Assert_True(_MaxDisplacement < 1.0, f"cargo must not drive the supported world pack (max {_MaxDisplacement} cm)");
        Assert_True(_MaxSpeed < 5.0, f"cargo must not accelerate the world pack (max {_MaxSpeed} cm/s)");
        Assert_True(utils_jolt_body::Get_MotionType(_Pack.Get_Body()) == ECk_MotionType::Dynamic, "the world pack stays Dynamic");
        Assert_True(utils_jolt_body::Get_MotionType(_Food.Get_Body()) == ECk_MotionType::Kinematic, "mounted food stays Kinematic");
        StowFrom(_Pack.Get_Holder());
    }

    UFUNCTION()
    private void Check_Worn(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_Hotbar.Get_IsWearingBackpack() && _Pack.Get_Mount() == EMars_WorldItem_Mount::Carried
            && _Pack.Get_IsSettled() && _Slot.Get_Item() == _FoodItem);
    }

    UFUNCTION()
    private void Step_Take(FCk_Handle InHandle, FInstancedStruct InPayload)
    { _Slot.Request_Take(FMars_Request_CargoSlot_Take(_FoodItem, _Hotbar.TryGet_TakeTarget(_FoodItem))); }

    UFUNCTION()
    private void Step_AssertTaken(FCk_Handle InHandle, FInstancedStruct InPayload)
    { Assert_True(_Slot.Get_IsOccupied() == false && _Hotbar.Get_ItemAt(0) == _FoodItem, "same food returns to the bag and empties Pocket1"); }
}
