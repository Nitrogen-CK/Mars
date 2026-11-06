// The cellar bat review room presets (/Game/ArtCandidates/CellarBat/R01/Review/CellarBat_R01_Review_MAP, built by
// Mars.CellarBat.BuildReviewMap in Script/Editor/Mars_CellarBat_MapBuilder.as). Not under Script/Editor: the saved map
// references them at runtime. The room is 2000 x 2000 x 600 round the origin, floor top at Z 0; the perch beam runs along
// X at (-600, 0), its underside at Z 530; a pillar stands at the centre; the target dummy at (600, 0). The room runs itself
// in PIE: the dummy walks a loop that pauses behind the pillar (line-of-sight refusal, the orbit fallback) and drops into a
// pit (a loss the bat searches for), and it swats the bat back every few landings (the hit-and-run retreat).
namespace utils_bat
{
    const FVector ReviewPerchAnchor = FVector(-600.0, 0.0, 530.0);
    const FVector ReviewVolumeCentre = FVector(0.0, 0.0, 300.0);
    const FVector ReviewVolumeHalfExtents = FVector(970.0, 970.0, 290.0);

    // The AnimBP's fallback on the final mesh: its Hover loop.
    const FString ReviewFallbackLoopPath = "/Game/ArtCandidates/CellarBat/R01/Animation/CellarBat_R01_Hover_Mars_ANIM.CellarBat_R01_Hover_Mars_ANIM";
}

// The review bat: placed at the hang point (ReviewPerchAnchor + HangOffset), it claims the roost under the beam, patrols the
// four corners of the room after hanging RoostIdleSeconds, and swoops at the dummy when it comes within AcquireRadius
// (the dummy is always in range of the perch, so in practice it goes for the dummy first). It flies on team Three, so the
// team-Two dummy and the team-One player are both Hostile. The spec is set in DoConstruct, not as subclass defaults: the
// spawn-params generator emits a non-default struct default as a positional constructor call.
class UMars_CellarBatReview_Bat_EntityScript : UMars_CellarBat_EntityScript
{
    default _ShowInPlaceActors = true;

    UFUNCTION(BlueprintOverride)
    ECk_EntityScript_ConstructionFlow DoConstruct(FCk_Handle& InHandle)
    {
        Spec.Monster.Team = ECk_Team_ID::Three;
        Spec.Roost.DiscoverRadius = 150.0f;
        Spec.Timing.RoostIdleSeconds = 6.0f;
        // The dummy's base is on the floor: aim at its chest.
        Spec.Swoop.AimHeight = 80.0f;
        // Just over the roost-to-dummy distance (1256), so the dummy at its post wakes the bat; LoseRadius equal to it so the
        // pit (HideDepth under the floor) and the far corner (Review_MoveTo) are losses inside the room that stay within
        // HomeRadius: last-known places for the search.
        Spec.Sensing.AcquireRadius = 1300.0f;
        Spec.Sensing.LoseRadius = 1300.0f;
        Spec.FlightNodes.Empty();
        Spec.FlightNodes.Add(FVector(-450.0, -650.0, 380.0));
        Spec.FlightNodes.Add(FVector(450.0, -650.0, 320.0));
        Spec.FlightNodes.Add(FVector(450.0, 650.0, 320.0));
        Spec.FlightNodes.Add(FVector(-450.0, 650.0, 380.0));

        // The final mesh under the final AnimBP (built by Tools/LevelDesign/cellar_bat_r01_review/cellar_bat_animbp_ue.py from
        // cellar_bat_animbp_manifest_final.json); the looping Hover is the fallback when the AnimBP does not load.
        Mesh = TSoftObjectPtr<USkeletalMesh>(FSoftObjectPath(utils_bat::CandidateMeshPath));
        AnimClass = TSoftClassPtr<UAnimInstance>(FSoftObjectPath(utils_bat::CandidateAnimClassPath));
        LoopClip = TSoftObjectPtr<UAnimSequence>(FSoftObjectPath(utils_bat::ReviewFallbackLoopPath));
        LogPhases = true;
        const auto Flow = Super::DoConstruct(InHandle);

        auto Bat = Get_Bat();
        if (CounterBlowEveryNthLanding > 0 && ck::IsValid(Bat))
        { Bat.BindTo_OnSwoopLanded(FMars_Delegate_Bat_OnSwoopLanded(this, n"OnReviewSwoopLanded")); }

        return Flow;
    }

