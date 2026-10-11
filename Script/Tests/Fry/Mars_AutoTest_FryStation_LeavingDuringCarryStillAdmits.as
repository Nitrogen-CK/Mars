// An operator leaving the fry station mid-transfer, the searing station's twin. The raw platter carries two meat boxes and
// docks; an operator takes the station and presses add food, then leaves while the hand carries: the leave's cancel is a
// no-op for a transfer past its grasp (the feed's own rule: it is committed), so the release lands through the bridge
// running in Idle and the fryer admits the box. The operator takes the station again, presses, and leaves while the hand
// still reaches: that transfer is Cancelled and the second box never left the raw platter.
class UMars_AutoTest_FryStation_LeavingDuringCarryStillAdmits : UMars_AutoTestRig_HeatStation
{
    private const FVector k_Origin = FVector(43600.0, -12000.0, -30000.0);
    private const FVector k_RawOffset = FVector(0.0, -300.0, 0.0);
    // Long enough phases that a leave lands inside the one under test.
    private const float32 k_ReachSeconds = 0.5f;
    private const float32 k_GraspSeconds = 0.08f;
    private const float32 k_CarrySeconds = 0.5f;
    private const float32 k_ReturnSeconds = 0.2f;
    // A poll budget, not a ceiling: platters construct, drop and settle over seconds.
    private const int32 k_SlowPolls = 900;

    private FCk_Handle _Raw;
    private TArray<FCk_Handle_FoodPiece> _Boxes;
    // The feed's phase the frame each leave was asked for.
    private EMars_CookingFeed_Phase _PhaseAtLeave = EMars_CookingFeed_Phase::Idle;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Spawn_Fry(InHandle, k_Origin, FMars_CookingFeed_TimingSpec(k_ReachSeconds, k_GraspSeconds, k_CarrySeconds, k_ReturnSeconds));
        _Raw = Spawn_Platter(InHandle, k_RawOffset, nullptr);
        for (int32 Index = 0; Index < 2; ++Index)
        {
            const auto BoxWorld = FTransform(FRotator::ZeroRotator, k_Origin + k_RawOffset + FVector(0.0, 20.0 * float64(Index), 50.0));
            _Boxes.Add(Build_Box(BoxWorld, GameplayTags::Food_Meat_Beef));
            Batter_Ledger(_Boxes.Last());
        }

