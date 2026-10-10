// An operated station stays focusable and refuses Use. A station with a Use probe stands in front of the player-path
// carrier; a bare operator reserves it by request, so its Use interactable holds the Operated claim. The carrier's view
// then turns onto the probe: the station's Use target is focused by the carrier (its state machine Focused) with its
// framework target disabled and its prompt reading the occupied text, and a Use press starts no interaction - the bare
// operator keeps the station. Isolated origin (90000, -40000, -30000).
class UMars_AutoTest_Station_AnOperatedStationStaysFocusableAndRefusesUse : UMars_AutoTestRig_PlayerPath
{
    private const FVector k_Origin = FVector(90000.0, -40000.0, -30000.0);
    // The Use probe, from the origin: in front of the carrier, at its eye height.
    private const FVector k_ProbeLocal = FVector(120.0, 0.0, 15.0);
    private const float32 k_ProbeRadius = 20.0f;

    private FCk_Handle_Station _Station;
    private FCk_Handle_Operator _Operator;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Build_PlayerPath(InHandle, k_Origin);
        BuildStation(InHandle);

        Add_Steps_UntilReady();
        Add_Step("a bare operator reserves the station", n"Step_ReserveForTheOperator");
        Add_Step_WaitUntil("the operator holds the station and its Use interactable holds the Operated claim", n"Check_Operated", 0, 0);
        Add_Step("turn the view onto the station's Use probe", n"Step_AimAtTheProbe");
        Add_Step_WaitUntil("the carrier focuses the operated station", n"Check_FocusedByTheCarrier", 0, 0);
        Add_Step("Focused, its target disabled, its prompt reads the occupied text; press Use", n"Step_AssertFocusedAndPress");
        Add_Step_WaitFrames("a press the station accepted would have started an interaction by now", 10);
        Add_Step("the press started nothing and the operator keeps the station; release Use", n"Step_AssertRefusedAndRelease");
        Run_Steps(InHandle);
    }

    // The station on a root of its own at the origin, its Use interactable a Kinematic probe on the view's line.
    private void BuildStation(FCk_Handle InHandle)
    {
        auto Parent = InHandle;
        auto StationEntity = utils_entity_lifetime::Request_CreateEntity(Parent);
        auto Root = utils_transform::Add(StationEntity, FTransform(FRotator::ZeroRotator, k_Origin), ECk_Replication::DoesNotReplicate);

        auto Probe = FMars_Interactable_ProbeInfo();
        Probe.ProbeSpec = FCk_Probe_Spec(GameplayTags::Probe_Mars_Interact);
        Probe.ProbeSpec.Set_MotionType(ECk_MotionType::Kinematic);
        Probe.ProbeShape = utils_shapes::Make_Sphere(FCk_ShapeSphere_Dimensions(k_ProbeRadius));
        Probe.ProbeOffset = FTransform(FRotator::ZeroRotator, k_ProbeLocal);

        auto Setup = FMars_Station_Setup();
        Setup.Probe = TOptional<FMars_Interactable_ProbeInfo>(Probe);
        _Station = utils_station::Add(Root, FMars_Station_Spec(), Setup);

        auto OperatorEntity = utils_entity_lifetime::Request_CreateEntity(Parent);
        _Operator = utils_operator::Add(OperatorEntity);
    }

    UFUNCTION()
    private void Step_ReserveForTheOperator(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Valid(_Station, "utils_station::Add composed the station");
        _Station.Request_Reserve(FMars_Request_Station_Reserve(_Operator));
    }

    UFUNCTION()
    private void Check_Operated(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Station.Get_IsOperatedBy(_Operator)
            && _Station.Get_Interactable().Get_IsDisabledFor(EMars_Interactable_DisableReason::Operated));
    }

    UFUNCTION()
    private void Step_AimAtTheProbe(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Aim_ViewAt(k_Origin + k_ProbeLocal);
    }

    UFUNCTION()
    private void Check_FocusedByTheCarrier(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Station.Get_Interactable().Get_CurrentFocuser() == _Carrier
            && utils_state_machine::Get_CurrentStateClass(_Station.Get_UseTarget().As_StateMachine()) == UMars_SmState_Interactable_Focused);
    }

    UFUNCTION()
    private void Step_AssertFocusedAndPress(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Target = _Station.Get_UseTarget();
        Assert_True(_Station.Get_Interactable().Get_IsFocusable(), "Operated keeps the station's Use interactable focusable");
        Assert_True(utils_interact_target::Get_Enabled(Target) == ECk_EnableDisable::Disable, "its framework target is disabled");

        const auto Prompt = Target.As_InteractPrompt();
        Assert_Equals_String(Prompt.Get_DisplayText().ToString(), FMars_Station_PromptSpec().OccupiedText.ToString(),
            "its prompt reads the occupied text");

        _UseKey.Press();
    }

    UFUNCTION()
    private void Step_AssertRefusedAndRelease(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(Get_IsUseHeld(), "Use is held");
        Assert_Invalid(utils_interact_target::TryGet_Interaction(_Station.Get_UseTarget(), _Carrier), "the press started no interaction");
        Assert_True(_Station.Get_IsOperatedBy(_Operator), "the bare operator keeps the station");
        _UseKey.Release();
    }
}
