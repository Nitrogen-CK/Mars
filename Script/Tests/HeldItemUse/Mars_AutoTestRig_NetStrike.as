// One OnDamaged as a machine raised it, with the frame it was raised in and how many hits its dealer had dealt by then.
struct FMars_NetStrikeTest_Damaged
{
    UPROPERTY()
    FMars_DamageEvent Event;

    UPROPERTY()
    float32 Applied = 0.0f;

    UPROPERTY()
    int32 Frame = 0;

    UPROPERTY()
    int32 DealtBefore = 0;
}

// The strike net tests' shared steps, on top of the hotbar rig's carrier: "the striker" is the carrier composed on the
// subject on both machines with its hand off the row's base, one bag slot, a team and a dealer whose signals each machine
// counts; "armed" is the server's cleaver in slot 0, selected, held on each machine. The server spawns a combat target
// (or a fig vine) under the replicated spawn owner; each machine finds its copy near where it was spawned and counts what
// its own copy raises. A client swings as the strike task does, or claims a blow straight through the cue; the server
// reads the tally of its copy of the subject.
UCLASS(Abstract)
class UMars_AutoTestRig_NetStrike : UMars_AutoTestRig_NetHotbar
{
    default _TimeoutSeconds = 25.0f;

    // A client asserts once the last server step has had this long to arrive.
    protected const float32 k_SettleSeconds = 1.0f;
    protected const float32 k_ClaimSpacingSeconds = 0.6f;
    protected const float64 k_NearCm = 400.0;
    protected const float32 k_MaxHealth = 100.0f;
    protected const FVector k_HandFromBase = FVector(-120.0, 0.0, 60.0);
    // The combat target's box hurtbox, centred on its root.
    protected const float64 k_TargetHurtboxHalfExtent = 40.0;
    protected const float32 k_VineHangHeight = 60.0f;
    protected const float32 k_VineRegrowSeconds = 30.0f;

    protected FVector _Base = FVector::ZeroVector;
    protected FVector _TargetAt = FVector::ZeroVector;
    protected int32 _EnsuresAtStart = 0;

    protected FCk_Handle_DamageDealer _Dealer;
    protected int32 _Dealt = 0;
    protected int32 _DealtFrame = -1;
    protected int32 _Rejected = 0;
    protected TOptional<EMars_DamageDealer_RejectReason> _LastRejectReason;

    // What this machine struck: the target's or the vine's Health and zone.
    protected FCk_Handle _Target;
    protected FCk_Handle_Health _Health;
    protected FCk_Handle_HitZone _Zone;
    protected TArray<FMars_NetStrikeTest_Damaged> _Damaged;

    protected FCk_Handle_Forage _Forage;
    protected int32 _Released = 0;
    protected int32 _Exhausted = 0;
    protected TOptional<EMars_Forage_ReleaseReason> _LastReleaseReason;

    // The client's swing: the frame it swept in and where its sweep hit.
    protected int32 _SwingFrame = -1;
    protected FCk_ShapeCast_Result _SwingHit;

    protected void Begin_Strike(FVector InBase)
    {
        _Base = InBase;
        _TargetAt = InBase;
        _EnsuresAtStart = utils_ensure::Get_EnsureCount();
        Compose_Striker();
    }

    // The carrier with its hand off the base, a team and a dealer, on the subject.
    private void Compose_Striker()
    {
        auto Subject = Get_SubjectEntity();
        Compose_HotbarCarrier(Get_HandLocation(), 1);
        utils_team::Add(Subject, ECk_Team_ID::One, ECk_Replication::DoesNotReplicate);
        _Dealer = utils_damage_dealer::Add(Subject, FMars_DamageDealer_Spec());
        _Dealer.BindTo_OnDamageDealt(FMars_Delegate_DamageDealer_OnDamageDealt(this, n"OnDealerDealt"));
        _Dealer.BindTo_OnDamageRejected(FMars_Delegate_DamageDealer_OnDamageRejected(this, n"OnDealerRejected"));
    }

    protected bool Get_IsServer()
    {
        return utils_net::Get_HasAuthority(Get_SubjectEntity());
    }

    protected int32 Get_NewEnsures() const
    {
        return utils_ensure::Get_EnsureCount() - _EnsuresAtStart;
    }

    protected FString Get_MachineName()
    {
        return Get_IsServer() ? "server" : "client";
    }

