// The zone and dealer net tests' shared steps, on top of the Health rig's: this machine's copy of the target's root zone
// and, when the target carries one, its limb zone (its roster's second entry); a count of OnHit on the root zone; a dealer
// composed on the subject by the machine that calls Compose_Dealer, with counts of what it dealt and rejected; and a fig
// vine the server spawns, found on each machine with its zone and its forage.
UCLASS(Abstract)
class UMars_AutoTestRig_NetHitZone : UMars_AutoTestRig_NetHealth
{
    protected FCk_Handle_HitZone _Zone;
    protected int32 _OnHit = 0;

    protected FCk_Handle_DamageDealer _Dealer;
    protected int32 _Dealt = 0;
    protected FCk_Handle_HitZone _LastDealtZone;
    protected int32 _DealtFrame = -1;
    protected int32 _Rejected = 0;
    protected TOptional<EMars_DamageDealer_RejectReason> _LastRejectReason;
    protected int32 _DealFrame = -1;

    protected FCk_Handle_Forage _Forage;
    protected int32 _Exhausted = 0;
    protected int32 _Replenished = 0;

    // Server: the target at the base with the limb zone, under the replicated spawn owner.
    protected void Spawn_ServerTargetWithLimb()
    {
        auto Params = FMars_NetCombat_Target_SpawnParams(FTransform(FRotator::ZeroRotator, _Base), k_MaxHealth);
        Params.LimbZone = ECk_EnableDisable::Enable;
        utils_entity_script::Request_SpawnEntity(utils_mars_net::Get_ReplicatedSpawnOwner(Get_SubjectEntity()),
            UMars_NetCombat_Target_EntityScript, Params);
    }

    // Server: the target at the base on InTeam, under the replicated spawn owner.
    protected void Spawn_ServerTargetOnTeam(ECk_Team_ID InTeam)
    {
        auto Params = FMars_NetCombat_Target_SpawnParams(FTransform(FRotator::ZeroRotator, _Base), k_MaxHealth);
        Params.Team = InTeam;
        utils_entity_script::Request_SpawnEntity(utils_mars_net::Get_ReplicatedSpawnOwner(Get_SubjectEntity()),
            UMars_NetCombat_Target_EntityScript, Params);
    }

