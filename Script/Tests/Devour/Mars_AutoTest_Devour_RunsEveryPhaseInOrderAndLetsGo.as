// A Begin takes the victim through Seize, Lift, Blink, Grin, Bite and Swallowed in that order, each broadcast once; the
// victim carries the devourer's mark from the first of them and loses it when the run ends Completed, with the devourer
// Idle again.
class UMars_AutoTest_Devour_RunsEveryPhaseInOrderAndLetsGo : UCk_AutoTest_Base
{
    private FCk_Handle_Devour _Devour;
    private FCk_Handle _Victim;
    private TArray<EMars_Devour_Phase> _Entered;
    private bool _MarkedAtSeize = false;
    private int32 _Ended = 0;
    private TOptional<EMars_Devour_End> _End;
    private FCk_Handle _EndedVictim;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Devourer = utils_entity_lifetime::Request_CreateEntity(InHandle);
        _Victim = utils_entity_lifetime::Request_CreateEntity(InHandle);

        auto Spec = FMars_Devour_Spec();
        Spec.Timing.SeizeSeconds = 0.1f;
        Spec.Timing.LiftSeconds = 0.1f;
        Spec.Timing.BlinkSeconds = 0.1f;
        Spec.Timing.GrinSeconds = 0.1f;
        Spec.Timing.BiteSeconds = 0.1f;
        Spec.Timing.SwallowedSeconds = 0.1f;
        _Devour = utils_devour::Add(Devourer, Spec);

        _Devour.BindTo_OnPhaseChanged(FMars_Delegate_Devour_OnPhaseChanged(this, n"OnPhaseChanged"));
        _Devour.BindTo_OnEnded(FMars_Delegate_Devour_OnEnded(this, n"OnEnded"));

        Add_Step("the devourer starts Idle and can seize the victim", n"Step_AssertIdle");
        Add_Step("request Begin", n"Step_Begin");
        Add_Step_WaitUntil("the run ended", n"Check_Ended", 0, 0);
        Add_Step("every phase ran once, in order, and the victim was let go", n"Step_AssertRun");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void OnPhaseChanged(FCk_Handle_Devour InDevour, EMars_Devour_Phase InPhase)
    {
        _Entered.Add(InPhase);
        if (InPhase == EMars_Devour_Phase::Seize)
        { _MarkedAtSeize = utils_devour::TryGet_Devourer(_Victim) == _Devour; }
    }

    UFUNCTION()
    private void OnEnded(FCk_Handle_Devour InDevour, FCk_Handle InVictim, EMars_Devour_End InEnd)
    {
        _Ended += 1;
        _End = TOptional<EMars_Devour_End>(InEnd);
        _EndedVictim = InVictim;
    }

    UFUNCTION()
    private void Step_AssertIdle(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Devour.Get_Phase() == EMars_Devour_Phase::Idle, f"a new devourer is Idle (got {_Devour.Get_Phase() :n})");
        Assert_False(_Devour.Get_IsActive(), "a new devourer holds nobody");
        Assert_True(_Devour.Get_CanSeize(_Victim), "an Idle devourer can seize a free victim");
        Assert_False(_Devour.Get_CanSeize(_Devour.H()), "a devourer cannot seize itself");
        Assert_False(ck::IsValid(utils_devour::TryGet_Devourer(_Victim)), "a free victim has no devourer");
    }

    UFUNCTION()
    private void Step_Begin(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Devour.Request_Begin(FMars_Request_Devour_Begin(_Victim));
    }

    UFUNCTION()
    private void Check_Ended(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Ended >= 1);
    }

    UFUNCTION()
    private void Step_AssertRun(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Entered.Num(), 6, "six phases were entered");
        for (int32 Index = 0; Index < _Entered.Num(); ++Index)
        {
            const auto Expected = EMars_Devour_Phase(int32(EMars_Devour_Phase::Seize) + Index);
            Assert_True(_Entered[Index] == Expected, f"phase {Index} is {Expected :n} (got {_Entered[Index] :n})");
        }

        Assert_True(_MarkedAtSeize, "the victim carried this devourer's mark when Seize was broadcast");
        Assert_Equals_Int(_Ended, 1, "OnEnded broadcast count");
        Assert_True(_End.GetValue() == EMars_Devour_End::Completed, f"the run Completed (got {_End.GetValue() :n})");
        Assert_True(_EndedVictim == _Victim, "OnEnded carries the victim");
        Assert_False(ck::IsValid(utils_devour::TryGet_Devourer(_Victim)), "the victim's mark is gone");
        Assert_True(_Devour.Get_Phase() == EMars_Devour_Phase::Idle, f"the devourer is Idle again (got {_Devour.Get_Phase() :n})");
        Assert_False(ck::IsValid(_Devour.Get_Victim()), "the devourer holds nobody");
    }
}
