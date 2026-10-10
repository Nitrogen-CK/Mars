// A world item the player picks up lands in the hotbar, through the real pickup. The player-path carrier (empty hands, two
// empty bag slots) turns its view onto a rock lying still on its floor and taps Use: the focus task offers the rock, the
// Use row opens the interaction, the gloves reach and grip, and the pickup task stows the rock into a bag slot, selected
// and held (the hands were empty); the emptied world item destroys itself. Isolated origin (155000, -70000, -30000).
class UMars_AutoTest_WorldItem_PickupStows : UMars_AutoTestRig_PlayerPath
{
    private const FVector k_Origin = FVector(155000.0, -70000.0, -30000.0);
    private const FVector k_RockLocal = FVector(120.0, 0.0, 16.0);

    private FCk_Handle _RockEntity;
    private FCk_Handle_WorldItem _Rock;
    private TOptional<FVector> _LastRockLocation;
    private int32 _StillFrames = 0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Build_PlayerPath(InHandle, k_Origin);
        _RockEntity = Spawn_WorldItem(InHandle, mars_items::Rock(), k_RockLocal);

        Add_Steps_UntilReady();
        Add_Step_WaitUntil("the rock lies still on the floor", n"Check_RockStill", 0, 0);
        Add_Step("the hands and the bag slots are empty; turn the view onto the rock", n"Step_AimAtRock");
        Add_Step_WaitUntil("the rock's pickup is focused", n"Check_RockFocused", 0, 0);
        Add_Step("press Use", n"Step_PressUse");
        Add_Step_WaitUntil("Use is held", n"Check_UseHeld", 0, 0);
        Add_Step("release Use", n"Step_ReleaseUse");
        Add_Step_WaitUntil("the rock lands in the selected bag slot and is held", n"Check_RockHeld", 0, 0);
        Add_Step_WaitUntil("the emptied world item destroyed itself", n"Check_WorldItemDestroyed", 0, 0);
        Add_Step("the rock is in a bag slot, selected and held", n"Step_AssertStowed");
        Run_Steps(InHandle);
    }

    // A constructed rock world item whose location moved less than 1.5 mm a frame for 10 frames.
    UFUNCTION()
    private void Check_RockStill(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        if (ck::Is_NOT_Valid(_Rock))
        {
            if (Get_IsConstructedWorldItem(_RockEntity) == false)
            {
                Res.Set(false);
                return;
            }

            _Rock = _RockEntity.As_WorldItem();
        }

        const auto Location = utils_transform::Get_EntityCurrentTransform(_RockEntity.As_Transform()).GetLocation();
        const auto IsStill = _LastRockLocation.IsSet() && _LastRockLocation.GetValue().Equals(Location, 0.15);
        _StillFrames = IsStill ? _StillFrames + 1 : 0;
        _LastRockLocation = TOptional<FVector>(Location);
        Res.Set(_StillFrames >= 10);
    }

    UFUNCTION()
    private void Step_AimAtRock(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(ck::Is_NOT_Valid(_HeldItem.Get_CurrentItem()), "the hands are empty");
        Assert_True(ck::Is_NOT_Valid(_Hotbar.Get_ItemAt(0)) && ck::Is_NOT_Valid(_Hotbar.Get_ItemAt(1)), "both bag slots are empty");
        Aim_ViewAt(_LastRockLocation.GetValue());
    }

    UFUNCTION()
    private void Check_RockFocused(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Rock.Get_Pickup().Get_IsFocused());
    }

    // HeldItem follows the hotbar's selected slot on its own.
    UFUNCTION()
    private void Check_RockHeld(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto Selected = _Hotbar.Get_SelectedIndex();
        const auto Held = _HeldItem.Get_CurrentItem();
        auto Res = OutResult;
        Res.Set(Selected.IsSet() && ck::IsValid(Held) && _Hotbar.Get_ItemAt(Selected.GetValue()) == Held);
    }

    UFUNCTION()
    private void Check_WorldItemDestroyed(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(ck::Is_NOT_Valid(_RockEntity));
    }

    UFUNCTION()
    private void Step_AssertStowed(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Selected = _Hotbar.Get_SelectedIndex();
        Assert_True(Selected.IsSet() && (Selected.GetValue() == 0 || Selected.GetValue() == 1), "a bag slot is selected");
        if (Selected.IsSet() == false)
        { return; }

        const auto Stowed = _Hotbar.Get_ItemAt(Selected.GetValue());
        Assert_True(ck::IsValid(Stowed), "the selected bag slot holds the rock");
        Assert_True(_HeldItem.Get_CurrentItem() == Stowed, "the rock is held: the hands were empty");
        Assert_True(ck::Is_NOT_Valid(_RockEntity), "the emptied world item destroyed itself");
    }
}
