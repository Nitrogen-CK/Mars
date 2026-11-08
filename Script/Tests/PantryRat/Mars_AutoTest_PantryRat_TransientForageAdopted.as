// R19 (transient ingredient death drop). The rat steals the Monk's Rind (Transient): it rides as one Visual world item on
// the mouth. A chef's cleaver strike kills the rat; it spawns one World-mode world item that ADOPTS the original item from
// the pocket (SourceItem / SourceInventory, never a definition seed), owned by the world, not the rat. The receipt is that
// holder holding the same item handle; the carry visual is gone; exactly one world item presents a Monk's Rind (no clone).
class UMars_AutoTest_PantryRat_TransientForageAdopted : UMars_AutoTestRig_PantryRaid
{
    default _TimeoutSeconds = 60.0f;

    private FCk_Handle_PantryRat _Rat;
    private FCk_Handle _CarryVisual;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        _Origin = FVector(692000.0, -200000.0, -60000.0);
        _Spec = Make_CourtSpec();
        _Spec.Population.ResidentsPerDen = 1;
        Arrange_Court(InHandle, 1);
        Make_WeaponHolder(InHandle);

        Add_CourtSteps();
        Add_Step_WaitUntil("the cheese is stolen", n"Check_FirstRatLoaded", k_LongPolls, 0);
        Add_Step("one carry visual on the mouth; strike", n"Step_AssertCarryAndStrike");
        Add_Step_WaitUntil("the corpse holds", n"Check_DeadHold", k_SlowPolls, 0);
        Add_Step("the original item adopted by a new world holder", n"Step_Assert");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_AssertCarryAndStrike(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Rat = Get_FirstRat();
        _CarryVisual = _Rat.Get_CarryVisual();
        Assert_True(ck::IsValid(_CarryVisual) && _CarryVisual.Is_WorldItem(), "one Visual world item carries the cheese");
        Assert_True(_CarryVisual.As_WorldItem().Get_Mode() == EMars_WorldItem_Mode::Visual, "it is Visual mode (no item of its own)");
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
        Assert_True(Death.ReleaseReceipt, "the adoption receipt landed");
        const auto Holder = Death.ReleaseHolder.As_WorldItem();
        Assert_True(Holder.Get_HeldItem() == _CheeseItem, "the new holder holds the original cheese handle");
        const FCk_Handle CheeseParent = _CheeseItem.Get_ParentInventory();
        FCk_Handle NewHolder = Holder.Get_Holder();
        Assert_True(CheeseParent == NewHolder, "the cheese's parent is the new holder");
        FCk_Handle RatEntity = _Rat;
        Assert_False(utils_entity_lifetime::Get_LifetimeOwner(Death.ReleaseHolder) == RatEntity, "the drop is not the rat's");
        Assert_False(ck::IsValid(_CarryVisual) && utils_world_item::Get_IsEnding(_CarryVisual) == false, "the carry visual is gone");

        auto Presenters = 0;
        for (auto Candidate : utils_entity_tag::ForEach_Entity(InHandle, n"TAG_MarsWorldItem"))
        {
            auto WorldItem = Candidate.As_WorldItem(ECk_SanityCheck::UnChecked);
            // This court only: an earlier test in the same lane may leave its own Monk's Rind in the world (Phase 9: the
            // lane re-partition put ReleaseRefusalBlocksCleanup's kept corpse loot ahead of this test).
            if (ck::IsValid(WorldItem) && WorldItem.Get_Mode() == EMars_WorldItem_Mode::World
                && WorldItem.Get_Definition() == mars_items::MonksRind() && utils_world_item::Get_IsEnding(Candidate) == false
                && (utils_transform::Get_EntityCurrentLocation(Candidate.As_Transform()) - _Origin).Size2D() < 1500.0)
            { ++Presenters; }
        }
        Assert_Equals_Int(Presenters, 1, "one World Monk's Rind: no clone");
        Assert_Equals_Int(_Rat.Get_Pocket().Get_NumItems(), 0, "the corpse's pocket is empty");
    }
}
