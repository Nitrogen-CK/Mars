// An empty-handed pull held through the whole Grip + Tug (0.7 s) finishes Succeeded and releases exactly one root (reason
// Plucked) as an ordinary World-mode Screaming Turnip yield; the bed is exhausted and its Use target claimed (disabled). A
// second pull on the emptied bed releases nothing.
class UMars_AutoTest_ScreamingTurnip_AnUnarmedPullReleasesOneRootAndEmptiesTheBed : UMars_AutoTestRig_ScreamingTurnip
{
    default _Origin = FVector(430000.0, 18000.0, -30000.0);

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        _Carrier = InHandle;
        Build_Floor(InHandle);
        Spawn_Bed(InHandle);

        Add_Step_WaitUntil("the bed is constructed", n"Check_BedReady");
        Add_Step("start a pull with free hands", n"Step_Pull");
        Add_Step_WaitUntil("the pull finishes", n"Check_PullFinished", k_SlowPolls);
        Add_Step_WaitUntil("one root is released", n"Check_Released", k_SlowPolls);
        Add_Step("one Plucked yield, the bed exhausted", n"Step_AssertReleased");
        Add_Step_WaitUntil("the yield seeded as a Screaming Turnip with its kernel", n"Check_YieldSeeded", k_SlowPolls);
        Add_Step_WaitUntil("the target is claimed", n"Check_TargetDisabled", k_SlowPolls);
        Add_Step("pull again on the empty bed", n"Step_Pull");
        Add_Step_WaitSeconds("a second pull would have completed in this window", 1.2f);
        Add_Step("the second pull released nothing", n"Step_AssertNoSecond");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_Pull(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Start_Pull();
    }

    UFUNCTION()
    private void Check_PullFinished(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_PullResults.Num() >= 1);
    }

    UFUNCTION()
    private void Check_Released(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Released.Num() >= 1);
    }

    UFUNCTION()
    private void Step_AssertReleased(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_PullResults[0] == ECk_SucceededFailed::Succeeded, "the held pull finishes Succeeded");
        Assert_Equals_Int(_Released.Num(), 1, "exactly one release");
        Assert_True(_ReleaseReasons[0] == EMars_Forage_ReleaseReason::Plucked, "released Plucked");
        Assert_True(_BedForage.Get_IsExhausted(), "the bed is exhausted");
        Assert_Equals_Int(_BedForage.Get_ChargesLeft(), 0, "no charge left");
        Assert_Equals_Int(_ExhaustedCount, 1, "OnExhausted once");
        Assert_False(_BedForage.Get_IsRegrowPending(), "a one-shot bed never regrows");
    }

    UFUNCTION()
    private void Check_YieldSeeded(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto WorldItem = _Released[0].As_WorldItem(ECk_SanityCheck::UnChecked);
        const auto Seeded = ck::IsValid(WorldItem) && WorldItem.Get_Mode() == EMars_WorldItem_Mode::World
            && ck::IsValid(WorldItem.Get_HeldItem()) && WorldItem.Get_HeldItem().Get_Definition() == mars_items::ScreamingTurnip();
        auto Res = OutResult;
        Res.Set(Seeded && _Released[0].Is_ScreamingTurnip());
    }

    UFUNCTION()
    private void Check_TargetDisabled(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_BedInteractable.Get_EnableDisable() == ECk_EnableDisable::Disable);
    }

    UFUNCTION()
    private void Step_AssertNoSecond(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Released.Num(), 1, "the second pull released nothing");
        Assert_Equals_Int(_BedForage.Get_ReleasedCount(), 1, "the Forage released once");
        Assert_Equals_Int(Get_YieldCountNearBed(InHandle), 1, "one root lies by the bed");
        Assert_True(_BedInteractable.Get_IsDisabledFor(EMars_Interactable_DisableReason::Exhausted), "the target stays claimed");
    }
}
