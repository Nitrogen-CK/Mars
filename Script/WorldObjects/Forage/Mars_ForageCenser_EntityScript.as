// Placeable censer: a chain from a pivot ArmLength + PivotClearance + BobRadius up, a perforated bob at its end over a
// basin ring. Every strike on the bob (or a thrown item against it at KnockMinSpeed or more) shakes a handful of
// peppercorns out of it and sets it swinging for SwingSeconds; after Charges handfuls it is empty until it refills
// RefillSeconds later. Both triggers are composed here: an invulnerable Health + Body zone + hurtbox whose every hit
// spills, and a kinematic Jolt sphere riding the bob for the knock, solid whether the censer is full or empty.
class UMars_ForageCenser_EntityScript : UMars_ForageSource_EntityScript
{
    default _ShowInPlaceActors = true;
    default _Replication = ECk_Replication::DoesNotReplicate;

    UPROPERTY(ExposeOnSpawn)
    FTransform SpawnTransform = FTransform::Identity;

    // The swing is built from these rather than an exposed FMars_Oscillator_Spec with `default` overrides: the
    // spawn-params generator emits a non-default script struct as a positional constructor call, which it does not have.
    UPROPERTY(ExposeOnSpawn)
    float32 SwingAmplitudeDegrees = 18.0f;

    UPROPERTY(ExposeOnSpawn)
    float32 SwingPeriodSeconds = 2.2f;

    UPROPERTY(ExposeOnSpawn)
    float32 SwingSettleSeconds = 0.8f;

    // How long one spill keeps it swinging.
    UPROPERTY(ExposeOnSpawn)
    float32 SwingSeconds = 3.0f;

    // Pivot to bob centre.
    UPROPERTY(ExposeOnSpawn)
    float32 ArmLength = 160.0f;

    UPROPERTY(ExposeOnSpawn)
    int32 Charges = 3;

    UPROPERTY(ExposeOnSpawn)
    float32 RefillSeconds = 20.0f;

    // Closing speed (uu/s) a thrown world item needs to knock a handful out.
    UPROPERTY(ExposeOnSpawn)
    float32 KnockMinSpeed = 500.0f;

    // False skips the pivot block, chain, bob, cluster and basin meshes (headless tests); the swing, zone, hurtbox and
    // knock body stay.
    UPROPERTY(ExposeOnSpawn)
    bool WithVisuals = true;

    // The resting bob's bottom stands this far above the origin.
    private const float64 PivotClearance = 60.0;
    private const float64 BobRadius = 30.0;
    private const float64 ChainWidth = 6.0;
    private const float32 BasinHalfWidth = 70.0f;
    private const float64 HurtboxMargin = 5.0;
    private const float64 ClusterLift = 8.0;
    private const float64 ClusterScale = 0.16;
    private const FVector SpillLaunch = FVector(0.0, 0.0, -120.0);
    private const int32 k_SpillBurstBehavior = 13; // SparksBurst
    private const float32 k_SpillBurstSize = 0.5f;
    private const float32 k_SpillBurstColor = 0.2f;

    private FCk_Handle_Oscillator _Swing;
    private FCk_Handle_Transform _ReleasePoint;
    private FCk_Handle_Timer _SwingTimer;
    // The entity script is a UObject, not a fragment, so it may hold the component.
    private UNiagaraComponent _SpillBurst;

    protected float32 Get_KnockMinSpeed() const override
    {
        return KnockMinSpeed;
    }

