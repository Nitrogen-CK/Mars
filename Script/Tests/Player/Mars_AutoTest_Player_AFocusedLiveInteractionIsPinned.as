// A focused interactable with a live interaction keeps the focus. The player-path carrier looks along the floor at a lever's
// probe 150 cm out and starts pulling it (its interaction stays live). A meat slab then lands on a pedestal in front of the
// lever, across the ray: it is the nearer hit and ranks higher (a food), yet the lever keeps the focus while the pull is
// live, and the slab is never focused. Once the pull ends, the focus goes to the slab.
// Isolated origin (94000, -40000, -30000).
class UMars_AutoTest_Player_AFocusedLiveInteractionIsPinned : UMars_AutoTestRig_PlayerPath
{
    default _TimeoutSeconds = 30.0f;

    private const FVector k_Origin = FVector(94000.0, -40000.0, -30000.0);
    private const FVector k_LeverLocal = FVector(150.0, 0.0, 15.0);
    private const float32 k_LeverRadius = 8.0f;
    // A static pedestal whose top lies 1 cm under the eye's ray, between the eye and the lever.
    private const FVector k_PedestalLocal = FVector(70.0, 0.0, 7.0);
    private const FVector k_PedestalHalfExtents = FVector(15.0, 15.0, 7.0);
    private const int32 k_SettlePolls = 900;
    // Ticks the focus task gets over the slab under the ray before the focus is read.
    private const int32 k_FocusTicks = 5;

    private FCk_Handle_Interactable _Lever;
    private FCk_Handle_InteractTarget _LeverTarget;
    private FCk_Handle _SlabEntity;
    private int32 _LeverUnfocusedCount = 0;
    private bool _SlabEverFocused = false;
    private TOptional<FVector> _LastSlabLocation;
    private int32 _SlabStillPolls = 0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Build_PlayerPath(InHandle, k_Origin);
        _Lever = Build_ProbedLever(InHandle, k_Origin + k_LeverLocal, k_LeverRadius);
        _LeverTarget = _Lever.Get_AllInteractTargets()[0];
        Add_Pedestal(InHandle);

