namespace utils_crawler
{
    // The crawler's motion profile: it rides the plane through its planted feet at its layout's clearance, slides along
    // faces it cannot step onto and steps up to about 1.3 clearances; its probe reach and top speed grow with its size.
    FCk_SurfaceMotion_Spec Make_MotionSpec(EMars_Crawler_Layout InLayout)
    {
        const auto Clearance = Get_LayoutClearance(InLayout);
        const auto Size = Get_LayoutSizeScale(InLayout);
        auto Contact = FCk_SurfaceMotion_Contact();
        Contact.Set_Clearance(Clearance);
        Contact.Set_ProbeReach(180.0f * Size);
        Contact.Set_HeightSource(ECk_SurfaceMotion_HeightSource::PlantedFeet);
        Contact.Set_WallPolicy(ECk_SurfaceMotion_WallPolicy::Slide);
        Contact.Set_MaxStepHeight(InLayout == EMars_Crawler_Layout::Radial ? 85.0f : Clearance * 1.3f);

        auto Movement = FCk_SurfaceMotion_Movement();
        Movement.Set_MaxSpeed(180.0f * Size);
        Movement.Set_SurfaceTurnRate(180.0f);

        auto Spec = FCk_SurfaceMotion_Spec();
        Spec.Set_Contact(Contact);
        Spec.Set_Movement(Movement);
        return Spec;
    }

    // The navigator's defaults, its speed and distances grown with the layout's size (the same body lengths a second).
    FMars_SurfaceNavigator_Spec Make_NavigatorSpec(EMars_Crawler_Layout InLayout)
    {
        const auto Size = Get_LayoutSizeScale(InLayout);
        const auto Defaults = FMars_SurfaceNavigator_Spec();
        return FMars_SurfaceNavigator_Spec(Defaults.Speed * Size, Defaults.AcceptanceRadius * Size, Defaults.StuckSeconds,
            Defaults.StuckDistance * Size, Defaults.AgentRadius * Size);
    }

    // A leg part: crushing ruins a leg faster than the body; depletion detaches the leg.
    FMars_BodyPart_Spec Make_LegPartSpec(FMars_Crawler_Vitals InVitals)
    {
        const auto Zone = utils_hit_zone::Make_FleshZoneSpec(GameplayTags::HitZone_Mars_Limb, 1.5f);
        const auto Severance = FMars_BodyPart_Severance(EMars_BodyPart_DepletionPolicy::DetachLeg, InVitals.SpillToBody, 0.5f, InVitals.LegDebris);
        return FMars_BodyPart_Spec(GameplayTags::BodyPart_Mars_Crawler_Leg, EMars_BodyPart_Function::Movement,
            FMars_Health_Spec(InVitals.LegHealth), Zone, Severance);
    }

    // The crawler monster, on team Two. Damage types the body zone does not name (Blunt) land at x1 with no condition
    // impact.
    FMars_Monster_Spec Make_MonsterSpec(FMars_Crawler_Vitals InVitals)
    {
        const auto Zone = utils_hit_zone::Make_FleshZoneSpec(GameplayTags::HitZone_Mars_Body, 1.0f);
        return FMars_Monster_Spec(GameplayTags::Monster_Mars_Crawler, FMars_Health_Spec(InVitals.BodyHealth),
            Zone, InVitals.CorpseSeconds, ECk_Team_ID::Two);
    }

    // The rig chain for one leg: its segments and foot, the Auto solver, the knee swivelled clear of solids, and, on a
    // layout that keeps them (Get_LayoutSiblingCapsules), one sibling-capsule radius per segment from its box cross section.
    FCk_ProceduralWalker_LegChain Make_LegChain(FMars_Crawler_LegRig InLeg, EMars_Crawler_Layout InLayout)
    {
        auto Radii = TArray<float32>();
        for (int32 Index = 0; Index < InLeg.Segments.Num() && Get_LayoutSiblingCapsules(InLayout); ++Index)
        {
            const auto HalfExtents = InLeg.SegmentHalfExtents[Index];
            Radii.Add(float32(Math::Sqrt(HalfExtents.Y * HalfExtents.Y + HalfExtents.Z * HalfExtents.Z)));
        }

        auto RigSpec = FCk_ProceduralRig_Spec();
        RigSpec.Set_Segments(InLeg.Segments);
        RigSpec.Set_Foot(InLeg.Foot);
        RigSpec.Set_Solver(ECk_ProceduralRig_ChainSolver::Auto);
        RigSpec.Set_Clearance(ECk_ProceduralRig_Clearance::Swivel);
        RigSpec.Set_SegmentClearanceRadii(Radii);
        return FCk_ProceduralWalker_LegChain(InLeg.LegId, RigSpec);
    }

    // The attack player's tuning, the one every clip action plays with. Sampling: the body jab keeps
    // its game-owned travel guard (no accepted sample moves it further than MaxSampleTravel); a pincer's claws travel the
    // chain's reach, so with a pincer clip the guard is raised to twice the front leg's reach (a hitch can pose a whole
    // phase in one sample). Transition: no entry blend (the windup starts at admission, from the identity offset and the claws'
    // own feet), CancelSeconds as the dedicated return a cancel eases back through, and a return timeout no shorter than
    // that return, nor than the time the gait gets to step a released claw back down.
    FCk_ProceduralAction_Tuning Make_AttackTuning(const FMars_Crawler_Spec& InSpec)
    {
        const auto& Combat = InSpec.Combat;
        auto Tuning = FCk_ProceduralAction_Tuning();

        auto Sampling = Tuning.Get_Sampling();
        Sampling.Set_MaxEndpointTravelCm(Combat.Hit.MaxSampleTravel);
        Sampling.Set_MaxSegmentAngularStepDegrees(180.0f);
        if (Combat.Get_HasPincer())
        {
            const TArray<FCk_ProceduralLeg_Spec> Legs = InSpec.Get_RigData().Get_Legs();
            Sampling.Set_MaxEndpointTravelCm(Math::Max(Combat.Hit.MaxSampleTravel, 2.0f * Get_ChainReach(Legs[0])));
        }
        Tuning.Set_Sampling(Sampling);

        auto Transition = Tuning.Get_Transition();
        const auto CancelReturn = float64(Combat.Timing.CancelSeconds);
        Transition.Set_EntryBlend(FCk_Time(0.0));
        Transition.Set_DedicatedReturn(FCk_Time(CancelReturn));
        auto ReturnTimeout = Math::Max(Transition.Get_ReturnTimeout().Get_Seconds(), CancelReturn);
        if (Combat.Get_HasPincer())
        { ReturnTimeout = Math::Max(ReturnTimeout, float64(PincerReturnTimeoutSeconds)); }
        Transition.Set_ReturnTimeout(FCk_Time(ReturnTimeout));
        Tuning.Set_Transition(Transition);
        return Tuning;
    }

