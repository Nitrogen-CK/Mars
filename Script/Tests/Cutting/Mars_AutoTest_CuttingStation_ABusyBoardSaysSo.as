// An add-food press the busy board refuses says so on the station's label. The joint is fed to the board; an operator whose
// intents read a real add-food key presses it again while the board holds the joint: the station's own gate refuses the
// press (the board takes one joint at a time), which the feed reports (OnTransferRefused StationGate), and the station's
// label reads "board busy" on its last line within the refusal's flash (constants_station::k_RefusalFlashSeconds). Nothing
// moved: the board still holds the one joint and the feed's glove is at rest. Isolated origin (177000, -70000, -30000).
class UMars_AutoTest_CuttingStation_ABusyBoardSaysSo : UMars_AutoTestRig_CuttingStation
{
    private const FVector k_Origin = FVector(177000.0, -70000.0, -30000.0);

    private FCk_Handle_FoodPiece _Joint;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Spawn_Station(InHandle, k_Origin);
        Arm_AddFoodKey(InHandle);
        Spawn_InputPlatter(InHandle, mars_items::Food_MeatSlab());

        Add_Step_WaitUntil("the station composed its Cutting, FoodBoard, feed and docks", n"Check_StationReady", 0, 0);
        Add_Steps_ArmTheAddFoodKey();
        Add_Steps_FeedTheJoint();
        Add_Step("note the joint; press add food while the board holds it", n"Step_PressWhileBusy");
        Add_Step_WaitUntil("the press is seen", n"Check_AddFoodHeld", 0, 0);
        Add_Step_WaitUntil("the feed refused the press for the station's gate", n"Check_RefusedByTheGate", 0, 0);
        Add_Step_WaitUntil("the label says board busy within the refusal's flash", n"Check_LabelSaysBoardBusy", 0,
            constants_station::k_RefusalFlashSeconds);
        Add_Step("release add food", n"Step_ReleaseAddFood");
        Add_Step("the refusal is on the label and nothing moved", n"Step_Assert");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_PressWhileBusy(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Joint = _Board.Get_Held()[0];
        Inject_AddFoodKey(ECk_InputSource_EventType::Pressed);
    }

    UFUNCTION()
    private void Check_RefusedByTheGate(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_FeedRefusals.Contains(EMars_CookingFeed_Refusal::StationGate));
    }

    UFUNCTION()
    private void Check_LabelSaysBoardBusy(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Station.Get_ShownLabel().EndsWith("\nboard busy"));
    }

    UFUNCTION()
    private void Step_Assert(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_FeedRefusals.Num() == 1 && _FeedRefusals[0] == EMars_CookingFeed_Refusal::StationGate,
            f"the feed refused the press once, for the station's gate ({_FeedRefusals.Num()} refusals)");
        Assert_True(_Board.Get_HeldCount() == 1 && _Board.Get_Held()[0] == _Joint, "the board still holds the joint only");
        Assert_True(_Feed.Get_Phase() == EMars_CookingFeed_Phase::Idle, "the feed's glove is at rest");
        Assert_True(_Station.Get_ShownLabel().EndsWith("\nboard busy"), f"the label's last line reads board busy ({_Station.Get_ShownLabel()})");
    }
}
