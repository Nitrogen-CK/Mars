// The server sources its feed (step 1) and watches 6 s. At step 1 the client reads its ledger, then asks its own copy for
// a press, a cancel, a reset, no source and an Accepted answer for a made-up piece: 1.5 s later its ledger is unchanged,
// it raised nothing since, its copy holds no request, both its pieces ride its platter at the server's rides and none
// hangs from its hand node, its hand is at rest and its platter raised no OnUnloaded. At the end the server's feed is idle
// in the same attempt with none admitted, its ledger's three serials are 0, its platter holds both pieces frozen, and it
// raised nothing but the first stock edge.
// Surface: Ck.CookingFeed.Net.AS_CookingFeed_TheClientWroteNothing
class UCk_AutoTest_Net_CookingFeed_TheClientWroteNothing : UMars_AutoTestRig_NetCookingFeed
{
    default _TimeoutSeconds = 25.0f;

    private const float64 k_X = 278000.0;
    private const float32 k_ServerWatchSeconds = 6.0f;
    private const float32 k_ClientWatchSeconds = 1.5f;

    private int32 _Generation = 0;
    // Client: what it read when it asked.
    private FMars_Fragment_CookingFeed_Net _LedgerBefore;
    private int32 _EventsBefore = 0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_FeedRig(InHandle, k_X);
        if (Get_IsServer() == false)
        { Await_FeedStep(1, n"OnClientStep1"); }
    }

    protected void On_ServerFeedFound() override
    {
        Source_AfterBind();
    }

    protected void On_ServerSourced() override
    {
        _Generation = _Feed.Get_Generation();
        Publish_FeedStep(Make_FeedStep(1));
        WaitSeconds(k_ServerWatchSeconds, n"OnServerWatched");
    }

    UFUNCTION()
    private void OnServerWatched(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Ledger = _Feed.Get_Ledger();
        Assert_True(_Feed.Get_Phase() == EMars_CookingFeed_Phase::Idle, "the server's feed is idle");
        Assert_Equals_Int(_Feed.Get_Generation(), _Generation, "the server's feed is in the same attempt");
        Assert_Equals_Int(_Feed.Get_Admitted(), 0, "the server's feed admitted none");
        Assert_True(Ledger.PhaseSerial == 0 && Ledger.RefusalSerial == 0 && Ledger.LetGoSerial == 0,
            f"the server's ledger's serials are 0 ({Describe_Ledger(Ledger)})");
        Assert_Equals_Int(_Platter.Get_HeldCount(), 2, "the server's platter holds both pieces frozen");
        Assert_True(_Events.Num() == 1 && Get_EventCount(EMars_TESTONLY_NetFeedEvent::StockChanged) == 1,
            f"the server raised nothing but the first stock edge ({Describe_Record()})");
        End_FeedServer(f"{Describe_Record()} ledger [{Describe_Ledger(Ledger)}] {Describe_Counts()}");
    }

    UFUNCTION()
    private void OnClientStep1(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _LedgerBefore = _Feed.Get_Ledger();
        _EventsBefore = _Events.Num();

        _Feed.Request_BeginTransfer(FMars_Request_CookingFeed_BeginTransfer());
        _Feed.Request_Cancel(FMars_Request_CookingFeed_Cancel());
        _Feed.Request_Reset(FMars_Request_CookingFeed_Reset());
        _Feed.Request_SetSource(FMars_Request_CookingFeed_SetSource(FCk_Handle_Platter()));
        _Feed.Request_ResolveAdmission(FMars_Request_CookingFeed_ResolveAdmission(FMars_CookingFeed_PieceId(99, 99),
            EMars_CookingFeed_Admission::Accepted, "made up"));
        WaitSeconds(k_ClientWatchSeconds, n"OnClientWatched");
    }

    UFUNCTION()
    private void OnClientWatched(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Ledger = _Feed.Get_Ledger();
        const auto Fault = Get_PileFault();
        Assert_True(Get_IsLedgerEqual(Ledger, _LedgerBefore), f"the client's ledger is unchanged ({Describe_Ledger(Ledger)} was {Describe_Ledger(_LedgerBefore)})");
        Assert_Equals_Int(_Events.Num(), _EventsBefore, f"the client raised nothing since it asked ({Describe_Record()})");
        Assert_False(_Feed.Has_Fragment(FMars_Fragment_CookingFeed_Requests), "the client's copy holds no request");
        Assert_Equals_Int(Get_PlatterReport().Count, 2, "the server reported both rides");
        Assert_True(Fault.IsEmpty(), f"both the client's pieces ride its platter at the server's rides ({Fault})");
        Assert_True(Get_IsHandAtRest(), f"the client's hand is at rest ({Describe_HandRest()})");
        Assert_Equals_Int(_Unloaded, 0, "the client's platter raised no OnUnloaded");
        End_FeedClient(f"{Describe_Record()} pileFault=[{Fault}] ledger [{Describe_Ledger(Ledger)}] {Describe_Signals()}");
    }

    private bool Get_IsLedgerEqual(FMars_Fragment_CookingFeed_Net InA, FMars_Fragment_CookingFeed_Net InB)
    {
        return InA.PhaseSerial == InB.PhaseSerial && InA.Phase == InB.Phase && InA.Hold == InB.Hold && InA.Piece == InB.Piece
            && InA.Aim == InB.Aim && InA.GraspPoint.Equals(InB.GraspPoint) && InA.Sourcing == InB.Sourcing && InA.Source == InB.Source
            && InA.Available == InB.Available && InA.Admitted == InB.Admitted && InA.Pile == InB.Pile
            && InA.RefusalSerial == InB.RefusalSerial && InA.LastRefusal == InB.LastRefusal && InA.LetGoSerial == InB.LetGoSerial;
    }
}
