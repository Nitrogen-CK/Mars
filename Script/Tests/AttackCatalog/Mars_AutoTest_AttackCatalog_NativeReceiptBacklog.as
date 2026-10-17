// This owns a separate native Explicit stream. It does not pause or inject backlog into the game's resolver.
class UMars_AutoTest_AttackCatalog_NativeReceiptBacklog : UMars_AutoTestRig_CrawlerEndpointCatalog
{
    default _TimeoutSeconds = 90.0f;
    default _Origin = FVector(-760000.0, -180000.0, 600.0);
    private int32 _BufferedAccepted = 0;
    private int32 _DrainedAccepted = 0;
    private int64 _LastAccepted = 0;
    private bool _HistoricalPage = false;
    private bool _SawLatestPage = false;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        SpawnFloorAndCrawler(InHandle, Make_EndpointSpec());
        Add_CatalogSettleSteps();
        Add_Step("create a body-only native Explicit action on the actual player", n"Step_NativeStart");
        Add_Step_WaitUntil("at least seventeen unconsumed accepted records really accumulate", n"Check_Backlog", k_SlowPolls, 0);
        Add_Step("the first sixteen-record historical page cannot be today's latest pose", n"Step_FirstPage");
        Add_Step("cancel through the native public request", n"Step_NativeCancel");
        Add_Step_WaitUntil("chronological bounded reads save and acknowledge the terminal", n"Check_DrainTerminal", k_SlowPolls, 0);
        Add_Step_WaitUntil("terminal acknowledgement releases the action and stream", n"Check_StreamReleased", k_SlowPolls, 0);
        Add_Step("E05 native page mechanics plus production latest-page policy", n"Step_AssertBacklog");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_NativeStart(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Play = FCk_ProceduralAction_PlaySpec(TSoftObjectPtr<UCk_ProceduralAction_Data>(_CatalogJabSource));
        Play.Set_Delivery(ECk_ProceduralAction_Delivery::Explicit);
        auto Scope = InHandle;
        _Calibration.Action = utils_procedural_action::Create_FromClip(Scope, _Crawler.Get_ActionPlayer(), Play);
        Assert_True(ck::IsValid(_Calibration.Action), "native backlog action exists");
        _Calibration.Identity = _Calibration.Action.Get_Identity();
        // Native player's default RecordsPerInstance is64; no production fragment is changed to obtain this capacity.
    }

    UFUNCTION()
    private void Check_Backlog(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto Page = _Crawler.Get_ActionPlayer().Read_Receipts(_Calibration.Identity, 0, 64);
        if (Page.Get_Result() != ECk_ProceduralAction_ReadResult::Succeeded && Page.Get_Result() != ECk_ProceduralAction_ReadResult::Pending)
        { FinishFailure(f"native unconsumed stream failed {Page.Get_Result() :n}"); return; }
        _BufferedAccepted = 0;
        for (const auto& Record : Page.Get_Records())
        { if (Record.Get_Kind() == ECk_ProceduralAction_RecordKind::AcceptedPose) { ++_BufferedAccepted; } }
        auto Res = OutResult;
        Res.Set(_BufferedAccepted >= 17);
    }

