// With controls.sprint_toggle on, sprint is a toggle the Locomotion sub-SM keeps: on the production player (the
// player-combat rig) walking forward, a Sprint press enters Sprint (its speed modifier goes on: the Sprint state's own
// task), letting go keeps it, and the next press drops back to Walk (the Walk state's task takes the modifier off). The pawn's InputIntents read a private Sprint key
// (UMars_AutoTestHelper_UseKey, the SP row). The setting is restored at teardown. Isolated origin (-236000, 236000, 8000).
class UMars_AutoTest_Player_SprintToggleLatchesUntilTheNextPress : UMars_AutoTestRig_PlayerCombat
{
    default _Origin = FVector(-236000.0, 236000.0, 8000.0);

    private UMars_AutoTestHelper_UseKey _Keys;
    private FCk_Handle_InputIntents _Intents;
    private TOptional<bool> _ToggleBefore;
    private TOptional<FVector> _LastHandLocation;
    private int32 _HandStillPolls = 0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        // At the floor's -X end (the floor spans 1000 either side of the origin), so the run forward stays on it.
        SpawnFloorAndUnpossessedPawnAt(InHandle, _Origin - FVector(800.0, 0.0, 0.0));
        PossessPawn();

        auto Rows = TArray<FMars_AutoTestHelper_KeyRow>();
        Rows.Add(FMars_AutoTestHelper_KeyRow(EKeys::F10, GameplayTags::Mars_Intent_Sprint, n"SP"));
        _Keys = Cast<UMars_AutoTestHelper_UseKey>(NewObject(this, UMars_AutoTestHelper_UseKey));
        _Keys.Build_WithRows(InHandle, EKeys::F9, Rows);

