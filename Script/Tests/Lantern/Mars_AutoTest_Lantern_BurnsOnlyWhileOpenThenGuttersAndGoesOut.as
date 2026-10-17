// A shuttered lantern keeps its tallow. Opened, it burns one measure every SecondsPerMeasure, gutters through the last
// GutterSeconds of the last, then goes out: each change broadcast once, in order, and the Burning tag gone.
class UMars_AutoTest_Lantern_BurnsOnlyWhileOpenThenGuttersAndGoesOut : UCk_AutoTest_Base
{
    // A poll budget, not a ceiling: the lantern burns one measure every SecondsPerMeasure.
    private const int32 k_SlowPolls = 900;

    private FCk_Handle_Lantern _Lantern;
    private TArray<int32> _Measures;
    private TArray<EMars_Lantern_Flame> _Flames;
    private TArray<bool> _Lit;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Spec = FMars_Lantern_Spec();
        Spec.Measures = 3;
        Spec.SecondsPerMeasure = 0.2f;
        Spec.GutterSeconds = 0.1f;

        auto Entity = utils_entity_lifetime::Request_CreateEntity(InHandle);
        _Lantern = utils_lantern::Add(Entity, Spec);
        _Lantern.BindTo_OnMeasuresChanged(FMars_Delegate_Lantern_OnMeasuresChanged(this, n"OnMeasuresChanged"));
        _Lantern.BindTo_OnFlameChanged(FMars_Delegate_Lantern_OnFlameChanged(this, n"OnFlameChanged"));
        _Lantern.BindTo_OnLitChanged(FMars_Delegate_Lantern_OnLitChanged(this, n"OnLitChanged"));

        Add_Step("it starts full, shuttered and dark", n"Step_AssertShuttered");
        Add_Step_WaitSeconds("leave it shuttered", 0.3f);
        Add_Step("a shuttered lantern burnt nothing", n"Step_AssertUnburnt");
        Add_Step("open the shutter", n"Step_Open");
        Add_Step_WaitUntil("it lights", n"Check_Lit", 0, 0);
        Add_Step_WaitUntil("it burns out", n"Check_Spent", k_SlowPolls, 0);
        Add_Step_WaitSeconds("let it sit spent", 0.3f);
        Add_Step("it burnt one measure at a time, guttered, then went out", n"Step_AssertBurntOut");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void OnMeasuresChanged(FCk_Handle_Lantern InLantern, int32 InMeasuresLeft)
    {
        _Measures.Add(InMeasuresLeft);
    }

    UFUNCTION()
    private void OnFlameChanged(FCk_Handle_Lantern InLantern, EMars_Lantern_Flame InFlame)
    {
        _Flames.Add(InFlame);
    }

    UFUNCTION()
    private void OnLitChanged(FCk_Handle_Lantern InLantern, bool InIsLit)
    {
        _Lit.Add(InIsLit);
    }

    UFUNCTION()
    private void Step_AssertShuttered(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Lantern.Get_MeasuresLeft(), 3, "it starts full");
        Assert_False(_Lantern.Get_IsLit(), "a shuttered lantern is dark");
        Assert_True(_Lantern.Get_Flame() == EMars_Lantern_Flame::Steady, "a full lantern's flame is steady");
        Assert_False(_Lantern.Has_Fragment(FMars_Tag_Lantern_Burning), "a shuttered lantern does not burn");
        Assert_True(_Lantern.Get_LightRadius() == 0.0f, "a dark lantern lights nothing");
    }

    UFUNCTION()
    private void Step_AssertUnburnt(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Lantern.Get_MeasuresLeft(), 3, "it kept every measure");
        Assert_True(_Lantern.Get_FuelFraction() == 1.0f, "it kept all its tallow");
        Assert_Equals_Int(_Measures.Num(), 0, "nothing changed");
    }

    UFUNCTION()
    private void Step_Open(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Lantern.Request_SetShutter(FMars_Request_Lantern_SetShutter(EMars_Lantern_Shutter::Open));
    }

    UFUNCTION()
    private void Check_Lit(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Lantern.Get_IsLit());
    }

    UFUNCTION()
    private void Check_Spent(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Lantern.Get_Flame() == EMars_Lantern_Flame::Spent);
    }

    UFUNCTION()
    private void Step_AssertBurntOut(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Measures.Num(), 3, "one broadcast per burnt measure");
        if (_Measures.Num() == 3)
        {
            Assert_Equals_Int(_Measures[0], 2, "the first measure burns");
            Assert_Equals_Int(_Measures[1], 1, "then the second");
            Assert_Equals_Int(_Measures[2], 0, "then the last");
        }

        Assert_Equals_Int(_Flames.Num(), 2, "the flame changed twice");
        if (_Flames.Num() == 2)
        {
            Assert_True(_Flames[0] == EMars_Lantern_Flame::Guttering, "it guttered first");
            Assert_True(_Flames[1] == EMars_Lantern_Flame::Spent, "then it went out");
        }

        Assert_Equals_Int(_Lit.Num(), 2, "it lit once and went dark once");
        if (_Lit.Num() == 2)
        {
            Assert_True(_Lit[0], "opening lit it");
            Assert_False(_Lit[1], "running out darkened it");
        }

        Assert_Equals_Int(_Lantern.Get_MeasuresLeft(), 0, "it stays empty");
        Assert_True(_Lantern.Get_Shutter() == EMars_Lantern_Shutter::Open, "its shutter is still open");
        Assert_False(_Lantern.Get_IsLit(), "an open spent lantern is dark");
        Assert_False(_Lantern.Has_Fragment(FMars_Tag_Lantern_Burning), "a spent lantern stops burning");
    }
}