    private bool Drain_Page(const FCk_ProceduralAction_ReadPage& InPage)
    {
        if (InPage.Get_Result() != ECk_ProceduralAction_ReadResult::Succeeded && InPage.Get_Result() != ECk_ProceduralAction_ReadResult::Pending)
        { FinishFailure(f"native drain failed {InPage.Get_Result() :n}"); return false; }
        for (const auto& Record : InPage.Get_Records())
        {
            Assert_True(Record.Get_StreamSequence() > _Calibration.Cursor && Record.Get_Identity().Get_Value() == _Calibration.Identity.Get_Value(),
                "explicit records are processed once, in action-local stream order");
            _Calibration.Cursor = Record.Get_StreamSequence();
            if (Record.Get_Kind() == ECk_ProceduralAction_RecordKind::AcceptedPose)
            {
                const auto Sample = Record.Get_Receipt().Get_Stamp().Get_SampleSequence();
                Assert_True(Sample > _LastAccepted && Record.Get_Receipt().Get_HasAcceptedPose(), "accepted samples drain in increasing native order");
                _LastAccepted = Sample;
                ++_DrainedAccepted;
            }
            if (Record.Get_Kind() == ECk_ProceduralAction_RecordKind::Terminal)
            { _Calibration.Result = Record.Get_Result(); _Calibration.TerminalSeen = true; }
        }
        if (InPage.Get_Records().Num() > 0)
        {
            auto Player = _Crawler.Get_ActionPlayer();
            Player.Request_ConsumeReceipts(FCk_Request_ProceduralActionPlayer_ConsumeReceipts(_Calibration.Identity, _Calibration.Cursor));
        }
        if (InPage.Get_HasMore() == false && utils_crawler::Get_LatestAcceptedIndex(InPage) >= 0) { _SawLatestPage = true; }
        return true;
    }

    UFUNCTION()
    private void Step_FirstPage(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Page = _Crawler.Get_ActionPlayer().Read_Receipts(_Calibration.Identity, _Calibration.Cursor, 16);
        _HistoricalPage = Page.Get_HasMore();
        Assert_True(_HistoricalPage && Page.Get_Records().Num() == 16,
            "the public native stream really contains more than one bounded page");
        Assert_Equals_Int(utils_crawler::Get_LatestAcceptedIndex(Page), -1, "historical HasMore page cannot be compared to current rendered geometry");
        Drain_Page(Page);
    }

    UFUNCTION()
    private void Step_NativeCancel(FCk_Handle InHandle, FInstancedStruct InPayload)
    { _Calibration.Action.Request_Cancel(FCk_Request_ProceduralAction_Cancel()); }

    UFUNCTION()
    private void Check_DrainTerminal(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        for (int32 PageIndex = 0; PageIndex < 4 && _Calibration.TerminalSeen == false; ++PageIndex)
        {
            const auto Page = _Crawler.Get_ActionPlayer().Read_Receipts(_Calibration.Identity, _Calibration.Cursor, 16);
            if (Drain_Page(Page) == false) { return; }
            if (Page.Get_HasMore() == false) { break; }
        }
        auto Res = OutResult;
        Res.Set(_Calibration.TerminalSeen);
    }

    UFUNCTION()
    private void Check_StreamReleased(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Retained = false;
        for (const auto& Identity : _Crawler.Get_ActionPlayer().Get_RetainedReceiptIdentities())
        { Retained = Retained || Identity.Get_Value() == _Calibration.Identity.Get_Value(); }
        auto Res = OutResult;
        Res.Set(_Calibration.TerminalSeen && ck::Is_NOT_Valid(_Calibration.Action) && Retained == false);
    }

    UFUNCTION()
    private void Step_AssertBacklog(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_BufferedAccepted >= 17 && _DrainedAccepted >= _BufferedAccepted && _HistoricalPage && _SawLatestPage,
            "all initially buffered accepted records drained through historical and true latest native pages");
        Assert_True(_Calibration.TerminalSeen && _Calibration.Result.Get_Outcome() != ECk_ProceduralAction_Outcome::None,
            "actual terminal outcome was saved before acknowledgement removed its stream");
        Assert_Equals_Int(_CatalogAdmissions.Num(), 0, "the calibration stream was not presented as a game attack");
        Log(f"[NativeReceiptBacklog] buffered {_BufferedAccepted}, drained {_DrainedAccepted}, cursor {_Calibration.Cursor}, terminal {_Calibration.Result.Get_Outcome() :n}/{_Calibration.Result.Get_Reason()}; native pages plus shared latest-page policy, not integrated game backlog injection");
    }
}
