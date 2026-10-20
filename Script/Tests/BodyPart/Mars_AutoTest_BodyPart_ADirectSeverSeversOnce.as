// A direct Sever request (no Health depletion) severs a DetachLeg part once: two Sever requests on leg 0 in one frame
// (7 Sever, then 9 Crush) sever it once with the first cause, the leg detaches and the part's Health is untouched (30).
// A third Sever, drained beside a 10 Sever ledger hit whose spill moves the body 120 -> 115 (the proof the part's drain
// ran), changes nothing: OnSevered stays at one.
class UMars_AutoTest_BodyPart_ADirectSeverSeversOnce : UMars_AutoTestRig_Crawler
{
    default _TimeoutSeconds = 15.0f;
    default _Origin = FVector(130000.0, 100000.0, 600.0);

    private FCk_Handle_BodyPart _Part;
    private FCk_Handle_ProceduralLeg _Leg;

    private int32 _SeveredCount = 0;
    private FMars_DamageEvent _SeveredCause;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        SpawnFloorAndCrawler(InHandle, Make_CrawlerSpec(FVector(400.0, 400.0, 200.0)));

        Add_Step_WaitUntil("the crawler is composed, its gait Ready and its 4 parts registered", n"Check_Ready", k_SlowPolls, 0);
        Add_Step("bind leg 0's OnSevered; request two severs in one frame", n"Step_SeverTwice");
        Add_Step_WaitUntil("leg 0 is severed and detached", n"Check_Severed", 0, 0);
        Add_Step("severed once with the first cause; request a third sever beside a ledger hit", n"Step_AssertSeveredAndSeverAgain");
        Add_Step_WaitUntil("the body reads 115", n"Check_BodyAt115", 0, 0);
        Add_Step("the third sever changed nothing", n"Step_AssertSeveredOnce");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void OnSevered(FCk_Handle_BodyPart InPart, FMars_DamageEvent InCause, TArray<FCk_Handle_Transform> InReleased)
    {
        ++_SeveredCount;
        _SeveredCause = InCause;
    }

    UFUNCTION()
    private void Step_SeverTwice(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Part = _Crawler.Get_LegParts()[0];
        _Leg = _Crawler.Get_Legs()[0];
        _Part.BindTo_OnSevered(FMars_Delegate_BodyPart_OnSevered(this, n"OnSevered"));

        Assert_True(_Part.Get_State() == EMars_BodyPart_State::Attached, "leg 0 starts Attached");
        Assert_Equals_Float(_Crawler.Get_Monster().Get_BodyHealth().Get_Current(), 120.0f, 0.001f, "the body starts at 120");

        _Part.Request_Sever(FMars_Request_BodyPart_Sever(FMars_DamageEvent(7.0f, GameplayTags::DamageType_Mars_Sever)));
        _Part.Request_Sever(FMars_Request_BodyPart_Sever(FMars_DamageEvent(9.0f, GameplayTags::DamageType_Mars_Crush)));
    }

    UFUNCTION()
    private void Check_Severed(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_SeveredCount > 0 && _Part.Get_State() == EMars_BodyPart_State::Severed &&
            utils_procedural_leg::Get_Status(_Leg) == ECk_ProceduralLeg_Status::Detached);
    }

    UFUNCTION()
    private void Step_AssertSeveredAndSeverAgain(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_SeveredCount, 1, "OnSevered fired once for two same-frame severs");
        Assert_Equals_Float(_SeveredCause.Amount, 7.0f, 0.001f, "OnSevered carries the first request's cause");
        Assert_True(_SeveredCause.DamageType == GameplayTags::DamageType_Mars_Sever, "OnSevered carries the first request's damage type");
        Assert_Equals_Float(_Part.Get_Health().Get_Current(), 30.0f, 0.001f, "a direct sever leaves the part's Health untouched");
        Assert_False(_Part.Get_Health().Get_IsDepleted(), "the part's Health is not depleted");
        Assert_False(_Part.Get_Zone().Get_IsEnabled(), "the sever disabled the part's zone");

        _Part.Request_Sever(FMars_Request_BodyPart_Sever(FMars_DamageEvent(11.0f, GameplayTags::DamageType_Mars_Sever)));
        _Part.Request_RecordHit(FMars_Request_BodyPart_RecordHit(FMars_DamageEvent(10.0f, GameplayTags::DamageType_Mars_Sever),
            FMars_HitZone_Reaction(GameplayTags::DamageType_Mars_Sever, 1.0f, EMars_HitZone_ConditionImpact::Damages)));
    }

    UFUNCTION()
    private void Check_BodyAt115(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Math::IsNearlyEqual(_Crawler.Get_Monster().Get_BodyHealth().Get_Current(), 115.0f, 0.001f));
    }

    UFUNCTION()
    private void Step_AssertSeveredOnce(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_SeveredCount, 1, "OnSevered still fired once");
        Assert_Equals_Float(_SeveredCause.Amount, 7.0f, 0.001f, "the cause is still the first request's");
        Assert_True(_Part.Get_State() == EMars_BodyPart_State::Severed, f"the part stays Severed (got {_Part.Get_State() :n})");
        Assert_Equals_Int(_Crawler.Get_Monster().Get_AttachedPartCount(), 3, "the monster counts 3 attached parts");
    }
}
