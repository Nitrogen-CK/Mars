// The real fry station, nobody operating. The server drives the skimmer on its own kernel and looks it, in one look, to the
// basket's centre; once its scoop is over the basket and at its target it reports the target and its scoop's root-frame
// location (step 1). On the client the kernel reads Driven, its target is the reported one (0.1 cm), its scoop's root XY
// is within 2 cm of the server's, and its scoop's largest move between two frames is at most the server's own largest
// (reported) plus 0.5 cm: the follower moves no more abruptly than the leader.
// Surface: Ck.Fry.Net.AS_Fry_TheSkimmerFollowsTheAuthorityOnTheClient
class UCk_AutoTest_Net_Fry_TheSkimmerFollowsTheAuthorityOnTheClient : UMars_AutoTestRig_NetHeatStation
{
    default _TimeoutSeconds = 25.0f;

    private const float64 k_X = 360000.0;
    private const float64 k_TargetToleranceCm = 0.1;
    private const float64 k_ScoopToleranceCm = 2.0;
    private const float64 k_FrameStepMarginCm = 0.5;

    protected EMars_TESTONLY_HeatStation Get_HeatStation() const override
    {
        return EMars_TESTONLY_HeatStation::Fry;
    }

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_HeatStationRig(InHandle, k_X);
        if (Get_IsServer() == false)
        { Await_Step(1); }
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Server
    //----------------------------------------------------------------------------------------------------------------------

    protected void On_ServerPlatterReady() override
    {
        Spawn_HeatStation();
    }

    protected void On_ServerFeedStationReady() override
    {
        _Fry.Request_SetDrive(FMars_Request_Fry_SetDrive(EMars_Implement_Drive::Driven));
        _Fry.Request_Look(FMars_Request_Fry_Look(Get_LookTowardBasket(1.0)));
        WaitUntil(n"Is_ServerOverBasket", n"OnServerOverBasket", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerOverBasket(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_Fry.Get_IsScoopOverBasket() && Get_IsScoopAtTarget());
    }

    UFUNCTION()
    private void OnServerOverBasket(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Mark_Time("step1");
        const auto Target = _Fry.Get_SkimmerTarget();
        _ReportTarget = FVector(Target.X, Target.Y, 0.0);
        _ReportScoop = _Fry.Get_ScoopRoot();
        FString StepAt = "";
        const auto LargestStep = Get_LargestScoopStep(0, StepAt);
        _ReportValue = float32(LargestStep);
        Report_HeatStep(1);
        End_HeatServer(f"largestStep={LargestStep} at=[{StepAt}] samples={_ScoopSamples.Num()} {Describe_Fry()} {Describe_FryLedger()} {Describe_FryRecord()}");
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Client
    //----------------------------------------------------------------------------------------------------------------------

    protected void On_ClientStep(int32 InStep) override
    {
        Mark_Time("step1");
        const auto Report = Get_HeatStationReport();
        const auto Target = _Fry.Get_SkimmerTarget();
        const auto TargetError = (Target - FVector2D(Report.Target.X, Report.Target.Y)).Size();
        const auto Scoop = _Fry.Get_ScoopRoot();
        const auto ScoopError = (FVector2D(Scoop.X, Scoop.Y) - FVector2D(Report.Scoop.X, Report.Scoop.Y)).Size();
        FString StepAt = "";
        const auto LargestStep = Get_LargestScoopStep(0, StepAt);
        const auto ServerStep = float64(Report.Value);
        Assert_True(_Fry.Get_Drive() == EMars_Implement_Drive::Driven, f"the client's kernel reads Driven ({Describe_Fry()} {Describe_FryLedger()})");
        Assert_True(TargetError <= k_TargetToleranceCm, f"the client's target is the server's (client {Target}, server {Report.Target})");
        Assert_True(ScoopError <= k_ScoopToleranceCm, f"the client's scoop is within 2 cm of the server's (client {Scoop}, server {Report.Scoop})");
        Assert_True(LargestStep <= ServerStep + k_FrameStepMarginCm,
            f"the client's scoop never moved more abruptly than the server's plus 0.5 cm in a frame (client {LargestStep} at {StepAt}, server {ServerStep})");
        End_HeatClient(f"targetError={TargetError} scoopError={ScoopError} largestStep={LargestStep} serverLargestStep={ServerStep} at=[{StepAt}] samples={_ScoopSamples.Num()} {Describe_Fry()} {Describe_FryLedger()}");
    }
}
