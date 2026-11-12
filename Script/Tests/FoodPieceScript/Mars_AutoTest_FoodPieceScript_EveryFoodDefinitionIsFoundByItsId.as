// Every food definition another machine can name has a valid, unique Data.Id that finds it again, and the food trait of
// each of the nine food item definitions names a definition with a valid id. An invalid or unknown id finds nothing.
class UMars_AutoTest_FoodPieceScript_EveryFoodDefinitionIsFoundByItsId : UCk_AutoTest_Base
{
    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Add_Step("every definition is found by its id; every food item's food has one", n"Step_Assert");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_Assert(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Definitions = utils_food::Get_Definitions();
        Assert_Equals_Int(Definitions.Num(), 9, "nine food definitions");

        TArray<FGameplayTag> Seen;
        for (auto Definition : Definitions)
        {
            const auto Id = Definition.Data.Id;
            Assert_True(Id.IsValid(), f"[{Definition.GetName()}] has a valid id");
            Assert_False(Seen.Contains(Id), f"[{Definition.GetName()}]'s id [{Id.ToString()}] is unique");
            Seen.Add(Id);
            Assert_True(utils_food::Find_Definition(Id) == Definition, f"[{Definition.GetName()}] is found by its id [{Id.ToString()}]");
        }

        Assert_True(utils_food::Find_Definition(FGameplayTag()) == nullptr, "an invalid id finds nothing");
        Assert_True(utils_food::Find_Definition(GameplayTags::Food_Meat) == nullptr, "an unknown id finds nothing");

        TArray<UCk_InventoryItem_Definition> Items;
        Items.Add(mars_items::Food_MeatSlab());
        Items.Add(mars_items::Food_MushroomSlice());
        Items.Add(mars_items::Food_Drumstick());
        Items.Add(mars_items::Food_Tentacle());
        Items.Add(mars_items::Food_Puffer());
        Items.Add(mars_items::Food_SpikedBerry());
        Items.Add(mars_items::Food_Mushroom());
        Items.Add(mars_items::Food_Pickle());
        Items.Add(mars_items::Food_Fish());
        for (auto Item : Items)
        {
            const UMars_ItemTrait_Food FoodTrait = Item.Get_ItemTraitByClass(UMars_ItemTrait_Food);
            const auto HasFood = ck::IsValid(FoodTrait) && ck::IsValid(FoodTrait.Food);
            Assert_True(HasFood, f"[{Item.GetName()}] has a Food trait naming a food");
            if (HasFood)
            { Assert_True(FoodTrait.Food.Data.Id.IsValid(), f"[{Item.GetName()}]'s food [{FoodTrait.Food.GetName()}] has a valid id"); }
        }
    }
}
