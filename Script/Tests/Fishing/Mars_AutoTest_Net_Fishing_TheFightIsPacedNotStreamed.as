// With a reel slow enough that the line does not run out, the server engages its spot directly and casts; once Waiting it
// forces a bite, strikes and holds the reel for 2 s, lets go and reports. The client counts the sampled frames in which its
// ledger's line or aim changed while the ledger read the reel held: at most 34 (the pace, not every frame) and at least 5.
// Surface: Ck.Fishing.Net.AS_Fishing_TheFightIsPacedNotStreamed
class UCk_AutoTest_Net_Fishing_TheFightIsPacedNotStreamed : UMars_AutoTestRig_NetFishing
{
    default _TimeoutSeconds = 25.0f;

    private const float64 k_X = 463000.0;
    private const float32 k_HoldSeconds = 2.0f;
    private const int32 k_MaxChangedFrames = 34;
    private const int32 k_MinChangedFrames = 5;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_FishingRig(InHandle, k_X);
        if (Get_IsServer() == false)
        { Await_Step(1, EMars_TESTONLY_NetMinigameArrival::Settled); }
    }

    protected void Configure_Spec(FMars_Fishing_Spec& InOutSpec) override
    {
        InOutSpec.Reel.ReelSpeedCmPerS = 100.0f;
    }

    protected void On_ServerStationReady() override
    {
        _Fishing.Request_Engage(FMars_Request_Fishing_Engage());
        _Fishing.Request_Cast(FMars_Request_Fishing_Cast(1.0f));
        Await_Phase(EMars_Fishing_Phase::Waiting, n"OnServerWaiting");
    }

    UFUNCTION()
    private void OnServerWaiting(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _Fishing.Request_ForceBite(FMars_Request_Fishing_ForceBite());
        _Fishing.Request_Hook(FMars_Request_Fishing_Hook());
        _Fishing.Request_ReelHold(FMars_Request_Fishing_ReelHold());
        WaitSeconds(k_HoldSeconds, n"OnServerHeld");
    }

    UFUNCTION()
    private void OnServerHeld(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _Fishing.Request_ReelRelease(FMars_Request_Fishing_ReelRelease());
        Report_Step(FMars_TESTONLY_NetMinigameStep(1));
        End_FishingServer(f"{Describe_Record()} {Describe_Fishing()}");
    }

    protected void On_ClientStep(int32 InStep) override
    {
        auto ChangedFrames = 0;
        auto HeldFrames = 0;
        auto LastCountedFrame = int64(-1);
        auto LastHeldFrame = int64(-1);
        auto HasPrevious = false;
        auto Previous = FMars_TESTONLY_NetFishingLedgerSample();
        for (const auto& Sample : _Samples)
        {
            const auto Ledger = Sample.Ledger;
            const auto IsChanged = HasPrevious && (Ledger.Line.LengthCm != Previous.Line.LengthCm || Ledger.Line.Tension != Previous.Line.Tension
                || Ledger.Aim.YawDeg != Previous.Aim.YawDeg || Ledger.Aim.PitchDeg != Previous.Aim.PitchDeg);
            Previous = Ledger;
            HasPrevious = true;
            if (Ledger.Reel != EMars_Fishing_Reel::Held)
            { continue; }

            if (Sample.Frame != LastHeldFrame)
            {
                LastHeldFrame = Sample.Frame;
                ++HeldFrames;
            }

            if (IsChanged && Sample.Frame != LastCountedFrame)
            {
                LastCountedFrame = Sample.Frame;
                ++ChangedFrames;
            }
        }

        Log_Minigame(f"changedFrames={ChangedFrames} heldFrames={HeldFrames} {Describe_Record()} {Describe_Fishing()}");
        Assert_True(ChangedFrames <= k_MaxChangedFrames, f"the client's ledger changed in at most {k_MaxChangedFrames} sampled frames of the hold ({ChangedFrames} of {HeldFrames})");
        Assert_True(ChangedFrames >= k_MinChangedFrames, f"the client's ledger changed in at least {k_MinChangedFrames} sampled frames of the hold ({ChangedFrames} of {HeldFrames})");
        End_FishingClient(f"{Describe_Record()} {Describe_Fishing()}");
    }
}
