// With an empty finished tray docked, a centre chop and a sweep hand both halves to the tray: the board lets them go without
// bodies (a hand-off) and the sweep bridge loads each onto the tray, arriving from where it lay. Both end on the tray as
// scene-node children of its root, still shown, with no body; the board is empty and touched and keeps nothing released.
class UMars_AutoTest_DicingStation_SweepHandsPiecesToTheTray : UMars_AutoTestRig_DicingStation
{
    private const FVector k_Origin = FVector(12800.0, -9000.0, -30000.0);

    private TArray<FCk_Handle_FoodPiece> _Halves;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Spawn_Station(InHandle, k_Origin);
        Spawn_InputPlatter(InHandle, mars::Food_MeatSlab_Mars);
        Spawn_OutputPlatter(InHandle);

        Add_Step_WaitUntil("the empty tray is constructed", n"Check_OutputPlatterReady", 0, 10.0f);
        Add_Steps_IntakeTheJoint();
        Add_Step("dock the tray", n"Step_DockOutput");
        Add_Step_WaitUntil("the tray is docked", n"Check_OutputDocked", 0, 5.0f);
        Add_Step("chop at the board's centre", n"Step_Chop");
        Add_Step_WaitUntil("the cut committed and both halves are shown", n"Check_TwoShown", 0, 5.0f);
        Add_Step("sweep", n"Step_SweepHalves");
        Add_Step_WaitUntil("both halves landed on the tray", n"Check_OnTray", 0, 5.0f);
        Add_Step_WaitFrames("the landing poses compose", 2);
        Add_Step("both ride the tray, shown and body-less; the board is empty", n"Step_Assert");
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
    private void Step_SweepHalves(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Halves = _Board.Get_Held();
        Assert_Equals_Int(_Halves.Num(), 2, "two halves are on the board");
        utils_dicing::Request_Sweep(_Station);
    }

    UFUNCTION()
    private void Check_OnTray(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_OutputPlatter.Get_HeldCount() >= _Halves.Num());
    }

    UFUNCTION()
    private void Step_Assert(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Released.Num(), 2, "the board let both halves go");
        Assert_Equals_Int(_Board.Get_HeldCount(), 0, "the board holds nothing");
        Assert_Equals_Int(_Board.Get_Released().Num(), 0, "a hand-off keeps nothing released");
        Assert_False(_Board.Get_IsUntouched(), "a sweep touches the board");
        Assert_Equals_Int(_OutputPlatter.Get_HeldCount(), 2, "the tray holds both halves");

        FCk_Handle TrayEntity = _OutputPlatter;
        const auto TrayRoot = TrayEntity.As_Transform();
        for (const auto& Half : _Halves)
        {
            Assert_True(Half.TryGet_Platter() == _OutputPlatter, f"[{Half.ToString()}] is on the tray");
            Assert_True(Get_Parent(Half) == TrayRoot, f"[{Half.ToString()}] is a scene-node child of the tray's root");
            Assert_False(Get_HasBody(Half), f"[{Half.ToString()}] has no body");
            Assert_True(ck::Is_NOT_Valid(Half.TryGet_FoodBoard()), f"[{Half.ToString()}] no longer belongs to the board");
            Assert_True(Get_IsShown(Half), f"[{Half.ToString()}] is still shown");
        }
    }
}
