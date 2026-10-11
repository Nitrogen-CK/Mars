// Downed's lockdown waits out the Climber's own request drain before it disables movement, on the production player:
//   (a) climbing when Downed is entered: the climb ends Lost and only then is movement disabled (mode None);
//   (b) not climbing, but a Mount queued in the frame Downed is entered (from the root state machine's OnStateChanged):
//       the next drain mounts (the player is seen climbing, Flying, while Downed), the lockdown's next poll asks for a
//       second Dismount, and only after that drain does movement go to None.
// Each ends held: Downed, off the ladder, mode None for k_HoldFrames frames - no Flying or Walking after the lock and no
// unbounded wait. Between the two the byte is cleared and the player walks again. Isolated origin (-190000, 210000, 8000).
class UMars_AutoTest_PlayerCombat_ClimbRace : UMars_AutoTestRig_PlayerCombat
{
    default _TimeoutSeconds = 40.0f;
    default _Origin = FVector(-190000.0, 210000.0, 8000.0);

    private FCk_Handle_Ladder _Ladder;
    private bool _QueueMountOnDowned = false;
    private bool _MountQueuedAtDownedEntry = false;
    private bool _ClimbingAtDownedEntry = false;
    private bool _SawClimbWhileDowned = false;
    private TArray<bool> _ClimbingChanges;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        SpawnFloorAndPlayer(InHandle);

