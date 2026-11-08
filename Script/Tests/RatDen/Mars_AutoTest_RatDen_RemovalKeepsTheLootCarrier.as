// R26 (den removal / teardown). A loaded thief flees with the cheese; its den is then destroyed. The rat is the raid's, not
// the den's: 3 s later it is alive, still fleeing (FleeWithLoot / FleePause / FleeCornered) with the same cheese, the raid
// still owns it and has dropped the den from its registry, and the rat's flee goals keep working without the den's portals.
class UMars_AutoTest_RatDen_RemovalKeepsTheLootCarrier : UMars_AutoTestRig_PantryRaid
{
    default _TimeoutSeconds = 60.0f;

    private FCk_Handle_PantryRat _Thief;
    private int32 _GoalsAtRemoval = 0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        _Origin = FVector(704000.0, -200000.0, -60000.0);
        _Spec = Make_CourtSpec();
        _Spec.Population.ResidentsPerDen = 1;
        Arrange_Court(InHandle, 0);

        Add_CourtSteps();
        Add_Step_WaitUntil("the cheese is stolen", n"Check_FirstRatLoaded", k_LongPolls, 0);
        Add_Step("destroy the den", n"Step_RemoveDen");
        Add_Step_WaitSeconds("3 s without the den", 3.0f);
        Add_Step("the loot carrier lives on", n"Step_Assert");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_RemoveDen(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Thief = Get_FirstRat();
        _GoalsAtRemoval = _Thief.Get_FleeGoals().Num();
        utils_entity_lifetime::Request_DestroyEntity(_DenEntity);
    }

    UFUNCTION()
    private void Step_Assert(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        FCk_Handle ThiefEntity = _Thief;
        Assert_True(ck::IsValid(ThiefEntity) && utils_world_item::Get_IsEnding(ThiefEntity) == false, "the thief lives");
        Assert_True(utils_pantry_rat::Get_IsLoadedPhase(_Thief.Get_Phase()), "still fleeing");
        Assert_True(_Thief.Get_Loot() == _CheeseItem, "still the same cheese");
        Assert_True(_Raid.Get_HasRat(_Thief), "the raid still owns it");
        Assert_Equals_Int(_Raid.Get_Dens().Num(), 0, "the raid dropped the destroyed den");
        Assert_True(_Thief.Get_FleeGoals().Num() > _GoalsAtRemoval, "it kept choosing flee goals");
    }
}