    UFUNCTION(BlueprintOverride)
    ECk_EntityScript_ConstructionFlow DoConstruct(FCk_Handle& InHandle)
    {
        auto Root = utils_transform::Add(InHandle, SpawnTransform, ECk_Replication::DoesNotReplicate);
        utils_entity_tag::Add(InHandle, n"TAG_MarsForageCenser");

        const auto PivotHeight = ArmLength + PivotClearance + BobRadius;
        auto PivotNode = utils_scene_node::Create(Root, FTransform(FRotator::ZeroRotator, FVector(0.0, 0.0, PivotHeight)));
        auto PivotTransform = PivotNode.As_Transform();
        auto BobNode = utils_scene_node::Create(PivotTransform, FTransform(FRotator::ZeroRotator, FVector(0.0, 0.0, -ArmLength)));
        auto BobTransform = BobNode.As_Transform();
        auto ReleaseNode = utils_scene_node::Create(BobTransform, FTransform(FRotator::ZeroRotator, FVector(0.0, 0.0, -BobRadius)));
        _ReleasePoint = ReleaseNode.As_Transform();

        auto SwingSpec = FMars_Oscillator_Spec();
        SwingSpec.AmplitudeDegrees = SwingAmplitudeDegrees;
        SwingSpec.PeriodSeconds = SwingPeriodSeconds;
        SwingSpec.SettleSeconds = SwingSettleSeconds;
        SwingSpec.StartRunning = false;
        // Each Add ensures on its own rejection.
        _Swing = utils_oscillator::Add(PivotNode, SwingSpec);
        if (ck::Is_NOT_Valid(_Swing))
        { return ECk_EntityScript_ConstructionFlow::Finished; }

        // Invulnerable: hits are counted by the zone, never drained.
        _Health = utils_health::Add(InHandle, FMars_Health_Spec(100.0f, 100.0f, ECk_EnableDisable::Enable));
        if (ck::Is_NOT_Valid(_Health))
        { return ECk_EntityScript_ConstructionFlow::Finished; }

        _Zone = utils_hit_zone::Add(InHandle, FMars_HitZone_Spec(GameplayTags::HitZone_Mars_Body));
        if (ck::Is_NOT_Valid(_Zone))
        { return ECk_EntityScript_ConstructionFlow::Finished; }

        const auto HurtboxHalfExtent = BobRadius + HurtboxMargin;
        utils_hit_zone::AddHurtbox_Box(_Zone, BobTransform, FMars_HitZone_Hurtbox(FVector(HurtboxHalfExtent, HurtboxHalfExtent, HurtboxHalfExtent), FTransform::Identity));

        auto Spec = FMars_Forage_Spec();
        Spec.Yield = FMars_Forage_YieldSpec(TSoftObjectPtr<UCk_InventoryItem_Definition>(mars_items::Peppercorns()), Charges);
        Spec.Exhaustion = FMars_Forage_ExhaustionSpec(EMars_Forage_Exhaustion::Regrows, RefillSeconds);
        Spec.Launch = FMars_Forage_LaunchSpec(SpillLaunch);
        Spec.Parts = FMars_Forage_Parts(_ReleasePoint);

        _Forage = utils_forage::Add(InHandle, Spec);
        if (ck::Is_NOT_Valid(_Forage))
        { return ECk_EntityScript_ConstructionFlow::Finished; }

        // Rides the bob: its own node directly under it.
        auto KnockBody = FMars_ForageSource_KnockBody();
        KnockBody.Radius = float32(BobRadius);
        KnockBody.MotionType = ECk_MotionType::Kinematic;
        KnockBody.Presence = EMars_ForageSource_KnockPresence::Permanent;
        AddKnockBody(BobTransform, KnockBody);

        _Zone.BindTo_OnHit(FMars_Delegate_HitZone_OnHit(this, n"OnZoneHit"));
        _Forage.BindTo_OnReleased(FMars_Delegate_Forage_OnReleased(this, n"OnSpilled"));
        BindForage();

        if (WithVisuals)
        { AddVisuals(Root, PivotTransform, BobTransform); }

        return ECk_EntityScript_ConstructionFlow::Finished;
    }

