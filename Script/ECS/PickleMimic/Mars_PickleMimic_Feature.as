//--------------------------------------------------------------------------------------------------------------------------
// Dynamic Handle Definition
//--------------------------------------------------------------------------------------------------------------------------

asset Mars_PickleMimicHandle of UCkDynamic_HandleDefinition
{
    TypeName = "FCk_Handle_PickleMimic";
    RequiredFragments.Add(FMars_Feature_PickleMimic);
    Description = "The pickle-jar mimic: a jar that sits disguised, stands up on four floating feet (a diagonal trot) to chase, and bites with its hinged lid";
}

struct FMars_Feature_PickleMimic {}

// Until UMars_Processor_PickleMimic_Setup has bound the body zone's hits to TakeHit.
struct FMars_Tag_PickleMimic_NeedsSetup {}

//--------------------------------------------------------------------------------------------------------------------------
// Spec
//--------------------------------------------------------------------------------------------------------------------------

// How fast it walks and where it keeps to.
struct FMars_PickleMimic_Locomotion
{
    // The Hunt state's chasing speed (short strides: the trot caps it).
    UPROPERTY()
    float32 HuntSpeed = 190.0f;

    // Back to its spot after losing the target.
    UPROPERTY()
    float32 ReturnSpeed = 110.0f;

    // Degrees a second it turns on the ground.
    UPROPERTY()
    float32 TurnRate = 240.0f;

    // Targets are only taken within this distance of home (where it spawned); it walks back there and sits down again.
    UPROPERTY()
    float32 HomeRadius = 2000.0f;
}

mixin FMars_Validation Validate(const FMars_PickleMimic_Locomotion& Self)
{
    if (utils_pickle_mimic::Get_IsPositiveFinite(Self.HuntSpeed) == false || utils_pickle_mimic::Get_IsPositiveFinite(Self.ReturnSpeed) == false ||
        utils_pickle_mimic::Get_IsPositiveFinite(Self.TurnRate) == false || utils_pickle_mimic::Get_IsPositiveFinite(Self.HomeRadius) == false)
    { return FMars_Validation(f"PickleMimic has a non-positive HuntSpeed [{Self.HuntSpeed}], ReturnSpeed [{Self.ReturnSpeed}], TurnRate [{Self.TurnRate}] or HomeRadius [{Self.HomeRadius}]"); }

    return FMars_Validation();
}

// How fast it stands up out of its disguise and sits back down into it (s, the whole way).
struct FMars_PickleMimic_Posture
{
    UPROPERTY()
    float32 StandSeconds = 0.45f;

    UPROPERTY()
    float32 TuckSeconds = 1.0f;
}

mixin FMars_Validation Validate(const FMars_PickleMimic_Posture& Self)
{
    if (utils_pickle_mimic::Get_IsPositiveFinite(Self.StandSeconds) == false || utils_pickle_mimic::Get_IsPositiveFinite(Self.TuckSeconds) == false)
    { return FMars_Validation(f"PickleMimic has a non-positive StandSeconds [{Self.StandSeconds}] or TuckSeconds [{Self.TuckSeconds}]"); }

    return FMars_Validation();
}

// The phase lengths of a timed action (s): Windup, then Active, then Recover, then the action is over and its cooldown runs.
struct FMars_PickleMimic_ActionTiming
{
    UPROPERTY()
    float32 WindupSeconds = 0.4f;

    UPROPERTY()
    float32 ActiveSeconds = 0.14f;

    UPROPERTY()
    float32 RecoverSeconds = 0.5f;

    UPROPERTY()
    float32 CooldownSeconds = 0.9f;

    FMars_PickleMimic_ActionTiming() {}

    FMars_PickleMimic_ActionTiming(float32 InWindupSeconds, float32 InActiveSeconds, float32 InRecoverSeconds, float32 InCooldownSeconds)
    {
        WindupSeconds = InWindupSeconds;
        ActiveSeconds = InActiveSeconds;
        RecoverSeconds = InRecoverSeconds;
        CooldownSeconds = InCooldownSeconds;
    }
}

mixin FMars_Validation Validate(const FMars_PickleMimic_ActionTiming& Self)
{
    if (utils_pickle_mimic::Get_IsPositiveFinite(Self.WindupSeconds) == false || utils_pickle_mimic::Get_IsPositiveFinite(Self.ActiveSeconds) == false ||
        utils_pickle_mimic::Get_IsPositiveFinite(Self.RecoverSeconds) == false || Math::IsFinite(Self.CooldownSeconds) == false || Self.CooldownSeconds < 0.0f)
    { return FMars_Validation(f"PickleMimic action has a non-positive phase (windup [{Self.WindupSeconds}], active [{Self.ActiveSeconds}], recover [{Self.RecoverSeconds}]) or a negative cooldown [{Self.CooldownSeconds}]"); }

    return FMars_Validation();
}

