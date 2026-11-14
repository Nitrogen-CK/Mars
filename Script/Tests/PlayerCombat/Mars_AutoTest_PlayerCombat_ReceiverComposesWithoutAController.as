// The receiver does not wait for a controller: the production pawn spawned with none composes a Health at its max, a
// HitZone and one hurtbox linked back to it, without TAG_MarsCombatTarget or TAG_MarsSharedCombatTarget, and stays that
// way; once the local player controller possesses it, the same Health, zone and hurtbox remain (no second receiver) and
// both tags appear. Isolated origin (-180000, 210000, 8000).
class UMars_AutoTest_PlayerCombat_ReceiverComposesWithoutAController : UMars_AutoTestRig_PlayerCombat
{
    default _Origin = FVector(-180000.0, 210000.0, 8000.0);

    private FCk_Handle_Health _FirstHealth;
    private FCk_Handle_HitZone _FirstZone;
    private FCk_Handle _FirstHurtbox;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        SpawnFloorAndUnpossessedPawn(InHandle);

        Add_Step_WaitUntil("the unpossessed pawn's entity is linked and composed", n"Check_EntityComposed", k_SlowPolls, 0);
        Add_Step("unpossessed: the receiver, no tag", n"Step_AssertUnpossessedReceiver");
        // Deliberately a fixed window: a tag that must stay absent and a receiver that must not be rebuilt have no event
        // to wait on.
        Add_Step_WaitFrames("let the pawn tick unpossessed", k_HoldFrames);
        Add_Step("still the same receiver, no tag; possess the pawn", n"Step_AssertStillAndPossess");
        Add_Step_WaitUntil("the tag appears", n"Check_TagPresent", k_SlowPolls, 0);
        Add_Step("possessed: the same receiver, now tagged", n"Step_AssertPossessedReceiver");
        Add_Step("tear down", n"Step_TearDown");
        Add_Step_WaitUntil("the player's entity is gone", n"Check_PlayerEntityGone", k_SlowPolls, 0);
        Run_Steps(InHandle);
    }

    private bool Get_HasTag() const
    {
        return utils_entity_tag::Has(_Player, n"TAG_MarsCombatTarget");
    }

    private bool Get_HasSharedTag() const
    {
        return utils_entity_tag::Has(_Player, n"TAG_MarsSharedCombatTarget");
    }

    private void AssertUntaggedReceiver(const FString& InWhen)
    {
        Assert_False(_Pawn.IsLocallyControlled(), f"{InWhen}: the pawn is not locally controlled");
        Assert_Valid(Get_Health(), f"{InWhen}: a Health");
        if (ck::IsValid(Get_Health()))
        { Assert_Equals_Float(Get_Health().Get_Current(), Get_Health().Get_Max(), 0.001f, f"{InWhen}: the Health is at its max"); }

        Assert_Valid(Get_Zone(), f"{InWhen}: a HitZone");
        Assert_Valid(Get_Hurtbox(), f"{InWhen}: one hurtbox");
        if (ck::IsValid(Get_Hurtbox()))
        { Assert_True(utils_hit_zone::TryGet_Zone(Get_Hurtbox()) == Get_Zone(), f"{InWhen}: the hurtbox links back to the zone"); }

        Assert_False(Get_HasTag(), f"{InWhen}: no TAG_MarsCombatTarget");
        Assert_False(Get_HasSharedTag(), f"{InWhen}: no TAG_MarsSharedCombatTarget");
    }

    private void AssertSameReceiver(const FString& InWhen)
    {
        Assert_True(Get_Health() == _FirstHealth, f"{InWhen}: the same Health");
        Assert_True(Get_Zone() == _FirstZone, f"{InWhen}: the same HitZone");
        Assert_True(Get_Hurtbox() == _FirstHurtbox, f"{InWhen}: the same one hurtbox");
    }

    UFUNCTION()
    private void Step_AssertUnpossessedReceiver(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        AssertUntaggedReceiver("unpossessed");
        _FirstHealth = Get_Health();
        _FirstZone = Get_Zone();
        _FirstHurtbox = Get_Hurtbox();
    }

    UFUNCTION()
    private void Step_AssertStillAndPossess(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        AssertUntaggedReceiver(f"unpossessed after {k_HoldFrames} frames");
        AssertSameReceiver(f"unpossessed after {k_HoldFrames} frames");
        PossessPawn();
    }

    UFUNCTION()
    private void Check_TagPresent(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_HasTag());
    }

    UFUNCTION()
    private void Step_AssertPossessedReceiver(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Pawn.IsLocallyControlled(), "possessed: the pawn is locally controlled");
        Assert_True(Get_HasTag(), "possessed: TAG_MarsCombatTarget");
        Assert_True(Get_HasSharedTag(), "possessed: TAG_MarsSharedCombatTarget");
        AssertSameReceiver("possessed");
        Assert_Equals_Int(Get_Zone().Get_Hurtboxes().Num(), 1, "possessed: the zone still has one hurtbox");
        Assert_Equals_Float(Get_Health().Get_Current(), Get_Health().Get_Max(), 0.001f, "possessed: the Health is still at its max");
    }
}

class AMars_AutoTest_PlayerCombat_ReceiverComposesWithoutAController_Actor : AMars_AutoTestRunner_PlayerCombat
{
    default _TimeoutSeconds = 30.0f;
    default _TestEntityScriptClass = UMars_AutoTest_PlayerCombat_ReceiverComposesWithoutAController;
}
