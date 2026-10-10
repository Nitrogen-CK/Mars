// Taking a platter off a dock reaches with both gloves, as picking it off the ground does. The dock (the Take target's
// owner) carries no world item of its own: once a platter has docked it hints the platter's fit and handedness (the
// platter's world item hints them from its own composition), so a gloved carrier's Take reach resolves a Sides target with
// both gloves on the tray. An empty dock hints nothing, before the dock and again after the platter is taken. Isolated
// origin (31600, -21000, -30000).
class UMars_AutoTest_PlatterDock_TakeReachesWithBothGloves : UMars_AutoTestRig_PlatterDock
{
    default _TimeoutSeconds = 30.0f;

    private const FVector k_Origin = FVector(31600.0, -21000.0, -30000.0);

    private FCk_Handle_PlatterDock _Dock;
    private FCk_Handle_InteractTarget _TakeTarget;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Add_CarrierBody(InHandle, k_Origin);
        Add_Hotbar(_Carrier, 1);
        _HeldItem = utils_held_item::Add(_Carrier);
        Add_CarrierHands();
        Bind_PushSelection();

        auto Root = Build_StationRoot(InHandle, k_Origin);
        _Dock = Build_Dock(Root, Make_DockSpec(Make_Policy(TOptional<FGameplayTag>(), false),
            FTransform(FRotator::ZeroRotator, FVector(60.0, 20.0, 50.0)), "input platter"));
        Spawn_Platter(InHandle, FMars_Platter_SpawnSpec(FTransform(FRotator::ZeroRotator, k_Origin + FVector(200.0, 0.0, 0.0))));

        Add_Step_WaitUntil("the platter is constructed", n"Check_PlattersConstructed", 0, 10.0f);
        Add_Step_WaitUntil("the gloves rest, listening for a reach", n"Check_CarrierHandsRest", 0, 5.0f);
        Add_Step("the platter hints two hands; the empty dock hints nothing; dock the platter", n"Step_AssertHintsAndDock");
        Add_Step_WaitUntil("the platter has landed on the dock", n"Check_Arrived", 0, 10.0f);
        Add_Step("the dock hints its platter; the carrier's gloves reach for the Take", n"Step_AssertDockHintAndReach");
        Add_Step_WaitUntil("the gloves took the Take reach", n"Check_ReachTaken", 0, 2.0f);
        Add_Step("both gloves reach for the tray (Sides layout)", n"Step_AssertBothGloves");
        Add_Step_WaitUntil("the gloves rest again", n"Check_CarrierHandsRest", 0, 5.0f);
        Add_Step("take the platter into the overflow", n"Step_Take");
        Add_Step_WaitUntil("the dock reports the platter undocked", n"Check_Undocked", 0, 5.0f);
        Add_Step("the emptied dock hints nothing", n"Step_AssertNoDockHint");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_AssertHintsAndDock(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const FCk_Handle PlatterEntity = _WorldItems[0];
        Assert_True(PlatterEntity.Has_ReachHint(), "the platter's world item hints a reach");
        if (PlatterEntity.Has_ReachHint())
        {
            Assert_True(PlatterEntity.Get_ReachHint().Handedness == EMars_ItemPresentation_Handedness::TwoHanded,
                "the platter is taken with two hands");
        }

        const FCk_Handle DockEntity = _Dock;
        Assert_False(DockEntity.Has_ReachHint(), "the empty dock hints nothing");
        Dock(_Dock, _PlatterItems[0]);
    }

    UFUNCTION()
    private void Check_Arrived(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_ArrivedCount(_Dock) == 1);
    }

    UFUNCTION()
    private void Step_AssertDockHintAndReach(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const FCk_Handle DockEntity = _Dock;
        const FCk_Handle PlatterEntity = _WorldItems[0];
        Assert_True(DockEntity.Has_ReachHint(), "the occupied dock hints a reach");
        if (DockEntity.Has_ReachHint() == false || PlatterEntity.Has_ReachHint() == false)
        { return; }

        const auto DockHint = DockEntity.Get_ReachHint();
        const auto PlatterHint = PlatterEntity.Get_ReachHint();
        Assert_True(DockHint.Handedness == PlatterHint.Handedness, "the dock hints its platter's handedness");
        Assert_True(DockHint.BoundsFit.Centre.Equals(PlatterHint.BoundsFit.Centre, 0.01)
            && DockHint.BoundsFit.HalfExtents.Equals(PlatterHint.BoundsFit.HalfExtents, 0.01), "the dock hints its platter's fit");

        const auto Action = _Dock.Get_ActionFor(_Carrier);
        Assert_True(Action == EMars_PlatterDock_Action::Take, f"empty-handed, the occupied dock offers Take (got [{Action :n}])");

        // The reach the player's HandsResolverBinds requests for a newly best Use target.
        auto Interactable = _Dock.Get_Interactable();
        _TakeTarget = Interactable.Get_InteractTarget(GameplayTags::InteractionChannel_Mars_Use);
        const auto& Context = _TakeTarget.Get_Fragment(FMars_Fragment_InteractionContext);
        const auto Subject = FMars_FPHands_ReachSubject(_TakeTarget, Context.Interactable, Context.InteractableOwner);
        _Hands.Request_StartReach(FMars_Request_FPHands_StartReach(Subject, _TakeTarget.Get_InteractionCompletionPolicy()));
    }

    UFUNCTION()
    private void Check_ReachTaken(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Hands.Get_ReachInteractTarget() == _TakeTarget && _Hands.Get_Target().IsSet());
    }

    UFUNCTION()
    private void Step_AssertBothGloves(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Target = _Hands.Get_Target().GetValue();
        Assert_True(Target.Layout == EMars_FPHands_GripLayout::Sides, f"the Take reach takes the tray by its sides (layout [{Target.Layout :n}])");
        Assert_True(Target.Right.IsSet(), "the right glove reaches");
        Assert_True(Target.Left.IsSet(), "the left glove reaches");
    }

    UFUNCTION()
    private void Step_Take(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Undock(_Dock, _PlatterItems[0], _Hotbar.TryGet_StowTarget(_PlatterItems[0]));
    }

    UFUNCTION()
    private void Check_Undocked(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_UndockedCount(_Dock) == 1);
    }

    UFUNCTION()
    private void Step_AssertNoDockHint(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const FCk_Handle DockEntity = _Dock;
        Assert_False(DockEntity.Has_ReachHint(), "the emptied dock hints nothing");
    }
}
