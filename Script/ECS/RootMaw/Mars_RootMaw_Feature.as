//--------------------------------------------------------------------------------------------------------------------------
// Dynamic Handle Definition
//--------------------------------------------------------------------------------------------------------------------------

asset Mars_RootMawHandle of UCkDynamic_HandleDefinition
{
    TypeName = "FCk_Handle_RootMaw";
    RequiredFragments.Add(FMars_Feature_RootMaw);
    Description = "The Root Maw: a turnip-headed plant that lies buried with only its leaves showing, bursts up to glide after its prey on a bed of roots, and bites with its hinged maw";
}

struct FMars_Feature_RootMaw {}

// Until UMars_Processor_RootMaw_Setup has bound the body zone's hits to TakeHit.
struct FMars_Tag_RootMaw_NeedsSetup {}

//--------------------------------------------------------------------------------------------------------------------------
// Spec
//--------------------------------------------------------------------------------------------------------------------------

// How fast it glides and where it keeps to.
struct FMars_RootMaw_Locomotion
{
    // The Hunt state's chasing speed.
    UPROPERTY()
    float32 HuntSpeed = 210.0f;

    // Back to its spot after losing the target.
    UPROPERTY()
    float32 ReturnSpeed = 120.0f;

    // Degrees a second it turns on the ground.
    UPROPERTY()
    float32 TurnRate = 200.0f;

    // Targets are only taken within this distance of home (where it spawned); it glides back there and burrows again.
    UPROPERTY()
    float32 HomeRadius = 2000.0f;
}

mixin FMars_Validation Validate(const FMars_RootMaw_Locomotion& Self)
{
    if (utils_root_maw::Get_IsPositiveFinite(Self.HuntSpeed) == false || utils_root_maw::Get_IsPositiveFinite(Self.ReturnSpeed) == false ||
        utils_root_maw::Get_IsPositiveFinite(Self.TurnRate) == false || utils_root_maw::Get_IsPositiveFinite(Self.HomeRadius) == false)
    { return FMars_Validation(f"RootMaw has a non-positive HuntSpeed [{Self.HuntSpeed}], ReturnSpeed [{Self.ReturnSpeed}], TurnRate [{Self.TurnRate}] or HomeRadius [{Self.HomeRadius}]"); }

    return FMars_Validation();
}

// How fast it bursts up out of the ground and sinks back into it (s, the whole way).
struct FMars_RootMaw_Posture
{
    UPROPERTY()
    float32 EmergeSeconds = 0.55f;

    UPROPERTY()
    float32 BurrowSeconds = 1.4f;
}

mixin FMars_Validation Validate(const FMars_RootMaw_Posture& Self)
{
    if (utils_root_maw::Get_IsPositiveFinite(Self.EmergeSeconds) == false || utils_root_maw::Get_IsPositiveFinite(Self.BurrowSeconds) == false)
    { return FMars_Validation(f"RootMaw has a non-positive EmergeSeconds [{Self.EmergeSeconds}] or BurrowSeconds [{Self.BurrowSeconds}]"); }

    return FMars_Validation();
}

// The phase lengths of a timed action (s): Windup, then Active, then Recover, then the action is over and its cooldown runs.
struct FMars_RootMaw_ActionTiming
{
    UPROPERTY()
    float32 WindupSeconds = 0.45f;

    UPROPERTY()
    float32 ActiveSeconds = 0.14f;

    UPROPERTY()
    float32 RecoverSeconds = 0.5f;

    UPROPERTY()
    float32 CooldownSeconds = 0.9f;

    FMars_RootMaw_ActionTiming() {}

    FMars_RootMaw_ActionTiming(float32 InWindupSeconds, float32 InActiveSeconds, float32 InRecoverSeconds, float32 InCooldownSeconds)
    {
        WindupSeconds = InWindupSeconds;
        ActiveSeconds = InActiveSeconds;
        RecoverSeconds = InRecoverSeconds;
        CooldownSeconds = InCooldownSeconds;
    }
}

mixin FMars_Validation Validate(const FMars_RootMaw_ActionTiming& Self)
{
    if (utils_root_maw::Get_IsPositiveFinite(Self.WindupSeconds) == false || utils_root_maw::Get_IsPositiveFinite(Self.ActiveSeconds) == false ||
        utils_root_maw::Get_IsPositiveFinite(Self.RecoverSeconds) == false || Math::IsFinite(Self.CooldownSeconds) == false || Self.CooldownSeconds < 0.0f)
    { return FMars_Validation(f"RootMaw action has a non-positive phase (windup [{Self.WindupSeconds}], active [{Self.ActiveSeconds}], recover [{Self.RecoverSeconds}]) or a negative cooldown [{Self.CooldownSeconds}]"); }

    return FMars_Validation();
}

