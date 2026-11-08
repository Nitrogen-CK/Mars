// R04 (no target returns empty rats). One resident; a chef guards the pack so the rat watches instead of stealing. The test
// then takes the cheese out of its pocket (into a plain holder): the pack has no cheese, so no target remains. After
// NoTargetReturnSeconds the empty rat goes ReturnEmpty, walks to the den's ReturnAdmission marker, is admitted (DenEnter)
// with its pocket empty, its slot is Dormant again (the proxy shows it) and the raid retires the rat entity. Nothing was
// stolen.
class UMars_AutoTest_RatDen_NoTargetReturnsEmptyRatsHome : UMars_AutoTestRig_PantryRaid
{
    default _TimeoutSeconds = 60.0f;

    private FCk_Handle_PantryRat _Rat;
    private FCk_Handle_Inventory_DataOnly _Elsewhere;
    private TArray<EMars_PantryRat_Phase> _Phases;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        _Origin = FVector(636000.0, -200000.0, -60000.0);
        _Spec = Make_CourtSpec();
        _Spec.Population.ResidentsPerDen = 1;
        Arrange_Court(InHandle, 1);
        Move_Chef(0, Get_PackSide(150.0));
        _Elsewhere = Make_OpenHolder(InHandle);

        Add_CourtSteps();
        Add_Step_WaitUntil("the rat is out and watching the guarded pack", n"Check_Watching", k_LongPolls, 0);
        Add_Step("take the cheese out of the pack", n"Step_RemoveCheese");
        Add_Step_WaitUntil("the rat was admitted home and retired", n"Check_Home", k_LongPolls, 0);
        Add_Step("it went ReturnEmpty -> DenEnter empty; the slot is Dormant", n"Step_Assert");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void OnPhaseChanged(FCk_Handle_PantryRat InRat, EMars_PantryRat_Phase InPrevious, EMars_PantryRat_Phase InNew)
    {
        _Phases.Add(InNew);
    }

    UFUNCTION()
    private void Check_Watching(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto Rat = Get_FirstRat();
        if (ck::IsValid(Rat) && ck::Is_NOT_Valid(_Rat))
        {
            _Rat = Rat;
            _Rat.BindTo_OnPhaseChanged(FMars_Delegate_PantryRat_OnPhaseChanged(this, n"OnPhaseChanged"));
        }

        auto Result = OutResult;
        Result.Set(ck::IsValid(_Rat) && _Rat.Get_Phase() == EMars_PantryRat_Phase::WatchGuarded);
    }

    UFUNCTION()
    private void Step_RemoveCheese(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Source = Get_Slot(1).Get_Inventory();
        Source.Request_TransferItem_ToDataOnly(FCk_Request_Inventory_TransferItem_ToDataOnly(_CheeseItem, _Elsewhere),
            FCk_Delegate_Inventory_OnOperationResult_Transfer());
    }

    UFUNCTION()
    private void Check_Home(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_Phases.Contains(EMars_PantryRat_Phase::DenEnter) && _Raid.Get_RatCount() == 0
            && _Den.Get_SlotState(0) == EMars_RatDen_SlotState::Dormant);
    }

    UFUNCTION()
    private void Step_Assert(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto ReturnAt = _Phases.FindIndex(EMars_PantryRat_Phase::ReturnEmpty);
        const auto EnterAt = _Phases.FindIndex(EMars_PantryRat_Phase::DenEnter);
        Assert_True(ReturnAt >= 0 && EnterAt > ReturnAt, "ReturnEmpty, then DenEnter");
        Assert_Equals_Int(_Den.Get_RefusedReturns(), 0, "the den admitted it (empty pocket)");
        Assert_True(_Den.Get_EyeSlot() == TOptional<int32>(0), "the proxy shows the resident home again");
        const FCk_Handle CheeseParent = _CheeseItem.Get_ParentInventory();
        FCk_Handle Elsewhere = _Elsewhere;
        Assert_True(CheeseParent == Elsewhere, "the cheese is where the test put it");
        Assert_True(Get_Slot(2).Get_Item() == _FoodItem, "the Mushroom was never stolen");
        Assert_Equals_Int(_Raid.Get_LeasesGranted(), 0, "no lease was ever granted");
    }
}
