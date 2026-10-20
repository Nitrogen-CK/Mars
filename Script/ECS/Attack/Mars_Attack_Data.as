// Authored values and copied observations for enemy attacks. No live entity handles or callbacks belong here.
enum EMars_Attack_EmitterSource { Body, LimbEndpoint }
enum EMars_Attack_AnatomySource { Body, ProceduralLimb }
enum EMars_Attack_TemporaryReadinessPolicy { WaitPreferred, UseReadyAlternative }
enum EMars_Attack_ControlWaitPolicy { PreferAvailable, WaitForPreferred }
enum EMars_Attack_Availability { Unavailable, Waiting, Ready }
enum EMars_Attack_SelectionDisposition { Prepare, Start, Wait, NoCapability }

// Why an attack cannot start now (admission codes, from utils_attack::Evaluate), or why an accepted hit's evidence was
// rejected (emitter codes, from the crawler's emitter checks).
enum EMars_Attack_BlockerCode
{
    // Admission: a required part or limb.
    PartMissing,
    PartPendingDestroy,
    PartWrongOwner,
    PartSevered,
    PartBroken,
    PartDepleted,
    ConditionDisallowed,
    LimbDetached,
    LimbDisabled,
    LimbUnavailable,
    ControlBusy,
    LimbReturning,
    LimbUnplanted,
    // Admission: the creature.
    SupportStance,
    SupportCapacity,
    Dead,
    NotReady,
    Ungrounded,
    Slope,
    Moving,
    WindupBlocked,
    Cooldown,
    GlobalCooldown,
    // Admission: the target.
    TargetLost,
    OutOfRange,
    TooClose,
    Height,
    Facing,
    // Emitter evidence.
    HitContactInvalid,
    EmitterCount,
    EmitterIdentity,
    EmitterBounds,
    AcceptedSourceInvalid,
    AcceptedRootInvalid,
    RootInvalid,
    RootDrift,
    FacingDrift,
    AcceptedSourceMissing,
    SampleTravel,
    AcceptedPresentationMismatch
}

// A Permanent blocker makes the attack incapable (Unavailable); a Temporary one only makes it wait.
enum EMars_Attack_BlockerKind { Permanent, Temporary }

// Idle: no preparation. Active: preparing for the preferred attack, counting the readiness wait. TimedOut: the wait ran
// past the preferred attack's Prepare.TimeoutSeconds; admission stops for that target until the preparation resets.
enum EMars_Attack_PreparationState { Idle, Active, TimedOut }

struct FMars_Attack_SlotRole
{
    UPROPERTY() FName Slot;
    UPROPERTY(meta = (Categories = "AttackRole")) FGameplayTag Role;
    UPROPERTY() EMars_BodyPart_Condition MaxCondition = EMars_BodyPart_Condition::Ruined;
}

struct FMars_Attack_PartRequirement
{
    UPROPERTY(meta = (Categories = "AttackRole")) FGameplayTag Role;
    UPROPERTY() EMars_BodyPart_Condition MaxCondition = EMars_BodyPart_Condition::Ruined;
}

struct FMars_Attack_Requirements
{
    UPROPERTY() TArray<FMars_Attack_SlotRole> Slots;
    UPROPERTY() TArray<FMars_Attack_PartRequirement> Parts;
}

struct FMars_Attack_MotionContract
{
    UPROPERTY() FName WindupPhase = n"Windup";
    UPROPERTY() FName StrikePhase = n"Strike";
    UPROPERTY() FName RecoverPhase = n"Recover";
    UPROPERTY() FName ObstructionWindow = n"Offense";
}

struct FMars_Attack_Prepare
{
    UPROPERTY() float32 MinDistance = 0.0f;
    UPROPERTY() float32 MaxDistance = 100.0f;
    // Resolve only in a private creature copy; zero remains a valid literal centre.
    UPROPERTY() bool UseCreatureFrontRange = false;
    UPROPERTY() float32 CreatureFrontRangeMargin = 70.0f;
    UPROPERTY() float32 FacingToleranceDegrees = 10.0f;
    UPROPERTY() float32 MaxHeightDifference = 60.0f;
    UPROPERTY() float32 MaxSpeedToStart = 3.0f;
    UPROPERTY() float32 TimeoutSeconds = 2.0f;
}

