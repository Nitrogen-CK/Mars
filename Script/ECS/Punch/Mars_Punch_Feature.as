//--------------------------------------------------------------------------------------------------------------------------
// Dynamic Handle Definition
//--------------------------------------------------------------------------------------------------------------------------

asset Mars_PunchHandle of UCkDynamic_HandleDefinition
{
    TypeName = "FCk_Handle_Punch";
    RequiredFragments.Add(FMars_Feature_Punch);
    Description = "Bare-fisted jabs: one light blow per throw, the hands alternating, each fist on its own short clock";
}

struct FMars_Feature_Punch {}

// Where one fist is on its jab. None is home.
enum EMars_Punch_Stroke
{
    None,
    // Thrown: travelling out to the blow.
    Out,
    // The blow has been dealt (or missed): coming home.
    Back
}

//--------------------------------------------------------------------------------------------------------------------------
// Spec
//--------------------------------------------------------------------------------------------------------------------------

// What one jab deals. At its blow, one sphere sweep of Radius from the thrower's viewpoint along its forward out to Reach,
// through the thrower's DamageDealer (Request_StrikeSweep: hurtboxes only, and a wall in front of one stops the fist); the
// first hurtbox hit takes Damage of DamageType.
struct FMars_Punch_Blow
{
    UPROPERTY()
    float32 Damage = 3.0f;

    // DamageType.Mars.{Sever, Crush, Blunt}.
    UPROPERTY(meta = (Categories = "DamageType"))
    FGameplayTag DamageType = GameplayTags::DamageType_Mars_Blunt;

    UPROPERTY()
    float32 Reach = 140.0f;

    UPROPERTY()
    float32 Radius = 18.0f;

    // The blow's impulse along the view, in cm/s, handed to whatever the sweep hits.
    UPROPERTY()
    float32 ImpulseSpeed = 100.0f;
}

// The jabs' clocks, in seconds.
struct FMars_Punch_Rhythm
{
    // From a throw to its blow.
    UPROPERTY()
    float32 ImpactSeconds = 0.07f;

    // From the blow until the fist is home, where it can be thrown again.
    UPROPERTY()
    float32 RecoverySeconds = 0.17f;

    // The least time between two throws. A throw asked for sooner waits (one at most) and goes once this has passed and
    // its fist is home.
    UPROPERTY()
    float32 IntervalSeconds = 0.12f;

    // This long after the last throw the combo is over: the next one leads with the spec's LeadHand again.
    UPROPERTY()
    float32 ComboSeconds = 0.6f;
}

struct FMars_Punch_Spec
{
    UPROPERTY()
    FMars_Punch_Blow Blow;

    UPROPERTY()
    FMars_Punch_Rhythm Rhythm;

    // The hand a combo opens with; the hands alternate from there.
    UPROPERTY()
    EMars_Hand LeadHand = EMars_Hand::Left;
}

//--------------------------------------------------------------------------------------------------------------------------
// Params
//--------------------------------------------------------------------------------------------------------------------------

struct FMars_Fragment_Punch_Params
{
    UPROPERTY()
    FMars_Punch_Spec Spec;
}

//--------------------------------------------------------------------------------------------------------------------------
// State
//--------------------------------------------------------------------------------------------------------------------------

// One fist's jab.
struct FMars_Punch_Fist
{
    UPROPERTY()
    EMars_Punch_Stroke Stroke = EMars_Punch_Stroke::None;

    // Seconds since the fist was thrown; 0 at home.
    UPROPERTY()
    float32 Elapsed = 0.0f;

    // The jab deals its blow (a Throw), or only shows one thrown on another machine (a Mirror).
    UPROPERTY()
    bool DealsBlow = false;
}

// Written only by UMars_Processor_Punch_HandleRequests, UMars_Processor_Punch_Tick and utils_punch::Add.
struct FMars_Fragment_Punch
{
    UPROPERTY()
    FMars_Punch_Fist Left;

    UPROPERTY()
    FMars_Punch_Fist Right;

    // The hand the next throw uses.
    UPROPERTY()
    EMars_Hand NextHand = EMars_Hand::Left;

    // Seconds since the last jab started; unset before the first and once the combo is over.
    UPROPERTY()
    TOptional<float32> SinceThrow;

    // A throw waiting for its turn. One at most: a throw asked for while one waits is dropped.
    UPROPERTY()
    bool HasWaitingThrow = false;

    // Jabs started since Add, mirrored ones included.
    UPROPERTY()
    int32 JabsThrown = 0;
}

//--------------------------------------------------------------------------------------------------------------------------
// Signals
//--------------------------------------------------------------------------------------------------------------------------

// InHand's fist was thrown: a Throw whose turn came, or a Mirror.
delegate void FMars_Delegate_Punch_OnThrown(FCk_Handle_Punch InPunch, EMars_Hand InHand);
event void FMars_Delegate_Punch_OnThrown_MC(FCk_Handle_Punch InPunch, EMars_Hand InHand);

// A thrown jab dealt its blow. InHit is what its sweep met: a hurtbox (the damage is already requested of the dealer), the
// world (a wall stopped the fist), or nothing - a default result, whose HitKind reads Probe with an invalid hit entity, as
// it also is for a thrower without a DamageDealer. Never broadcast for a mirrored jab, which sweeps nothing.
delegate void FMars_Delegate_Punch_OnBlow(FCk_Handle_Punch InPunch, EMars_Hand InHand, FCk_ShapeCast_Result InHit);
event void FMars_Delegate_Punch_OnBlow_MC(FCk_Handle_Punch InPunch, EMars_Hand InHand, FCk_ShapeCast_Result InHit);

struct FMars_Fragment_Punch_Signals
{
    FMars_Delegate_Punch_OnThrown_MC OnThrown;
    FMars_Delegate_Punch_OnBlow_MC OnBlow;
}

//--------------------------------------------------------------------------------------------------------------------------
// Requests
//--------------------------------------------------------------------------------------------------------------------------

// Throw a jab with the next hand. It starts once Rhythm.IntervalSeconds have passed since the last jab and that hand's
// fist is home - at once when both already hold - and waits until then. One throw waits at most: the rest are dropped,
// so every press is a jab only as fast as the rhythm allows. AngelScript rejects a TArray of an empty struct, so it carries
// one placeholder field.
struct FMars_Request_Punch_Throw
{
    UPROPERTY()
    bool Requested = true;

    FMars_Request_Punch_Throw() {}
}

// Show a jab thrown on another machine: Hand's fist starts now, whatever the rhythm (the thrower's own copy already
// applied it), restarting if it was in flight, and deals no blow. The next throw here uses the other hand. Every field
// replicates, so a character can carry the hand to the other machines as-is.
struct FMars_Request_Punch_Mirror
{
    UPROPERTY()
    EMars_Hand Hand = EMars_Hand::Left;

    FMars_Request_Punch_Mirror() {}

    FMars_Request_Punch_Mirror(EMars_Hand InHand)
    {
        Hand = InHand;
    }
}

// Drained Mirror -> Throw; see the processor.
struct FMars_Fragment_Punch_Requests
{
    UPROPERTY()
    TArray<FMars_Request_Punch_Mirror> MirrorRequests;

    UPROPERTY()
    TArray<FMars_Request_Punch_Throw> ThrowRequests;
}
