// A timed reach requested while the gloves are releasing interrupts the release: the phase goes Release -> Hold with no
// stop at rest, and the new hold reach starts from the alpha the release had reached (no snap back to zero), then
// completes. The first hold reaches fully before it is released, so the release starts from 1 and the alpha it is
// interrupted at is well clear of zero.
class UMars_AutoTest_FPHands_ReachDuringReleaseContinuesFromReleaseAlpha : UCk_AutoTest_Base
{
    private FCk_Handle_FPHands _Hands;
    private FCk_Handle_StateMachine _Sm;
    private FCk_Handle _Player;
    private TArray<EMars_FPHands_Phase> _Phases;
    private float32 _AlphaBefore = 0.0f;
    private float32 _FirstHoldAlpha = -1.0f;
    private bool _SawSecondHold = false;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        _Player = InHandle;
        auto RootEntity = utils_entity_lifetime::Request_CreateEntity(InHandle);
        auto Root = utils_transform::Add(RootEntity, FTransform::Identity, ECk_Replication::DoesNotReplicate);
        auto HandNode = utils_scene_node::Create(Root, FTransform::Identity);

        auto Spec = FMars_FPHands_Spec();
        Spec.Reach.GrabOutSeconds = 0.2f;
        Spec.Reach.GrabGripSeconds = 0.2f;
        Spec.Reach.GrabBackSeconds = 0.2f;
        Spec.Reach.ReleaseSeconds = 0.4f;

        _Hands = utils_fphands::Add(_Player, Spec, HandNode.As_Transform());
        _Sm = utils_state_machine::Add(_Player, FCk_StateMachine_Spec(UMars_SmState_Hands_Rest));
        _Hands.BindTo_OnPhaseChanged(FMars_Delegate_FPHands_OnPhaseChanged(this, n"OnPhaseChanged"));

        Add_Step_WaitUntil("the Hands SM rests in Rest, listening for a reach", n"Check_RestListening", 0, 5.0f);
        Add_Step("request a timed reach", n"Step_RequestTimedReach");
        Add_Step_WaitUntil("the hold reaches fully and listens for a lost target", n"Check_HoldFullyReached", 0, 5.0f);
        Add_Step("request a release", n"Step_RequestRelease");
        Add_Step_WaitUntil("the release is under way", n"Check_ReleaseUnderWay", 0, 5.0f);
        Add_Step("record the release alpha and request a timed reach again", n"Step_RecordAlphaAndReach");
        Add_Step_WaitUntil("the phase is Hold again", n"Check_SecondHold", 0, 5.0f);
        Add_Step("the new hold starts from the release alpha", n"Step_AssertNoSnap");
        Add_Step_WaitUntil("the new hold reaches fully", n"Check_FullyReached", 0, 5.0f);
        Add_Step("the phases ran Hold, Release, Hold", n"Step_AssertSequence");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void OnPhaseChanged(FCk_Handle_FPHands InHands, EMars_FPHands_Phase InPrevious, EMars_FPHands_Phase InNew)
    {
        _Phases.Add(InNew);
    }

    UFUNCTION()
    private void Check_RestListening(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(utils_state_machine::Get_CurrentStateClass(_Sm) == UMars_SmState_Hands_Rest
            && _Hands.Has_Fragment(FMars_Fragment_FPHands_Signals)
            && _Hands.Get_Fragment(FMars_Fragment_FPHands_Signals).OnReachRequested._Inner.IsBound());
    }

    UFUNCTION()
    private void Step_RequestTimedReach(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Hands.Request_StartReach(FMars_Request_FPHands_StartReach(FCk_Handle_InteractTarget(), FCk_Handle_Interactable(), _Player, false));
    }

    UFUNCTION()
    private void Check_HoldFullyReached(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Hands.Get_Phase() == EMars_FPHands_Phase::Hold
            && _Hands.Get_ReachAlpha() >= 0.999f
            && _Hands.Get_Fragment(FMars_Fragment_FPHands_Signals).OnReachTargetLost._Inner.IsBound());
    }

    UFUNCTION()
    private void Step_RequestRelease(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Hands.Request_Release();
    }

    UFUNCTION()
    private void Check_ReleaseUnderWay(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Hands.Get_Phase() == EMars_FPHands_Phase::Release && _Hands.Get_PhaseTime() > 0.08f);
    }

    UFUNCTION()
    private void Step_RecordAlphaAndReach(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _AlphaBefore = _Hands.Get_ReachAlpha();
        Assert_True(_AlphaBefore > 0.0f && _AlphaBefore < 1.0f, f"the release is part way back (alpha {_AlphaBefore})");
        _Hands.Request_StartReach(FMars_Request_FPHands_StartReach(FCk_Handle_InteractTarget(), FCk_Handle_Interactable(), _Player, false));
    }

    // Captures the alpha on the first frame the second Hold is observed.
    UFUNCTION()
    private void Check_SecondHold(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        if (_SawSecondHold == false && _Hands.Get_Phase() == EMars_FPHands_Phase::Hold)
        {
            _SawSecondHold = true;
            _FirstHoldAlpha = _Hands.Get_ReachAlpha();
        }

        auto Res = OutResult;
        Res.Set(_SawSecondHold);
    }

    UFUNCTION()
    private void Step_AssertNoSnap(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_FirstHoldAlpha >= _AlphaBefore - 0.05f,
            f"the new hold starts from the release alpha, no snap to zero (first hold alpha {_FirstHoldAlpha}, release alpha {_AlphaBefore})");
    }

    UFUNCTION()
    private void Check_FullyReached(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Hands.Get_Phase() == EMars_FPHands_Phase::Hold && _Hands.Get_ReachAlpha() >= 0.999f);
    }

    UFUNCTION()
    private void Step_AssertSequence(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Phases.Num(), 3, "three phase changes");
        if (_Phases.Num() != 3)
        { return; }

        Assert_True(_Phases[0] == EMars_FPHands_Phase::Hold, "first change is to Hold");
        Assert_True(_Phases[1] == EMars_FPHands_Phase::Release, "second change is to Release");
        Assert_True(_Phases[2] == EMars_FPHands_Phase::Hold, "third change is back to Hold, with no stop at rest");
    }
}
