// The real searing station with lost pieces lingering one second, nobody operating. The server admits the slab and, once it
// lies on the pan, teleports its body 80 cm beside the pan; when its kernel raises OnPieceLost it reports (step 1), and
// once the entry is gone it reports again (step 2). On the client the piece read Lost at step 1 or in a sampled frame
// before step 2; at step 2 its kernel has no rows, its summary counts one lost, and its copy is gone.
// Surface: Ck.Searing.Net.AS_Searing_ALostPieceLeavesTheClientsBooks
class UCk_AutoTest_Net_Searing_ALostPieceLeavesTheClientsBooks : UMars_AutoTestRig_NetHeatStation
{
    default _TimeoutSeconds = 25.0f;

    private const float64 k_X = 325000.0;
    private const FVector k_BesideThePanLocal = FVector(80.0, 0.0, 20.0);

    private FMars_CookingFeed_PieceId _Id;

    // Client: whether its kernel ever read the piece Lost, and the copy it found at step 1.
    private bool _SawLost = false;
    private FGuid _CopyId;

    protected EMars_TESTONLY_HeatStation Get_HeatStation() const override
    {
        return EMars_TESTONLY_HeatStation::Searing;
    }

    protected FMars_Searing_Spec Make_SearingSpec() const override
    {
        auto Spec = FMars_Searing_Spec();
        Spec.Loss.LingerSeconds = 1.0f;
        return Spec;
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
        Spawn_FoodsThen(mars_items::Food_MeatSlab(), 1, n"OnServerFoods");
    }

    UFUNCTION()
    private void OnServerFoods(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Spawn_HeatStation();
    }

    protected void On_ServerFeedStationReady() override
    {
        _Followed.Add(_Foods[0].As_FoodPiece());
        _Id = Admit(_Foods[0].As_FoodPiece());
        WaitUntil(n"Is_ServerOnPan", n"OnServerOnPan", k_SlowPolls);
    }

    // On the pan: it has arrived at its release, so the loss is judged from its next pose.
    UFUNCTION()
    private void Is_ServerOnPan(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_Searing.Get_HasPiece(_Id) && _Searing.Get_PieceContact(_Id) == EMars_Searing_Contact::OnPan);
    }

    UFUNCTION()
    private void OnServerOnPan(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto PanBaseWorld = _Searing.Get_PanBaseWorld();
        auto Body = _Searing.Get_PieceBody(_Id);
        const auto PieceWorld = utils_transform::Get_EntityCurrentTransform(_Searing.Get_PieceEntity(_Id).As_Transform());
        utils_jolt_body::Request_Teleport(Body,
            FCk_Request_JoltBody_Teleport(PanBaseWorld.TransformPosition(k_BesideThePanLocal), PieceWorld.Rotator()));
        WaitUntil(n"Is_ServerLost", n"OnServerLost", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerLost(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_LostIds.Num() > 0);
    }

    UFUNCTION()
    private void OnServerLost(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Mark_Time("step1");
        Report_HeatStep(1);
        WaitUntil(n"Is_ServerGone", n"OnServerGone", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerGone(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_Searing.Get_HasPiece(_Id) == false);
    }

    UFUNCTION()
    private void OnServerGone(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Mark_Time("step2");
        // The lost piece is destroyed by now: the client took its id at step 1.
        _Followed.Empty();
        Report_HeatStep(2);
        End_HeatServer(f"{Describe_Pan()} {Describe_SearingLedger()} {Describe_SearingRecord()}");
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Client
    //----------------------------------------------------------------------------------------------------------------------

    protected void On_HeatStationSample() override
    {
        if (Get_IsServer())
        { return; }

        const auto Report = Get_HeatStationReport();
        if (Report.Step < 1 || Report.Step >= 2 || Report.BowlIds.Num() == 0)
        { return; }

        const auto Id = Report.BowlIds[0];
        if (_Searing.Get_HasPiece(Id) && _Searing.Get_PieceStatus(Id) == EMars_Searing_PieceStatus::Lost)
        { _SawLost = true; }
    }

    protected void On_ClientStep(int32 InStep) override
    {
        if (InStep == 1)
        {
            Mark_Time("step1");
            const auto Report = Get_HeatStationReport();
            _Id = Report.BowlIds.Num() > 0 ? Report.BowlIds[0] : FMars_CookingFeed_PieceId();
            _CopyId = Report.PieceGuids.Num() > 0 ? Report.PieceGuids[0] : FGuid();
            if (_Searing.Get_HasPiece(_Id) && _Searing.Get_PieceStatus(_Id) == EMars_Searing_PieceStatus::Lost)
            { _SawLost = true; }

            Log_HeatStation(f"step 1: sawLost={_SawLost} {Describe_Pan()} {Describe_SearingLedger()}");
            Await_Step(2);
            return;
        }

        Mark_Time("step2");
        const auto Copy = Find_PieceById(_CopyId);
        Assert_True(_SawLost, "the client read the piece Lost before its entry went");
        Assert_Equals_Int(_Searing.Get_PieceIds().Num(), 0, f"the client's kernel has no rows ({Describe_SearingLedger()})");
        Assert_Equals_Int(_Searing.Get_Summary().Lost, 1, "the client's summary counts one lost");
        Assert_False(Get_IsLive(Copy), "the client's copy is gone");
        End_HeatClient(f"sawLost={_SawLost} copyLive={Get_IsLive(Copy)} {Describe_Pan()} {Describe_SearingLedger()} {Describe_SearingRecord()}");
    }
}