struct FMars_Attack_Emitter
{
    UPROPERTY(meta = (Categories = "AttackEmitter")) FGameplayTag Id;
    UPROPERTY() EMars_Attack_EmitterSource Source = EMars_Attack_EmitterSource::Body;
    UPROPERTY() FName Slot;
    UPROPERTY() FName DamageWindow = n"Offense";
    // None inherits Motion.ObstructionWindow. Endpoint sweeps can exclude lift-off and replanting.
    UPROPERTY() FName ObstructionWindow;
    UPROPERTY() FVector LocalCenter = FVector::ZeroVector;
    UPROPERTY() bool UseCreatureFrontCenter = false;
    UPROPERTY() float32 Radius = 20.0f;
    UPROPERTY() float32 MaxSampleTravel = 80.0f;
}

struct FMars_Attack_Hit
{
    UPROPERTY() float32 Damage = 15.0f;
    UPROPERTY() FGameplayTag DamageType;
    UPROPERTY() TArray<FMars_Attack_Emitter> Emitters;
}

struct FMars_Attack_Cooldown
{
    UPROPERTY() float32 RecoverySeconds = 0.70f;
    UPROPERTY() float32 ReuseSeconds = 0.0f;
}

struct FMars_Attack_Definition
{
    UPROPERTY() TSoftObjectPtr<UCk_ProceduralAction_Data> Clip;
    UPROPERTY() FMars_Attack_MotionContract Motion;
    UPROPERTY() FMars_Attack_Requirements Requirements;
    UPROPERTY() FMars_Attack_Prepare Prepare;
    UPROPERTY() FMars_Attack_Hit Hit;
    UPROPERTY() FMars_Attack_Cooldown Cooldown;
    // None emits no cue batches; the entity script matches the profile it dresses (Mars_Crawler_Cues.as).
    UPROPERTY(meta = (Categories = "AttackCue")) FGameplayTag CueProfile;
}

struct FMars_Attack_Entry
{
    UPROPERTY(meta = (Categories = "Attack")) FGameplayTag Id;
    UPROPERTY() TSoftObjectPtr<UMars_AttackDefinition_Data> Definition;
    UPROPERTY() int32 Priority = 0;
    UPROPERTY() bool Enabled = true;
}

struct FMars_Attack_SelectionPolicy
{
    UPROPERTY() EMars_Attack_TemporaryReadinessPolicy TemporaryReadiness = EMars_Attack_TemporaryReadinessPolicy::WaitPreferred;
    UPROPERTY() EMars_Attack_ControlWaitPolicy ControlWait = EMars_Attack_ControlWaitPolicy::PreferAvailable;
    UPROPERTY() float32 ReadyAlternativeDelaySeconds = 0.25f;
}

struct FMars_Attack_ExecutionPolicy
{
    UPROPERTY() FCk_ProceduralAction_Tuning Tuning;
    UPROPERTY() FCk_ProceduralLimbControl_Locomotion Locomotion;
    UPROPERTY() float32 MaxRootDrift = 10.0f;
    UPROPERTY() float32 MaxGroundSlopeDegrees = 35.0f;
}

struct FMars_Attack_Loadout
{
    UPROPERTY() TArray<FMars_Attack_Entry> Entries;
    UPROPERTY() FMars_Attack_SelectionPolicy Selection;
    UPROPERTY() FMars_Attack_ExecutionPolicy Execution;
}

struct FMars_Attack_AnatomyBinding
{
    UPROPERTY(meta = (Categories = "AttackRole")) FGameplayTag Role;
    UPROPERTY() EMars_Attack_AnatomySource Source = EMars_Attack_AnatomySource::Body;
    UPROPERTY() FName LimbId;
    // Composition's morphology adapter supplies this; a dedicated appendage need not borrow locomotion support.
    UPROPERTY() bool Locomotor = false;
}

struct FMars_Attack_Comparison
{
    UPROPERTY() FString Expected;
    UPROPERTY() FString Actual;

    FMars_Attack_Comparison() {}
    FMars_Attack_Comparison(FString InExpected, FString InActual)
    { Expected = InExpected; Actual = InActual; }
}

