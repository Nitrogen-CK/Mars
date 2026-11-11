// No aim, no path; an aim with empty hands, no path either. A bare carrier with a ThrowPreview:
//   - composed and idle: not aiming, End None, and no OnPathUpdated over a settle;
//   - aiming with empty hands: aiming, End None, no points, and OnPathUpdated fired (the cleared path is reported);
//   - a rock stowed into the hands: End leaves None within a few frames;
//   - SetAim(Idle): not aiming, End None; OnAimChanged fired exactly twice over the test (Aiming, then Idle);
//   - SetAim(Aiming) then SetAim(Idle) in one frame: the last wins, so it stays idle and nothing more is broadcast.
// Isolated origin (252000, -40000, -30000).
class UMars_AutoTest_ThrowPreview_NoAimNoPathAndEmptyHandsNoPath : UMars_AutoTestRig_ThrowPreview
{
    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        _Origin = FVector(252000.0, -40000.0, -30000.0);
        Add_CarrierBody(InHandle, _Origin);
        Add_PreviewParts(2);
        _Holders.Add(MakeSeededHolder(InHandle, mars_items::Rock()));

        Add_Step_WaitUntil("the holder holds its rock", n"Check_HoldersSeeded");
        Add_Step_WaitSeconds("idle for a while", 0.25f);
        Add_Step("idle: not aiming, no path, nothing broadcast", n"Step_AssertIdle");
        Add_Step("aim with empty hands", n"Step_Aim");
        Add_Step_WaitUntil("aiming, and a path update arrived", n"Check_AimingAndUpdated");
        Add_Step("aiming with empty hands: still no path", n"Step_AssertEmptyHandsNoPath");
        Add_Step("stow the rock into the hands", n"Step_StowFirst");
        Add_Step_WaitUntil("the hands hold it", n"Check_Holding");
        Add_Step_WaitUntil("the path leaves None within a few frames", n"Check_PathNotNone", 30, 1.0f);
        Add_Step("stop aiming", n"Step_Idle");
        Add_Step_WaitUntil("not aiming", n"Check_NotAiming");
        Add_Step("idle again: no path, OnAimChanged fired Aiming then Idle", n"Step_AssertIdleAgain");
        Add_Step("aim and stop aiming in one frame", n"Step_AimThenIdle");
        Add_Step_WaitSeconds("let the drain run", 0.25f);
        Add_Step("the last request won: still idle, nothing more broadcast", n"Step_AssertLastWins");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_AssertIdle(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Valid(_Preview, "the preview composed");
        Assert_False(_Preview.Get_IsAiming(), "a fresh preview is not aiming");
        Assert_True(_Preview.Get_Path().End == EMars_ThrowPreview_End::None, "a fresh preview has no path");
        Assert_Equals_Int(_PathUpdates, 0, "an idle preview broadcasts no OnPathUpdated");
        Assert_Equals_Int(_AimChanges.Num(), 0, "an idle preview broadcasts no OnAimChanged");
    }

    UFUNCTION()
    private void Check_AimingAndUpdated(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Preview.Get_IsAiming() && _PathUpdates > 0);
    }

    UFUNCTION()
    private void Step_AssertEmptyHandsNoPath(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Path = _Preview.Get_Path();
        Assert_True(Path.End == EMars_ThrowPreview_End::None, f"empty hands leave no path (End {Path.End :n})");
        Assert_Equals_Int(Path.Points.Num(), 0, "empty hands leave no points");
        Assert_Equals_Int(_AimChanges.Num(), 1, "OnAimChanged fired once, for the aim");
        if (_AimChanges.Num() > 0)
        { Assert_True(_AimChanges[0] == EMars_ThrowPreview_Aim::Aiming, "the first OnAimChanged is Aiming"); }
    }

    UFUNCTION()
    private void Check_PathNotNone(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Preview.Get_Path().End != EMars_ThrowPreview_End::None);
    }

    UFUNCTION()
    private void Step_Idle(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Preview.Request_SetAim(FMars_Request_ThrowPreview_SetAim(EMars_ThrowPreview_Aim::Idle));
    }

    UFUNCTION()
    private void Check_NotAiming(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Preview.Get_IsAiming() == false);
    }

    UFUNCTION()
    private void Step_AssertIdleAgain(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Preview.Get_Path().End == EMars_ThrowPreview_End::None, "stopping the aim clears the path");
        Assert_Equals_Int(_Preview.Get_Path().Points.Num(), 0, "stopping the aim clears the points");
        Assert_Equals_Int(_AimChanges.Num(), 2, "OnAimChanged fired twice");
        if (_AimChanges.Num() == 2)
        { Assert_True(_AimChanges[1] == EMars_ThrowPreview_Aim::Idle, "the second OnAimChanged is Idle"); }
    }

    UFUNCTION()
    private void Step_AimThenIdle(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Preview.Request_SetAim(FMars_Request_ThrowPreview_SetAim(EMars_ThrowPreview_Aim::Aiming));
        _Preview.Request_SetAim(FMars_Request_ThrowPreview_SetAim(EMars_ThrowPreview_Aim::Idle));
    }

    UFUNCTION()
    private void Step_AssertLastWins(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_False(_Preview.Get_IsAiming(), "Aiming then Idle in one frame ends idle: the last request wins");
        Assert_Equals_Int(_AimChanges.Num(), 2, "OnAimChanged fired exactly twice over the test");
        Assert_True(_Preview.Get_Path().End == EMars_ThrowPreview_End::None, "still no path");
    }
}