// What a landed blow does.
struct FMars_RootMaw_Blow
{
    UPROPERTY()
    float32 Damage = 22.0f;

    UPROPERTY(meta = (Categories = "DamageType"))
    FGameplayTag DamageType = GameplayTags::DamageType_Mars_Crush;

    // The swept sphere's radius.
    UPROPERTY()
    float32 Radius = 40.0f;

    FMars_RootMaw_Blow() {}

    FMars_RootMaw_Blow(float32 InDamage, FGameplayTag InDamageType, float32 InRadius)
    {
        Damage = InDamage;
        DamageType = InDamageType;
        Radius = InRadius;
    }
}

// The bite: through the windup it turns to the target and its maw gapes wide; through the active phase it lunges along the
// line it faced at LungeSpeed and the jaw slams shut, the maw's front edge (utils_root_maw::BiteMouth) sweeping
// Blow.Radius, each target hit at most once; through the recovery it stands, the jaw shut.
struct FMars_RootMaw_Bite
{
    UPROPERTY()
    FMars_RootMaw_ActionTiming Timing = FMars_RootMaw_ActionTiming(0.45f, 0.14f, 0.5f, 0.9f);

    UPROPERTY()
    FMars_RootMaw_Blow Blow = FMars_RootMaw_Blow(22.0f, GameplayTags::DamageType_Mars_Crush, 40.0f);

    // A bite starts only on a target within this distance of its axis, on the ground ...
    UPROPERTY()
    float32 Range = 140.0f;

    // ... and within this angle of its facing.
    UPROPERTY()
    float32 FacingDegrees = 40.0f;

    UPROPERTY()
    float32 LungeSpeed = 450.0f;
}

mixin FMars_Validation Validate(const FMars_RootMaw_Bite& Self)
{
    const auto TimingValidation = Self.Timing.Validate();
    if (TimingValidation.IsValid() == false)
    { return TimingValidation; }

    if (utils_root_maw::Get_IsPositiveFinite(Self.Range) == false || utils_root_maw::Get_IsPositiveFinite(Self.Blow.Radius) == false ||
        Self.FacingDegrees <= 0.0f || Self.FacingDegrees > 180.0f || Math::IsFinite(Self.Blow.Damage) == false || Self.Blow.Damage < 0.0f ||
        Math::IsFinite(Self.LungeSpeed) == false || Self.LungeSpeed < 0.0f)
    { return FMars_Validation(f"RootMaw bite has a bad Range [{Self.Range}], FacingDegrees [{Self.FacingDegrees}], Radius [{Self.Blow.Radius}], Damage [{Self.Blow.Damage}] or LungeSpeed [{Self.LungeSpeed}]"); }

    return FMars_Validation();
}

// Target sensing (UMars_Processor_RootMaw_Targeting): among the entities tagged TAG_MarsCombatTarget and Hostile to it.
struct FMars_RootMaw_Senses
{
    // A buried Maw bursts up when its target comes this close.
    UPROPERTY()
    float32 WakeRadius = 450.0f;

    UPROPERTY()
    float32 AcquireRadius = 1400.0f;

    // A held target is kept until it leaves this radius (hysteresis over AcquireRadius) or home's HomeRadius.
    UPROPERTY()
    float32 LoseRadius = 2000.0f;

    UPROPERTY()
    float32 SenseInterval = 0.2f;
}

mixin FMars_Validation Validate(const FMars_RootMaw_Senses& Self)
{
    if (utils_root_maw::Get_IsPositiveFinite(Self.WakeRadius) == false || Self.AcquireRadius < Self.WakeRadius ||
        Self.LoseRadius < Self.AcquireRadius || utils_root_maw::Get_IsPositiveFinite(Self.SenseInterval) == false)
    { return FMars_Validation(f"RootMaw has a bad WakeRadius [{Self.WakeRadius}], AcquireRadius [{Self.AcquireRadius}], LoseRadius [{Self.LoseRadius}] or SenseInterval [{Self.SenseInterval}]"); }

    return FMars_Validation();
}

// Health, and what a blow that does not kill does: the Maw flinches for FlinchSeconds (it stops, the jaw slams, a bite's
// windup starts over once it passes; an active bite runs on).
struct FMars_RootMaw_Vitals
{
    UPROPERTY()
    float32 BodyHealth = 140.0f;

