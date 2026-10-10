// The operator rig's state machine: the player's Alive mode cut down to the tasks that run without a pawn, a camera
// director or a widget. The root keeps what outlives both modes (the held-item -> gloves link and the gloves' Hands
// sub-SM, as Alive does) and a sub-SM that is the player's free-roam / station split: Roam runs the view trace -> focus and
// the Use row -> resolver intent and its interaction (as Locomotion does); Operating runs the Operating state's tasks while
// the carrier's operator holds a station. Composed from the Operating state: Grip (the station's grip interaction under
// the Operate intent), LeaveIntent (Back asks the station to release the operator) and Hints (the "leave" row on the
// carrier's action hint display). Not composed: PoseLock, which glides the operator's ACharacter to the stand (the carrier
// is no pawn), and Camera, which snaps the player viewpoint's camera director (the rig's viewpoint has none, and the task
// ensures without one).
class UMars_AutoTestState_OperatorRig : UCk_SmState_EntityScript
{
    UFUNCTION(BlueprintOverride)
    void DoDefineState(FCk_Handle_SmState_UnderConstruction& InHandle)
    {
        AddTask(InHandle, UMars_SmTask_HeldItemDrivesHands);
        AddTask(InHandle, UMars_AutoTestTask_OperatorRigModes);
        AddTask(InHandle, UMars_SmTask_HandsSubSm);
    }
}

class UMars_AutoTestTask_OperatorRigModes : UCk_SmTask_SubStateMachine
{
    default _InitialStateClass = UMars_AutoTestState_OperatorRigRoam;
    default _CompletionBehavior = ECk_SmTask_SubSm_CompletionBehavior::KeepRunning;
}

class UMars_AutoTestState_OperatorRigRoam : UCk_SmState_EntityScript
{
    UFUNCTION(BlueprintOverride)
    void DoDefineState(FCk_Handle_SmState_UnderConstruction& InHandle)
    {
        auto ToOperating = AddTransition(InHandle, UMars_AutoTestState_OperatorRigOperating);
        AddCondition(ToOperating, UMars_SmCondition_IsOperating);

        AddTask(InHandle, UMars_SmTask_InteractionFocus);
        AddTask(InHandle, UMars_SmTask_UseIntentToResolver);
    }
}

class UMars_AutoTestState_OperatorRigOperating : UCk_SmState_EntityScript
{
    UFUNCTION(BlueprintOverride)
    void DoDefineState(FCk_Handle_SmState_UnderConstruction& InHandle)
    {
        auto ToRoam = AddTransition(InHandle, UMars_AutoTestState_OperatorRigRoam);
        AddCondition(ToRoam, UMars_SmCondition_IsNotOperating);

        AddTask(InHandle, UMars_SmTask_Operating_Grip);
        AddTask(InHandle, UMars_SmTask_Operating_LeaveIntent);
        AddTask(InHandle, UMars_SmTask_Operating_Hints);
    }
}

// The operator rig: the player-path carrier (gloves, the Hands sub-SM, a Use resolver, InputIntents fed by a private key
// stack, the merged intent task, the real InteractionFocus over a rig-aimed trace) made an operator: the Operator feature,
// an action hint display, the Operate mapping on its resolver beside Use, and key rows for Back, Interact_Primary,
// Interact_Secondary and StationAddFood beside Use, composed under UMars_AutoTestState_OperatorRig. It takes a station the
// way the player does - the view on the station's Use probe, a Use press, the station's own reserve interaction - and
// leaves it with Back. The station is a bare one (Build_BareStation) or a subclass's.
UCLASS(Abstract)
class UMars_AutoTestRig_Operator : UMars_AutoTestRig_PlayerPath
{
    default _TimeoutSeconds = 30.0f;

    protected FCk_Handle_Operator _Operator;
    protected FCk_Handle_ActionHintDisplay _Display;
    protected FCk_Handle_Station _Station;
    // In arrival order, from the station's own signals.
    protected TArray<FCk_Handle> _Reserved;
    protected TArray<EMars_Station_ReleaseReason> _ReleaseReasons;

