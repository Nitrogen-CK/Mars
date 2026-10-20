// The two ways a run ends early, each on its own devourer. A Cancel while a victim is held lets it go at once: OnEnded
// says Cancelled, the mark is gone, the devourer is Idle and the same victim can be seized again; a Cancel while Idle
// does nothing. A held victim that is destroyed cancels its run the same way and leaves its devourer free for another.
class UMars_AutoTest_Devour_ACancelOrALostVictimEndsTheRunCancelled : UCk_AutoTest_Base
{
    private FCk_Handle_Devour _Cancelled;
    private FCk_Handle _CancelledVictim;
    private int32 _CancelledSeizes = 0;
    private int32 _CancelledEnds = 0;
    private TOptional<EMars_Devour_End> _CancelledEnd;

    private FCk_Handle_Devour _Bereft;
    private FCk_Handle _LostVictim;
    private FCk_Handle _NextVictim;
    private int32 _BereftSeizes = 0;
    private int32 _BereftEnds = 0;
    private TOptional<EMars_Devour_End> _BereftEnd;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        // Long phases: only a Cancel or the victim's end ends these runs.
        auto Spec = FMars_Devour_Spec();
        Spec.Timing.SeizeSeconds = 30.0f;

        auto CancelledEntity = utils_entity_lifetime::Request_CreateEntity(InHandle);
        _CancelledVictim = utils_entity_lifetime::Request_CreateEntity(InHandle);
        _Cancelled = utils_devour::Add(CancelledEntity, Spec);
        _Cancelled.BindTo_OnPhaseChanged(FMars_Delegate_Devour_OnPhaseChanged(this, n"OnCancelledPhaseChanged"));
        _Cancelled.BindTo_OnEnded(FMars_Delegate_Devour_OnEnded(this, n"OnCancelledEnded"));

        auto BereftEntity = utils_entity_lifetime::Request_CreateEntity(InHandle);
        _LostVictim = utils_entity_lifetime::Request_CreateEntity(InHandle);
        _NextVictim = utils_entity_lifetime::Request_CreateEntity(InHandle);
        _Bereft = utils_devour::Add(BereftEntity, Spec);
        _Bereft.BindTo_OnPhaseChanged(FMars_Delegate_Devour_OnPhaseChanged(this, n"OnBereftPhaseChanged"));
        _Bereft.BindTo_OnEnded(FMars_Delegate_Devour_OnEnded(this, n"OnBereftEnded"));

        Add_Step("a Cancel while Idle", n"Step_Cancel");
        Add_Step_WaitSeconds("an end would be broadcast in this window", 0.3f);
        Add_Step("nothing ended", n"Step_AssertNothingEnded");
        Add_Step("both devourers Begin", n"Step_Begin");
        Add_Step_WaitUntil("both victims are seized", n"Check_BothSeized", 0, 0);
        Add_Step("a Cancel for one, the other's victim destroyed", n"Step_CancelAndDestroy");
        Add_Step_WaitUntil("both runs ended", n"Check_BothEnded", 0, 0);
        Add_Step("both runs were Cancelled and both devourers are free", n"Step_AssertCancelled");
        Add_Step("the cancelled devourer Begins again", n"Step_BeginAgain");
        Add_Step_WaitUntil("its victim is seized again", n"Check_SeizedAgain", 0, 0);
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void OnCancelledPhaseChanged(FCk_Handle_Devour InDevour, EMars_Devour_Phase InPhase)
    {
        if (InPhase == EMars_Devour_Phase::Seize)
        { _CancelledSeizes += 1; }
    }

    UFUNCTION()
    private void OnCancelledEnded(FCk_Handle_Devour InDevour, FCk_Handle InVictim, EMars_Devour_End InEnd)
    {
        _CancelledEnds += 1;
        _CancelledEnd = TOptional<EMars_Devour_End>(InEnd);
    }

    UFUNCTION()
    private void OnBereftPhaseChanged(FCk_Handle_Devour InDevour, EMars_Devour_Phase InPhase)
    {
        if (InPhase == EMars_Devour_Phase::Seize)
        { _BereftSeizes += 1; }
    }

    UFUNCTION()
    private void OnBereftEnded(FCk_Handle_Devour InDevour, FCk_Handle InVictim, EMars_Devour_End InEnd)
    {
        _BereftEnds += 1;
        _BereftEnd = TOptional<EMars_Devour_End>(InEnd);
    }

    UFUNCTION()
    private void Step_Cancel(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Cancelled.Request_Cancel(FMars_Request_Devour_Cancel());
    }

    UFUNCTION()
    private void Step_AssertNothingEnded(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_CancelledEnds, 0, "a Cancel while Idle ends nothing");
    }

    UFUNCTION()
    private void Step_Begin(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Cancelled.Request_Begin(FMars_Request_Devour_Begin(_CancelledVictim));
        _Bereft.Request_Begin(FMars_Request_Devour_Begin(_LostVictim));
    }

    UFUNCTION()
    private void Check_BothSeized(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_CancelledSeizes >= 1 && _BereftSeizes >= 1);
    }

    UFUNCTION()
    private void Step_CancelAndDestroy(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Cancelled.Request_Cancel(FMars_Request_Devour_Cancel());
        utils_entity_lifetime::Request_DestroyEntity(_LostVictim);
    }

    UFUNCTION()
    private void Check_BothEnded(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_CancelledEnds >= 1 && _BereftEnds >= 1);
    }

    UFUNCTION()
    private void Step_AssertCancelled(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_CancelledEnds, 1, "the cancelled run's OnEnded broadcast count");
        Assert_True(_CancelledEnd.GetValue() == EMars_Devour_End::Cancelled, f"the cancelled run was Cancelled (got {_CancelledEnd.GetValue() :n})");
        Assert_False(ck::IsValid(utils_devour::TryGet_Devourer(_CancelledVictim)), "the cancelled victim's mark is gone");
        Assert_False(_Cancelled.Get_IsActive(), "the cancelled devourer is Idle");
        Assert_True(_Cancelled.Get_CanSeize(_CancelledVictim), "the cancelled victim can be seized again");

        Assert_Equals_Int(_BereftEnds, 1, "the lost victim's run's OnEnded broadcast count");
        Assert_True(_BereftEnd.GetValue() == EMars_Devour_End::Cancelled, f"the lost victim's run was Cancelled (got {_BereftEnd.GetValue() :n})");
        Assert_False(_Bereft.Get_IsActive(), "the bereft devourer is Idle");
        Assert_True(_Bereft.Get_CanSeize(_NextVictim), "the bereft devourer can seize someone else");
    }

    UFUNCTION()
    private void Step_BeginAgain(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Cancelled.Request_Begin(FMars_Request_Devour_Begin(_CancelledVictim));
    }

    UFUNCTION()
    private void Check_SeizedAgain(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_CancelledSeizes >= 2 && utils_devour::TryGet_Devourer(_CancelledVictim) == _Cancelled);
    }
}