    // A crawler without a pincer clip plays its jab on the body alone and lends no leg (the default locomotion's support is
    // Disabled). A pincer also borrows the two front legs from the gait, on Make_PincerLocomotion's terms.
    FCk_ProceduralActionPlayer_Spec Make_AttackPlayerSpec(const FMars_Crawler_Spec& InSpec)
    {
        auto Spec = FCk_ProceduralActionPlayer_Spec();
        Spec.Set_Tuning(Make_AttackTuning(InSpec));
        if (InSpec.Combat.Get_HasPincer())
        { Spec.Set_Locomotion(Make_PincerLocomotion(InSpec)); }
        return Spec;
    }

    // How a pincer borrows the front legs (the borrowing player's terms; a walking preview of the clip copies them): the
    // player counts the legs left standing and lets them wait out the whole pincer clip and a cancel's return before a
    // step the count forbids interrupts it, and hands a claw back to the gait as a real step from wherever the action left
    // it (the windup key, when a cancel lands in the air) to where the gait wants the foot, within the attack tuning's
    // sampling budget and PincerReturnTimeoutSeconds. Needs a loaded pincer clip.
    FCk_ProceduralLimbControl_Locomotion Make_PincerLocomotion(const FMars_Crawler_Spec& InSpec)
    {
        const auto& Combat = InSpec.Combat;
        const auto CancelSeconds = float64(Combat.Timing.CancelSeconds);
        auto Support = FCk_ProceduralLimbControl_Support(ECk_ProceduralLimbControl_SupportMode::CountOnly, PincerMinStandingLegs);
        Support.Set_SupportHoldTimeout(FCk_Time(Get_ClipSeconds(Combat.PincerClip.Get()) + CancelSeconds));

        auto Return = FCk_ProceduralLimbControl_Return();
        Return.Set_Duration(FCk_Time(CancelSeconds));
        Return.Set_Timeout(FCk_Time(float64(PincerReturnTimeoutSeconds)));

        auto Locomotion = FCk_ProceduralLimbControl_Locomotion();
        Locomotion.Set_Support(Support);
        Locomotion.Set_Return(Return);
        return Locomotion;
    }

