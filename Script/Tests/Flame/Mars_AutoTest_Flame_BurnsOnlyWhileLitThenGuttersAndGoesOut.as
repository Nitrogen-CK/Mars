// A snuffed flame keeps its fuel. Lit, it burns one measure every SecondsPerMeasure, gutters through the last
// GutterSeconds of the last, then goes out: each change broadcast once, in order, and the Burning tag gone. Spent, it is
// still set Lit: only the fuel put it out.
class UMars_AutoTest_Flame_BurnsOnlyWhileLitThenGuttersAndGoesOut : UCk_AutoTest_Base
{
    // A poll budget, not a ceiling: the flame burns one measure every SecondsPerMeasure.
    private const int32 k_SlowPolls = 900;

    private FCk_Handle_Flame _Flame;
    private TArray<int32> _Measures;
    private TArray<EMars_Flame_Condition> _Conditions;
    private TArray<bool> _Lit;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Fuel = FMars_Flame_Fuel();
        Fuel.Measures = 3;
        Fuel.SecondsPerMeasure = 0.2f;
        Fuel.GutterSeconds = 0.1f;

        auto Spec = FMars_Flame_Spec();
        Spec.Fuel = TOptional<FMars_Flame_Fuel>(Fuel);

        auto Entity = utils_entity_lifetime::Request_CreateEntity(InHandle);
        _Flame = utils_flame::Add(Entity, Spec);
        _Flame.BindTo_OnMeasuresChanged(FMars_Delegate_Flame_OnMeasuresChanged(this, n"OnMeasuresChanged"));
        _Flame.BindTo_OnConditionChanged(FMars_Delegate_Flame_OnConditionChanged(this, n"OnConditionChanged"));
        _Flame.BindTo_OnLitChanged(FMars_Delegate_Flame_OnLitChanged(this, n"OnLitChanged"));

        Add_Step("it starts full, snuffed and dark", n"Step_AssertSnuffed");
        Add_Step_WaitSeconds("leave it snuffed", 0.3f);
        Add_Step("a snuffed flame burnt nothing", n"Step_AssertUnburnt");
        Add_Step("light it", n"Step_Light");
        Add_Step_WaitUntil("it lights", n"Check_Lit", 0, 0);
        Add_Step_WaitUntil("it burns out", n"Check_Spent", k_SlowPolls, 0);
        Add_Step_WaitSeconds("let it sit spent", 0.3f);
        Add_Step("it burnt one measure at a time, guttered, then went out", n"Step_AssertBurntOut");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void OnMeasuresChanged(FCk_Handle_Flame InFlame, int32 InMeasuresLeft)
    {
        _Measures.Add(InMeasuresLeft);
    }

    UFUNCTION()
    private void OnConditionChanged(FCk_Handle_Flame InFlame, EMars_Flame_Condition InCondition)
    {
        _Conditions.Add(InCondition);
    }

    UFUNCTION()
    private void OnLitChanged(FCk_Handle_Flame InFlame, bool InIsLit)
    {
        _Lit.Add(InIsLit);
    }

    UFUNCTION()
    private void Step_AssertSnuffed(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Flame.Get_MeasuresLeft(), 3, "it starts full");
        Assert_False(_Flame.Get_IsLit(), "a snuffed flame is dark");
        Assert_True(_Flame.Get_Condition() == EMars_Flame_Condition::Steady, "a full flame is steady");
        Assert_False(_Flame.Has_Fragment(FMars_Tag_Flame_Burning), "a snuffed flame does not burn");
        Assert_True(_Flame.Get_LightRadius() == 0.0f, "a dark flame lights nothing");
    }

    UFUNCTION()
    private void Step_AssertUnburnt(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Flame.Get_MeasuresLeft(), 3, "it kept every measure");
        Assert_True(_Flame.Get_FuelFraction() == 1.0f, "it kept all its fuel");
        Assert_Equals_Int(_Measures.Num(), 0, "nothing changed");
    }

    UFUNCTION()
    private void Step_Light(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Flame.Request_SetIgnition(FMars_Request_Flame_SetIgnition(EMars_Flame_Ignition::Lit));
    }

    UFUNCTION()
    private void Check_Lit(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Flame.Get_IsLit());
    }

    UFUNCTION()
    private void Check_Spent(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Flame.Get_Condition() == EMars_Flame_Condition::Spent);
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

        Assert_Equals_Int(_Conditions.Num(), 2, "the condition changed twice");
        if (_Conditions.Num() == 2)
        {
            Assert_True(_Conditions[0] == EMars_Flame_Condition::Guttering, "it guttered first");
            Assert_True(_Conditions[1] == EMars_Flame_Condition::Spent, "then it went out");
        }

        Assert_Equals_Int(_Lit.Num(), 2, "it lit once and went dark once");
        if (_Lit.Num() == 2)
        {
            Assert_True(_Lit[0], "lighting lit it");
            Assert_False(_Lit[1], "running out darkened it");
        }

        Assert_Equals_Int(_Flame.Get_MeasuresLeft(), 0, "it stays empty");
        Assert_True(_Flame.Get_Ignition() == EMars_Flame_Ignition::Lit, "it is still set Lit");
        Assert_False(_Flame.Get_IsLit(), "a spent flame set Lit is dark");
        Assert_False(_Flame.Has_Fragment(FMars_Tag_Flame_Burning), "a spent flame stops burning");
    }
}
