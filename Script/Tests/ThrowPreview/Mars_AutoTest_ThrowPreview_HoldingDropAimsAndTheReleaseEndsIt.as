// Holding Drop aims, and the release ends it. A carrier down the player's path runs the player's DropThrowIntent and
// ThrowPreviewFollowsArm tasks over HeldItemUse and a ThrowPreview (UMars_AutoTestRig_ThrowPreviewPlayerPath) and holds a
// rock:
//   - Drop pressed: not aiming while the hold is short of ThrowHoldSeconds;
//   - once ThrowHoldSeconds have passed: aiming, and the path has an end;
//   - Drop released: OnItemLaunched fires once, as a Throw, and within a few frames the preview stops aiming and its path
//     is cleared;
//   - a second rock, Drop held past ThrowHoldSeconds (aiming), then the hands emptied mid-hold by selecting the empty bag
//     slot (as Step_SelectEmptySlot does): within a few frames not aiming.
// Isolated origin (272000, -40000, -30000).
class UMars_AutoTest_ThrowPreview_HoldingDropAimsAndTheReleaseEndsIt : UMars_AutoTestRig_ThrowPreviewPlayerPath
{
    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Build_ThrowPreviewPlayerPath(InHandle, FVector(272000.0, -40000.0, -30000.0));

        // Well inside the hold: a third of it.
        const auto ShortOfTheHold = Get_ThrowHoldSeconds() / 3.0f;

        Add_Steps_UntilHoldingTheFirstRock();
        Add_Step("press Drop", n"Step_PressDrop");
        Add_Step_WaitUntil("Drop reads held", n"Check_DropHeld");
        Add_Step_WaitSeconds("a third of ThrowHoldSeconds", ShortOfTheHold);
        Add_Step("short of the hold: not aiming", n"Step_AssertNotAiming");
        Add_Step_WaitSeconds("the rest of ThrowHoldSeconds", Get_ThrowHoldSeconds() - ShortOfTheHold);
        Add_Step_WaitUntil("within a few frames the preview aims and its path has an end", n"Check_AimingWithAPath", k_FewFrames, 1.0f);
        Add_Step("release Drop", n"Step_ReleaseDrop");
        Add_Step_WaitUntil("the rock is launched", n"Check_Launched");
        Add_Step_WaitUntil("within a few frames the preview stops aiming and its path is cleared", n"Check_IdleWithoutAPath", k_FewFrames, 1.0f);
        Add_Step("launched once, as a Throw", n"Step_AssertThrownOnce");
        Add_Step("stow the second rock into the hands", n"Step_StowSecond");
        Add_Step_WaitUntil("the hands hold the second rock", n"Check_HoldingSecond");
        Add_Step("press Drop", n"Step_PressDrop");
        Add_Step_WaitUntil("Drop reads held", n"Check_DropHeld");
        Add_Step_WaitSeconds("ThrowHoldSeconds", Get_ThrowHoldSeconds());
        Add_Step_WaitUntil("within a few frames the preview aims", n"Check_AimingWithAPath", k_FewFrames, 1.0f);
        Add_Step("empty the hands mid-hold: select the empty bag slot", n"Step_SelectTheOtherSlot");
        Add_Step_WaitUntil("the hands are empty", n"Check_HandsEmpty");
        Add_Step_WaitUntil("within a few frames the preview stops aiming", n"Check_IdleWithoutAPath", k_FewFrames, 1.0f);
        Add_Step("not aiming; release Drop", n"Step_AssertEmptiedAndRelease");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_AssertNotAiming(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_False(_Preview.Get_IsAiming(), "a hold short of ThrowHoldSeconds does not aim");
        Assert_Equals_Int(_AimChanges.Num(), 0, "no OnAimChanged before the hold arms");
    }

    UFUNCTION()
    private void Check_AimingWithAPath(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Preview.Get_IsAiming() && _Preview.Get_Path().End != EMars_ThrowPreview_End::None);
    }

    UFUNCTION()
    private void Check_IdleWithoutAPath(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Preview.Get_IsAiming() == false && _Preview.Get_Path().End == EMars_ThrowPreview_End::None);
    }

    UFUNCTION()
    private void Step_AssertThrownOnce(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Launches.Num(), 1, "the release launched the rock once");
        if (_Launches.Num() > 0)
        { Assert_True(_Launches[0] == EMars_LaunchKind::Throw, f"the release past the hold throws (got {_Launches[0] :n})"); }

        Assert_Equals_Int(_AimChanges.Num(), 2, "OnAimChanged fired twice: Aiming at the arm, Idle at the release");
        if (_AimChanges.Num() == 2)
        {
            Assert_True(_AimChanges[0] == EMars_ThrowPreview_Aim::Aiming, "the first OnAimChanged is Aiming");
            Assert_True(_AimChanges[1] == EMars_ThrowPreview_Aim::Idle, "the second OnAimChanged is Idle");
        }
    }

    // Selects whichever bag slot does not hold the second rock (the thrown rock left its slot empty).
    UFUNCTION()
    private void Step_SelectTheOtherSlot(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Other = _Hotbar.Get_ItemAt(0) == _Items[1] ? 1 : 0;
        Assert_False(ck::IsValid(_Hotbar.Get_ItemAt(Other)), f"bag slot {Other} is empty");
        _Hotbar.Request_Select(FMars_Request_Hotbar_Select(Other));
    }

    UFUNCTION()
    private void Step_AssertEmptiedAndRelease(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_False(_Preview.Get_IsAiming(), "emptying the hands mid-hold stops the aim");
        Assert_Equals_Int(_Launches.Num(), 1, "emptying the hands launched nothing");
        _UseKey.Release_Row(GameplayTags::Mars_Intent_Drop);
    }
}