    // The dummy swats back: every CounterBlowEveryNthLanding-th landed swoop, CounterBlowSeconds later (the bat is pulling
    // out), a blow of CounterBlowDamage through the bat's body zone, so the room shows the hit-and-run retreat on its own.
    // 0 = never.
    UPROPERTY(ExposeOnSpawn)
    int32 CounterBlowEveryNthLanding = 3;

    UPROPERTY(ExposeOnSpawn)
    float32 CounterBlowDamage = 5.0f;

    private const float32 CounterBlowSeconds = 0.5f;
    private int32 _Landings = 0;

    UFUNCTION()
    private void OnReviewSwoopLanded(FCk_Handle_Bat InBat, int32 InGeneration, FCk_Handle_HitZone InZone)
    {
        _Landings += 1;
        if (_Landings % CounterBlowEveryNthLanding != 0)
        { return; }

        FCk_Handle Self = InBat;
        auto TimerSpec = FCk_Timer_Spec(FCk_Time(CounterBlowSeconds));
        TimerSpec.Set_StartingState(ECk_Timer_State::Running)
                 .Set_Behavior(ECk_Timer_Behavior::StopOnDone);
        auto Timer = utils_timer::Add(Self, TimerSpec);
        if (ck::IsValid(Timer))
        { Timer.BindTo_OnDone(FCk_Delegate_Timer(this, n"OnCounterBlowDue")); }
    }

    UFUNCTION()
    private void OnCounterBlowDue(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Log(f"[CellarBat] dummy swats back after landing #{_Landings}");
        Review_Damage(CounterBlowDamage);
    }

    // Review hooks, called from editor Python on the PIE instance (Tools/LevelDesign/cellar_bat_r01_review): a lethal
    // blow on the body health (the same request the death test sends), and a one-line state readout.
    UFUNCTION()
    void Review_Kill()
    {
        auto Bat = Get_Bat();
        if (ck::Is_NOT_Valid(Bat))
        { return; }

        auto Health = Bat.Get_Monster().Get_BodyHealth();
        Log(f"[CellarBat] review kill in {Bat.Get_Phase()} at {Bat.Get_Location().ToString()}");
        Health.Request_ApplyDamage(FMars_Request_Health_ApplyDamage(FMars_DamageEvent(100000.0f, GameplayTags::DamageType_Mars_Blunt)));
    }

    // A blow of InAmount through the body zone (the route a weapon takes): under Spec.Timing.StunDamage it flinches (Hit), at
    // or over it stuns.
    UFUNCTION()
    void Review_Damage(float32 InAmount)
    {
        auto Bat = Get_Bat();
        if (ck::Is_NOT_Valid(Bat))
        { return; }

        auto Zone = Bat.Get_Monster().Get_BodyZone();
        Log(f"[CellarBat] review damage {InAmount} in {Bat.Get_Phase()} at {Bat.Get_Location().ToString()}");
        Zone.Request_Hit(FMars_Request_HitZone_Hit(FMars_DamageEvent(InAmount, GameplayTags::DamageType_Mars_Blunt)));
    }

    UFUNCTION()
    FString Review_Describe() const
    {
        auto Bat = Get_Bat();
        FCk_Handle Entity = Bat;
        if (ck::Is_NOT_Valid(Entity))
        { return "invalid"; }

        const auto State = Bat.Get_Fragment(FMars_Fragment_Bat);
        const auto Here = Bat.Get_Location();
        return f"phase={Bat.Get_Phase()} loc=({Here.X :.0},{Here.Y :.0},{Here.Z :.0}) dead={Bat.Get_IsDead()} swoop={Bat.Get_SwoopStage()} gen={State.Swoop.Generation} landed={State.Swoop.Landed} cancelled={State.Swoop.Cancelled} route={State.Route.Generation}:{State.Route.Outcome} claim={Bat.Get_RoostClaim()}" + Describe_Swoop(Bat);
    }

