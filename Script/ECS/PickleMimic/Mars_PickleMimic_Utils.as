// One action's progress, for whoever poses or reads it: what runs, which phase, and how far through it [0, 1].
struct FMars_PickleMimic_ActionFrame
{
    UPROPERTY()
    EMars_PickleMimic_Action Action = EMars_PickleMimic_Action::None;

    UPROPERTY()
    EMars_PickleMimic_ActionPhase Phase = EMars_PickleMimic_ActionPhase::None;

    UPROPERTY()
    float32 Alpha = 0.0f;

    FMars_PickleMimic_ActionFrame() {}

    FMars_PickleMimic_ActionFrame(EMars_PickleMimic_Action InAction, EMars_PickleMimic_ActionPhase InPhase, float32 InAlpha)
    {
        Action = InAction;
        Phase = InPhase;
        Alpha = InAlpha;
    }
}

// One foot as the walker has it: where (world), whether it stands on the ground, and how far through its swing [0, 1].
struct FMars_PickleMimic_Foot
{
    UPROPERTY()
    FVector Location;

    UPROPERTY()
    bool Planted = true;

    UPROPERTY()
    float32 SwingAlpha = 0.0f;
}

namespace utils_pickle_mimic
{
    // The mouth's front edge in the walker body's frame: the bite's blow is centred here.
    const FVector BiteMouth = FVector(40.0, 0.0, 64.0);

    // The body zone's box round the jar (body frame): centre and half extents.
    const FVector HurtboxCentre = FVector(0.0, 0.0, 36.0);
    const FVector HurtboxHalfExtents = FVector(32.0, 32.0, 40.0);

    // How fast the lid follows the latched gape between bites (openings a second).
    const float32 LidEaseRate = 4.0f;

    bool Get_IsPositiveFinite(float32 InValue)
    {
        return Math::IsFinite(InValue) && InValue > 0.0f;
    }

