// Fire passes from a lit bare flame to an unlit bare one, never into or out of glass: A (lit, bare) can light B (unlit,
// bare, needs a flame) but not C (unlit, glass); D (lit, glass) cannot light B. B lit from A lights the next pass and fires
// OnLitChanged once. A light from a flame that has since gone out, or that is gone, is dropped quietly: B2 stays dark and
// nothing ensures. Isolated origin: (10000, 0, -60000).
class UMars_AutoTest_Flame_OpenFirePassesToOpenAndNeverThroughGlass : UCk_AutoTest_Base
{
    private const FVector k_Origin = FVector(10000.0, 0.0, -60000.0);

    private FCk_Handle_Flame _A;
    private FCk_Handle_Flame _B;
    private FCk_Handle_Flame _C;
    private FCk_Handle_Flame _D;
    private FCk_Handle_Flame _B2;
    private FCk_Handle_Flame _E;
    private TArray<bool> _BLit;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        _A = Add_Flame(InHandle, Make_Spec(EMars_Flame_Ignition::Lit, EMars_Flame_Enclosure::Open, EMars_Flame_Lighting::SelfLighting), 0.0);
        _B = Add_Flame(InHandle, Make_Spec(EMars_Flame_Ignition::Snuffed, EMars_Flame_Enclosure::Open, EMars_Flame_Lighting::NeedsAFlame), 200.0);
        _C = Add_Flame(InHandle, Make_Spec(EMars_Flame_Ignition::Snuffed, EMars_Flame_Enclosure::Enclosed, EMars_Flame_Lighting::SelfLighting), 400.0);
        _D = Add_Flame(InHandle, Make_Spec(EMars_Flame_Ignition::Lit, EMars_Flame_Enclosure::Enclosed, EMars_Flame_Lighting::SelfLighting), 600.0);
        _B2 = Add_Flame(InHandle, Make_Spec(EMars_Flame_Ignition::Snuffed, EMars_Flame_Enclosure::Open, EMars_Flame_Lighting::NeedsAFlame), 800.0);
        _E = Add_Flame(InHandle, Make_Spec(EMars_Flame_Ignition::Lit, EMars_Flame_Enclosure::Open, EMars_Flame_Lighting::SelfLighting), 1000.0);
        _B.BindTo_OnLitChanged(FMars_Delegate_Flame_OnLitChanged(this, n"OnBLitChanged"));

