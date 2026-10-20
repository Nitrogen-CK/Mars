// A Momentary control releases ActiveSeconds after it activates, and an engage while active re-arms the countdown:
//   - a control that starts active arms its release at setup and goes Inactive on its own;
//   - an engaged control goes Active (OnActiveChanged once), a second engage half-way through keeps it Active (OnEngaged
//     twice, no second Active edge) and restarts the countdown, so it goes Inactive ActiveSeconds after the re-engage,
//     not after the first engage.
class UMars_AutoTest_Control_MomentaryReleasesAndReArms : UCk_AutoTest_Base
{
    private const float32 k_StartActiveSeconds = 0.3f;
    private const float32 k_ActiveSeconds = 0.8f;
    // The re-engage lands this long after the first engage, well inside k_ActiveSeconds.
    private const float64 k_ReEngageAfterSeconds = 0.5;
    // Timers advance per frame: a release lands within a few frames of its due time.
    private const float64 k_FrameTolerance = 0.15;

    private FCk_Handle_Control _StartsActive;
    private FCk_Handle_Control _Engaged;

    private TArray<EMars_Control_Activation> _StartsActiveEdges;
    private TArray<EMars_Control_Activation> _EngagedEdges;
    private int32 _EngagedCount = 0;

    private float64 _FirstEngageSeconds = 0.0;
    private float64 _ReEngageSeconds = 0.0;
    private float64 _InactiveSeconds = 0.0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        _StartsActive = Add_Momentary(InHandle, k_StartActiveSeconds, true);
        _StartsActive.BindTo_OnActiveChanged(FMars_Delegate_Control_OnActiveChanged(this, n"OnStartsActiveChanged"));

        _Engaged = Add_Momentary(InHandle, k_ActiveSeconds, false);
        _Engaged.BindTo_OnActiveChanged(FMars_Delegate_Control_OnActiveChanged(this, n"OnEngagedActiveChanged"));
        _Engaged.BindTo_OnEngaged(FMars_Delegate_Control_OnEngaged(this, n"OnEngaged"));

        Add_Step("both controls composed; engage the second", n"Step_Engage");
        Add_Step_WaitUntil("the engaged control is Active", n"Check_EngagedActive", 0, 0);
        Add_Step_WaitUntil("the engaged control has been active the re-engage delay", n"Check_ReEngageDue", 0, 0);
        Add_Step("re-engage while active", n"Step_ReEngage");
        Add_Step_WaitUntil("the engaged control is Inactive again", n"Check_EngagedInactive", 0, 0);
        Add_Step("the re-engage restarted the countdown and broadcast no second Active edge", n"Step_AssertReArmed");
        Add_Step_WaitUntil("the start-active control released on its own", n"Check_StartsActiveReleased", 0, 0);
        Add_Step("the start-active control broadcast one Inactive edge", n"Step_AssertStartsActiveReleased");
        Run_Steps(InHandle);
    }

    private FCk_Handle_Control Add_Momentary(FCk_Handle InHandle, float32 InActiveSeconds, bool InStartActive)
    {
        auto Entity = utils_entity_lifetime::Request_CreateEntity(InHandle);
        auto Spec = FMars_Control_Spec();
        Spec.Behavior = EMars_Control_Behavior::Momentary;
        Spec.ActiveSeconds = InActiveSeconds;
        Spec.StartActive = InStartActive;
        return utils_control::Add(Entity, Spec);
    }

    UFUNCTION()
    private void OnStartsActiveChanged(FCk_Handle_Control InControl, EMars_Control_Activation InActivation)
    {
        _StartsActiveEdges.Add(InActivation);
    }

    UFUNCTION()
    private void OnEngagedActiveChanged(FCk_Handle_Control InControl, EMars_Control_Activation InActivation)
    {
        _EngagedEdges.Add(InActivation);
        if (InActivation == EMars_Control_Activation::Inactive)
        { _InactiveSeconds = System::GetGameTimeInSeconds(); }
    }

    UFUNCTION()
    private void OnEngaged(FCk_Handle_Control InControl)
    {
        _EngagedCount += 1;
    }

    UFUNCTION()
    private void Step_Engage(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Valid(_StartsActive, "the start-active control was composed");
        Assert_Valid(_Engaged, "the engaged control was composed");
        Assert_False(_Engaged.Get_IsActive(), "the engaged control starts inactive");

        _FirstEngageSeconds = System::GetGameTimeInSeconds();
        _Engaged.Request_Engage(FMars_Request_Control_Engage());
    }

    UFUNCTION()
    private void Check_EngagedActive(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Engaged.Get_IsActive());
    }

    UFUNCTION()
    private void Check_ReEngageDue(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(System::GetGameTimeInSeconds() - _FirstEngageSeconds >= k_ReEngageAfterSeconds);
    }

    UFUNCTION()
    private void Step_ReEngage(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Engaged.Get_IsActive(), "the engaged control is still active before its countdown ran out");
        _ReEngageSeconds = System::GetGameTimeInSeconds();
        _Engaged.Request_Engage(FMars_Request_Control_Engage());
    }

    UFUNCTION()
    private void Check_EngagedInactive(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_EngagedEdges.Num() >= 2);
    }

    UFUNCTION()
    private void Step_AssertReArmed(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_EngagedCount, 2, "OnEngaged fired for both engages");
        Assert_Equals_Int(_EngagedEdges.Num(), 2, "OnActiveChanged fired twice: one Active edge, one Inactive edge");
        if (_EngagedEdges.Num() == 2)
        {
            Assert_True(_EngagedEdges[0] == EMars_Control_Activation::Active, f"the first edge is Active (got {_EngagedEdges[0] :n})");
            Assert_True(_EngagedEdges[1] == EMars_Control_Activation::Inactive, f"the second edge is Inactive (got {_EngagedEdges[1] :n})");
        }

        const auto SinceReEngage = _InactiveSeconds - _ReEngageSeconds;
        Assert_True(SinceReEngage >= float64(k_ActiveSeconds) - k_FrameTolerance && SinceReEngage <= float64(k_ActiveSeconds) + k_FrameTolerance,
            f"the release came ActiveSeconds [{k_ActiveSeconds}] after the re-engage (got {SinceReEngage} s)");

        const auto SinceFirst = _InactiveSeconds - _FirstEngageSeconds;
        Assert_True(SinceFirst >= float64(k_ActiveSeconds) + k_ReEngageAfterSeconds - k_FrameTolerance,
            f"the release did not come on the first engage's countdown (got {SinceFirst} s after it)");
    }

    UFUNCTION()
    private void Check_StartsActiveReleased(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_StartsActive.Get_IsActive() == false);
    }

    UFUNCTION()
    private void Step_AssertStartsActiveReleased(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_StartsActiveEdges.Num(), 1, "the start-active control broadcast one edge");
        if (_StartsActiveEdges.Num() == 1)
        { Assert_True(_StartsActiveEdges[0] == EMars_Control_Activation::Inactive, f"the edge is Inactive (got {_StartsActiveEdges[0] :n})"); }
    }
}
