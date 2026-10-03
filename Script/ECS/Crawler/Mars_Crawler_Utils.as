namespace utils_crawler
{
    // The crawler's motion profile: it rides the plane through its planted feet, slides along faces it cannot step onto
    // and steps up to about 1.3 clearances.
    FCk_SurfaceMotion_Spec Make_MotionSpec()
    {
        auto Contact = FCk_SurfaceMotion_Contact();
        Contact.Set_Clearance(65.0f);
        Contact.Set_ProbeReach(180.0f);
        Contact.Set_HeightSource(ECk_SurfaceMotion_HeightSource::PlantedFeet);
        Contact.Set_WallPolicy(ECk_SurfaceMotion_WallPolicy::Slide);
        Contact.Set_MaxStepHeight(85.0f);

        auto Movement = FCk_SurfaceMotion_Movement();
        Movement.Set_MaxSpeed(180.0f);
        Movement.Set_SurfaceTurnRate(180.0f);

        auto Spec = FCk_SurfaceMotion_Spec();
        Spec.Set_Contact(Contact);
        Spec.Set_Movement(Movement);
        return Spec;
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

    // The rig chain for one leg: its segments and foot, the Auto solver, the knee swivelled clear of solids, and one
    // sibling-capsule radius per segment from its box cross section.
    FCk_ProceduralWalker_LegChain Make_LegChain(FMars_Crawler_LegRig InLeg)
    {
        auto Radii = TArray<float32>();
        for (int32 Index = 0; Index < InLeg.Segments.Num(); ++Index)
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

    // Composes the crawler on InRoot (the simulation body; the entity script built the rig's transform entities and
    // their visuals): surface motion -> walker (legs, gait, rigs) -> body pose (before any detach) -> monster -> one
    // part per leg on the leg entity, with a hurtbox on every segment and the foot -> the body hurtbox -> the navigator
    // (on the root, steering the surface motion) -> the brain (Mars_Crawler_Goap.as) -> the crawler fragments -> LAST
    // the state machine (Mars_Crawler_Hfsm.as), whose conditions bind the brain and the Dead attribute as it enters
    // Alive. A rejected spec (rig included) or sub-feature ensures and returns an invalid handle.
    FCk_Handle_Crawler Add(FCk_Handle_Transform& InRoot, FMars_Crawler_Spec InSpec)
    {
        FCk_Handle RootEntity = InRoot;

        const auto Validation = InSpec.Validate();
        if (ck::EnsureIfNot(Validation.IsValid(), f"[Crawler] [{RootEntity.ToString()}] rejected the spec: {Validation.Get_Error()}"))
        { return FCk_Handle_Crawler(); }

        const auto& Rig = InSpec.Rig;

        auto Motion = utils_surface_motion::Add(InRoot, Make_MotionSpec());

        auto Chains = TArray<FCk_ProceduralWalker_LegChain>();
        for (const auto& Leg : Rig.Legs)
        { Chains.Add(Make_LegChain(Leg)); }

        auto Walker = utils_procedural_animation::Add_Walker(InRoot, utils_crawler::Get_RigData(InSpec.LegCount), utils_crawler::Mars_CrawlerGait, Chains);
        auto Gait = Walker.Get_Gait();
        if (ck::EnsureIfNot(ck::IsValid(Gait) && ck::IsValid(Motion),
            f"[Crawler] [{RootEntity.ToString()}] surface motion or walker composition was rejected"))
        { return FCk_Handle_Crawler(); }

        auto Support = FCk_ProceduralBodyPose_Support();
        Support.Set_CollapseDrop(45.0f);
        Support.Set_MaxTilt(22.0f);
        auto Conform = FCk_ProceduralBodyPose_Conform();
        Conform.Set_Mode(ECk_ProceduralBodyPose_ConformMode::PlantedFeet);
        auto PoseSpec = FCk_ProceduralBodyPose_Spec(Rig.Presentation);
        PoseSpec.Set_Support(Support);
        PoseSpec.Set_Conform(Conform);
        auto BodyPose = utils_procedural_body_pose::Add(Gait, PoseSpec);

        // Each sub-feature's Add ensures on its own rejection.
        auto Monster = utils_monster::Add(RootEntity, Make_MonsterSpec(InSpec.Vitals));
        if (ck::Is_NOT_Valid(Monster))
        { return FCk_Handle_Crawler(); }

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

        auto Navigator = utils_surface_navigator::Add(Motion, FMars_SurfaceNavigator_Spec());
        auto Brain = utils_brain::Add(RootEntity, Make_BrainSpec());
        if (ck::Is_NOT_Valid(Navigator) || ck::Is_NOT_Valid(Brain))
        { return FCk_Handle_Crawler(); }

        auto Params = FMars_Fragment_Crawler_Params();
        Params.Spec = InSpec;

        auto State = FMars_Fragment_Crawler();
        State.Motion = Motion;
        State.Gait = Gait;
        State.BodyPose = BodyPose;
        State.Presentation = Rig.Presentation;
        State.LegParts = LegParts;
        State.Navigator = Navigator;

        RootEntity.Add_Fragment(FMars_Feature_Crawler());
        RootEntity.Add_Fragment(Params);
        RootEntity.Add_Fragment(State);
        RootEntity.Add_Fragment(FMars_Tag_Crawler_NeedsSetup());

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

        auto Goal = TArray<FCk_GoapWS_Condition_Authored>();
        Goal.Add(FCk_GoapWS_Condition_Authored(Get_SettledFact(), true));

        auto Spec = FMars_Brain_Spec(GameplayTags::Mars_Goap_Crawler, GameplayTags::Mars_WS_Crawler, Facts, Goal, 0.25f);
        Spec.AddAction(UMars_GoapAction_Crawler_Roam);
        Spec.AddAction(UMars_GoapAction_Crawler_Flinch);
        Spec.AddAction(UMars_GoapAction_Crawler_Cower);
        Spec.AddAction(UMars_GoapAction_Crawler_Idle);
        return Spec;
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

mixin FCk_Handle_ProceduralBodyPose Get_BodyPose(const FCk_Handle_Crawler& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Crawler).BodyPose;
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
