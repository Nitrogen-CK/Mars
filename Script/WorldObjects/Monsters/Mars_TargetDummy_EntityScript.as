// Placeable target dummy (Room 5): a 60x60x120 post on team Two with a Health, one Body zone (Sever x1 Damages, Crush
// x1.5 Ruins) and one hurtbox over the post, so the player's strikes have something to land on before the crawlers.
// The origin is the post's base. A hit punches the post to 90% for 0.1 s; depletion flattens it to 20% height and,
// RearmSeconds later, heals it back to MaxHealth and stands it up again.
class UMars_TargetDummy_EntityScript : UCk_GenericEntityScript_UE
{
    default _ShowInPlaceActors = true;
    default _Replication = ECk_Replication::DoesNotReplicate;

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
        auto Root = utils_transform::Add(InHandle, SpawnTransform, ECk_Replication::DoesNotReplicate);
        utils_entity_tag::Add(InHandle, n"TAG_MarsTargetDummy");
        utils_team::Add(InHandle, ECk_Team_ID::Two, ECk_Replication::DoesNotReplicate);

        _Health = utils_health::Add(InHandle, FMars_Health_Spec(MaxHealth));
        if (ck::Is_NOT_Valid(_Health))
        { return ECk_EntityScript_ConstructionFlow::Finished; }

        auto ZoneSpec = FMars_HitZone_Spec(GameplayTags::ResolveGameplayTag(n"HitZone.Mars.Body"));
        ZoneSpec.Reactions.Add(FMars_HitZone_Reaction(GameplayTags::ResolveGameplayTag(n"DamageType.Mars.Sever"), 1.0f,
            EMars_HitZone_ConditionImpact::Damages));
        ZoneSpec.Reactions.Add(FMars_HitZone_Reaction(GameplayTags::ResolveGameplayTag(n"DamageType.Mars.Crush"), 1.5f,
            EMars_HitZone_ConditionImpact::Ruins));
        auto Zone = utils_hit_zone::Add(InHandle, ZoneSpec);

        // The body node sits at the base so the punch and the flatten scale the post toward the floor.
        _BodyNode = utils_scene_node::Create(Root, FTransform::Identity);
        auto Body = _BodyNode.As_Transform();
        const auto PostCentre = FTransform(FRotator::ZeroRotator, FVector(0.0, 0.0, PostHeight * 0.5));

        // The hurtbox wraps the post with a margin, so a Blocking strike sweep meets the probe before the post's own
        // collision should that ever be part of the Jolt world.
        if (ck::IsValid(Zone))
        {
            const auto HalfExtents = FVector(PostWidth * 0.5, PostWidth * 0.5, PostHeight * 0.5) + FVector(HurtboxMargin, HurtboxMargin, HurtboxMargin);
            utils_hit_zone::AddHurtbox_Box(Zone, Body, FMars_HitZone_Hurtbox(HalfExtents, PostCentre));
        }

        AddPost(Body, PostCentre.GetLocation());

        _Health.BindTo_OnDamaged(FMars_Delegate_Health_OnDamaged(this, n"OnDamaged"));
        _Health.BindTo_OnDepleted(FMars_Delegate_Health_OnDepleted(this, n"OnDepleted"));

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
        _RearmTimer = RestartTimer(_RearmTimer, RearmSeconds, n"OnRearmDone");
    }

    UFUNCTION()
    private void OnPunchDone(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        if ((FCk_Handle(_PunchTimer) == FCk_Handle(InTimer)) == false || _IsFlattened)
        { return; }

        SetBodyScale(FVector::OneVector);
    }

    UFUNCTION()
    private void OnRearmDone(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        if ((FCk_Handle(_RearmTimer) == FCk_Handle(InTimer)) == false)
        { return; }

        _IsFlattened = false;
        SetBodyScale(FVector::OneVector);

        if (ck::IsValid(_Health))
        { _Health.Request_Heal(FMars_Request_Health_Heal(MaxHealth)); }
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
        { utils_entity_lifetime::Request_DestroyEntity(FCk_Handle(InPrevious)); }

        auto Owner = FCk_Handle(_Health);
        if (ck::Is_NOT_Valid(Owner))
        { return FCk_Handle_Timer(); }

        auto TimerSpec = FCk_Timer_Spec(FCk_Time(InSeconds));
        TimerSpec.Set_StartingState(ECk_Timer_State::Running)
                 .Set_Behavior(ECk_Timer_Behavior::StopOnDone);

        auto Timer = utils_timer::Add(Owner, TimerSpec);
        if (ck::IsValid(Timer))
        { Timer.BindTo_OnDone(FCk_Delegate_Timer(this, InHandler)); }

        return Timer;
    }

    // NewObject needs a UObject outer, hence a private method on the entity script.
    private void AddPost(FCk_Handle_Transform& InAttachTo, FVector InLocation)
    {
        auto CubeMesh = engine::load::Cube();
        if (ck::Is_NOT_Valid(CubeMesh))
        { return; }

        // Engine cube is 100 uu with its pivot at the centre.
        const auto Scale = FVector(PostWidth, PostWidth, PostHeight) * 0.01;
        auto Node = utils_scene_node::Create(InAttachTo, FTransform(FRotator::ZeroRotator, InLocation, Scale));
        auto NodeEntity = FCk_Handle(Node);

        auto Archetype = NewObject(this, UStaticMeshComponent);
        // Movable: the component is registered first and then receives the entity transform, which a Static component
        // refuses once the world has begun play.
        Archetype.SetMobility(EComponentMobility::Movable);
        Archetype.SetStaticMesh(CubeMesh);
        auto Material = assets::load::ProtoGrid_Interactable_Mars_MI();
        if (ck::IsValid(Material))
        { Archetype.SetMaterial(0, Material); }
        Archetype.SetCollisionProfileName(collision::profile::BlockAll);

        auto ComponentParams = utils_unreal_component::Make_Params_FromArchetype(
            Archetype, ECk_UnrealComponent_TickPolicy::DoNotTick, n"TargetDummy_Post");
        utils_unreal_component::Add(NodeEntity, ComponentParams);
    }
}
