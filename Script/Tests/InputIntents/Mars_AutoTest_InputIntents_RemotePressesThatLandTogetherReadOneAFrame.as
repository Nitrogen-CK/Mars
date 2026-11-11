// The authority's copy of a remote operator has no matcher: its presses come from remote samples. Presses that land
// together are read one a frame, never merged: two samples in one frame that each carry a press already released read as
// two presses, and one sample that makes up three lost presses reads as three, the last one held until its release.
class UMars_AutoTest_InputIntents_RemotePressesThatLandTogetherReadOneAFrame : UCk_AutoTest_Base
{
    private const FGameplayTag k_Intent = GameplayTags::Mars_Intent_Interact_Primary;
    // Frames the reader polls after each batch of samples: more than a run of three takes to read.
    private const int32 k_ReadFrames = 12;
    // The seed's serial: presses from before the seed never count.
    private const int32 k_SeedSerial = 7;

    private FCk_Handle_InputIntents _Intents;
    private FMars_IntentEdge _Edge;
    private int32 _Presses = 0;
    private int32 _ReadUntilFrame = 0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Entity = InHandle;
        _Intents = utils_input_intents::Add(Entity);

        Add_Step("the first sample seeds", n"Step_Seed");
        Add_Step_WaitUntil("the reader polls the seed", n"Check_ReadFrames", 0, 0);
        Add_Step("the seed raises no press", n"Step_AssertSeedIsQuiet");
        Add_Step("two samples land in one frame, each a press already released", n"Step_TwoInOneFrame");
        Add_Step_WaitUntil("the reader polls the two", n"Check_ReadFrames", 0, 0);
        Add_Step("both presses were read and the row is released", n"Step_AssertTwoRead");
        Add_Step("one sample makes up three presses, the last one held", n"Step_ThreeInOneSample");
        Add_Step_WaitUntil("the reader polls the three", n"Check_ReadFrames", 0, 0);
        Add_Step("three more presses were read and the hold stands", n"Step_AssertThreeMoreAndHeld");
        Add_Step("the release arrives", n"Step_Release");
        Add_Step_WaitUntil("the reader polls the release", n"Check_ReadFrames", 0, 0);
        Add_Step("the hold ended with no further press", n"Step_AssertReleased");
        Run_Steps(InHandle);
    }

    private void Apply_Sample(int32 InSerial, EMars_InputIntents_Hold InHold)
    {
        auto Sample = FMars_InputIntents_RemoteSample();
        Sample.Intents.Add(FMars_InputIntents_RemoteIntent(k_Intent, InSerial, InHold));
        _Intents.Request_ApplyRemoteSample(FMars_Request_InputIntents_ApplyRemoteSample(Sample));
        _ReadUntilFrame = int32(utils_time::Get_FrameCounter()) + k_ReadFrames;
    }

    UFUNCTION()
    private void Check_ReadFrames(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        if (utils_input_intents::Get_HasPress(_Edge.Advance(_Intents, k_Intent)))
        { _Presses += 1; }

        Res.Set(int32(utils_time::Get_FrameCounter()) >= _ReadUntilFrame);
    }

    UFUNCTION()
    private void Step_Seed(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Apply_Sample(k_SeedSerial, EMars_InputIntents_Hold::Released);
    }

    UFUNCTION()
    private void Step_AssertSeedIsQuiet(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Presses, 0, "the seed's serial raises no press");
        Assert_True(_Intents.Get_IsIntentActive(k_Intent) == false, "the seeded row reads inactive");
    }

    UFUNCTION()
    private void Step_TwoInOneFrame(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Apply_Sample(k_SeedSerial + 1, EMars_InputIntents_Hold::Released);
        Apply_Sample(k_SeedSerial + 2, EMars_InputIntents_Hold::Released);
    }

    UFUNCTION()
    private void Step_AssertTwoRead(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Log(f"[InputIntentsTest] two presses that landed in one frame read as {_Presses}");
        Assert_Equals_Int(_Presses, 2, "two presses that landed in one frame are read as two");
        Assert_True(_Intents.Get_IsIntentActive(k_Intent) == false, "the row reads released once both were read");
    }

    UFUNCTION()
    private void Step_ThreeInOneSample(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Apply_Sample(k_SeedSerial + 5, EMars_InputIntents_Hold::Held);
    }

    UFUNCTION()
    private void Step_AssertThreeMoreAndHeld(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Log(f"[InputIntentsTest] a sample that made up three presses brought the reader to {_Presses}");
        Assert_Equals_Int(_Presses, 5, "a sample that makes up three presses is read as three more");
        Assert_True(_Intents.Get_IsIntentActive(k_Intent), "the last press is held");
    }

    UFUNCTION()
    private void Step_Release(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Apply_Sample(k_SeedSerial + 5, EMars_InputIntents_Hold::Released);
    }

    UFUNCTION()
    private void Step_AssertReleased(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Presses, 5, "a release raises no press");
        Assert_True(_Intents.Get_IsIntentActive(k_Intent) == false, "the hold ended with the release");
    }
}
