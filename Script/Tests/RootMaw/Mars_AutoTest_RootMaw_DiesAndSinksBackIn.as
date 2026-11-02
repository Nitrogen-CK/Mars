// A hostile target stands 300 uu away: the Maw bursts up. A lethal blow then lands on its body health: it dies (the
// behaviour sub-SM is gone with Alive), sinks back into the ground (buried) with its jaw slack at DeadGape, and neither
// glides nor bites.
class UMars_AutoTest_RootMaw_DiesAndSinksBackIn : UMars_AutoTestRig_RootMaw
{
    default _TimeoutSeconds = 30.0f;
    default _Origin = FVector(-250000.0, 140000.0, 600.0);

    private FVector _DeadAt;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        SpawnFloorAndMaw(InHandle, FMars_RootMaw_Spec());
        SpawnTarget(InHandle, FVector(300.0, 0.0, 0.0));

        Add_Step_WaitUntil("the Maw is composed and grounded", n"Check_Ready", k_SlowPolls, 0);
        Add_Step_WaitUntil("it is up", n"Check_Up", 0, 4.0f);
        Add_Step("a lethal blow lands", n"Step_Kill");
        Add_Step_WaitUntil("it is dead and sunk back in", n"Check_SunkDead", 0, 4.0f);
        Add_Step("it died and sank where it was", n"Step_AssertDead");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Check_Up(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Maw.Get_IsEmerged());
    }

    UFUNCTION()
    private void Step_Kill(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Health = _Maw.Get_Monster().Get_BodyHealth();
        Health.Request_ApplyDamage(FMars_Request_Health_ApplyDamage(FMars_DamageEvent(100000.0f, GameplayTags::DamageType_Mars_Blunt)));
    }

    UFUNCTION()
    private void Check_SunkDead(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        const auto Done = _Maw.Get_IsDead() && _Maw.Get_IsBuried() &&
            Math::Abs(_Maw.Get_JawOpen() - utils_root_maw::DeadGape) < 0.01f;
        if (Done)
        { _DeadAt = _Maw.Get_Location(); }

        Res.Set(Done);
    }

    UFUNCTION()
    private void Step_AssertDead(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Maw.Get_BehaviorStateClass() == nullptr, "the behaviour sub-SM ended with Alive");
        Assert_True(_Maw.Get_Admission(EMars_RootMaw_Action::Bite, _Maw.Get_Target()) == EMars_RootMaw_Admission::Dead,
            "a bite is refused as Dead");
        Assert_True(_Maw.Get_IsActionBusy() == false, "no bite runs");
        Assert_True((_Maw.Get_Location() - _DeadAt).Size() <= 2.0, "it did not glide on once dead");
    }
}