// What a landed blow does.
struct FMars_PickleMimic_Blow
{
    UPROPERTY()
    float32 Damage = 20.0f;

    UPROPERTY(meta = (Categories = "DamageType"))
    FGameplayTag DamageType = GameplayTags::DamageType_Mars_Crush;

    // The swept sphere's radius.
    UPROPERTY()
    float32 Radius = 38.0f;

    FMars_PickleMimic_Blow() {}

    FMars_PickleMimic_Blow(float32 InDamage, FGameplayTag InDamageType, float32 InRadius)
    {
        Damage = InDamage;
        DamageType = InDamageType;
        Radius = InRadius;
    }
}

// The bite: through the windup it turns to the target and its lid gapes wide; through the active phase it lunges along the
// line it faced at LungeSpeed and the lid slams shut, the mouth (utils_pickle_mimic::BiteMouth) sweeping Blow.Radius, each
// target hit at most once; through the recovery it stands, the lid shut.
struct FMars_PickleMimic_Bite
{
    UPROPERTY()
    FMars_PickleMimic_ActionTiming Timing = FMars_PickleMimic_ActionTiming(0.4f, 0.14f, 0.5f, 0.9f);

    UPROPERTY()
    FMars_PickleMimic_Blow Blow = FMars_PickleMimic_Blow(20.0f, GameplayTags::DamageType_Mars_Crush, 38.0f);

    // A bite starts only on a target within this distance of the jar's axis, on the ground ...
    UPROPERTY()
    float32 Range = 130.0f;

    // ... and within this angle of its facing.
    UPROPERTY()
    float32 FacingDegrees = 40.0f;

    UPROPERTY()
    float32 LungeSpeed = 420.0f;
}

mixin FMars_Validation Validate(const FMars_PickleMimic_Bite& Self)
{
    const auto TimingValidation = Self.Timing.Validate();
    if (TimingValidation.IsValid() == false)
    { return TimingValidation; }

    if (utils_pickle_mimic::Get_IsPositiveFinite(Self.Range) == false || utils_pickle_mimic::Get_IsPositiveFinite(Self.Blow.Radius) == false ||
        Self.FacingDegrees <= 0.0f || Self.FacingDegrees > 180.0f || Math::IsFinite(Self.Blow.Damage) == false || Self.Blow.Damage < 0.0f ||
        Math::IsFinite(Self.LungeSpeed) == false || Self.LungeSpeed < 0.0f)
    { return FMars_Validation(f"PickleMimic bite has a bad Range [{Self.Range}], FacingDegrees [{Self.FacingDegrees}], Radius [{Self.Blow.Radius}], Damage [{Self.Blow.Damage}] or LungeSpeed [{Self.LungeSpeed}]"); }

    return FMars_Validation();
}

// Target sensing (UMars_Processor_PickleMimic_Targeting): among the entities tagged TAG_MarsCombatTarget and Hostile to it.
struct FMars_PickleMimic_Senses
{
    // A disguised mimic wakes when its target comes this close.
    UPROPERTY()
    float32 WakeRadius = 400.0f;

    UPROPERTY()
    float32 AcquireRadius = 1400.0f;

    // A held target is kept until it leaves this radius (hysteresis over AcquireRadius) or home's HomeRadius.
    UPROPERTY()
    float32 LoseRadius = 2000.0f;

    UPROPERTY()
    float32 SenseInterval = 0.2f;
}

mixin FMars_Validation Validate(const FMars_PickleMimic_Senses& Self)
{
    if (utils_pickle_mimic::Get_IsPositiveFinite(Self.WakeRadius) == false || Self.AcquireRadius < Self.WakeRadius ||
        Self.LoseRadius < Self.AcquireRadius || utils_pickle_mimic::Get_IsPositiveFinite(Self.SenseInterval) == false)
    { return FMars_Validation(f"PickleMimic has a bad WakeRadius [{Self.WakeRadius}], AcquireRadius [{Self.AcquireRadius}], LoseRadius [{Self.LoseRadius}] or SenseInterval [{Self.SenseInterval}]"); }

    return FMars_Validation();
}

