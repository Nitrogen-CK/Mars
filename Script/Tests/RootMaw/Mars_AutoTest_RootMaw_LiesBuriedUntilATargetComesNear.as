// A hostile target stands 1000 uu away, inside the Maw's AcquireRadius but outside its WakeRadius: the Maw takes it as its
// target yet stays Buried (its body sunk BuryDrop into the ground, only the crown showing) with its jaw shut, and does not
// move for 2 s. The target then steps to 300 uu: the Maw goes Emerging, bursts up (OnStance Emerged, the body back on the
// ground under the root) with its maw wide, and goes on to Hunt.
class UMars_AutoTest_RootMaw_LiesBuriedUntilATargetComesNear : UMars_AutoTestRig_RootMaw
{
    default _TimeoutSeconds = 30.0f;
    default _Origin = FVector(-250000.0, 40000.0, 600.0);

    private const float32 k_WatchSeconds = 2.0f;

    private float64 _WatchStart = 0.0;
    private FVector _Start;
    private float64 _WorstDrift = 0.0;
    private float32 _MaxJaw = 0.0f;
    private bool _StayedBuried = true;
    private TArray<EMars_RootMaw_Stance> _Stances;
    private bool _SawEmerging = false;
    private float32 _WidestEmerging = 0.0f;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        SpawnFloorAndMaw(InHandle, FMars_RootMaw_Spec());
        SpawnTarget(InHandle, FVector(1000.0, 0.0, 0.0));

        Add_Step_WaitUntil("the Maw is composed and grounded", n"Check_Ready", k_SlowPolls, 0);
        Add_Step_WaitUntil("it holds the far target and lies buried", n"Check_BuriedWithTarget", 0, 5.0f);
        Add_Step("start watching", n"Step_StartWatching");
        Add_Step_WaitUntil("2 s of the burial watched", n"Check_Watched", 0, k_WatchSeconds + 2.0f);
        Add_Step("the burial held still", n"Step_AssertStill");
        Add_Step("the target steps close", n"Step_Approach");
        Add_Step_WaitUntil("the Maw bursts up and hunts", n"Check_Hunting", 0, 4.0f);
        Add_Step("it came up", n"Step_AssertEmerged");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Check_BuriedWithTarget(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Maw.Get_HasTarget() && _Maw.Get_IsBuried() && _Maw.Get_BehaviorStateClass() == UMars_SmState_RootMaw_Buried);
    }

    UFUNCTION()
    private void Step_StartWatching(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _WatchStart = System::GetGameTimeInSeconds();
        _Start = _Maw.Get_Location();
        _Maw.BindTo_OnStance(FMars_Delegate_RootMaw_OnStance(this, n"OnStance"));
    }

    UFUNCTION()
    private void OnStance(FCk_Handle_RootMaw InMaw, EMars_RootMaw_Stance InStance)
    {
        _Stances.Add(InStance);
    }

    UFUNCTION()
    private void Check_Watched(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        _WorstDrift = Math::Max(_WorstDrift, (_Maw.Get_Location() - _Start).Size());
        _MaxJaw = Math::Max(_MaxJaw, _Maw.Get_JawOpen());
        _StayedBuried = _StayedBuried && _Maw.Get_IsBuried() && _Maw.Get_BehaviorStateClass() == UMars_SmState_RootMaw_Buried;
        Res.Set(System::GetGameTimeInSeconds() - _WatchStart >= k_WatchSeconds);
    }

    UFUNCTION()
    private void Step_AssertStill(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_StayedBuried, "the Maw stayed Buried with a target beyond its WakeRadius");
        Assert_True(_WorstDrift <= 2.0, f"the buried Maw did not move (drifted {_WorstDrift} uu)");
        Assert_True(_MaxJaw <= 0.001f, f"the jaw stayed shut (opened to {_MaxJaw})");
        Assert_True(_Maw.Get_DistanceTravelled() <= 2.0, f"it logged no travel ({_Maw.Get_DistanceTravelled()} uu)");
        const auto Drop = _Maw.Get_Location().Z - _Maw.Get_BodyTransform().GetLocation().Z;
        Assert_Equals_Float(float32(Drop), utils_root_maw::Clearance + utils_root_maw::BuryDrop, 0.5f, "the body lay BuryDrop under the ground");
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
        const auto Emerging = _Maw.Get_BehaviorStateClass() == UMars_SmState_RootMaw_Emerging;
        _SawEmerging = _SawEmerging || Emerging;
        if (Emerging)
        { _WidestEmerging = Math::Max(_WidestEmerging, _Maw.Get_JawOpen()); }

        Res.Set(_Maw.Get_BehaviorStateClass() == UMars_SmState_RootMaw_Hunt);
    }

    UFUNCTION()
    private void Step_AssertEmerged(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_SawEmerging, "the behaviour went through Emerging");
        Assert_True(_Maw.Get_IsEmerged(), "the Maw is up");
        Assert_True(_Stances.Num() >= 1 && _Stances[0] == EMars_RootMaw_Stance::Emerged, "OnStance announced Emerged");
        const auto Drop = _Maw.Get_Location().Z - _Maw.Get_BodyTransform().GetLocation().Z;
        Assert_Equals_Float(float32(Drop), utils_root_maw::Clearance, 0.5f, "the body is back on the ground under the root");
        Assert_True(_WidestEmerging > 0.6f, f"the maw opened wide as it came up ({_WidestEmerging})");
    }
}