        Add_Step("only a lit bare flame lights, and only a bare flame", n"Step_AssertIgniteRules");
        Add_Step("light B from A", n"Step_LightBFromA");
        Add_Step_WaitUntil("B lights", n"Check_BLit", 0, 0);
        Add_Step("B lit once; A is unchanged", n"Step_AssertBLit");
        Add_Step("snuff A", n"Step_SnuffA");
        Add_Step_WaitUntil("A goes out", n"Check_ADark", 0, 0);
        Add_Step("light B2 from A, which went out", n"Step_LightB2FromA");
        Add_Step_WaitSeconds("let the request drain", 0.1f);
        Add_Step("B2 stayed dark", n"Step_AssertB2Dark");
        Add_Step("destroy E", n"Step_DestroyE");
        Add_Step_WaitUntil("E is gone", n"Check_EGone", 0, 0);
        Add_Step("light B2 from E, which is gone", n"Step_LightB2FromE");
        Add_Step_WaitSeconds("let the request drain", 0.1f);
        Add_Step("B2 stayed dark", n"Step_AssertB2Dark");
        Run_Steps(InHandle);
    }

    // Unlimited fuel, the defaults' radii.
    private FMars_Flame_Spec Make_Spec(EMars_Flame_Ignition InIgnition, EMars_Flame_Enclosure InEnclosure, EMars_Flame_Lighting InLighting) const
    {
        auto Spec = FMars_Flame_Spec();
        Spec.StartIgnition = InIgnition;
        Spec.Enclosure = InEnclosure;
        Spec.Lighting = InLighting;
        return Spec;
    }

    // A bare flame entity, InOffsetY along Y from the origin.
    private FCk_Handle_Flame Add_Flame(FCk_Handle InHandle, FMars_Flame_Spec InSpec, float64 InOffsetY)
    {
        auto Entity = utils_entity_lifetime::Request_CreateEntity(InHandle);
        utils_transform::Add(Entity, FTransform(FRotator::ZeroRotator, k_Origin + FVector(0.0, InOffsetY, 0.0)), ECk_Replication::DoesNotReplicate);
        return utils_flame::Add(Entity, InSpec);
    }

    UFUNCTION()
    private void OnBLitChanged(FCk_Handle_Flame InFlame, bool InIsLit)
    {
        _BLit.Add(InIsLit);
    }

    UFUNCTION()
    private void Step_AssertIgniteRules(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_A.Get_CanPassFire(), "a lit bare flame passes fire");
        Assert_False(_D.Get_CanPassFire(), "a lit flame behind glass does not");
        Assert_True(_B.Get_CanBeLitBy(_A), "B (bare) can be lit by A (lit, bare)");
        Assert_False(_C.Get_CanBeLitBy(_A), "C (glass) cannot be lit by A: so its light is never asked for");
        Assert_False(_B.Get_CanBeLitBy(_D), "B cannot be lit by D (lit, glass)");
        Assert_False(_A.Get_CanBeLitBy(_A), "a flame cannot light itself");
        Assert_False(_B.Get_CanSelfLight(), "B needs a flame");
    }

    UFUNCTION()
    private void Step_LightBFromA(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _B.Request_SetIgnition(FMars_Request_Flame_SetIgnition(EMars_Flame_Ignition::Lit, _A));
    }

    UFUNCTION()
    private void Check_BLit(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_B.Get_IsLit());
    }

    UFUNCTION()
    private void Step_AssertBLit(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_B.Get_Ignition() == EMars_Flame_Ignition::Lit, "B is lit");
        Assert_Equals_Int(_BLit.Num(), 1, "OnLitChanged fired once");
        if (_BLit.Num() == 1)
        { Assert_True(_BLit[0], "the edge lit it"); }

        Assert_True(_A.Get_IsLit(), "passing fire leaves A lit");
        Assert_False(_C.Get_IsLit(), "C stays dark");
        Assert_False(_B.Get_CanBeLitBy(_A), "a lit flame cannot be lit again");
    }

    UFUNCTION()
    private void Step_SnuffA(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _A.Request_SetIgnition(FMars_Request_Flame_SetIgnition(EMars_Flame_Ignition::Snuffed));
    }

    UFUNCTION()
    private void Check_ADark(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_A.Get_IsLit() == false);
    }

    // The request reaches the drain after its Source went out: the race a held torch snuffed in the same frame makes.
    UFUNCTION()
    private void Step_LightB2FromA(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_False(_B2.Get_CanBeLitBy(_A), "a dark flame cannot light B2");
        _B2.Request_SetIgnition(FMars_Request_Flame_SetIgnition(EMars_Flame_Ignition::Lit, _A));
    }

    UFUNCTION()
    private void Step_AssertB2Dark(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_False(_B2.Get_IsLit(), "B2 is dark");
        Assert_True(_B2.Get_Ignition() == EMars_Flame_Ignition::Snuffed, "the light from a flame that cannot pass fire was dropped");
    }

    UFUNCTION()
    private void Step_DestroyE(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_B2.Get_CanBeLitBy(_E), "E could light B2 while it lived");
        utils_entity_lifetime::Request_DestroyEntity(_E.H());
    }

    UFUNCTION()
    private void Check_EGone(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(ck::Is_NOT_Valid(_E));
    }

    UFUNCTION()
    private void Step_LightB2FromE(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _B2.Request_SetIgnition(FMars_Request_Flame_SetIgnition(EMars_Flame_Ignition::Lit, _E));
    }
}
