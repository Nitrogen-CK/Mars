// A lethal hit downs the production player through its own Health, with the debug Downed byte left clear: 100 Blunt on
// the player's zone depletes the Health, the root state machine leaves Alive (tearing its subtree down) and enters Downed
// exactly once, the controller ignores move input and the movement component is disabled (mode None, no velocity), and
// it stays that way. Isolated origin (-200000, 210000, 8000).
class UMars_AutoTest_PlayerCombat_LethalDowned : UMars_AutoTestRig_PlayerCombat
{
    default _Origin = FVector(-200000.0, 210000.0, 8000.0);

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        SpawnFloorAndPlayer(InHandle);

        Add_Step_WaitUntil("the pawn's entity is linked, Alive and standing on the floor", n"Check_PlayerReady", k_SlowPolls, 0);
        Add_Step("the local player composed its combat receiver", n"Step_AssertLocalReceiver");
        Add_Step("hit the player's zone for 100 Blunt", n"Step_LethalHit");
        Add_Step_WaitUntil("the player is Downed with movement disabled", n"Check_DownedAndLocked", k_SlowPolls, 0);
        Add_Step("Downed once, by the Health alone; input and movement held", n"Step_AssertDowned");
        Add_Step("watch the hold", n"Step_BeginHold");
        Add_Step_WaitUntil("the player stays Downed and locked", n"Check_HeldDowned", k_SlowPolls, 0);
        Add_Step("held, and still entered once", n"Step_AssertHeld");
        Add_Step("tear down", n"Step_TearDown");
        Add_Step_WaitUntil("the player's entity is gone", n"Check_PlayerEntityGone", k_SlowPolls, 0);
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_LethalHit(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Valid(Get_Health(), "the local player composed a Health");
        Assert_Valid(Get_Zone(), "the local player composed a HitZone");
        Assert_False(Get_IsDownedFlagSet(), "the debug Downed byte is clear");

        ResetStateCounts();
        auto Zone = Get_Zone();
        Zone.Request_Hit(FMars_Request_HitZone_Hit(FMars_DamageEvent(100.0f, GameplayTags::DamageType_Mars_Blunt)));
    }

    UFUNCTION()
    private void Check_DownedAndLocked(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_IsInDowned() && Get_MovementMode() == EMovementMode::MOVE_None);
    }

    UFUNCTION()
    private void Step_AssertDowned(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Health = Get_Health();
        Assert_True(Health.Get_IsDepleted(), "the Health is depleted");
        Assert_Equals_Float(Health.Get_Current(), 0.0f, 0.001f, "the Health reads 0");
        Assert_False(Get_IsDownedFlagSet(), "the debug Downed byte is still clear: the Health downed the player");
        Assert_Equals_Int(_DownedEntries, 1, "Downed was entered once");
        Assert_False(Get_IsInAlive(), "Alive (and its locomotion and interaction subtree) is gone");
        Assert_True(Get_IsMoveInputIgnored(), "the controller ignores move input");
        Assert_Equals_Float(_Pawn.GetVelocity().Size(), 0.0, 0.01, "the character has no velocity");
    }

    UFUNCTION()
    private void Step_BeginHold(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        BeginHold();
    }

    UFUNCTION()
    private void Step_AssertHeld(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        AssertHeld("after a lethal hit");
        Assert_Equals_Int(_DownedEntries, 1, "Downed was still entered only once");
        Assert_Equals_Int(_AliveEntries, 0, "Alive was not re-entered");
    }
}

class AMars_AutoTest_PlayerCombat_LethalDowned_Actor : AMars_AutoTestRunner_PlayerCombat
{
    default _TimeoutSeconds = 30.0f;
    default _TestEntityScriptClass = UMars_AutoTest_PlayerCombat_LethalDowned;
}
