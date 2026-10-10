// The input dock takes whole food, however much of it. The station's own flow makes the cut platter: the joint is fed to the
// board, chopped once and swept onto the finished tray, so the tray carries the joint's two halves. The input dock's policy
// refuses that tray NotWhole (it has no count to refuse), and once one half is unloaded, the tray with the other half
// NotWhole still.
class UMars_AutoTest_CuttingStation_InputDockRefusesACutPlatter : UMars_AutoTestRig_CuttingStation
{
    private const FVector k_Origin = FVector(17600.0, -9000.0, -30000.0);

    private FCk_Handle_FoodPiece _Unloaded;
    private bool _HasUnloaded = false;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Spawn_Station(InHandle, k_Origin);
        Spawn_InputPlatter(InHandle, mars_items::Food_MeatSlab());
        Spawn_OutputPlatter(InHandle);

        Add_Step_WaitUntil("the empty tray is constructed", n"Check_OutputPlatterReady", 0, 10.0f);
        Add_Steps_FeedTheJoint();
        Add_Step("dock the tray", n"Step_DockOutput");
        Add_Step_WaitUntil("the tray is docked", n"Check_OutputDocked", 0, 5.0f);
        Add_Step("chop at the board's centre", n"Step_Chop");
        Add_Step_WaitUntil("the cut committed and both halves are shown", n"Check_TwoShown", 0, 5.0f);
        Add_Step("sweep the halves onto the tray", n"Step_Sweep");
        Add_Step_WaitUntil("both halves landed on the tray", n"Check_TwoOnTray", 0, 5.0f);
        Add_Step("the input policy refuses the two halves NotWhole; unload one", n"Step_AssertTwoHalvesAndUnload");
        Add_Step_WaitUntil("one half came off the tray", n"Check_OneOnTray", 0, 5.0f);
        Add_Step("the input policy refuses the one half NotWhole", n"Step_AssertNotWhole");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_Chop(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Chop();
    }

    // A chop that issued nothing settles at once so the assertions report it.
    UFUNCTION()
    private void Check_TwoShown(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set((_Issues.Num() > 0 && _Issues[0].Issued == 0) || (_PieceCuts >= 1 && _Board.Get_HeldCount() == 2 && Get_AllHeldShown()));
    }

    UFUNCTION()
    private void Check_TwoOnTray(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_OutputPlatter.Get_HeldCount() == 2);
    }

    UFUNCTION()
    private void Step_AssertTwoHalvesAndUnload(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Policy = _InputDock.Get_Spec().Policy;
        Assert_True(Policy.WholeOnly, "the input dock takes whole pieces only");
        Assert_False(Policy.RequireEmpty.IsSet(), "the input dock takes an empty platter as well as a laden one");

        const auto Refusal = utils_platter_dock::Get_Refusal(Policy, _OutputPlatter);
        Assert_True(Refusal.IsSet() && Refusal.GetValue() == EMars_PlatterDock_Refusal::NotWhole,
            f"the two halves are refused NotWhole (got [{Describe(Refusal)}])");

        const auto Held = _OutputPlatter.Get_Held();
        _Unloaded = Held[Held.Num() - 1];
        _OutputPlatter.BindTo_OnUnloaded(FMars_Delegate_Platter_OnUnloaded(this, n"OnTrayUnloaded"));
        _OutputPlatter.Request_Unload(FMars_Request_Platter_Unload(_Unloaded));
    }

    UFUNCTION()
    private void Check_OneOnTray(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_HasUnloaded && _OutputPlatter.Get_HeldCount() == 1);
    }

    UFUNCTION()
    private void Step_AssertNotWhole(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Half = _OutputPlatter.Get_Held()[0];
        Assert_False(Half.Get_IsWhole(), "the half on the tray is not whole");

        const auto Refusal = utils_platter_dock::Get_Refusal(_InputDock.Get_Spec().Policy, _OutputPlatter);
        Assert_True(Refusal.IsSet() && Refusal.GetValue() == EMars_PlatterDock_Refusal::NotWhole,
            f"the one half is refused NotWhole (got [{Describe(Refusal)}])");
    }

    private FString Describe(TOptional<EMars_PlatterDock_Refusal> InRefusal) const
    {
        if (InRefusal.IsSet() == false)
        { return "none"; }

        return f"{InRefusal.GetValue() :n}";
    }

    UFUNCTION()
    private void OnTrayUnloaded(FCk_Handle_Platter InPlatter, FCk_Handle_FoodPiece InPiece)
    {
        if (InPiece == _Unloaded)
        { _HasUnloaded = true; }
    }
}