    protected void Build_Operator(FCk_Handle InHandle, FVector InOrigin)
    {
        Build_PlayerPath(InHandle, InOrigin);
        _Operator = utils_operator::Add(_Carrier);
        _Display = utils_action_hint_display::Add(_Carrier);
    }

    // A station on a root of its own at InRootLocal from the origin (no grips, no minigame), its Use interactable a
    // Kinematic probe sphere at the eye's height over the root.
    protected void Build_BareStation(FCk_Handle InHandle, FVector InRootLocal)
    {
        auto Parent = InHandle;
        auto StationEntity = utils_entity_lifetime::Request_CreateEntity(Parent);
        auto Root = utils_transform::Add(StationEntity, FTransform(FRotator::ZeroRotator, _Origin + InRootLocal), ECk_Replication::DoesNotReplicate);

        auto Probe = FMars_Interactable_ProbeInfo();
        Probe.ProbeSpec = FCk_Probe_Spec(GameplayTags::Probe_Mars_Interact);
        Probe.ProbeSpec.Set_MotionType(ECk_MotionType::Kinematic);
        Probe.ProbeShape = utils_shapes::Make_Sphere(FCk_ShapeSphere_Dimensions(20.0f));
        Probe.ProbeOffset = FTransform(FRotator::ZeroRotator, FVector(0.0, 0.0, _EyeHeight));

        auto Setup = FMars_Station_Setup();
        Setup.Probe = TOptional<FMars_Interactable_ProbeInfo>(Probe);
        Watch_Station(utils_station::Add(Root, FMars_Station_Spec(), Setup));
    }

    protected void Watch_Station(FCk_Handle_Station InStation)
    {
        _Station = InStation;
        _Station.BindTo_OnReserved(FMars_Delegate_Station_OnReserved(this, n"OnStationReserved"));
        _Station.BindTo_OnReleased(FMars_Delegate_Station_OnReleased(this, n"OnStationReleased"));
    }

    // Up to the carrier holding the station through its Use interaction, its gloves on the station's grip.
    protected void Add_Steps_TakeTheStationThroughUse()
    {
        Add_Step("turn the view onto the station's Use probe", n"Step_AimAtTheStation");
        Add_Step_WaitUntil("the carrier focuses the station", n"Check_StationFocused", 0, 0);
        Add_Step("press Use", n"Step_PressUse");
        Add_Step_WaitUntil("the station names the carrier its operator", n"Check_OperatingTheStation", 0, 0);
        Add_Step("release Use", n"Step_ReleaseUse");
        Add_Step_WaitUntil("the gloves hold the station's grip", n"Check_GlovesOnTheGrip", 0, 0);
    }

    protected FVector Get_UseProbeWorld() const
    {
        FCk_Handle Interactable = _Station.Get_Interactable();
        return utils_transform::Get_EntityCurrentTransform(Interactable.As_Transform()).GetLocation();
    }

    // The station's Use interaction from the carrier is over (it ends with the reserve's answer).
    protected bool Get_IsUseInteractionOver() const
    {
        return ck::Is_NOT_Valid(utils_interact_target::TryGet_Interaction(_Station.Get_UseTarget(), _Carrier));
    }

    protected bool Get_IsGlovesOnTheGrip() const
    {
        return _Hands.Get_Phase() == EMars_FPHands_Phase::Hold && _Hands.Get_IsReachTarget(_Station.Get_GripTarget());
    }

    protected void Press_Row(FGameplayTag InIntent)
    {
        _UseKey.Press_Row(InIntent);
    }

    protected void Release_Row(FGameplayTag InIntent)
    {
        _UseKey.Release_Row(InIntent);
    }

    protected bool Get_IsRowHeld(FGameplayTag InIntent) const
    {
        return _Intents.Get_IsIntentActive(InIntent);
    }

