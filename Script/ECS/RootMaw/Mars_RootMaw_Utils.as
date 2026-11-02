// One action's progress, for whoever poses or reads it: what runs, which phase, and how far through it [0, 1].
struct FMars_RootMaw_ActionFrame
{
    UPROPERTY()
    EMars_RootMaw_Action Action = EMars_RootMaw_Action::None;

    UPROPERTY()
    EMars_RootMaw_ActionPhase Phase = EMars_RootMaw_ActionPhase::None;

    UPROPERTY()
    float32 Alpha = 0.0f;

    FMars_RootMaw_ActionFrame() {}

    FMars_RootMaw_ActionFrame(EMars_RootMaw_Action InAction, EMars_RootMaw_ActionPhase InPhase, float32 InAlpha)
    {
        Action = InAction;
        Phase = InPhase;
        Alpha = InAlpha;
    }
}

// Every number here is measured in the body's frame (cm: +X the maw's direction, +Y right, +Z up; the origin is the ground
// under the bulb's axis when it is up) and matches the art contract of Tools/Blender/mars_monsters/build_root_maw_pieces.py
// (its RootMaw_RestLayout.json). Change the art and these together.
namespace utils_root_maw
{
    // The root (the surface motion's body) rides this far over the ground; the body node hangs Clearance under it.
    const float32 Clearance = 30.0f;

    // Buried, the body sinks this far into the ground: only the bulb's pink shoulder and the crown of leaves show.
    const float32 BuryDrop = 78.0f;

    // The maw's front edge, at the mouth's corners' height: the bite's blow is centred here.
    const FVector BiteMouth = FVector(40.0, 0.0, 57.5);

    // The body zone's box round the bulb (body frame): centre and half extents.
    const FVector HurtboxCentre = FVector(0.0, 0.0, 52.0);
    const FVector HurtboxHalfExtents = FVector(38.0, 42.0, 44.0);

    // How fast the jaw follows the latched gape between bites (openings a second).
    const float32 JawEaseRate = 4.0f;

    bool Get_IsPositiveFinite(float32 InValue)
    {
        return Math::IsFinite(InValue) && InValue > 0.0f;
    }