    // Monster.Mars.PickleMimic (DefaultGameplayTags.ini). Looked up, not GameplayTags::: an editor that booted before the
    // tag existed still compiles this script (it then has no tag, and Add refuses the mimic until the editor restarts).
    FGameplayTag Get_MonsterTag()
    {
        return FGameplayTag::RequestGameplayTag(n"Monster.Mars.PickleMimic", false);
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Composition
    //----------------------------------------------------------------------------------------------------------------------

    // A ground walker: a face it meets is a wall it slides along (it never climbs), it rides its rays, and its top speed
    // is the bite's lunge.
    FCk_SurfaceMotion_Spec Make_MotionSpec(FMars_PickleMimic_Spec InSpec)
    {
        auto Contact = FCk_SurfaceMotion_Contact();
        Contact.Set_Clearance(Clearance);
        Contact.Set_ProbeReach(Clearance * 2.6f);
        Contact.Set_HeightSource(ECk_SurfaceMotion_HeightSource::Rays);
        Contact.Set_WallPolicy(ECk_SurfaceMotion_WallPolicy::Slide);
        Contact.Set_MaxStepHeight(0.0f);

        auto Movement = FCk_SurfaceMotion_Movement();
        Movement.Set_MaxSpeed(Math::Max(InSpec.Bite.LungeSpeed, InSpec.Locomotion.HuntSpeed));
        Movement.Set_SurfaceTurnRate(InSpec.Locomotion.TurnRate);

        auto Spec = FCk_SurfaceMotion_Spec();
        Spec.Set_Contact(Contact);
        Spec.Set_Movement(Movement);
        return Spec;
    }

    // The body node's offset under the root at InRise (0 tucked .. 1 standing).
    FTransform Get_BodyOffset(float32 InRise)
    {
        return FTransform(FRotator::ZeroRotator, FVector(0.0, 0.0, -TuckDrop * (1.0f - Get_EaseInOut(InRise))));
    }

    // Composes the mimic on InRoot (the jar: the SurfaceMotion body, Clearance over the ground; the entity script built
    // the rig's body node at Get_BodyOffset(0) with every visual on it): surface motion -> the walker on the body node
    // (four floating feet, the trot) -> monster -> damage dealer -> the body-zone hurtbox round the jar -> the mimic's
    // fragments, tucked (UMars_Processor_PickleMimic_Setup then binds the body zone's hits to TakeHit) -> LAST the state
    // machine (Mars_PickleMimic_Hfsm.as). A rejected spec or sub-feature ensures and returns an invalid handle.
    FCk_Handle_PickleMimic Add(FCk_Handle_Transform& InRoot, FMars_PickleMimic_Spec InSpec)
    {
        FCk_Handle RootEntity = InRoot;
        const auto Validation = InSpec.Validate();
        if (ck::EnsureIfNot(Validation.IsValid(), f"[PickleMimic] [{RootEntity.ToString()}] rejected the spec: {Validation.Get_Error()}"))
        { return FCk_Handle_PickleMimic(); }

        auto Motion = utils_surface_motion::Add(InRoot, Make_MotionSpec(InSpec));
        if (ck::EnsureIfNot(ck::IsValid(Motion), f"[PickleMimic] [{RootEntity.ToString()}] surface motion was rejected"))
        { return FCk_Handle_PickleMimic(); }

        auto Body = InSpec.Rig.Body.As_Transform();
        auto Walker = utils_procedural_animation::Add_Walker(Body, FCk_ProceduralWalker_Spec(utils_pickle_mimic::Mars_PickleMimicRig, utils_pickle_mimic::Mars_PickleMimicGait));
        if (ck::EnsureIfNot(ck::IsValid(Walker.Get_Gait()), f"[PickleMimic] [{RootEntity.ToString()}] the walker was rejected"))
        { return FCk_Handle_PickleMimic(); }

        auto Monster = utils_monster::Add(RootEntity, FMars_Monster_Spec(Get_MonsterTag(), FMars_Health_Spec(InSpec.Vitals.BodyHealth),
            utils_hit_zone::Make_FleshZoneSpec(GameplayTags::HitZone_Mars_Body, 1.0f), InSpec.Vitals.CorpseSeconds, ECk_Team_ID::Two));
        if (ck::Is_NOT_Valid(Monster))
        { return FCk_Handle_PickleMimic(); }

        auto Dealer = utils_damage_dealer::Add(RootEntity, FMars_DamageDealer_Spec());
        if (ck::Is_NOT_Valid(Dealer))
        { return FCk_Handle_PickleMimic(); }

        auto BodyZone = Monster.Get_BodyZone();
        utils_hit_zone::AddHurtbox_Box(BodyZone, Body, FMars_HitZone_Hurtbox(HurtboxHalfExtents, FTransform(FRotator::ZeroRotator, HurtboxCentre)));

        auto Params = FMars_Fragment_PickleMimic_Params();
        Params.Spec = InSpec;

        auto State = FMars_Fragment_PickleMimic();
        State.Motion = Motion;
        State.Monster = Monster;
        State.Dealer = Dealer;
        State.Gait = Walker.Get_Gait();
        State.Home = utils_transform::Get_EntityCurrentLocation(InRoot);

        auto Posture = FMars_Fragment_PickleMimic_Posture();
        Posture.AppliedDrop = TuckDrop;

        RootEntity.Add_Fragment(FMars_Feature_PickleMimic());
        RootEntity.Add_Fragment(Params);
        RootEntity.Add_Fragment(State);
        RootEntity.Add_Fragment(FMars_Fragment_PickleMimic_Drive());
        RootEntity.Add_Fragment(Posture);
        RootEntity.Add_Fragment(FMars_Fragment_PickleMimic_Mouth());
        RootEntity.Add_Fragment(FMars_Fragment_PickleMimic_Action());
        RootEntity.Add_Fragment(FMars_Fragment_PickleMimic_Targeting());
        RootEntity.Add_Fragment(FMars_Fragment_PickleMimic_Hurt());
        RootEntity.Add_Fragment(FMars_Tag_PickleMimic_NeedsSetup());

        // Last: Alive's condition reads the Dead attribute as the machine enters its initial state.
        utils_state_machine::Add(RootEntity, FCk_StateMachine_Spec(UMars_SmState_PickleMimic_Alive));
        return RootEntity.As_PickleMimic();
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Geometry
    //----------------------------------------------------------------------------------------------------------------------

    // InVector laid onto the plane of InUp, unit length (zero when InVector is along InUp).
    FVector Get_Tangent(FVector InVector, FVector InUp)
    {
        return (InVector - InUp * InVector.DotProduct(InUp)).GetSafeNormal();
    }

    float32 Get_EaseOut(float32 InAlpha)
    {
        const auto Inverse = 1.0f - Math::Clamp(InAlpha, 0.0f, 1.0f);
        return 1.0f - Inverse * Inverse;
    }

    float32 Get_EaseIn(float32 InAlpha)
    {
        const auto Alpha = Math::Clamp(InAlpha, 0.0f, 1.0f);
        return Alpha * Alpha;
    }

    float32 Get_EaseInOut(float32 InAlpha)
    {
        const auto Alpha = Math::Clamp(InAlpha, 0.0f, 1.0f);
        return Alpha * Alpha * (3.0f - 2.0f * Alpha);
    }

    // The lid's opening through a bite: it gapes from InLidAtStart to wide through the windup, slams shut through the
    // active phase and stays shut through the recovery.
    float32 Get_BiteLid(FMars_PickleMimic_ActionFrame InFrame, float32 InLidAtStart)
    {
        if (InFrame.Phase == EMars_PickleMimic_ActionPhase::Windup)
        { return Math::Lerp(InLidAtStart, 1.0f, Get_EaseOut(InFrame.Alpha)); }

        if (InFrame.Phase == EMars_PickleMimic_ActionPhase::Active)
        { return 1.0f - Get_EaseIn(InFrame.Alpha); }

        return 0.0f;
    }

    float32 Get_PhaseSeconds(FMars_PickleMimic_ActionTiming InTiming, EMars_PickleMimic_ActionPhase InPhase)
    {
        if (InPhase == EMars_PickleMimic_ActionPhase::Windup)
        { return InTiming.WindupSeconds; }

        if (InPhase == EMars_PickleMimic_ActionPhase::Active)
        { return InTiming.ActiveSeconds; }

        if (InPhase == EMars_PickleMimic_ActionPhase::Recover)
        { return InTiming.RecoverSeconds; }

        return 0.0f;
    }

    FMars_PickleMimic_ActionFrame Make_Frame(FMars_PickleMimic_Spec InSpec, const FMars_Fragment_PickleMimic_Action& InAction)
    {
        const auto Seconds = Get_PhaseSeconds(InSpec.Bite.Timing, InAction.Phase);
        const auto Alpha = Seconds > 0.0f ? Math::Clamp(InAction.PhaseElapsed / Seconds, 0.0f, 1.0f) : 0.0f;
        return FMars_PickleMimic_ActionFrame(InAction.Kind, InAction.Phase, Alpha);
    }

    // The crack stage InHealthShare (current / max body health) has reached: 0 intact, 1 cracked, 2 heavily cracked.
    int32 Get_CrackStageFor(FMars_PickleMimic_Vitals InVitals, float32 InHealthShare)
    {
        if (InHealthShare <= InVitals.HeavilyCrackedBelow)
        { return 2; }

        return InHealthShare <= InVitals.CrackedBelow ? 1 : 0;
    }

    // A target the mimic may act on: alive as an entity and placed in the world.
    bool Get_IsTargetValid(FCk_Handle InTarget)
    {
        if (ck::Is_NOT_Valid(InTarget) || utils_entity_lifetime::Get_IsPendingDestroy(InTarget, ECk_EntityLifetime_DestructionPhase::BeginDestroy))
        { return false; }

        return ck::IsValid(InTarget.As_Transform(ECk_SanityCheck::UnChecked));
    }
}

//--------------------------------------------------------------------------------------------------------------------------
// Getters
//--------------------------------------------------------------------------------------------------------------------------

mixin FMars_PickleMimic_Spec Get_Spec(const FCk_Handle_PickleMimic& Self)
{
    return Self.Get_Fragment(FMars_Fragment_PickleMimic_Params).Spec;
}

mixin FCk_Handle_SurfaceMotion Get_Motion(const FCk_Handle_PickleMimic& Self)
{
    return Self.Get_Fragment(FMars_Fragment_PickleMimic).Motion;
}

mixin FCk_Handle_Monster Get_Monster(const FCk_Handle_PickleMimic& Self)
{
    return Self.Get_Fragment(FMars_Fragment_PickleMimic).Monster;
}

mixin FCk_Handle_ProceduralGait Get_Gait(const FCk_Handle_PickleMimic& Self)
{
    return Self.Get_Fragment(FMars_Fragment_PickleMimic).Gait;
}

mixin FVector Get_Home(const FCk_Handle_PickleMimic& Self)
{
    return Self.Get_Fragment(FMars_Fragment_PickleMimic).Home;
}

mixin bool Get_IsDead(const FCk_Handle_PickleMimic& Self)
{
    return Self.Get_Monster().Get_IsDead();
}

// The root: the jar's base, Clearance over the ground, wherever the body has sunk to.
mixin FTransform Get_RootTransform(const FCk_Handle_PickleMimic& Self)
{
    return utils_transform::Get_EntityCurrentTransform(Self.As_Transform());
}

mixin FVector Get_Location(const FCk_Handle_PickleMimic& Self)
{
    return utils_transform::Get_EntityCurrentLocation(Self.As_Transform());
}

mixin FCk_Handle_SceneNode Get_Body(const FCk_Handle_PickleMimic& Self)
{
    return Self.Get_Spec().Rig.Body;
}

// The walker body (the jar as drawn: sunk while tucked).
mixin FTransform Get_BodyTransform(const FCk_Handle_PickleMimic& Self)
{
    return utils_transform::Get_EntityCurrentTransform(Self.Get_Body().As_Transform());
}

// The normal of the ground it stands on (its own up while it has none).
mixin FVector Get_SurfaceUp(const FCk_Handle_PickleMimic& Self)
{
    const auto Up = utils_surface_motion::Get_SupportNormal(Self.Get_Motion()).GetSafeNormal();
    return Up.IsNearlyZero() ? Self.Get_RootTransform().GetRotation().GetUpVector() : Up;
}

mixin bool Get_IsGrounded(const FCk_Handle_PickleMimic& Self)
{
    const auto Motion = Self.Get_Motion();
    return utils_surface_motion::Get_Status(Motion) == ECk_ProceduralAnimation_Status::Ready &&
        utils_surface_motion::Get_Support(Motion) == ECk_SurfaceMotion_Support::Grounded;
}

mixin bool Get_IsWalkerReady(const FCk_Handle_PickleMimic& Self)
{
    return utils_procedural_gait::Get_Status(Self.Get_Gait()) == ECk_ProceduralAnimation_Status::Ready;
}

// The four feet in leg order (front-right, front-left, back-right, back-left); a leg the walker has not set up yet stands
// at its rest foot.
mixin TArray<FMars_PickleMimic_Foot> Get_Feet(const FCk_Handle_PickleMimic& Self)
{
    FCk_Handle BodyEntity = Self.Get_Body();
    auto Feet = TArray<FMars_PickleMimic_Foot>();
    for (int32 Index = 0; Index < utils_pickle_mimic::Get_LegCount(); ++Index)
    {
        auto Foot = FMars_PickleMimic_Foot();
        Foot.Location = Self.Get_RootTransform().TransformPosition(utils_pickle_mimic::Get_RestFootLocal(Index));
        const auto Leg = utils_procedural_leg::TryGet_Leg(BodyEntity, utils_pickle_mimic::Get_LegId(Index));
        if (ck::IsValid(Leg) && Self.Get_IsWalkerReady())
        {
            const auto Data = utils_procedural_leg::Get_Foot(Leg);
            Foot.Location = Data.Get_Position();
            Foot.Planted = Data.Get_Phase() != ECk_ProceduralLeg_FootPhase::Swinging;
            Foot.SwingAlpha = Data.Get_SwingAlpha();
        }

        Feet.Add(Foot);
    }

    return Feet;
}

mixin EMars_PickleMimic_Stance Get_Stance(const FCk_Handle_PickleMimic& Self)
{
    return Self.Get_Fragment(FMars_Fragment_PickleMimic_Posture).Stance;
}

// 0 sitting tucked .. 1 standing.
mixin float32 Get_Rise(const FCk_Handle_PickleMimic& Self)
{
    return Self.Get_Fragment(FMars_Fragment_PickleMimic_Posture).Rise;
}

// Fully up and told to stay up: it may walk and bite.
mixin bool Get_IsStanding(const FCk_Handle_PickleMimic& Self)
{
    const auto& Posture = Self.Get_Fragment(FMars_Fragment_PickleMimic_Posture);
    return Posture.Stance == EMars_PickleMimic_Stance::Standing && Posture.Rise >= 1.0f;
}

// Fully sat down and told to stay down: the disguise.
mixin bool Get_IsTucked(const FCk_Handle_PickleMimic& Self)
{
    const auto& Posture = Self.Get_Fragment(FMars_Fragment_PickleMimic_Posture);
    return Posture.Stance == EMars_PickleMimic_Stance::Tucked && Posture.Rise <= 0.0f;
}

// 0 shut .. 1 wide (the entity script draws 1 as its lid's widest angle).
mixin float32 Get_LidOpen(const FCk_Handle_PickleMimic& Self)
{
    return Self.Get_Fragment(FMars_Fragment_PickleMimic_Mouth).LidOpen;
}

mixin FCk_Handle Get_Target(const FCk_Handle_PickleMimic& Self)
{
    return Self.Get_Fragment(FMars_Fragment_PickleMimic_Targeting).Target;
}

mixin bool Get_HasTarget(const FCk_Handle_PickleMimic& Self)
{
    return utils_pickle_mimic::Get_IsTargetValid(Self.Get_Target());
}

mixin FVector Get_TargetLocation(const FCk_Handle_PickleMimic& Self)
{
    return utils_transform::Get_EntityCurrentLocation(Self.Get_Target().As_Transform());
}

// Within the senses' WakeRadius of the root (false with no target).
mixin bool Get_IsTargetNear(const FCk_Handle_PickleMimic& Self)
{
    if (Self.Get_HasTarget() == false)
    { return false; }

    return (Self.Get_TargetLocation() - Self.Get_Location()).Size() <= Self.Get_Spec().Senses.WakeRadius;
}

mixin FMars_Fragment_PickleMimic_Action Get_Action(const FCk_Handle_PickleMimic& Self)
{
    return Self.Get_Fragment(FMars_Fragment_PickleMimic_Action);
}

mixin FMars_PickleMimic_ActionFrame Get_ActionFrame(const FCk_Handle_PickleMimic& Self)
{
    return utils_pickle_mimic::Make_Frame(Self.Get_Spec(), Self.Get_Fragment(FMars_Fragment_PickleMimic_Action));
}

// The bite's blow centre now (world): the mouth's front edge on the body.
mixin FVector Get_MouthLocation(const FCk_Handle_PickleMimic& Self)
{
    return Self.Get_BodyTransform().TransformPosition(utils_pickle_mimic::BiteMouth);
}

mixin bool Get_HasPendingRequests(const FCk_Handle_PickleMimic& Self)
{
    return Self.Has_Fragment(FMars_Fragment_PickleMimic_Requests);
}

mixin FMars_Fragment_PickleMimic_Hurt Get_Hurt(const FCk_Handle_PickleMimic& Self)
{
    return Self.Get_Fragment(FMars_Fragment_PickleMimic_Hurt);
}

mixin bool Get_IsFlinching(const FCk_Handle_PickleMimic& Self)
{
    return Self.Get_Fragment(FMars_Fragment_PickleMimic_Hurt).FlinchLeft > 0.0f;
}

// How far through the current flinch [0, 1] (1 when not flinching).
mixin float32 Get_FlinchAlpha(const FCk_Handle_PickleMimic& Self)
{
    const auto Seconds = Self.Get_Spec().Vitals.FlinchSeconds;
    const auto Left = Self.Get_Fragment(FMars_Fragment_PickleMimic_Hurt).FlinchLeft;
    return Seconds > 0.0f ? Math::Clamp(1.0f - Left / Seconds, 0.0f, 1.0f) : 1.0f;
}

// A blow found it disguised and it has not stood up since.
mixin bool Get_IsStartled(const FCk_Handle_PickleMimic& Self)
{
    return Self.Get_Fragment(FMars_Fragment_PickleMimic_Hurt).Startled;
}

// 0 intact, 1 cracked, 2 heavily cracked.
mixin int32 Get_CrackStage(const FCk_Handle_PickleMimic& Self)
{
    return Self.Get_Fragment(FMars_Fragment_PickleMimic_Hurt).CrackStage;
}

// An action runs, or a Start is queued.
mixin bool Get_IsActionBusy(const FCk_Handle_PickleMimic& Self)
{
    if (Self.Get_Fragment(FMars_Fragment_PickleMimic_Action).Kind != EMars_PickleMimic_Action::None)
    { return true; }

    return Self.Has_Fragment(FMars_Fragment_PickleMimic_Requests) &&
        Self.Get_Fragment(FMars_Fragment_PickleMimic_Requests).StartRequests.Num() > 0;
}

// Whether InAction on InTarget would be admitted now (the drain asks exactly this).
mixin EMars_PickleMimic_Admission Get_Admission(const FCk_Handle_PickleMimic& Self, EMars_PickleMimic_Action InAction, FCk_Handle InTarget)
{
    if (Self.Get_IsDead())
    { return EMars_PickleMimic_Admission::Dead; }

    if (Self.Get_IsStanding() == false)
    { return EMars_PickleMimic_Admission::NotStanding; }

    const auto& Action = Self.Get_Fragment(FMars_Fragment_PickleMimic_Action);
    if (Action.Kind != EMars_PickleMimic_Action::None)
    { return EMars_PickleMimic_Admission::Busy; }

    if (Self.Get_IsFlinching())
    { return EMars_PickleMimic_Admission::Flinching; }

    if (Action.BiteCooldown > 0.0f)
    { return EMars_PickleMimic_Admission::Cooldown; }

    if (utils_pickle_mimic::Get_IsTargetValid(InTarget) == false)
    { return EMars_PickleMimic_Admission::NoTarget; }

    if (Self.Get_IsGrounded() == false)
    { return EMars_PickleMimic_Admission::Ungrounded; }

    const auto Spec = Self.Get_Spec();
    const auto Root = Self.Get_RootTransform();
    const auto Up = Self.Get_SurfaceUp();
    const auto Offset = utils_transform::Get_EntityCurrentLocation(InTarget.As_Transform()) - Root.GetLocation();
    const auto Along = Offset - Up * Offset.DotProduct(Up);
    if (Along.Size() > Spec.Bite.Range)
    { return EMars_PickleMimic_Admission::OutOfRange; }

    const auto Forward = utils_pickle_mimic::Get_Tangent(Root.GetRotation().GetForwardVector(), Up);
    if (Along.IsNearlyZero() == false && Along.GetSafeNormal().DotProduct(Forward) < Math::Cos(Math::DegreesToRadians(Spec.Bite.FacingDegrees)))
    { return EMars_PickleMimic_Admission::Facing; }

    return EMars_PickleMimic_Admission::Admitted;
}

//--------------------------------------------------------------------------------------------------------------------------
// Requests
//--------------------------------------------------------------------------------------------------------------------------

mixin void Request_TakeHit(FCk_Handle_PickleMimic& Self, const FMars_Request_PickleMimic_TakeHit& InRequest)
{
    Self.AddOrGet_Fragment(FMars_Fragment_PickleMimic_Requests).TakeHitRequests.Add(InRequest);
}

mixin void Request_Drive(FCk_Handle_PickleMimic& Self, const FMars_Request_PickleMimic_Drive& InRequest)
{
    Self.AddOrGet_Fragment(FMars_Fragment_PickleMimic_Requests).DriveRequests.Add(InRequest);
}

mixin void Request_Stop(FCk_Handle_PickleMimic& Self, const FMars_Request_PickleMimic_Stop& InRequest)
{
    Self.AddOrGet_Fragment(FMars_Fragment_PickleMimic_Requests).StopRequests.Add(InRequest);
}

mixin void Request_SetStance(FCk_Handle_PickleMimic& Self, const FMars_Request_PickleMimic_SetStance& InRequest)
{
    Self.AddOrGet_Fragment(FMars_Fragment_PickleMimic_Requests).SetStanceRequests.Add(InRequest);
}

mixin void Request_Gape(FCk_Handle_PickleMimic& Self, const FMars_Request_PickleMimic_Gape& InRequest)
{
    Self.AddOrGet_Fragment(FMars_Fragment_PickleMimic_Requests).GapeRequests.Add(InRequest);
}

mixin void Request_Start(FCk_Handle_PickleMimic& Self, const FMars_Request_PickleMimic_Start& InRequest)
{
    Self.AddOrGet_Fragment(FMars_Fragment_PickleMimic_Requests).StartRequests.Add(InRequest);
}

mixin void Request_Cancel(FCk_Handle_PickleMimic& Self, const FMars_Request_PickleMimic_Cancel& InRequest)
{
    Self.AddOrGet_Fragment(FMars_Fragment_PickleMimic_Requests).CancelRequests.Add(InRequest);
}

//--------------------------------------------------------------------------------------------------------------------------
// Signal Binding
//--------------------------------------------------------------------------------------------------------------------------

mixin void BindTo_OnActionPhase(FCk_Handle_PickleMimic& Self, FMars_Delegate_PickleMimic_OnActionPhase InDelegate)
{
    auto& Signals = Self.AddOrGet_Fragment(FMars_Fragment_PickleMimic_Signals);
    Signals.OnActionPhase.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnActionPhase(FCk_Handle_PickleMimic& Self, FMars_Delegate_PickleMimic_OnActionPhase InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_PickleMimic_Signals))
    { Self.Get_Fragment(FMars_Fragment_PickleMimic_Signals).OnActionPhase.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName()); }
}

