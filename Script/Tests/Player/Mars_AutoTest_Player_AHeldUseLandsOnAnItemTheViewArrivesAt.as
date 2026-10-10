// A held Use lands on an item the view arrives at. The player-path carrier's view rests on a rock lying still on the floor
// whose pickup probe is off, so the trace sees nothing. Use is pressed, and in the matcher's own press broadcast (the one
// the player's Use -> resolver task opens the Use intent in) the rock's probe comes on: the overlap begins in the frame
// the Use intent opens, so the rock becomes focused, offered and the best Use target all at once. The rock is stowed
// within the gloves' reach and grip plus half a second of the press. Isolated origin (80000, -40000, -30000).
class UMars_AutoTest_Player_AHeldUseLandsOnAnItemTheViewArrivesAt : UMars_AutoTestRig_PlayerPath
{
    private const FVector k_Origin = FVector(80000.0, -40000.0, -30000.0);
    private const FVector k_RockLocal = FVector(120.0, 0.0, 16.0);
    // The drains around the gloves' grab: the press, the focus, the offer and the interaction before it, the transfer
    // after the grip.
    private const float32 k_StowSlackSeconds = 0.5f;

    private FCk_Handle _RockEntity;
    private FCk_Handle_WorldItem _Rock;
    private TOptional<FVector> _LastRockLocation;
    private int32 _StillFrames = 0;
    private bool _ProbeOn = false;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Build_PlayerPath(InHandle, k_Origin);
        _RockEntity = Spawn_WorldItem(InHandle, mars_items::Rock(), k_RockLocal);

        // The gloves' grab out to the rock and their grip, plus the drains around it.
        const auto Grab = FMars_FPHands_Spec().Reach.Grab;
        const auto StowSeconds = Grab.OutSeconds + Grab.GripSeconds + k_StowSlackSeconds;

        Add_Steps_UntilReady();
        Add_Step_WaitUntil("the rock lies still on the floor", n"Check_RockStill", 0, 0);
        Add_Step("turn the rock's pickup probe off and the view onto the rock", n"Step_ProbeOffAndAim");
        Add_Step_WaitUntil("the rock's probe is off", n"Check_ProbeOff", 0, 0);
        Add_Step_WaitFrames("the trace runs over the rock a few times", 5);
        Add_Step("watch the Use row's press; press and hold Use", n"Step_PressUseAndProbeOnThePress");
        Add_Step_WaitUntil("the rock is stowed within the gloves' grab plus half a second", n"Check_RockStowed", 0, StowSeconds);
        Add_Step("the probe came on with Use held; the rock is in a bag slot and its world item gave it up", n"Step_AssertStowed");
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
    private void Step_ProbeOffAndAim(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_False(_Rock.Get_Pickup().Get_IsFocused(), "the rock is not focused before the view turns onto it");
        Set_RockProbe(ECk_EnableDisable::Disable);
        Aim_ViewAt(_LastRockLocation.GetValue());
    }

    UFUNCTION()
    private void Check_ProbeOff(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        FCk_Handle PickupEntity = _Rock.Get_Pickup();
        auto Res = OutResult;
        Res.Set(PickupEntity.As_Probe().Get_IsEnabledDisabled() == ECk_EnableDisable::Disable);
    }

    // Bound after the player's tasks, so the Use intent opens first in the same broadcast.
    UFUNCTION()
    private void Step_PressUseAndProbeOnThePress(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_False(_Rock.Get_Pickup().Get_IsFocused(), "the trace does not see the rock while its probe is off");
        utils_intent_matcher::BindTo_OnIntentPhaseChanged(_UseKey.Get_Matcher(),
            FCk_Delegate_IntentMatcher_PhaseChanged(this, n"OnUsePhaseChanged"), ECk_Signal_BindingPolicy::IgnorePayloadInFlight);
        _UseKey.Press();
    }

    UFUNCTION()
    private void OnUsePhaseChanged(FCk_Handle_IntentMatcher InMatcher, FName InIntentName, FGameplayTag InIntentTag,
                                   ECk_Intent_Phase InPreviousPhase, ECk_Intent_Phase InNewPhase, int32 InFrame)
    {
        const auto IsPress = InIntentTag == GameplayTags::Mars_Intent_Interact_Use
            && InNewPhase == ECk_Intent_Phase::Active && InPreviousPhase != ECk_Intent_Phase::Active;
        if (IsPress == false || _ProbeOn)
        { return; }

        _ProbeOn = true;
        Set_RockProbe(ECk_EnableDisable::Enable);
    }

    private void Set_RockProbe(ECk_EnableDisable InEnableDisable)
    {
        FCk_Handle PickupEntity = _Rock.Get_Pickup();
        utils_probe::Request_EnableDisable(PickupEntity.As_Probe(), FCk_Request_Probe_EnableDisable(InEnableDisable));
    }

    // A transient rock's world item ends once its holder gives the item up.
    UFUNCTION()
    private void Check_RockStowed(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_IsRockGivenUp() && Get_IsInABagSlot());
    }

    UFUNCTION()
    private void Step_AssertStowed(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_ProbeOn, "the rock's probe came on in the Use row's press broadcast");
        Assert_True(Get_IsUseHeld(), "Use is still held");
        Assert_True(Get_IsInABagSlot(), "the rock is in a bag slot");
        Assert_True(Get_IsRockGivenUp(), "the rock's world item gave it up");
    }

    private bool Get_IsRockGivenUp()
    {
        return ck::Is_NOT_Valid(_Rock) || ck::Is_NOT_Valid(_Rock.Get_HeldItem());
    }

    private bool Get_IsInABagSlot()
    {
        return ck::IsValid(_Hotbar.Get_ItemAt(0)) || ck::IsValid(_Hotbar.Get_ItemAt(1));
    }
}
