// A harness fixture: the fig vine whose authority, as it composes, asks one Knock release, so its one fig drops in the
// spawn frame and its regrow is armed. A copy is born into an exhausted vine that released once.
class UMars_TESTONLY_NetFigVine_BornReleased_EntityScript : UMars_Forage_FigVine_EntityScript
{
    UFUNCTION(BlueprintOverride)
    ECk_EntityScript_ConstructionFlow DoConstruct(FCk_Handle& InHandle)
    {
        const auto Flow = Super::DoConstruct(InHandle);
        if (utils_net::Get_HasAuthority(InHandle) == false)
        { return Flow; }

        if (ck::EnsureIfNot(ck::IsValid(_Forage), f"[ForageNetTest] [{InHandle.ToString()}] the born vine composed no Forage"))
        { return Flow; }

        _Forage.Request_Release(FMars_Request_Forage_Release(EMars_Forage_ReleaseReason::Knock));
        return Flow;
    }
}

// The server's vine is born released and exhausted (the fixture above): the client's copy takes the empty vine as it
// stands, announcing the exhaustion once and raising no release. The regrow, then a later Knock release and its
// exhaustion, reach it as they arrive: one release, with the server's reason.
// Surface: Ck.Forage.Net.AS_Forage_ACopyBornExhaustedRaisesNoPastRelease
class UCk_AutoTest_Net_Forage_ACopyBornExhaustedRaisesNoPastRelease : UMars_AutoTestRig_NetForage
{
    default _TimeoutSeconds = 25.0f;

    private const FVector k_Base = FVector(75000.0, 0.0, 5000.0);
    private const float32 k_RegrowSeconds = 3.0f;
    private const float32 k_BvClientSettleSeconds = 1.0f;

    // Client: the find, each recorded notify of the ledger and each exhaustion, with its frame.
    private int32 _BvFoundFrame = -1;
    private EMars_Net_InitialState _BvInitialAtFind = EMars_Net_InitialState::Awaited;
    private TArray<int32> _BvNotifyFrames;
    private TArray<FMars_Fragment_Forage> _BvNotifies;
    private TArray<int32> _BvExhaustFrames;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_Rig(k_Base);

        if (Get_IsServer() == false)
        {
            WaitUntil(n"Is_BornVineFound", n"OnClientFound", k_SlowPolls);
            return;
        }

        WaitUntil(n"Is_ReplicatedSpawnOwnerPublished", n"OnServerOwnerPublished", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_BornVineFound(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        if (Get_IsSourceFound(n"TAG_MarsForageVine") == false)
        {
            Result.Set(false);
            return;
        }

        if (_BvFoundFrame < 0 && Get_IsServer() == false)
        { Begin_BornVineRecord(); }

        Result.Set(true);
    }

    private void Begin_BornVineRecord()
    {
        _BvFoundFrame = int32(utils_time::Get_FrameCounter());
        _BvInitialAtFind = Get_BvInitialState();
        _Source.BindTo_OnRepNotify(FMars_Fragment_Forage, FCk_DynamicFragment_OnRepNotify(this, n"OnBornVineNotify"));
        _Forage.BindTo_OnExhausted(FMars_Delegate_Forage_OnExhausted(this, n"OnBornVineExhausted"));
    }

    //------------------------------------------------------------------------------------------------------------------
    // Server
    //------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void OnServerOwnerPublished(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        auto Params = UMars_Forage_FigVine_EntityScript::Params();
        Params.SpawnTransform = FTransform(FRotator::ZeroRotator, _Base);
        Params.RegrowSeconds = k_RegrowSeconds;
        Params.WithVisuals = false;
        utils_entity_script::Request_SpawnEntity(utils_mars_net::Get_ReplicatedSpawnOwner(Get_SubjectEntity()),
            UMars_TESTONLY_NetFigVine_BornReleased_EntityScript, Params);
        WaitUntil(n"Is_BornVineFound", n"OnServerFound", k_SlowPolls);
    }

