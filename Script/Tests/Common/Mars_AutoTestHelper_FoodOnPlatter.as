// Puts a whole food on a platter the kernel's way, for tests: the food item is spawned under the world's transient entity (a
// piece outlives its spawner: the caller tracks it for cleanup) and, once it finishes construction (its joint Ready,
// dressed, bodied, a world item), the platter is asked to Load it. The platter is constructed by then: it finishes in its
// spawn frame, a food item only once its mesh has imported.
UCLASS()
class UMars_AutoTestHelper_FoodOnPlatter : UObject
{
    // In parallel: a spawned food entity and the platter entity it goes onto.
    private TArray<FCk_Handle> _Foods;
    private TArray<FCk_Handle> _Platters;

    // InFoodItem's food item at InWorld, loaded onto InPlatterEntity (a platter world item, constructed or under
    // construction) once constructed. Returns the food entity under construction.
    FCk_Handle Spawn_Onto(FCk_Handle InPlatterEntity, UCk_InventoryItem_Definition InFoodItem, FTransform InWorld)
    {
        auto SpawnParams = UMars_FoodItem_EntityScript::Params();
        SpawnParams.SpawnTransform = InWorld;
        SpawnParams.Definition = utils_held_item::Make_DefinitionSoft(InFoodItem);
        SpawnParams.Mode = EMars_WorldItem_Mode::World;

        auto Owner = ck::TransientEntity();
        auto Pending = utils_entity_script::Request_SpawnEntity(Owner, UMars_FoodItem_EntityScript, SpawnParams);
        utils_pending_entity_script::Promise_OnConstructed(Pending, FCk_Delegate_EntityScript_Constructed(this, n"OnFoodConstructed"));

        auto Food = Pending.Get_EntityUnderConstruction();
        _Foods.Add(Food);
        _Platters.Add(InPlatterEntity);
        return Food;
    }

    UFUNCTION()
    private void OnFoodConstructed(FCk_Handle_EntityScript InFood)
    {
        FCk_Handle Food = InFood;
        const auto Index = _Foods.FindIndex(Food);
        if (ck::EnsureIfNot(Index != -1, f"[AutoTest] Food item [{Food.ToString()}] was not spawned onto a platter by this helper"))
        { return; }

        auto Platter = _Platters[Index].As_Platter(ECk_SanityCheck::UnChecked);
        if (ck::EnsureIfNot(ck::IsValid(Platter), f"[AutoTest] [{_Platters[Index].ToString()}] is no constructed platter when its food [{Food.ToString()}] is"))
        { return; }

        Platter.Request_Load(FMars_Request_Platter_Load(Food.As_FoodPiece()));
    }
}