    protected FVector Get_HandLocation() const
    {
        return _Base + k_HandFromBase;
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Armed
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    protected void Is_ServerReady(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(utils_mars_net::Get_HasReplicatedSpawnOwner(Get_SubjectEntity()) && Get_IsCarrierReady(_Carrier));
    }

    // Server: a cleaver in slot 0, selected.
    protected void Arm_Server()
    {
        Seed_ServerSlotWith(0, mars_items::Cleaver());
        _Carrier.Hotbar.Request_SetSelection(FMars_Request_Hotbar_SetSelection(TOptional<int32>(0)));
    }

    UFUNCTION()
    protected void Is_Armed(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsArmed());
    }

    // This machine's own HeldItem holds a cleaver.
    protected bool Get_IsArmed()
    {
        if (Get_IsCarrierReady(_Carrier) == false)
        { return false; }

        const auto Item = _Carrier.HeldItem.Get_CurrentItem();
        return ck::IsValid(Item) && Item.Get_Definition() == mars_items::Cleaver();
    }

    //----------------------------------------------------------------------------------------------------------------------
    // The target
    //----------------------------------------------------------------------------------------------------------------------

    // Server: the target at _TargetAt on InTeam, under the replicated spawn owner.
    protected void Spawn_ServerTarget(ECk_Team_ID InTeam)
    {
        auto Params = FMars_NetCombat_Target_SpawnParams(FTransform(FRotator::ZeroRotator, _TargetAt), k_MaxHealth);
        Params.Team = InTeam;
        utils_entity_script::Request_SpawnEntity(utils_mars_net::Get_ReplicatedSpawnOwner(Get_SubjectEntity()),
            UMars_NetCombat_Target_EntityScript, Params);
    }

