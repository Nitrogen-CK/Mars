// A FreeTurn control (a dial's knob) moves nothing: a grip asked for AtEngageAlpha is held OnRelease anyway, the drain's
// nudges leave summed as one OnTurned, any amount of pull never ends the grip, engages or reports progress, and only
// EndManipulation lets go. A FreeTurn spec that is not ManuallyCompleted is rejected.
class UMars_AutoTest_Control_FreeTurnHandsOutItsPullUntilRelease : UCk_AutoTest_Base
{
    private const int32 k_SpinFrames = 30;
    private const float32 k_SpinDegrees = 20.0f;

    private FCk_Handle_Control _Control;
    private TArray<float32> _Turns;
    private TArray<EMars_Control_Grip> _Grips;
    private int32 _ProgressCount = 0;
    private int32 _EngagedCount = 0;
    private int32 _SpunFrames = 0;
    private int32 _TurnsAtRelease = 0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Entity = utils_entity_lifetime::Request_CreateEntity(InHandle);
        utils_transform::Add(Entity, FTransform::Identity, ECk_Replication::DoesNotReplicate);

        _Control = utils_control::Add(Entity, Make_Spec(ECk_Interaction_CompletionPolicy::ManuallyCompleted));
        _Control.BindTo_OnTurned(FMars_Delegate_Control_OnTurned(this, n"OnTurned"));
        _Control.BindTo_OnManipulationChanged(FMars_Delegate_Control_OnManipulationChanged(this, n"OnGripChanged"));
        _Control.BindTo_OnManipulationProgress(FMars_Delegate_Control_OnManipulationProgress(this, n"OnProgress"));
        _Control.BindTo_OnEngaged(FMars_Delegate_Control_OnEngaged(this, n"OnEngaged"));

        Add_Step("a FreeTurn spec must be ManuallyCompleted; grip asking for the threshold", n"Step_ValidateThenGrip");
        Add_Step_WaitUntil("gripped", n"Check_Gripped", 0, 0);
        Add_Step("held OnRelease; two nudges in one frame", n"Step_AssertHeldThenNudgeTwice");
        Add_Step_WaitUntil("one turn handed out", n"Check_OneTurn", 0, 0);
        Add_Step("the two nudges left summed", n"Step_AssertSummed");
        Add_Step_WaitUntil("spin far past any threshold", n"Check_Spun", 0, 0);
        Add_Step("still gripped, nothing engaged, no progress; let go", n"Step_AssertSpunThenRelease");
        Add_Step_WaitUntil("released", n"Check_Released", 0, 0);
        Add_Step("released once, no turn after", n"Step_AssertReleased");
        Run_Steps(InHandle);
    }

    private FMars_Control_Spec Make_Spec(ECk_Interaction_CompletionPolicy InPolicy) const
    {
        auto Spec = FMars_Control_Spec();
        Spec.Interaction = InPolicy;
        Spec.Manipulation.Mode = EMars_Control_ManipulationMode::FreeTurn;
        Spec.Manipulation.PullAxis = FVector(0.0, -1.0, 0.0);
        return Spec;
    }

    UFUNCTION()
    private void Step_ValidateThenGrip(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(Make_Spec(ECk_Interaction_CompletionPolicy::ManuallyCompleted).Validate().IsValid(), "a gripped FreeTurn validates");
        Assert_False(Make_Spec(ECk_Interaction_CompletionPolicy::Instant).Validate().IsValid(), "an Instant FreeTurn is rejected");
        Assert_True(_Control.Get_IsFreeTurn(), "the control is FreeTurn");

        _Control.Request_BeginManipulation(FMars_Request_Control_BeginManipulation(
            FCk_Handle_Interaction(), EMars_Control_ManipulationCompletion::AtEngageAlpha));
    }

    UFUNCTION()
    private void Check_Gripped(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Control.Get_IsManipulating());
    }

    UFUNCTION()
    private void Step_AssertHeldThenNudgeTwice(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Control.Get_ManipulationCompletion() == EMars_Control_ManipulationCompletion::OnRelease,
            "a FreeTurn grip is held until release whatever the request asked");
        Assert_Equals_Int(_Turns.Num(), 0, "no turn before a nudge");

        _Control.Request_Nudge(FMars_Request_Control_Nudge(4.0f));
        _Control.Request_Nudge(FMars_Request_Control_Nudge(3.0f));
    }

    UFUNCTION()
    private void Check_OneTurn(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Turns.Num() >= 1);
    }

    UFUNCTION()
    private void Step_AssertSummed(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Turns.Num(), 1, "one turn for one drain");
        Assert_Equals_Float(_Turns[0], 7.0f, 0.001f, "the drain's nudges summed");
    }

    // k_SpinFrames nudges of k_SpinDegrees: 600 degrees, ten times what a Travel lever's whole travel takes.
    UFUNCTION()
    private void Check_Spun(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        if (_SpunFrames >= k_SpinFrames)
        {
            Res.Set(true);
            return;
        }

        _SpunFrames += 1;
        _Control.Request_Nudge(FMars_Request_Control_Nudge(k_SpinDegrees));
        Res.Set(_Control.Get_IsManipulating() == false);
    }

    UFUNCTION()
    private void Step_AssertSpunThenRelease(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Control.Get_IsManipulating(), "no amount of pull ends a FreeTurn grip");
        Assert_Equals_Int(_EngagedCount, 0, "nothing engaged");
        Assert_False(_Control.Get_IsActive(), "the control never flipped");
        Assert_Equals_Int(_ProgressCount, 0, "a FreeTurn grip reports no progress");

        auto Total = 0.0f;
        for (const auto Turn : _Turns)
        { Total += Turn; }
        Assert_Equals_Float(Total, 7.0f + k_SpinFrames * k_SpinDegrees, 0.01f, "every nudge left as a turn");

        _TurnsAtRelease = _Turns.Num();
        _Control.Request_EndManipulation(FMars_Request_Control_EndManipulation());
    }

    UFUNCTION()
    private void Check_Released(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Control.Get_IsManipulating() == false);
    }

    UFUNCTION()
    private void Step_AssertReleased(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Grips.Num(), 2, "gripped, then released");
        if (_Grips.Num() == 2)
        { Assert_True(_Grips[1] == EMars_Control_Grip::Released, "the last grip edge is the release"); }

        Assert_Equals_Int(_Turns.Num(), _TurnsAtRelease, "no turn after the release");
    }

    UFUNCTION()
    private void OnTurned(FCk_Handle_Control InControl, float32 InDegrees)
    {
        _Turns.Add(InDegrees);
    }

    UFUNCTION()
    private void OnGripChanged(FCk_Handle_Control InControl, EMars_Control_Grip InGrip)
    {
        _Grips.Add(InGrip);
    }

    UFUNCTION()
    private void OnProgress(FCk_Handle_Control InControl, float32 InProgress)
    {
        ++_ProgressCount;
    }

    UFUNCTION()
    private void OnEngaged(FCk_Handle_Control InControl)
    {
        ++_EngagedCount;
    }
}
