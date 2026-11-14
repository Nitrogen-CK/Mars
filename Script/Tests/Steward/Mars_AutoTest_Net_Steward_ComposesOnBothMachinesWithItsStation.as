// The steward is one creature on every machine: the server's camp steward has authority, is a Devour and a mechanism
// sink with a View node, carries its Contracts station on its root, stands at its spot and rests Idle with its ledger
// reading Idle, serial 0 and itself, its sink Unpowered and no mirror record; the client's copy, without authority and
// replicating there, composes the same list once its sink has evaluated, keeps a mirror record and has no pending
// Devour request.
// Surface: Ck.Steward.Net.AS_Steward_ComposesOnBothMachinesWithItsStation
class UCk_AutoTest_Net_Steward_ComposesOnBothMachinesWithItsStation : UMars_AutoTestRig_NetSteward
{
    default _TimeoutSeconds = 28.0f;

    private const FVector k_RowBase = FVector(640000.0, 0.0, 5000.0);
    private const FString k_Row = "ComposesOnBothMachinesWithItsStation";

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_StewardRow(k_RowBase, EMars_NetDevourTest_Victims::None);

        if (Get_IsServer())
        {
            WaitUntil(n"Is_ServerSpawnOwnerReady", n"OnServerOwnerReady", k_SlowPolls);
            return;
        }

        WaitUntil(n"Is_StewardSinkEvaluated", n"OnClientEvaluated", k_SlowPolls);
    }

    // The list both machines assert; InMachine names the machine in the messages.
    private void Assert_Composed(FString InMachine)
    {
        FCk_Handle Entity = _Devourer;
        const auto HasStation = Entity.Has_Fragment(FMars_Fragment_CampUiStation)
            && Entity.Get_Fragment(FMars_Fragment_CampUiStation).Station == EMars_CampStation::Contracts;
        const auto FromSpot = (Get_StewardLocation() - (_Base + k_StewardOffset)).Size();
        const auto Ledger = Get_DevourLedger();
        Assert_True(ck::IsValid(Get_StewardSink()), f"the {InMachine}'s steward is a mechanism sink");
        Assert_True(Get_StewardPower() == EMars_MechanismSink_Power::Unpowered, f"the {InMachine}'s sink reads Unpowered");
        Assert_True(ck::IsValid(_Devourer.Get_View()), f"the {InMachine}'s steward has a View node");
        Assert_True(HasStation, f"the {InMachine}'s steward's root carries its Contracts station");
        Assert_True(FromSpot < k_StewardSpotCm, f"the {InMachine}'s steward stands at its spot ({FromSpot} cm off)");
        Assert_True(Get_IsDevourerIn(EMars_Devour_Phase::Idle), f"the {InMachine}'s steward is Idle");
        Assert_True(Ledger.Phase == EMars_Devour_Phase::Idle, f"the {InMachine}'s ledger reads Idle");
        Assert_Equals_Int(Ledger.Serial, 0, f"the {InMachine}'s ledger reads serial 0");
        Assert_True(Describe_RawVictim() == "self", f"the {InMachine}'s ledger names the steward itself while Idle");
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Server
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void OnServerOwnerReady(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Spawn_ServerCampSteward();
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
        Assert_True(Get_HasDevourerAuthority(), "the server has authority over its steward");
        Assert_Composed("server");
        Assert_False(Get_HasStewardMirrorState(), "the server's steward keeps no mirror record");
        Hold_StewardServerRow(k_Row, "");
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Client
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void OnClientEvaluated(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSampling(k_SettleSeconds, n"OnClientSettled");
    }

    UFUNCTION()
    private void OnClientSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto ReplicatesHere = Get_IsDevourerGone() == false &&utils_mars_net::Get_ReplicatesHere(_Devourer);
        Log_StewardRow(k_Row, f"replicatesHere={ReplicatesHere}");
        Assert_False(Get_HasDevourerAuthority(), "the client has no authority over its copy of the steward");
        Assert_True(ReplicatesHere, "the client's copy of the steward replicates there");
        Assert_Composed("client");
        Assert_True(Get_HasStewardMirrorState(), "the client's copy keeps a mirror record");
        Assert_False(Get_HasDevourRequests(), "the client's copy has no pending Devour request");
        Finish_DevourRow();
    }
}
