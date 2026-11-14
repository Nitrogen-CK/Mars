// A raid and a den are one of each on every machine, and only the server's raid runs: the server's raid (its field
// composed, not built) counts its den and the one stand-in carrying TAG_MarsSharedCombatTarget, not the one carrying
// TAG_MarsCombatTarget alone, and its den publishes its eyes. The client's copies have no authority and replicate; its
// raid copy has run nothing (no clock, no den, no chef, no pack although its den copy stands inside its bounds) and
// reads its field invalid; its den copy composed whole at its spot with the server's eyes and keeps a mirror state.
// Surface: Ck.PantryRaid.Net.AS_PantryRaid_RaidAndDenComposeOnBothMachines
class UCk_AutoTest_Net_PantryRaid_RaidAndDenComposeOnBothMachines : UMars_AutoTestRig_NetPantryRaid
{
    default _TimeoutSeconds = 28.0f;

    private const FVector k_Base = FVector(670000.0, 0.0, 5000.0);
    private const FVector k_SharedChefOffset = FVector(0.0, 300.0, 0.0);
    private const FVector k_LocalChefOffset = FVector(0.0, -300.0, 0.0);
    private const float32 k_ServerWatchSeconds = 3.0f;
    private const FString k_Row = "RaidAndDenComposeOnBothMachines";

    private FCk_Handle _SharedChef;
    private FCk_Handle _LocalChef;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_PantryRow(k_Base);

        if (Get_IsServer() == false)
        {
            WaitUntil(n"Is_RowRaidAndDenFound", n"OnClientFound", k_SlowPolls);
            return;
        }

        WaitUntil(n"Is_RowSpawnOwnerPublished", n"OnServerOwnerPublished", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerOwnerPublished(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Spawn_ServerVolume();
        Spawn_ServerRaid(Make_RowSpec());
        Spawn_ServerDen(2);
        _SharedChef = Make_ServerChef(_Base + k_SharedChefOffset, n"TAG_MarsSharedCombatTarget");
        _LocalChef = Make_ServerChef(_Base + k_LocalChefOffset, n"TAG_MarsCombatTarget");
        WaitUntil(n"Is_RowRaidAndDenFound", n"OnServerFound", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_ServerWatchSeconds, n"OnServerWatched");
    }

    UFUNCTION()
    private void OnServerWatched(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Chefs = _RowRaid.Get_Chefs();
        const auto Dens = _RowRaid.Get_Dens();
        Assert_True(utils_net::Get_HasAuthority(_RowRaid), "the server has authority over its raid");
        Assert_True(utils_net::Get_HasAuthority(_RowDen), "the server has authority over its den");
        Assert_True(_RowRaid.Get_Clock() > 1.0f, f"the server's raid clock runs (reads {_RowRaid.Get_Clock()})");
        Assert_True(Dens.Num() == 1 && Dens[0] == _RowDen, f"the server's raid counts its den alone ({Dens.Num()} dens)");
        Assert_Equals_Int(Chefs.Num(), 1, "the server's raid counts one chef");
        if (Chefs.Num() == 1)
        {
            Assert_True(Chefs[0].Root == _SharedChef, "the server's chef is the stand-in carrying the shared tag");
            Assert_True((Chefs[0].Location - (_Base + k_SharedChefOffset)).Size() <= 5.0, "the chef stands within 5 of its spot");
        }

        Assert_False(_RowRaid.Get_IsReady(), "the server's raid is not ready (its field is not built)");
        Assert_Equals_Int(_RowRaid.Get_RatCount(), 0, "the server's raid has no rat");
        Assert_True(ck::IsValid(_RowRaid.Get_NavVolume()), "the server's raid reads its field valid");
        Assert_Equals_Int(_RowDen.Get_SlotCountIn(EMars_RatDen_SlotState::Dormant), 2, "the server's den: two residents Dormant");
        Assert_True(Get_IsRowEyeSlot(0), "the server's den: eye slot 0");
        Assert_True(Get_IsRowDenLedger(EMars_RatDen_Eyes::Shown, 0), "the server's den ledger reads Shown and 0");
        Assert_False(Get_IsRowDenMirrorStateSet(), "the server's den keeps no mirror state");
        Hold_PantryServerRow(k_Row, f"localChefIsChef={utils_pantry_raid::Get_IsChef(_LocalChef)}");
    }

    UFUNCTION()
    private void OnClientFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_SettleSeconds, n"OnClientSettled");
    }

    UFUNCTION()
    private void OnClientSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        if (Get_IsRowEnding(_RowRaid) || Get_IsRowEnding(_RowDen))
        {
            Log_PantryRow(k_Row, "copies=gone");
            FinishFailure("the client's copies were gone before it asserted");
            return;
        }

        const auto DenRoot = Get_RowRootLocation(_RowDen);
        Assert_False(utils_net::Get_HasAuthority(_RowRaid), "the client has no authority over its raid copy");
        Assert_False(utils_net::Get_HasAuthority(_RowDen), "the client has no authority over its den copy");
        Assert_True(utils_mars_net::Get_ReplicatesHere(_RowRaid), "the client's raid copy replicates");
        Assert_True(utils_mars_net::Get_ReplicatesHere(_RowDen), "the client's den copy replicates");
        Assert_True(_RowRaid.Get_Clock() == 0.0f, f"the client's raid copy clock reads 0 (reads {_RowRaid.Get_Clock()})");
        Assert_True(_RowRaid.Get_IsInsideBounds(DenRoot), "the client's den copy stands inside its raid copy's bounds");
        Assert_Equals_Int(_RowRaid.Get_Dens().Num(), 0, "the client's raid copy has no den");
        Assert_Equals_Int(_RowRaid.Get_Chefs().Num(), 0, "the client's raid copy has no chef");
        Assert_Equals_Int(_RowRaid.Get_Packs().Num(), 0, "the client's raid copy has no pack");
        Assert_False(_RowRaid.Get_IsReady(), "the client's raid copy is not ready");
        Assert_False(ck::IsValid(_RowRaid.Get_NavVolume()), "the client's raid copy reads its field invalid");
        Assert_False(_RowRaid.Has_Fragment(FMars_Fragment_PantryRaid_Requests), "the client's raid copy carries no requests");
        Assert_True(_RowDen.Has_Fragment(FMars_Fragment_RatDen_Assembly), "the client's den copy carries its assembly");
        Assert_True((DenRoot - _DenSpot).Size() <= 5.0, "the client's den copy stands within 5 of its spot");
        Assert_True((_RowDen.Get_PortalWorld(EMars_RatDen_Portal::OutsideStand) - (_DenSpot + FVector(75.0, 0.0, 0.0))).Size() <= 5.0,
            "the client's den copy's OutsideStand is 75 out of its opening");
        Assert_Equals_Int(_RowDen.Get_ResidentCount(), 2, "the client's den copy has two residents");
        Assert_True(Get_IsRowEyeSlot(0), "the client's den copy: eye slot 0");
        Assert_True(Get_IsRowDenLedger(EMars_RatDen_Eyes::Shown, 0), "the client's den ledger reads Shown and 0");
        Assert_True(Get_IsRowDenMirrorStateSet(), "the client's den copy keeps its mirror state");
        Finish_PantryRow(k_Row, "");
    }
}