mixin void BindTo_OnBlowLanded(FCk_Handle_PickleMimic& Self, FMars_Delegate_PickleMimic_OnBlowLanded InDelegate)
{
    auto& Signals = Self.AddOrGet_Fragment(FMars_Fragment_PickleMimic_Signals);
    Signals.OnBlowLanded.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnBlowLanded(FCk_Handle_PickleMimic& Self, FMars_Delegate_PickleMimic_OnBlowLanded InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_PickleMimic_Signals))
    { Self.Get_Fragment(FMars_Fragment_PickleMimic_Signals).OnBlowLanded.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName()); }
}

mixin void BindTo_OnStance(FCk_Handle_PickleMimic& Self, FMars_Delegate_PickleMimic_OnStance InDelegate)
{
    auto& Signals = Self.AddOrGet_Fragment(FMars_Fragment_PickleMimic_Signals);
    Signals.OnStance.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void BindTo_OnSpill(FCk_Handle_PickleMimic& Self, FMars_Delegate_PickleMimic_OnSpill InDelegate)
{
    auto& Signals = Self.AddOrGet_Fragment(FMars_Fragment_PickleMimic_Signals);
    Signals.OnSpill.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnSpill(FCk_Handle_PickleMimic& Self, FMars_Delegate_PickleMimic_OnSpill InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_PickleMimic_Signals))
    { Self.Get_Fragment(FMars_Fragment_PickleMimic_Signals).OnSpill.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName()); }
}

mixin void UnbindFrom_OnStance(FCk_Handle_PickleMimic& Self, FMars_Delegate_PickleMimic_OnStance InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_PickleMimic_Signals))
    { Self.Get_Fragment(FMars_Fragment_PickleMimic_Signals).OnStance.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName()); }
}
