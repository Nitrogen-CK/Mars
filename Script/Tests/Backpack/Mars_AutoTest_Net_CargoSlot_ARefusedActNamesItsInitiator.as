// A client's take at an empty slot reaches the authority, which asks Get_ActionFor again, reads Blocked_NothingHeld and
// refuses: the slot's replicated ledger advances by one on both machines, names the subject and says ActionBlocked, and
// nobody ensures (a stale or racing Act is not a broken caller).
// Surface: Ck.Backpack.Net.AS_CargoSlot_ARefusedActNamesItsInitiator
class UCk_AutoTest_Net_CargoSlot_ARefusedActNamesItsInitiator : UMars_AutoTestRig_NetBackpack
{
    private const FVector k_FloorTop = FVector(52000.0, 0.0, 5000.0);

    private int32 _SerialAtAct = 0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Subject = Get_SubjectEntity();
        if (ck::Is_NOT_Valid(Subject))
        { FinishFailure("subject entity not found"); return; }

        Begin_NetBackpack(InHandle, k_FloorTop);

        if (utils_net::Get_HasAuthority(Subject) == false)
        {
            WaitUntil(n"Is_PackReady", n"OnClientPackReady", k_SlowPolls);
            return;
        }

        WaitUntil(n"Is_ReplicatedSpawnOwnerPublished", n"OnServerOwnerPublished", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerOwnerPublished(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Spawn_ServerPack();
        WaitUntil(n"Is_PackReady", n"OnServerPackReady", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerPackReady(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _SerialAtAct = _Slot0.Get_RefusalSerial();
        WaitUntil(n"Is_Refused", n"OnServerRefused", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerRefused(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_Refusal("server");
        WaitSeconds(k_ServerHoldSeconds + 1.0f, n"OnServerHeld");
    }

    UFUNCTION()
    private void OnClientPackReady(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _SerialAtAct = _Slot0.Get_RefusalSerial();
        utils_cargo_slot::Request_ActFor(_Slot0, Get_SubjectEntity(), EMars_CargoSlot_Action::Take);
        WaitUntil(n"Is_Refused", n"OnClientRefused", k_SlowPolls);
    }

    UFUNCTION()
    private void OnClientRefused(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_Refusal("client");
        const auto NewEnsures = Get_NewEnsures();
        const auto Serial = _Slot0.Get_RefusalSerial();
        const auto Reason = _Slot0.Get_LastRefusal();
        const auto NamesSubject = _Slot0.Get_LastRefused() == Get_SubjectEntity();
        Log(f"[CargoSlotNetTest] refused take serial={_SerialAtAct}->{Serial} reason={Reason :n} namesSubject={NamesSubject} newEnsures={NewEnsures}");
        Assert_True(NewEnsures == 0, f"no ensure fired (got {NewEnsures})");
        FinishSuccess();
    }

    UFUNCTION()
    private void Is_Refused(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_Slot0.Get_RefusalSerial() > _SerialAtAct && _Slot0.Get_LastRefused() == Get_SubjectEntity());
    }

    private void Assert_Refusal(FString InMachine)
    {
        Assert_True(_Slot0.Get_RefusalSerial() == _SerialAtAct + 1,
            f"the {InMachine}'s ledger advanced by one (got {_SerialAtAct} -> {_Slot0.Get_RefusalSerial()})");
        Assert_True(_Slot0.Get_LastRefusal() == EMars_Interaction_FailReason::ActionBlocked,
            f"the {InMachine}'s ledger says ActionBlocked (got [{_Slot0.Get_LastRefusal() :n}])");
        Assert_False(_Slot0.Get_IsOccupied(), f"the {InMachine}'s slot is still empty");
    }
}