    // Composes the crawler on InRoot (the simulation body; the entity script built the rig's transform entities and
    // their visuals): surface motion -> walker (legs, gait, rigs, body pose, and the action player when armed) -> monster -> the
    // damage dealer (armed only) -> one part per leg on the leg entity, with a hurtbox on every segment and the foot ->
    // the body hurtbox -> the navigator (on the root, steering the surface motion) -> the brain (Mars_Crawler_Goap.as)
    // -> the crawler fragments and, armed only, the combat fragments -> LAST the state machine (Mars_Crawler_Hfsm.as),
    // whose conditions bind the brain and the Dead attribute as it enters Alive. Armed = Spec.Combat.Enabled in a local
    // combat world; an unarmed crawler composes exactly what it did before combat existed. A rejected spec (rig and
    // combat profile included) or sub-feature ensures and returns an invalid handle.
    FCk_Handle_Crawler Add(FCk_Handle_Transform& InRoot, FMars_Crawler_Spec InSpec)
    {
        FCk_Handle RootEntity = InRoot;

        const auto Validation = InSpec.Validate();
        if (ck::EnsureIfNot(Validation.IsValid(), f"[Crawler] [{RootEntity.ToString()}] rejected the spec: {Validation.Get_Error()}"))
        { return FCk_Handle_Crawler(); }

        const auto& Rig = InSpec.Rig;

        auto Motion = utils_surface_motion::Add(InRoot, Make_MotionSpec(InSpec.Layout));

        auto Chains = TArray<FCk_ProceduralWalker_LegChain>();
        for (const auto& Leg : Rig.Legs)
        { Chains.Add(Make_LegChain(Leg, InSpec.Layout)); }

        const auto Armed = InSpec.Combat.Enabled &&
            utils_local_session::Get_IsLocalCombatWorld(utils_entity_lifetime::Get_WorldForEntity(RootEntity));

        auto Support = FCk_ProceduralBodyPose_Support();
        Support.Set_CollapseDrop(45.0f);
        Support.Set_MaxTilt(22.0f);
        auto Conform = FCk_ProceduralBodyPose_Conform();
        Conform.Set_Mode(ECk_ProceduralBodyPose_ConformMode::PlantedFeet);
        auto PoseSpec = FCk_ProceduralBodyPose_Spec(Rig.Presentation);
        PoseSpec.Set_Support(Support);
        PoseSpec.Set_Conform(Conform);

        auto WalkerSpec = FCk_ProceduralWalker_Spec(InSpec.Get_RigData(), Get_LayoutGaitData(InSpec.Layout));
        WalkerSpec.Set_Chains(Chains);
        WalkerSpec.Set_BodyPose(ECk_EnableDisable::Enable);
        WalkerSpec.Set_BodyPoseSpec(PoseSpec);
        // Armed crawlers own one body-channel player on the walker's articulation.
        if (Armed)
        {
            WalkerSpec.Set_ActionPlayer(ECk_EnableDisable::Enable);
            WalkerSpec.Set_ActionPlayerSpec(Make_AttackPlayerSpec(InSpec));
        }
        auto Walker = utils_procedural_animation::Add_Walker(InRoot, WalkerSpec);
        auto Gait = Walker.Get_Gait();
        if (ck::EnsureIfNot(ck::IsValid(Gait) && ck::IsValid(Motion),
            f"[Crawler] [{RootEntity.ToString()}] surface motion or walker composition was rejected"))
        { return FCk_Handle_Crawler(); }

        // Each sub-feature's Add ensures on its own rejection.
        auto Monster = utils_monster::Add(RootEntity, Make_MonsterSpec(InSpec.Vitals));
        if (ck::Is_NOT_Valid(Monster))
        { return FCk_Handle_Crawler(); }

        auto Dealer = FCk_Handle_DamageDealer();
        if (Armed)
        {
            Dealer = utils_damage_dealer::Add(RootEntity, FMars_DamageDealer_Spec());
            if (ck::Is_NOT_Valid(Dealer))
            { return FCk_Handle_Crawler(); }
        }

        auto BodyZone = Monster.Get_BodyZone();
        auto Presentation = Rig.Presentation;
        utils_hit_zone::AddHurtbox_Box(BodyZone, Presentation, FMars_HitZone_Hurtbox(Rig.BodyHalfExtents, FTransform::Identity));

        const auto Legs = Walker.Get_Legs();
        if (ck::EnsureIfNot(Legs.Num() == Rig.Legs.Num(),
            f"[Crawler] [{RootEntity.ToString()}] the walker made [{Legs.Num()}] legs for a rig of [{Rig.Legs.Num()}]"))
        { return FCk_Handle_Crawler(); }

        const auto LegPartSpec = Make_LegPartSpec(InSpec.Vitals);
        auto LegParts = TArray<FCk_Handle_BodyPart>();
        for (int32 Index = 0; Index < Legs.Num(); ++Index)
        {
            const auto& LegRig = Rig.Legs[Index];
            FCk_Handle LegEntity = Legs[Index];
            auto PartSpec = LegPartSpec;
            PartSpec.Monster = Monster;
            PartSpec.SegmentHalfExtents = LegRig.SegmentHalfExtents;
            auto Part = utils_body_part::Add(LegEntity, PartSpec);
            if (ck::Is_NOT_Valid(Part))
            { return FCk_Handle_Crawler(); }

            AddLegHurtboxes(Part, LegRig);
            LegParts.Add(Part);
        }

        auto Navigator = utils_surface_navigator::Add(Motion, Make_NavigatorSpec(InSpec.Layout));
        auto Brain = utils_brain::Add(RootEntity, Make_BrainSpec());
        if (ck::Is_NOT_Valid(Navigator) || ck::Is_NOT_Valid(Brain))
        { return FCk_Handle_Crawler(); }

        auto Params = FMars_Fragment_Crawler_Params();
        Params.Spec = InSpec;

        auto State = FMars_Fragment_Crawler();
        State.Motion = Motion;
        State.Gait = Gait;
        State.Articulation = Walker.Get_Articulation();
        State.BodyPose = Walker.Get_BodyPose();
        State.ActionPlayer = Walker.Get_ActionPlayer();
        State.Presentation = Rig.Presentation;
        State.LegParts = LegParts;
        State.Navigator = Navigator;

        RootEntity.Add_Fragment(FMars_Feature_Crawler());
        RootEntity.Add_Fragment(Params);
        RootEntity.Add_Fragment(State);
        RootEntity.Add_Fragment(FMars_Tag_Crawler_NeedsSetup());

        if (Armed)
        {
            auto Combat = FMars_Fragment_Crawler_Combat();
            Combat.Armed = true;
            Combat.Dealer = Dealer;
            Combat.Home = utils_transform::Get_EntityCurrentLocation(InRoot);

            RootEntity.Add_Fragment(Combat);
            RootEntity.Add_Fragment(FMars_Fragment_Crawler_Targeting());
            auto CombatTarget = FMars_Fragment_Crawler_CombatTarget();
            CombatTarget.Aggressive = InSpec.Combat.StartAggressive == ECk_EnableDisable::Enable;
            RootEntity.Add_Fragment(CombatTarget);
            RootEntity.Add_Fragment(FMars_Fragment_Crawler_Attack());
            RootEntity.Add_Fragment(FMars_Fragment_Crawler_AttackObservations());
            RootEntity.Add_Fragment(FMars_Fragment_Crawler_AttackIntents());
            RootEntity.Add_Fragment(FMars_Fragment_Crawler_Engage());
        }

        // Last: Alive's conditions read the Dead attribute and the brain as the machine enters its initial state.
        utils_state_machine::Add(RootEntity, FCk_StateMachine_Spec(UMars_SmState_Crawler_Alive));
        return RootEntity.As_Crawler();
    }

    // The crawler's brain over the Mars_Crawler_Goap.as catalog: its goal, Settled, is never written true, so the plan's
    // first action stays the standing behaviour.
    FMars_Brain_Spec Make_BrainSpec()
    {
        auto Facts = TArray<FMars_Brain_Fact>();
        Facts.Add(FMars_Brain_Fact(Get_IsHurtFact(), false));
        Facts.Add(FMars_Brain_Fact(Get_CanWalkFact(), true));
        Facts.Add(FMars_Brain_Fact(Get_SettledFact(), false));
        Facts.Add(FMars_Brain_Fact(Get_HasCombatTargetFact(), false));

        auto Goal = TArray<FCk_GoapWS_Condition_Authored>();
        Goal.Add(FCk_GoapWS_Condition_Authored(Get_SettledFact(), true));

        auto Spec = FMars_Brain_Spec(GameplayTags::Mars_Goap_Crawler, GameplayTags::Mars_WS_Crawler, Facts, Goal, 0.25f);
        Spec.AddAction(UMars_GoapAction_Crawler_Roam);
        Spec.AddAction(UMars_GoapAction_Crawler_Engage);
        Spec.AddAction(UMars_GoapAction_Crawler_Flinch);
        Spec.AddAction(UMars_GoapAction_Crawler_Cower);
        Spec.AddAction(UMars_GoapAction_Crawler_Idle);
        return Spec;
    }

