// The board takes one joint at a time: an add-food press while it holds anything is refused by the station before the feed
// sees it. An input platter carrying two bare boxes docks; an operator whose intents read a real add-food key takes the
// station and presses it: one box comes to the board. The key is released and, once the other box has frozen on the
// platter, pressed again: nothing moves. The board still holds the one box, the other still lies on the input platter, the
// feed's glove never left its rest (no phase since the first transfer ended, no reservation) and the feed itself refused
// nothing (the press never reached it). Isolated origin (22400, -9000, -30000).
class UMars_AutoTest_CuttingStation_AddFoodIsRefusedWhileTheBoardHoldsAnything : UMars_AutoTestRig_CuttingStation
{
    private const FVector k_Origin = FVector(22400.0, -9000.0, -30000.0);

    private FCk_Handle _InputPlatterSpawned;
    private TArray<FCk_Handle_FoodPiece> _Boxes;
    private FCk_Handle_FoodPiece _OnBoard;
    // How many feed phases had been entered when the second press came.
    private int32 _PhasesBeforeSecondPress = -1;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Spawn_Station(InHandle, k_Origin);
        Arm_AddFoodKey(InHandle);

        _InputPlatterSpawned = Spawn_PlatterAt(InHandle, k_InputPlatterOffset,
            FMars_Platter_SpawnSpec(FTransform::Identity, mars_items::Platter_Large()));
        for (int32 Index = 0; Index < 2; ++Index)
        { _Boxes.Add(Build_Box(FTransform(FRotator::ZeroRotator, k_Origin + k_InputPlatterOffset + FVector(100.0, 20.0 * Index, 0.0)))); }

        Add_Step_WaitUntil("the station composed its Cutting, FoodBoard, feed and docks", n"Check_StationReady", 0, 5.0f);
        Add_Steps_ArmTheAddFoodKey();
        Add_Step_WaitUntil("the input platter is constructed and both boxes are Ready", n"Check_PlatterAndBoxesReady", 0, 10.0f);
        Add_Step("load both boxes onto the input platter", n"Step_LoadBoxes");
        Add_Step_WaitUntil("both boxes landed", n"Check_BoxesLanded", 0, 8.0f);
        Add_Step("dock the input platter", n"Step_DockInput");
        Add_Step_WaitUntil("the input platter is docked", n"Check_InputDocked", 0, 5.0f);
        Add_Step("an operator takes the station", n"Step_Take");
        Add_Step_WaitUntil("the station's state machine is Operated", n"Check_Operated", 0, 2.0f);
        Add_Step_WaitUntil("the feed draws from the docked platter, its pile frozen", n"Check_FeedSourced", 0, 5.0f);
        Add_Step("press add food", n"Step_PressAddFood");
        Add_Step_WaitUntil("the press is seen", n"Check_AddFoodHeld", 0, 2.0f);
        Add_Step_WaitUntil("one box is on the board and the glove is back", n"Check_OneOnBoard", 0, 5.0f);
        Add_Step("release add food", n"Step_ReleaseAddFood");
        Add_Step_WaitUntil("the release is seen", n"Check_AddFoodReleased", 0, 2.0f);
        Add_Step_WaitUntil("the other box is frozen on the input platter", n"Check_FeedSourced", 0, 5.0f);
        Add_Step("note the feed; press add food again", n"Step_PressAgain");
        Add_Step_WaitUntil("the second press is seen", n"Check_AddFoodHeld", 0, 2.0f);
        Add_Step_WaitFrames("a transfer would have reached by now", 30);
        Add_Step("the press was refused: nothing moved", n"Step_Assert");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Check_PlatterAndBoxesReady(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto IsReady = Get_IsPlatterConstructed(_InputPlatterSpawned) && _Boxes[0].Get_Status() == EMars_FoodPiece_Status::Ready
            && _Boxes[1].Get_Status() == EMars_FoodPiece_Status::Ready;
        if (IsReady && ck::Is_NOT_Valid(_InputPlatter))
        {
            _InputPlatter = _InputPlatterSpawned.As_Platter();
            _InputPlatterItem = _InputPlatterSpawned.As_WorldItem().Get_HeldItem();
        }

        auto Res = OutResult;
        Res.Set(IsReady);
    }

    UFUNCTION()
    private void Step_LoadBoxes(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        for (const auto& Box : _Boxes)
        { _InputPlatter.Request_Load(FMars_Request_Platter_Load(Box)); }
    }

    UFUNCTION()
    private void Check_BoxesLanded(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_InputPlatter.Get_HeldCount() == 2);
    }

    UFUNCTION()
    private void Check_OneOnBoard(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Board.Get_HeldCount() == 1 && _InputPlatter.Get_HeldCount() + _InputPlatter.Get_PendingCount() == 1
            && _Feed.Get_Phase() == EMars_CookingFeed_Phase::Idle);
    }

    UFUNCTION()
    private void Step_PressAgain(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _OnBoard = _Board.Get_Held()[0];
        _PhasesBeforeSecondPress = _FeedPhases.Num();
        Assert_Equals_Int(_Feed.Get_Admitted(), 1, "the first press brought one box");
        Assert_Equals_Int(_Feed.Get_Available(), 1, "the feed counts the other box");
        Inject_AddFoodKey(ECk_InputSource_EventType::Pressed);
    }

    UFUNCTION()
    private void Step_Assert(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_OperatorIntents.Get_IsIntentActive(GameplayTags::Mars_Intent_StationAddFood), "the second press is still held");
        Assert_True(_Board.Get_HeldCount() == 1 && _Board.Get_Held()[0] == _OnBoard, "the board still holds the first box only");
        Assert_Equals_Int(_InputPlatter.Get_HeldCount(), 1, "the other box still lies on the input platter");
        Assert_Equals_Int(_Placed.Num(), 1, "one box was placed");
        Assert_True(_Feed.Get_Phase() == EMars_CookingFeed_Phase::Idle, "the feed's glove is at rest");
        Assert_False(_Feed.TryGet_ActivePiece().IsSet(), "nothing is reserved");
        Assert_Equals_Int(_FeedPhases.Num(), _PhasesBeforeSecondPress, "the glove never left its rest after the second press");
        Assert_Equals_Int(_FeedRefusals.Num(), 0, "the press never reached the feed");
        Assert_Equals_Int(_Feed.Get_Admitted(), 1, "one admission");
    }
}
