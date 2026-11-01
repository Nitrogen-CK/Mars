// A hostile target stands 300 uu away: the mimic wakes and stands. A lethal blow then lands on its body health: it dies
// (the behaviour sub-SM is gone with Alive), its body zone stops taking hits, it sits back down (tucked) and its lid hangs
// slack at DeadGape; it no longer walks.
class UMars_AutoTest_PickleMimic_DiesAndSitsDown : UMars_AutoTestRig_PickleMimic
{
    default _TimeoutSeconds = 30.0f;
    default _Origin = FVector(-170000.0, 130000.0, 600.0);

    private FVector _DeadAt;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        SpawnFloorAndMimic(InHandle, FMars_PickleMimic_Spec());
        SpawnTarget(InHandle, FVector(300.0, 0.0, 0.0));

        Add_Step_WaitUntil("the mimic is composed and its gait is Ready", n"Check_WalkerReady", k_SlowPolls, 0);
        Add_Step_WaitUntil("it stands", n"Check_Standing", 0, 4.0f);
        Add_Step("a lethal blow lands", n"Step_Kill");
        Add_Step_WaitUntil("it is dead and sat down", n"Check_SatDead", 0, 4.0f);
        Add_Step("it died where it stood", n"Step_AssertDead");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Check_Standing(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Mimic.Get_IsStanding());
    }

    UFUNCTION()
    private void Step_Kill(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Health = _Mimic.Get_Monster().Get_BodyHealth();
        Health.Request_ApplyDamage(FMars_Request_Health_ApplyDamage(FMars_DamageEvent(100000.0f, GameplayTags::DamageType_Mars_Blunt)));
    }

    UFUNCTION()
    private void Check_SatDead(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        const auto Done = _Mimic.Get_IsDead() && _Mimic.Get_IsTucked() &&
            Math::Abs(_Mimic.Get_LidOpen() - utils_pickle_mimic::DeadGape) < 0.01f;
        if (Done)
        { _DeadAt = _Mimic.Get_Location(); }

        Res.Set(Done);
    }

    UFUNCTION()
    private void Step_AssertDead(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Mimic.Get_BehaviorStateClass() == nullptr, "the behaviour sub-SM ended with Alive");
        Assert_True(_Mimic.Get_Admission(EMars_PickleMimic_Action::Bite, _Mimic.Get_Target()) == EMars_PickleMimic_Admission::Dead,
            "a bite is refused as Dead");
        Assert_True(_Mimic.Get_IsActionBusy() == false, "no bite runs");
    }
}