    // From death to despawn (it sinks back into the ground meanwhile).
    UPROPERTY()
    float32 CorpseSeconds = 5.0f;

    UPROPERTY()
    float32 FlinchSeconds = 0.3f;
}

mixin FMars_Validation Validate(const FMars_RootMaw_Vitals& Self)
{
    if (utils_root_maw::Get_IsPositiveFinite(Self.BodyHealth) == false || Self.CorpseSeconds < 0.0f || Self.FlinchSeconds < 0.0f)
    { return FMars_Validation(f"RootMaw has a non-positive BodyHealth [{Self.BodyHealth}] or a negative CorpseSeconds [{Self.CorpseSeconds}] or FlinchSeconds [{Self.FlinchSeconds}]"); }

    return FMars_Validation();
}

// The transform the kernel moves, built by the entity script (features own no visuals): the body, a scene node on the root
// at the ground under the bulb that the kernel sinks utils_root_maw::BuryDrop while the Maw lies buried. Everything seen
// hangs off it.
struct FMars_RootMaw_Rig
{
    UPROPERTY()
    FCk_Handle_SceneNode Body;
}

struct FMars_RootMaw_Spec
{
    UPROPERTY()
    FMars_RootMaw_Locomotion Locomotion;

    UPROPERTY()
    FMars_RootMaw_Posture Posture;

    UPROPERTY()
    FMars_RootMaw_Bite Bite;

    UPROPERTY()
    FMars_RootMaw_Senses Senses;

    UPROPERTY()
    FMars_RootMaw_Vitals Vitals;

    // Built by the entity script.
    UPROPERTY()
    FMars_RootMaw_Rig Rig;
}

mixin FMars_Validation Validate(const FMars_RootMaw_Spec& Self)
{
    auto Validation = Self.Locomotion.Validate();
    if (Validation.IsValid() == false)
    { return Validation; }

    Validation = Self.Posture.Validate();
    if (Validation.IsValid() == false)
    { return Validation; }

    Validation = Self.Bite.Validate();
    if (Validation.IsValid() == false)
    { return Validation; }

    Validation = Self.Senses.Validate();
    if (Validation.IsValid() == false)
    { return Validation; }

    Validation = Self.Vitals.Validate();
    if (Validation.IsValid() == false)
    { return Validation; }

    if (ck::Is_NOT_Valid(Self.Rig.Body))
    { return FMars_Validation("RootMaw rig has no Body"); }

    return FMars_Validation();
}

//--------------------------------------------------------------------------------------------------------------------------
// Params
//--------------------------------------------------------------------------------------------------------------------------

struct FMars_Fragment_RootMaw_Params
{
    UPROPERTY()
    FMars_RootMaw_Spec Spec;
}

//--------------------------------------------------------------------------------------------------------------------------
// State
//--------------------------------------------------------------------------------------------------------------------------

// Composed by Add; never written afterwards.
struct FMars_Fragment_RootMaw
{
    UPROPERTY()
    FCk_Handle_SurfaceMotion Motion;

    UPROPERTY()
    FCk_Handle_Monster Monster;

    UPROPERTY()
    FCk_Handle_DamageDealer Dealer;

    // The root's location at Add.
    UPROPERTY()
    FVector Home;
}

// What it is told to do between actions (the control layer's Drive / Stop). A running action overrides it; buried (or
// still coming up) it does not move.
struct FMars_Fragment_RootMaw_Drive
{
    UPROPERTY()
    FVector Direction = FVector::ZeroVector;

    UPROPERTY()
    float32 Speed = 0.0f;
}

enum EMars_RootMaw_Stance
{
    // Sunk into the ground with only its leaves showing: the ambush.
    Buried,
    Emerged
}

// Emerge runs 0 (buried) .. 1 (up) toward Stance; the body sinks BuryDrop * (1 - Get_EaseInOut(Emerge)).
struct FMars_Fragment_RootMaw_Posture
{
    UPROPERTY()
    EMars_RootMaw_Stance Stance = EMars_RootMaw_Stance::Buried;

    UPROPERTY()
    float32 Emerge = 0.0f;

    // The body node's last drop (cm below the ground): the processor moves the node only when this changes.
    UPROPERTY()
    float32 AppliedDrop = -1.0f;
}

