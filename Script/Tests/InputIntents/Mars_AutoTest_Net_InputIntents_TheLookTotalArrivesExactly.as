// The client feeds 200 look deltas, one a frame, from a seeded generator, with every third sample not sent: the deltas the
// server's FMars_LookCursor read over the subject's InputIntents sum to the generator's total within 1e-9, and nothing
// more arrives after. The server knows the total from the same generator, not from the stream.
// Surface: Ck.InputIntents.Net.AS_InputIntents_TheLookTotalArrivesExactly
class UCk_AutoTest_Net_InputIntents_TheLookTotalArrivesExactly : UMars_AutoTestRig_NetInputIntents
{
    private const int32 k_Deltas = 200;
    private const int64 k_Seed = 20261111;
    private const float64 k_Tolerance = 1e-9;

    private int64 _Generator = 0;
    private int32 _DeltasFed = 0;
    private int32 _FlushFrames = 0;
    private FVector _FedTotal = FVector::ZeroVector;

    private FMars_LookCursor _ServerLook;
    private FVector _ServerSum = FVector::ZeroVector;
    private FVector _ExpectedTotal = FVector::ZeroVector;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Subject = Get_SubjectEntity();
        if (ck::Is_NOT_Valid(Subject))
        { FinishFailure("subject entity not found"); return; }

        Begin_NetInputIntentsTest();
        _DropEvery = 3;
        _Generator = k_Seed;

        if (utils_net::Get_HasAuthority(Subject) == false)
        {
            WaitUntil(n"Is_ClientFed", n"OnClientFed", k_SlowPolls);
            return;
        }

        for (int32 Index = 0; Index < k_Deltas; ++Index)
        { _ExpectedTotal += Next_Delta(); }

        _ServerLook.Seed(_Intents);
        WaitUntil(n"Is_ServerAtTheTotal", n"OnServerAtTheTotal", k_SlowPolls);
    }

    // A delta of up to 2 degrees each way on yaw and pitch, from a 31-bit linear congruential generator.
    private FVector Next_Delta()
    {
        const auto X = Next_Unit();
        const auto Y = Next_Unit();
        return FVector(X * 4.0 - 2.0, Y * 4.0 - 2.0, 0.0);
    }

    private float64 Next_Unit()
    {
        _Generator = (_Generator * 1103515245 + 12345) % 2147483648;
        return float64(_Generator) / 2147483648.0;
    }

    // One delta a frame after the seed frames, then idle frames to flush; every frame is sampled.
    UFUNCTION()
    private void Is_ClientFed(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        if (_SamplesMade >= k_SeedFrames && _DeltasFed < k_Deltas)
        {
            const auto Delta = Next_Delta();
            _FedTotal += Delta;
            _DeltasFed += 1;
            _Intents.Request_AddLookDelta(FMars_Request_InputIntents_AddLookDelta(Delta));
        }
        else if (_DeltasFed >= k_Deltas)
        { _FlushFrames += 1; }

        Sample_AndSend();
        Result.Set(_FlushFrames >= k_FlushFrames);
    }

    UFUNCTION()
    private void OnClientFed(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Error = (_Sampler.LookTotal - _FedTotal).GetAbsMax();
        Log(f"[InputIntentsNet] the client fed {_DeltasFed} look deltas totalling {_FedTotal}; its sampler read {_Sampler.LookTotal}; {_SamplesSent} of {_SamplesMade} samples sent");
        Assert_True(Error <= k_Tolerance, f"the client's sampler read every delta it fed (off by {Error})");
        FinishSuccess();
    }

    UFUNCTION()
    private void Is_ServerAtTheTotal(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Tick_ServerLook();
        Result.Set((_ServerSum - _ExpectedTotal).GetAbsMax() <= k_Tolerance);
    }

    UFUNCTION()
    private void OnServerAtTheTotal(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitUntil(n"Is_ServerSettled", n"OnServerSettled", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerSettled(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Tick_ServerLook();
        _ServerSettleFrames += 1;
        Result.Set(_ServerSettleFrames >= k_ServerSettleFrames);
    }

    UFUNCTION()
    private void OnServerSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Error = (_ServerSum - _ExpectedTotal).GetAbsMax();
        Log(f"[InputIntentsNet] the server's look cursor read {_ServerSum} against the generator's {_ExpectedTotal} (off by {Error})");
        Assert_True(Error <= k_Tolerance, f"the server's look reads sum to the client's total within {k_Tolerance} (off by {Error})");
        Assert_True(Get_NewEnsures() == 0, f"no ensure fired (got {Get_NewEnsures()})");
        WaitSeconds(k_ServerHoldSeconds, n"OnServerHeld");
    }

    private void Tick_ServerLook()
    {
        if (_ServerLook.Advance(_Intents))
        { _ServerSum += _Intents.Get_LookDelta(); }
    }
}
