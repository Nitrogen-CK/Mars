// Coherence of the running value across drains: every drain must start from the value the previous drain left, however
// close together the drains are. Three segments against Health(100), all hits 10:
//   A. three hits one per step with a one-frame wait between them      -> Remaining 90, 80, 70
//   B. two hits queued in one step, then one more after one frame        -> Remaining 60, 50, 40
//   C. one hit whose OnDamaged handler queues the next (the tightest
//      spacing a caller can produce: the follow-up drains on the very
//      next processor pass, or re-entrantly in the same one)              -> Remaining 30, 20
// A drain that read a stale value (the attribute's write not yet landed) would repeat a Remaining (90, 90, ...) and the
// final value would not reach the expected one. Each drain's frame number is logged so the run shows the real spacing.
class UMars_AutoTest_Health_HitsOnConsecutiveFramesAccumulate : UCk_AutoTest_Base
{
    private FCk_Handle_Health _Health;

    private TArray<float32> _DamagedApplied;
    private TArray<float32> _DamagedRemaining;
    private TArray<int64> _DamagedFrames;

    // Segment C: OnDamaged queues one follow-up hit while this is set.
    private bool _ChainNextHit = false;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Entity = utils_entity_lifetime::Request_CreateEntity(InHandle);
        _Health = utils_health::Add(Entity, FMars_Health_Spec(100.0f));
        _Health.BindTo_OnDamaged(FMars_Delegate_Health_OnDamaged(this, n"OnDamaged"));

        Add_Step("A: hit 10", n"Step_Hit");
        Add_Step_WaitFrames("A: one frame", 1);
        Add_Step("A: hit 10", n"Step_Hit");
        Add_Step_WaitFrames("A: one frame", 1);
        Add_Step("A: hit 10", n"Step_Hit");
        Add_Step_WaitUntil("A: Health reads 70", n"Check_At70", 0, 2.0f);
        Add_Step("A: Remaining 90, 80, 70; B: two hits of 10 in one step", n"Step_AssertAAndHitTwice");
        Add_Step_WaitFrames("B: one frame", 1);
        Add_Step("B: hit 10", n"Step_Hit");
        Add_Step_WaitUntil("B: Health reads 40", n"Check_At40", 0, 2.0f);
        Add_Step("B: Remaining 60, 50, 40; C: a hit whose OnDamaged queues the next", n"Step_AssertBAndChain");
        Add_Step_WaitUntil("C: Health reads 20", n"Check_At20", 0, 2.0f);
        Add_Step("C: Remaining 30, 20", n"Step_AssertC");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void OnDamaged(FCk_Handle_Health InHealth, FMars_DamageEvent InEvent, float32 InApplied, float32 InRemaining)
    {
        _DamagedApplied.Add(InApplied);
        _DamagedRemaining.Add(InRemaining);
        _DamagedFrames.Add(utils_time::Get_FrameNumber());
        Log(f"[Mars_AutoTest_Health_HitsOnConsecutiveFramesAccumulate] OnDamaged #{_DamagedRemaining.Num()} frame [{utils_time::Get_FrameNumber()}] applied [{InApplied}] remaining [{InRemaining}]");

        if (_ChainNextHit == false)
        { return; }

        _ChainNextHit = false;
        _Health.Request_ApplyDamage(Make_Hit());
    }

    private FMars_Request_Health_ApplyDamage Make_Hit()
    {
        return FMars_Request_Health_ApplyDamage(FMars_DamageEvent(10.0f, GameplayTags::DamageType_Mars_Blunt));
    }

    private void Assert_Sequence(int32 InFirst, const TArray<float32>& InExpectedRemaining, const FString& InSegment)
    {
        Assert_Equals_Int(_DamagedRemaining.Num(), InFirst + InExpectedRemaining.Num(), f"{InSegment}: OnDamaged fired once per hit");
        if (_DamagedRemaining.Num() != InFirst + InExpectedRemaining.Num())
        { return; }

        for (int32 Index = 0; Index < InExpectedRemaining.Num(); ++Index)
        {
            const auto Slot = InFirst + Index;
            Assert_Equals_Float(_DamagedApplied[Slot], 10.0f, 0.001f, f"{InSegment}: hit [{Index}] applied 10");
            Assert_Equals_Float(_DamagedRemaining[Slot], InExpectedRemaining[Index], 0.001f,
                f"{InSegment}: hit [{Index}] left {InExpectedRemaining[Index]} (frame {_DamagedFrames[Slot]})");
        }
    }

    UFUNCTION()
    private void Step_Hit(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Valid(_Health, "utils_health::Add composed the Health");
        _Health.Request_ApplyDamage(Make_Hit());
    }

    UFUNCTION()
    private void Check_At70(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Math::IsNearlyEqual(_Health.Get_Current(), 70.0f, 0.001f));
    }

    UFUNCTION()
    private void Step_AssertAAndHitTwice(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Expected = TArray<float32>();
        Expected.Add(90.0f);
        Expected.Add(80.0f);
        Expected.Add(70.0f);
        Assert_Sequence(0, Expected, "A");

        _Health.Request_ApplyDamage(Make_Hit());
        _Health.Request_ApplyDamage(Make_Hit());
    }

    UFUNCTION()
    private void Check_At40(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Math::IsNearlyEqual(_Health.Get_Current(), 40.0f, 0.001f));
    }

    UFUNCTION()
    private void Step_AssertBAndChain(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Expected = TArray<float32>();
        Expected.Add(60.0f);
        Expected.Add(50.0f);
        Expected.Add(40.0f);
        Assert_Sequence(3, Expected, "B");

        _ChainNextHit = true;
        _Health.Request_ApplyDamage(Make_Hit());
    }

    UFUNCTION()
    private void Check_At20(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_DamagedRemaining.Num() >= 8 && Math::IsNearlyEqual(_Health.Get_Current(), 20.0f, 0.001f));
    }

    UFUNCTION()
    private void Step_AssertC(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Expected = TArray<float32>();
        Expected.Add(30.0f);
        Expected.Add(20.0f);
        Assert_Sequence(6, Expected, "C");
        Assert_False(_Health.Get_IsDepleted(), "20 of 100 is not depleted");
    }
}
