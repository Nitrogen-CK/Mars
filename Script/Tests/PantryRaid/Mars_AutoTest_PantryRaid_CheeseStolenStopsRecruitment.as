// R12 (cheese stolen / removed). One resident steals the cheese itself. The pack has no cheese left, so its scent disarms
// and no empty-rat target remains. A second den with two fresh residents is then placed inside the bounds: the raid
// discovers it, yet over 3 s no emergence is asked and no rat spawns - no recruitment without scent. The loaded thief keeps
// fleeing with the same cheese the whole time.
class UMars_AutoTest_PantryRaid_CheeseStolenStopsRecruitment : UMars_AutoTestRig_PantryRaid
{
    default _TimeoutSeconds = 60.0f;

    private FCk_Handle _SecondDenEntity;
    private FCk_Handle_PantryRat _Thief;
    private int32 _NonFleeFrames = 0;
    private bool _Watching = false;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        _Origin = FVector(668000.0, -200000.0, -60000.0);
        _Spec = Make_CourtSpec();
        _Spec.Population.ResidentsPerDen = 1;
        Arrange_Court(InHandle, 0);
        utils_timer::Create_Tick(InHandle, FCk_Delegate_Timer(this, n"OnWatch"));

        Add_CourtSteps();
        Add_Step_WaitUntil("the cheese is stolen", n"Check_FirstRatLoaded", k_LongPolls, 0);
        Add_Step("the scent is gone; place a second den with two residents", n"Step_AssertDisarmedAndAddDen");
        Add_Step_WaitUntil("the raid discovered the second den", n"Check_SecondDenKnown", k_SlowPolls, 0);
        Add_Step_WaitSeconds("3 s of no scent", 3.0f);
        Add_Step("no recruitment; the thief kept fleeing with the cheese", n"Step_Assert");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void OnWatch(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        if (IsFinished() || _Watching == false)
        { return; }

        if (utils_pantry_rat::Get_IsLoadedPhase(_Thief.Get_Phase()) == false)
        { ++_NonFleeFrames; }
    }

    UFUNCTION()
    private void Step_AssertDisarmedAndAddDen(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Thief = Get_FirstRat();
        Assert_True(_Thief.Get_Loot() == _CheeseItem, "the thief holds the cheese");
        const auto Record = _Raid.TryGet_PackRecord(_Pack);
        Assert_True(Record.IsSet() && Record.GetValue().HasCheese == false && Record.GetValue().ScentArmed == false,
            "no cheese in the pack: its scent is disarmed");
        _Watching = true;

        auto DenParams = UMars_RatDen_EntityScript::Params();
        DenParams.SpawnTransform = FTransform(FRotator(0.0, 90.0, 0.0), _Origin + FVector(0.0, -450.0, 0.0));
        DenParams.Spec = FMars_RatDen_Spec(2);
        _SecondDenEntity = utils_entity_script::Request_SpawnEntity(InHandle, UMars_RatDen_EntityScript, DenParams).Get_EntityUnderConstruction();
    }

    UFUNCTION()
    private void Check_SecondDenKnown(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_Raid.Get_Dens().Num() == 2);
    }

    UFUNCTION()
    private void Step_Assert(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Watching = false;
        Assert_Equals_Int(_Raid.Get_RatCount(), 1, "no new rat");
        Assert_Equals_Int(_Raid.Get_Fragment(FMars_Fragment_PantryRaid).PendingOperations.Num(), 0, "no emergence asked");
        const auto SecondDen = _SecondDenEntity.As_RatDen();
        Assert_Equals_Int(SecondDen.Get_SlotCountIn(EMars_RatDen_SlotState::Dormant), 2, "the new den's residents stay Dormant");
        Assert_Equals_Int(_NonFleeFrames, 0, "the thief never left its flee phases");
        Assert_True(_Thief.Get_Loot() == _CheeseItem, "still the same cheese");
    }
}
