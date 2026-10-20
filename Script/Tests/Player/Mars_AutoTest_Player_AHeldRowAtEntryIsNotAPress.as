// A Use row already held when the player's tasks enter is not a press: on the player-path carrier the view rests on a
// still rock and Use is pressed and held before the player's tasks are composed (as when a station hands the player back
// to free roam with Use still down). The view focuses the rock, yet nothing picks it up while the row stays held;
// releasing and pressing again picks it up. Isolated origin (86000, -40000, -30000).
class UMars_AutoTest_Player_AHeldRowAtEntryIsNotAPress : UMars_AutoTestRig_PlayerPath
{
    private const FVector k_Origin = FVector(86000.0, -40000.0, -30000.0);
    private const FVector k_RockLocal = FVector(120.0, 0.0, 16.0);

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Build_PlayerPath(InHandle, k_Origin);
        _PathRockEntity = Spawn_WorldItem(InHandle, mars_items::Rock(), k_RockLocal);

        Add_Step_WaitUntil("the Use key is minted and the sampler records", n"Check_UseKeyRecording", 0, 0);
        Add_Step("bake the Use level row and swap it in", n"Step_SwapUseSet");
        Add_Step_WaitUntil("the Use row is live on the matcher", n"Check_UseSetActive", 0, 0);
        Add_Step_WaitUntil("the rock lies still on the floor", n"Check_PathRockStill", 0, 0);
        Add_Step("turn the view onto the rock, press and hold Use, and hand the matcher to the carrier", n"Step_AimPressAndSetMatcher");
        Add_Step_WaitUntil("the carrier reads the held Use row", n"Check_UseHeld", 0, 0);
        Add_Step("compose the player's tasks with Use already held", n"Step_ComposeWithUseHeld");
        Add_Step_WaitUntil("the view's focus lands on the rock", n"Check_RockFocused", 0, 0);
        Add_Step_WaitFrames("a held row taken for a press would have picked the rock up by now", 60);
        Add_Step("the rock still lies in the world with Use held; release Use", n"Step_AssertNotTakenAndRelease");
        Add_Step_WaitUntil("the Use row releases", n"Check_UseReleased", 0, 0);
        Add_Step("press Use again", n"Step_PressUse");
        Add_Step_WaitUntil("the fresh press picks the rock up", n"Check_PathRockStowed", 0, 0);
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_AimPressAndSetMatcher(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Aim_ViewAt(_PathRockLastLocation.GetValue());
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
        Res.Set(_PathRock.Get_Pickup().Get_IsFocused());
    }

    UFUNCTION()
    private void Step_AssertNotTakenAndRelease(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(Get_IsUseHeld(), "Use is still held");
        Assert_True(_PathRock.Get_Pickup().Get_IsFocused(), "the rock is focused");
        Assert_True(ck::IsValid(_PathRock.Get_HeldItem()), "the rock's item is still in its holder");
        Assert_True(ck::Is_NOT_Valid(_Hotbar.Get_ItemAt(0)) && ck::Is_NOT_Valid(_Hotbar.Get_ItemAt(1)), "both bag slots are empty");
        _UseKey.Release();
    }
}
