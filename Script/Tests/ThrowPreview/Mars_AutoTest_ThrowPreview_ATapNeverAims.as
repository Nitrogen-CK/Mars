// A tap never aims. A carrier down the player's path runs the player's DropThrowIntent and ThrowPreviewFollowsArm tasks
// over HeldItemUse and a ThrowPreview (UMars_AutoTestRig_ThrowPreviewPlayerPath) and holds a rock. Drop pressed and
// released well inside ThrowHoldSeconds: the rock launches once, as a Drop, and over a settle longer than
// ThrowHoldSeconds OnAimChanged never fires and the preview never aims. Isolated origin (276000, -40000, -30000).
class UMars_AutoTest_ThrowPreview_ATapNeverAims : UMars_AutoTestRig_ThrowPreviewPlayerPath
{
    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Build_ThrowPreviewPlayerPath(InHandle, FVector(276000.0, -40000.0, -30000.0));

        Add_Steps_UntilHoldingTheFirstRock();
        Add_Step("press Drop", n"Step_PressDrop");
        Add_Step_WaitUntil("Drop reads held", n"Check_DropHeld");
        Add_Step("release Drop at once", n"Step_ReleaseDrop");
        Add_Step_WaitUntil("the rock is launched", n"Check_Launched");
        Add_Step_WaitSeconds("settle past ThrowHoldSeconds", Get_ThrowHoldSeconds() * 2.0f);
        Add_Step("dropped once; never aimed", n"Step_AssertDroppedNeverAimed");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_AssertDroppedNeverAimed(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Launches.Num(), 1, "the tap launched the rock once");
        if (_Launches.Num() > 0)
        { Assert_True(_Launches[0] == EMars_LaunchKind::Drop, f"a tap drops (got {_Launches[0] :n})"); }

        Assert_Equals_Int(_AimChanges.Num(), 0, "a tap never fires OnAimChanged");
        Assert_False(_Preview.Get_IsAiming(), "a tap never aims");
        Assert_True(_Preview.Get_Path().End == EMars_ThrowPreview_End::None, "a tap leaves no path");
    }
}