// Health, and what a blow that does not kill does: the mimic flinches for FlinchSeconds (it stops, the lid slams, a bite's
// windup starts over once it passes; an active bite runs on), and its glass cracks in stages as BodyHealth falls: stage 1
// at or below CrackedBelow of its maximum, stage 2 at or below HeavilyCrackedBelow (it never mends). On death its jar
// spills SpilledPickles pickles (OnSpill, once).
struct FMars_PickleMimic_Vitals
{
    UPROPERTY()
    float32 BodyHealth = 120.0f;

    // From death to despawn.
    UPROPERTY()
    float32 CorpseSeconds = 6.0f;

    UPROPERTY()
    float32 FlinchSeconds = 0.3f;

    UPROPERTY()
    float32 CrackedBelow = 0.7f;

    UPROPERTY()
    float32 HeavilyCrackedBelow = 0.35f;

    // The brine shader's Pickle Jar draws eight (a ring of seven round the wall and one in the middle).
    UPROPERTY()
    int32 SpilledPickles = 8;
}

mixin FMars_Validation Validate(const FMars_PickleMimic_Vitals& Self)
{
    if (utils_pickle_mimic::Get_IsPositiveFinite(Self.BodyHealth) == false || Self.CorpseSeconds < 0.0f || Self.FlinchSeconds < 0.0f)
    { return FMars_Validation(f"PickleMimic has a non-positive BodyHealth [{Self.BodyHealth}] or a negative CorpseSeconds [{Self.CorpseSeconds}] or FlinchSeconds [{Self.FlinchSeconds}]"); }

    if (Self.HeavilyCrackedBelow <= 0.0f || Self.HeavilyCrackedBelow >= Self.CrackedBelow || Self.CrackedBelow >= 1.0f)
    { return FMars_Validation(f"PickleMimic needs 0 < HeavilyCrackedBelow [{Self.HeavilyCrackedBelow}] < CrackedBelow [{Self.CrackedBelow}] < 1"); }

    if (Self.SpilledPickles < 0 || Self.SpilledPickles > 12)
    { return FMars_Validation(f"PickleMimic spills [{Self.SpilledPickles}] pickles (0 .. 12, what its jar can hold)"); }

    return FMars_Validation();
}

// The transform the kernel moves, built by the entity script (features own no visuals): the walker body, a scene node on
// the root that sinks utils_pickle_mimic::TuckDrop while the mimic sits disguised. Everything seen hangs off it.
struct FMars_PickleMimic_Rig
{
    UPROPERTY()
    FCk_Handle_SceneNode Body;
}

struct FMars_PickleMimic_Spec
{
    UPROPERTY()
    FMars_PickleMimic_Locomotion Locomotion;

    UPROPERTY()
    FMars_PickleMimic_Posture Posture;

    UPROPERTY()
    FMars_PickleMimic_Bite Bite;

    UPROPERTY()
    FMars_PickleMimic_Senses Senses;

    UPROPERTY()
    FMars_PickleMimic_Vitals Vitals;

    // Built by the entity script.
    UPROPERTY()
    FMars_PickleMimic_Rig Rig;
}

mixin FMars_Validation Validate(const FMars_PickleMimic_Spec& Self)
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
    { return FMars_Validation("PickleMimic rig has no Body"); }

    return FMars_Validation();
}

//--------------------------------------------------------------------------------------------------------------------------
// Params
//--------------------------------------------------------------------------------------------------------------------------

struct FMars_Fragment_PickleMimic_Params
{
    UPROPERTY()
    FMars_PickleMimic_Spec Spec;
}

//--------------------------------------------------------------------------------------------------------------------------
// State
//--------------------------------------------------------------------------------------------------------------------------

// Composed by Add; never written afterwards.
struct FMars_Fragment_PickleMimic
{
    UPROPERTY()
    FCk_Handle_SurfaceMotion Motion;

    UPROPERTY()
    FCk_Handle_Monster Monster;

    UPROPERTY()
    FCk_Handle_DamageDealer Dealer;

    UPROPERTY()
    FCk_Handle_ProceduralGait Gait;

    // The root's location at Add.
    UPROPERTY()
    FVector Home;
}

// What it is told to do between actions (the control layer's Drive / Stop). A running action overrides it; tucked (or
// still standing up) it does not walk.
struct FMars_Fragment_PickleMimic_Drive
{
    UPROPERTY()
    FVector Direction = FVector::ZeroVector;

    UPROPERTY()
    float32 Speed = 0.0f;
}

enum EMars_PickleMimic_Stance
{
    // Sat low between its feet, lid shut: the disguise.
    Tucked,
    Standing
}

