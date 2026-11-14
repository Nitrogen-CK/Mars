// Placeable target dummy (Room 5): a 60x60x120 post on team Two with a Health, one Body zone (Sever x1 Damages, Crush
// x1.5 Ruins) and one hurtbox over the post, so the player's strikes have something to land on before the crawlers.
// The origin is the post's base. The entity, its root transform and its Health's ledger replicate; a blow reaches it as
// any zone's does (a client's through its strike claim). The punch (90% for 0.1 s) and the flatten (20% height) follow the
// Health's signals on every machine; only the authority's timer heals it back to MaxHealth RearmSeconds after depletion,
// and every machine stands it up when that heal arrives.
class UMars_TargetDummy_EntityScript : UCk_GenericEntityScript_UE
{
    default _ShowInPlaceActors = true;
    // Stance A: the entity, its transform and its Health ledger replicate; the post, the zone and the hurtbox are each
    // machine's own; only the authority's timer heals.
    default _Replication = ECk_Replication::Replicates;

    UPROPERTY(ExposeOnSpawn)
    FTransform SpawnTransform = FTransform::Identity;

    UPROPERTY(ExposeOnSpawn)
    float32 MaxHealth = 100.0f;

    UPROPERTY(ExposeOnSpawn)
    float32 RearmSeconds = 5.0f;

    private const float64 PostWidth = 60.0;
    private const float64 PostHeight = 120.0;
    private const float64 HurtboxMargin = 5.0;
    private const float32 PunchSeconds = 0.1f;
    private const float64 PunchScale = 0.9;
    private const float64 FlattenedScaleZ = 0.2;

    // Scaled for the punch and the flatten; the post visual and the hurtbox hang off it, so both follow.
    private FCk_Handle_SceneNode _BodyNode;
    private FCk_Handle_Health _Health;
    private FCk_Handle_Timer _PunchTimer;
    private FCk_Handle_Timer _RearmTimer;
    private bool _IsFlattened = false;

