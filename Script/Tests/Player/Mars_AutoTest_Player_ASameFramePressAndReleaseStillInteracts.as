// A press and a release delivered in one frame still interact: on the player-path carrier the view rests on a still,
// focused rock, and Use is pressed and released in the same frame (one sampled row: the Use row goes Active and back to
// Idle in one matcher pass). The press still reaches the resolver and the rock is picked up. Isolated origin
// (88000, -40000, -30000).
class UMars_AutoTest_Player_ASameFramePressAndReleaseStillInteracts : UMars_AutoTestRig_PlayerPath
{
    private const FVector k_Origin = FVector(88000.0, -40000.0, -30000.0);
    private const FVector k_RockLocal = FVector(120.0, 0.0, 16.0);

    private FCk_Handle _RockEntity;
    private FCk_Handle_WorldItem _Rock;
    private TOptional<FVector> _LastRockLocation;
    private int32 _StillFrames = 0;
    // The matcher frames the Use row went Active and back to Idle on.
    private TOptional<int32> _ActiveFrame;
    private TOptional<int32> _IdleFrame;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Build_PlayerPath(InHandle, k_Origin);
        _RockEntity = Spawn_WorldItem(InHandle, mars_items::Rock(), k_RockLocal);

        Add_Steps_UntilReady();
        Add_Step_WaitUntil("the rock lies still on the floor", n"Check_RockStill", 0, 0);
        Add_Step("turn the view onto the rock", n"Step_AimAtRock");
        Add_Step_WaitUntil("the rock's pickup is focused", n"Check_RockFocused", 0, 0);
        Add_Step("watch the Use row; press and release Use in the same frame", n"Step_PressAndRelease");
        Add_Step_WaitUntil("the rock is stowed", n"Check_RockStowed", 0, 0);
        Add_Step("the row went Active and Idle in one matcher frame, and the rock is in a bag slot", n"Step_AssertStowed");
        Run_Steps(InHandle);
    }

    // A constructed rock world item whose location moved less than 1.5 mm a frame for 10 frames.
    UFUNCTION()
    private void Check_RockStill(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        if (ck::Is_NOT_Valid(_Rock))
        {
            const auto Constructed = ck::IsValid(_RockEntity) && _RockEntity.Is_WorldItem()
                && ck::IsValid(_RockEntity.As_WorldItem().Get_HeldItem());
            if (Constructed == false)
            {
                Res.Set(false);
                return;
            }

            _Rock = _RockEntity.As_WorldItem();
        }

        const auto Location = utils_transform::Get_EntityCurrentTransform(_RockEntity.As_Transform()).GetLocation();
        const auto IsStill = _LastRockLocation.IsSet() && _LastRockLocation.GetValue().Equals(Location, 0.15);
        _StillFrames = IsStill ? _StillFrames + 1 : 0;
        _LastRockLocation = TOptional<FVector>(Location);
        Res.Set(_StillFrames >= 10);
    }

    UFUNCTION()
    private void Step_AimAtRock(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Aim_ViewAt(_LastRockLocation.GetValue());
    }

    UFUNCTION()
    private void Check_RockFocused(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Rock.Get_Pickup().Get_IsFocused());
    }

    UFUNCTION()
    private void Step_PressAndRelease(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        utils_intent_matcher::BindTo_OnIntentPhaseChanged(_UseKey.Get_Matcher(),
            FCk_Delegate_IntentMatcher_PhaseChanged(this, n"OnUsePhaseChanged"), ECk_Signal_BindingPolicy::IgnorePayloadInFlight);
        _UseKey.Press();
        _UseKey.Release();
    }

    UFUNCTION()
    private void OnUsePhaseChanged(FCk_Handle_IntentMatcher InMatcher, FName InIntentName, FGameplayTag InIntentTag,
                                   ECk_Intent_Phase InPreviousPhase, ECk_Intent_Phase InNewPhase, int32 InFrame)
    {
        if (InIntentTag != GameplayTags::Mars_Intent_Interact_Use)
        { return; }

        if (InNewPhase == ECk_Intent_Phase::Active && _ActiveFrame.IsSet() == false)
        { _ActiveFrame = TOptional<int32>(InFrame); }

        if (InPreviousPhase == ECk_Intent_Phase::Active && InNewPhase != ECk_Intent_Phase::Active && _IdleFrame.IsSet() == false)
        { _IdleFrame = TOptional<int32>(InFrame); }
    }

    // A transient rock's world item ends once its holder gives the item up.
    UFUNCTION()
    private void Check_RockStowed(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set((ck::Is_NOT_Valid(_Rock) || ck::Is_NOT_Valid(_Rock.Get_HeldItem()))
            && (ck::IsValid(_Hotbar.Get_ItemAt(0)) || ck::IsValid(_Hotbar.Get_ItemAt(1))));
    }

    UFUNCTION()
    private void Step_AssertStowed(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_ActiveFrame.IsSet() && _IdleFrame.IsSet() && _ActiveFrame.GetValue() == _IdleFrame.GetValue(),
            "the Use row went Active and back to Idle in one matcher frame");
        Assert_False(Get_IsUseHeld(), "Use is not held");
        Assert_True(ck::IsValid(_Hotbar.Get_ItemAt(0)) || ck::IsValid(_Hotbar.Get_ItemAt(1)), "the rock is in a bag slot");
    }
}