struct FMars_Attack_Diagnostic
{
    UPROPERTY() FName Code;
    UPROPERTY() FString Field;
    UPROPERTY() FString Expected;
    UPROPERTY() FString Actual;
}

struct FMars_Attack_ValidationReport
{
    UPROPERTY() TArray<FMars_Attack_Diagnostic> Diagnostics;
    UPROPERTY() bool Truncated = false;

    bool Get_IsValid() const
    { return Diagnostics.Num() == 0 && Truncated == false; }
}

struct FMars_Attack_EntryIdentity
{
    UPROPERTY() FGameplayTag Id;
    UPROPERTY() int32 Priority = 0;
    UPROPERTY() TSoftObjectPtr<UMars_AttackDefinition_Data> DefinitionPath;
    UPROPERTY() int32 GameRevision = 0;
}

struct FMars_Attack_ResolvedSlot
{
    UPROPERTY() FName Slot;
    UPROPERTY() FMars_Attack_AnatomyBinding Binding;
    UPROPERTY() EMars_BodyPart_Condition MaxCondition = EMars_BodyPart_Condition::Ruined;
}

struct FMars_Attack_ResolvedPart
{
    UPROPERTY() FMars_Attack_AnatomyBinding Binding;
    UPROPERTY() EMars_BodyPart_Condition MaxCondition = EMars_BodyPart_Condition::Ruined;
}

struct FMars_Attack_ResolvedEntry
{
    UPROPERTY() FMars_Attack_EntryIdentity Identity;
    UPROPERTY() FMars_Attack_Definition Definition;
    // Original asset identity is distinct from the construction-time frozen Definition.Clip.
    UPROPERTY() TSoftObjectPtr<UCk_ProceduralAction_Data> SourceClip;
    UPROPERTY() TArray<FMars_Attack_ResolvedSlot> Slots;
    UPROPERTY() TArray<FMars_Attack_ResolvedPart> Parts;
}

struct FMars_Attack_ResolvedLoadout
{
    UPROPERTY() TArray<FMars_Attack_ResolvedEntry> Entries;
    UPROPERTY() FMars_Attack_SelectionPolicy Selection;
    UPROPERTY() FMars_Attack_ExecutionPolicy Execution;
    UPROPERTY() TArray<FMars_Attack_AnatomyBinding> Anatomy;
    UPROPERTY() int32 GameRevision = 0;
    UPROPERTY() TSoftObjectPtr<UMars_AttackLoadout_Data> Path;
}

struct FMars_Attack_PartObservation
{
    UPROPERTY() bool Live = false;
    UPROPERTY() bool PendingDestroy = false;
    UPROPERTY() bool OwnerMatches = false;
    UPROPERTY() EMars_BodyPart_State State = EMars_BodyPart_State::Attached;
    UPROPERTY() bool Depleted = false;
    UPROPERTY() EMars_BodyPart_Condition Condition = EMars_BodyPart_Condition::Pristine;
}

struct FMars_Attack_LimbObservation
{
    UPROPERTY() bool Exists = false;
    UPROPERTY() bool Attached = false;
    UPROPERTY() bool Enabled = false;
    UPROPERTY() ECk_ProceduralLimbControl_State Control = ECk_ProceduralLimbControl_State::Unavailable;
    UPROPERTY() bool Planted = false;
    UPROPERTY() bool Trusted = false;
}

struct FMars_Attack_RoleObservation
{
    UPROPERTY() FGameplayTag Role;
    UPROPERTY() EMars_Attack_AnatomySource Source = EMars_Attack_AnatomySource::Body;
    UPROPERTY() FName LimbId;
    UPROPERTY() FMars_Attack_PartObservation Part;
    UPROPERTY() FMars_Attack_LimbObservation Limb;
}

struct FMars_Attack_SupportLimbObservation
{
    UPROPERTY() FName LimbId;
    UPROPERTY() FMars_Attack_PartObservation Part;
    UPROPERTY() FMars_Attack_LimbObservation Limb;
}

