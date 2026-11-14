// The server's court emerges one rat and then loses its pack (the pack, the Rind with it, is destroyed): with no
// target the rat turns home, enters its den, hides, is admitted and retired by its raid, so its den's slot 0 sits
// dormant again under the eyes and nothing was refused. The client's copy turns home and enters its den too, crouches
// solid and then fades on its own clock, never dies, and goes when the authority's does; its den copy's eyes stand for
// slot 0 again.
// Surface: Ck.PantryRat.Net.AS_PantryRat_ARatThatGoesHomeFadesAndGoesOnBothMachines
class UCk_AutoTest_Net_PantryRat_ARatThatGoesHomeFadesAndGoesOnBothMachines : UMars_AutoTestRig_NetPantryRat
{
    default _TimeoutSeconds = 28.0f;

    private const FVector k_Base = FVector(685000.0, 0.0, 5000.0);
    private const FString k_Row = "ARatThatGoesHomeFadesAndGoesOnBothMachines";
    private const float32 k_NoTargetReturnSeconds = 0.5f;
    private const float32 k_HomeSeconds = 15.0f;

    private int32 _PackDestroyedFrame = -1;

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

        auto Spec = Make_RowSpec();
        Spec.Population.MaxActiveRats = 1;
        Spec.Scent.NoTargetReturnSeconds = k_NoTargetReturnSeconds;
        Begin_ServerRatCourt(Spec, n"OnServerRatOut");
    }

    UFUNCTION()
    private void OnServerRatOut(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        utils_entity_lifetime::Request_DestroyEntity(_RowPackEntity);
        _PackDestroyedFrame = int32(utils_time::Get_FrameCounter());
        auto Until = Make_RatUntil(EMars_NetRatTest_UntilKind::GoneAndUnrecorded, EMars_PantryRat_Phase::Emerge);
        Until.MaxSeconds = TOptional<float32>(k_HomeSeconds);
        Wait_RowRatUntil(Until, n"OnServerRatHome");
    }

    UFUNCTION()
    private void OnServerRatHome(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Wait_RowSampling(k_ComposeSeconds, n"OnServerSettled");
    }

    UFUNCTION()
    private void OnServerSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Extra = f"packDestroyed={_PackDestroyedFrame} dormantAt={Get_FrameOf(EMars_PantryRat_Phase::DormantInDen)} ratEnd={_RatGoneFrame} {Describe_CourtFrames()}";
        if (Get_IsRowEnding(_RowDen))
        {
            Log_RatRow(k_Row, Extra);
            FinishFailure("the server's den was gone before it asserted");
            return;
        }

        auto Expected = TArray<EMars_PantryRat_Phase>();
        Expected.Add(EMars_PantryRat_Phase::ReturnEmpty);
        Expected.Add(EMars_PantryRat_Phase::DenEnter);
        Expected.Add(EMars_PantryRat_Phase::DormantInDen);
        Assert_True(Get_IsRatRecordedInOrder(Expected), "the server's rat turned home, entered its den and hid, in that order");
        Assert_True(Get_IsRowRatGone(), "the server's rat is gone");
        Assert_True(_RowDen.Get_SlotState(0) == EMars_RatDen_SlotState::Dormant, "the server's den slot 0 is Dormant");
        Assert_True(Get_IsRowEyeSlot(0), "the server's den eyes stand for slot 0");
        Assert_Equals_Int(_RowDen.Get_RefusedReturns(), 0, "the server's den refused no return");
        Assert_Equals_Int(Count_RatsHere(), 0, "no rat is left on the server");
        Hold_RatServerRow(k_Row, Extra);
    }

    UFUNCTION()
    private void OnClientFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Wait_RowRatUntil(Make_RatUntil(EMars_NetRatTest_UntilKind::Gone, EMars_PantryRat_Phase::Emerge), n"OnClientRatGone");
    }

    UFUNCTION()
    private void OnClientRatGone(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Wait_RowSampling(k_SettleSeconds, n"OnClientSettled");
    }

    UFUNCTION()
    private void OnClientSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Extra = f"dormantAt={Get_FrameOf(EMars_PantryRat_Phase::DormantInDen)} ratEnd={_RatGoneFrame}";
        Get_IsRowDenFound();
        if (Get_IsRowEnding(_RowDen))
        {
            Log_RatRow(k_Row, Extra);
            FinishFailure("the client's den copy was gone before it asserted");
            return;
        }

        auto Expected = TArray<EMars_PantryRat_Phase>();
        Expected.Add(EMars_PantryRat_Phase::ReturnEmpty);
        Expected.Add(EMars_PantryRat_Phase::DenEnter);
        Assert_True(Get_IsRatRecordedInOrder(Expected), "the client's rat turned home, then entered its den");
        Assert_True(_RatDenEnterSawFadedAfterSolid,
            "the client's rat read solid while it entered its den and then below one half (the crouch, then the fade)");
        Assert_Equals_Int(_RatDiedSignals, 0, "the client's rat never died");
        Assert_Equals_Int(Count_RatsHere(), 0, "no rat is left on the client");
        Assert_True(Get_IsRowEyeSlot(0), "the client's den copy's eyes stand for slot 0");
        Finish_RatRow(k_Row, Extra);
    }

    // The frame this machine recorded its rat changing into InPhase; -1 if it never did.
    private int32 Get_FrameOf(EMars_PantryRat_Phase InPhase) const
    {
        for (const auto& Change : _RatChanges)
        {
            if (Change.To == InPhase)
            { return Change.Frame; }
        }

        return -1;
    }
}
