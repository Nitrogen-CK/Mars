// With a fixed 0.2 s blink interval and no double blinks, the eyes complete three blinks, close during each one, are
// fully open again between them, and complete them one interval plus one blink (close + hold + open) apart. Isolated Z
// band: -65000.
class UMars_AutoTest_Eyes_BlinkCountsAtFixedInterval : UCk_AutoTest_Base
{
    private FCk_Handle_Eyes _Eyes;
    private FMars_Eyes_Spec _Spec;

    // Frame quantisation and hitches between the completions the polls observe.
    private float _GapToleranceSeconds = 0.15;

    // Sampled every poll while waiting: the highest Blink seen, per completed-blink count whether the eyes were seen
    // fully open before the next blink completed, and the time each count was first seen.
    private float32 _MaxBlinkSeen = 0.0f;
    private TArray<bool> _SeenOpenAtCount;
    private TMap<int32, float> _FirstSeenAtCount;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto FaceEntity = utils_entity_lifetime::Request_CreateEntity(InHandle);
        auto FaceNode = utils_transform::Add(FaceEntity, FTransform(FRotator::ZeroRotator, FVector(0.0, 0.0, -65000.0)),
            ECk_Replication::DoesNotReplicate);

        _Spec = FMars_Eyes_Spec();
        auto Blink = FMars_Eyes_BlinkSpec();
        Blink.IntervalMinSeconds = 0.2f;
        Blink.IntervalMaxSeconds = 0.2f;
        Blink.DoubleBlinkChance = 0.0f;
        _Spec.Blink = Blink;
        _Eyes = utils_eyes::Add(FaceNode, _Spec);

        for (int32 Count = 0; Count <= 3; ++Count)
        { _SeenOpenAtCount.Add(false); }

        Add_Step("the eyes have a presentation", n"Step_AssertPresentation");
        Add_Step_WaitUntil("three blinks completed", n"Check_ThreeBlinks");
        Add_Step("each blink closed the eyes and they were open again between blinks", n"Step_AssertBlinkShape");
        Add_Step("consecutive blinks completed one interval plus one blink apart", n"Step_AssertBlinkSpacing");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_AssertPresentation(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Valid(_Eyes, "Add with a valid spec returns a valid handle");
        if (_Eyes.Get_HasPresentation() == false)
        { FinishFailure("the eyes have no presentation in this world - Get_CanExecuteCosmeticEvents was false"); }
    }

    UFUNCTION()
    private void Check_ThreeBlinks(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto Count = _Eyes.Get_BlinkCount();
        const auto Blink = _Eyes.Get_Blink();

        _MaxBlinkSeen = Math::Max(_MaxBlinkSeen, Blink);
        if (Count >= 0 && Count < _SeenOpenAtCount.Num())
        {
            if (Blink <= 0.0f)
            { _SeenOpenAtCount[Count] = true; }

            if (_FirstSeenAtCount.Contains(Count) == false)
            { _FirstSeenAtCount.Add(Count, System::GetGameTimeInSeconds()); }
        }

        auto Res = OutResult;
        Res.Set(Count >= 3);
    }

    UFUNCTION()
    private void Step_AssertBlinkShape(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_MaxBlinkSeen > 0.5f, f"the eyes closed during the blinks (highest Blink seen [{_MaxBlinkSeen}])");
        Assert_True(_SeenOpenAtCount[1], "the eyes were fully open between the first and second blink");
        Assert_True(_SeenOpenAtCount[2], "the eyes were fully open between the second and third blink");
    }

    UFUNCTION()
    private void Step_AssertBlinkSpacing(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto& BlinkSpec = _Spec.Blink.GetValue();
        const auto Expected = float(BlinkSpec.IntervalMinSeconds
            + BlinkSpec.CloseSeconds + BlinkSpec.HoldSeconds + BlinkSpec.OpenSeconds);
        for (int32 Count = 2; Count <= 3; ++Count)
        {
            float Previous = 0.0;
            float Current = 0.0;
            if (_FirstSeenAtCount.Find(Count - 1, Previous) == false || _FirstSeenAtCount.Find(Count, Current) == false)
            {
                Assert_True(false, f"blink {Count - 1} and blink {Count} were both seen completing");
                continue;
            }

            const auto Gap = Current - Previous;
            Assert_True(Gap >= Expected - _GapToleranceSeconds,
                f"blink {Count} completed [{Gap :.3}] s after blink {Count - 1} - no sooner than [{Expected :.3}] s minus [{_GapToleranceSeconds}]");
            Assert_True(Gap <= Expected + _GapToleranceSeconds,
                f"blink {Count} completed [{Gap :.3}] s after blink {Count - 1} - no later than [{Expected :.3}] s plus [{_GapToleranceSeconds}]");
        }
    }
}