// Rise runs 0 (tucked) .. 1 (standing) toward Stance; the walker body sinks TuckDrop * (1 - Get_Lift(Rise)).
struct FMars_Fragment_PickleMimic_Posture
{
    UPROPERTY()
    EMars_PickleMimic_Stance Stance = EMars_PickleMimic_Stance::Tucked;

    UPROPERTY()
    float32 Rise = 0.0f;

    // The body node's last offset (cm below the root): the processor moves the node only when this changes.
    UPROPERTY()
    float32 AppliedDrop = -1.0f;
}

// The lid: Gape is the latched opening the control layer asks for between bites (0 shut .. 1 wide); LidOpen is the
// lid's opening now, eased toward Gape, or set by the bite while one runs.
struct FMars_Fragment_PickleMimic_Mouth
{
    UPROPERTY()
    float32 Gape = 0.0f;

    UPROPERTY()
    float32 LidOpen = 0.0f;
}

enum EMars_PickleMimic_Action
{
    None,
    Bite
}

enum EMars_PickleMimic_ActionPhase
{
    None,
    Windup,
    Active,
    Recover
}

// Why a Start was refused (the drain's verdict, also what the admission getter answers).
enum EMars_PickleMimic_Admission
{
    Admitted,
    Dead,
    NotStanding,
    Busy,
    Flinching,
    Cooldown,
    NoTarget,
    Ungrounded,
    OutOfRange,
    Facing
}

// The one running action and its clocks. Written only by the request drain and the action tick.
struct FMars_Fragment_PickleMimic_Action
{
    UPROPERTY()
    EMars_PickleMimic_Action Kind = EMars_PickleMimic_Action::None;

    UPROPERTY()
    EMars_PickleMimic_ActionPhase Phase = EMars_PickleMimic_ActionPhase::None;

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

    // The mouth's place last frame: this frame's sweep starts there.
    UPROPERTY()
    FVector LastBlowCentre;

    // The zones this action has hurt (each at most once).
    UPROPERTY()
    TArray<FCk_Handle_HitZone> HitZones;

    UPROPERTY()
    float32 BiteCooldown = 0.0f;

    // The lid's opening when the windup began (the windup gapes from there).
    UPROPERTY()
    float32 LidAtStart = 0.0f;
}

// What blows have done to it. Written only by the request drain (a TakeHit) and the tick (the clocks, the crack stage).
struct FMars_Fragment_PickleMimic_Hurt
{
    // Seconds of flinch left (0: not flinching).
    UPROPERTY()
    float32 FlinchLeft = 0.0f;

    // Bumped by every flinch, so a reader sees each one.
    UPROPERTY()
    int32 FlinchCount = 0;

    // Along the ground, from the jar toward where the last flinching blow came from (zero when it cannot tell).
    UPROPERTY()
    FVector FlinchFrom = FVector::ZeroVector;

    // A blow found it disguised: it wakes whatever the distance. Held until it next stands fully up (or dies).
    UPROPERTY()
    bool Startled = false;

    // 0 intact, 1 cracked, 2 heavily cracked (Vitals' thresholds); it only rises.
    UPROPERTY()
    int32 CrackStage = 0;

    // Its death spilled the jar's pickles (OnSpill went out).
    UPROPERTY()
    bool Spilled = false;
}

struct FMars_Fragment_PickleMimic_Targeting
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
delegate void FMars_Delegate_PickleMimic_OnActionPhase(FCk_Handle_PickleMimic InMimic, EMars_PickleMimic_Action InAction, EMars_PickleMimic_ActionPhase InPhase);
event void FMars_Delegate_PickleMimic_OnActionPhase_MC(FCk_Handle_PickleMimic InMimic, EMars_PickleMimic_Action InAction, EMars_PickleMimic_ActionPhase InPhase);

// A blow landed on a zone (the zone's own OnHit carries the damage).
delegate void FMars_Delegate_PickleMimic_OnBlowLanded(FCk_Handle_PickleMimic InMimic, EMars_PickleMimic_Action InAction, FCk_Handle_HitZone InZone);
event void FMars_Delegate_PickleMimic_OnBlowLanded_MC(FCk_Handle_PickleMimic InMimic, EMars_PickleMimic_Action InAction, FCk_Handle_HitZone InZone);

// Rise reached its stance (fully up, or fully sat down).
delegate void FMars_Delegate_PickleMimic_OnStance(FCk_Handle_PickleMimic InMimic, EMars_PickleMimic_Stance InStance);
event void FMars_Delegate_PickleMimic_OnStance_MC(FCk_Handle_PickleMimic InMimic, EMars_PickleMimic_Stance InStance);