    // Written only by the combat request drain: Aggressive and holding a valid combat target.
    FGameplayTag Get_HasCombatTargetFact()
    {
        return GameplayTags::Mars_WS_Crawler_HasCombatTarget;
    }

    // A hurtbox on every segment (its own box) and on the foot (the last box), each a scene node under that part.
    void AddLegHurtboxes(FCk_Handle_BodyPart InPart, FMars_Crawler_LegRig InLeg)
    {
        auto Zone = InPart.Get_Zone();
        for (int32 Index = 0; Index < InLeg.Segments.Num(); ++Index)
        {
            auto Segment = InLeg.Segments[Index];
            utils_hit_zone::AddHurtbox_Box(Zone, Segment, FMars_HitZone_Hurtbox(InLeg.SegmentHalfExtents[Index], FTransform::Identity));
        }

        auto Foot = InLeg.Foot;
        utils_hit_zone::AddHurtbox_Box(Zone, Foot, FMars_HitZone_Hurtbox(InLeg.SegmentHalfExtents.Last(), FTransform::Identity));
    }
}

//--------------------------------------------------------------------------------------------------------------------------
// Getters
//--------------------------------------------------------------------------------------------------------------------------

mixin FMars_Crawler_Spec Get_Spec(const FCk_Handle_Crawler& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Crawler_Params).Spec;
}

mixin FCk_Handle_SurfaceMotion Get_Motion(const FCk_Handle_Crawler& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Crawler).Motion;
}

mixin FCk_Handle_ProceduralGait Get_Gait(const FCk_Handle_Crawler& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Crawler).Gait;
}

mixin FCk_Handle_ProceduralArticulation Get_Articulation(const FCk_Handle_Crawler& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Crawler).Articulation;
}

mixin FCk_Handle_ProceduralBodyPose Get_BodyPose(const FCk_Handle_Crawler& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Crawler).BodyPose;
}

mixin FCk_Handle_ProceduralActionPlayer Get_ActionPlayer(const FCk_Handle_Crawler& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Crawler).ActionPlayer;
}

mixin FCk_Handle_Transform Get_Presentation(const FCk_Handle_Crawler& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Crawler).Presentation;
}

// Every leg the walker created, in rig order; a severed leg stays listed, and reads invalid once its debris timer
// destroys it.
mixin TArray<FCk_Handle_ProceduralLeg> Get_Legs(const FCk_Handle_Crawler& Self)
{
    auto Legs = TArray<FCk_Handle_ProceduralLeg>();
    for (const auto& Part : Self.Get_Fragment(FMars_Fragment_Crawler).LegParts)
    {
        if (ck::IsValid(Part))
        { Legs.Add(Part.Get_Leg()); }
        else
        { Legs.Add(FCk_Handle_ProceduralLeg()); }
    }
    return Legs;
}

// LegParts[i] is the part on Get_Legs()[i] (the same entity).
mixin TArray<FCk_Handle_BodyPart> Get_LegParts(const FCk_Handle_Crawler& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Crawler).LegParts;
}

// Goal -> path -> steering for the crawler's surface motion (the same root entity).
mixin FCk_Handle_SurfaceNavigator Get_Navigator(const FCk_Handle_Crawler& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Crawler).Navigator;
}

mixin FCk_Handle_Monster Get_Monster(const FCk_Handle_Crawler& Self)
{
    return Self.As_Monster();
}

// The decision layer, on the same root (facts through Request_SetFact only).
mixin FCk_Handle_Brain Get_Brain(const FCk_Handle_Crawler& Self)
{
    return Self.As_Brain();
}

// Damage events on the body or any leg so far.
mixin int32 Get_HurtCount(const FCk_Handle_Crawler& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Crawler).HurtCount;
}

// The behaviour sub-SM's current state (Idle / Roam / Flinch / Cower), or null outside Alive. Read-only walk: the root
// machine's current state -> its tasks -> the sub-SM entity the BehaviorSubSm task created.
mixin TSubclassOf<UCk_SmState_EntityScript> Get_BehaviorStateClass(const FCk_Handle_Crawler& Self)
{
    auto RootMachine = Self.As_StateMachine(ECk_SanityCheck::UnChecked);
    if (ck::Is_NOT_Valid(RootMachine))
    { return nullptr; }

    const auto RootState = utils_state_machine::Get_CurrentStateHandle(RootMachine);
    if (ck::Is_NOT_Valid(RootState))
    { return nullptr; }

    auto Frontier = utils_entity_lifetime::Get_LifetimeDependents(RootState);
    for (int32 Depth = 0; Depth < 2 && Frontier.Num() > 0; ++Depth)
    {
        auto Next = TArray<FCk_Handle>();
        for (auto Entity : Frontier)
        {
            const auto SubMachine = Entity.As_StateMachine(ECk_SanityCheck::UnChecked);
            if (ck::IsValid(SubMachine))
            { return utils_state_machine::Get_CurrentStateClass(SubMachine); }

            Next.Append(Entity.Get_LifetimeDependents());
        }
        Frontier = Next;
    }

    return nullptr;
}