    UFUNCTION(BlueprintOverride)
    void DoEndPlay(FCk_Handle InHandle)
    {
        if (ck::IsValid(_SpillBurst))
        { _SpillBurst.DestroyComponent(); }

        _SpillBurst = nullptr;
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Triggers
    //----------------------------------------------------------------------------------------------------------------------

    // Queues only: the zone arbiter is mid-broadcast.
    UFUNCTION()
    private void OnZoneHit(FCk_Handle_HitZone InZone, FMars_DamageEvent InScaledEvent, FMars_HitZone_Reaction InReaction)
    {
        _Forage.Request_Release(FMars_Request_Forage_Release(EMars_Forage_ReleaseReason::Hit));
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Forage signals
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void OnSpilled(FCk_Handle_Forage InForage, FCk_Handle InWorldItem, EMars_Forage_ReleaseReason InReason)
    {
        _Swing.Request_SetRunning(FMars_Request_Oscillator_SetRunning(EMars_Oscillator_RunState::Running));
        _SwingTimer = RestartTimer(_SwingTimer, SwingSeconds, n"OnSwingDone");
        PlaySpillBurst();
    }

    UFUNCTION()
    private void OnSwingDone(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        // A newer spill restarted the swing.
        if (_SwingTimer != InTimer)
        { return; }

        _Swing.Request_SetRunning(FMars_Request_Oscillator_SetRunning(EMars_Oscillator_RunState::Stopped));
    }

    // One-shot: a previous timer is destroyed so only the newest one fires.
    private FCk_Handle_Timer RestartTimer(FCk_Handle_Timer InPrevious, float32 InSeconds, FName InHandler)
    {
        if (ck::IsValid(InPrevious))
        { utils_entity_lifetime::Request_DestroyEntity(InPrevious); }

        auto TimerSpec = FCk_Timer_Spec(FCk_Time(InSeconds));
        TimerSpec.Set_StartingState(ECk_Timer_State::Running)
                 .Set_Behavior(ECk_Timer_Behavior::StopOnDone);

        auto Timer = utils_timer::Add(_Forage, TimerSpec);
        if (ck::IsValid(Timer))
        { Timer.BindTo_OnDone(FCk_Delegate_Timer(this, InHandler)); }

        return Timer;
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Visuals
    //----------------------------------------------------------------------------------------------------------------------

    // One reused burst component: spawned at the first spill whose template is ready (a cold template never stalls the
    // game thread; the spill just goes without a puff), then moved and re-activated per spill. Null under nullrhi.
    private void PlaySpillBurst()
    {
        const auto ReleaseWorld = utils_transform::Get_EntityCurrentTransform(_ReleasePoint);

        if (ck::IsValid(_SpillBurst))
        {
            _SpillBurst.SetWorldLocation(ReleaseWorld.GetLocation());
            _SpillBurst.Activate(true);
            return;
        }

        if (utils_particles::Get_IsBehaviorTemplateReady(k_SpillBurstBehavior) == false)
        { return; }

        _SpillBurst = utils_particles::Spawn_BehaviorAtLocation(k_SpillBurstBehavior, ReleaseWorld.GetLocation(), ReleaseWorld.Rotator());
        if (ck::IsValid(_SpillBurst))
        { utils_particles::Request_ApplyTuningValues(_SpillBurst, k_SpillBurstSize, k_SpillBurstColor, 1.0f, 1.0f); }
    }

    // Engine cube and sphere are 100 uu with their pivot at the centre. The pivot block and the basin walls are solid (a
    // collision-bearing mesh part bakes into the Jolt static world), so a spilled handful lands inside the ring.
    private void AddVisuals(FCk_Handle_Transform& InRoot, FCk_Handle_Transform& InPivot, FCk_Handle_Transform& InBob)
    {
        auto CubeMesh = engine::load::Cube();
        auto SphereMesh = engine::load::Sphere();
        auto InteractableMaterial = assets::load::ProtoGrid_Interactable_Mars_MI();
        auto Presentation = Anchor.ForagePresentation.Get();
        UMaterialInterface StoneMaterial = assets::load::ProtoGrid_Wall_Mars_MI();
        UMaterialInterface BasinMaterial = nullptr;
        auto ChainMesh = CubeMesh;
        auto BobMesh = SphereMesh;
        auto ContentsMesh = SphereMesh;
        UMaterialInterface ChainMaterial = InteractableMaterial;
        UMaterialInterface BobMaterial = InteractableMaterial;
        UMaterialInterface ContentsMaterial = assets::load::ProtoGrid_Item_Mars_MI();
        float64 ChainLength = ArmLength;

        if (ck::IsValid(Presentation))
        {
            if (ck::IsValid(Presentation.StoneMaterial))
            {
                StoneMaterial = Presentation.StoneMaterial;
                BasinMaterial = Presentation.StoneMaterial;
            }

            // A missing optional mesh keeps the original cube, material AND full-length transform.
            if (ck::IsValid(Presentation.Censer.ChainMesh) && ArmLength > BobRadius)
            {
                ChainMesh = Presentation.Censer.ChainMesh;
                ChainMaterial = nullptr;
                ChainLength = ArmLength - BobRadius;
            }
            if (ck::IsValid(Presentation.Censer.BobMesh))
            {
                BobMesh = Presentation.Censer.BobMesh;
                BobMaterial = nullptr;
            }
            if (ck::IsValid(Presentation.Censer.ContentsMesh))
            {
                ContentsMesh = Presentation.Censer.ContentsMesh;
                ContentsMaterial = nullptr;
            }
        }

        const auto PivotHeight = ArmLength + PivotClearance + BobRadius;
        InRoot.Add_MeshPart(this, FMars_MeshPart(
            FTransform(FRotator::ZeroRotator, FVector(0.0, 0.0, PivotHeight), FVector(40.0, 40.0, 30.0) * 0.01),
            CubeMesh, StoneMaterial, collision::profile::BlockAll, n"ForageCenser_PivotBlock"));

        if (ck::IsValid(Presentation) && ck::IsValid(Presentation.TimberPostMaterial))
        {
            const auto SupportBottom = PivotHeight + 15.0;
            const auto SupportHeight = Presentation.Censer.CeilingHeightCm - SupportBottom;
            if (SupportHeight > 0.0)
            {
                InRoot.Add_MeshPart(this, FMars_MeshPart(
                    FTransform(FRotator::ZeroRotator, FVector(0.0, 0.0, SupportBottom + SupportHeight * 0.5), FVector(8.0, 8.0, SupportHeight) * 0.01),
                    CubeMesh, Presentation.TimberPostMaterial, collision::profile::NoCollision, n"ForageCenser_CeilingSupport"));
            }
        }

        InPivot.Add_MeshPart(this, FMars_MeshPart(
            FTransform(FRotator::ZeroRotator, FVector(0.0, 0.0, -ChainLength * 0.5), FVector(ChainWidth, ChainWidth, ChainLength) * 0.01),
            ChainMesh, ChainMaterial, collision::profile::NoCollision, n"ForageCenser_Chain"));

        InBob.Add_MeshPart(this, FMars_MeshPart(
            FTransform(FRotator::ZeroRotator, FVector::ZeroVector, FVector::OneVector * (BobRadius * 2.0 * 0.01)),
            BobMesh, BobMaterial, collision::profile::NoCollision, n"ForageCenser_Bob"));

        _YieldMesh = InBob.Add_MeshPart(this, FMars_MeshPart(
            FTransform(FRotator::ZeroRotator, FVector(0.0, 0.0, BobRadius + ClusterLift), FVector::OneVector * ClusterScale),
            ContentsMesh, ContentsMaterial, collision::profile::NoCollision, n"ForageCenser_Cluster"));

        InRoot.Add_ForageBasinRing(this, FMars_ForageBasin_Spec(BasinHalfWidth), BasinMaterial);
    }
}
