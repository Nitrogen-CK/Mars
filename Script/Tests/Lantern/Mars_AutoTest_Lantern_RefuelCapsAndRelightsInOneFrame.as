// A refuel adds measures capped at full, and a refuel and an open in one frame light a spent, shuttered lantern (refuels
// drain before the shutter). A lantern on an entity with no world item lights its World radius.
class UMars_AutoTest_Lantern_RefuelCapsAndRelightsInOneFrame : UCk_AutoTest_Base
{
    private FCk_Handle_Lantern _Lantern;
    private int32 _LitEdges = 0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Spec = FMars_Lantern_Spec();
        Spec.Measures = 3;
        Spec.StartMeasures = TOptional<int32>(0);

        auto Entity = utils_entity_lifetime::Request_CreateEntity(InHandle);
        _Lantern = utils_lantern::Add(Entity, Spec);
        _Lantern.BindTo_OnLitChanged(FMars_Delegate_Lantern_OnLitChanged(this, n"OnLitChanged"));

        Add_Step("it starts spent and shuttered", n"Step_AssertSpent");
        Add_Step("refuel and open it in one frame", n"Step_RefuelAndOpen");
        Add_Step_WaitUntil("it lights", n"Check_Lit", 0, 0);
        Add_Step("it lit with the refuel's measures, at its World radius", n"Step_AssertRelit");
        Add_Step("refuel it past full", n"Step_Overfill");
        Add_Step_WaitUntil("the refuel lands", n"Check_Full", 0, 0);
        Add_Step("it is capped at full and lit once", n"Step_AssertCapped");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void OnLitChanged(FCk_Handle_Lantern InLantern, bool InIsLit)
    {
        _LitEdges += 1;
    }

    UFUNCTION()
    private void Step_AssertSpent(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Lantern.Get_Flame() == EMars_Lantern_Flame::Spent, "an empty lantern is spent");
        Assert_True(_Lantern.Get_CanRefuel(), "an empty lantern can be refuelled");
        Assert_False(_Lantern.Get_IsLit(), "it is dark");
    }

    UFUNCTION()
    private void Step_RefuelAndOpen(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Lantern.Request_Refuel(FMars_Request_Lantern_Refuel(2));
        _Lantern.Request_SetShutter(FMars_Request_Lantern_SetShutter(EMars_Lantern_Shutter::Open));
    }

    UFUNCTION()
    private void Check_Lit(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Lantern.Get_IsLit());
    }

    UFUNCTION()
    private void Step_AssertRelit(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Lantern.Get_MeasuresLeft(), 2, "the refuel's two measures");
        Assert_True(_Lantern.Get_Flame() == EMars_Lantern_Flame::Steady, "two measures burn steady");
        Assert_True(_Lantern.Get_LightRadius() == FMars_Lantern_Radius().World, "a lantern with no world item lights its World radius");
    }

    UFUNCTION()
    private void Step_Overfill(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Lantern.Request_Refuel(FMars_Request_Lantern_Refuel(5));
    }

    UFUNCTION()
    private void Check_Full(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Lantern.Get_MeasuresLeft() == 3);
    }

    UFUNCTION()
    private void Step_AssertCapped(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Lantern.Get_MeasuresLeft(), 3, "a refuel never passes Measures");
        Assert_False(_Lantern.Get_CanRefuel(), "a full lantern takes no more");
        Assert_Equals_Int(_LitEdges, 1, "it lit once and stayed lit");
    }
}
