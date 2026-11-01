// A hostile target stands 1000 uu away, inside the mimic's AcquireRadius but outside its WakeRadius: the mimic takes it
// as its target yet stays Disguised, sat down (tucked: its body sunk TuckDrop) with its lid shut, and does not move for
// 2 s. The target then steps to 300 uu: the mimic goes Waking, stands up (OnStance Standing, the body back up under the
// root), cracks its lid open and goes on to Hunt.
class UMars_AutoTest_PickleMimic_SitsDisguisedUntilATargetComesNear : UMars_AutoTestRig_PickleMimic
{
    default _TimeoutSeconds = 30.0f;
    default _Origin = FVector(-170000.0, 50000.0, 600.0);

    private const float32 k_WatchSeconds = 2.0f;

    private float64 _WatchStart = 0.0;
    private FVector _Start;
    private float64 _WorstDrift = 0.0;
    private float32 _MaxLid = 0.0f;
    private bool _WentTucked = true;
    private TArray<EMars_PickleMimic_Stance> _Stances;
    private bool _SawWaking = false;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        SpawnFloorAndMimic(InHandle, FMars_PickleMimic_Spec());
        SpawnTarget(InHandle, FVector(1000.0, 0.0, 0.0));

        Add_Step_WaitUntil("the mimic is composed and its gait is Ready", n"Check_WalkerReady", k_SlowPolls, 0);
        Add_Step_WaitUntil("it holds the far target and sits tucked", n"Check_TuckedWithTarget", 0, 5.0f);
        Add_Step("start watching", n"Step_StartWatching");
        Add_Step_WaitUntil("2 s of the disguise watched", n"Check_Watched", 0, k_WatchSeconds + 2.0f);
        Add_Step("the disguise held still", n"Step_AssertStill");
        Add_Step("the target steps close", n"Step_Approach");
        Add_Step_WaitUntil("the mimic stands and hunts", n"Check_Hunting", 0, 4.0f);
        Add_Step("it woke up", n"Step_AssertWoke");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Check_TuckedWithTarget(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Mimic.Get_HasTarget() && _Mimic.Get_IsTucked() && _Mimic.Get_BehaviorStateClass() == UMars_SmState_PickleMimic_Disguised);
    }

    UFUNCTION()
    private void Step_StartWatching(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _WatchStart = System::GetGameTimeInSeconds();
        _Start = _Mimic.Get_Location();
        _Mimic.BindTo_OnStance(FMars_Delegate_PickleMimic_OnStance(this, n"OnStance"));
    }

    UFUNCTION()
    private void OnStance(FCk_Handle_PickleMimic InMimic, EMars_PickleMimic_Stance InStance)
    {
        _Stances.Add(InStance);
    }

    UFUNCTION()
    private void Check_Watched(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        _WorstDrift = Math::Max(_WorstDrift, (_Mimic.Get_Location() - _Start).Size());
        _MaxLid = Math::Max(_MaxLid, _Mimic.Get_LidOpen());
        _WentTucked = _WentTucked && _Mimic.Get_IsTucked() && _Mimic.Get_BehaviorStateClass() == UMars_SmState_PickleMimic_Disguised;
        Res.Set(System::GetGameTimeInSeconds() - _WatchStart >= k_WatchSeconds);
    }

    UFUNCTION()
    private void Step_AssertStill(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_WentTucked, "the mimic stayed Disguised and tucked with a target beyond its WakeRadius");
        Assert_True(_WorstDrift <= 2.0, f"the disguised mimic did not move (drifted {_WorstDrift} uu)");
        Assert_True(_MaxLid <= 0.001f, f"the lid stayed shut (opened to {_MaxLid})");
        const auto Drop = _Mimic.Get_Location().Z - _Mimic.Get_BodyTransform().GetLocation().Z;
        Assert_Equals_Float(float32(Drop), utils_pickle_mimic::TuckDrop, 0.5f, "the walker body sat TuckDrop under the root");
    }

    UFUNCTION()
    private void Step_Approach(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        MoveTarget(FVector(300.0, 0.0, 0.0));
    }

    UFUNCTION()
    private void Check_Hunting(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        _SawWaking = _SawWaking || _Mimic.Get_BehaviorStateClass() == UMars_SmState_PickleMimic_Waking;
        Res.Set(_Mimic.Get_BehaviorStateClass() == UMars_SmState_PickleMimic_Hunt);
    }

    UFUNCTION()
    private void Step_AssertWoke(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_SawWaking, "the behaviour went through Waking");
        Assert_True(_Mimic.Get_IsStanding(), "the mimic stands");
        Assert_True(_Stances.Num() >= 1 && _Stances[0] == EMars_PickleMimic_Stance::Standing, "OnStance announced Standing");
        const auto Drop = _Mimic.Get_Location().Z - _Mimic.Get_BodyTransform().GetLocation().Z;
        Assert_True(Math::Abs(Drop) <= 0.5, f"the walker body is back up under the root (drop {Drop})");
        Assert_True(_Mimic.Get_LidOpen() > 0.05f, f"the lid is open a crack ({_Mimic.Get_LidOpen()})");
    }
}