    UFUNCTION()
    protected void Is_ZoneTargetFound(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsZoneTargetFound());
    }

    // This machine's copy of the target has composed its Health and its root zone; the first time, the zone's OnHit is
    // counted from here.
    protected bool Get_IsZoneTargetFound()
    {
        if (ck::IsValid(_Zone))
        { return true; }

        if (Get_IsTargetFound() == false)
        { return false; }

        auto Zone = _Target.As_HitZone(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(Zone))
        { return false; }

        Bind_Zone(Zone);
        return true;
    }

    // The roster's second entry on this machine's copy of the target, read straight from the roster; invalid until it exists.
    protected FCk_Handle_HitZone Get_LimbZone()
    {
        if (ck::Is_NOT_Valid(_Target) || _Target.Has_Fragment(FMars_Fragment_HitZone_Roster) == false)
        { return FCk_Handle_HitZone(); }

        const auto& Zones = _Target.Get_Fragment(FMars_Fragment_HitZone_Roster).Zones;
        if (Zones.Num() < 2)
        { return FCk_Handle_HitZone(); }

        return Zones[1];
    }

    // Server: InAmount of InDamageType straight onto this machine's root zone.
    protected void Request_ZoneHit(float32 InAmount, FGameplayTag InDamageType)
    {
        _Zone.Request_Hit(FMars_Request_HitZone_Hit(FMars_DamageEvent(InAmount, InDamageType)));
    }

    // On the machine that calls it: the subject joins team One and composes a dealer whose results are counted here.
    protected void Compose_Dealer()
    {
        auto Subject = Get_SubjectEntity();
        utils_team::Add(Subject, ECk_Team_ID::One, ECk_Replication::DoesNotReplicate);
        _Dealer = utils_damage_dealer::Add(Subject, FMars_DamageDealer_Spec());
        _Dealer.BindTo_OnDamageDealt(FMars_Delegate_DamageDealer_OnDamageDealt(this, n"OnDealerDealt"));
        _Dealer.BindTo_OnDamageRejected(FMars_Delegate_DamageDealer_OnDamageRejected(this, n"OnDealerRejected"));
    }

    // This machine's dealer deals InAmount Sever on its copy's first hurtbox, as a swept swing would.
    protected void Request_DealOnHurtbox(float32 InAmount)
    {
        const auto Hurtboxes = _Zone.Get_Hurtboxes();
        if (ck::EnsureIfNot(Hurtboxes.Num() > 0, "[HitZoneNetTest] the target's copy has no hurtbox to deal on"))
        { return; }

        _DealFrame = int32(utils_time::Get_FrameCounter());
        _Dealer.Request_DealDamage(FMars_Request_DamageDealer_DealDamage(Hurtboxes[0],
            utils_damage_dealer::Make_Event(_Dealer, InAmount, GameplayTags::DamageType_Mars_Sever)));
    }

    UFUNCTION()
    protected void Is_VineFound(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsVineFound());
    }

    // Server: a fig vine (one fig, regrowing after InRegrowSeconds) at the base.
    protected void Spawn_ServerFigVine(float32 InRegrowSeconds)
    {
        auto Params = UMars_Forage_FigVine_EntityScript::Params();
        Params.SpawnTransform = FTransform(FRotator::ZeroRotator, _Base);
        Params.RegrowSeconds = InRegrowSeconds;
        Params.WithVisuals = false;
        utils_entity_script::Request_SpawnEntity(utils_mars_net::Get_ReplicatedSpawnOwner(Get_SubjectEntity()), UMars_Forage_FigVine_EntityScript, Params);
    }

    // This machine's copy of the vine near the base has composed its forage, Health and zone; the first time, the zone's
    // OnHit and the forage's exhaustion and regrow are counted from here (and the server tracks it).
    protected bool Get_IsVineFound()
    {
        if (ck::IsValid(_Forage))
        { return true; }

        for (auto Candidate : utils_entity_tag::ForEach_Entity(Get_SubjectEntity(), n"TAG_MarsForageVine"))
        {
            if (Get_IsNear(Candidate) == false)
            { continue; }

            auto Forage = Candidate.As_Forage(ECk_SanityCheck::UnChecked);
            auto Health = Candidate.As_Health(ECk_SanityCheck::UnChecked);
            auto Zone = Candidate.As_HitZone(ECk_SanityCheck::UnChecked);
            if (ck::Is_NOT_Valid(Forage) || ck::Is_NOT_Valid(Health) || ck::Is_NOT_Valid(Zone))
            { continue; }

            _Target = Candidate;
            _Health = Health;
            _Forage = Forage;
            _Forage.BindTo_OnExhausted(FMars_Delegate_Forage_OnExhausted(this, n"OnVineExhausted"));
            _Forage.BindTo_OnReplenished(FMars_Delegate_Forage_OnReplenished(this, n"OnVineReplenished"));
            Bind_Zone(Zone);
            if (Get_IsServer())
            { Track_ForCleanup(Candidate); }

            return true;
        }

        return false;
    }

    // The row's one log line on this machine: its Health, its root zone, its dealer, then InExtra.
    protected void Log_ZoneRow(FString InRow, FString InExtra)
    {
        const auto IsZoneFound = ck::IsValid(_Zone);
        const auto Current = ck::IsValid(_Health) ? _Health.Get_Current() : -1.0f;
        const auto HitCount = IsZoneFound ? _Zone.Get_HitCount() : -1;
        const auto IsEnabled = IsZoneFound && _Zone.Get_IsEnabled();
        const auto Hurtboxes = IsZoneFound ? _Zone.Get_Hurtboxes().Num() : -1;
        const auto HitsDealt = ck::IsValid(_Dealer) ? _Dealer.Get_HitsDealt() : -1;
        const auto HitsRejected = ck::IsValid(_Dealer) ? _Dealer.Get_HitsRejected() : -1;
        const auto Reason = _LastRejectReason.IsSet() ? f"{_LastRejectReason.GetValue() :n}" : "none";
        const auto Line = f"[HitZoneNetTest] {InRow} {Get_MachineName()} current={Current} hitCount={HitCount} onHit={_OnHit} enabled={IsEnabled} hurtboxes={Hurtboxes} damaged={_Damaged.Num()} dealt={_Dealt} hitsDealt={HitsDealt} rejected={_Rejected} hitsRejected={HitsRejected} lastReason={Reason} ensures={Get_NewEnsures()} {InExtra}";
        Log(Line);
    }

    private void Bind_Zone(FCk_Handle_HitZone InZone)
    {
        _Zone = InZone;
        _Zone.BindTo_OnHit(FMars_Delegate_HitZone_OnHit(this, n"OnZoneHit"));
    }

    UFUNCTION()
    private void OnZoneHit(FCk_Handle_HitZone InZone, FMars_DamageEvent InScaledEvent, FMars_HitZone_Reaction InReaction)
    {
        _OnHit += 1;
    }

    UFUNCTION()
    private void OnDealerDealt(FCk_Handle_DamageDealer InDealer, FCk_Handle_HitZone InZone, FMars_DamageEvent InEvent)
    {
        _Dealt += 1;
        _LastDealtZone = InZone;
        _DealtFrame = int32(utils_time::Get_FrameCounter());
    }

    UFUNCTION()
    private void OnDealerRejected(FCk_Handle_DamageDealer InDealer, FCk_Handle InHitEntity, EMars_DamageDealer_RejectReason InReason)
    {
        _Rejected += 1;
        _LastRejectReason = TOptional<EMars_DamageDealer_RejectReason>(InReason);
    }

    UFUNCTION()
    private void OnVineExhausted(FCk_Handle_Forage InForage)
    {
        _Exhausted += 1;
    }

    UFUNCTION()
    private void OnVineReplenished(FCk_Handle_Forage InForage)
    {
        _Replenished += 1;
    }
}