        Add_Step_WaitUntil("the station composed its Fry, feed and docks", n"Check_StationReady", 0, 0);
        Add_Step_WaitUntil("the raw platter is constructed and both boxes are Ready", n"Check_RawConstructed", k_SlowPolls, 0);
        Add_Step("load both meat boxes onto it", n"Step_LoadBoxes");
        Add_Step_WaitUntil("both boxes landed", n"Check_BoxesLoaded", k_SlowPolls, 0);
        Add_Step("dock it on the raw platter dock", n"Step_DockRaw");
        Add_Step_WaitUntil("it is docked and arrived", n"Check_RawDocked", k_SlowPolls, 0);
        Add_Step("an operator takes the station", n"Step_Take");
        Add_Step_WaitUntil("Operated, and the feed draws from both boxes", n"Check_OperatedWithTwo", 0, 0);
        Add_Step("press add food", n"Step_BeginTransfer");
        Add_Step_WaitUntil("the hand carries", n"Check_Carrying", 0, 0);
        Add_Step("leave mid-carry", n"Step_LeaveNow");
        Add_Step_WaitUntil("Idle, and the carried box was admitted", n"Check_IdleAndAdmitted", k_SlowPolls, 0);
        Add_Step("the admission landed with nobody operating", n"Step_AssertAdmitted");
        Add_Step_WaitUntil("the hand is home", n"Check_FeedIdle", 0, 0);
        Add_Step("the operator takes the station again", n"Step_Take");
        Add_Step_WaitUntil("Operated, and the feed draws from the last box, settled on the platter", n"Check_OperatedWithOne", k_SlowPolls, 0);
        Add_Step("press add food", n"Step_BeginTransfer");
        Add_Step_WaitUntil("the hand reaches", n"Check_Reaching", 0, 0);
        Add_Step("leave mid-reach", n"Step_LeaveNow");
        Add_Step_WaitUntil("Idle, and the transfer was cancelled", n"Check_IdleAndCancelled", 0, 0);
        Add_Step("the last box never left the raw platter", n"Step_AssertCancelled");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Check_RawConstructed(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_IsPlatterReady(_Raw, 0) && _Boxes[0].Get_Status() == EMars_FoodPiece_Status::Ready
            && _Boxes[1].Get_Status() == EMars_FoodPiece_Status::Ready);
    }

    UFUNCTION()
    private void Step_LoadBoxes(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Platter = _Raw.As_Platter();
        for (const auto& Box : _Boxes)
        { Platter.Request_Load(FMars_Request_Platter_Load(Box)); }
    }

    UFUNCTION()
    private void Check_BoxesLoaded(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Raw.As_Platter().Get_HeldCount() == 2);
    }

    UFUNCTION()
    private void Step_DockRaw(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Dock(_InputDock, _Raw);
    }

    UFUNCTION()
    private void Check_RawDocked(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_IsDocked(_InputDock, _Raw));
    }

    UFUNCTION()
    private void Check_OperatedWithTwo(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_IsOperated() && _Feed.Get_Source() == _Raw.As_Platter() && _Feed.Get_Available() == 2);
    }

    UFUNCTION()
    private void Check_Carrying(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Feed.Get_Phase() == EMars_CookingFeed_Phase::Carry);
    }

    UFUNCTION()
    private void Step_LeaveNow(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _PhaseAtLeave = _Feed.Get_Phase();
        Leave();
    }

    UFUNCTION()
    private void Check_IdleAndAdmitted(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_IsIdle() && _Settles.Num() > 0);
    }

    UFUNCTION()
    private void Step_AssertAdmitted(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_PhaseAtLeave == EMars_CookingFeed_Phase::Carry, f"the operator left while the hand carried (got {_PhaseAtLeave :n})");
        Assert_Equals_Int(Get_SettleCount(EMars_CookingFeed_Settle::Admitted), 1, "the carried transfer settled Admitted");
        Assert_Equals_Int(Get_SettleCount(EMars_CookingFeed_Settle::Cancelled), 0, "nothing was cancelled");
        Assert_Equals_Int(Get_PieceIds().Num(), 1, "the fryer holds the admitted box");
        Assert_Equals_Int(_Raw.As_Platter().Get_Occupancy(), 1, "one box is left on the raw platter");
    }

    UFUNCTION()
    private void Check_FeedIdle(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Feed.Get_Phase() == EMars_CookingFeed_Phase::Idle);
    }

    UFUNCTION()
    private void Check_OperatedWithOne(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_IsOperated() && _Feed.Get_Available() == 1 && _Raw.As_Platter().Get_HeldCount() == 1);
    }

    UFUNCTION()
    private void Check_Reaching(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Feed.Get_Phase() == EMars_CookingFeed_Phase::Reach);
    }

    UFUNCTION()
    private void Check_IdleAndCancelled(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_IsIdle() && Get_SettleCount(EMars_CookingFeed_Settle::Cancelled) > 0);
    }

    UFUNCTION()
    private void Step_AssertCancelled(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_PhaseAtLeave == EMars_CookingFeed_Phase::Reach, f"the operator left while the hand reached (got {_PhaseAtLeave :n})");
        Assert_Equals_Int(Get_SettleCount(EMars_CookingFeed_Settle::Cancelled), 1, "the reaching transfer settled Cancelled");
        Assert_Equals_Int(Get_SettleCount(EMars_CookingFeed_Settle::Admitted), 1, "no second admission");
        Assert_Equals_Int(Get_PieceIds().Num(), 1, "the fryer still holds one box");

        const auto Raw = _Raw.As_Platter();
        Assert_Equals_Int(Raw.Get_HeldCount(), 1, "the last box is still on the raw platter");
        for (const auto& Box : _Boxes)
        {
            if (Get_PieceIds().Num() == 1 && Get_PieceHandle(Get_PieceIds()[0]) == Box)
            { continue; }

            Assert_True(Box.TryGet_Platter() == Raw, f"[{Box.ToString()}] is still on the raw platter");
        }
    }

    // The fryer admits only battered pieces: the box arrives as the batter station's take-out hands one back.
    private void Batter_Ledger(FCk_Handle_FoodPiece InBox)
    {
        auto Box = InBox;
        auto CookState = Box.Get_CookState();
        CookState.Battered = 1.0f;
        Box.Request_SetCookState(FMars_Request_FoodPiece_SetCookState(CookState));
    }
}
