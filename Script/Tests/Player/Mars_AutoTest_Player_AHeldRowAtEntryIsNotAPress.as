// A Use row already held when the player's tasks enter is not a press: on the player-path carrier the view rests on a
// still rock and Use is pressed and held before the player's tasks are composed (as when a station hands the player back
// to free roam with Use still down). The view focuses the rock, yet nothing picks it up while the row stays held;
// releasing and pressing again picks it up. Isolated origin (86000, -40000, -30000).
class UMars_AutoTest_Player_AHeldRowAtEntryIsNotAPress : UMars_AutoTestRig_PlayerPath
{
    private const FVector k_Origin = FVector(86000.0, -40000.0, -30000.0);
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

        Add_Step_WaitUntil("the Use key is minted and the sampler records", n"Check_UseKeyRecording", 0, 0);
        Add_Step("bake the Use level row and swap it in", n"Step_SwapUseSet");
        Add_Step_WaitUntil("the Use row is live on the matcher", n"Check_UseSetActive", 0, 0);
        Add_Step_WaitUntil("the rock lies still on the floor", n"Check_RockStill", 0, 0);
        Add_Step("turn the view onto the rock, press and hold Use, and hand the matcher to the carrier", n"Step_AimPressAndSetMatcher");
        Add_Step_WaitUntil("the carrier reads the held Use row", n"Check_UseHeld", 0, 0);
        Add_Step("compose the player's tasks with Use already held", n"Step_ComposeWithUseHeld");
        Add_Step_WaitUntil("the view's focus lands on the rock", n"Check_RockFocused", 0, 0);
        Add_Step_WaitFrames("a held row taken for a press would have picked the rock up by now", 60);
        Add_Step("the rock still lies in the world with Use held; release Use", n"Step_AssertNotTakenAndRelease");
        Add_Step_WaitUntil("the Use row releases", n"Check_UseReleased", 0, 0);
        Add_Step("press Use again", n"Step_PressUse");
        Add_Step_WaitUntil("the fresh press picks the rock up", n"Check_RockStowed", 0, 0);
        Run_Steps(InHandle);
    }

    // A constructed rock world item whose location moved less than 1.5 mm a frame for 10 frames.
    UFUNCTION()
    private void Check_RockStill(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        if (ck::Is_NOT_Valid(_Rock))
        {
            const auto Constructed = ck::IsValid(_RockEntity) && _RockEntity.Is_WorldItem()
                && ck::IsValid(_RockEntity.As_WorldItem().Get_HeldItem());
            if (Constructed == false)
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
    private void Step_AimPressAndSetMatcher(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Aim_ViewAt(_LastRockLocation.GetValue());
        _UseKey.Press();
        _Intents.Request_SetMatcher(FMars_Request_InputIntents_SetMatcher(_UseKey.Get_Matcher()));
    }

    UFUNCTION()
    private void Step_ComposeWithUseHeld(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Sm = utils_state_machine::Add(_Carrier, FCk_StateMachine_Spec(UMars_AutoTestState_PlayerPathRig));
    }

    UFUNCTION()
    private void Check_RockFocused(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Rock.Get_Pickup().Get_IsFocused());
    }

    UFUNCTION()
    private void Step_AssertNotTakenAndRelease(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(Get_IsUseHeld(), "Use is still held");
        Assert_True(_Rock.Get_Pickup().Get_IsFocused(), "the rock is focused");
        Assert_True(ck::IsValid(_Rock.Get_HeldItem()), "the rock's item is still in its holder");
        Assert_True(ck::Is_NOT_Valid(_Hotbar.Get_ItemAt(0)) && ck::Is_NOT_Valid(_Hotbar.Get_ItemAt(1)), "both bag slots are empty");
        _UseKey.Release();
    }

    // A transient rock's world item ends once its holder gives the item up.
    UFUNCTION()
    private void Check_RockStowed(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set((ck::Is_NOT_Valid(_Rock) || ck::Is_NOT_Valid(_Rock.Get_HeldItem()))
            && (ck::IsValid(_Hotbar.Get_ItemAt(0)) || ck::IsValid(_Hotbar.Get_ItemAt(1))));
    }
}
