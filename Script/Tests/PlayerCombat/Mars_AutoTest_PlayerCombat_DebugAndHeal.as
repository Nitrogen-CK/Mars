// The debug Downed byte still downs the production player, but no longer revives a player at zero Health: byte 1 enters
// Downed; a lethal hit then depletes the Health; clearing the byte keeps the player Downed (the byte reads 0, the root
// state does not move); healing 100 with the byte clear returns the player to Alive exactly once, with Walking restored
// and the controller's move-input ignore given back (no stacked ignore left over). Isolated origin
// (-195000, 210000, 8000).
class UMars_AutoTest_PlayerCombat_DebugAndHeal : UMars_AutoTestRig_PlayerCombat
{
    default _Origin = FVector(-195000.0, 210000.0, 8000.0);

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        SpawnFloorAndPlayer(InHandle);

        Add_Step_WaitUntil("the pawn's entity is linked, Alive and standing on the floor", n"Check_PlayerReady", k_SlowPolls, 0);
        Add_Step("the local player composed its combat receiver", n"Step_AssertLocalReceiver");
        Add_Step("set the debug Downed byte", n"Step_SetByte");
        Add_Step_WaitUntil("the player is Downed with movement disabled", n"Check_DownedAndLocked", k_SlowPolls, 0);
        Add_Step("Downed once by the byte; hit the player for 100", n"Step_AssertDownedAndHit");
        Add_Step_WaitUntil("the Health is depleted", n"Check_Depleted", k_SlowPolls, 0);
        Add_Step("clear the byte at zero Health", n"Step_ClearByte");
        Add_Step_WaitUntil("the byte reads 0", n"Check_ByteClear", k_SlowPolls, 0);
        // Deliberately a fixed window: staying Downed has no event to wait on; the byte already reads 0, so the
        // condition has had what it needs to revive.
        Add_Step_WaitSeconds("give the root state the chance to revive", 0.3f);
        Add_Step("still Downed; heal 100", n"Step_AssertStillDownedAndHeal");
        Add_Step_WaitUntil("the player is Alive and walking", n"Check_AliveAndWalking", k_SlowPolls, 0);
        Add_Step("revived once, input given back", n"Step_AssertRevived");
        Add_Step_WaitSeconds("watch for a second transition", 0.3f);
        Add_Step("each transition happened once", n"Step_AssertOnce");
        Add_Step("tear down", n"Step_TearDown");
        Add_Step_WaitUntil("the player's entity is gone", n"Check_PlayerEntityGone", k_SlowPolls, 0);
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_SetByte(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_False(Get_IsMoveInputIgnored(), "Alive: the controller takes move input");
        ResetStateCounts();
        SetDownedFlag(true);
    }

    UFUNCTION()
    private void Check_DownedAndLocked(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_IsInDowned() && Get_MovementMode() == EMovementMode::MOVE_None);
    }

    UFUNCTION()
    private void Step_AssertDownedAndHit(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_DownedEntries, 1, "the byte entered Downed once");
        Assert_False(Get_Health().Get_IsDepleted(), "the Health is not what downed the player");
        Assert_True(Get_IsMoveInputIgnored(), "Downed: the controller ignores move input");

        auto Zone = Get_Zone();
        Zone.Request_Hit(FMars_Request_HitZone_Hit(FMars_DamageEvent(100.0f, GameplayTags::DamageType_Mars_Blunt)));
    }

    UFUNCTION()
    private void Check_Depleted(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_Health().Get_IsDepleted());
    }

    UFUNCTION()
    private void Step_ClearByte(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        SetDownedFlag(false);
    }

    UFUNCTION()
    private void Check_ByteClear(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_IsDownedFlagSet() == false);
    }

    UFUNCTION()
    private void Step_AssertStillDownedAndHeal(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(Get_IsInDowned(), "a cleared byte at zero Health keeps the player Downed");
        Assert_Equals_Int(_AliveEntries, 0, "Alive was not re-entered");
        Assert_True(Get_MovementMode() == EMovementMode::MOVE_None, f"movement stays disabled (mode {Get_MovementMode() :n})");
        Assert_True(Get_IsMoveInputIgnored(), "the controller still ignores move input");

        auto Health = Get_Health();
        Health.Request_Heal(FMars_Request_Health_Heal(100.0f));
    }

    UFUNCTION()
    private void Check_AliveAndWalking(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_IsInAlive() && Get_MovementMode() == EMovementMode::MOVE_Walking);
    }

    UFUNCTION()
    private void Step_AssertRevived(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Health = Get_Health();
        Assert_False(Health.Get_IsDepleted(), "the heal cleared the depletion");
        Assert_Equals_Float(Health.Get_Current(), 100.0f, 0.001f, "the Health reads 100");
        Assert_Equals_Int(_AliveEntries, 1, "Alive was entered once");
        Assert_False(Get_IsMoveInputIgnored(), "the controller's move-input ignore was given back: none is left stacked");
    }

    UFUNCTION()
    private void Step_AssertOnce(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_DownedEntries, 1, "Downed was entered once in all");
        Assert_Equals_Int(_AliveEntries, 1, "Alive was entered once in all");
        Assert_True(Get_IsInAlive(), "the player is still Alive");
        Assert_True(Get_MovementMode() == EMovementMode::MOVE_Walking, f"still walking (mode {Get_MovementMode() :n})");
        Assert_False(Get_IsMoveInputIgnored(), "still taking move input");
    }
}

class AMars_AutoTest_PlayerCombat_DebugAndHeal_Actor : AMars_AutoTestRunner_PlayerCombat
{
    default _TimeoutSeconds = 30.0f;
    default _TestEntityScriptClass = UMars_AutoTest_PlayerCombat_DebugAndHeal;
}
