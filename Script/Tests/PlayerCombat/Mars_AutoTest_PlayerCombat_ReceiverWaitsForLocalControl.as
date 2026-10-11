// The receiver waits for local control: the production pawn spawned with no controller composes its entity (its state
// machine exists) but no Health, no HitZone and no TAG_MarsCombatTarget, and stays that way; once the local player
// controller possesses it, the receiver composes (Health, zone, one hurtbox) and the tag appears, with no further event
// than the possession. Isolated origin (-180000, 210000, 8000).
class UMars_AutoTest_PlayerCombat_ReceiverWaitsForLocalControl : UMars_AutoTestRig_PlayerCombat
{
    default _Origin = FVector(-180000.0, 210000.0, 8000.0);

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        SpawnFloorAndUnpossessedPawn(InHandle);

        Add_Step_WaitUntil("the unpossessed pawn's entity is linked and composed", n"Check_EntityComposed", k_SlowPolls, 0);
        Add_Step("unpossessed: no receiver", n"Step_AssertNoReceiver");
        // Deliberately a fixed window: an absent receiver has no event to wait on; the entity is already composed, so the
        // per-tick retry has had its chances.
        Add_Step_WaitFrames("let the pawn tick unpossessed", 30);
        Add_Step("still no receiver; possess the pawn", n"Step_AssertStillNoReceiverAndPossess");
        Add_Step_WaitUntil("the receiver composes and the tag appears", n"Check_ReceiverComposed", k_SlowPolls, 0);
        Add_Step("the receiver is the local player's", n"Step_AssertReceiver");
        Add_Step("tear down", n"Step_TearDown");
        Add_Step_WaitUntil("the player's entity is gone", n"Check_PlayerEntityGone", k_SlowPolls, 0);
        Run_Steps(InHandle);
    }

    private bool Get_HasTag() const
    {
        return utils_entity_tag::Has(_Player, n"TAG_MarsCombatTarget");
    }

    private void AssertNoReceiver(const FString& InWhen)
    {
        Assert_False(_Pawn.IsLocallyControlled(), f"{InWhen}: the pawn is not locally controlled");
        Assert_Invalid(Get_Health(), f"{InWhen}: no Health");
        Assert_Invalid(Get_Zone(), f"{InWhen}: no HitZone");
        Assert_False(Get_HasTag(), f"{InWhen}: no TAG_MarsCombatTarget");
    }

    UFUNCTION()
    private void Step_AssertNoReceiver(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        AssertNoReceiver("unpossessed");
    }

    UFUNCTION()
    private void Step_AssertStillNoReceiverAndPossess(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        AssertNoReceiver("unpossessed after 30 frames");
        PossessPawn();
    }

    UFUNCTION()
    private void Check_ReceiverComposed(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(ck::IsValid(Get_Health()) && ck::IsValid(Get_Hurtbox()) && Get_HasTag());
    }

    UFUNCTION()
    private void Step_AssertReceiver(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Pawn.IsLocallyControlled(), "possessed: the pawn is locally controlled");
        Assert_Valid(Get_Zone(), "possessed: the HitZone composed");
        Assert_True(utils_hit_zone::TryGet_Zone(Get_Hurtbox()) == Get_Zone(), "possessed: the hurtbox links back to the zone");
        Assert_Equals_Float(Get_Health().Get_Current(), 100.0f, 0.001f, "possessed: Health starts at its max");
    }
}

class AMars_AutoTest_PlayerCombat_ReceiverWaitsForLocalControl_Actor : AMars_AutoTestRunner_PlayerCombat
{
    default _TimeoutSeconds = 30.0f;
    default _TestEntityScriptClass = UMars_AutoTest_PlayerCombat_ReceiverWaitsForLocalControl;
}