    // The server finds its vine before the spawn frame's drain has run: it reads the born state a beat later.
    UFUNCTION()
    private void OnServerFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_SettleSeconds, n"OnServerBornSettled");
    }

    UFUNCTION()
    private void OnServerBornSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Ledger = _Forage.Get_Fragment(FMars_Fragment_Forage);
        const auto Figs = Count_WorldItemsNear(mars_items::Fig());
        const auto Line = f"[ForageNetTest] ACopyBornExhaustedRaisesNoPastRelease server: born charges={Ledger.ChargesLeft} released={Ledger.ReleasedCount} reason={Ledger.LastReason :n} figs={Figs} regrowPending={_Forage.Get_IsRegrowPending()} ensures={Get_NewEnsures()}";
        Log(Line);
        Assert_True(Ledger.ChargesLeft == 0 && Ledger.ReleasedCount == 1, f"the server's vine was born released and exhausted ({Line})");
        WaitUntil(n"Is_ServerRegrown", n"OnServerRegrown", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerRegrown(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_Forage.Get_ChargesLeft() >= 1);
    }

    UFUNCTION()
    private void OnServerRegrown(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_SettleSeconds, n"OnServerReadyToRelease");
    }

    UFUNCTION()
    private void OnServerReadyToRelease(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _Forage.Request_Release(FMars_Request_Forage_Release(EMars_Forage_ReleaseReason::Knock));
        WaitUntil(n"Is_ReleasedTwice", n"OnServerReleasedTwice", k_SlowPolls);
    }

    // This machine's ledger counts the later release too; the server tracks the figs it counts.
    UFUNCTION()
    private void Is_ReleasedTwice(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        if (ck::Is_NOT_Valid(_Forage) || utils_entity_lifetime::Get_IsPendingDestroy(_Forage, ECk_EntityLifetime_DestructionPhase::BeginDestroy))
        {
            Result.Set(false);
            return;
        }

        Count_WorldItemsNear(mars_items::Fig());
        Result.Set(_Forage.Get_ReleasedCount() >= 2);
    }

    UFUNCTION()
    private void OnServerReleasedTwice(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_BvClientSettleSeconds, n"OnServerSettled");
    }

    UFUNCTION()
    private void OnServerSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_Equals_Int(_Forage.Get_ReleasedCount(), 2, "the server's vine released twice");
        Assert_Equals_Int(_Forage.Get_ChargesLeft(), 0, "the server's vine is exhausted again");
        Assert_Equals_Int(Count_WorldItemsNear(mars_items::Fig()), 2, "two figs lie under the server's vine");
        Assert_Equals_Int(Get_NewEnsures(), 0, "no ensure on the server");
        WaitSeconds(k_ServerHoldSeconds, n"OnServerHeld");
    }

    //------------------------------------------------------------------------------------------------------------------
    // Client
    //------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void OnClientFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitUntil(n"Is_ReleasedTwice", n"OnClientReleasedTwice", k_SlowPolls);
    }

    UFUNCTION()
    private void OnClientReleasedTwice(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_BvClientSettleSeconds, n"OnClientSettled");
    }

    UFUNCTION()
    private void OnClientSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Ledger = _Forage.Get_Fragment(FMars_Fragment_Forage);
        const auto First = _BvNotifies.Num() > 0 ? _BvNotifies[0] : FMars_Fragment_Forage();
        const auto FirstFrame = _BvNotifyFrames.Num() > 0 ? _BvNotifyFrames[0] : -1;
        const auto Figs = Count_WorldItemsNear(mars_items::Fig());
        const auto Line = Describe_BornVine();
        const auto LogLine = f"[ForageNetTest] ACopyBornExhaustedRaisesNoPastRelease client: charges={Ledger.ChargesLeft} released={Ledger.ReleasedCount} signals={_Released} order={_Order} figs={Figs} ensures={Get_NewEnsures()} {Line}";
        Log(LogLine);

        Assert_True(Get_BvInitialState() == EMars_Net_InitialState::Taken, f"the client's copy took the state it was born into ({Line})");
        Assert_True(_BvInitialAtFind == EMars_Net_InitialState::Awaited, f"the client found its copy before its ledger's first application ({Line})");
        Assert_True(_BvNotifyFrames.Num() > 0, f"the client recorded a rep-notify of its copy's ledger ({Line})");
        Assert_True(First.ChargesLeft == 0 && First.ReleasedCount == 1, f"the first notify carried the release and the exhaustion it was born into ({Line})");
        Assert_Equals_String(_Order, "EPRE", f"the client announced the born exhaustion, the regrow, the later release and its exhaustion ({Line})");
        Assert_True(_BvExhaustFrames.Num() > 0 && _BvExhaustFrames[0] == FirstFrame, f"the born exhaustion was announced in the first notify's frame ({Line})");
        Assert_Equals_Int(_Released, Ledger.ReleasedCount - First.ReleasedCount, f"the client released only after its first notify ({Line})");
        Assert_True(_LastReason.IsSet() && _LastReason.GetValue() == EMars_Forage_ReleaseReason::Knock, f"the client's release carries the server's reason ({Line})");
        Assert_Equals_Int(Figs, 2, f"two figs lie under the client's vine ({Line})");
        Assert_Equals_Int(Get_NewEnsures(), 0, "no ensure on the client");
        FinishSuccess();
    }

    // This machine's copy's level now; Awaited while there is none.
    private EMars_Net_InitialState Get_BvInitialState() const
    {
        if (ck::Is_NOT_Valid(_Forage) || _Forage.Has_Fragment(FMars_Fragment_Forage_Local) == false)
        { return EMars_Net_InitialState::Awaited; }

        return _Forage.Get_Fragment(FMars_Fragment_Forage_Local).InitialState;
    }

    private FString Describe_BornVine()
    {
        auto Notifies = "";
        for (int32 Index = 0; Index < _BvNotifyFrames.Num(); ++Index)
        { Notifies += f"{_BvNotifyFrames[Index]}:{_BvNotifies[Index].ChargesLeft}/{_BvNotifies[Index].ReleasedCount} "; }

        auto Exhausts = "";
        for (const auto Frame : _BvExhaustFrames)
        { Exhausts += f"E@{Frame} "; }

        return f"found@{_BvFoundFrame} initialAtFind={_BvInitialAtFind :n} initial={Get_BvInitialState() :n} notifies=[{Notifies}] exhausts=[{Exhausts}]";
    }

    // A notify can land on a vine already ending.
    UFUNCTION()
    private void OnBornVineNotify(FCk_Handle InHandle, FCk_DynamicFragment_RepNotifyInfo InInfo)
    {
        if (ck::Is_NOT_Valid(InHandle) || InHandle.Has_Fragment(FMars_Fragment_Forage) == false)
        { return; }

        _BvNotifyFrames.Add(int32(utils_time::Get_FrameCounter()));
        _BvNotifies.Add(InHandle.Get_Fragment(FMars_Fragment_Forage));
    }

    UFUNCTION()
    private void OnBornVineExhausted(FCk_Handle_Forage InForage)
    {
        _BvExhaustFrames.Add(int32(utils_time::Get_FrameCounter()));
    }
}
