// The server engages its spot directly, aims 10 degrees right and casts at half power; once its spot reads Waiting it reports
// where its bait lies. The client raised OnCast once and OnPhaseChanged Casting then Waiting, once each, in that order;
// while it read Casting its bait was above the water and moved in at least 5 sampled frames; at the report its bait lies
// within 5 cm of the server's and it has a line out.
// Surface: Ck.Fishing.Net.AS_Fishing_ACastFliesAndLandsOnTheClient
class UCk_AutoTest_Net_Fishing_ACastFliesAndLandsOnTheClient : UMars_AutoTestRig_NetFishing
{
    default _TimeoutSeconds = 25.0f;

    private const float64 k_X = 460000.0;
    private const int32 k_MinFlyingFrames = 5;
    private const float64 k_MaxBaitErrorCm = 5.0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_FishingRig(InHandle, k_X);
        if (Get_IsServer() == false)
        { Await_Step(1, EMars_TESTONLY_NetMinigameArrival::Settled); }
    }

    protected void On_ServerStationReady() override
    {
        _Fishing.Request_Engage(FMars_Request_Fishing_Engage());
        _Fishing.Request_Aim(FMars_Request_Fishing_Aim(10.0f, 0.0f));
        _Fishing.Request_Cast(FMars_Request_Fishing_Cast(0.5f));
        Await_Phase(EMars_Fishing_Phase::Waiting, n"OnServerWaiting");
    }

    UFUNCTION()
    private void OnServerWaiting(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Report_Point(_Fishing.Get_Bait().Position);
        Report_Step(FMars_TESTONLY_NetMinigameStep(1));
        End_FishingServer(f"{Describe_Record()} {Describe_Fishing()}");
    }

    protected void On_ClientStep(int32 InStep) override
    {
        const auto Reported = Get_ReportedPoint();
        const auto Surface = _FishingSpec.Water.SurfaceZ;

        auto FlyingFrames = 0;
        auto LastFrame = int64(-1);
        auto LastCastingBait = FVector::ZeroVector;
        auto HasPrevious = false;
        auto Previous = FVector::ZeroVector;
        for (const auto& Sample : _Samples)
        {
            if (Sample.Phase != EMars_Fishing_Phase::Casting || Sample.Frame == LastFrame)
            { continue; }

            LastFrame = Sample.Frame;
            LastCastingBait = Sample.Bait.Position;
            const auto HasMoved = HasPrevious && Sample.Bait.Position.Distance(Previous) > 0.01;
            if (Sample.Bait.Position.Z > Surface && HasMoved)
            { ++FlyingFrames; }

            Previous = Sample.Bait.Position;
            HasPrevious = true;
        }

        const auto Bait = _Fishing.Get_Bait().Position;
        const auto Error = Bait.Distance(Reported);
        Log_Minigame(f"landing error={Error} flightEndError={Get_HorizontalDistance(LastCastingBait, Reported)} flyingFrames={FlyingFrames} {Describe_Record()} {Describe_Fishing()}");

        const auto CastingAt = Find_Phase(EMars_Fishing_Phase::Casting, 0);
        const auto WaitingAt = Find_Phase(EMars_Fishing_Phase::Waiting, 0);
        Assert_Equals_Int(Get_SignalCount(EMars_TESTONLY_NetFishingSignal::OnCast), 1, f"the client raised OnCast once ({Describe_Record()})");
        Assert_Equals_Int(Count_Phase(EMars_Fishing_Phase::Casting), 1, f"the client raised Casting once ({Describe_Record()})");
        Assert_Equals_Int(Count_Phase(EMars_Fishing_Phase::Waiting), 1, f"the client raised Waiting once ({Describe_Record()})");
        Assert_True(CastingAt >= 0 && WaitingAt > CastingAt, f"the client raised Casting before Waiting ({Describe_Record()})");
        Assert_True(FlyingFrames >= k_MinFlyingFrames, f"the client's bait flew above the water in at least {k_MinFlyingFrames} sampled frames ({FlyingFrames})");
        Assert_True(Error <= k_MaxBaitErrorCm, f"the client's bait lies within {k_MaxBaitErrorCm} cm of the server's ({Bait} vs {Reported}: {Error})");
        Assert_True(_Fishing.Get_HasLineOut(), "the client has a line out");
        End_FishingClient(f"{Describe_Record()} {Describe_Fishing()}");
    }
}