    // A row reading InText is on the carrier's legend.
    protected bool Get_HasHint(FString InText) const
    {
        for (auto Row : _Display.Get_VisibleHints())
        {
            if (Row.Get_Spec().Text.ToString() == InText)
            { return true; }
        }

        return false;
    }

    protected TSubclassOf<UCk_SmState_EntityScript> Get_RigStateClass() const override
    { return UMars_AutoTestState_OperatorRig; }

    protected TArray<FMars_AutoTestHelper_KeyRow> Get_ExtraKeyRows() const override
    {
        TArray<FMars_AutoTestHelper_KeyRow> Rows;
        Rows.Add(FMars_AutoTestHelper_KeyRow(EKeys::F10, GameplayTags::Mars_Intent_Back, n"BK"));
        Rows.Add(FMars_AutoTestHelper_KeyRow(EKeys::F11, GameplayTags::Mars_Intent_Interact_Primary, n"IP"));
        Rows.Add(FMars_AutoTestHelper_KeyRow(EKeys::F12, GameplayTags::Mars_Intent_Interact_Secondary, n"IS"));
        Rows.Add(FMars_AutoTestHelper_KeyRow(EKeys::F8, GameplayTags::Mars_Intent_StationAddFood, n"AF"));
        return Rows;
    }

    // The Use mapping (one target at a time: no distance sort) and the Operate mapping the player's Operating state opens
    // for a station's grip, as the player's own resolver carries it.
    protected FCk_InteractionResolver_Spec Make_ResolverSpec() const override
    {
        auto UseChannels = TArray<FGameplayTag>();
        UseChannels.Add(GameplayTags::InteractionChannel_Mars_Use);
        auto UseMapping = FCk_InteractionResolver_IntentChannelMapping(GameplayTags::InteractionIntent_Mars_Use, UseChannels);
        UseMapping.Set_DistanceSorting(ECk_InteractionResolver_DistanceSorting::Disabled);

        auto OperateChannels = TArray<FGameplayTag>();
        OperateChannels.Add(GameplayTags::InteractionChannel_Mars_Operate);

        auto Mappings = TArray<FCk_InteractionResolver_IntentChannelMapping>();
        Mappings.Add(UseMapping);
        Mappings.Add(FCk_InteractionResolver_IntentChannelMapping(GameplayTags::InteractionIntent_Mars_Operate, OperateChannels));
        return FCk_InteractionResolver_Spec(Mappings);
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Steps
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    protected void Step_AimAtTheStation(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Aim_ViewAt(Get_UseProbeWorld());
    }

    UFUNCTION()
    protected void Check_StationFocused(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Station.Get_Interactable().Get_CurrentFocuser() == _Carrier
            && utils_state_machine::Get_CurrentStateClass(_Station.Get_UseTarget().As_StateMachine()) == UMars_SmState_Interactable_Focused);
    }

    UFUNCTION()
    protected void Check_OperatingTheStation(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Station.Get_IsOperatedBy(_Carrier) && _Operator.Get_Station() == _Station);
    }

    UFUNCTION()
    protected void Check_GlovesOnTheGrip(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_IsGlovesOnTheGrip());
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Handlers
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void OnStationReserved(FCk_Handle_Station InStation, FCk_Handle InOperator)
    {
        _Reserved.Add(InOperator);
    }

    UFUNCTION()
    private void OnStationReleased(FCk_Handle_Station InStation, FCk_Handle InOperator, EMars_Station_ReleaseReason InReason)
    {
        _ReleaseReasons.Add(InReason);
    }
}

// The operator rig at a real heat station: the searing or fry station spawned through its entity script with its two
// platter docks, World-mode platters lying on floors beside it until a test docks them, and the carrier standing in front
// of it. The station, the platters, the boxes, docking and readiness are the shared heat-station fixture's
// (UMars_AutoTestHelper_HeatStation), as UMars_AutoTestRig_HeatStation's are. The handlers record the feed's settles and
// the kernel's take-outs.
UCLASS(Abstract)
class UMars_AutoTestRig_HeatOperator : UMars_AutoTestRig_Operator
{
    default _TimeoutSeconds = 60.0f;