// It died and its jar broke: InCount pickles (Vitals.SpilledPickles) spill out. Once, the frame it is first seen dead.
delegate void FMars_Delegate_PickleMimic_OnSpill(FCk_Handle_PickleMimic InMimic, int32 InCount);
event void FMars_Delegate_PickleMimic_OnSpill_MC(FCk_Handle_PickleMimic InMimic, int32 InCount);

struct FMars_Fragment_PickleMimic_Signals
{
    FMars_Delegate_PickleMimic_OnActionPhase_MC OnActionPhase;
    FMars_Delegate_PickleMimic_OnBlowLanded_MC OnBlowLanded;
    FMars_Delegate_PickleMimic_OnStance_MC OnStance;
    FMars_Delegate_PickleMimic_OnSpill_MC OnSpill;
}

//--------------------------------------------------------------------------------------------------------------------------
// Requests
//--------------------------------------------------------------------------------------------------------------------------

// Latched: it walks along InDirection (laid onto the ground) at InSpeed until the next Drive or Stop.
struct FMars_Request_PickleMimic_Drive
{
    UPROPERTY()
    FVector Direction;

    UPROPERTY()
    float32 Speed = 0.0f;

    FMars_Request_PickleMimic_Drive() {}

    FMars_Request_PickleMimic_Drive(FVector InDirection, float32 InSpeed)
    {
        Direction = InDirection;
        Speed = InSpeed;
    }
}

// A blow landed on its body zone (fed from the zone's OnHit with the scaled event). Unless it is dead the mimic flinches;
// found disguised it is startled awake (the lid pops) and takes the blow's instigator as its target when that is Hostile;
// up and holding no target it takes the instigator too.
struct FMars_Request_PickleMimic_TakeHit
{
    UPROPERTY()
    FMars_DamageEvent Event;

    FMars_Request_PickleMimic_TakeHit() {}

    FMars_Request_PickleMimic_TakeHit(FMars_DamageEvent InEvent)
    {
        Event = InEvent;
    }
}

struct FMars_Request_PickleMimic_Stop
{
    UPROPERTY()
    bool _Placeholder = false;
}

// Stand up out of the disguise, or sit back down into it (Rise runs there over StandSeconds / TuckSeconds).
struct FMars_Request_PickleMimic_SetStance
{
    UPROPERTY()
    EMars_PickleMimic_Stance Stance = EMars_PickleMimic_Stance::Standing;

    FMars_Request_PickleMimic_SetStance() {}

    FMars_Request_PickleMimic_SetStance(EMars_PickleMimic_Stance InStance)
    {
        Stance = InStance;
    }
}

// Latched: how far the lid hangs open between bites, 0 shut .. 1 wide.
struct FMars_Request_PickleMimic_Gape
{
    UPROPERTY()
    float32 Amount = 0.0f;

    FMars_Request_PickleMimic_Gape() {}

    FMars_Request_PickleMimic_Gape(float32 InAmount)
    {
        Amount = InAmount;
    }
}

// Starts InAction on InTarget if it is admissible now (Get_Admission); a refusal is dropped.
struct FMars_Request_PickleMimic_Start
{
    UPROPERTY()
    EMars_PickleMimic_Action Action = EMars_PickleMimic_Action::None;

    UPROPERTY()
    FCk_Handle Target;

    FMars_Request_PickleMimic_Start() {}

    FMars_Request_PickleMimic_Start(EMars_PickleMimic_Action InAction, FCk_Handle InTarget)
    {
        Action = InAction;
        Target = InTarget;
    }
}

// Ends the running action at once (no recovery); its cooldown still starts.
struct FMars_Request_PickleMimic_Cancel
{
    UPROPERTY()
    bool _Placeholder = false;
}

// Applied Cancel -> TakeHit -> Stop -> Drive -> SetStance -> Gape -> Start, each kind in arrival order.
struct FMars_Fragment_PickleMimic_Requests
{
    UPROPERTY()
    TArray<FMars_Request_PickleMimic_Cancel> CancelRequests;

    UPROPERTY()
    TArray<FMars_Request_PickleMimic_TakeHit> TakeHitRequests;

    UPROPERTY()
    TArray<FMars_Request_PickleMimic_Stop> StopRequests;

    UPROPERTY()
    TArray<FMars_Request_PickleMimic_Drive> DriveRequests;

    UPROPERTY()
    TArray<FMars_Request_PickleMimic_SetStance> SetStanceRequests;

    UPROPERTY()
    TArray<FMars_Request_PickleMimic_Gape> GapeRequests;

    UPROPERTY()
    TArray<FMars_Request_PickleMimic_Start> StartRequests;
}
