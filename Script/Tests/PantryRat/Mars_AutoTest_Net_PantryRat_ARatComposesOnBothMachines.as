// The server's court emerges one rat: the server has authority over it and it replicates there under its raid, with
// what decides and moves it (a navigator, a pocket, a state machine, its links to its raid and its den) and no
// transform interpolation. The client's copy of it lives under the client's copy of the raid, without authority; it
// has its own pocket and none of the rest: its links name nobody, its tuning is the row's, and it carries the monster
// (body Health 1, one hurtbox addressed {its root, 0}), the mouth node, a transform interpolation, the ledger and the
// mirror's state; it reads unloaded, solid and shown. The client's raid copy holds no rat record.
// Surface: Ck.PantryRat.Net.AS_PantryRat_ARatComposesOnBothMachines
class UCk_AutoTest_Net_PantryRat_ARatComposesOnBothMachines : UMars_AutoTestRig_NetPantryRat
{
    default _TimeoutSeconds = 28.0f;

    private const FVector k_Base = FVector(678000.0, 0.0, 5000.0);
    private const FString k_Row = "ARatComposesOnBothMachines";

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
        Begin_ServerRatCourt(Spec, n"OnServerRatOut");
    }

    UFUNCTION()
    private void OnServerRatOut(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Wait_RowSampling(k_ComposeSeconds, n"OnServerComposed");
    }

    UFUNCTION()
    private void OnServerComposed(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        if (Get_IsRowRatGone())
        {
            Log_RatRow(k_Row, "");
            FinishFailure("the server's rat was gone before it asserted");
            return;
        }

        FCk_Handle Entity = _RowRat;
        FCk_Handle RaidEntity = _RowRaid;
        Assert_True(utils_net::Get_HasAuthority(Entity), "the server has authority over its rat");
        Assert_True(utils_entity_replication_driver::Has(Entity), "the server's rat has a replication driver");
        Assert_True(utils_mars_net::Get_ReplicatesHere(Entity), "the server's rat replicates");
        Assert_True(Entity.Get_LifetimeOwner() == RaidEntity, "the server's rat lives under its raid");
        Assert_True(ck::IsValid(_RowRat.Get_Navigator()), "the server's rat has a navigator");
        Assert_True(ck::IsValid(_RowRat.Get_Pocket()), "the server's rat has a pocket");
        Assert_True(Get_HasRowRatStateMachine(), "the server's rat has a state machine");
        Assert_True(Get_HasRowRatSurfaceNavigator(), "the server's rat root is a surface navigator");
        Assert_True(_RowRat.Get_Raid() == _RowRaid, "the server's rat's raid is its raid");
        Assert_True(_RowRat.Get_Den() == _RowDen, "the server's rat's den is its den");
        Assert_False(utils_transform_interpolation::Has(Entity), "the server's rat has no transform interpolation");
        Assert_True(Get_HasRowRatLedger(), "the server's rat has its ledger");
        Hold_RatServerRow(k_Row, Describe_CourtFrames());
    }

    UFUNCTION()
    private void OnClientFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Wait_RowSampling(k_SettleSeconds, n"OnClientSettled");
    }

    UFUNCTION()
    private void OnClientSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Get_IsRowRaidFound();
        if (Get_IsRowRatGone() || Get_IsRowEnding(_RowRaid))
        {
            Log_RatRow(k_Row, "");
            FinishFailure("the client's rat or raid copy was gone before it asserted");
            return;
        }

        FCk_Handle Entity = _RowRat;
        FCk_Handle RaidEntity = _RowRaid;
        auto Monster = _RowRat.Get_Monster();
        auto Zone = Monster.Get_BodyZone();
        const auto Address = Zone.Get_Address();
        const auto Tuning = _RowRat.Get_Tuning();
        Assert_False(utils_net::Get_HasAuthority(Entity), "the client has no authority over its rat");
        Assert_True(utils_mars_net::Get_ReplicatesHere(Entity), "the client's rat replicates");
        Assert_True(Entity.Get_LifetimeOwner() == RaidEntity, "the client's rat lives under its raid copy");
        Assert_False(ck::IsValid(_RowRat.Get_Navigator()), "the client's rat has no navigator");
        FCk_Handle PocketEntity = _RowRat.Get_Pocket();
        Assert_True(ck::IsValid(PocketEntity), "the client's rat has a pocket");
        Assert_True(ck::IsValid(PocketEntity) && _RowRat.Get_Pocket().Get_NumItems() == 0, "the client's pocket holds no item");
        Assert_True(ck::IsValid(PocketEntity) && utils_entity_lifetime::Get_LifetimeOwner(PocketEntity) == Entity,
            "the client's pocket's lifetime owner is its rat");
        Assert_False(ck::IsValid(_RowRat.Get_Raid()), "the client's rat names no raid");
        Assert_False(ck::IsValid(_RowRat.Get_Den()), "the client's rat names no den");
        Assert_False(Get_HasRowRatStateMachine(), "the client's rat has no state machine");
        Assert_False(Get_HasRowRatSurfaceNavigator(), "the client's rat root is no surface navigator");
        Assert_Equals_Int(_RowRat.Get_Links().OperationId, 1, "the client's rat keeps operation 1");
        Assert_Equals_Int(_RowRat.Get_Links().ResidentSlot, 0, "the client's rat keeps slot 0");
        Assert_True(Tuning.Speeds.Creep == 100.0f, f"the client's rat creeps at 100 (reads {Tuning.Speeds.Creep})");
        Assert_True(Tuning.Scent.GroundArmSeconds == 0.5f, f"the client's rat carries the row's scent arm 0.5 (reads {Tuning.Scent.GroundArmSeconds})");
        Assert_True(ck::IsValid(Monster), "the client's rat has a monster");
        Assert_True(Math::IsNearlyEqual(Monster.Get_BodyHealth().Get_Current(), 1.0f, 0.0001f), "the client's rat body Health reads 1");
        Assert_Equals_Int(Zone.Get_Hurtboxes().Num(), 1, "the client's body zone has one hurtbox");
        Assert_True(Address.Root == Entity && Address.Index == 0, "the client's body zone's address is {its root, 0}");
        Assert_True(utils_hit_zone::TryGet_ZoneAt(Address) == Zone, "the client's body zone's address resolves back to it");
        Assert_True(ck::IsValid(_RowRat.Get_MouthNode()), "the client's rat has a mouth node");
        Assert_True(utils_transform_interpolation::Has(Entity), "the client's rat has a transform interpolation");
        Assert_True(Get_HasRowRatLedger(), "the client's rat has its ledger");
        Assert_True(Get_HasRowRatLocal(), "the client's rat has its mirror's state");
        Assert_False(_RowRat.Get_IsLoaded(), "the client's rat reads unloaded");
        Assert_True(_RowRat.Get_FadeAlpha() == 1.0f, f"the client's rat reads solid (fade {_RowRat.Get_FadeAlpha()})");
        Assert_False(_RowRat.Get_IsHidden(), "the client's rat is shown");
        Assert_Equals_Int(_RowRaid.Get_RatCount(), 0, "the client's raid copy has no rat record");
        Finish_RatRow(k_Row, "");
    }
}
