// With no finished tray docked the sweep is refused at the control: after a centre chop and a sweep the board still holds
// both halves, nothing was released (loose or handed off) and nothing gained a body.
class UMars_AutoTest_CuttingStation_SweepWithoutATrayIsRefused : UMars_AutoTestRig_CuttingStation
{
    private const FVector k_Origin = FVector(16800.0, -9000.0, -30000.0);

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Spawn_Station(InHandle, k_Origin);
        Spawn_InputPlatter(InHandle, mars_items::Food_MeatSlab());

        Add_Steps_FeedTheJoint();
        Add_Step("chop at the board's centre", n"Step_Chop");
        Add_Step_WaitUntil("the cut committed and both halves are shown", n"Check_TwoShown", 0, 5.0f);
        Add_Step("sweep with no tray docked", n"Step_Sweep");
        Add_Step_WaitFrames("a release would have drained by now", 10);
        Add_Step("the board still holds both halves; nothing was released", n"Step_Assert");
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
    private void Step_Assert(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_False(ck::IsValid(_OutputDock.Get_Platter()), "no tray is docked");
        Assert_Equals_Int(_PieceCuts, 1, "the chop cut the joint");
        Assert_Equals_Int(_Board.Get_HeldCount(), 2, "the board still holds both halves");
        Assert_Equals_Int(_Released.Num(), 0, "nothing was released");
        Assert_Equals_Int(_Board.Get_Released().Num(), 0, "nothing is loose");

        for (const auto& Half : _Board.Get_Held())
        { Assert_False(Get_HasBody(Half), f"[{Half.ToString()}] has no body"); }
    }
}