// A uniform random point in RoamBounds at the body's height, projected onto the nav surface when a provider answers.
mixin FVector Pick_RoamPoint(const FCk_Handle_Crawler& Self)
{
    const auto Bounds = Self.Get_Spec().RoamBounds;
    const auto Body = utils_transform::Get_EntityCurrentLocation(Self.As_Transform());
    const auto Raw = FVector(Math::RandRange(Bounds.Min.X, Bounds.Max.X), Math::RandRange(Bounds.Min.Y, Bounds.Max.Y), Body.Z);

    auto Query = FCk_NavSurface_ProjectionQuery(Raw);
    Query.Set_SearchHalfExtents(FVector(100.0, 100.0, 200.0));
    const auto Projection = utils_nav_surface::Try_ProjectPoint(Query);
    if (Projection.Get_Status() == ECk_NavSurface_QueryStatus::Success)
    { return Projection.Get_Location(); }

    return Raw;
}

// The leg's rig parts as the entity script built them (a severed leg's parts are debris until they die).
mixin FMars_Crawler_LegRig Get_LegRig(const FCk_Handle_Crawler& Self, int32 InIndex)
{
    const auto& Legs = Self.Get_Fragment(FMars_Fragment_Crawler_Params).Spec.Rig.Legs;
    if (ck::EnsureIfNot(Legs.IsValidIndex(InIndex), f"[Crawler] [{Self.ToString()}] has no leg [{InIndex}] (it has [{Legs.Num()}])"))
    { return FMars_Crawler_LegRig(); }

    return Legs[InIndex];
}

//--------------------------------------------------------------------------------------------------------------------------
// Combat getters (read-only; an unarmed crawler reads Idle, no target and nothing pending)
//--------------------------------------------------------------------------------------------------------------------------

// Spec.Combat.Enabled in a local combat world: only then does the crawler carry any combat state.
mixin bool Get_IsCombatArmed(const FCk_Handle_Crawler& Self)
{
    return Self.Has_Fragment(FMars_Fragment_Crawler_Combat) && Self.Get_Fragment(FMars_Fragment_Crawler_Combat).Armed;
}

mixin FCk_Handle_DamageDealer Get_CombatDealer(const FCk_Handle_Crawler& Self)
{
    if (Self.Has_Fragment(FMars_Fragment_Crawler_Combat) == false)
    { return FCk_Handle_DamageDealer(); }

    return Self.Get_Fragment(FMars_Fragment_Crawler_Combat).Dealer;
}

mixin FVector Get_CombatHome(const FCk_Handle_Crawler& Self)
{
    if (Self.Has_Fragment(FMars_Fragment_Crawler_Combat) == false)
    { return FVector::ZeroVector; }

    return Self.Get_Fragment(FMars_Fragment_Crawler_Combat).Home;
}

// Targeting chooses combat targets (Spec.Combat.StartAggressive, then Request_SetAggression); false when unarmed.
mixin bool Get_IsAggressive(const FCk_Handle_Crawler& Self)
{
    return Self.Has_Fragment(FMars_Fragment_Crawler_CombatTarget) && Self.Get_Fragment(FMars_Fragment_Crawler_CombatTarget).Aggressive;
}

mixin FCk_Handle Get_CombatTarget(const FCk_Handle_Crawler& Self)
{
    if (Self.Has_Fragment(FMars_Fragment_Crawler_CombatTarget) == false)
    { return FCk_Handle(); }

    return Self.Get_Fragment(FMars_Fragment_Crawler_CombatTarget).Target;
}

mixin int32 Get_CombatTargetGeneration(const FCk_Handle_Crawler& Self)
{
    if (Self.Has_Fragment(FMars_Fragment_Crawler_CombatTarget) == false)
    { return 0; }

    return Self.Get_Fragment(FMars_Fragment_Crawler_CombatTarget).TargetGeneration;
}

// True until the combat request drain has run.
mixin bool Get_HasPendingCombatRequests(const FCk_Handle_Crawler& Self)
{
    return Self.Has_Fragment(FMars_Fragment_Crawler_Requests);
}

mixin EMars_Crawler_AttackPhase Get_AttackPhase(const FCk_Handle_Crawler& Self)
{
    if (Self.Has_Fragment(FMars_Fragment_Crawler_Attack) == false)
    { return EMars_Crawler_AttackPhase::Idle; }

    return Self.Get_Fragment(FMars_Fragment_Crawler_Attack).Phase;
}

// The crawler must stand where it is: its attack is posing, recovering, cooling down or still handing its legs back to
// the gait. The phase is Idle again only once the attack's action has finished its return, and a leg stepping back onto
// the ground under a body that walks away from it never lands. The behaviours ask this before they send a MoveTo.
mixin bool Get_IsHeldByAttack(const FCk_Handle_Crawler& Self)
{
    return Self.Get_AttackPhase() != EMars_Crawler_AttackPhase::Idle;
}

mixin float32 Get_AttackCooldownRemaining(const FCk_Handle_Crawler& Self)
{
    if (Self.Has_Fragment(FMars_Fragment_Crawler_Attack) == false)
    { return 0.0f; }

    return Self.Get_Fragment(FMars_Fragment_Crawler_Attack).CooldownRemaining;
}

mixin int32 Get_AttackGeneration(const FCk_Handle_Crawler& Self)
{
    if (Self.Has_Fragment(FMars_Fragment_Crawler_Attack) == false)
    { return 0; }

    return Self.Get_Fragment(FMars_Fragment_Crawler_Attack).Generation;
}

// The attack's target, copied at admission.
mixin FCk_Handle Get_AttackTarget(const FCk_Handle_Crawler& Self)
{
    if (Self.Has_Fragment(FMars_Fragment_Crawler_Attack) == false)
    { return FCk_Handle(); }

    return Self.Get_Fragment(FMars_Fragment_Crawler_Attack).Target;
}

mixin FVector Get_AttackCommittedDirection(const FCk_Handle_Crawler& Self)
{
    if (Self.Has_Fragment(FMars_Fragment_Crawler_Attack) == false)
    { return FVector::ZeroVector; }

    return Self.Get_Fragment(FMars_Fragment_Crawler_Attack).CommittedDirection;
}

