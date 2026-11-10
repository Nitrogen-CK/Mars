// The player's tasks the jab test runs on its carrier: the player-path rig's (the view trace -> focus, the Use row ->
// resolver intent, the held-item -> gloves link, the Hands sub-SM) and the Primary row -> jab task.
class UMars_AutoTestState_PlayerPathPunchRig : UCk_SmState_EntityScript
{
    UFUNCTION(BlueprintOverride)
    void DoDefineState(FCk_Handle_SmState_UnderConstruction& InHandle)
    {
        AddTask(InHandle, UMars_SmTask_InteractionFocus);
        AddTask(InHandle, UMars_SmTask_UseIntentToResolver);
        AddTask(InHandle, UMars_SmTask_HeldItemDrivesHands);
        AddTask(InHandle, UMars_SmTask_HandsSubSm);
        AddTask(InHandle, UMars_SmTask_PunchIntent);
    }
}

// A Primary press is a jab only with empty hands and nothing focused. On the player-path carrier (with the Punch feature
// and a Primary row on a key of its own), looking at nothing: a press throws the left fist, and a second press the
// right - one jab per press, the hands alternating. With the view on a rock lying on the floor (focused, its pickup
// prompt offered) a press throws nothing: the prompt owns the press. Use then picks the rock up, and with the rock in the
// hands and the view off everything a press throws nothing either. Isolated origin (96000, -40000, -30000).
class UMars_AutoTest_Player_PrimaryWithEmptyHandsAndNothingFocusedPunches : UMars_AutoTestRig_PlayerPath
{
    default _TimeoutSeconds = 40.0f;

    private const FVector k_Origin = FVector(96000.0, -40000.0, -30000.0);
    private const FVector k_RockLocal = FVector(120.0, 0.0, 16.0);
    // A press's throw request drains on the next frame; a window this long would show a jab that should not be thrown.
    private const float32 k_NoJabSeconds = 0.5f;

    private FCk_Handle_Punch _Punch;
    private TArray<EMars_Hand> _Thrown;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Build_PlayerPath(InHandle, k_Origin);
        _Punch = utils_punch::Add(_Carrier, FMars_Punch_Spec());
        _Punch.BindTo_OnThrown(FMars_Delegate_Punch_OnThrown(this, n"OnThrown"));
        _PathRockEntity = Spawn_WorldItem(InHandle, mars_items::Rock(), k_RockLocal);

        Add_Steps_UntilReady();
        Add_Step_WaitUntil("the rock lies still on the floor", n"Check_PathRockStill", 0, 0);

        Add_Step("looking at nothing with empty hands: press Primary", n"Step_AssertFreeAndPressPrimary");
        Add_Step_WaitUntil("a jab is thrown", n"Check_OneThrown", 0, 0);
        Add_Step("release Primary", n"Step_ReleasePrimary");
        Add_Step_WaitUntil("the Primary row releases", n"Check_PrimaryReleased", 0, 0);
        Add_Step("press Primary again", n"Step_PressPrimary");
        Add_Step_WaitUntil("a second jab is thrown", n"Check_TwoThrown", 0, 0);
        Add_Step("left then right; release Primary and turn the view onto the rock", n"Step_AssertLeftRightReleaseAndAim");
        Add_Step_WaitUntil("the rock is focused and the Primary row is released", n"Check_RockFocusedAndPrimaryReleased", 0, 0);

        Add_Step("press Primary on the focused rock", n"Step_PressPrimary");
        Add_Step_WaitSeconds("a jab would have been thrown by now", k_NoJabSeconds);
        Add_Step("the focused prompt kept the press; release Primary and pick the rock up with Use", n"Step_AssertNoJabReleaseAndUse");
        Add_Step_WaitUntil("the rock is in the hands and the gloves rest", n"Check_HoldingAndResting", 0, 0);