    // Where the bat's root is now (the review's chase camera follows it); the origin once it is gone.
    UFUNCTION()
    FVector Review_Location() const
    {
        auto Bat = Get_Bat();
        FCk_Handle Entity = Bat;
        if (ck::Is_NOT_Valid(Entity))
        { return FVector::ZeroVector; }

        return Bat.Get_Location();
    }

    // Free-space readout of the bat's flight volume at InPoint (review diagnosis only).
    UFUNCTION()
    bool Review_IsPointFree(FVector InPoint) const
    {
        auto Bat = Get_Bat();
        FCk_Handle Entity = Bat;
        if (ck::Is_NOT_Valid(Entity) || ck::Is_NOT_Valid(Bat.Get_Volume()))
        { return false; }

        return utils_voxel_nav_volume::Get_IsPointFree(Bat.Get_Volume(), InPoint);
    }

    private FString Describe_Swoop(const FCk_Handle_Bat& InBat) const
    {
        if (InBat.Get_HasTarget() == false)
        { return " target=none"; }

        const auto Aim = InBat.Get_TargetAimPoint();
        const auto Strike = InBat.Get_StrikePoint();
        const auto Volume = InBat.Get_Volume();
        const auto AimFree = ck::IsValid(Volume) && utils_voxel_nav_volume::Get_IsPointFree(Volume, Aim);
        return f" target=yes admission={InBat.Get_SwoopAdmission(InBat.Get_Target())} toStrike={(Strike - InBat.Get_Location()).Size() :.0} toAim={(Aim - InBat.Get_Location()).Size() :.0} aim=({Aim.X :.0},{Aim.Y :.0},{Aim.Z :.0}) aimFree={AimFree}";
    }
}

// One stop of the review dummy's walk: Offset from its spawn point (world axes, ground level); it holds there PauseSeconds,
// and with HideSeconds set it drops HideDepth under the floor for that long first (the pit).
struct FMars_CellarBatReview_WalkNode
{
    UPROPERTY()
    FVector Offset;

    UPROPERTY()
    float32 PauseSeconds = 0.0f;

    UPROPERTY()
    float32 HideSeconds = 0.0f;

    FMars_CellarBatReview_WalkNode() {}

    FMars_CellarBatReview_WalkNode(FVector InOffset, float32 InPauseSeconds, float32 InHideSeconds)
    {
        Offset = InOffset;
        PauseSeconds = InPauseSeconds;
        HideSeconds = InHideSeconds;
    }
}

// The walk the review dummy repeats at Speed (cm/s). Nodes empty: it stands at its post (the default route is filled in by
// the dummy when WalksByDefault).
struct FMars_CellarBatReview_Walk
{
    UPROPERTY()
    TArray<FMars_CellarBatReview_WalkNode> Nodes;

    UPROPERTY()
    float32 Speed = 160.0f;

    // Deep enough that the hidden dummy is past the bat's LoseRadius from where it circles, shallow enough to stay within
    // HomeRadius of the perch (a searchable loss).
    UPROPERTY()
    float32 HideDepth = 1200.0f;
}

enum EMars_CellarBatReview_WalkStage
{
    Walking,
    Paused,
    Hidden
}

// The review dummy: a post the size of the room 5 target dummy (60 x 60 x 120, origin at its base) on team Two, a combat
// target (TAG_MarsCombatTarget) with a Health, one Body zone and one hurtbox over the post. Unlike UMars_TargetDummy_EntityScript
// its post draws without collision: a BlockAll post reaches the Jolt static world (LiveExtract takes runtime components),
// the voxel bake carves it out of the flight volume with the bat's clearance, and the bat's swoop admission then refuses
// every aim point on it (seen in PIE 2026-11-05: (600,0,80..170) not free, (600,0,200) free). Every OnDamaged is counted
// and logged for the review; it never flattens (MaxHealth is high).
class UMars_CellarBatReview_TargetDummy_EntityScript : UCk_GenericEntityScript_UE
{
    default _ShowInPlaceActors = true;
    default _Replication = ECk_Replication::DoesNotReplicate;

