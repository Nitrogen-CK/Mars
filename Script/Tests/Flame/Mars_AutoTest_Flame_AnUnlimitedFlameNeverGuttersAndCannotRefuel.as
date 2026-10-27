// A flame with no fuel block (a fixture's) burns forever: lit, its clock never runs, it stays Steady and full, nothing about
// its fuel is ever broadcast, and it cannot be refuelled. With no world item it shows its World probe. Snuffed, it goes
// dark. Isolated origin: (6000, 0, -60000).
class UMars_AutoTest_Flame_AnUnlimitedFlameNeverGuttersAndCannotRefuel : UCk_AutoTest_Base
{
    private FCk_Handle_Flame _Flame;
    private TArray<bool> _Lit;
    private int32 _MeasuresEdges = 0;
    private int32 _ConditionEdges = 0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Entity = utils_entity_lifetime::Request_CreateEntity(InHandle);
        utils_transform::Add(Entity, FTransform(FRotator::ZeroRotator, FVector(6000.0, 0.0, -60000.0)), ECk_Replication::DoesNotReplicate);

        auto Spec = FMars_Flame_Spec();
        Spec.Lighting = EMars_Flame_Lighting::NeedsAFlame;
        Spec.Radius.World = 500.0f;

        _Flame = utils_flame::Add(Entity, Spec);
        _Flame.BindTo_OnLitChanged(FMars_Delegate_Flame_OnLitChanged(this, n"OnLitChanged"));
        _Flame.BindTo_OnMeasuresChanged(FMars_Delegate_Flame_OnMeasuresChanged(this, n"OnMeasuresChanged"));
        _Flame.BindTo_OnConditionChanged(FMars_Delegate_Flame_OnConditionChanged(this, n"OnConditionChanged"));

        Add_Step("it starts snuffed, steady and full", n"Step_AssertUnlit");
        Add_Step("light it from another lit bare flame", n"Step_Light");
        Add_Step_WaitUntil("it lights and shows its World probe", n"Check_LitAndShown", 0, 0);
        Add_Step_WaitSeconds("let it burn", 0.5f);
        Add_Step("it burnt nothing and never guttered", n"Step_AssertUnburnt");
        Add_Step("snuff it", n"Step_Snuff");
        Add_Step_WaitUntil("it goes dark", n"Check_Dark", 0, 0);
        Add_Step("it lit once and went dark once", n"Step_AssertSnuffed");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void OnLitChanged(FCk_Handle_Flame InFlame, bool InIsLit)
    {
        _Lit.Add(InIsLit);
    }

    UFUNCTION()
    private void OnMeasuresChanged(FCk_Handle_Flame InFlame, int32 InMeasuresLeft)
    {
        _MeasuresEdges += 1;
    }

    UFUNCTION()
    private void OnConditionChanged(FCk_Handle_Flame InFlame, EMars_Flame_Condition InCondition)
    {
        _ConditionEdges += 1;
    }

    UFUNCTION()
    private void Step_AssertUnlit(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_False(_Flame.Get_IsLit(), "it starts snuffed");
        Assert_True(_Flame.Get_Condition() == EMars_Flame_Condition::Steady, "unlimited fuel is steady");
        Assert_Equals_Float(_Flame.Get_FuelFraction(), 1.0f, 0.0001f, "unlimited fuel is full");
        Assert_False(_Flame.Get_CanRefuel(), "unlimited fuel cannot be refuelled");
        Assert_False(_Flame.Get_CanSelfLight(), "a flame that needs a flame cannot light itself");
        Assert_Equals_Int(_Flame.Get_MeasuresLeft(), 0, "unlimited fuel counts no measures");
        Assert_False(ck::IsValid(_Flame.Get_LightProbe(EMars_Flame_Pool::Stowed)), "a flame that snuffs stowed has no Stowed probe");
    }

    // A second bare flame, lit, on its own entity: the source that lights this one.
    UFUNCTION()
    private void Step_Light(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Spec = FMars_Flame_Spec();
        Spec.StartIgnition = EMars_Flame_Ignition::Lit;

        auto SourceEntity = utils_entity_lifetime::Request_CreateEntity(InHandle);
        const auto Source = utils_flame::Add(SourceEntity, Spec);
        Assert_True(_Flame.Get_CanBeLitBy(Source), "a lit bare flame can light an unlit bare one");

        _Flame.Request_SetIgnition(FMars_Request_Flame_SetIgnition(EMars_Flame_Ignition::Lit, Source));
    }

    UFUNCTION()
    private void Check_LitAndShown(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto Shown = _Flame.Get_ShownLightPool();
        auto Res = OutResult;
        Res.Set(_Flame.Get_IsLit() && Shown.IsSet() && Shown.GetValue() == EMars_Flame_Pool::World);
    }

    UFUNCTION()
    private void Step_AssertUnburnt(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto& State = _Flame.Get_Fragment(FMars_Fragment_Flame);
        Assert_True(_Flame.Get_IsLit(), "it is still lit");
        Assert_True(_Flame.Get_Condition() == EMars_Flame_Condition::Steady, "it stays steady");
        Assert_Equals_Float(_Flame.Get_FuelFraction(), 1.0f, 0.0001f, "it stays full");
        Assert_False(_Flame.Get_CanRefuel(), "it still cannot be refuelled");
        Assert_Equals_Int(_Flame.Get_MeasuresLeft(), 0, "it still counts no measures");
        Assert_True(State.MeasureElapsed == 0.0f, "its measure clock never ran");
        Assert_Equals_Float(_Flame.Get_LightRadius(), 500.0f, 0.01f, "it lights its World radius");
        Assert_Equals_Int(_MeasuresEdges, 0, "OnMeasuresChanged never fired");
        Assert_Equals_Int(_ConditionEdges, 0, "OnConditionChanged never fired");
    }

    UFUNCTION()
    private void Step_Snuff(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Flame.Request_SetIgnition(FMars_Request_Flame_SetIgnition(EMars_Flame_Ignition::Snuffed));
    }

    UFUNCTION()
    private void Check_Dark(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Flame.Get_IsLit() == false && _Flame.Get_ShownLightPool().IsSet() == false);
    }

    UFUNCTION()
    private void Step_AssertSnuffed(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Lit.Num(), 2, "OnLitChanged fired for the lighting and the snuffing");
        if (_Lit.Num() == 2)
        {
            Assert_True(_Lit[0], "the first edge lit it");
            Assert_False(_Lit[1], "the second put it out");
        }

        Assert_Equals_Int(_MeasuresEdges, 0, "OnMeasuresChanged never fired");
        Assert_Equals_Int(_ConditionEdges, 0, "OnConditionChanged never fired");
    }
}
