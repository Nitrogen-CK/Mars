// The server raises its Root Maw and latches a gape of 0.8 as soon as its behaviour reads Buried and it carries no
// pending requests, before the client's copy can be sure to have composed: the client's copy reads emerged with its jaw
// at 0.8 and its ledger Emerged and 0.8, having raised OnStance(Emerged) at most once (0: the ledger stood when the
// copy bound and it shows the Maw where it is; 1: the ledger arrived after and it played the rise).
// Surface: Ck.RootMaw.Net.AS_RootMaw_ALateBinderSeesAnEmergedMaw
class UCk_AutoTest_Net_RootMaw_ALateBinderSeesAnEmergedMaw : UMars_AutoTestRig_NetRootMaw
{
    default _TimeoutSeconds = 25.0f;

    private const FVector k_Base = FVector(574000.0, 0.0, 5000.0);
    private const float32 k_LateGape = 0.8f;
    private const float32 k_HoldSeconds = 4.0f;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_MawRow(k_Base);

        if (Get_IsServer() == false)
        {
            WaitUntil(n"Is_MawFound", n"OnClientFound", k_SlowPolls);
            return;
        }

        WaitUntil(n"Is_ReplicatedSpawnOwnerPublished", n"OnServerOwnerPublished", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerOwnerPublished(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Spawn_ServerMawFloor();
        Spawn_ServerMaw(FMars_RootMaw_Spec());
        WaitUntil(n"Is_BuriedAndQuiet", n"OnServerQuiet", k_SlowPolls);
    }

    // Its behaviour reads Buried (the state's own requests were issued) and the drain has taken them.
    UFUNCTION()
    private void Is_BuriedAndQuiet(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsMawFound() && _Maw.Get_BehaviorStateClass() == UMars_SmState_RootMaw_Buried
            && _Maw.Has_Fragment(FMars_Fragment_RootMaw_Requests) == false);
    }

    UFUNCTION()
    private void OnServerQuiet(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitFrames(1, n"OnServerRaise");
    }

    UFUNCTION()
    private void OnServerRaise(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _Maw.Request_SetStance(FMars_Request_RootMaw_SetStance(EMars_RootMaw_Stance::Emerged));
        _Maw.Request_Gape(FMars_Request_RootMaw_Gape(k_LateGape));
        WaitSampling(k_HoldSeconds, n"OnServerWatched");
    }

    UFUNCTION()
    private void OnServerWatched(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_True(_Maw.Get_IsEmerged(), "the server's Maw is up");
        Assert_True(Get_HasMawLedger(), "the server's Maw has its ledger");
        const auto Ledger = Get_MawLedger();
        Assert_True(Ledger.Stance == EMars_RootMaw_Stance::Emerged, "the server's ledger reads Emerged");
        Assert_True(Math::IsNearlyEqual(Ledger.Gape, k_LateGape, 0.0001f), "the server's ledger reads a gape of 0.8");
        Hold_MawServerRow("ALateBinderSeesAnEmergedMaw", "");
    }

    UFUNCTION()
    private void OnClientFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitUntil(n"Is_MawEmerged", n"OnClientEmerged", k_SlowPolls);
    }

    UFUNCTION()
    private void OnClientEmerged(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSampling(k_SettleSeconds, n"OnClientSettled");
    }

    UFUNCTION()
    private void OnClientSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_True(Math::IsNearlyEqual(_Maw.Get_Emerge(), 1.0f, 0.0001f), "the client's Maw is fully up");
        const auto Jaw = _Maw.Get_JawOpen();
        Assert_True(Math::Abs(Jaw - k_LateGape) <= 0.05f, f"the client's jaw is within 0.05 of 0.8 (reads {Jaw})");
        Assert_True(Get_HasMawLedger(), "the client's copy has its ledger");
        const auto Ledger = Get_MawLedger();
        Assert_True(Ledger.Stance == EMars_RootMaw_Stance::Emerged, "the client's ledger reads Emerged");
        Assert_True(Math::IsNearlyEqual(Ledger.Gape, k_LateGape, 0.0001f), "the client's ledger reads a gape of 0.8");
        Assert_True(_MawEmergedStances <= 1, "the client raised OnStance(Emerged) at most once");
        Finish_MawRow("ALateBinderSeesAnEmergedMaw", f"path={_MawEmergedStances}");
    }
}