        Add_Step("release Use and turn the view off everything", n"Step_ReleaseUseAndAimAway");
        Add_Step_WaitUntil("the Use row releases", n"Check_UseReleased", 0, 0);
        Add_Step("press Primary with the rock in the hands", n"Step_AssertHoldingAndPressPrimary");
        Add_Step_WaitSeconds("a jab would have been thrown by now", k_NoJabSeconds);
        Add_Step("full hands threw nothing", n"Step_AssertNoJabWithFullHands");
        Run_Steps(InHandle);
    }

    protected TSubclassOf<UCk_SmState_EntityScript> Get_RigStateClass() const override
    { return UMars_AutoTestState_PlayerPathPunchRig; }

    protected TArray<FMars_AutoTestHelper_KeyRow> Get_ExtraKeyRows() const override
    {
        auto Rows = TArray<FMars_AutoTestHelper_KeyRow>();
        Rows.Add(FMars_AutoTestHelper_KeyRow(EKeys::F10, GameplayTags::Mars_Intent_Interact_Primary, n"IP"));
        return Rows;
    }

    UFUNCTION()
    private void OnThrown(FCk_Handle_Punch InPunch, EMars_Hand InHand)
    {
        _Thrown.Add(InHand);
    }

    private bool Get_IsPrimaryHeld() const
    {
        return _Intents.Get_IsIntentActive(GameplayTags::Mars_Intent_Interact_Primary);
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Steps
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void Step_AssertFreeAndPressPrimary(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Valid(_Punch, "the carrier has fists");
        Assert_True(ck::Is_NOT_Valid(_HeldItem.Get_CurrentItem()), "the hands are empty");
        Assert_False(_PathRock.Get_Pickup().Get_IsFocused(), "the view rests on nothing");
        Assert_Equals_Int(_Punch.Get_JabsThrown(), 0, "nothing thrown yet");

        _UseKey.Press_Row(GameplayTags::Mars_Intent_Interact_Primary);
    }

    UFUNCTION()
    private void Step_PressPrimary(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _UseKey.Press_Row(GameplayTags::Mars_Intent_Interact_Primary);
    }

    UFUNCTION()
    private void Step_ReleasePrimary(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _UseKey.Release_Row(GameplayTags::Mars_Intent_Interact_Primary);
    }

    UFUNCTION()
    private void Check_OneThrown(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Punch.Get_JabsThrown() >= 1);
    }

    UFUNCTION()
    private void Check_TwoThrown(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Punch.Get_JabsThrown() >= 2);
    }

    UFUNCTION()
    private void Check_PrimaryReleased(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_IsPrimaryHeld() == false);
    }

    UFUNCTION()
    private void Step_AssertLeftRightReleaseAndAim(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Thrown.Num(), 2, "two presses were two jabs");
        if (_Thrown.Num() == 2)
        {
            Assert_True(_Thrown[0] == EMars_Hand::Left, "the first press threw the left");
            Assert_True(_Thrown[1] == EMars_Hand::Right, "the second press threw the right");
        }

        _UseKey.Release_Row(GameplayTags::Mars_Intent_Interact_Primary);
        Aim_ViewAt(_PathRockLastLocation.GetValue());
    }

    UFUNCTION()
    private void Check_RockFocusedAndPrimaryReleased(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_PathRock.Get_Pickup().Get_IsFocused() && Get_IsPrimaryHeld() == false);
    }

    UFUNCTION()
    private void Step_AssertNoJabReleaseAndUse(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(Get_IsPrimaryHeld(), "Primary is held");
        Assert_True(_PathRock.Get_Pickup().Get_IsFocused(), "the rock is still focused");
        Assert_Equals_Int(_Punch.Get_JabsThrown(), 2, "a press on a focused prompt threw nothing");
        Assert_False(_Punch.Get_HasWaitingThrow(), "and left no throw waiting");

        _UseKey.Release_Row(GameplayTags::Mars_Intent_Interact_Primary);
        _UseKey.Press();
    }

    UFUNCTION()
    private void Check_HoldingAndResting(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(ck::IsValid(_HeldItem.Get_CurrentItem()) && _Hands.Get_Phase() == EMars_FPHands_Phase::None
            && Get_IsPrimaryHeld() == false);
    }

    UFUNCTION()
    private void Step_ReleaseUseAndAimAway(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _UseKey.Release();
        Aim_ViewAway();
    }

    UFUNCTION()
    private void Step_AssertHoldingAndPressPrimary(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(ck::IsValid(_HeldItem.Get_CurrentItem()), "the hands hold the rock");
        Assert_True(_Hands.Get_Phase() == EMars_FPHands_Phase::None, f"the gloves rest (phase {_Hands.Get_Phase() :n})");

        _UseKey.Press_Row(GameplayTags::Mars_Intent_Interact_Primary);
    }

    UFUNCTION()
    private void Step_AssertNoJabWithFullHands(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(Get_IsPrimaryHeld(), "Primary is held");
        Assert_Equals_Int(_Punch.Get_JabsThrown(), 2, "a press with the hands full threw nothing");
        Assert_False(_Punch.Get_HasWaitingThrow(), "and left no throw waiting");

        _UseKey.Release_Row(GameplayTags::Mars_Intent_Interact_Primary);
    }
}
