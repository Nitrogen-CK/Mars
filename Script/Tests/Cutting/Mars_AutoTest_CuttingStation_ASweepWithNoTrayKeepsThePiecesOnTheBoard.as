// A take-out with no tray strands nothing: the board refuses it and lets nothing go. The joint is fed to the board and
// chopped in two. With no finished tray the station's take-out names none (as one whose tray is gone by the time it
// applies; the control's own sweep caps itself at none up front), uncapped by the press: the board refuses it NoRoom and
// keeps the same two halves, each its member and bodiless, nothing let go and nothing placed again. The board works on as
// before: a second chop cuts the positive half (three pieces), and once a tray docks a sweep lands all three on it.
class UMars_AutoTest_CuttingStation_ASweepWithNoTrayKeepsThePiecesOnTheBoard : UMars_AutoTestRig_CuttingStation
{
    private const FVector k_Origin = FVector(24000.0, -9000.0, -30000.0);
    private const float32 k_SecondChopLateral = 8.0f;

    private TArray<FCk_Handle_FoodPiece> _Halves;
    private int32 _PlacedBeforeHandoff = 0;
    private int32 _ReleasedBeforeHandoff = 0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Spawn_Station(InHandle, k_Origin);
        Spawn_InputPlatter(InHandle, mars_items::Food_MeatSlab());
        Spawn_OutputPlatter(InHandle);

        Add_Step_WaitUntil("the empty tray is constructed", n"Check_OutputPlatterReady", k_SlowPolls, 0);
        Add_Steps_FeedTheJoint();
        Add_Step("chop at the board's centre", n"Step_Chop");
        Add_Step_WaitUntil("the cut committed and both halves are shown", n"Check_TwoShown", k_SlowPolls, 0);
        Add_Step_WaitUntil("the cleaver is back up", n"Check_ChopDone", 0, 0);
        Add_Step("no tray is docked: a take-out naming none", n"Step_HandOffWithNoTray");
        Add_Step_WaitUntil("the board refused it", n"Check_Refused", 0, 0);
        Add_Step_WaitFrames("a stray hand-off would have drained by now", 5);
        Add_Step("the board holds the same two halves, members, bodiless", n"Step_AssertKept");
        Add_Step("move the hand along the board", n"Step_MoveHand");
        Add_Step_WaitUntil("the hand reached the second chop", n"Check_HandAtSecondChop", 0, 0);
        Add_Step("chop again", n"Step_Chop");
        Add_Step_WaitUntil("the second cut committed and every piece is shown", n"Check_ThreeShown", k_SlowPolls, 0);
        Add_Step("dock the tray", n"Step_DockOutput");
        Add_Step_WaitUntil("the tray is docked", n"Check_OutputDocked", k_SlowPolls, 0);
        Add_Step("sweep", n"Step_Sweep");
        Add_Step_WaitUntil("all three landed on the tray", n"Check_AllOnTray", k_SlowPolls, 0);
        Add_Step("the tray holds the three pieces; the board is empty", n"Step_AssertSwept");
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
    private void Step_HandOffWithNoTray(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_False(ck::IsValid(_OutputDock.Get_Platter()), "no tray is docked");
        Assert_Equals_Int(_PieceCuts, 1, "the chop cut the joint");
        _Halves = _Board.Get_Held();
        _PlacedBeforeHandoff = _Placed.Num();
        _ReleasedBeforeHandoff = _Released.Num();

        FCk_Handle Station = _Station;
        utils_cooking_feed::Request_StationTakeOut(Station, FMars_Request_StationTakeOut(_Halves.Num(), FCk_Handle_Platter()));
    }

    UFUNCTION()
    private void Check_Refused(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_ReleaseRefusals.Num() > 0);
    }

    UFUNCTION()
    private void Step_AssertKept(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Halves.Num(), 2, "two halves were on the board");
        Assert_Equals_Int(_ReleaseRefusals.Num(), 1, "the take-out was refused once");
        if (_ReleaseRefusals.Num() == 1)
        { Assert_True(_ReleaseRefusals[0] == EMars_FoodBoard_ReleaseRefusal::NoRoom, f"refused NoRoom (got {_ReleaseRefusals[0] :n})"); }

        Assert_Equals_Int(_Board.Get_HeldCount(), 2, "the board still holds two pieces");
        Assert_Equals_Int(_Released.Num() - _ReleasedBeforeHandoff, 0, "the board let nothing go");
        Assert_Equals_Int(_Placed.Num() - _PlacedBeforeHandoff, 0, "and placed nothing again");
        for (const auto& Half : _Halves)
        {
            Assert_True(_Board.Get_Held().Contains(Half), f"[{Half.ToString()}] is on the board");
            Assert_True(Half.TryGet_FoodBoard() == _Board, f"[{Half.ToString()}] is the board's member");
            Assert_False(Get_HasBody(Half), f"[{Half.ToString()}] has no body");
            Assert_True(ck::Is_NOT_Valid(Half.TryGet_Platter()), f"[{Half.ToString()}] names no platter");
        }
    }

    UFUNCTION()
    private void Step_MoveHand(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        MoveHandTo(k_SecondChopLateral);
    }

    UFUNCTION()
    private void Check_HandAtSecondChop(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Math::Abs(_Cutting.Get_HandLateral() - k_SecondChopLateral) < 0.01f && _Cutting.Get_IsChopping() == false);
    }

    UFUNCTION()
    private void Check_ThreeShown(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set((_Issues.Num() > 1 && _Issues[1].Issued == 0) || (_PieceCuts >= 2 && _Board.Get_HeldCount() == 3 && Get_AllHeldShown()));
    }

    UFUNCTION()
    private void Check_AllOnTray(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_OutputPlatter.Get_HeldCount() == 3 && _OutputPlatter.Get_PendingCount() == 0 && _Board.Get_HeldCount() == 0);
    }

    UFUNCTION()
    private void Step_AssertSwept(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_PieceCuts, 2, "the second chop cut a half");
        Assert_Equals_Int(_OutputPlatter.Get_HeldCount(), 3, "the tray holds the three pieces");
        Assert_Equals_Int(_Board.Get_HeldCount(), 0, "the board holds nothing");

        FCk_Handle TrayEntity = _OutputPlatter;
        const auto TrayRoot = TrayEntity.As_Transform();
        for (const auto& Piece : _OutputPlatter.Get_Held())
        {
            Assert_True(Get_Parent(Piece) == TrayRoot, f"[{Piece.ToString()}] is a scene-node child of the tray's root");
            Assert_True(ck::Is_NOT_Valid(Piece.TryGet_FoodBoard()), f"[{Piece.ToString()}] no longer belongs to the board");
        }
    }
}