// The clip the current (or last) attack played; the jab before the first. Null on an unarmed crawler.
mixin UCk_ProceduralAction_Data Get_AttackClip(const FCk_Handle_Crawler& Self)
{
    if (Self.Has_Fragment(FMars_Fragment_Crawler_Attack) == false)
    { return nullptr; }

    return Self.Get_Spec().Combat.Get_Clip(Self.Get_Fragment(FMars_Fragment_Crawler_Attack).ClipKind);
}

// The jab's clip action while one is held (an invalid handle otherwise).
mixin FCk_Handle_ProceduralAction Get_AttackAction(const FCk_Handle_Crawler& Self)
{
    if (Self.Has_Fragment(FMars_Fragment_Crawler_Attack) == false)
    { return FCk_Handle_ProceduralAction(); }

    return Self.Get_Fragment(FMars_Fragment_Crawler_Attack).Action;
}

// The sample sequence of the current action's last accepted receipt; 0 when none.
mixin int64 Get_AttackAcknowledgedSampleId(const FCk_Handle_Crawler& Self)
{
    if (Self.Has_Fragment(FMars_Fragment_Crawler_AttackObservations) == false)
    { return 0; }

    return Self.Get_Fragment(FMars_Fragment_Crawler_AttackObservations).AckSampleId;
}

// The clip interval of the current action's last accepted receipt (its PhaseId is None before the first).
mixin FCk_ProceduralAction_Interval Get_AttackAcceptedInterval(const FCk_Handle_Crawler& Self)
{
    if (Self.Has_Fragment(FMars_Fragment_Crawler_AttackObservations) == false)
    { return FCk_ProceduralAction_Interval(); }

    return Self.Get_Fragment(FMars_Fragment_Crawler_AttackObservations).AcceptedInterval;
}

// The presentation's world transform of the last acknowledged sample.
mixin FTransform Get_AttackAcceptedWorld(const FCk_Handle_Crawler& Self)
{
    if (Self.Has_Fragment(FMars_Fragment_Crawler_AttackObservations) == false)
    { return FTransform::Identity; }

    return Self.Get_Fragment(FMars_Fragment_Crawler_AttackObservations).AcceptedWorld;
}

mixin FVector Get_AttackAcceptedHitCenter(const FCk_Handle_Crawler& Self)
{
    if (Self.Has_Fragment(FMars_Fragment_Crawler_AttackObservations) == false)
    { return FVector::ZeroVector; }

    return Self.Get_Fragment(FMars_Fragment_Crawler_AttackObservations).AcceptedHitCenter;
}

// The longest sample-to-sample sweep of the current (or last) attack.
mixin float32 Get_AttackLongestSweep(const FCk_Handle_Crawler& Self)
{
    if (Self.Has_Fragment(FMars_Fragment_Crawler_AttackObservations) == false)
    { return 0.0f; }

    return Self.Get_Fragment(FMars_Fragment_Crawler_AttackObservations).LongestSweep;
}

// A hit was observed and waits for the next attack tick to commit or discard it.
mixin bool Get_AttackCandidatePending(const FCk_Handle_Crawler& Self)
{
    if (Self.Has_Fragment(FMars_Fragment_Crawler_AttackObservations) == false)
    { return false; }

    return Self.Get_Fragment(FMars_Fragment_Crawler_AttackObservations).Candidate.IsSet();
}

// This attack sent its one damage request (whatever the dealer made of it).
mixin bool Get_AttackDamageCommitted(const FCk_Handle_Crawler& Self)
{
    if (Self.Has_Fragment(FMars_Fragment_Crawler_Attack) == false)
    { return false; }

    return Self.Get_Fragment(FMars_Fragment_Crawler_Attack).DamageCommitted;
}

// The sample whose hit was committed; 0 when none.
mixin int64 Get_AttackCommittedSampleId(const FCk_Handle_Crawler& Self)
{
    if (Self.Has_Fragment(FMars_Fragment_Crawler_Attack) == false)
    { return 0; }

    return Self.Get_Fragment(FMars_Fragment_Crawler_Attack).CommittedSampleId;
}

mixin TOptional<EMars_Crawler_AttackCancel> Get_AttackLastCancel(const FCk_Handle_Crawler& Self)
{
    if (Self.Has_Fragment(FMars_Fragment_Crawler_Attack) == false)
    { return TOptional<EMars_Crawler_AttackCancel>(); }

    return Self.Get_Fragment(FMars_Fragment_Crawler_Attack).LastCancel;
}

mixin TOptional<EMars_Crawler_AttackReject> Get_AttackLastReject(const FCk_Handle_Crawler& Self)
{
    if (Self.Has_Fragment(FMars_Fragment_Crawler_Attack) == false)
    { return TOptional<EMars_Crawler_AttackReject>(); }

    return Self.Get_Fragment(FMars_Fragment_Crawler_Attack).LastReject;
}

// InTarget can be attacked and kept: live, not being destroyed, with a Health that is not depleted and an enabled HitZone,
// within LoseRadius of the crawler (horizontally).
mixin bool Get_IsCombatTargetValid(const FCk_Handle_Crawler& Self, FCk_Handle InTarget)
{
    if (ck::Is_NOT_Valid(InTarget) || utils_entity_lifetime::Get_IsPendingDestroy(InTarget, ECk_EntityLifetime_DestructionPhase::BeginDestroy))
    { return false; }

    const auto Transform = InTarget.As_Transform(ECk_SanityCheck::UnChecked);
    const auto Health = InTarget.As_Health(ECk_SanityCheck::UnChecked);
    const auto Zone = InTarget.As_HitZone(ECk_SanityCheck::UnChecked);
    if (ck::Is_NOT_Valid(Transform) || ck::Is_NOT_Valid(Health) || ck::Is_NOT_Valid(Zone))
    { return false; }

    if (Health.Get_IsDepleted() || Zone.Get_IsEnabled() == false)
    { return false; }

    const auto TargetLocation = utils_transform::Get_EntityCurrentLocation(Transform);
    const auto Root = utils_transform::Get_EntityCurrentLocation(Self.As_Transform());
    return (TargetLocation - Root).Size2D() <= Self.Get_Spec().Combat.Targeting.LoseRadius;
}