// The maw: Gape is the latched opening the control layer asks for between bites (0 shut .. 1 wide); JawOpen is the jaw's
// opening now, eased toward Gape, or set by the bite while one runs.
struct FMars_Fragment_RootMaw_Mouth
{
    UPROPERTY()
    float32 Gape = 0.0f;

    UPROPERTY()
    float32 JawOpen = 0.0f;
}

// Its glide over the ground, measured by the tick from the root's own motion (the root trail and anything else that wants
// to follow it read this): the ground velocity last frame and the distance it has glided since Add.
struct FMars_Fragment_RootMaw_Travel
{
    UPROPERTY()
    FVector Velocity = FVector::ZeroVector;

    UPROPERTY()
    float64 Distance = 0.0;

    UPROPERTY()
    FVector LastLocation = FVector::ZeroVector;

    UPROPERTY()
    bool HasSample = false;
}

enum EMars_RootMaw_Action
{
    None,
    Bite
}

enum EMars_RootMaw_ActionPhase
{
    None,
    Windup,
    Active,
    Recover
}

// Why a Start was refused (the drain's verdict, also what the admission getter answers).
enum EMars_RootMaw_Admission
{
    Admitted,
    Dead,
    NotEmerged,
    Busy,
    Flinching,
    Cooldown,
    NoTarget,
    Ungrounded,
    OutOfRange,
    Facing
}

// The one running action and its clocks. Written only by the request drain and the action tick.
struct FMars_Fragment_RootMaw_Action
{
    UPROPERTY()
    EMars_RootMaw_Action Kind = EMars_RootMaw_Action::None;

    UPROPERTY()
    EMars_RootMaw_ActionPhase Phase = EMars_RootMaw_ActionPhase::None;

    // Seconds into the current phase.
    UPROPERTY()
    float32 PhaseElapsed = 0.0f;

    // Bumped by every admitted Start.
    UPROPERTY()
    int32 Generation = 0;

    UPROPERTY()
    FCk_Handle Target;

    // On the ground: the line it faces through the windup and lunges along.
    UPROPERTY()
    FVector CommittedDirection = FVector::ForwardVector;

    // The maw's place last frame: this frame's sweep starts there.
    UPROPERTY()
    FVector LastBlowCentre;

    // The zones this action has hurt (each at most once).
    UPROPERTY()
    TArray<FCk_Handle_HitZone> HitZones;

    UPROPERTY()
    float32 BiteCooldown = 0.0f;

    // The jaw's opening when the windup began (the windup gapes from there).
    UPROPERTY()
    float32 JawAtStart = 0.0f;
}

// What blows have done to it. Written only by the request drain (a TakeHit) and the tick (the clocks).
struct FMars_Fragment_RootMaw_Hurt
{
    // Seconds of flinch left (0: not flinching).
    UPROPERTY()
    float32 FlinchLeft = 0.0f;

    // Bumped by every flinch, so a reader sees each one.
    UPROPERTY()
    int32 FlinchCount = 0;

    // Along the ground, from the Maw toward where the last flinching blow came from (zero when it cannot tell).
    UPROPERTY()
    FVector FlinchFrom = FVector::ZeroVector;

    // A blow found it buried: it bursts up whatever the distance. Held until it is next fully up (or dies).
    UPROPERTY()
    bool Startled = false;
}

struct FMars_Fragment_RootMaw_Targeting
{
    UPROPERTY()
    FCk_Handle Target;

    UPROPERTY()
    float32 SenseClock = 0.0f;
}

//--------------------------------------------------------------------------------------------------------------------------
// Signals
//--------------------------------------------------------------------------------------------------------------------------

// Every phase change of an action, None last (normal end and cancel alike).
delegate void FMars_Delegate_RootMaw_OnActionPhase(FCk_Handle_RootMaw InMaw, EMars_RootMaw_Action InAction, EMars_RootMaw_ActionPhase InPhase);
event void FMars_Delegate_RootMaw_OnActionPhase_MC(FCk_Handle_RootMaw InMaw, EMars_RootMaw_Action InAction, EMars_RootMaw_ActionPhase InPhase);

// A blow landed on a zone (the zone's own OnHit carries the damage).
delegate void FMars_Delegate_RootMaw_OnBlowLanded(FCk_Handle_RootMaw InMaw, EMars_RootMaw_Action InAction, FCk_Handle_HitZone InZone);
event void FMars_Delegate_RootMaw_OnBlowLanded_MC(FCk_Handle_RootMaw InMaw, EMars_RootMaw_Action InAction, FCk_Handle_HitZone InZone);