        Add_Steps_UntilReady();
        Add_Step("look at the lever", n"Step_LookAtTheLever");
        Add_Step_WaitUntil("the lever is focused", n"Check_LeverFocused", 0, 0);
        Add_Step("start pulling the lever", n"Step_StartThePull");
        Add_Step_WaitUntil("the pull is live", n"Check_PullLive", 0, 0);
        Add_Step("watch the lever's focus and drop a meat slab onto the pedestal across the ray", n"Step_WatchAndDropTheSlab");
        Add_Step_WaitUntil("the slab lies still across the ray", n"Check_SlabStillUnderTheRay", k_SettlePolls, 0);
        Add_Step_WaitFrames("the focus task ticks over the slab under the ray", k_FocusTicks);
        Add_Step("the lever kept the focus through the pull; the slab was never focused; end the pull", n"Step_AssertPinnedAndEndThePull");
        Add_Step_WaitUntil("the focus goes to the slab", n"Check_SlabFocused", 0, 0);
        Add_Step("the lever lost the focus once the pull ended", n"Step_AssertUnpinned");
        Run_Steps(InHandle);
    }

    private void Add_Pedestal(FCk_Handle InOwner)
    {
        auto Owner = InOwner;
        auto Pedestal = utils_entity_lifetime::Request_CreateEntity(Owner);
        utils_transform::Add(Pedestal, FTransform(FRotator::ZeroRotator, k_Origin + k_PedestalLocal), ECk_Replication::DoesNotReplicate);
        auto Shape = FCk_Jolt_ShapeDimensions(ECk_Jolt_ShapeType::Box);
        Shape.Set_HalfExtents(k_PedestalHalfExtents);
        auto PedestalSpec = FCk_JoltBody_Spec(ECk_JoltBody_ShapeSource::ExplicitShape);
        PedestalSpec.Set_ShapeDimensions(Shape);
        PedestalSpec.Set_MotionType(ECk_MotionType::Static);
        PedestalSpec.Set_CollisionProfileName(n"BlockAll");
        utils_jolt_body::Add(Pedestal, PedestalSpec);
    }

    UFUNCTION()
    private void Step_LookAtTheLever(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Aim_ViewAt(k_Origin + k_LeverLocal);
    }

    UFUNCTION()
    private void Check_LeverFocused(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Lever.Get_CurrentFocuser() == _Carrier);
    }

    // The lever is a pulled Control (ManuallyCompleted): its interaction stays live until it is ended.
    UFUNCTION()
    private void Step_StartThePull(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _LeverTarget.Request_StartInteraction(FCk_Try_InteractTarget_StartInteraction(_Carrier, _Carrier));
    }

    UFUNCTION()
    private void Check_PullLive(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(ck::IsValid(utils_interact_target::TryGet_Interaction(_LeverTarget, _Carrier)));
    }

    UFUNCTION()
    private void Step_WatchAndDropTheSlab(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Lever.BindTo_OnUnfocused(FMars_Delegate_Interactable_OnUnfocused(this, n"OnLeverUnfocused"));
        _SlabEntity = Spawn_Slab(k_PedestalLocal + FVector(0.0, 0.0, k_PedestalHalfExtents.Z + 15.0));
    }

    UFUNCTION()
    private void OnLeverUnfocused(FCk_Handle_Interactable InInteractable, FCk_Handle InUnfocusedBy)
    {
        ++_LeverUnfocusedCount;
    }

    // Also records whether the slab was ever focused while it settled.
    UFUNCTION()
    private void Check_SlabStillUnderTheRay(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        if (Get_IsConstructedWorldItem(_SlabEntity) == false)
        {
            Res.Set(false);
            return;
        }

        Record_SlabFocus();
        const auto Location = utils_transform::Get_EntityCurrentTransform(_SlabEntity.As_Transform()).GetLocation();
        const auto IsStill = _LastSlabLocation.IsSet() && _LastSlabLocation.GetValue().Equals(Location, 0.15);
        _SlabStillPolls = IsStill ? _SlabStillPolls + 1 : 0;
        _LastSlabLocation = TOptional<FVector>(Location);

        FCk_Handle SlabPickup = _SlabEntity.As_WorldItem().Get_Pickup();
        Res.Set(_SlabStillPolls >= 10 && Get_IsUnderTheTrace(SlabPickup));
    }

    UFUNCTION()
    private void Step_AssertPinnedAndEndThePull(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Record_SlabFocus();
        FCk_Handle LeverEntity = _Lever;
        Log(f"[PinTest] the lever is under the ray behind the slab: {Get_IsUnderTheTrace(LeverEntity)}");
        Assert_True(ck::IsValid(utils_interact_target::TryGet_Interaction(_LeverTarget, _Carrier)), "the pull is still live");
        Assert_True(_Lever.Get_CurrentFocuser() == _Carrier, "the lever keeps the focus through the pull");
        Assert_Equals_Int(_LeverUnfocusedCount, 0, "the lever was never unfocused while the slab came onto the ray");
        Assert_False(_SlabEverFocused, "the slab was never focused while the pull was live");

        _LeverTarget.Request_CancelInteraction(FCk_Request_InteractTarget_CancelInteraction(_Carrier));
    }

    UFUNCTION()
    private void Check_SlabFocused(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_SlabEntity.As_WorldItem().Get_Pickup().Get_CurrentFocuser() == _Carrier);
    }

    UFUNCTION()
    private void Step_AssertUnpinned(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_False(ck::IsValid(utils_interact_target::TryGet_Interaction(_LeverTarget, _Carrier)), "the pull has ended");
        Assert_False(_Lever.Get_IsFocused(), "the lever lost the focus to the nearer slab");
    }

    private void Record_SlabFocus()
    {
        if (Get_IsConstructedWorldItem(_SlabEntity) && _SlabEntity.As_WorldItem().Get_Pickup().Get_IsFocused())
        { _SlabEverFocused = true; }
    }
}
