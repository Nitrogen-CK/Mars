// R27 (async assets and callbacks). An empty rat watches a guarded pack. Late answers stamped for something else arrive: a
// successful claim answer naming the cheese while the rat is not claiming, a navigator answer for a goal it never asked for,
// a SpawnRat for its own (already spawned) operation, and a den MarkOutside for a foreign operation. Every one is ignored as
// stale and counted: no loot is recorded, the cheese never leaves its slot, no second rat appears, the den's slots are
// unchanged and the rat's phase and route are untouched.
class UMars_AutoTest_PantryRat_StaleCallbacksIgnored : UMars_AutoTestRig_PantryRaid
{
    default _TimeoutSeconds = 60.0f;

    private FCk_Handle_PantryRat _Rat;
    private int32 _StaleBefore = 0;
    private int32 _DenStaleBefore = 0;
    private EMars_PantryRat_RouteStatus _RouteBefore;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        _Origin = FVector(708000.0, -200000.0, -60000.0);
        _Spec = Make_CourtSpec();
        _Spec.Population.ResidentsPerDen = 1;
        Arrange_Court(InHandle, 1);
        Move_Chef(0, Get_PackSide(150.0));

        Add_CourtSteps();
        Add_Step_WaitUntil("the rat is out and watching", n"Check_Watching", k_LongPolls, 0);
        Add_Step("deliver the stale answers", n"Step_Stale");
        Add_Step_WaitSeconds("let every drain run", 0.5f);
        Add_Step("every stale answer was ignored", n"Step_Assert");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Check_Watching(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        _Rat = Get_FirstRat();
        auto Result = OutResult;
        Result.Set(ck::IsValid(_Rat) && _Rat.Get_Phase() == EMars_PantryRat_Phase::WatchGuarded
            && _Rat.Get_Route().Status != EMars_PantryRat_RouteStatus::Moving);
    }

    UFUNCTION()
    private void Step_Stale(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _StaleBefore = _Rat.Get_StaleResults();
        _DenStaleBefore = _Den.Get_StaleRequests();
        _RouteBefore = _Rat.Get_Route().Status;

        _Rat.Request_ClaimResult(FMars_Request_PantryRat_ClaimResult(_CheeseItem, _CheeseItem, ECk_Inventory_OperationResult_Transfer::Success));
        _Rat.Request_NavResult(FMars_Request_PantryRat_NavResult(_Origin + FVector(9999.0, 0.0, 0.0), true));
        const auto Links = _Rat.Get_Links();
        _Raid.Request_SpawnRat(FMars_Request_PantryRaid_SpawnRat(_Den, Links.ResidentSlot, Links.OperationId));
        _Den.Request_MarkOutside(FMars_Request_RatDen_MarkOutside(Links.ResidentSlot, Links.OperationId + 100));
    }

    UFUNCTION()
    private void Step_Assert(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Rat.Get_StaleResults() - _StaleBefore >= 2, "the claim answer and the navigator answer were stale");
        Assert_False(_Rat.Get_IsLoaded(), "no loot recorded from a stale claim answer");
        Assert_True(Get_Slot(1).Get_Item() == _CheeseItem, "the cheese never left its slot");
        Assert_True(_Raid.Get_StaleSpawns() >= 1, "the repeated SpawnRat was stale");
        Assert_Equals_Int(_Raid.Get_RatCount(), 1, "no second rat");
        Assert_True(_Den.Get_StaleRequests() - _DenStaleBefore >= 1, "the foreign MarkOutside was stale");
        Assert_True(_Den.Get_SlotState(0) == EMars_RatDen_SlotState::Outside, "the den slot is unchanged");
        Assert_True(utils_pantry_rat::Get_IsLoadedPhase(_Rat.Get_Phase()) == false, "the rat is still empty-handed");
    }
}
