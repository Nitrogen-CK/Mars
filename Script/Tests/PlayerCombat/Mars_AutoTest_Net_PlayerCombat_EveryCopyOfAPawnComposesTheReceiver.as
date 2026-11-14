// A pawn nobody controls composes the receiver on every machine: the server's copy and the client's each carry a Health
// at 100, a zone and one hurtbox linked back to it, and neither carries TAG_MarsCombatTarget; the client has no authority
// over the pawn's entity. The viewer beside it (the client's pawn) carries the receiver too and no tag on either machine:
// the host does not control it, and the client has no authority over it.
// Surface: Ck.PlayerCombat.Net.AS_PlayerCombat_EveryCopyOfAPawnComposesTheReceiver
class UCk_AutoTest_Net_PlayerCombat_EveryCopyOfAPawnComposesTheReceiver : UMars_AutoTestRig_NetPlayerCombat
{
    default _TimeoutSeconds = 25.0f;

    private const FVector k_Base = FVector(530000.0, 0.0, 5000.0);
    private const float32 k_ServerWatchSeconds = 4.0f;
    private const FString k_Row = "EveryCopyOfAPawnComposesTheReceiver";

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_Rig(k_Base);

        if (Get_IsServer() == false)
        {
            WaitUntil(n"Is_PawnComposed", n"OnComposed", k_SlowPolls);
            return;
        }

        Spawn_ServerPawn();
        Spawn_ServerViewer();
        WaitUntil(n"Is_ServerReadyWithViewer", n"OnComposed", k_SlowPolls);
    }

    UFUNCTION()
    private void OnComposed(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        if (Require_Receiver(k_Row) == false)
        { return; }

        WaitSeconds(Get_IsServer() ? k_ServerWatchSeconds : k_SettleSeconds, n"OnWatched");
    }

    UFUNCTION()
    private void OnWatched(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Machine = Get_MachineName();
        const auto Hurtbox = Get_Hurtbox();
        const auto Viewer = Get_Viewer();
        auto ViewerEntity = ck::IsValid(Viewer) ? Viewer.Get_GameplayComposedEntity() : FCk_Handle();
        const auto ViewerZone = ViewerEntity.As_HitZone(ECk_SanityCheck::UnChecked);
        const auto ViewerHasHealth = ck::IsValid(ViewerEntity.As_Health(ECk_SanityCheck::UnChecked));
        const auto ViewerHurtboxes = ck::IsValid(ViewerZone) ? ViewerZone.Get_Hurtboxes().Num() : -1;
        const auto ViewerAuthority = ck::IsValid(ViewerEntity) && utils_net::Get_HasAuthority(ViewerEntity);
        const auto ViewerTag = ck::IsValid(ViewerEntity) && utils_entity_tag::Has(ViewerEntity, n"TAG_MarsCombatTarget");
        const auto ViewerLocal = ck::IsValid(Viewer) && Viewer.IsLocallyControlled();
        Log_Row(k_Row, f"viewer=[health {ViewerHasHealth} hurtboxes {ViewerHurtboxes} authority {ViewerAuthority} local {ViewerLocal} tag {ViewerTag}]");
        Assert_Equals_Float(_Health.Get_Current(), 100.0f, 0.01f, f"the {Machine}'s copy reads 100");
        Assert_Valid(_Zone, f"the {Machine}'s copy has a zone");
        Assert_Valid(Hurtbox, f"the {Machine}'s copy has one hurtbox");
        Assert_True(ck::IsValid(Hurtbox) && utils_hit_zone::TryGet_Zone(Hurtbox) == _Zone, f"the {Machine}'s hurtbox links back to its zone");
        Assert_False(Get_HasCombatTargetTag(), f"the {Machine}'s copy carries no TAG_MarsCombatTarget (nobody controls it)");
        if (Get_IsServer() == false)
        { Assert_False(utils_net::Get_HasAuthority(_Player), "the client has no authority over the pawn's entity"); }

        Assert_Valid(ViewerEntity, f"the {Machine}'s copy of the viewer composed");
        Assert_False(ViewerTag, f"the {Machine}'s copy of the viewer carries no TAG_MarsCombatTarget");
        if (Get_IsServer())
        {
            Assert_True(ViewerHasHealth && ck::IsValid(ViewerZone) && ViewerHurtboxes == 1,
                f"the server's copy of the viewer has a Health, a zone and one hurtbox (hurtboxes {ViewerHurtboxes})");
            Assert_True(ViewerAuthority, "the server has authority over the viewer's entity");
        }
        else
        {
            Assert_True(ViewerLocal, "the client controls the viewer locally");
            Assert_False(ViewerAuthority, "the client has no authority over the viewer's entity");
        }

        Assert_Equals_Int(Get_NewEnsures(), 0, f"no ensure on the {Machine}");
        // The server's watch is its hold: it wrote nothing after the spawn.
        TearDown();
        FinishSuccess();
    }
}
