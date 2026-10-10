// Placing a held platter on a dock is a Place gesture: the carrier (with gloves) holds a platter and uses an empty dock.
// The gloves take a Place reach whose spot is over the dock's node (the reach target names a place point) and the platter
// is still Held, the dock empty, the frame after the interaction began; at the gloves' Grip the dock is still empty (its
// Dock request goes out there), the dock reports the platter docked only after that Grip, and the platter ends Carried on
// the dock's node. Isolated origin (30400, -21000, -30000).
class UMars_AutoTest_PlatterDock_PlaceRunsAPlaceReachAndDocksAtTheGrip : UMars_AutoTestRig_PlatterDock
{
    default _TimeoutSeconds = 30.0f;

    private const FVector k_Origin = FVector(30400.0, -21000.0, -30000.0);

    private FCk_Handle_PlatterDock _Dock;
    private TArray<EMars_FPHands_ReachKind> _ReachKinds;
    // The hands' phases (since the carrier's gloves were added) the moment the dock reported the platter docked.
    private TArray<EMars_FPHands_Phase> _PhasesAtDocked;
    private TOptional<bool> _DockOccupiedAtGrip;
    private bool _PlacePointSeen = false;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Add_CarrierBody(InHandle, k_Origin);
        Add_Hotbar(_Carrier, 1);
        _HeldItem = utils_held_item::Add(_Carrier);
        Add_CarrierHands();
        Bind_PushSelection();
        _Hands.BindTo_OnReachRequested(FMars_Delegate_FPHands_OnReachRequested(this, n"OnReachRequested"));
        _Hands.BindTo_OnPhaseChanged(FMars_Delegate_FPHands_OnPhaseChanged(this, n"OnPhaseChanged"));

        auto Root = Build_StationRoot(InHandle, k_Origin);
        _Dock = Build_Dock(Root, Make_DockSpec(Make_Policy(TOptional<FGameplayTag>(), false),
            FTransform(FRotator::ZeroRotator, FVector(60.0, 20.0, 50.0)), "input platter"));
        _Dock.BindTo_OnDocked(FMars_Delegate_PlatterDock_OnDocked(this, n"OnDocked"));
        Spawn_Platter(InHandle, FMars_Platter_SpawnSpec(FTransform(FRotator::ZeroRotator, k_Origin + FVector(200.0, 0.0, 0.0))));

        Add_Step_WaitUntil("the platter is constructed", n"Check_PlattersConstructed", 0, 10.0f);
        Add_Step_WaitUntil("the gloves rest, listening for a reach", n"Check_CarrierHandsRest", 0, 5.0f);
        Add_Step("stow the platter into the overflow and carry it", n"Step_Stow");
        Add_Step_WaitUntil("the platter is Held", n"Check_Held", 0, 5.0f);
        Add_Step_WaitSeconds("the hold's arrival settles", 0.5f);
        Add_Step("the carrier focuses the dock", n"Step_FocusDock");
        Add_Step_WaitFrames("the dock's prompt follows the focuser", 3);
        Add_Step("the dock offers Place; the carrier uses it", n"Step_Place");
        Add_Step_WaitFrames("the interaction has begun", 1);
        Add_Step("a Place reach over the dock; the platter is still Held and the dock empty", n"Step_AssertNotOnEnter");
        Add_Step_WaitUntil("the dock reports the platter docked", n"Check_Docked", 0, 5.0f);
        Add_Step_WaitUntil("the platter is Carried on the dock", n"Check_OnTheDock", 0, 5.0f);
        Add_Step("the dock was asked at the gloves' Grip, and the platter rides the dock's node", n"Step_AssertDockedAtTheGrip");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_Stow(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Stow_Platter(0);
    }

    UFUNCTION()
    private void Check_Held(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_WorldItems[0].Get_Mount() == EMars_WorldItem_Mount::Held && _HeldItem.Get_CurrentItem() == _PlatterItems[0]);
    }

    UFUNCTION()
    private void Step_FocusDock(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Interactable = _Dock.Get_Interactable();
        Interactable.Request_Focus(FMars_Request_Interactable_Focus(_Carrier));
    }

    UFUNCTION()
    private void Step_Place(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Action = _Dock.Get_ActionFor(_Carrier);
        Assert_True(Action == EMars_PlatterDock_Action::Place, f"holding a platter, the empty dock offers Place (got [{Action :n}])");

        auto Interactable = _Dock.Get_Interactable();
        auto Target = Interactable.Get_InteractTarget(GameplayTags::InteractionChannel_Mars_Use);
        Target.Request_StartInteraction(FCk_Try_InteractTarget_StartInteraction(_Carrier, _Carrier));
    }

    UFUNCTION()
    private void Step_AssertNotOnEnter(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_ReachKinds.Contains(EMars_FPHands_ReachKind::Place), "the gloves took a Place reach");
        Assert_True(_PlacePointSeen, "the reach target names where the platter is set down");
        Assert_True(_WorldItems[0].Get_Mount() == EMars_WorldItem_Mount::Held, "the platter is still Held");
        Assert_False(_Dock.Get_IsOccupied(), "the dock is still empty");
        Assert_Equals_Int(Get_DockedCount(_Dock), 0, "nothing docked yet");
    }

    UFUNCTION()
    private void Check_Docked(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_DockedCount(_Dock) == 1);
    }

    UFUNCTION()
    private void Check_OnTheDock(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_WorldItems[0].Get_Mount() == EMars_WorldItem_Mount::Carried && Get_MountParent(_WorldItems[0]) == _Dock.Get_Node());
    }

    UFUNCTION()
    private void Step_AssertDockedAtTheGrip(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_DockOccupiedAtGrip.IsSet(), "the gloves reached their Grip");
        Assert_True(_DockOccupiedAtGrip == false, "the dock was still empty at the Grip: the Dock request went out there");
        Assert_True(_PhasesAtDocked.Contains(EMars_FPHands_Phase::Grip), "the dock reported the platter docked only after the gloves' Grip");
        Assert_Equals_Int(Get_DockedCount(_Dock), 1, "one dock");
        Assert_True(_Dock.Get_Platter() == _Platters[0], "the dock holds the platter");
        Assert_True(ck::Is_NOT_Valid(_HeldItem.Get_CurrentItem()), "the hands are empty");
    }

    UFUNCTION()
    private void OnReachRequested(FCk_Handle_FPHands InHands, EMars_FPHands_ReachKind InKind)
    {
        _ReachKinds.Add(InKind);
        const auto Target = InHands.Get_Target();
        if (InKind == EMars_FPHands_ReachKind::Place && Target.IsSet() && Target.GetValue().PlaceAt.IsSet())
        { _PlacePointSeen = true; }
    }

    UFUNCTION()
    private void OnPhaseChanged(FCk_Handle_FPHands InHands, EMars_FPHands_Phase InPrevious, EMars_FPHands_Phase InNew)
    {
        if (InNew == EMars_FPHands_Phase::Grip && _DockOccupiedAtGrip.IsSet() == false)
        { _DockOccupiedAtGrip = TOptional<bool>(_Dock.Get_IsOccupied()); }
    }

    UFUNCTION()
    private void OnDocked(FCk_Handle_PlatterDock InDock, FCk_Handle_Platter InPlatter)
    {
        _PhasesAtDocked = _HandPhases;
    }
}