// Emerge reached its stance (fully up, or fully buried).
delegate void FMars_Delegate_RootMaw_OnStance(FCk_Handle_RootMaw InMaw, EMars_RootMaw_Stance InStance);
event void FMars_Delegate_RootMaw_OnStance_MC(FCk_Handle_RootMaw InMaw, EMars_RootMaw_Stance InStance);

struct FMars_Fragment_RootMaw_Signals
{
    FMars_Delegate_RootMaw_OnActionPhase_MC OnActionPhase;
    FMars_Delegate_RootMaw_OnBlowLanded_MC OnBlowLanded;
    FMars_Delegate_RootMaw_OnStance_MC OnStance;
}

//--------------------------------------------------------------------------------------------------------------------------
// Requests
//--------------------------------------------------------------------------------------------------------------------------

// Latched: it glides along InDirection (laid onto the ground) at InSpeed until the next Drive or Stop.
struct FMars_Request_RootMaw_Drive
{
    UPROPERTY()
    FVector Direction;

    UPROPERTY()
    float32 Speed = 0.0f;

    FMars_Request_RootMaw_Drive() {}

    FMars_Request_RootMaw_Drive(FVector InDirection, float32 InSpeed)
    {
        Direction = InDirection;
        Speed = InSpeed;
    }
}

// A blow landed on its body zone (fed from the zone's OnHit with the scaled event). Unless it is dead the Maw flinches;
// found buried it is startled up (the jaw pops wide) and takes the blow's instigator as its target when that is Hostile;
// up and holding no target it takes the instigator too.
struct FMars_Request_RootMaw_TakeHit
{
    UPROPERTY()
    FMars_DamageEvent Event;

    FMars_Request_RootMaw_TakeHit() {}

    FMars_Request_RootMaw_TakeHit(FMars_DamageEvent InEvent)
    {
        Event = InEvent;
    }
}

struct FMars_Request_RootMaw_Stop
{
    UPROPERTY()
    bool _Placeholder = false;
}

// Burst up out of the ground, or sink back into it (Emerge runs there over EmergeSeconds / BurrowSeconds).
struct FMars_Request_RootMaw_SetStance
{
    UPROPERTY()
    EMars_RootMaw_Stance Stance = EMars_RootMaw_Stance::Emerged;

    FMars_Request_RootMaw_SetStance() {}

    FMars_Request_RootMaw_SetStance(EMars_RootMaw_Stance InStance)
    {
        Stance = InStance;
    }
}

// Latched: how far the maw hangs open between bites, 0 shut .. 1 wide.
struct FMars_Request_RootMaw_Gape
{
    UPROPERTY()
    float32 Amount = 0.0f;

    FMars_Request_RootMaw_Gape() {}

    FMars_Request_RootMaw_Gape(float32 InAmount)
    {
        Amount = InAmount;
    }
}

// Starts InAction on InTarget if it is admissible now (Get_Admission); a refusal is dropped.
struct FMars_Request_RootMaw_Start
{
    UPROPERTY()
    EMars_RootMaw_Action Action = EMars_RootMaw_Action::None;

    UPROPERTY()
    FCk_Handle Target;

    FMars_Request_RootMaw_Start() {}

    FMars_Request_RootMaw_Start(EMars_RootMaw_Action InAction, FCk_Handle InTarget)
    {
        Action = InAction;
        Target = InTarget;
    }
}

// Ends the running action at once (no recovery); its cooldown still starts.
struct FMars_Request_RootMaw_Cancel
{
    UPROPERTY()
    bool _Placeholder = false;
}

// Applied Cancel -> TakeHit -> Stop -> Drive -> SetStance -> Gape -> Start, each kind in arrival order.
struct FMars_Fragment_RootMaw_Requests
{
    UPROPERTY()
    TArray<FMars_Request_RootMaw_Cancel> CancelRequests;

    UPROPERTY()
    TArray<FMars_Request_RootMaw_TakeHit> TakeHitRequests;

    UPROPERTY()
    TArray<FMars_Request_RootMaw_Stop> StopRequests;

    UPROPERTY()
    TArray<FMars_Request_RootMaw_Drive> DriveRequests;

    UPROPERTY()
    TArray<FMars_Request_RootMaw_SetStance> SetStanceRequests;

    UPROPERTY()
    TArray<FMars_Request_RootMaw_Gape> GapeRequests;

    UPROPERTY()
    TArray<FMars_Request_RootMaw_Start> StartRequests;
}
