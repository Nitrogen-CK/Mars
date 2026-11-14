// The server's born rat watches, turns home and enters its den in its spawn frame, then hides there (its den does not
// know it and refuses it, and its raid holds no record of it, so nothing retires it). The client's copy is born into
// the den entry: its ledger's first application reads DenEnter and is taken once as it stands, announced as one change
// from Emerge in that frame, its fade already at its end and never shown; the watch and the turn home are never seen.
// The hide then arrives as the one change after it.
// Surface: Ck.PantryRat.Net.AS_PantryRat_ACopyBornIntoADenEntryShowsItAsItStands
class UCk_AutoTest_Net_PantryRat_ACopyBornIntoADenEntryShowsItAsItStands : UMars_AutoTestRig_NetPantryRat
{
    default _TimeoutSeconds = 28.0f;

    private const FVector k_Base = FVector(682000.0, 0.0, 5000.0);
    private const FString k_Row = "ACopyBornIntoADenEntryShowsItAsItStands";
    private const float32 k_NeverShownFade = 0.0001f;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_PantryRow(k_Base);

        if (Get_IsServer() == false)
        {
            WaitUntil(n"Is_RowRatFound", n"OnClientFound", k_SlowPolls);
            return;
        }

        Begin_ServerBornCourt(Make_RowSpec(), n"OnServerCourt");
    }

    UFUNCTION()
    private void OnServerCourt(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        auto BornThrough = TArray<EMars_PantryRat_Phase>();
        BornThrough.Add(EMars_PantryRat_Phase::Observe);
        BornThrough.Add(EMars_PantryRat_Phase::ReturnEmpty);
        BornThrough.Add(EMars_PantryRat_Phase::DenEnter);
        Spawn_ServerBornRat(BornThrough, utils_pantry_raid::Make_RatTuning(Make_RowSpec()));
        WaitUntil(n"Is_RowRatFound", n"OnServerFound", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Wait_RowRatUntil(Make_RatUntil(EMars_NetRatTest_UntilKind::ReadsPhase, EMars_PantryRat_Phase::DormantInDen), n"OnServerHidden");
    }

    UFUNCTION()
    private void OnServerHidden(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Wait_RowSampling(k_ComposeSeconds, n"OnServerSettled");
    }

    UFUNCTION()
    private void OnServerSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        if (Get_IsRowRatGone())
        {
            Log_RatRow(k_Row, "");
            FinishFailure("the server's rat was gone before it asserted");
            return;
        }

        Assert_True(_RowRat.Get_Phase() == EMars_PantryRat_Phase::DormantInDen, "the server's rat sits in its den");
        Assert_True(_RowRat.Get_IsHidden(), "the server's rat is hidden");
        Assert_True(_RowRat.Get_FadeAlpha() == 1.0f, f"the server's hidden rat reads fade 1 (reads {_RowRat.Get_FadeAlpha()})");
        Assert_True(Get_RowRatLedger().Phase == EMars_PantryRat_Phase::DormantInDen, "the server's ledger reads DormantInDen");
        Assert_Equals_Int(_RowRat.Get_PhaseChanges(), 4, "the server's rat changed phase four times");
        Hold_RatServerRow(k_Row, "");
    }

    UFUNCTION()
    private void OnClientFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Wait_RowRatUntil(Make_RatUntil(EMars_NetRatTest_UntilKind::ReadsPhase, EMars_PantryRat_Phase::DormantInDen), n"OnClientHidden");
    }

    UFUNCTION()
    private void OnClientHidden(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Wait_RowSampling(k_SettleSeconds, n"OnClientSettled");
    }

    UFUNCTION()
    private void OnClientSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Path = Get_IsBornPath() ? "born" : "arrived";
        if (Get_IsRowRatGone())
        {
            Log_RatRow(k_Row, f"path={Path}");
            FinishFailure("the client's rat was gone before it asserted");
            return;
        }

        const auto FirstApplication = _RatApplications.Num() > 0 ? _RatApplications[0] : FMars_NetRatTest_Application();
        Assert_True(Get_RowRatInitialState() == EMars_Net_InitialState::Taken, "the client's rat took the state it was born into");
        Assert_True(_RatApplications.Num() > 0 && FirstApplication.Phase == EMars_PantryRat_Phase::DenEnter,
            "the client's ledger's first application reads DenEnter");
        Assert_Equals_Int(_RatChanges.Num(), 2, "the client's rat recorded two changes");
        Assert_True(_RatChanges.Num() > 0 && _RatChanges[0].From == EMars_PantryRat_Phase::Emerge
            && _RatChanges[0].To == EMars_PantryRat_Phase::DenEnter && _RatChanges[0].Frame == FirstApplication.Frame,
            "the client's first change is Emerge to DenEnter, in the frame of the ledger's first application");
        Assert_True(_RatChanges.Num() > 1 && _RatChanges[1].From == EMars_PantryRat_Phase::DenEnter
            && _RatChanges[1].To == EMars_PantryRat_Phase::DormantInDen, "the client's second change is DenEnter to DormantInDen");
        Assert_False(Get_IsRatRecorded(EMars_PantryRat_Phase::Observe), "the client never saw its rat watch");
        Assert_False(Get_IsRatRecorded(EMars_PantryRat_Phase::ReturnEmpty), "the client never saw its rat turn home");
        Assert_True(_RatDenEnterHighestFade.IsSet() && _RatDenEnterHighestFade.GetValue() <= k_NeverShownFade,
            "the client's rat never read a fade above 0.0001 while it entered its den");
        Assert_False(_RatHiddenInDenEnter, "the client's rat was not hidden while it entered its den");
        Assert_True(_RowRat.Get_IsHidden(), "the client's rat is hidden");
        Assert_True(_RowRat.Get_FadeAlpha() == 1.0f, f"the client's hidden rat reads fade 1 (reads {_RowRat.Get_FadeAlpha()})");
        Assert_True(Get_RowRatLedger().Phase == EMars_PantryRat_Phase::DormantInDen, "the client's ledger reads DormantInDen");
        Finish_RatRow(k_Row, f"path={Path}");
    }

    // born: the first application carried the den entry and was taken as it stood (one announce in its frame, the fade
    // never shown); arrived: the copy played some of it as an event.
    private bool Get_IsBornPath() const
    {
        if (_RatApplications.Num() == 0 || _RatChanges.Num() == 0)
        { return false; }

        return _RatApplications[0].Phase == EMars_PantryRat_Phase::DenEnter && _RatChanges[0].From == EMars_PantryRat_Phase::Emerge
            && _RatChanges[0].To == EMars_PantryRat_Phase::DenEnter && _RatChanges[0].Frame == _RatApplications[0].Frame
            && _RatDenEnterHighestFade.IsSet() && _RatDenEnterHighestFade.GetValue() <= k_NeverShownFade;
    }
}
