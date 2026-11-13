// A remote look carries the seconds it took on the sender. Two samples that land in one drain, their look totals 4 and 8
// degrees and their look seconds 0.05 and 0.1 past the seed, make one look delta of 8 degrees that took 0.1 s. A local look
// delta takes this frame: its seconds are unset. After a clear the next sample seeds again and raises no look.
class UMars_AutoTest_InputIntents_ARemoteLookCarriesItsOwnSeconds : UCk_AutoTest_Base
{
    private const FVector k_SeedTotal = FVector(10.0, 0.0, 0.0);
    private const float32 k_SeedSeconds = 1.0f;
    private const FVector k_ReseedTotal = FVector(50.0, 0.0, 0.0);

    private FCk_Handle_InputIntents _Intents;
    private int32 _SeenSequence = 0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Entity = InHandle;
        _Intents = utils_input_intents::Add(Entity);

        Add_Step("a seeding sample", n"Step_Seed");
        Add_Step_WaitUntil("the seed drained", n"Check_Seeded", 0, 0);
        Add_Step("the seed raised no look", n"Step_AssertSeedQuiet");
        Add_Step("two samples land in one drain", n"Step_TwoSamples");
        Add_Step_WaitUntil("the look delta drained", n"Check_LookAdvanced", 0, 0);
        Add_Step("one look delta of 8 degrees that took 0.1 s", n"Step_AssertMerged");
        Add_Step("a local look delta", n"Step_LocalLook");
        Add_Step_WaitUntil("the local look drained", n"Check_LookAdvanced", 0, 0);
        Add_Step("a local look has no seconds", n"Step_AssertLocalUnset");
        Add_Step("a clear and a sample in one drain", n"Step_ClearAndSample");
        Add_Step_WaitUntil("the sample seeded again", n"Check_Reseeded", 0, 0);
        Add_Step("the new seed raised no look", n"Step_AssertReseedQuiet");
        Run_Steps(InHandle);
    }

    private void Apply_Look(FVector InTotal, float32 InSeconds)
    {
        auto Sample = FMars_InputIntents_RemoteSample();
        Sample.LookTotal = InTotal;
        Sample.LookSeconds = InSeconds;
        _Intents.Request_ApplyRemoteSample(FMars_Request_InputIntents_ApplyRemoteSample(Sample));
    }

    private TOptional<FVector> TryGet_RemoteLookTotal()
    {
        if (_Intents.Has_Fragment(FMars_Fragment_InputIntents_Remote) == false)
        { return TOptional<FVector>(); }

        return _Intents.Get_Fragment(FMars_Fragment_InputIntents_Remote).LookTotal;
    }

    private FString Describe_Seconds()
    {
        const auto Seconds = _Intents.Get_LookDeltaSeconds();
        return Seconds.IsSet() ? f"{Seconds.GetValue()}" : "unset";
    }

    UFUNCTION()
    private void Check_Seeded(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(TryGet_RemoteLookTotal() == k_SeedTotal);
    }

    UFUNCTION()
    private void Check_LookAdvanced(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Intents.Get_LookDeltaSequence() != _SeenSequence);
    }

    UFUNCTION()
    private void Check_Reseeded(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(TryGet_RemoteLookTotal() == k_ReseedTotal);
    }

    UFUNCTION()
    private void Step_Seed(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _SeenSequence = _Intents.Get_LookDeltaSequence();
        Apply_Look(k_SeedTotal, k_SeedSeconds);
    }

    UFUNCTION()
    private void Step_AssertSeedQuiet(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Intents.Get_LookDeltaSequence(), _SeenSequence, "the seed raised no look delta");
    }

    UFUNCTION()
    private void Step_TwoSamples(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _SeenSequence = _Intents.Get_LookDeltaSequence();
        Apply_Look(k_SeedTotal + FVector(4.0, 0.0, 0.0), k_SeedSeconds + 0.05f);
        Apply_Look(k_SeedTotal + FVector(8.0, 0.0, 0.0), k_SeedSeconds + 0.1f);
    }

    UFUNCTION()
    private void Step_AssertMerged(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Delta = _Intents.Get_LookDelta();
        const auto Seconds = _Intents.Get_LookDeltaSeconds();
        const auto SecondsText = Describe_Seconds();
        Log(f"[InputIntentsTest] two remote samples in one drain: delta {Delta}, seconds {SecondsText}, sequence {_SeenSequence} -> {_Intents.Get_LookDeltaSequence()}");
        Assert_Equals_Int(_Intents.Get_LookDeltaSequence(), _SeenSequence + 1, "the two samples advanced the look once");
        Assert_True(Delta.Equals(FVector(8.0, 0.0, 0.0), 0.001), f"one look delta of 8 degrees (got {Delta})");
        Assert_True(Seconds.IsSet() && Math::Abs(Seconds.GetValue() - 0.1f) < 0.0001f, f"the look took 0.1 s on the sender (got {Describe_Seconds()})");
    }

    UFUNCTION()
    private void Step_LocalLook(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _SeenSequence = _Intents.Get_LookDeltaSequence();
        _Intents.Request_AddLookDelta(FMars_Request_InputIntents_AddLookDelta(FVector(2.0, 0.0, 0.0)));
    }

    UFUNCTION()
    private void Step_AssertLocalUnset(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Intents.Get_LookDelta().Equals(FVector(2.0, 0.0, 0.0), 0.001), f"the local look delta drained (got {_Intents.Get_LookDelta()})");
        Assert_True(_Intents.Get_LookDeltaSeconds().IsSet() == false, f"a local look has no seconds (got {Describe_Seconds()})");
    }

    UFUNCTION()
    private void Step_ClearAndSample(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _SeenSequence = _Intents.Get_LookDeltaSequence();
        _Intents.Request_ClearRemote(FMars_Request_InputIntents_ClearRemote());
        Apply_Look(k_ReseedTotal, 7.0f);
    }

    UFUNCTION()
    private void Step_AssertReseedQuiet(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto& Remote = _Intents.Get_Fragment(FMars_Fragment_InputIntents_Remote);
        Assert_Equals_Int(_Intents.Get_LookDeltaSequence(), _SeenSequence, "the sample after the clear seeded and raised no look");
        Assert_True(Remote.LookSeconds.IsSet() && Remote.LookSeconds.GetValue() == 7.0f, "the look seconds were seeded with the look total");
    }
}
