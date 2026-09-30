struct FMars_Feature_HandBob {}

//--------------------------------------------------------------------------------------------------------------------------
// Spec
//--------------------------------------------------------------------------------------------------------------------------

// Procedural motion of the first-person hands from the owning character's locomotion: a stride bob while walking, arm
// swing on free hands, float while airborne, a springy squash on landing, and breathing at rest. Offsets are in the
// hand node's frame (X forward, Y right, Z up). Complements CkSway, which only lags the hands behind camera motion.
struct FMars_HandBob_Spec
{
    // Ground speed at which the stride runs at StridesPerSecond and the bob at full amplitude (cm/s).
    UPROPERTY(Category = "Stride")
    float32 ReferenceSpeed = 420.0f;

    // Full left-right-left cycles per second at ReferenceSpeed; the bob dips twice per stride (once per step).
    UPROPERTY(Category = "Stride")
    float32 StridesPerSecond = 1.6f;

    // Amplitude keeps growing past ReferenceSpeed (sprint) up to this multiple.
    UPROPERTY(Category = "Stride")
    float32 MaxAmountScale = 1.5f;

    // How quickly the bob fades in when moving and out when stopping, 1/s.
    UPROPERTY(Category = "Stride")
    float32 AmountInterpSpeed = 7.0f;

    UPROPERTY(Category = "Stride")
    float32 CrouchScale = 0.6f;

    // Dip at each footfall (cm).
    UPROPERTY(Category = "Bob")
    float32 VerticalCm = 1.6f;

    // Side-to-side drift over a stride (cm).
    UPROPERTY(Category = "Bob")
    float32 LateralCm = 1.2f;

    // Roll with the side-to-side drift (deg).
    UPROPERTY(Category = "Bob")
    float32 RollDeg = 2.5f;

    // Nod at each footfall (deg, positive tips the hands down).
    UPROPERTY(Category = "Bob")
    float32 PitchDeg = 1.5f;

    // Free hands swing forward/back in opposite phase, like arms (cm).
    UPROPERTY(Category = "Arm Swing")
    float32 ArmSwingCm = 3.5f;

    // The hand swinging forward lifts a little, like an arm (cm).
    UPROPERTY(Category = "Arm Swing")
    float32 ArmSwingLiftCm = 1.0f;

    UPROPERTY(Category = "Air")
    float32 AirLiftPerFallSpeed = 0.006f;

    UPROPERTY(Category = "Air")
    float32 MaxAirLiftCm = 5.0f;

    // Downward kick on landing per cm/s of impact speed (cm/s of spring velocity).
    UPROPERTY(Category = "Air")
    float32 LandKickPerImpactSpeed = 0.09f;

    UPROPERTY(Category = "Air")
    float32 MaxLandKick = 70.0f;

    // The vertical spring that carries air lift and the landing squash. Low damping = bouncy.
    UPROPERTY(Category = "Air")
    float32 SpringFrequencyHz = 3.0f;

    UPROPERTY(Category = "Air")
    float32 SpringDampingRatio = 0.35f;

    // Rise and fall while standing still (cm, seconds per breath).
    UPROPERTY(Category = "Breath")
    float32 BreathCm = 0.4f;

    UPROPERTY(Category = "Breath")
    float32 BreathPeriodSeconds = 3.6f;
}

//--------------------------------------------------------------------------------------------------------------------------
// Params
//--------------------------------------------------------------------------------------------------------------------------

struct FMars_Fragment_HandBob_Params
{
    UPROPERTY()
    FMars_HandBob_Spec Spec;
}

//--------------------------------------------------------------------------------------------------------------------------
// State
//--------------------------------------------------------------------------------------------------------------------------

struct FMars_Fragment_HandBob
{
    // Stride phase, radians [0, 2PI).
    UPROPERTY()
    float32 Phase = 0.0f;

    // 0 at rest, 1 at ReferenceSpeed on the ground.
    UPROPERTY()
    float32 Amount = 0.0f;

    UPROPERTY()
    float32 BreathTime = 0.0f;

    // Vertical spring (air lift + landing squash).
    UPROPERTY()
    float32 SpringOffset = 0.0f;

    UPROPERTY()
    float32 SpringVelocity = 0.0f;

    UPROPERTY()
    bool WasFalling = false;

    UPROPERTY()
    float32 LastVerticalSpeed = 0.0f;

    // Signed arm swing this frame, [-1, 1] x Amount: positive = right hand forward, left hand back.
    UPROPERTY()
    float32 ArmSwing = 0.0f;
}
