// Taking a platter off a dock rides the gloves home, as a pickup does. A gloved carrier (hotbar, HeldItem with its
// selection pushed) uses the occupied dock's Take: at the gloves' Grip the platter is undocked into the overflow and held,
// yet it does not move from the dock until the gloves start their Return, and it reaches its HeldOffset under the Hand
// node within a frame of the gloves coming to Rest. Isolated origin (32800, -21000, -30000).
class UMars_AutoTest_PlatterDock_ATakeAtTheGripArrivesWithTheGlovesReturn : UMars_AutoTestRig_PlatterDock
{
    default _TimeoutSeconds = 30.0f;

    private const FVector k_Origin = FVector(32800.0, -21000.0, -30000.0);
    private const float64 k_StillCm = 0.5;
    private const float64 k_AtOffsetCm = 0.5;
    private const int32 k_MaxFramesAfterRest = 2;
    private const int32 k_GiveUpFramesAfterRest = 30;

    private FCk_Handle_PlatterDock _Dock;
    private FVector _PlatterAtStart;
    private bool _SawReturn = false;
    private int32 _FramesBeforeReturn = 0;
    private int32 _MovedFramesBeforeReturn = 0;
    private int32 _FramesAtRest = 0;
    private int32 _ArrivedOnRestFrame = -1;

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
        Add_Step("dock the platter", n"Step_Dock");
        Add_Step_WaitUntil("the platter has landed on the dock", n"Check_Arrived", 0, 10.0f);
        Add_Step("the carrier focuses the dock", n"Step_FocusDock");
        Add_Step_WaitFrames("the dock's target enters Focused", 3);
        Add_Step("the carrier reaches for the dock and takes the platter", n"Step_ReachAndTake");
        Add_Step_WaitUntil("the gloves grip, return and rest; the platter rides them home", n"Check_RideHome", 0, 5.0f);
        Add_Step("still until the Return; at its HeldOffset within a frame of Rest", n"Step_AssertRodeHome");
        Run_Steps(InHandle);
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
        Res.Set(Get_ArrivedCount(_Dock) == 1);
    }

    UFUNCTION()
    private void Step_FocusDock(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Interactable = _Dock.Get_Interactable();
        Interactable.Request_Focus(FMars_Request_Interactable_Focus(_Carrier));
    }

    // What the player's resolver and interaction glue do on a press: the gloves reach for the dock's Use target, and the
    // interaction starts.
    UFUNCTION()
    private void Step_ReachAndTake(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Action = _Dock.Get_ActionFor(_Carrier);
        Assert_True(Action == EMars_PlatterDock_Action::Take, f"empty-handed, the occupied dock offers Take (got [{Action :n}])");

        _PlatterAtStart = Get_PlatterWorld().GetLocation();

        auto Interactable = _Dock.Get_Interactable();
        auto Target = Interactable.Get_InteractTarget(GameplayTags::InteractionChannel_Mars_Use);
        const auto& Context = Target.Get_Fragment(FMars_Fragment_InteractionContext);
        _Hands.Request_StartReach(FMars_Request_FPHands_StartReach(
            FMars_FPHands_ReachSubject(Target, Context.Interactable, Context.InteractableOwner), Target.Get_InteractionCompletionPolicy()));
        Target.Request_StartInteraction(FCk_Try_InteractTarget_StartInteraction(_Carrier, _Carrier));
    }

    UFUNCTION()
    private void Check_RideHome(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        if (_HandPhases.Contains(EMars_FPHands_Phase::Return))
        { _SawReturn = true; }

        if (_SawReturn == false)
        {
            ++_FramesBeforeReturn;
            if (Get_PlatterWorld().GetLocation().Equals(_PlatterAtStart, k_StillCm) == false)
            { ++_MovedFramesBeforeReturn; }

            Res.Set(false);
            return;
        }

        if (_Hands.Get_Phase() != EMars_FPHands_Phase::None)
        {
            Res.Set(false);
            return;
        }

        ++_FramesAtRest;
        if (Get_IsAtHeldOffset())
        {
            _ArrivedOnRestFrame = _FramesAtRest;
            Res.Set(true);
            return;
        }

        Res.Set(_FramesAtRest >= k_GiveUpFramesAfterRest);
    }

    UFUNCTION()
    private void Step_AssertRodeHome(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_FramesBeforeReturn > 1, f"the gloves reached and gripped over frames ({_FramesBeforeReturn})");
        Assert_Equals_Int(_MovedFramesBeforeReturn, 0, "the platter stayed on the dock until the gloves started their Return");
        Assert_True(_WorldItems[0].Get_Mount() == EMars_WorldItem_Mount::Held && _WorldItems[0].Get_Carrier() == _Carrier,
            "the platter is held by the carrier");
        Assert_True(_ArrivedOnRestFrame >= 1 && _ArrivedOnRestFrame <= k_MaxFramesAfterRest,
            f"the platter was at its HeldOffset within a frame of the gloves' Rest (rest frame {_ArrivedOnRestFrame})");
    }

    private FTransform Get_PlatterWorld() const
    {
        FCk_Handle Entity = _WorldItems[0];
        return utils_transform::Get_EntityCurrentTransform(Entity.As_Transform());
    }

    private bool Get_IsAtHeldOffset() const
    {
        const UMars_ItemTrait_Presentation Presentation = utils_world_item::TryGet_Presentation(_WorldItems[0]);
        if (ck::Is_NOT_Valid(Presentation))
        { return false; }

        const auto InHand = Get_PlatterWorld().GetRelativeTransform(utils_transform::Get_EntityCurrentTransform(_HandNode));
        return InHand.GetLocation().Equals(Presentation.Mounting.HeldOffset.GetLocation(), k_AtOffsetCm);
    }
}
