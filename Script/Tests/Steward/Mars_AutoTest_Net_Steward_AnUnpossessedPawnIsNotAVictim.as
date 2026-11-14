// A pawn nobody possesses is not a victim: with the production pawn standing at the base uncontrolled, the channel
// rising powers the server's steward's sink and seizes nothing (the pawn's entity carries neither prey tag and no
// marker; no phase, no end, serial 0); the client's copy reads its sink Powered and stays Idle with nothing recorded.
// Nothing else in the harness world is prey either.
// Surface: Ck.Steward.Net.AS_Steward_AnUnpossessedPawnIsNotAVictim
class UCk_AutoTest_Net_Steward_AnUnpossessedPawnIsNotAVictim : UMars_AutoTestRig_NetSteward
{
    default _TimeoutSeconds = 28.0f;

    private const FVector k_RowBase = FVector(643000.0, 0.0, 5000.0);
    private const FString k_Row = "AnUnpossessedPawnIsNotAVictim";

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_StewardRow(k_RowBase, EMars_NetDevourTest_Victims::None);

        if (Get_IsServer())
        {
            Spawn_ServerPawn();
            WaitUntil(n"Is_ServerReadyForSteward", n"OnServerOwnerReady", k_SlowPolls);
            return;
        }

        WaitUntil(n"Is_StewardCopiesFound", n"OnClientFound", k_SlowPolls);
    }

    // Nothing recorded and nothing begun.
    private void Assert_NothingSeized(FString InMachine)
    {
        Assert_True(Get_IsDevourerIn(EMars_Devour_Phase::Idle), f"the {InMachine}'s steward is Idle");
        Assert_Equals_Int(Get_DevourLedger().Serial, 0, f"the {InMachine}'s ledger reads serial 0");
        Assert_Equals_Int(_DevourPhases.Num(), 0, f"the {InMachine} recorded no phase");
        Assert_Equals_Int(_DevourEnds.Num(), 0, f"the {InMachine} recorded no end");
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Server
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void Is_ServerReadyForSteward(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(utils_mars_net::Get_HasReplicatedSpawnOwner(Get_SubjectEntity()) && Get_IsReceiverFound());
    }

    UFUNCTION()
    private void OnServerOwnerReady(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        if (Require_Receiver(k_Row) == false)
        { return; }

        Spawn_ServerSteward();
        WaitUntil(n"Is_StewardSinkEvaluated", n"OnServerFound", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSampling(k_ComposeSeconds, n"OnServerComposed");
    }

    UFUNCTION()
    private void OnServerComposed(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Spawn_ServerFailSource(EMars_MechanismSource_Output::Deasserted);
        WaitSampling(k_RiseDelaySeconds, n"OnServerReadyToRise");
    }

    UFUNCTION()
    private void OnServerReadyToRise(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Request_ServerFailChannel(EMars_MechanismSource_Output::Asserted);
        WaitSampling(k_ServerQuietSeconds, n"OnServerQuiet");
    }

    UFUNCTION()
    private void OnServerQuiet(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto HasShared = utils_entity_tag::Has(_Player, n"TAG_MarsSharedCombatTarget");
        const auto HasLocal = utils_entity_tag::Has(_Player, n"TAG_MarsCombatTarget");
        Assert_True(Get_StewardPower() == EMars_MechanismSink_Power::Powered, "the server's sink reads Powered");
        Assert_NothingSeized("server");
        Assert_False(HasShared, "the unpossessed pawn's entity does not carry TAG_MarsSharedCombatTarget");
        Assert_False(HasLocal, "the unpossessed pawn's entity does not carry TAG_MarsCombatTarget");
        Assert_False(Get_HasVictimMarker(_Player), "the unpossessed pawn's entity has no marker");
        Hold_StewardServerRow(k_Row, f"pawnShared={HasShared} pawnLocal={HasLocal}");
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Client
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void OnClientFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitUntil(n"Is_StewardSinkPowered", n"OnClientPowered", k_SlowPolls);
    }

    UFUNCTION()
    private void OnClientPowered(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSampling(k_ClientQuietSeconds, n"OnClientSettled");
    }

    UFUNCTION()
    private void OnClientSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Log_StewardRow(k_Row, "");
        Assert_False(Get_HasDevourerAuthority(), "the client has no authority over its copy of the steward");
        Assert_NothingSeized("client");
        Finish_DevourRow();
    }
}
