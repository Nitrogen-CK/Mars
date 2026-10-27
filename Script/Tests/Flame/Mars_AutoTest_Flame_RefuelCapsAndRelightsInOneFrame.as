// A refuel adds measures capped at full, and a refuel and a Lit in one frame light a spent, snuffed flame (refuels drain
// before the ignition). A flame on an entity with no world item lights its World radius.
class UMars_AutoTest_Flame_RefuelCapsAndRelightsInOneFrame : UCk_AutoTest_Base
{
    private FCk_Handle_Flame _Flame;
    private int32 _LitEdges = 0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Fuel = FMars_Flame_Fuel();
        Fuel.Measures = 3;
        Fuel.StartMeasures = TOptional<int32>(0);

        auto Spec = FMars_Flame_Spec();
        Spec.Fuel = TOptional<FMars_Flame_Fuel>(Fuel);

        auto Entity = utils_entity_lifetime::Request_CreateEntity(InHandle);
        _Flame = utils_flame::Add(Entity, Spec);
        _Flame.BindTo_OnLitChanged(FMars_Delegate_Flame_OnLitChanged(this, n"OnLitChanged"));

        Add_Step("it starts spent and snuffed", n"Step_AssertSpent");
        Add_Step("refuel and light it in one frame", n"Step_RefuelAndLight");
        Add_Step_WaitUntil("it lights", n"Check_Lit", 0, 0);
        Add_Step("it lit with the refuel's measures, at its World radius", n"Step_AssertRelit");
        Add_Step("refuel it past full", n"Step_Overfill");
        Add_Step_WaitUntil("the refuel lands", n"Check_Full", 0, 0);
        Add_Step("it is capped at full and lit once", n"Step_AssertCapped");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void OnLitChanged(FCk_Handle_Flame InFlame, bool InIsLit)
    {
        _LitEdges += 1;
    }

    UFUNCTION()
    private void Step_AssertSpent(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Flame.Get_Condition() == EMars_Flame_Condition::Spent, "an empty flame is spent");
        Assert_True(_Flame.Get_CanRefuel(), "an empty refuelable flame can be refuelled");
        Assert_False(_Flame.Get_CanSelfLight(), "an empty flame cannot light itself");
        Assert_False(_Flame.Get_IsLit(), "it is dark");
    }

    UFUNCTION()
    private void Step_RefuelAndLight(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Flame.Request_Refuel(FMars_Request_Flame_Refuel(2));
        _Flame.Request_SetIgnition(FMars_Request_Flame_SetIgnition(EMars_Flame_Ignition::Lit));
    }

    UFUNCTION()
    private void Check_Lit(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Flame.Get_IsLit());
    }

    UFUNCTION()
    private void Step_AssertRelit(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Flame.Get_MeasuresLeft(), 2, "the refuel's two measures");
        Assert_True(_Flame.Get_Condition() == EMars_Flame_Condition::Steady, "two measures burn steady");
        Assert_True(_Flame.Get_LightRadius() == FMars_Flame_Radius().World, "a flame with no world item lights its World radius");
    }

    UFUNCTION()
    private void Step_Overfill(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Flame.Request_Refuel(FMars_Request_Flame_Refuel(5));
    }

    UFUNCTION()
    private void Check_Full(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Flame.Get_MeasuresLeft() == 3);
    }

    UFUNCTION()
    private void Step_AssertCapped(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Flame.Get_MeasuresLeft(), 3, "a refuel never passes Measures");
        Assert_False(_Flame.Get_CanRefuel(), "a full flame takes no more");
        Assert_Equals_Int(_LitEdges, 1, "it lit once and stayed lit");
    }
}