    protected EMars_AutoTest_HeatStation _Kind = EMars_AutoTest_HeatStation::Searing;
    protected FVector _StationOrigin;
    protected FCk_Handle_CookingFeed _Feed;
    // Invalid on the fry station.
    protected FCk_Handle_Searing _Searing;
    // Invalid on the searing station.
    protected FCk_Handle_Fry _Fry;
    protected FCk_Handle_PlatterDock _InputDock;
    protected FCk_Handle_PlatterDock _OutputDock;
    protected TArray<EMars_CookingFeed_Settle> _Settles;
    protected TArray<FCk_Handle_FoodPiece> _TakenOut;

    private UMars_AutoTestHelper_HeatStation _Fixture;

    // The real InKind station at InStationOrigin with the feed's default timing; the carrier stands at InCarrierLocal from
    // the station's origin, facing it.
    protected void Build_HeatOperator(FCk_Handle InHandle, EMars_AutoTest_HeatStation InKind, FVector InStationOrigin, FVector InCarrierLocal)
    {
        _Kind = InKind;
        _StationOrigin = InStationOrigin;
        Build_Operator(InHandle, InStationOrigin + InCarrierLocal);
        _Fixture = Cast<UMars_AutoTestHelper_HeatStation>(NewObject(this, UMars_AutoTestHelper_HeatStation));

        auto Pending = FCk_Handle_PendingEntityScript();
        if (InKind == EMars_AutoTest_HeatStation::Searing)
        { Pending = _Fixture.Spawn_Searing(InHandle, InStationOrigin, FMars_CookingFeed_TimingSpec()); }
        else
        { Pending = _Fixture.Spawn_Fry(InHandle, InStationOrigin, FMars_CookingFeed_TimingSpec()); }

        utils_pending_entity_script::Promise_OnConstructed(Pending, FCk_Delegate_EntityScript_Constructed(this, n"OnHeatStationConstructed"));
    }

    // A large platter lying on a floor beside the station at InOffset from its origin, with InFoodItem's whole joint loaded
    // onto it (null = empty); under construction until Get_IsPlatterReady says otherwise.
    protected FCk_Handle Spawn_Platter(FCk_Handle InHandle, FVector InOffset, UCk_InventoryItem_Definition InFoodItem)
    {
        auto PlatterEntity = _Fixture.Spawn_EmptyPlatter(InHandle, _StationOrigin + InOffset, mars_items::Platter_Large());
        if (ck::IsValid(InFoodItem))
        { Track_ForCleanup(_Fixture.Spawn_FoodOnto(PlatterEntity, InFoodItem, _StationOrigin + InOffset + FVector(0.0, 0.0, 60.0))); }

        return PlatterEntity;
    }

    // An empty InPlatterItem platter lying on a floor beside the station at InOffset from its origin.
    protected FCk_Handle Spawn_EmptyPlatterOf(FCk_Handle InHandle, FVector InOffset, UCk_InventoryItem_Definition InPlatterItem)
    {
        return _Fixture.Spawn_EmptyPlatter(InHandle, _StationOrigin + InOffset, InPlatterItem);
    }

    // The FoodPiece rig's box fixture with InKind and no definition, under the world's transient entity, tracked for cleanup.
    protected FCk_Handle_FoodPiece Build_Box(FTransform InWorld, FGameplayTag InKind)
    {
        const auto Box = _Fixture.Build_Box(InWorld, InKind);
        FCk_Handle BoxEntity = Box;
        Track_ForCleanup(BoxEntity);
        return Box;
    }

    // Constructed (a World-mode platter whose holder holds its item) with InHeld pieces landed on it.
    protected bool Get_IsPlatterReady(FCk_Handle InEntity, int32 InHeld) const
    {
        return _Fixture.Get_IsPlatterReady(InEntity, InHeld);
    }

