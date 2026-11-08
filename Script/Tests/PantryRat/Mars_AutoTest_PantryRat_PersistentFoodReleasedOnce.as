// R18 (persistent food death drop). The Mushroom (a Persistent Food) sits in the first low pocket, so the rat steals it: its
// own world item - the same body, never a second - mounts Carried on the rat's mouth (the carry receipt). A chef's cleaver
// strike kills the rat; it issues one Release of that world item (one release operation) and the receipt is that world item
// committing World with the same Mushroom back in its own holder (OnMountChanged -> World, once). No food definition was
// spawned: exactly one world item holds a Mushroom. The corpse then holds empty (DeadHold).
class UMars_AutoTest_PantryRat_PersistentFoodReleasedOnce : UMars_AutoTestRig_PantryRaid
{
    default _TimeoutSeconds = 60.0f;

    private FCk_Handle_PantryRat _Rat;
    private TArray<EMars_WorldItem_Mount> _MountChanges;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        _Origin = FVector(688000.0, -200000.0, -60000.0);
        _Spec = Make_CourtSpec();
        _Spec.Population.ResidentsPerDen = 1;
        _MushroomFirst = true;
        Arrange_Court(InHandle, 1);
        Make_WeaponHolder(InHandle);

        Add_CourtSteps();
        Add_Step_WaitUntil("the Mushroom is stolen and rides the rat's mouth", n"Check_Carried", k_LongPolls, 0);
        Add_Step("the same body on the rat; strike", n"Step_AssertCarriedAndStrike");
        Add_Step_WaitUntil("the corpse holds", n"Check_DeadHold", k_SlowPolls, 0);
        Add_Step("one release of the same Mushroom, its body World", n"Step_Assert");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void OnMountChanged(FCk_Handle_WorldItem InWorldItem, EMars_WorldItem_Mount InPrevious, EMars_WorldItem_Mount InNew)
    {
        _MountChanges.Add(InNew);
    }

    UFUNCTION()
    private void Check_Carried(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        _Rat = Get_FirstRat();
        FCk_Handle RatEntity = _Rat;
        auto Result = OutResult;
        Result.Set(ck::IsValid(_Rat) && _Rat.Get_HasCarryReceipt() && _Food.Get_Mount() == EMars_WorldItem_Mount::Carried
            && _Food.Get_Carrier() == RatEntity);
    }

    UFUNCTION()
    private void Step_AssertCarriedAndStrike(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Rat.Get_Loot() == _FoodItem, "the loot is the Mushroom's own item");
        Assert_True(_FoodItem.Get_PersistentWorldItem() == _Food, "still the same world item");
        Assert_True(ck::Is_NOT_Valid(_Rat.Get_CarryVisual()), "no second (visual) body for a Persistent food");
        Assert_True(_Food.Get_MountPoint() == utils_pantry_rat::Get_MouthPoint(), "it rides AttachPoint.Mars.RatMouth");
        _Food.BindTo_OnMountChanged(FMars_Delegate_WorldItem_OnMountChanged(this, n"OnMountChanged"));
        Strike_Rat(_Rat, 0);
    }

    UFUNCTION()
    private void Check_DeadHold(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_Rat.Get_Phase() == EMars_PantryRat_Phase::DeadHold);
    }

    UFUNCTION()
    private void Step_Assert(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Death = _Rat.Get_Death();
        Assert_Equals_Int(Death.ReleaseOperationId, 1, "one release operation");
        Assert_True(Death.ReleaseReceipt, "the release's receipt landed");
        FCk_Handle FoodEntity = _Food;
        Assert_True(Death.ReleaseHolder == FoodEntity, "the release was the Mushroom's own world item");
        Assert_True(_Food.Get_Mount() == EMars_WorldItem_Mount::World, "its body is World");
        const FCk_Handle FoodParent = _FoodItem.Get_ParentInventory();
        FCk_Handle FoodHolder = _Food.Get_Holder();
        Assert_True(FoodParent == FoodHolder, "the same Mushroom is back in its own holder");
        Assert_Equals_Int(_MountChanges.FindIndex(EMars_WorldItem_Mount::World) >= 0 ? 1 : 0, 1, "OnMountChanged reported World");
        auto WorldCount = 0;
        for (auto Mount : _MountChanges)
        { if (Mount == EMars_WorldItem_Mount::World) { ++WorldCount; } }
        Assert_Equals_Int(WorldCount, 1, "released once");

        auto Holders = 0;
        for (auto Candidate : utils_entity_tag::ForEach_Entity(InHandle, n"TAG_MarsWorldItem"))
        {
            auto WorldItem = Candidate.As_WorldItem(ECk_SanityCheck::UnChecked);
            if (ck::IsValid(WorldItem) && WorldItem.Get_Mode() == EMars_WorldItem_Mode::World
                && WorldItem.Get_Definition() == mars_items::Food_Mushroom())
            { ++Holders; }
        }
        Assert_Equals_Int(Holders, 1, "one Mushroom world item: no definition respawn");
        Assert_Equals_Int(_Rat.Get_Pocket().Get_NumItems(), 0, "the corpse's pocket is empty");
    }
}