// The crawler is dead or its body Health depleted (the Dead attribute lags the depletion by a drain).
mixin bool Get_IsCombatDead(const FCk_Handle_Crawler& Self)
{
    const auto Monster = Self.Get_Monster();
    return Monster.Get_IsDead() || Monster.Get_BodyHealth().Get_IsDepleted();
}

// Unset when nothing about the crawler alone forbids an attack: Ready gait, body pose and surface motion, grounded on
// trusted contact no steeper than MaxGroundSlopeDegrees. Otherwise the reason (NotReady, Ungrounded or Slope).
mixin TOptional<EMars_Crawler_AttackReject> Get_SupportRejection(const FCk_Handle_Crawler& Self)
{
    const auto Motion = Self.Get_Motion();
    if (utils_procedural_gait::Get_Status(Self.Get_Gait()) != ECk_ProceduralAnimation_Status::Ready ||
        utils_procedural_body_pose::Get_Status(Self.Get_BodyPose()) != ECk_ProceduralAnimation_Status::Ready ||
        utils_surface_motion::Get_Status(Motion) != ECk_ProceduralAnimation_Status::Ready)
    { return TOptional<EMars_Crawler_AttackReject>(EMars_Crawler_AttackReject::NotReady); }

    if (utils_surface_motion::Get_Support(Motion) != ECk_SurfaceMotion_Support::Grounded ||
        utils_surface_motion::Get_ContactQuery(Motion) != ECk_SurfaceMotion_ContactQuery::Trusted)
    { return TOptional<EMars_Crawler_AttackReject>(EMars_Crawler_AttackReject::Ungrounded); }

    const auto Normal = utils_surface_motion::Get_SupportNormal(Motion).GetSafeNormal();
    const auto SlopeDegrees = Math::RadiansToDegrees(Math::Acos(Math::Clamp(Normal.DotProduct(FVector::UpVector), -1.0, 1.0)));
    if (Normal.IsNearlyZero() || SlopeDegrees > Self.Get_Spec().Combat.Prepare.MaxGroundSlopeDegrees)
    { return TOptional<EMars_Crawler_AttackReject>(EMars_Crawler_AttackReject::Slope); }

    return TOptional<EMars_Crawler_AttackReject>();
}

// Why a start at InTarget would be rejected now, in admission order (Disarmed, Busy, NoTarget, TargetInvalid, Dead, Legs,
// NotReady, Ungrounded, Slope, Stance, Height, OutOfRange, Moving, Facing, WindupBlocked); unset when it would be
// admitted. A cancel queued in the same drain (CancelPending) is the attack tick's to add. Stance only ever delays a
// pincer: a crawler that just stopped waits for its feet to land instead of asking the gait for two legs it would refuse
// to lend.
mixin TOptional<EMars_Crawler_AttackReject> Get_StartRejection(const FCk_Handle_Crawler& Self, FCk_Handle InTarget)
{
    if (Self.Get_IsCombatArmed() == false)
    { return TOptional<EMars_Crawler_AttackReject>(EMars_Crawler_AttackReject::Disarmed); }

    if (ck::Is_NOT_Valid(Self.Get_ActionPlayer()))
    { return TOptional<EMars_Crawler_AttackReject>(EMars_Crawler_AttackReject::NotReady); }

    if (Self.Get_AttackPhase() != EMars_Crawler_AttackPhase::Idle || Self.Get_AttackCooldownRemaining() > 0.0f)
    { return TOptional<EMars_Crawler_AttackReject>(EMars_Crawler_AttackReject::Busy); }

    const auto CombatTarget = Self.Get_CombatTarget();
    if (ck::Is_NOT_Valid(CombatTarget))
    { return TOptional<EMars_Crawler_AttackReject>(EMars_Crawler_AttackReject::NoTarget); }

    if (InTarget != CombatTarget || Self.Get_IsCombatTargetValid(InTarget) == false)
    { return TOptional<EMars_Crawler_AttackReject>(EMars_Crawler_AttackReject::TargetInvalid); }

    if (Self.Get_IsCombatDead())
    { return TOptional<EMars_Crawler_AttackReject>(EMars_Crawler_AttackReject::Dead); }

    const auto Spec = Self.Get_Spec();
    if (utils_procedural_gait::Get_EnabledLegCount(Self.Get_Gait()) < Spec.MinLegsToWalk)
    { return TOptional<EMars_Crawler_AttackReject>(EMars_Crawler_AttackReject::Legs); }

    const auto SupportRejection = Self.Get_SupportRejection();
    if (SupportRejection.IsSet())
    { return SupportRejection; }

    const auto Claws = utils_crawler::Find_AttackClaws(Self);
    if (Claws.Num() > 0 && utils_crawler::Get_IsPincerStanceReady(Self, Claws) == false)
    { return TOptional<EMars_Crawler_AttackReject>(EMars_Crawler_AttackReject::Stance); }

    const auto Prepare = Spec.Combat.Prepare;
    const auto RootTransform = utils_transform::Get_EntityCurrentTransform(Self.As_Transform());
    const auto ToTarget = utils_transform::Get_EntityCurrentLocation(InTarget.As_Transform()) - RootTransform.GetLocation();
    if (Math::Abs(ToTarget.Z) > Prepare.MaxHeightDifference)
    { return TOptional<EMars_Crawler_AttackReject>(EMars_Crawler_AttackReject::Height); }

    if (ToTarget.Size2D() > Prepare.StartDistance)
    { return TOptional<EMars_Crawler_AttackReject>(EMars_Crawler_AttackReject::OutOfRange); }

    const auto Motion = Self.Get_Motion();
    if (utils_surface_motion::Get_Velocity(Motion).Size() > Prepare.MaxSpeedToStart)
    { return TOptional<EMars_Crawler_AttackReject>(EMars_Crawler_AttackReject::Moving); }

    const auto Up = utils_surface_motion::Get_SupportNormal(Motion).GetSafeNormal();
    if (utils_crawler::Get_PlanarAngleDegrees(RootTransform.GetRotation().GetForwardVector(), ToTarget, Up) > Prepare.FacingToleranceDegrees)
    { return TOptional<EMars_Crawler_AttackReject>(EMars_Crawler_AttackReject::Facing); }

    if (Self.Get_IsWindupBlocked())
    { return TOptional<EMars_Crawler_AttackReject>(EMars_Crawler_AttackReject::WindupBlocked); }

    return TOptional<EMars_Crawler_AttackReject>();
}