    // Every piece a platter brings lives under the world's transient entity: tracked for cleanup.
    protected void Track_Held(FCk_Handle InPlatterEntity)
    {
        for (const auto& Piece : InPlatterEntity.As_Platter().Get_Held())
        { Track_ForCleanup(Piece); }
    }

    protected void Dock(FCk_Handle_PlatterDock InDock, FCk_Handle InPlatterEntity)
    {
        _Fixture.Dock(InDock, InPlatterEntity);
    }

    // Docked on InDock and no longer lerping onto it.
    protected bool Get_IsDocked(FCk_Handle_PlatterDock InDock, FCk_Handle InPlatterEntity) const
    {
        return _Fixture.Get_IsDocked(InDock, InPlatterEntity);
    }

    // The kernel's admitted pieces, in admission order.
    protected TArray<FMars_CookingFeed_PieceId> Get_PieceIds() const
    {
        if (_Kind == EMars_AutoTest_HeatStation::Searing)
        { return _Searing.Get_PieceIds(); }

        return _Fry.Get_PieceIds();
    }

    protected bool Get_IsStationOperated() const
    {
        return _Fixture.Get_IsOperated(_Station, _Kind);
    }

    protected int32 Get_SettleCount(EMars_CookingFeed_Settle InSettle) const
    {
        auto Count = 0;
        for (const auto& Settle : _Settles)
        {
            if (Settle == InSettle)
            { ++Count; }
        }

        return Count;
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Checks
    //----------------------------------------------------------------------------------------------------------------------

    // The kernel, the feed and both docks are composed and the kernel's static furniture is in the simulation.
    UFUNCTION()
    protected void Check_HeatStationReady(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Fixture.Get_IsStationReady(_Station));
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Handlers
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void OnHeatStationConstructed(FCk_Handle_EntityScript InEntityScriptHandle)
    {
        // Outside the test's own lifetime subtree: the runner's cascade would leave the station alive into later tests.
        Track_ForCleanup(InEntityScriptHandle);
        Watch_Station(InEntityScriptHandle.As_Station());
        _Feed = InEntityScriptHandle.As_CookingFeed();
        _Searing = InEntityScriptHandle.As_Searing(ECk_SanityCheck::UnChecked);
        _Fry = InEntityScriptHandle.As_Fry(ECk_SanityCheck::UnChecked);
        _InputDock = utils_platter_dock::Find_OnStation(InEntityScriptHandle, EMars_PlatterDock_Role::Input);
        _OutputDock = utils_platter_dock::Find_OnStation(InEntityScriptHandle, EMars_PlatterDock_Role::Output);

        _Feed.BindTo_OnTransferSettled(FMars_Delegate_CookingFeed_OnTransferSettled(this, n"OnHeatTransferSettled"));
        if (ck::IsValid(_Searing))
        { _Searing.BindTo_OnPieceTakenOut(FMars_Delegate_Searing_OnPieceTakenOut(this, n"OnSearingTakenOut")); }

        if (ck::IsValid(_Fry))
        { _Fry.BindTo_OnPieceTakenOut(FMars_Delegate_Fry_OnPieceTakenOut(this, n"OnFryTakenOut")); }
    }

    UFUNCTION()
    private void OnHeatTransferSettled(FCk_Handle_CookingFeed InFeed, FMars_CookingFeed_PieceId InPieceId, EMars_CookingFeed_Settle InSettle)
    {
        _Settles.Add(InSettle);
    }

    UFUNCTION()
    private void OnSearingTakenOut(FCk_Handle_Searing InSearing, FMars_CookingFeed_PieceId InPieceId, FCk_Handle_FoodPiece InPiece)
    {
        _TakenOut.Add(InPiece);
    }

    UFUNCTION()
    private void OnFryTakenOut(FCk_Handle_Fry InFry, FMars_CookingFeed_PieceId InPieceId, FCk_Handle_FoodPiece InPiece)
    {
        _TakenOut.Add(InPiece);
    }
}