struct FMars_Attack_SelfState
{
    UPROPERTY() bool Alive = false;
    UPROPERTY() bool Ready = false;
    UPROPERTY() bool Grounded = false;
    UPROPERTY() float32 SlopeDegrees = 0.0f;
    UPROPERTY() float32 RootSpeed = 0.0f;
    UPROPERTY() bool MobilityReady = false;
    UPROPERTY() bool SupportRegionReady = false;
}

struct FMars_Attack_SelfObservation
{
    UPROPERTY() FMars_Attack_SelfState State;
    UPROPERTY() TArray<FMars_Attack_SupportLimbObservation> SupportLimbs;
    UPROPERTY() bool WindupClear = false;
}

struct FMars_Attack_TargetObservation
{
    UPROPERTY() bool Valid = false;
    UPROPERTY() int64 Identity = 0;
    UPROPERTY() int32 Generation = 0;
    UPROPERTY() float32 Distance = 0.0f;
    UPROPERTY() float32 HeightDifference = 0.0f;
    UPROPERTY() float32 FacingDegrees = 0.0f;
}

struct FMars_Attack_CooldownObservation
{
    UPROPERTY() float32 EntryRemaining = 0.0f;
    UPROPERTY() float32 GlobalRemaining = 0.0f;
}

struct FMars_Attack_EvaluationQuery
{
    UPROPERTY() FMars_Attack_ResolvedEntry Entry;
    UPROPERTY() TArray<FMars_Attack_RoleObservation> Roles;
    UPROPERTY() FMars_Attack_ExecutionPolicy Execution;
    UPROPERTY() FMars_Attack_SelfObservation Self;
    UPROPERTY() FMars_Attack_TargetObservation Target;
    UPROPERTY() FMars_Attack_CooldownObservation Cooldown;
}

struct FMars_Attack_Blocker
{
    UPROPERTY() EMars_Attack_BlockerCode Code = EMars_Attack_BlockerCode::NotReady;
    // Follows Code (utils_attack::Get_BlockerKind); set by utils_attack::Make_Blocker.
    UPROPERTY() EMars_Attack_BlockerKind Kind = EMars_Attack_BlockerKind::Temporary;
    UPROPERTY() FString Field;
    UPROPERTY() FGameplayTag Role;
    UPROPERTY() FName Slot;
    UPROPERTY() FString Expected;
    UPROPERTY() FString Actual;
}

struct FMars_Attack_Evaluation
{
    UPROPERTY() FGameplayTag AttackId;
    UPROPERTY() EMars_Attack_Availability Availability = EMars_Attack_Availability::Unavailable;
    UPROPERTY() bool Capable = false;
    UPROPERTY() TArray<FMars_Attack_Blocker> Blockers;
    UPROPERTY() int32 EnabledSupport = 0;
    UPROPERTY() int32 StandingSupport = 0;
}

struct FMars_Attack_SelectionCandidate
{
    UPROPERTY() FGameplayTag Id;
    UPROPERTY() int32 Priority = 0;
    // Zero means never accepted; positive values are accepted-admission sequence numbers, not timestamps.
    UPROPERTY() int64 LastStartSequence = 0;
    UPROPERTY() FMars_Attack_Evaluation Evaluation;
}

struct FMars_Attack_Preparation
{
    UPROPERTY() EMars_Attack_PreparationState State = EMars_Attack_PreparationState::Idle;
    UPROPERTY() FGameplayTag Preferred;
    UPROPERTY() int64 TargetIdentity = 0;
    UPROPERTY() int32 TargetGeneration = 0;
    UPROPERTY() float32 ElapsedReadinessWait = 0.0f;
}

struct FMars_Attack_SelectionQuery
{
    UPROPERTY() TArray<FMars_Attack_SelectionCandidate> Candidates;
    UPROPERTY() FMars_Attack_SelectionPolicy Policy;
    UPROPERTY() FMars_Attack_Preparation Preparation;
    UPROPERTY() FMars_Attack_TargetObservation Target;
}

struct FMars_Attack_Selection
{
    UPROPERTY() TOptional<FGameplayTag> Preferred;
    UPROPERTY() TOptional<FGameplayTag> ReadyChoice;
    UPROPERTY() TOptional<FGameplayTag> Selected;
    UPROPERTY() EMars_Attack_SelectionDisposition Disposition = EMars_Attack_SelectionDisposition::NoCapability;
}