    UPROPERTY(ExposeOnSpawn)
    FTransform SpawnTransform = FTransform::Identity;

    UPROPERTY(ExposeOnSpawn)
    float32 MaxHealth = 100000.0f;

    // Its walk (see FMars_CellarBatReview_Walk). Default route, from the post at (600, 0): south along the east wall, west
    // to the pit at (0, -700) and 8 s under the floor, up to the cover spot (160, 0) right behind the pillar for 5 s, out
    // to (600, 500), back to the post: a moving target (the lead), a loss to search for, a target behind cover (the
    // line-of-sight refusal and the orbit fallback), about 50 s a lap.
    UPROPERTY(ExposeOnSpawn)
    FMars_CellarBatReview_Walk Walk;

    UPROPERTY(ExposeOnSpawn)
    bool WalksByDefault = true;

    private const float64 PostWidth = 60.0;
    private const float64 PostHeight = 120.0;
    private const float64 HurtboxMargin = 5.0;

    private int32 _Damaged = 0;
    private FCk_Handle_Transform _Root;
    private EMars_CellarBatReview_WalkStage _Stage = EMars_CellarBatReview_WalkStage::Walking;
    private int32 _NextNode = 0;
    private float32 _StageLeft = 0.0f;

    UFUNCTION(BlueprintOverride)
    ECk_EntityScript_ConstructionFlow DoConstruct(FCk_Handle& InHandle)
    {
        auto Root = utils_transform::Add(InHandle, SpawnTransform, ECk_Replication::DoesNotReplicate);
        _Root = Root;
        if (Walk.Nodes.Num() == 0 && WalksByDefault)
        { Walk.Nodes = Make_DefaultRoute(); }

        if (Walk.Nodes.Num() > 0)
        {
            BuildPitMarkers(InHandle);
            utils_timer::Create_Tick(InHandle, FCk_Delegate_Timer(this, n"OnWalkTick"));
        }

        utils_team::Add(InHandle, ECk_Team_ID::Two, ECk_Replication::DoesNotReplicate);
        utils_entity_tag::Add(InHandle, n"TAG_MarsCombatTarget");

        auto Health = utils_health::Add(InHandle, FMars_Health_Spec(MaxHealth));
        if (ck::Is_NOT_Valid(Health))
        { return ECk_EntityScript_ConstructionFlow::Finished; }

        auto Zone = utils_hit_zone::Add(InHandle, utils_hit_zone::Make_FleshZoneSpec(GameplayTags::HitZone_Mars_Body, 1.5f));
        if (ck::Is_NOT_Valid(Zone))
        { return ECk_EntityScript_ConstructionFlow::Finished; }

        const auto PostCentre = FTransform(FRotator::ZeroRotator, FVector(0.0, 0.0, PostHeight * 0.5));
        const auto HalfExtents = FVector(PostWidth * 0.5, PostWidth * 0.5, PostHeight * 0.5) + FVector(HurtboxMargin, HurtboxMargin, HurtboxMargin);
        utils_hit_zone::AddHurtbox_Box(Zone, Root, FMars_HitZone_Hurtbox(HalfExtents, PostCentre));

        if (FApp::CanEverRender())
        {
            Root.Add_MeshPart(this, FMars_MeshPart(
                FTransform(FRotator::ZeroRotator, PostCentre.GetLocation(), FVector(PostWidth, PostWidth, PostHeight) * 0.01),
                engine::load::Cube(), assets::load::ProtoGrid_Interactable_Mars_MI(), collision::profile::NoCollision, n"CellarBatReviewDummy_Post"));
        }

        Health.BindTo_OnDamaged(FMars_Delegate_Health_OnDamaged(this, n"OnReviewDamaged"));
        return ECk_EntityScript_ConstructionFlow::Finished;
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Walk
    //----------------------------------------------------------------------------------------------------------------------

    private TArray<FMars_CellarBatReview_WalkNode> Make_DefaultRoute() const
    {
        auto Route = TArray<FMars_CellarBatReview_WalkNode>();
        Route.Add(FMars_CellarBatReview_WalkNode(FVector(0.0, -600.0, 0.0), 0.0f, 0.0f));
        Route.Add(FMars_CellarBatReview_WalkNode(FVector(-600.0, -700.0, 0.0), 0.0f, 8.0f));
        Route.Add(FMars_CellarBatReview_WalkNode(FVector(-440.0, 0.0, 0.0), 5.0f, 0.0f));
        Route.Add(FMars_CellarBatReview_WalkNode(FVector(0.0, 500.0, 0.0), 0.0f, 0.0f));
        Route.Add(FMars_CellarBatReview_WalkNode(FVector::ZeroVector, 0.0f, 0.0f));
        return Route;
    }

    private FVector Get_NodeLocation(int32 InNode) const
    {
        return SpawnTransform.GetLocation() + Walk.Nodes[Math::Clamp(InNode, 0, Walk.Nodes.Num() - 1)].Offset;
    }

    // A dark plate on the floor at every pit node, so the drop reads as a hole: its own entity, since the post moves.
    private void BuildPitMarkers(FCk_Handle& InHandle)
    {
        if (FApp::CanEverRender() == false)
        { return; }

        for (int32 Index = 0; Index < Walk.Nodes.Num(); ++Index)
        {
            if (Walk.Nodes[Index].HideSeconds <= 0.0f)
            { continue; }

            auto Pit = utils_entity_lifetime::Request_CreateEntity(InHandle);
            auto PitRoot = utils_transform::Add(Pit, FTransform(FRotator::ZeroRotator, Get_NodeLocation(Index)), ECk_Replication::DoesNotReplicate);
            auto Plate = FMars_MeshPart(FTransform(FRotator::ZeroRotator, FVector(0.0, 0.0, 1.5), FVector(1.4, 1.4, 0.03)),
                engine::load::Cube(), assets::load::ProtoGrid_Interactable_Mars_MI(), collision::profile::NoCollision, n"CellarBatReviewDummy_Pit");
            Plate.PrimaryColor = FLinearColor(0.02f, 0.02f, 0.025f, 1.0f);
            Plate.Tint = EMars_MeshPart_Tint::ProtoGrid;
            PitRoot.Add_MeshPart(this, Plate);
        }
    }

    UFUNCTION()
    private void OnWalkTick(FCk_Handle_Timer InHandle, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        if (ck::Is_NOT_Valid(_Root) || Walk.Nodes.Num() == 0)
        { return; }

        const auto Dt = float32(InDeltaT.Get_Seconds());
        if (_Stage != EMars_CellarBatReview_WalkStage::Walking)
        {
            _StageLeft -= Dt;
            if (_StageLeft > 0.0f)
            { return; }

            if (_Stage == EMars_CellarBatReview_WalkStage::Hidden)
            {
                Log(f"[CellarBat] dummy climbs out of the pit at {Get_NodeLocation(_NextNode).ToString()}");
                utils_transform::Request_SetLocation(_Root, FCk_Request_Transform_SetLocation(Get_NodeLocation(_NextNode)));
            }

            _Stage = EMars_CellarBatReview_WalkStage::Walking;
            _NextNode = (_NextNode + 1) % Walk.Nodes.Num();
            return;
        }

        const auto Node = Walk.Nodes[_NextNode];
        const auto Target = Get_NodeLocation(_NextNode);
        const auto Here = utils_transform::Get_EntityCurrentLocation(_Root);
        const auto Delta = Target - Here;
        const auto Distance = Delta.Size();
        const auto Step = float64(Walk.Speed * Dt);
        if (Distance > Step)
        {
            utils_transform::Request_SetLocation(_Root, FCk_Request_Transform_SetLocation(Here + Delta / Distance * Step));
            return;
        }

        if (Node.HideSeconds > 0.0f)
        {
            Log(f"[CellarBat] dummy drops into the pit at {Target.ToString()} for {Node.HideSeconds} s");
            utils_transform::Request_SetLocation(_Root, FCk_Request_Transform_SetLocation(Target - FVector(0.0, 0.0, Walk.HideDepth)));
            _Stage = EMars_CellarBatReview_WalkStage::Hidden;
            _StageLeft = Node.HideSeconds;
            return;
        }

        utils_transform::Request_SetLocation(_Root, FCk_Request_Transform_SetLocation(Target));
        if (Node.PauseSeconds > 0.0f)
        {
            Log(f"[CellarBat] dummy holds at {Target.ToString()} for {Node.PauseSeconds} s");
            _Stage = EMars_CellarBatReview_WalkStage::Paused;
            _StageLeft = Node.PauseSeconds;
            return;
        }

        _NextNode = (_NextNode + 1) % Walk.Nodes.Num();
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Review hooks
    //----------------------------------------------------------------------------------------------------------------------

    // Takes the dummy out of the bat's senses (drops it RetireDrop under the floor, past the bat's LoseRadius), so the review
    // sees the bat give up, return and perch.
    UFUNCTION()
    void Review_Retire()
    {
        if (ck::Is_NOT_Valid(_Root))
        { return; }

        const auto Here = utils_transform::Get_EntityCurrentLocation(_Root);
        Log(f"[CellarBat] dummy retired from {Here.ToString()}");
        utils_transform::Request_SetLocation(_Root, FCk_Request_Transform_SetLocation(Here - FVector(0.0, 0.0, RetireDrop)));
    }

    private const float64 RetireDrop = 5000.0;

    // Puts the dummy somewhere else in the room (its base at InLocation): a hop past the bat's LoseRadius that stays within
    // its HomeRadius leaves a last-known place for the bat to search.
    UFUNCTION()
    void Review_MoveTo(FVector InLocation)
    {
        if (ck::Is_NOT_Valid(_Root))
        { return; }

        Log(f"[CellarBat] dummy moved to {InLocation.ToString()}");
        utils_transform::Request_SetLocation(_Root, FCk_Request_Transform_SetLocation(InLocation));
    }

    // Review_MoveTo now, then Review_Retire InDelaySeconds later (a timer on the dummy): the bat senses the loss where the
    // dummy went (a searchable last-known place) and finds nothing there, which the two calls from separate probes cannot
    // stage (the next sense, 0.2 s on, finds the dummy again when the corner is within AcquireRadius).
    UFUNCTION()
    void Review_MoveThenRetire(FVector InLocation, float32 InDelaySeconds)
    {
        Review_MoveTo(InLocation);
        FCk_Handle Self = _Root;
        auto TimerSpec = FCk_Timer_Spec(FCk_Time(Math::Max(InDelaySeconds, 0.0f)));
        TimerSpec.Set_StartingState(ECk_Timer_State::Running)
                 .Set_Behavior(ECk_Timer_Behavior::StopOnDone);
        auto Timer = utils_timer::Add(Self, TimerSpec);
        if (ck::IsValid(Timer))
        { Timer.BindTo_OnDone(FCk_Delegate_Timer(this, n"OnRetireDelayDone")); }
    }

    UFUNCTION()
    private void OnRetireDelayDone(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Review_Retire();
    }

    // How many OnDamaged the dummy has broadcast (the review counts one per landed swoop).
    UFUNCTION()
    int32 Review_DamagedCount() const
    {
        return _Damaged;
    }

    UFUNCTION()
    private void OnReviewDamaged(FCk_Handle_Health InHealth, FMars_DamageEvent InEvent, float32 InApplied, float32 InRemaining)
    {
        _Damaged += 1;
        Log(f"[CellarBat] dummy damaged #{_Damaged}: {InApplied} applied, {InRemaining} left");
    }
}

// The review room's flight space: the whole room inside the walls, floor to ceiling. Placed at ReviewVolumeCentre.
class UMars_CellarBatReview_FlightVolume_EntityScript : UMars_BatFlightVolume_EntityScript
{
    default _ShowInPlaceActors = true;
    default HalfExtents = FVector(970.0, 970.0, 290.0);
}
