// A take-out the tray has no room for says so on the station's label. The small finished tray (four places) docks empty on
// the real fry station and four fillers are loaded onto it: it is full. The operator rig's carrier takes the station through
// its Use interaction and presses its take-out key (Interact_Secondary): the station's take-out reader asks the fryer for
// the drained pieces capped at the tray's free room, none, and the fryer refuses (OnTakeOutRefused NoRoom). The station's
// label then reads "tray full" on its last line within the refusal's flash (constants_station::k_RefusalFlashSeconds), and
// nothing left the fryer or reached the tray. Isolated origin (176000, -70000, -30000).
class UMars_AutoTest_FryStation_ARefusedTakeOutSaysTrayFull : UMars_AutoTestRig_HeatOperator
{
    private const FVector k_Origin = FVector(176000.0, -70000.0, -30000.0);
    // Behind the stand, facing the counter.
    private const FVector k_CarrierLocal = FVector(-115.0, 0.0, 0.0);
    private const FVector k_TrayOffset = FVector(0.0, 300.0, 0.0);
    // A poll budget, not a ceiling: platters construct and settle and a dock arrives over seconds.
    private const int32 k_SlowPolls = 900;
    // The small tray's places, every one filled.
    private const int32 k_TrayPlaces = 4;

    private FCk_Handle _Tray;
    private TArray<FCk_Handle_FoodPiece> _Fillers;
    private TArray<EMars_CookingFeed_TakeOutRefusal> _TakeOutRefusals;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Build_HeatOperator(InHandle, EMars_AutoTest_HeatStation::Fry, k_Origin, k_CarrierLocal);
        _Tray = Spawn_EmptyPlatterOf(InHandle, k_TrayOffset, mars_items::Platter());
        for (int32 Index = 0; Index < k_TrayPlaces; ++Index)
        {
            const auto FillerWorld = FTransform(FRotator::ZeroRotator, k_Origin + k_TrayOffset + FVector(0.0, 0.0, 60.0 + 15.0 * float64(Index)));
            _Fillers.Add(Build_Box(FillerWorld, GameplayTags::Food_Meat_Beef));
        }

        Add_Steps_UntilReady();
        Add_Step_WaitUntil("the station composed its Fry, feed and docks", n"Check_HeatStationReady", 0, 0);
        Add_Step_WaitUntil("the tray is constructed and every filler is Ready", n"Check_TrayAndFillersReady", k_SlowPolls, 0);
        Add_Step("dock the empty small tray", n"Step_DockTheTray");
        Add_Step_WaitUntil("the tray is docked and arrived", n"Check_TrayDocked", k_SlowPolls, 0);
        Add_Step("fill the docked tray", n"Step_FillTheTray");
        Add_Step_WaitUntil("the fillers landed: the tray is full", n"Check_TrayFull", k_SlowPolls, 0);
        Add_Steps_TakeTheStationThroughUse();
        Add_Step_WaitUntil("the station's state machine is Operated", n"Check_StationOperated", 0, 0);
        Add_Step("press the take-out key", n"Step_PressTakeOut");
        Add_Step_WaitUntil("the fryer refused the take-out: the tray has no room", n"Check_RefusedNoRoom", 0, 0);
        Add_Step_WaitUntil("the label says tray full within the refusal's flash", n"Check_LabelSaysTrayFull", 0,
            constants_station::k_RefusalFlashSeconds);
        Add_Step("release the take-out key", n"Step_ReleaseTakeOut");
        Add_Step("the refusal is on the label, and nothing left the fryer or reached the tray", n"Step_Assert");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Check_TrayAndFillersReady(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto AllReady = Get_IsPlatterReady(_Tray, 0);
        for (const auto& Filler : _Fillers)
        { AllReady = AllReady && Filler.Get_Status() == EMars_FoodPiece_Status::Ready; }

        auto Res = OutResult;
        Res.Set(AllReady);
    }

    // The finished tray's dock takes only an empty tray, so the tray docks first and is filled there.
    UFUNCTION()
    private void Step_DockTheTray(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Fry.BindTo_OnTakeOutRefused(FMars_Delegate_Fry_OnTakeOutRefused(this, n"OnTakeOutRefused"));
        Dock(_OutputDock, _Tray);
    }

    UFUNCTION()
    private void Check_TrayDocked(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_IsDocked(_OutputDock, _Tray));
    }

    UFUNCTION()
    private void Step_FillTheTray(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Tray = _Tray.As_Platter();
        for (const auto& Filler : _Fillers)
        { Tray.Request_Load(FMars_Request_Platter_Load(Filler)); }
    }

    UFUNCTION()
    private void Check_TrayFull(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto Tray = _Tray.As_Platter();
        auto Res = OutResult;
        Res.Set(Tray.Get_HeldCount() == k_TrayPlaces && Tray.Get_FreeCount() == 0);
    }

    UFUNCTION()
    private void Check_StationOperated(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_IsStationOperated());
    }

    UFUNCTION()
    private void Step_PressTakeOut(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Press_Row(GameplayTags::Mars_Intent_Interact_Secondary);
    }

    UFUNCTION()
    private void Check_RefusedNoRoom(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_TakeOutRefusals.Contains(EMars_CookingFeed_TakeOutRefusal::NoRoom));
    }

    UFUNCTION()
    private void Check_LabelSaysTrayFull(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Station.Get_ShownLabel().EndsWith("\ntray full"));
    }

    UFUNCTION()
    private void Step_ReleaseTakeOut(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Release_Row(GameplayTags::Mars_Intent_Interact_Secondary);
    }

    UFUNCTION()
    private void Step_Assert(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_TakeOutRefusals.Num() == 1 && _TakeOutRefusals[0] == EMars_CookingFeed_TakeOutRefusal::NoRoom,
            f"the press was refused once, for no room ({_TakeOutRefusals.Num()} refusals)");
        Assert_Equals_Int(_TakenOut.Num(), 0, "the fryer handed nothing back");
        Assert_Equals_Int(_Tray.As_Platter().Get_Occupancy(), k_TrayPlaces, "the tray still holds its four fillers and nothing more");
        Assert_True(_Station.Get_ShownLabel().EndsWith("\ntray full"), f"the label's last line reads tray full ({_Station.Get_ShownLabel()})");
    }

    UFUNCTION()
    private void OnTakeOutRefused(FCk_Handle_Fry InFry, EMars_CookingFeed_TakeOutRefusal InRefusal)
    {
        _TakeOutRefusals.Add(InRefusal);
    }
}
