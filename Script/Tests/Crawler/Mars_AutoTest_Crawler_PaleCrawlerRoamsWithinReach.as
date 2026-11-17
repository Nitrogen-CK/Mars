// The pale crawler roaming on a flat floor for 20 s keeps every foot well inside its chain's reach of its hip: a foot
// dragged to the full reach straightens the leg (the visible "stretched leg"; the gait's force-step bound is 0.92 of the
// reach, and a foot within a few percent past it is a transient), and every leg steps. Reports the per-leg maximum
// stretch (foot-to-hip distance over reach), step count and the body's travel.
class UMars_AutoTest_Crawler_PaleCrawlerRoamsWithinReach : UMars_AutoTestRig_Crawler
{
    default _TimeoutSeconds = 60.0f;
    default _Origin = FVector(130000.0, 140000.0, 600.0);

    private const float64 k_SampleSeconds = 20.0;
    private const float64 k_MaxStretch = 0.96;

    private TArray<FCk_Handle_ProceduralLeg> _Legs;
    private TArray<FVector> _HipsLocal;
    private TArray<float64> _Reaches;
    private TArray<float64> _MaxStretch;
    private TArray<int32> _LegSteps;
    private TArray<ECk_ProceduralLeg_FootPhase> _LastPhases;
    private float64 _Travel = 0.0;
    private FVector _LastBody;
    private float64 _SamplingSince = -1.0;
    private int32 _Samples = 0;
    // Diagnostics: the first moment each leg crosses k_DiagStretch, and the body's yaw a sample ago.
    private const float64 k_DiagStretch = 0.95;
    private TArray<FString> _Diag;
    private float64 _LastYaw = 0.0;
    private float64 _LastTime = 0.0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Spec = FMars_Crawler_Spec(8, FBox(_Origin - FVector(700.0, 700.0, 200.0), _Origin + FVector(700.0, 700.0, 200.0)));
        Spec.Layout = EMars_Crawler_Layout::PaleCrawler;
        Spec.RoamDwellSeconds = 0.5f;
        SpawnFloorAndCrawler(InHandle, Spec);

        Add_Step_WaitUntil("the crawler is composed, its gait Ready and its 8 parts registered", n"Check_Ready", k_SlowPolls, 0);
        Add_Step("start sampling the legs", n"Step_StartSampling");
        Add_Step_WaitUntil("20 s of roaming sampled", n"Check_Sampled", 4000, 0);
        Add_Step("every foot stayed within reach and every leg stepped", n"Step_Assert");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_StartSampling(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const TArray<FCk_ProceduralLeg_Spec> LegSpecs = _Crawler.Get_Spec().Get_RigData().Get_Legs();
        const auto Parts = _Crawler.Get_LegParts();
        for (int32 Index = 0; Index < Parts.Num(); ++Index)
        {
            FCk_Handle LegEntity = Parts[Index];
            _Legs.Add(LegEntity.As_ProceduralLeg());
            _HipsLocal.Add(LegSpecs[Index].Get_Placement().Get_HipLocal());
            _Reaches.Add(utils_crawler::Get_ChainReach(LegSpecs[Index]));
            _MaxStretch.Add(0.0);
            _LegSteps.Add(0);
            _LastPhases.Add(ECk_ProceduralLeg_FootPhase::Planted);
        }

        _LastBody = BodyLocation();
        _SamplingSince = System::GetGameTimeInSeconds();
        _LastTime = _SamplingSince;
        _LastYaw = utils_transform::Get_EntityCurrentTransform(_Crawler.As_Transform()).Rotator().Yaw;
        for (int32 Index = 0; Index < _Legs.Num(); ++Index)
        { _Diag.Add(""); }
        utils_timer::Create_Tick(InHandle, FCk_Delegate_Timer(this, n"OnSampleTick"));
    }

    UFUNCTION()
    private void OnSampleTick(FCk_Handle_Timer InHandle, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        if (_SamplingSince < 0.0 || ck::Is_NOT_Valid(_Crawler))
        { return; }

        const auto Root = utils_transform::Get_EntityCurrentTransform(_Crawler.As_Transform());
        const auto Body = BodyLocation();
        const auto Now = System::GetGameTimeInSeconds();
        const auto Dt = Math::Max(Now - _LastTime, 1.0e-4);
        const auto Speed = (Body - _LastBody).Size2D() / Dt;
        const auto Yaw = Root.Rotator().Yaw;
        const auto YawRate = Math::FindDeltaAngleDegrees(_LastYaw, Yaw) / Dt;
        _Travel += (Body - _LastBody).Size2D();
        _LastBody = Body;
        _LastYaw = Yaw;
        _LastTime = Now;
        ++_Samples;

        for (int32 Index = 0; Index < _Legs.Num(); ++Index)
        {
            const auto Foot = utils_procedural_leg::Get_Foot(_Legs[Index]);
            if (Foot.Get_Phase() == ECk_ProceduralLeg_FootPhase::Planted && _LastPhases[Index] == ECk_ProceduralLeg_FootPhase::Swinging)
            { ++_LegSteps[Index]; }
            _LastPhases[Index] = Foot.Get_Phase();

            const auto Stretch = (Foot.Get_Position() - Root.TransformPosition(_HipsLocal[Index])).Size() / _Reaches[Index];
            _MaxStretch[Index] = Math::Max(_MaxStretch[Index], Stretch);
            if (Stretch > k_DiagStretch && _Diag[Index].IsEmpty())
            {
                const auto FootBody = Root.InverseTransformPosition(Foot.Get_Position());
                const auto Control = _Crawler.Get_Articulation().Get_LimbControl(utils_procedural_leg::Get_Id(_Legs[Index]));
                _Diag[Index] = f"t {Now - _SamplingSince :.2} s, speed {Speed :.0} cm/s, yaw rate {YawRate :.0} deg/s, body z {Body.Z - _Origin.Z :.1}, foot {Foot.Get_Phase() :n}, foot(body) {FootBody.ToString()}, hip(body) {_HipsLocal[Index].ToString()}, control {Control.Get_State() :n} participating {Control.Get_Participating()} reason {Control.Get_Reason()}, steps so far {_LegSteps[Index]}";
            }
        }
    }

    UFUNCTION()
    private void Check_Sampled(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_SamplingSince >= 0.0 && System::GetGameTimeInSeconds() - _SamplingSince >= k_SampleSeconds);
    }

    UFUNCTION()
    private void Step_Assert(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        FString Text = f"travel {_Travel :.0} cm over {_Samples} samples;";
        for (int32 Index = 0; Index < _Legs.Num(); ++Index)
        { Text = f"{Text} [leg {Index}: max stretch {_MaxStretch[Index] :.3}, {_LegSteps[Index]} steps]"; }

        Print(Text);
        for (int32 Index = 0; Index < _Legs.Num(); ++Index)
        {
            if (_Diag[Index].IsEmpty() == false)
            { Print(f"DIAG leg {Index} first over {k_DiagStretch :.2}: {_Diag[Index]}"); }
        }
        Assert_True(_Travel > 200.0, f"the crawler roamed ({Text})");
        for (int32 Index = 0; Index < _Legs.Num(); ++Index)
        {
            Assert_True(_MaxStretch[Index] <= k_MaxStretch, f"leg {Index} stayed within its reach ({Text})");
            Assert_True(_LegSteps[Index] > 0, f"leg {Index} stepped ({Text})");
        }
    }
}