    // Monster.Mars.RootMaw (DefaultGameplayTags.ini). Looked up, not GameplayTags::: an editor that booted before the tag
    // existed still compiles this script (it then has no tag, and Add refuses the Maw until the editor restarts).
    FGameplayTag Get_MonsterTag()
    {
        return FGameplayTag::RequestGameplayTag(n"Monster.Mars.RootMaw", false);
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Composition
    //----------------------------------------------------------------------------------------------------------------------

    // A ground glider: a face it meets is a wall it slides along (it never climbs), it rides its rays, and its top speed is
    // the bite's lunge.
    FCk_SurfaceMotion_Spec Make_MotionSpec(FMars_RootMaw_Spec InSpec)
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

    // The body node's offset under the root at InEmerge (0 buried .. 1 up): the ground under the root, less the burial.
    FTransform Get_BodyOffset(float32 InEmerge)
    {
        return FTransform(FRotator::ZeroRotator, FVector(0.0, 0.0, -Clearance - BuryDrop * (1.0f - Get_EaseInOut(InEmerge))));
    }

    // Composes the Maw on InRoot (the SurfaceMotion body, Clearance over the ground; the entity script built the rig's body
    // node at Get_BodyOffset(0) with every visual on it): surface motion -> monster -> damage dealer -> the body-zone
    // hurtbox round the bulb (on the body node: buried, only the crown can be struck) -> the Maw's fragments, buried
    // (UMars_Processor_RootMaw_Setup then binds the body zone's hits to TakeHit) -> LAST the state machine
    // (Mars_RootMaw_Hfsm.as). A rejected spec or sub-feature ensures and returns an invalid handle.
    FCk_Handle_RootMaw Add(FCk_Handle_Transform& InRoot, FMars_RootMaw_Spec InSpec)
    {
        FCk_Handle RootEntity = InRoot;
        const auto Validation = InSpec.Validate();
        if (ck::EnsureIfNot(Validation.IsValid(), f"[RootMaw] [{RootEntity.ToString()}] rejected the spec: {Validation.Get_Error()}"))
        { return FCk_Handle_RootMaw(); }

        auto Motion = utils_surface_motion::Add(InRoot, Make_MotionSpec(InSpec));
        if (ck::EnsureIfNot(ck::IsValid(Motion), f"[RootMaw] [{RootEntity.ToString()}] surface motion was rejected"))
        { return FCk_Handle_RootMaw(); }

        auto Monster = utils_monster::Add(RootEntity, FMars_Monster_Spec(Get_MonsterTag(), FMars_Health_Spec(InSpec.Vitals.BodyHealth),
            utils_hit_zone::Make_FleshZoneSpec(GameplayTags::HitZone_Mars_Body, 1.0f), InSpec.Vitals.CorpseSeconds, ECk_Team_ID::Two));
        if (ck::Is_NOT_Valid(Monster))
        { return FCk_Handle_RootMaw(); }

        auto Dealer = utils_damage_dealer::Add(RootEntity, FMars_DamageDealer_Spec());
        if (ck::Is_NOT_Valid(Dealer))
        { return FCk_Handle_RootMaw(); }

        auto Body = InSpec.Rig.Body.As_Transform();
        auto BodyZone = Monster.Get_BodyZone();
        utils_hit_zone::AddHurtbox_Box(BodyZone, Body, FMars_HitZone_Hurtbox(HurtboxHalfExtents, FTransform(FRotator::ZeroRotator, HurtboxCentre)));

        auto Params = FMars_Fragment_RootMaw_Params();
        Params.Spec = InSpec;

        auto State = FMars_Fragment_RootMaw();
        State.Motion = Motion;
        State.Monster = Monster;
        State.Dealer = Dealer;
        State.Home = utils_transform::Get_EntityCurrentLocation(InRoot);

        auto Posture = FMars_Fragment_RootMaw_Posture();
        Posture.AppliedDrop = float32(-Get_BodyOffset(0.0f).GetLocation().Z);

        RootEntity.Add_Fragment(FMars_Feature_RootMaw());
        RootEntity.Add_Fragment(Params);
        RootEntity.Add_Fragment(State);
        RootEntity.Add_Fragment(FMars_Fragment_RootMaw_Drive());
        RootEntity.Add_Fragment(Posture);
        RootEntity.Add_Fragment(FMars_Fragment_RootMaw_Mouth());
        RootEntity.Add_Fragment(FMars_Fragment_RootMaw_Travel());
        RootEntity.Add_Fragment(FMars_Fragment_RootMaw_Action());
        RootEntity.Add_Fragment(FMars_Fragment_RootMaw_Targeting());
        RootEntity.Add_Fragment(FMars_Fragment_RootMaw_Hurt());
        RootEntity.Add_Fragment(FMars_Tag_RootMaw_NeedsSetup());

        // Last: Alive's condition reads the Dead attribute as the machine enters its initial state.
        utils_state_machine::Add(RootEntity, FCk_StateMachine_Spec(UMars_SmState_RootMaw_Alive));
        return RootEntity.As_RootMaw();
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

    // The jaw's opening through a bite: it gapes from InJawAtStart to wide through the windup, slams shut through the
    // active phase and stays shut through the recovery.
    float32 Get_BiteJaw(FMars_RootMaw_ActionFrame InFrame, float32 InJawAtStart)
    {
        if (InFrame.Phase == EMars_RootMaw_ActionPhase::Windup)
        { return Math::Lerp(InJawAtStart, 1.0f, Get_EaseOut(InFrame.Alpha)); }

        if (InFrame.Phase == EMars_RootMaw_ActionPhase::Active)
        { return 1.0f - Get_EaseIn(InFrame.Alpha); }

        return 0.0f;
    }

    float32 Get_PhaseSeconds(FMars_RootMaw_ActionTiming InTiming, EMars_RootMaw_ActionPhase InPhase)
    {
        if (InPhase == EMars_RootMaw_ActionPhase::Windup)
        { return InTiming.WindupSeconds; }

        if (InPhase == EMars_RootMaw_ActionPhase::Active)
        { return InTiming.ActiveSeconds; }

        if (InPhase == EMars_RootMaw_ActionPhase::Recover)
        { return InTiming.RecoverSeconds; }

        return 0.0f;
    }

    FMars_RootMaw_ActionFrame Make_Frame(FMars_RootMaw_Spec InSpec, const FMars_Fragment_RootMaw_Action& InAction)
    {
        const auto Seconds = Get_PhaseSeconds(InSpec.Bite.Timing, InAction.Phase);
        const auto Alpha = Seconds > 0.0f ? Math::Clamp(InAction.PhaseElapsed / Seconds, 0.0f, 1.0f) : 0.0f;
        return FMars_RootMaw_ActionFrame(InAction.Kind, InAction.Phase, Alpha);
    }

    // A target the Maw may act on: alive as an entity and placed in the world.
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

mixin FMars_RootMaw_Spec Get_Spec(const FCk_Handle_RootMaw& Self)
{
    return Self.Get_Fragment(FMars_Fragment_RootMaw_Params).Spec;
}

mixin FCk_Handle_SurfaceMotion Get_Motion(const FCk_Handle_RootMaw& Self)
{
    return Self.Get_Fragment(FMars_Fragment_RootMaw).Motion;
}

mixin FCk_Handle_Monster Get_Monster(const FCk_Handle_RootMaw& Self)
{
    return Self.Get_Fragment(FMars_Fragment_RootMaw).Monster;
}

mixin FVector Get_Home(const FCk_Handle_RootMaw& Self)
{
    return Self.Get_Fragment(FMars_Fragment_RootMaw).Home;
}

mixin bool Get_IsDead(const FCk_Handle_RootMaw& Self)
{
    return Self.Get_Monster().Get_IsDead();
}

// The root: Clearance over the ground under the bulb, wherever the body has sunk to.
mixin FTransform Get_RootTransform(const FCk_Handle_RootMaw& Self)
{
    return utils_transform::Get_EntityCurrentTransform(Self.As_Transform());
}

mixin FVector Get_Location(const FCk_Handle_RootMaw& Self)
{
    return utils_transform::Get_EntityCurrentLocation(Self.As_Transform());
}

mixin FCk_Handle_SceneNode Get_Body(const FCk_Handle_RootMaw& Self)
{
    return Self.Get_Spec().Rig.Body;
}

// The body (the Maw as drawn: sunk while buried).
mixin FTransform Get_BodyTransform(const FCk_Handle_RootMaw& Self)
{
    return utils_transform::Get_EntityCurrentTransform(Self.Get_Body().As_Transform());
}

// The ground under the root (where its roots grow).
mixin FVector Get_GroundLocation(const FCk_Handle_RootMaw& Self)
{
    return Self.Get_RootTransform().TransformPosition(FVector(0.0, 0.0, -utils_root_maw::Clearance));
}

// The normal of the ground it glides on (its own up while it has none).
mixin FVector Get_SurfaceUp(const FCk_Handle_RootMaw& Self)
{
    const auto Up = utils_surface_motion::Get_SupportNormal(Self.Get_Motion()).GetSafeNormal();
    return Up.IsNearlyZero() ? Self.Get_RootTransform().GetRotation().GetUpVector() : Up;
}

mixin bool Get_IsGrounded(const FCk_Handle_RootMaw& Self)
{
    const auto Motion = Self.Get_Motion();
    return utils_surface_motion::Get_Status(Motion) == ECk_ProceduralAnimation_Status::Ready &&
        utils_surface_motion::Get_Support(Motion) == ECk_SurfaceMotion_Support::Grounded;
}

mixin EMars_RootMaw_Stance Get_Stance(const FCk_Handle_RootMaw& Self)
{
    return Self.Get_Fragment(FMars_Fragment_RootMaw_Posture).Stance;
}

// 0 buried .. 1 up.
mixin float32 Get_Emerge(const FCk_Handle_RootMaw& Self)
{
    return Self.Get_Fragment(FMars_Fragment_RootMaw_Posture).Emerge;
}

// Fully up and told to stay up: it may glide and bite.
mixin bool Get_IsEmerged(const FCk_Handle_RootMaw& Self)
{
    const auto& Posture = Self.Get_Fragment(FMars_Fragment_RootMaw_Posture);
    return Posture.Stance == EMars_RootMaw_Stance::Emerged && Posture.Emerge >= 1.0f;
}

// Fully sunk and told to stay down: the ambush.
mixin bool Get_IsBuried(const FCk_Handle_RootMaw& Self)
{
    const auto& Posture = Self.Get_Fragment(FMars_Fragment_RootMaw_Posture);
    return Posture.Stance == EMars_RootMaw_Stance::Buried && Posture.Emerge <= 0.0f;
}

// 0 shut .. 1 wide (the entity script draws 0 as the teeth meeting and 1 as its widest gape).
mixin float32 Get_JawOpen(const FCk_Handle_RootMaw& Self)
{
    return Self.Get_Fragment(FMars_Fragment_RootMaw_Mouth).JawOpen;
}

// Its velocity over the ground last frame (cm/s).
mixin FVector Get_GroundVelocity(const FCk_Handle_RootMaw& Self)
{
    return Self.Get_Fragment(FMars_Fragment_RootMaw_Travel).Velocity;
}

// How far it has glided since it was added (cm).
mixin float64 Get_DistanceTravelled(const FCk_Handle_RootMaw& Self)
{
    return Self.Get_Fragment(FMars_Fragment_RootMaw_Travel).Distance;
}

mixin FCk_Handle Get_Target(const FCk_Handle_RootMaw& Self)
{
    return Self.Get_Fragment(FMars_Fragment_RootMaw_Targeting).Target;
}

mixin bool Get_HasTarget(const FCk_Handle_RootMaw& Self)
{
    return utils_root_maw::Get_IsTargetValid(Self.Get_Target());
}

mixin FVector Get_TargetLocation(const FCk_Handle_RootMaw& Self)
{
    return utils_transform::Get_EntityCurrentLocation(Self.Get_Target().As_Transform());
}

// Within the senses' WakeRadius of the root (false with no target).
mixin bool Get_IsTargetNear(const FCk_Handle_RootMaw& Self)
{
    if (Self.Get_HasTarget() == false)
    { return false; }

    return (Self.Get_TargetLocation() - Self.Get_Location()).Size() <= Self.Get_Spec().Senses.WakeRadius;
}

mixin FMars_Fragment_RootMaw_Action Get_Action(const FCk_Handle_RootMaw& Self)
{
    return Self.Get_Fragment(FMars_Fragment_RootMaw_Action);
}

mixin FMars_RootMaw_ActionFrame Get_ActionFrame(const FCk_Handle_RootMaw& Self)
{
    return utils_root_maw::Make_Frame(Self.Get_Spec(), Self.Get_Fragment(FMars_Fragment_RootMaw_Action));
}

// The bite's blow centre now (world): the maw's front edge on the body.
mixin FVector Get_MouthLocation(const FCk_Handle_RootMaw& Self)
{
    return Self.Get_BodyTransform().TransformPosition(utils_root_maw::BiteMouth);
}

mixin FMars_Fragment_RootMaw_Hurt Get_Hurt(const FCk_Handle_RootMaw& Self)
{
    return Self.Get_Fragment(FMars_Fragment_RootMaw_Hurt);
}

mixin bool Get_IsFlinching(const FCk_Handle_RootMaw& Self)
{
    return Self.Get_Fragment(FMars_Fragment_RootMaw_Hurt).FlinchLeft > 0.0f;
}

// How far through the current flinch [0, 1] (1 when not flinching).
mixin float32 Get_FlinchAlpha(const FCk_Handle_RootMaw& Self)
{
    const auto Seconds = Self.Get_Spec().Vitals.FlinchSeconds;
    const auto Left = Self.Get_Fragment(FMars_Fragment_RootMaw_Hurt).FlinchLeft;
    return Seconds > 0.0f ? Math::Clamp(1.0f - Left / Seconds, 0.0f, 1.0f) : 1.0f;
}

// A blow found it buried and it has not come fully up since.
mixin bool Get_IsStartled(const FCk_Handle_RootMaw& Self)
{
    return Self.Get_Fragment(FMars_Fragment_RootMaw_Hurt).Startled;
}

// An action runs, or a Start is queued.
mixin bool Get_IsActionBusy(const FCk_Handle_RootMaw& Self)
{
    if (Self.Get_Fragment(FMars_Fragment_RootMaw_Action).Kind != EMars_RootMaw_Action::None)
    { return true; }

    return Self.Has_Fragment(FMars_Fragment_RootMaw_Requests) &&
        Self.Get_Fragment(FMars_Fragment_RootMaw_Requests).StartRequests.Num() > 0;
}

// Whether InAction on InTarget would be admitted now (the drain asks exactly this).
mixin EMars_RootMaw_Admission Get_Admission(const FCk_Handle_RootMaw& Self, EMars_RootMaw_Action InAction, FCk_Handle InTarget)
{
    if (Self.Get_IsDead())
    { return EMars_RootMaw_Admission::Dead; }

    if (Self.Get_IsEmerged() == false)
    { return EMars_RootMaw_Admission::NotEmerged; }

    const auto& Action = Self.Get_Fragment(FMars_Fragment_RootMaw_Action);
    if (Action.Kind != EMars_RootMaw_Action::None)
    { return EMars_RootMaw_Admission::Busy; }

    if (Self.Get_IsFlinching())
    { return EMars_RootMaw_Admission::Flinching; }

    if (Action.BiteCooldown > 0.0f)
    { return EMars_RootMaw_Admission::Cooldown; }

    if (utils_root_maw::Get_IsTargetValid(InTarget) == false)
    { return EMars_RootMaw_Admission::NoTarget; }

    if (Self.Get_IsGrounded() == false)
    { return EMars_RootMaw_Admission::Ungrounded; }

    const auto Spec = Self.Get_Spec();
    const auto Root = Self.Get_RootTransform();
    const auto Up = Self.Get_SurfaceUp();
    const auto Offset = utils_transform::Get_EntityCurrentLocation(InTarget.As_Transform()) - Root.GetLocation();
    const auto Along = Offset - Up * Offset.DotProduct(Up);
    if (Along.Size() > Spec.Bite.Range)
    { return EMars_RootMaw_Admission::OutOfRange; }

    const auto Forward = utils_root_maw::Get_Tangent(Root.GetRotation().GetForwardVector(), Up);
    if (Along.IsNearlyZero() == false && Along.GetSafeNormal().DotProduct(Forward) < Math::Cos(Math::DegreesToRadians(Spec.Bite.FacingDegrees)))
    { return EMars_RootMaw_Admission::Facing; }

    return EMars_RootMaw_Admission::Admitted;
}

//--------------------------------------------------------------------------------------------------------------------------
// Requests
//--------------------------------------------------------------------------------------------------------------------------

mixin void Request_TakeHit(FCk_Handle_RootMaw& Self, const FMars_Request_RootMaw_TakeHit& InRequest)
{
    Self.AddOrGet_Fragment(FMars_Fragment_RootMaw_Requests).TakeHitRequests.Add(InRequest);
}

mixin void Request_Drive(FCk_Handle_RootMaw& Self, const FMars_Request_RootMaw_Drive& InRequest)
{
    Self.AddOrGet_Fragment(FMars_Fragment_RootMaw_Requests).DriveRequests.Add(InRequest);
}

mixin void Request_Stop(FCk_Handle_RootMaw& Self, const FMars_Request_RootMaw_Stop& InRequest)
{
    Self.AddOrGet_Fragment(FMars_Fragment_RootMaw_Requests).StopRequests.Add(InRequest);
}

mixin void Request_SetStance(FCk_Handle_RootMaw& Self, const FMars_Request_RootMaw_SetStance& InRequest)
{
    Self.AddOrGet_Fragment(FMars_Fragment_RootMaw_Requests).SetStanceRequests.Add(InRequest);
}

mixin void Request_Gape(FCk_Handle_RootMaw& Self, const FMars_Request_RootMaw_Gape& InRequest)
{
    Self.AddOrGet_Fragment(FMars_Fragment_RootMaw_Requests).GapeRequests.Add(InRequest);
}

mixin void Request_Start(FCk_Handle_RootMaw& Self, const FMars_Request_RootMaw_Start& InRequest)
{
    Self.AddOrGet_Fragment(FMars_Fragment_RootMaw_Requests).StartRequests.Add(InRequest);
}

mixin void Request_Cancel(FCk_Handle_RootMaw& Self, const FMars_Request_RootMaw_Cancel& InRequest)
{
    Self.AddOrGet_Fragment(FMars_Fragment_RootMaw_Requests).CancelRequests.Add(InRequest);
}

//--------------------------------------------------------------------------------------------------------------------------
// Signal Binding
//--------------------------------------------------------------------------------------------------------------------------

mixin void BindTo_OnActionPhase(FCk_Handle_RootMaw& Self, FMars_Delegate_RootMaw_OnActionPhase InDelegate)
{
    auto& Signals = Self.AddOrGet_Fragment(FMars_Fragment_RootMaw_Signals);
    Signals.OnActionPhase.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnActionPhase(FCk_Handle_RootMaw& Self, FMars_Delegate_RootMaw_OnActionPhase InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_RootMaw_Signals))
    { Self.Get_Fragment(FMars_Fragment_RootMaw_Signals).OnActionPhase.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName()); }
}

mixin void BindTo_OnBlowLanded(FCk_Handle_RootMaw& Self, FMars_Delegate_RootMaw_OnBlowLanded InDelegate)
{
    auto& Signals = Self.AddOrGet_Fragment(FMars_Fragment_RootMaw_Signals);
    Signals.OnBlowLanded.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnBlowLanded(FCk_Handle_RootMaw& Self, FMars_Delegate_RootMaw_OnBlowLanded InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_RootMaw_Signals))
    { Self.Get_Fragment(FMars_Fragment_RootMaw_Signals).OnBlowLanded.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName()); }
}

mixin void BindTo_OnStance(FCk_Handle_RootMaw& Self, FMars_Delegate_RootMaw_OnStance InDelegate)
{
    auto& Signals = Self.AddOrGet_Fragment(FMars_Fragment_RootMaw_Signals);
    Signals.OnStance.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnStance(FCk_Handle_RootMaw& Self, FMars_Delegate_RootMaw_OnStance InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_RootMaw_Signals))
    { Self.Get_Fragment(FMars_Fragment_RootMaw_Signals).OnStance.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName()); }
}
