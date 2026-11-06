// The cellar bat review room presets (/Game/ArtCandidates/CellarBat/R01/Review/CellarBat_R01_Review_MAP, built by
// Mars.CellarBat.BuildReviewMap in Script/Editor/Mars_CellarBat_MapBuilder.as). Not under Script/Editor: the saved map
// references them at runtime. The room is 2000 x 2000 x 600 round the origin, floor top at Z 0; the perch beam runs along
// X at (-600, 0), its underside at Z 530; a pillar stands at the centre; the target dummy at (600, 0).
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
        Spec.Sensing.AcquireRadius = 1600.0f;
        // Equal to AcquireRadius so a dummy moved to the far corner (Review_MoveTo) drops out of sense inside the room and
        // leaves a last-known place for the search.
        Spec.Sensing.LoseRadius = 1600.0f;
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
        return Super::DoConstruct(InHandle);
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

    private const float64 PostWidth = 60.0;
    private const float64 PostHeight = 120.0;
    private const float64 HurtboxMargin = 5.0;

    private int32 _Damaged = 0;
    private FCk_Handle_Transform _Root;

    UFUNCTION(BlueprintOverride)
    ECk_EntityScript_ConstructionFlow DoConstruct(FCk_Handle& InHandle)
    {
        auto Root = utils_transform::Add(InHandle, SpawnTransform, ECk_Replication::DoesNotReplicate);
        _Root = Root;
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