    UFUNCTION(BlueprintOverride)
    ECk_EntityScript_ConstructionFlow DoConstruct(FCk_Handle& InHandle)
    {
        auto Root = utils_transform::Add(InHandle, SpawnTransform, ECk_Replication::Replicates);
        utils_entity_tag::Add(InHandle, n"TAG_MarsTargetDummy");
        utils_team::Add(InHandle, ECk_Team_ID::Two, ECk_Replication::DoesNotReplicate);

        _Health = utils_health::Add(InHandle, FMars_Health_Spec(MaxHealth));
        if (ck::Is_NOT_Valid(_Health))
        { return ECk_EntityScript_ConstructionFlow::Finished; }

        // Each Add ensures on its own rejection.
        auto Zone = utils_hit_zone::Add(InHandle, utils_hit_zone::Make_FleshZoneSpec(GameplayTags::HitZone_Mars_Body, 1.5f));
        if (ck::Is_NOT_Valid(Zone))
        { return ECk_EntityScript_ConstructionFlow::Finished; }

        // The body node sits at the base so the punch and the flatten scale the post toward the floor.
        _BodyNode = utils_scene_node::Create(Root, FTransform::Identity);
        auto Body = _BodyNode.As_Transform();
        const auto PostCentre = FTransform(FRotator::ZeroRotator, FVector(0.0, 0.0, PostHeight * 0.5));

        // The hurtbox wraps the post with a margin, so a Blocking strike sweep meets the probe before the post's own
        // collision should that ever be part of the Jolt world.
        const auto HalfExtents = FVector(PostWidth * 0.5, PostWidth * 0.5, PostHeight * 0.5) + FVector(HurtboxMargin, HurtboxMargin, HurtboxMargin);
        utils_hit_zone::AddHurtbox_Box(Zone, Body, FMars_HitZone_Hurtbox(HalfExtents, PostCentre));

        // Engine cube is 100 uu with its pivot at the centre.
        Body.Add_MeshPart(this, FMars_MeshPart(
            FTransform(FRotator::ZeroRotator, PostCentre.GetLocation(), FVector(PostWidth, PostWidth, PostHeight) * 0.01),
            engine::load::Cube(), assets::load::ProtoGrid_Interactable_Mars_MI(), collision::profile::BlockAll, n"TargetDummy_Post"));

        _Health.BindTo_OnDamaged(FMars_Delegate_Health_OnDamaged(this, n"OnDamaged"));
        _Health.BindTo_OnDepleted(FMars_Delegate_Health_OnDepleted(this, n"OnDepleted"));
        _Health.BindTo_OnHealed(FMars_Delegate_Health_OnHealed(this, n"OnHealed"));

        return ECk_EntityScript_ConstructionFlow::Finished;
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Handlers
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void OnDamaged(FCk_Handle_Health InHealth, FMars_DamageEvent InEvent, float32 InApplied, float32 InRemaining)
    {
        if (_IsFlattened)
        { return; }

        SetBodyScale(FVector(PunchScale, PunchScale, PunchScale));
        _PunchTimer = RestartTimer(_PunchTimer, PunchSeconds, n"OnPunchDone");
    }

    UFUNCTION()
    private void OnDepleted(FCk_Handle_Health InHealth, FMars_DamageEvent InCause)
    {
        _IsFlattened = true;
        SetBodyScale(FVector(1.0, 1.0, FlattenedScaleZ));

        // A copy without authority drops Health requests: it waits for the heal to arrive through the ledger instead.
        if (utils_net::Get_HasAuthority(InHealth))
        { _RearmTimer = RestartTimer(_RearmTimer, RearmSeconds, n"OnRearmDone"); }
    }

    UFUNCTION()
    private void OnPunchDone(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        if (_PunchTimer != InTimer || _IsFlattened)
        { return; }

        SetBodyScale(FVector::OneVector);
    }

    UFUNCTION()
    private void OnRearmDone(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        if (_RearmTimer != InTimer)
        { return; }

        if (ck::IsValid(_Health))
        { _Health.Request_Heal(FMars_Request_Health_Heal(MaxHealth)); }
    }

    // Raised by the authority's drain and by every other machine's mirror, so each stands the post up as the heal lands.
    UFUNCTION()
    private void OnHealed(FCk_Handle_Health InHealth, float32 InApplied, float32 InRemaining)
    {
        _IsFlattened = false;
        SetBodyScale(FVector::OneVector);
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Visuals
    //----------------------------------------------------------------------------------------------------------------------

    private void SetBodyScale(FVector InScale)
    {
        if (ck::Is_NOT_Valid(_BodyNode))
        { return; }

        auto Offset = utils_scene_node::Get_Offset(_BodyNode);
        Offset.SetScale3D(InScale);
        utils_scene_node::Request_UpdateOffset(_BodyNode, FCk_Request_SceneNode_UpdateRelativeTransform(Offset));
    }

    // One-shot: a previous timer of the same kind is destroyed so only the newest one fires.
    private FCk_Handle_Timer RestartTimer(FCk_Handle_Timer InPrevious, float32 InSeconds, FName InHandler)
    {
        if (ck::IsValid(InPrevious))
        { utils_entity_lifetime::Request_DestroyEntity(InPrevious); }

        auto TimerSpec = FCk_Timer_Spec(FCk_Time(InSeconds));
        TimerSpec.Set_StartingState(ECk_Timer_State::Running)
                 .Set_Behavior(ECk_Timer_Behavior::StopOnDone);

        // The handlers that restart timers are bound only once _Health composed.
        auto Timer = utils_timer::Add(_Health, TimerSpec);
        if (ck::IsValid(Timer))
        { Timer.BindTo_OnDone(FCk_Delegate_Timer(this, InHandler)); }

        return Timer;
    }
}