    UFUNCTION()
    protected void Is_TargetFound(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsTargetFound());
    }

    // This machine's copy of the target near _TargetAt has composed its Health and its root zone; the first time, its
    // Health's signals are recorded from here (and the server tracks it).
    protected bool Get_IsTargetFound()
    {
        if (ck::IsValid(_Zone))
        { return true; }

        for (auto Candidate : utils_entity_tag::ForEach_Entity(Get_SubjectEntity(), n"TAG_MarsTestNetCombatTarget"))
        {
            if (Get_IsNear(Candidate, _TargetAt) == false)
            { continue; }

            auto Health = Candidate.As_Health(ECk_SanityCheck::UnChecked);
            auto Zone = Candidate.As_HitZone(ECk_SanityCheck::UnChecked);
            if (ck::Is_NOT_Valid(Health) || ck::Is_NOT_Valid(Zone))
            { continue; }

            Take_Struck(Candidate, Health, Zone);
            return true;
        }

        return false;
    }

    protected bool Get_IsCurrent(float32 InExpected)
    {
        return ck::IsValid(_Health) && Math::IsNearlyEqual(_Health.Get_Current(), InExpected, 0.01f);
    }

    //----------------------------------------------------------------------------------------------------------------------
    // A claim row: the server arms (unless told not to), spawns the target and watches; the client claims once it holds
    // the cleaver and has found its copy. The row names OnServerWatched and OnClientReady.
    //----------------------------------------------------------------------------------------------------------------------

    protected float32 _WatchSeconds = 4.0f;
    protected ECk_Team_ID _TargetTeam = ECk_Team_ID::Two;
    protected ECk_EnableDisable _ServerArms = ECk_EnableDisable::Enable;

    protected void Start_ClaimRow()
    {
        if (Get_IsServer())
        {
            WaitUntil(n"Is_ServerReady", n"OnClaimRowServerReady", k_SlowPolls);
            return;
        }

        WaitUntil(n"Is_ClientReadyToClaim", n"OnClientReady", k_SlowPolls);
    }

    UFUNCTION()
    private void OnClaimRowServerReady(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        if (_ServerArms == ECk_EnableDisable::Disable)
        {
            Spawn_ServerTarget(_TargetTeam);
            WaitUntil(n"Is_TargetFound", n"OnClaimRowServerFound", k_SlowPolls);
            return;
        }

        Arm_Server();
        WaitUntil(n"Is_Armed", n"OnClaimRowServerArmed", k_SlowPolls);
    }

    UFUNCTION()
    private void OnClaimRowServerArmed(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Spawn_ServerTarget(_TargetTeam);
        WaitUntil(n"Is_TargetFound", n"OnClaimRowServerFound", k_SlowPolls);
    }

    UFUNCTION()
    private void OnClaimRowServerFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(_WatchSeconds, n"OnServerWatched");
    }

    UFUNCTION()
    protected void Is_ClientReadyToClaim(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        const auto IsArmed = _ServerArms == ECk_EnableDisable::Disable || Get_IsArmed();
        Result.Set(Get_IsCarrierReady(_Carrier) && IsArmed && Get_IsTargetFound());
    }

    // The row's log line on this machine, no ensure, done.
    protected void Finish_Row(FString InRow, FString InExtra)
    {
        Log_Row(InRow, InExtra);
        Assert_Equals_Int(Get_NewEnsures(), 0, f"no ensure on the {Get_MachineName()}");
        FinishSuccess();
    }

    // Server: the row's log line and no ensure, then the hold after its last write before it finishes.
    protected void Hold_ServerRow(FString InRow, FString InExtra)
    {
        Log_Row(InRow, InExtra);
        Assert_Equals_Int(Get_NewEnsures(), 0, "no ensure on the server");
        WaitSeconds(k_ServerHoldSeconds, n"OnServerHeld");
    }

    //----------------------------------------------------------------------------------------------------------------------
    // The vine
    //----------------------------------------------------------------------------------------------------------------------

    // Server: a fig vine at the base whose fruit hangs level with the hand, without visuals.
    protected void Spawn_ServerFigVine()
    {
        auto Params = UMars_Forage_FigVine_EntityScript::Params();
        Params.SpawnTransform = FTransform(FRotator::ZeroRotator, _Base);
        Params.HangHeight = k_VineHangHeight;
        Params.RegrowSeconds = k_VineRegrowSeconds;
        Params.WithVisuals = false;
        utils_entity_script::Request_SpawnEntity(utils_mars_net::Get_ReplicatedSpawnOwner(Get_SubjectEntity()), UMars_Forage_FigVine_EntityScript, Params);
    }

    UFUNCTION()
    protected void Is_VineFound(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsVineFound());
    }

    // This machine's copy of the vine near the base has composed its Health, zone and forage; the first time, their
    // signals are counted from here (and the server tracks it).
    protected bool Get_IsVineFound()
    {
        if (ck::IsValid(_Forage))
        { return true; }

        for (auto Candidate : utils_entity_tag::ForEach_Entity(Get_SubjectEntity(), n"TAG_MarsForageVine"))
        {
            if (Get_IsNear(Candidate, _Base) == false)
            { continue; }

            auto Health = Candidate.As_Health(ECk_SanityCheck::UnChecked);
            auto Zone = Candidate.As_HitZone(ECk_SanityCheck::UnChecked);
            auto Forage = Candidate.As_Forage(ECk_SanityCheck::UnChecked);
            if (ck::Is_NOT_Valid(Health) || ck::Is_NOT_Valid(Zone) || ck::Is_NOT_Valid(Forage))
            { continue; }

            _Forage = Forage;
            _Forage.BindTo_OnReleased(FMars_Delegate_Forage_OnReleased(this, n"OnForageReleased"));
            _Forage.BindTo_OnExhausted(FMars_Delegate_Forage_OnExhausted(this, n"OnForageExhausted"));
            Take_Struck(Candidate, Health, Zone);
            return true;
        }

        return false;
    }

    // Figs near the base; the server tracks each one it counts.
    protected int32 Count_FigsNear()
    {
        auto Count = 0;
        for (auto Candidate : utils_entity_tag::ForEach_Entity(Get_SubjectEntity(), n"TAG_MarsWorldItem"))
        {
            auto WorldItem = Candidate.As_WorldItem(ECk_SanityCheck::UnChecked);
            if (ck::Is_NOT_Valid(WorldItem) || Get_IsNear(Candidate, _Base) == false)
            { continue; }

            const auto Item = WorldItem.Get_HeldItem();
            if (ck::Is_NOT_Valid(Item) || Item.Get_Definition() != mars_items::Fig())
            { continue; }

            if (Get_IsServer())
            { Track_ForCleanup(Candidate); }

            Count += 1;
        }

        return Count;
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Swinging and claiming
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    protected void Is_ZoneSweepable(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsZoneSweepable());
    }

    // Armed, a silent sweep from the hand along +X, as far as the held item reaches, reports a hurtbox of this machine's
    // struck zone: its hurtbox is in the probe world.
    protected bool Get_IsZoneSweepable()
    {
        if (ck::Is_NOT_Valid(_Zone) || Get_IsArmed() == false)
        { return false; }

        const UMars_ItemTrait_Strike Strike = _Carrier.HeldItem.Get_CurrentItem().Get_Strike();
        const auto Start = Get_HandLocation();
        auto Settings = FCk_ShapeCast_Settings(
            Start,
            Start + FVector::ForwardVector * Strike.Reach,
            utils_shapes::Make_Sphere(FCk_ShapeSphere_Dimensions(Strike.Radius)),
            GameplayTag::MakeContainerFromTag(GameplayTags::Probe_Mars_HitZone));
        Settings.Set_OverlapNotifyPolicy(ECk_ProbeResponse_Policy::Silent);
        auto Subject = Get_SubjectEntity();
        const auto Hit = utils_probe_trace::Request_SingleShapeTrace(Subject, Settings);
        return utils_hit_zone::TryGet_Zone(Hit.Get_HitEntity()) == _Zone;
    }

    // The two calls the strike task makes, from the hand along +X: the dealer's sweep with the task's template, then the
    // claim of what it found.
    protected void Swing_FromTheHand()
    {
        auto Subject = Get_SubjectEntity();
        const auto Item = _Carrier.HeldItem.Get_CurrentItem();
        const UMars_ItemTrait_Strike Strike = Item.Get_Strike();
        const auto Start = Get_HandLocation();
        const auto Forward = FVector::ForwardVector;

        auto Template = utils_damage_dealer::Make_Event(_Dealer, Strike.Damage, Strike.DamageType);
        Template.Source.Causer = Item;
        Template.Hit.Impulse = Forward * Strike.ImpulseSpeed;

        _SwingFrame = int32(utils_time::Get_FrameCounter());
        _SwingHit = _Dealer.Request_StrikeSweep(FMars_DamageDealer_Sweep(Start, Start + Forward * Strike.Reach, Strike.Radius), Template);
        utils_held_item_use::Fire_StrikeCueFor(Subject, FMars_HeldItemUse_Swing(Item, _SwingHit, Template.Hit.Impulse));
    }

    // The default claim: this machine's copy of the struck zone, the cleaver, the point of the target's hurtbox nearest
    // the hand, +X.
    protected FMars_HeldItemUse_Strike Make_Claim()
    {
        const auto Address = _Zone.Get_Address();
        auto Claim = FMars_HeldItemUse_Strike();
        Claim.ZoneRoot = Address.Root;
        Claim.ZoneIndex = Address.Index;
        Claim.Item = utils_held_item::Make_DefinitionSoft(mars_items::Cleaver());
        Claim.Location = _TargetAt + FVector(-k_TargetHurtboxHalfExtent, 0.0, k_TargetHurtboxHalfExtent);
        Claim.Normal = FVector(-1.0, 0.0, 0.0);
        Claim.Impulse = FVector::ForwardVector;
        return Claim;
    }

    protected void Fire_Claim(const FMars_HeldItemUse_Strike& InClaim)
    {
        utils_cue_generic::Request_ExecuteCue(Get_SubjectEntity(), GameplayTags::Cue_Mars_HeldItemUse_Strike, InClaim,
            ECk_Cue_ReliabilityPolicy::Reliable, ECk_Cue_MulticastPolicy::ServerOnly);
    }

    protected FMars_HeldItemUse_StrikeTally Get_Tally()
    {
        return _Carrier.Use.Get_StrikeTally();
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Asserts and the log line
    //----------------------------------------------------------------------------------------------------------------------

    protected void Assert_Tally(int32 InApplied, int32 InRefused, TOptional<EMars_HeldItemUse_StrikeRefusal> InLastRefusal)
    {
        const auto Tally = Get_Tally();
        Assert_Equals_Int(Tally.Applied, InApplied, f"the server applied {InApplied} claim(s)");
        Assert_Equals_Int(Tally.Refused, InRefused, f"the server refused {InRefused} claim(s)");
        const auto SameRefusal = Tally.LastRefusal.IsSet() == InLastRefusal.IsSet()
            && (InLastRefusal.IsSet() == false || Tally.LastRefusal.GetValue() == InLastRefusal.GetValue());
        Assert_True(SameRefusal, "the server's last refusal is the expected one");
    }

    // The distances the authority measures for a contact at InLocation: from the hand, and from the nearest hurtbox node
    // of the struck zone.
    protected FString Describe_Distances(FVector InLocation)
    {
        const auto Hand = utils_transform::Get_EntityCurrentTransform(_Carrier.HeldItem.Get_HandAttachPoint()).GetLocation();
        auto Nearest = -1.0;
        if (ck::IsValid(_Zone))
        {
            for (auto Hurtbox : _Zone.Get_Hurtboxes())
            {
                const auto Node = Hurtbox.As_Transform(ECk_SanityCheck::UnChecked);
                if (ck::Is_NOT_Valid(Node))
                { continue; }

                const auto Distance = (utils_transform::Get_EntityCurrentTransform(Node).GetLocation() - InLocation).Size();
                if (Nearest < 0.0 || Distance < Nearest)
                { Nearest = Distance; }
            }
        }

        auto ReachLimit = -1.0;
        if (Get_IsArmed())
        {
            const UMars_ItemTrait_Strike Strike = _Carrier.HeldItem.Get_CurrentItem().Get_Strike();
            ReachLimit = Strike.Reach + Strike.Radius + constants_held_item_use::k_StrikeReachSlack;
        }

        const auto FromHand = (InLocation - Hand).Size();
        return f"handToContact={FromHand} hurtboxToContact={Nearest} reachLimit={ReachLimit} zoneLimit={constants_held_item_use::k_StrikeZoneSlack}";
    }

    // The row's one log line on this machine.
    protected void Log_Row(FString InRow, FString InExtra)
    {
        const auto Tally = Get_Tally();
        const auto Current = ck::IsValid(_Health) ? _Health.Get_Current() : -1.0f;
        const auto Refusal = Tally.LastRefusal.IsSet() ? f"{Tally.LastRefusal.GetValue() :n}" : FString("none");
        const auto LastAt = Tally.LastAppliedAt.IsSet() ? Tally.LastAppliedAt.GetValue() : -1.0;
        const auto HitsDealt = ck::IsValid(_Dealer) ? _Dealer.Get_HitsDealt() : -1;
        const auto Reject = _LastRejectReason.IsSet() ? f"{_LastRejectReason.GetValue() :n}" : FString("none");
        const auto FirstDamagedFrame = _Damaged.Num() > 0 ? _Damaged[0].Frame : -1;
        const auto Line = f"[StrikeNetTest] {InRow} {Get_MachineName()} tally=[applied {Tally.Applied} refused {Tally.Refused} last {Refusal} at {LastAt}] current={Current} damaged={_Damaged.Num()} dealt={_Dealt} hitsDealt={HitsDealt} rejected={_Rejected} reject={Reject} released={_Released} exhausted={_Exhausted} swingFrame={_SwingFrame} dealtFrame={_DealtFrame} damagedFrame={FirstDamagedFrame} ensures={Get_NewEnsures()} {InExtra}";
        Log(Line);
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Signals
    //----------------------------------------------------------------------------------------------------------------------

    private void Take_Struck(FCk_Handle InEntity, FCk_Handle_Health InHealth, FCk_Handle_HitZone InZone)
    {
        _Target = InEntity;
        _Health = InHealth;
        _Zone = InZone;
        _Health.BindTo_OnDamaged(FMars_Delegate_Health_OnDamaged(this, n"OnStruckDamaged"));
        if (Get_IsServer())
        { Track_ForCleanup(InEntity); }
    }

    protected bool Get_IsNear(FCk_Handle InEntity, FVector InAt)
    {
        const auto Transform = InEntity.As_Transform(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(Transform))
        { return false; }

        auto Offset = utils_transform::Get_EntityCurrentTransform(Transform).GetLocation() - InAt;
        Offset.Z = 0.0;
        return Offset.Size() < k_NearCm;
    }

    UFUNCTION()
    private void OnDealerDealt(FCk_Handle_DamageDealer InDealer, FCk_Handle_HitZone InZone, FMars_DamageEvent InEvent)
    {
        _Dealt += 1;
        if (_DealtFrame < 0)
        { _DealtFrame = int32(utils_time::Get_FrameCounter()); }
    }

    UFUNCTION()
    private void OnDealerRejected(FCk_Handle_DamageDealer InDealer, FCk_Handle InHitEntity, EMars_DamageDealer_RejectReason InReason)
    {
        _Rejected += 1;
        _LastRejectReason = InReason;
    }

    UFUNCTION()
    private void OnStruckDamaged(FCk_Handle_Health InHealth, FMars_DamageEvent InEvent, float32 InApplied, float32 InRemaining)
    {
        auto Record = FMars_NetStrikeTest_Damaged();
        Record.Event = InEvent;
        Record.Applied = InApplied;
        Record.Frame = int32(utils_time::Get_FrameCounter());
        Record.DealtBefore = _Dealt;
        _Damaged.Add(Record);
    }

    UFUNCTION()
    private void OnForageReleased(FCk_Handle_Forage InForage, FCk_Handle InWorldItem, EMars_Forage_ReleaseReason InReason)
    {
        _Released += 1;
        _LastReleaseReason = InReason;
    }

    UFUNCTION()
    private void OnForageExhausted(FCk_Handle_Forage InForage)
    {
        _Exhausted += 1;
    }
}
