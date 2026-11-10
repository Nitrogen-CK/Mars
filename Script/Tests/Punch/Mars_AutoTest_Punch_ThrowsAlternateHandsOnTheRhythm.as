// Three throws are three jabs, left, right, left: each fist runs Out -> Back -> home on the rhythm's clock and deals its
// blow once, when it turns back; the hands alternate from the lead hand; a throw asked for inside the interval starts only
// once the interval has passed (the first fist is still coming home then, so two jabs overlap). After the third jab the
// next hand is the right; once the combo window has passed with no throw it is the lead hand again. A thrower with no
// DamageDealer: every blow reports a miss. No transform, no physics: nothing here has a place in the world.
class UMars_AutoTest_Punch_ThrowsAlternateHandsOnTheRhythm : UCk_AutoTest_Base
{
    // A poll budget, not a ceiling: the jabs run on the rhythm's own clock.
    private const int32 k_SlowPolls = 900;

    private FCk_Handle_Punch _Punch;
    private FMars_Punch_Spec _Spec;
    private TArray<EMars_Hand> _Thrown;
    private TArray<EMars_Hand> _Blows;
    private int32 _BlowsThatHit = 0;
    // The left fist's clock when the right was thrown.
    private TOptional<float32> _LeftElapsedAtRightThrow;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        // Slow enough that every stroke spans several frames in a headless lane.
        _Spec.Rhythm.ImpactSeconds = 0.4f;
        _Spec.Rhythm.RecoverySeconds = 0.6f;
        _Spec.Rhythm.IntervalSeconds = 0.5f;
        _Spec.Rhythm.ComboSeconds = 1.5f;

        auto Entity = utils_entity_lifetime::Request_CreateEntity(InHandle);
        _Punch = utils_punch::Add(Entity, _Spec);
        _Punch.BindTo_OnThrown(FMars_Delegate_Punch_OnThrown(this, n"OnThrown"));
        _Punch.BindTo_OnBlow(FMars_Delegate_Punch_OnBlow(this, n"OnBlow"));

        Add_Step("fresh fists are home and the clock's boundaries hold", n"Step_AssertFresh");
        Add_Step("throw", n"Step_Throw");
        Add_Step_WaitUntil("the first jab is thrown", n"Check_OneThrown", 0, 0);
        Add_Step("it is the left, travelling out; throw again inside the interval", n"Step_AssertLeftOutAndThrow");
        Add_Step_WaitUntil("the second jab is thrown", n"Check_TwoThrown", k_SlowPolls, 0);
        Add_Step("it is the right, an interval after the left", n"Step_AssertRightAfterTheInterval");
        Add_Step_WaitUntil("both fists are home", n"Check_FistsHome", k_SlowPolls, 0);
        Add_Step("each jab dealt one blow; throw a third", n"Step_AssertBlowsAndThrow");
        Add_Step_WaitUntil("the third jab is home again", n"Check_ThreeThrownAndHome", k_SlowPolls, 0);
        Add_Step("it was the left: the next hand is the right", n"Step_AssertThirdIsLeft");
        Add_Step_WaitUntil("the combo ends: the next hand is the lead hand", n"Check_NextIsLead", k_SlowPolls, 0);
        Add_Step("nothing more was thrown", n"Step_AssertDone");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void OnThrown(FCk_Handle_Punch InPunch, EMars_Hand InHand)
    {
        _Thrown.Add(InHand);
        if (InHand == EMars_Hand::Right && _LeftElapsedAtRightThrow.IsSet() == false)
        { _LeftElapsedAtRightThrow = TOptional<float32>(InPunch.Get_Fist(EMars_Hand::Left).Elapsed); }
    }

    UFUNCTION()
    private void OnBlow(FCk_Handle_Punch InPunch, EMars_Hand InHand, FCk_ShapeCast_Result InHit)
    {
        _Blows.Add(InHand);
        if (ck::IsValid(InHit.Get_HitEntity()))
        { _BlowsThatHit += 1; }
    }

    UFUNCTION()
    private void Step_AssertFresh(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Valid(_Punch, "utils_punch::Add composed the fists");
        Assert_False(_Punch.Get_IsPunching(), "fresh fists are home");
        Assert_True(_Punch.Get_NextHand() == EMars_Hand::Left, "the first throw uses the lead hand, the left");
        Assert_Equals_Int(_Punch.Get_JabsThrown(), 0, "nothing thrown yet");

        const auto& Rhythm = _Spec.Rhythm;
        Assert_True(utils_punch::Get_StrokeAt(Rhythm, 0.0f) == EMars_Punch_Stroke::Out, "a fist just thrown travels out");
        Assert_True(utils_punch::Get_StrokeAt(Rhythm, Rhythm.ImpactSeconds) == EMars_Punch_Stroke::Back, "at ImpactSeconds it turns back");
        Assert_True(utils_punch::Get_StrokeAt(Rhythm, utils_punch::Get_JabSeconds(Rhythm)) == EMars_Punch_Stroke::None,
            "ImpactSeconds + RecoverySeconds after the throw it is home");

        auto Fist = FMars_Punch_Fist();
        Assert_Equals_Float(utils_punch::Get_Extension(Rhythm, Fist), 0.0f, 0.0001f, "a fist at home is not extended");
        Fist.Stroke = EMars_Punch_Stroke::Out;
        Fist.Elapsed = Rhythm.ImpactSeconds * 0.5f;
        Assert_Equals_Float(utils_punch::Get_Extension(Rhythm, Fist), 0.5f, 0.0001f, "halfway to the blow it is half extended");
        Fist.Stroke = EMars_Punch_Stroke::Back;
        Fist.Elapsed = Rhythm.ImpactSeconds;
        Assert_Equals_Float(utils_punch::Get_Extension(Rhythm, Fist), 1.0f, 0.0001f, "at the blow it is fully extended");
        Fist.Elapsed = Rhythm.ImpactSeconds + Rhythm.RecoverySeconds * 0.75f;
        Assert_Equals_Float(utils_punch::Get_Extension(Rhythm, Fist), 0.25f, 0.0001f, "three quarters through the recovery a quarter is left");
    }

