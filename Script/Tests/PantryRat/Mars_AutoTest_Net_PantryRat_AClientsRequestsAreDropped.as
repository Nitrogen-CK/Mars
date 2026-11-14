// The client asks its copy of a watching rat to guard, to move, to stop, to claim, to take a claim's answer, to take a
// hit, to die, to take a route's answer and to take a refused release: a machine without authority drops every one of
// them, so its copy still watches where it stood, unhurt and alive, its counters at 0 and no change raised since; the
// server's rat, which nothing sends home, watches on where it spawned, changed once (into its watch), refused nothing,
// took nothing and was never hurt.
// Surface: Ck.PantryRat.Net.AS_PantryRat_AClientsRequestsAreDropped
class UCk_AutoTest_Net_PantryRat_AClientsRequestsAreDropped : UMars_AutoTestRig_NetPantryRat
{
    default _TimeoutSeconds = 28.0f;

    private const FVector k_Base = FVector(683000.0, 0.0, 5000.0);
    private const FString k_Row = "AClientsRequestsAreDropped";
    private const float32 k_WatchSeconds = 5.0f;
    private const float32 k_ClientWatchSeconds = 1.5f;
    private const float32 k_ClientHit = 10.0f;
    private const float32 k_NeverHomeSeconds = 60.0f;
    private const float64 k_StillCm = 5.0;

    private int32 _ChangesAtAsks = 0;
    private FVector _StoodAt = FVector::ZeroVector;

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
        auto Tuning = utils_pantry_raid::Make_RatTuning(Make_RowSpec());
        Tuning.Scent.NoTargetReturnSeconds = k_NeverHomeSeconds;
        auto BornThrough = TArray<EMars_PantryRat_Phase>();
        BornThrough.Add(EMars_PantryRat_Phase::Observe);
        Spawn_ServerBornRat(BornThrough, Tuning);
        WaitUntil(n"Is_RowRatFound", n"OnServerFound", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Wait_RowSampling(k_WatchSeconds, n"OnServerWatched");
    }

    UFUNCTION()
    private void OnServerWatched(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        if (Get_IsRowRatGone())
        {
            Log_RatRow(k_Row, "");
            FinishFailure("the server's rat was gone before it asserted");
            return;
        }

        const auto Moved = Get_PlanarDistance(_RowRat.Get_Location(), _DenSpot + k_BornFromDen);
        Assert_True(_RowRat.Get_Phase() == EMars_PantryRat_Phase::Observe, "the server's rat watches");
        Assert_Equals_Int(_RowRat.Get_PhaseChanges(), 1, "the server's rat changed phase once");
        Assert_Equals_Int(_RowRat.Get_RejectedAdvances(), 0, "the server's rat refused no advance");
        Assert_Equals_Int(_RowRat.Get_StaleResults(), 0, "the server's rat ignored no stale answer");
        Assert_Equals_Int(_RowRat.Get_ClaimTransfersIssued(), 0, "the server's rat issued no transfer");
        Assert_False(_RowRat.Get_IsDead(), "the server's rat is alive");
        Assert_True(Math::IsNearlyEqual(_RowRat.Get_Monster().Get_BodyHealth().Get_Current(), 1.0f, 0.0001f), "the server's rat body Health reads 1");
        Assert_True(Moved <= k_StillCm, f"the server's rat stands within {k_StillCm} of where it spawned (moved {Moved})");
        Hold_RatServerRow(k_Row, "");
    }

    UFUNCTION()
    private void OnClientFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Wait_RowRatUntil(Make_RatUntil(EMars_NetRatTest_UntilKind::ReadsPhase, EMars_PantryRat_Phase::Observe), n"OnClientWatching");
    }

    UFUNCTION()
    private void OnClientWatching(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        if (Get_IsRowRatGone())
        {
            Log_RatRow(k_Row, "");
            FinishFailure("the client's rat was gone before it asked");
            return;
        }

        _ChangesAtAsks = _RatChanges.Num();
        _StoodAt = _RowRat.Get_Location();
        _RowRat.Request_Advance(FMars_Request_PantryRat_Advance(EMars_PantryRat_Phase::Observe, EMars_PantryRat_Phase::WatchGuarded));
        _RowRat.Request_MoveTo(FMars_Request_PantryRat_MoveTo(_StoodAt + FVector(200.0, 0.0, 0.0), 240.0f, EMars_PantryRat_RoutePurpose::Approach));
        _RowRat.Request_Stop(FMars_Request_PantryRat_Stop());
        _RowRat.Request_Claim(FMars_Request_PantryRat_Claim(1));
        _RowRat.Request_ClaimResult(FMars_Request_PantryRat_ClaimResult(FCk_Handle_Item(), FCk_Handle_Item(),
            ECk_Inventory_OperationResult_Transfer::Success));
        _RowRat.Request_TakeHit(FMars_Request_PantryRat_TakeHit(FMars_DamageEvent(k_ClientHit, GameplayTags::DamageType_Mars_Blunt)));
        _RowRat.Request_Died(FMars_Request_PantryRat_Died(FMars_DamageEvent(k_ClientHit, GameplayTags::DamageType_Mars_Blunt)));
        _RowRat.Request_NavResult(FMars_Request_PantryRat_NavResult(_StoodAt, true));
        _RowRat.Request_ReleaseRefused(FMars_Request_PantryRat_ReleaseRefused(FCk_Handle(), EMars_WorldItem_ReleaseRefusal::NotMounted));
        Wait_RowSampling(k_ClientWatchSeconds, n"OnClientWatched");
    }

    UFUNCTION()
    private void OnClientWatched(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        if (Get_IsRowRatGone())
        {
            Log_RatRow(k_Row, "");
            FinishFailure("the client's rat was gone before it asserted");
            return;
        }

        const auto Moved = Get_PlanarDistance(_RowRat.Get_Location(), _StoodAt);
        Assert_False(_RowRat.Has_Fragment(FMars_Fragment_PantryRat_Requests), "the client's copy carries no requests");
        Assert_True(_RowRat.Get_Phase() == EMars_PantryRat_Phase::Observe, "the client's rat watches");
        Assert_True(Get_RowRatLedger().Phase == EMars_PantryRat_Phase::Observe, "the client's ledger reads Observe");
        Assert_Equals_Int(_RatChanges.Num(), _ChangesAtAsks, "the client's rat raised no change since it asked");
        Assert_Equals_Int(_RowRat.Get_RejectedAdvances(), 0, "the client's rat refused no advance");
        Assert_Equals_Int(_RowRat.Get_StaleResults(), 0, "the client's rat ignored no stale answer");
        Assert_False(_RowRat.Get_Monster().Get_IsDead(), "the client's monster is alive");
        Assert_True(Math::IsNearlyEqual(_RowRat.Get_Monster().Get_BodyHealth().Get_Current(), 1.0f, 0.0001f), "the client's rat body Health reads 1");
        Assert_True(Moved <= k_StillCm, f"the client's rat stands within {k_StillCm} of where it stood (moved {Moved})");
        Finish_RatRow(k_Row, "");
    }
}