        Add_Step_WaitUntil("the pawn's entity is linked, Alive and standing on the floor", n"Check_PlayerReady", k_SlowPolls, 0);
        Add_Step_WaitUntil("the keys are minted and the sampler records", n"Check_KeysRecording", k_SlowPolls, 0);
        Add_Step("bake the rows; turn the sprint toggle on", n"Step_SwapAndToggleOn");
        Add_Step_WaitUntil("the rows are live and the pawn reads them", n"Check_PawnReadsTheKeys", k_SlowPolls, 0);
        Add_Step("walk forward", n"Step_WalkForward");
        Add_Step_WaitUntil("the player walks", n"Check_Walking", k_SlowPolls, 0);
        Add_Step("press Sprint", n"Step_PressSprint");
        Add_Step_WaitUntil("the player sprints", n"Check_Sprinting", k_SlowPolls, 0);
        Add_Step("let go of Sprint", n"Step_AssertSprintAndRelease");
        Add_Step_WaitUntil("Sprint reads released", n"Check_SprintReleased", k_SlowPolls, 0);
        Add_Step_WaitUntil("the character runs past the walk speed", n"Check_RunningPastWalk", k_SlowPolls, 0);
        Add_Step("still sprinting after the release; press Sprint again", n"Step_AssertLatchedAndPressAgain");
        Add_Step_WaitUntil("the player walks again", n"Check_Walking", k_SlowPolls, 0);
        Add_Step("the sprint modifier is off; stop", n"Step_AssertWalkAndStop");
        // Tearing a pawn down while it still moves trips two ensures in the frame its entity outlives the actor: the
        // transform sync's root component and the hand's sway (its spring still displaced). At rest neither has work.
        Add_Step_WaitUntil("the pawn and its hand sway have come to rest", n"Check_AtRest", k_SlowPolls, 0);
        Add_Step("tear down", n"Step_RestoreAndTearDown");
        Add_Step_WaitUntil("the player's entity is gone", n"Check_PlayerEntityGone", k_SlowPolls, 0);
        Run_Steps(InHandle);
    }

    UFUNCTION(BlueprintOverride)
    void DoEndPlay(FCk_Handle InHandle)
    {
        Restore_Toggle();
        Super::DoEndPlay(InHandle);
    }

    private void Restore_Toggle()
    {
        if (_ToggleBefore.IsSet() == false)
        { return; }

        utils_game_settings::Request_SetSettingValue_Bool(FCk_Request_GameSettings_SetValue_Bool(constants_settings::k_SprintToggle, _ToggleBefore.GetValue()));
        _ToggleBefore.Reset();
    }

    // The input profile may hand the pawn its own matcher after this test's: the test's is asked for again whenever it
    // does not hold.
    private void Keep_TestMatcher()
    {
        if (_Intents.Get_Matcher() != _Keys.Get_Matcher())
        { _Intents.Request_SetMatcher(FMars_Request_InputIntents_SetMatcher(_Keys.Get_Matcher())); }
    }

    UFUNCTION()
    private void Check_KeysRecording(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Keys.Get_IsRecording());
    }

    UFUNCTION()
    private void Step_SwapAndToggleOn(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Swapped = _Keys.Request_SwapUseSet();
        if (Swapped.IsValid() == false)
        {
            FinishFailure(Swapped.Get_Error());
            return;
        }

        _ToggleBefore = TOptional<bool>(utils_game_settings::Get_SettingValue_Bool(constants_settings::k_SprintToggle, false));
        Assert_True(utils_game_settings::Request_SetSettingValue_Bool(FCk_Request_GameSettings_SetValue_Bool(constants_settings::k_SprintToggle, true)),
            "the sprint toggle setting is registered and set");
        _Intents = _Player.As_InputIntents();
    }

    UFUNCTION()
    private void Check_PawnReadsTheKeys(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Keep_TestMatcher();
        Res.Set(_Keys.Get_IsUseSetActive() && _Intents.Get_Matcher() == _Keys.Get_Matcher());
    }

    UFUNCTION()
    private void Step_WalkForward(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Intents.Request_SetMoveDirection(FMars_Request_InputIntents_SetMoveDirection(FVector(1.0, 0.0, 0.0)));
    }

    UFUNCTION()
    private void Check_Walking(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Keep_TestMatcher();
        Res.Set(_Pawn.GetVelocity().Size() > 10.0 && utils_locomotion_speed::Get_IsSprinting(_Player) == false);
    }

    UFUNCTION()
    private void Step_PressSprint(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_False(utils_locomotion_speed::Get_IsSprinting(_Player), "walking: no sprint modifier");
        _Keys.Press_Row(GameplayTags::Mars_Intent_Sprint);
    }

    UFUNCTION()
    private void Check_Sprinting(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Keep_TestMatcher();
        Res.Set(utils_locomotion_speed::Get_IsSprinting(_Player));
    }

    UFUNCTION()
    private void Step_AssertSprintAndRelease(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Intents.Get_IsIntentActive(GameplayTags::Mars_Intent_Sprint), "Sprint is still held as the sprint begins");
        _Keys.Release_Row(GameplayTags::Mars_Intent_Sprint);
    }

    UFUNCTION()
    private void Check_SprintReleased(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Intents.Get_IsIntentActive(GameplayTags::Mars_Intent_Sprint) == false);
    }

    // MaxWalkSpeed follows the attribute (UMars_SmTask_MovementSpeedSync): the pawn only outruns the walk speed while
    // the sprint speed applies.
    UFUNCTION()
    private void Check_RunningPastWalk(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Keep_TestMatcher();
        Res.Set(_Pawn.GetVelocity().Size() > float64(mars::Mars_PlayerCharacter_Config.Movement.Speeds.Walk) + 20.0);
    }

    UFUNCTION()
    private void Step_AssertLatchedAndPressAgain(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(utils_locomotion_speed::Get_IsSprinting(_Player), "toggled: letting go of Sprint keeps the player sprinting");
        _Keys.Press_Row(GameplayTags::Mars_Intent_Sprint);
    }

    UFUNCTION()
    private void Step_AssertWalkAndStop(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_False(utils_locomotion_speed::Get_IsSprinting(_Player), "the second press walked: the sprint modifier is off");
        _Keys.Release_Row(GameplayTags::Mars_Intent_Sprint);
        _Intents.Request_SetMoveDirection(FMars_Request_InputIntents_SetMoveDirection(FVector::ZeroVector));
    }

    // The pawn stands still and the swaying Hand node's offset (Player.Hand, the side node's grandparent: side node ->
    // hand bob -> hand) has not moved more than 0.1 mm in 10 polls in a row: the sway's spring has settled.
    UFUNCTION()
    private void Check_AtRest(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        const auto HandBob = utils_scene_node::Get_Parent(_Player.As_FPHands().Get_SideNode());
        const auto Hand = HandBob.As_SceneNode(ECk_SanityCheck::UnChecked).Get_Parent().As_SceneNode(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(Hand))
        {
            Res.Set(false);
            return;
        }

        const auto HandLocation = utils_scene_node::Get_Offset(Hand).GetLocation();
        const auto IsStill = _LastHandLocation.IsSet() && _LastHandLocation.GetValue().Equals(HandLocation, 0.01);
        _HandStillPolls = IsStill ? _HandStillPolls + 1 : 0;
        _LastHandLocation = TOptional<FVector>(HandLocation);
        Res.Set(_Pawn.GetVelocity().Size() < 1.0 && _Pawn.CharacterMovement.IsMovingOnGround() && _HandStillPolls >= 10);
    }

    UFUNCTION()
    private void Step_RestoreAndTearDown(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Restore_Toggle();
        TearDown();
    }
}

// The production pawn's spawn-time log noise is listed on the shared runner base. Tearing down a pawn that ran trips
// CkSway's foreign-write ensure on Player.Hand in the frames its entity outlives the actor - the same teardown noise
// PackFit_WornPackRaisesTheCrouch has shown since it was written (2026-10-17); a rig teardown defect, not this test's.
class AMars_AutoTest_Player_SprintToggleLatchesUntilTheNextPress_Actor : AMars_AutoTestRunner_PlayerCombat
{
    default _TestEntityScriptClass = UMars_AutoTest_Player_SprintToggleLatchesUntilTheNextPress;

    UFUNCTION(BlueprintOverride)
    TArray<FString> Get_ExpectedLogErrors() const
    {
        auto Out = Super::Get_ExpectedLogErrors();
        Out.Add("(Player.Hand)] offset was written by something other than Sway");
        return Out;
    }
}