// A world body stands between the hit centre now and where the windup end key of the clip an attack admitted now would
// play puts it.
mixin bool Get_IsWindupBlocked(const FCk_Handle_Crawler& Self)
{
    const auto Combat = Self.Get_Spec().Combat;
    const auto WindupKey = utils_crawler::Get_PhaseEndBody(Combat.Get_Clip(utils_crawler::Get_NextClipKind(Self)), EMars_Crawler_AttackPhase::Windup);
    const auto Presentation = utils_transform::Get_EntityCurrentTransform(Self.Get_Presentation());
    const auto RootTransform = utils_transform::Get_EntityCurrentTransform(Self.As_Transform());
    const auto Neutral = utils_crawler::Get_HitCenter(Presentation, Combat.Hit.LocalCenter);
    const auto Windup = Neutral + RootTransform.GetRotation().RotateVector(utils_crawler::Make_HitCenterOffset(WindupKey, Combat.Hit.LocalCenter));

    auto Settings = utils_crawler::Make_AttackQuery(Neutral, Windup, Combat.Hit.Radius);
    Settings.Set_IgnoredEntities(Self.Get_AttackIgnoredEntities());
    FCk_Handle Tracer = Self;
    const auto Result = utils_probe_trace::Request_SingleShapeTrace(Tracer, Settings);
    return ck::IsValid(Result.Get_HitEntity()) && Result.Get_HitKind() == ECk_ProbeTrace_HitKind::World;
}

// The combat target is set and a start at it would be admitted now.
mixin bool Get_CanStartAttack(const FCk_Handle_Crawler& Self)
{
    return Self.Get_StartRejection(Self.Get_CombatTarget()).IsSet() == false;
}

// The Engage behaviour's current stage; None outside Engage and on an unarmed crawler.
mixin EMars_Crawler_EngageStage Get_EngageStage(const FCk_Handle_Crawler& Self)
{
    if (Self.Has_Fragment(FMars_Fragment_Crawler_Engage) == false)
    { return EMars_Crawler_EngageStage::None; }

    return Self.Get_Fragment(FMars_Fragment_Crawler_Engage).Stage;
}

//--------------------------------------------------------------------------------------------------------------------------
// Combat requests (an armed crawler only)
//--------------------------------------------------------------------------------------------------------------------------

mixin void Request_SetAggression(FCk_Handle_Crawler& Self, const FMars_Request_Crawler_SetAggression& InRequest)
{
    if (ck::EnsureIfNot(Self.Get_IsCombatArmed(), f"[Crawler] [{Self.ToString()}] is not armed for combat; SetAggression dropped"))
    { return; }

    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_Crawler_Requests);
    Requests.SetAggressionRequests.Add(InRequest);
}

mixin void Request_SetCombatTarget(FCk_Handle_Crawler& Self, const FMars_Request_Crawler_SetCombatTarget& InRequest)
{
    if (ck::EnsureIfNot(Self.Get_IsCombatArmed(), f"[Crawler] [{Self.ToString()}] is not armed for combat; SetCombatTarget dropped"))
    { return; }

    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_Crawler_Requests);
    Requests.SetCombatTargetRequests.Add(InRequest);
}

mixin void Request_StartAttack(FCk_Handle_Crawler& Self, const FMars_Request_Crawler_StartAttack& InRequest)
{
    if (ck::EnsureIfNot(Self.Get_IsCombatArmed(), f"[Crawler] [{Self.ToString()}] is not armed for combat; StartAttack dropped"))
    { return; }

    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_Crawler_Requests);
    Requests.StartAttackRequests.Add(InRequest);
}

// An unarmed crawler has no attack to cancel, so the intent already holds and nothing is queued.
mixin void Request_CancelAttack(FCk_Handle_Crawler& Self, const FMars_Request_Crawler_CancelAttack& InRequest)
{
    if (Self.Get_IsCombatArmed() == false)
    { return; }

    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_Crawler_Requests);
    Requests.CancelAttackRequests.Add(InRequest);
}

//--------------------------------------------------------------------------------------------------------------------------
// Signal Binding
//--------------------------------------------------------------------------------------------------------------------------

mixin void BindTo_OnAttackPhaseChanged(FCk_Handle_Crawler& Self, FMars_Delegate_Crawler_OnAttackPhaseChanged InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_Crawler_Signals);
    Fragment.OnAttackPhaseChanged.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnAttackPhaseChanged(FCk_Handle_Crawler& Self, FMars_Delegate_Crawler_OnAttackPhaseChanged InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_Crawler_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_Crawler_Signals).OnAttackPhaseChanged.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void BindTo_OnTargetChanged(FCk_Handle_Crawler& Self, FMars_Delegate_Crawler_OnTargetChanged InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_Crawler_Signals);
    Fragment.OnTargetChanged.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnTargetChanged(FCk_Handle_Crawler& Self, FMars_Delegate_Crawler_OnTargetChanged InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_Crawler_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_Crawler_Signals).OnTargetChanged.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}
