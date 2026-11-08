// R11 (any ingredient eligibility). Items seeded from their real definitions: ordinary forage carrying the PantryIngredient
// marker (Root, Truffle), Persistent Food (Mushroom), the cheese itself (Monk's Rind) and a bulky Food (Meat Slab, 18 cm half
// width) are all stealable; a backpack, a weapon (Cleaver, Strike) and an unmarked sandbox item (Rock) are not. The bulky
// food rides the drag offset, an ordinary one the mouth. In the real court both low pockets - the cheese and the Mushroom -
// are eligible slots of the armed pack: cheese is the lure, not the only prize.
class UMars_AutoTest_PantryRaid_AnyIngredientIsEligible : UMars_AutoTestRig_PantryRaid
{
    default _TimeoutSeconds = 60.0f;

    private TArray<FCk_Handle_Inventory_DataOnly> _Seeded;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        _Origin = FVector(664000.0, -200000.0, -60000.0);
        _Spec = Make_CourtSpec();
        _Spec.Population.MaxActiveRats = 1;
        _Spec.Population.ResidentsPerDen = 1;
        Arrange_Court(InHandle, 1);
        Move_Chef(0, Get_PackSide(150.0));

        _Seeded.Add(Make_SeededHolder(InHandle, mars_items::Root()));
        _Seeded.Add(Make_SeededHolder(InHandle, mars_items::Truffle()));
        _Seeded.Add(Make_SeededHolder(InHandle, mars_items::Food_Mushroom()));
        _Seeded.Add(Make_SeededHolder(InHandle, mars_items::MonksRind()));
        _Seeded.Add(Make_SeededHolder(InHandle, mars_items::Food_MeatSlab()));
        _Seeded.Add(Make_SeededHolder(InHandle, mars_items::Backpack()));
        _Seeded.Add(Make_SeededHolder(InHandle, mars_items::Cleaver()));
        _Seeded.Add(Make_SeededHolder(InHandle, mars_items::Rock()));

        Add_CourtSteps();
        Add_Step_WaitUntil("every probe item is seeded", n"Check_Seeded", k_SlowPolls, 0);
        Add_Step("ingredients, foods and the cheese are stealable; the rest are not", n"Step_AssertPredicate");
        Add_Step_WaitUntil("the pack's scent arms", n"Check_Armed", k_LongPolls, 0);
        Add_Step("both low pockets are eligible slots", n"Step_AssertSlots");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Check_Seeded(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto All = true;
        for (const auto& Holder : _Seeded)
        { All = All && Holder.Get_NumItems() == 1; }

        auto Result = OutResult;
        Result.Set(All);
    }

    private FCk_Handle_Item Get_Probe(int32 InIndex) const
    {
        return _Seeded[InIndex].Get_SoleItem();
    }

    UFUNCTION()
    private void Step_AssertPredicate(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(Get_Probe(0).Has_PantryIngredient() && utils_pantry_raid::Get_IsStealable(Get_Probe(0)), "Root (forage, PantryIngredient) is stealable");
        Assert_True(utils_pantry_raid::Get_IsStealable(Get_Probe(1)), "Truffle (forage, PantryIngredient) is stealable");
        Assert_True(Get_Probe(2).Has_Food() && utils_pantry_raid::Get_IsStealable(Get_Probe(2)), "Mushroom (Food) is stealable");
        Assert_True(Get_Probe(3).Has_StinkyCheese() && utils_pantry_raid::Get_IsStealable(Get_Probe(3)), "the cheese itself is stealable");
        Assert_True(utils_pantry_raid::Get_IsStealable(Get_Probe(4)), "a bulky Food (Meat Slab) is stealable");
        Assert_False(utils_pantry_raid::Get_IsStealable(Get_Probe(5)), "a backpack is not");
        Assert_False(utils_pantry_raid::Get_IsStealable(Get_Probe(6)), "a weapon is not");
        Assert_False(utils_pantry_raid::Get_IsStealable(Get_Probe(7)), "an unmarked item is not");

        const UMars_ItemTrait_Presentation Bulky = Get_Probe(4).Get_Presentation();
        const UMars_ItemTrait_Presentation Small = Get_Probe(2).Get_Presentation();
        Assert_False(utils_pantry_rat::Get_CarryOffset(Bulky).Equals(FTransform::Identity), "the bulky food rides the drag offset");
        Assert_True(utils_pantry_rat::Get_CarryOffset(Small).Equals(FTransform::Identity), "the Mushroom rides the mouth");
    }

    UFUNCTION()
    private void Check_Armed(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto Record = _Raid.TryGet_PackRecord(_Pack);
        auto Result = OutResult;
        Result.Set(Record.IsSet() && Record.GetValue().ScentArmed);
    }

    UFUNCTION()
    private void Step_AssertSlots(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Record = _Raid.TryGet_PackRecord(_Pack).GetValue();
        Assert_True(Record.HasCheese, "the pack holds the cheese");
        Assert_True(Record.EligibleSlots.Contains(1), "the cheese's pocket is eligible");
        Assert_True(Record.EligibleSlots.Contains(2), "the Mushroom's pocket is eligible");
        Assert_False(Record.EligibleSlots.Contains(0), "the 75 cm pocket is out of reach (and empty)");
    }
}