    UFUNCTION()
    private void Step_Throw(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Punch.Request_Throw(FMars_Request_Punch_Throw());
    }

    UFUNCTION()
    private void Check_OneThrown(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Punch.Get_JabsThrown() >= 1);
    }

    UFUNCTION()
    private void Step_AssertLeftOutAndThrow(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Thrown.Num(), 1, "OnThrown fired once");
        Assert_True(_Thrown.Num() == 1 && _Thrown[0] == EMars_Hand::Left, "the first jab is the left");
        Assert_True(_Punch.Get_Stroke(EMars_Hand::Left) == EMars_Punch_Stroke::Out,
            f"the left fist travels out (got {_Punch.Get_Stroke(EMars_Hand::Left) :n})");
        Assert_True(_Punch.Get_Stroke(EMars_Hand::Right) == EMars_Punch_Stroke::None, "the right fist is home");
        Assert_True(_Punch.Get_NextHand() == EMars_Hand::Right, "the next throw uses the right");
        Assert_Equals_Int(_Blows.Num(), 0, "no blow before ImpactSeconds");

        _Punch.Request_Throw(FMars_Request_Punch_Throw());
    }

    UFUNCTION()
    private void Check_TwoThrown(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Punch.Get_JabsThrown() >= 2);
    }

    UFUNCTION()
    private void Step_AssertRightAfterTheInterval(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Thrown.Num() == 2 && _Thrown[1] == EMars_Hand::Right, f"the second jab is the right (thrown {_Thrown.Num()})");
        Assert_True(_LeftElapsedAtRightThrow.IsSet(), "the right's throw was announced");
        if (_LeftElapsedAtRightThrow.IsSet() == false)
        { return; }

        const auto LeftElapsed = _LeftElapsedAtRightThrow.GetValue();
        Assert_True(LeftElapsed >= _Spec.Rhythm.IntervalSeconds - 0.0001f,
            f"the right was thrown no sooner than IntervalSeconds after the left (the left's clock read {LeftElapsed})");
        Assert_True(LeftElapsed < utils_punch::Get_JabSeconds(_Spec.Rhythm),
            f"the left was still in flight then: the two jabs overlap (the left's clock read {LeftElapsed})");
    }

    UFUNCTION()
    private void Check_FistsHome(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Punch.Get_IsPunching() == false);
    }

    UFUNCTION()
    private void Step_AssertBlowsAndThrow(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Blows.Num() == 2 && _Blows[0] == EMars_Hand::Left && _Blows[1] == EMars_Hand::Right,
            f"each jab dealt one blow, the left's then the right's (got {_Blows.Num()})");
        Assert_Equals_Int(_BlowsThatHit, 0, "a thrower without a DamageDealer hits nothing");
        Assert_Equals_Float(_Punch.Get_Extension(EMars_Hand::Left), 0.0f, 0.0001f, "the left fist is home");
        Assert_Equals_Float(_Punch.Get_Extension(EMars_Hand::Right), 0.0f, 0.0001f, "the right fist is home");

        _Punch.Request_Throw(FMars_Request_Punch_Throw());
    }

    UFUNCTION()
    private void Check_ThreeThrownAndHome(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Punch.Get_JabsThrown() >= 3 && _Punch.Get_IsPunching() == false);
    }

    UFUNCTION()
    private void Step_AssertThirdIsLeft(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Thrown.Num() == 3 && _Thrown[2] == EMars_Hand::Left, f"the third jab is the left again (thrown {_Thrown.Num()})");
        Assert_True(_Punch.Get_NextHand() == EMars_Hand::Right, "inside the combo window the next hand is the right");
    }

    UFUNCTION()
    private void Check_NextIsLead(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Punch.Get_NextHand() == EMars_Hand::Left);
    }

    UFUNCTION()
    private void Step_AssertDone(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Punch.Get_JabsThrown(), 3, "three throws were three jabs");
        Assert_Equals_Int(_Blows.Num(), 3, "three blows");
        Assert_False(_Punch.Get_HasWaitingThrow(), "no throw is left waiting");
    }
}
