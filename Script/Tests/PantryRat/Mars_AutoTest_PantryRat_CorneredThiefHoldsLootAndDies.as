// R14 (a blocked thief is catchable in place) + R13 (it never goes home). The court's loaded keep-out round the den portals
// is set wider than the arena (LoadedPortalKeepOutCm 5000), so no flee candidate is admissible: the loaded thief goes
// FleeCornered and stays there, holding the same cheese, never entering a home / fade phase, re-scoring every decision
// interval (it never issues a flee move). It stays hit-able: the chef's real strike (the cleaver through the dealer's
// StrikeSweep) kills it in place, and the cheese is released once to a World holder outside the pocket.
class UMars_AutoTest_PantryRat_CorneredThiefHoldsLootAndDies : UMars_AutoTestRig_PantryRaid
{
    default _TimeoutSeconds = 60.0f;

    private FCk_Handle_PantryRat _Thief;
    private TArray<EMars_PantryRat_Phase> _Phases;
    private float32 _CorneredSince = -1.0f;
    private int32 _FleeGoalsAtCorner = 0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        _Origin = FVector(708000.0, -200000.0, -60000.0);
        _Spec = Make_CourtSpec();
        _Spec.Population.ResidentsPerDen = 1;
        _Spec.Routing.LoadedPortalKeepOutCm = 5000.0f;
        Arrange_Court(InHandle, 1);
        Make_WeaponHolder(InHandle);
        Make_ChefDealer(0, 1.0f);

        Add_CourtSteps();
        Add_Step_WaitUntil("the cheese is stolen", n"Check_Stolen", k_LongPolls, 0);
        Add_Step_WaitUntil("the thief is cornered", n"Check_Cornered", k_SlowPolls, 0);
        Add_Step_WaitSeconds("it holds the corner", 2.0f);
        Add_Step("still cornered with the same cheese, no flee move; strike it", n"Step_AssertAndStrike");
        Add_Step_WaitUntil("the corpse holds", n"Check_DeadHold", k_SlowPolls, 0);
        Add_Step("it died where it was cornered and released the cheese once", n"Step_Assert");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void OnPhaseChanged(FCk_Handle_PantryRat InRat, EMars_PantryRat_Phase InPrevious, EMars_PantryRat_Phase InNew)
    {
        _Phases.Add(InNew);
    }

    UFUNCTION()
    private void Check_Stolen(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto Rat = Get_FirstRat();
        const auto Stolen = ck::IsValid(Rat) && Rat.Get_Loot() == _CheeseItem;
        if (Stolen && ck::Is_NOT_Valid(_Thief))
        {
            _Thief = Rat;
            _Thief.BindTo_OnPhaseChanged(FMars_Delegate_PantryRat_OnPhaseChanged(this, n"OnPhaseChanged"));
        }

        auto Result = OutResult;
        Result.Set(Stolen);
    }

    UFUNCTION()
    private void Check_Cornered(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto Cornered = _Thief.Get_Phase() == EMars_PantryRat_Phase::FleeCornered;
        if (Cornered)
        {
            _CorneredSince = _Thief.Get_Clock();
            _FleeGoalsAtCorner = _Thief.Get_FleeGoals().Num();
        }

        auto Result = OutResult;
        Result.Set(Cornered);
    }

    UFUNCTION()
    private void Step_AssertAndStrike(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Thief.Get_Phase() == EMars_PantryRat_Phase::FleeCornered, "still FleeCornered after 2 s");
        Assert_True(_Thief.Get_Loot() == _CheeseItem, "holding the same cheese");
        Assert_Equals_Int(_Thief.Get_Pocket().Get_NumItems(), 1, "the pocket holds it");
        Assert_Equals_Int(_Thief.Get_FleeGoals().Num(), _FleeGoalsAtCorner, "no flee move was admitted while cornered");
        for (auto Phase : _Phases)
        { Assert_False(utils_pantry_rat::Get_IsHomeOrFadePhase(Phase), f"never a home / fade phase (saw {Phase :n})"); }

        Assert_True(Strike_RatAsTheChef(_Thief, 0, FVector(1.0, 0.0, 0.0)), "the real strike's sweep found the cornered rat's hurtbox");
    }

    UFUNCTION()
    private void Check_DeadHold(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_Thief.Get_Phase() == EMars_PantryRat_Phase::DeadHold);
    }

    UFUNCTION()
    private void Step_Assert(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Phases.Contains(EMars_PantryRat_Phase::Dying), "it died");
        Assert_Equals_Int(_Thief.Get_Death().ReleaseOperationId, 1, "one release");
        Assert_True(_Thief.Get_Death().ReleaseReceipt, "the release's receipt landed");
        const FCk_Handle Parent = _CheeseItem.Get_ParentInventory();
        FCk_Handle Pocket = _Thief.Get_Pocket();
        Assert_True(ck::IsValid(Parent) && Parent != Pocket, "the same cheese is outside the pocket");
    }
}
