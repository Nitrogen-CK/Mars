// Pickup, open and paging run through the player's real trace/intent/resolver path. The previous-page and emote rows
// are activated together as shared Q does; a focused rock pickup wins over toggling the open held book.
class UMars_AutoTest_Cookbook_PlayerInputPagesAndFocusedPromptWins : UMars_AutoTestRig_Cookbook
{
    private FCk_Handle _LooseRockEntity;
    private FCk_Handle_WorldItem _LooseRock;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Build_Cookbook(InHandle, FVector(131000.0, -40000.0, -30000.0));
        Add_Steps_PickupAndOpen();
        Add_Step("press E to advance", n"Step_Next");
        Add_Step_WaitUntil("one page section advanced", n"Check_Next", 0, 0);
        Add_Step("hold Q to return", n"Step_Previous");
        Add_Step_WaitUntil("the first page section returned", n"Check_Previous", 0, 0);
        Add_Step_WaitFrames("a held Q does not repeat", 12);
        Add_Step("Q consumed paging and the emote wheel stayed closed", n"Step_AssertPreviousAndRelease");
        Add_Step("spawn a real world pickup beside the book", n"Step_SpawnLooseRock");
        Add_Step_WaitUntil("the rock is seeded", n"Check_LooseRockReady", 0, 0);
        Add_Step("aim the real trace at the rock", n"Step_AimAtLooseRock");
        Add_Step_WaitUntil("the rock's pickup is focused", n"Check_LooseRockFocused", 0, 0);
        Add_Step("tap the shared Primary / Use key", n"Step_TapPrimary");
        Add_Step_WaitUntil("the rock is stowed in the other bag slot", n"Check_RockStowed", 0, 0);
        Add_Step("the world prompt won and the book stayed open", n"Step_AssertPriority");
        Add_Step("look away", n"Step_LookAway");
        Add_Step_WaitFrames("the prompt clears", 4);
        Add_Step("Primary closes the book", n"Step_TapPrimary");
        Add_Step_WaitUntil("the book is fully closed", n"Check_BookClosed", 0, 0);
        Add_Step_WaitFrames("closed geometry restores", 4);
        Add_Step("closing restores the ordinary hold and visual origin", n"Step_AssertClosedGeometry");
        Add_Step("Q regains the normal emote wheel", n"Step_Previous");
        Add_Step_WaitUntil("the wheel opened with the book shut", n"Check_WheelOpen", 0, 0);
        Add_Step("release Q", n"Step_ReleasePrevious");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_Next(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _UseKey.Press_Row(utils_cookbook::Get_NextIntent());
        _UseKey.Release_Row(utils_cookbook::Get_NextIntent());
    }

    UFUNCTION()
    private void Check_Next(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_BookPresentation.Get_PageSectionIndex() == 1 && _BookPresentation.Get_IsTransitioning() == false);
    }

    UFUNCTION()
    private void Step_Previous(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _UseKey.Press_Row(utils_cookbook::Get_PreviousIntent());
        _UseKey.Press_Row(GameplayTags::Mars_Intent_EmoteWheel);
    }

    UFUNCTION()
    private void Check_Previous(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_BookPresentation.Get_PageSectionIndex() == 0 && _BookPresentation.Get_IsTransitioning() == false);
    }

    UFUNCTION()
    private void Step_AssertPreviousAndRelease(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_BookPresentation.Get_PageSectionIndex(), 0, "a Q hold returns exactly one section");
        Assert_False(_Wheel.Get_IsOpen(), "shared Q never opens the emote wheel while the cookbook is open");
        Step_ReleasePrevious(InHandle, InPayload);
    }

    UFUNCTION()
    private void Step_ReleasePrevious(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _UseKey.Release_Row(utils_cookbook::Get_PreviousIntent());
        _UseKey.Release_Row(GameplayTags::Mars_Intent_EmoteWheel);
    }

    UFUNCTION()
    private void Step_SpawnLooseRock(FCk_Handle InHandle, FInstancedStruct InPayload)
    { _LooseRockEntity = Spawn_WorldItem(InHandle, mars_items::Rock(), FVector(100.0, -90.0, 16.0)); }

    UFUNCTION()
    private void Check_LooseRockReady(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto Ready = Get_IsConstructedWorldItem(_LooseRockEntity);
        if (Ready)
        { _LooseRock = _LooseRockEntity.As_WorldItem(); }

        auto Result = OutResult;
        Result.Set(Ready);
    }

    UFUNCTION()
    private void Step_AimAtLooseRock(FCk_Handle InHandle, FInstancedStruct InPayload)
    { Aim_ViewAt(utils_transform::Get_EntityCurrentTransform(_LooseRock.As_Transform()).GetLocation()); }

    UFUNCTION()
    private void Check_LooseRockFocused(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(ck::IsValid(_LooseRock) && _LooseRock.Get_Pickup().Get_IsFocused());
    }

    UFUNCTION()
    private void Check_RockStowed(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(ck::IsValid(_Hotbar.Get_ItemAt(1)) && ck::Is_NOT_Valid(_LooseRock));
    }

    UFUNCTION()
    private void Step_AssertPriority(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_HeldItem.Get_CurrentItem() == _BookItem, "picking up a second item leaves the cookbook selected");
        Assert_True(_BookPresentation.Get_IsOpen(), "Primary ran the focused world pickup instead of closing the book");
        Assert_Equals_Int(_BookPresentation.Get_PageSectionIndex(), 0, "the focused pickup did not turn a page");
        const auto View = utils_held_view::Make(_BookItem);
        Assert_False(View.Mesh.IsNull(), "the remote held-item view retains the closed static book proxy");
    }

    UFUNCTION()
    private void Check_WheelOpen(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_Wheel.Get_IsOpen() && _BookPresentation.Get_IsOpen() == false);
    }
}