        Add_Step_WaitUntil("the pawn's entity is linked, Alive and standing on the floor", n"Check_PlayerReady", k_SlowPolls, 0);
        Add_Step("the local player composed its combat receiver", n"Step_AssertLocalReceiver");
        Add_Step("(a) put a ladder by the player and mount it", n"Step_BuildLadderAndMount");
        Add_Step_WaitUntil("(a) the player climbs, Flying", n"Check_ClimbingFlying", k_SlowPolls, 0);
        Add_Step("(a) down the climbing player", n"Step_DownWhileClimbing");
        Add_Step_WaitUntil("(a) the player is Downed, off the ladder, movement None", n"Check_DownedLockedOffLadder", k_SlowPolls, 0);
        Add_Step("(a) the climb ended Lost before the lock", n"Step_AssertSequenceA");
        Add_Step_WaitUntil("(a) the player stays Downed and locked", n"Check_HeldDowned", k_SlowPolls, 0);
        Add_Step("(a) held; clear the byte", n"Step_AssertHeldAndRevive");
        Add_Step_WaitUntil("the player is Alive and walking again", n"Check_AliveAndWalking", k_SlowPolls, 0);
        Add_Step("(b) down the player with a Mount queued in the frame Downed is entered", n"Step_DownWithQueuedMount");
        Add_Step_WaitUntil("(b) the player is Downed, off the ladder, movement None", n"Check_DownedLockedOffLadderSampling", k_SlowPolls, 0);
        Add_Step("(b) the queued Mount won the first drain and a second Dismount ended it", n"Step_AssertSequenceB");
        Add_Step_WaitUntil("(b) the player stays Downed and locked", n"Check_HeldDowned", k_SlowPolls, 0);
        Add_Step("(b) held", n"Step_AssertHeldB");
        Add_Step("tear down", n"Step_TearDown");
        Add_Step_WaitUntil("the player's entity is gone", n"Check_PlayerEntityGone", k_SlowPolls, 0);
        Run_Steps(InHandle);
    }

    protected void OnDownedEntered() override
    {
        auto Climber = Get_Climber();
        _ClimbingAtDownedEntry = Climber.Get_IsClimbing();
        if (_QueueMountOnDowned == false)
        { return; }

        _QueueMountOnDowned = false;
        _MountQueuedAtDownedEntry = true;
        Climber.Request_Mount(FMars_Request_Climber_Mount(_Ladder, EMars_Ladder_Zone::Front));
    }

    UFUNCTION()
    private void OnClimbingChanged(FCk_Handle_Climber InClimber, EMars_Climber_ClimbState InClimbState)
    {
        _ClimbingChanges.Add(InClimbState == EMars_Climber_ClimbState::Climbing);
    }

    private void AssertLastDismountLost(const FString& InWhat)
    {
        const auto LastDismount = Get_Climber().Get_LastDismount();
        Assert_True(LastDismount.IsSet() && LastDismount.GetValue() == EMars_Climber_Dismount::Lost, f"{InWhat}: the climb ended Lost");
    }

    UFUNCTION()
    private void Step_BuildLadderAndMount(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto LadderEntity = utils_entity_lifetime::Request_CreateEntity(InHandle);
        auto Root = utils_transform::Add(LadderEntity, FTransform(FRotator::ZeroRotator, _Origin + FVector(150.0, 0.0, 0.0)), ECk_Replication::DoesNotReplicate);
        _Ladder = utils_ladder::Add(Root, FMars_Ladder_Spec());
        Assert_Valid(_Ladder, "the ladder composed");

        auto Climber = Get_Climber();
        Assert_Valid(Climber, "the player has a Climber");
        Climber.BindTo_OnClimbingChanged(FMars_Delegate_Climber_OnClimbingChanged(this, n"OnClimbingChanged"));
        Climber.Request_Mount(FMars_Request_Climber_Mount(_Ladder, EMars_Ladder_Zone::Front));
    }

    UFUNCTION()
    private void Check_ClimbingFlying(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_Climber().Get_IsClimbing() && Get_MovementMode() == EMovementMode::MOVE_Flying);
    }

    UFUNCTION()
    private void Step_DownWhileClimbing(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        ResetStateCounts();
        _ClimbingChanges.Empty();
        SetDownedFlag(true);
    }

    UFUNCTION()
    private void Check_DownedLockedOffLadder(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto Climber = Get_Climber();
        auto Res = OutResult;
        Res.Set(Get_IsInDowned() && Climber.Get_IsClimbing() == false && Climber.Get_HasPendingRequests() == false
            && Get_MovementMode() == EMovementMode::MOVE_None);
    }

    UFUNCTION()
    private void Step_AssertSequenceA(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_DownedEntries, 1, "(a) Downed was entered once");
        Assert_True(_ClimbingAtDownedEntry, "(a) the player was climbing when Downed was entered");
        AssertLastDismountLost("(a)");
        Assert_Equals_Int(_ClimbingChanges.Num(), 1, "(a) one climbing change: the dismount");
        BeginHold();
    }

    UFUNCTION()
    private void Step_AssertHeldAndRevive(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        AssertHeld("(a)");
        SetDownedFlag(false);
    }

    UFUNCTION()
    private void Check_AliveAndWalking(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_IsInAlive() && Get_MovementMode() == EMovementMode::MOVE_Walking && Get_IsMoveInputIgnored() == false);
    }

    UFUNCTION()
    private void Step_DownWithQueuedMount(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_False(Get_Climber().Get_IsClimbing(), "(b) the player is not climbing before Downed");
        ResetStateCounts();
        _ClimbingChanges.Empty();
        _SawClimbWhileDowned = false;
        _MountQueuedAtDownedEntry = false;
        _QueueMountOnDowned = true;
        SetDownedFlag(true);
    }

    // Also records, every frame, whether the player is seen climbing while Downed.
    UFUNCTION()
    private void Check_DownedLockedOffLadderSampling(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto Climber = Get_Climber();
        if (Get_IsInDowned() && Climber.Get_IsClimbing())
        { _SawClimbWhileDowned = true; }

        auto Res = OutResult;
        Res.Set(_MountQueuedAtDownedEntry && Get_IsInDowned() && Climber.Get_IsClimbing() == false
            && Climber.Get_HasPendingRequests() == false && Get_MovementMode() == EMovementMode::MOVE_None);
    }

    UFUNCTION()
    private void Step_AssertSequenceB(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_DownedEntries, 1, "(b) Downed was entered once");
        Assert_True(_MountQueuedAtDownedEntry, "(b) the Mount was queued in the frame Downed was entered");
        Assert_False(_ClimbingAtDownedEntry, "(b) the player was not climbing when Downed was entered");
        Assert_True(_SawClimbWhileDowned, "(b) the queued Mount won the first drain: the player climbed while Downed");
        AssertLastDismountLost("(b)");
        Assert_Equals_Int(_ClimbingChanges.Num(), 2, "(b) two climbing changes: the queued mount, then the second dismount");
        if (_ClimbingChanges.Num() == 2)
        {
            Assert_True(_ClimbingChanges[0], "(b) the first change is the mount");
            Assert_False(_ClimbingChanges[1], "(b) the second change is the dismount");
        }

        BeginHold();
    }

    UFUNCTION()
    private void Step_AssertHeldB(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        AssertHeld("(b)");
        Assert_Equals_Int(_DownedEntries, 1, "(b) Downed was still entered once");
    }
}

class AMars_AutoTest_PlayerCombat_ClimbRace_Actor : AMars_AutoTestRunner_PlayerCombat
{
    default _TimeoutSeconds = 40.0f;
    default _TestEntityScriptClass = UMars_AutoTest_PlayerCombat_ClimbRace;
}
