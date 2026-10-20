// The service steward's look: the body mesh and its idle, where its eyes sit and how they behave, and how it stages a
// devouring. Read by UMars_Steward_EntityScript. The mesh, its eye plate and the numbers below come out of one pipeline: the Blender
// builder (Tools/Blender/mars_steward/build_steward.py) and the editor-side importer next to it
// (unreal/mars_steward_ue.py), which logs Face.Offset for the mesh it imported.

struct FMars_Steward_Body
{
    UPROPERTY()
    TSoftObjectPtr<USkeletalMesh> Mesh;

    // Looped on the body from the moment it exists. Optional: without it the steward stands in its reference pose.
    UPROPERTY()
    TSoftObjectPtr<UAnimSequence> Idle;

    // The body relative to the steward's root (its feet, +X forward). Yaw -90 turns a mesh that faces +Y (the steward
    // faces -Y in Blender, +Y once imported) to the root's forward; it must match the import's facing. Scale is the
    // Scale field's (this one must stay 1).
    UPROPERTY()
    FTransform MeshOffset = FTransform(FRotator(0.0, -90.0, 0.0), FVector::ZeroVector, FVector::OneVector);

    // Uniform body scale. Steward_Mars_SK is authored at the steward's height (289.9 cm to the top of its toque, its
    // eyes ReferenceEyeHeightCm up), so this is 1; it is the one number to change to try another height.
    UPROPERTY()
    float32 Scale = 1.0f;

    // The reference pose's eye height above the root (cm): where the face is taken to be before the body exists.
    UPROPERTY()
    float32 ReferenceEyeHeightCm = 229.0f;
}

// Where the eyes sit on the steward. They are drawn by the body mesh itself: its face plate is the EyesSlot section,
// UV-mapped so the eye-plate look draws one eye on each half of the plate (4.3 x 8.4 cm at rest). The entity script
// composes Gaze and Eyes on a face node that follows Bone, and the eyes write the body's custom primitive data.
struct FMars_Steward_Face
{
    UPROPERTY()
    FName Bone = n"head";

    // The face node relative to Bone, in unscaled body units: +X out of the face, +Y the steward's right, +Z up, on the
    // plate's keel level with the eyes. Derived from Steward_Mars_SK's reference pose by mars_steward_ue.face_offset:
    // the head bone sits at component (0.566, 13.021, 228.150), tipped forward (the source auto-rig's bone), and the
    // node at component (0, 28.217, 229.35) facing +Y: Offset = NodeInComponent * Inverse(HeadInComponent). Gaze aims
    // from here. Scale must stay one (the body's Scale sizes it). Re-derive when the mesh is re-exported.
    UPROPERTY()
    FTransform Offset = FTransform(FRotator(-15.317, 73.451, -85.512), FVector(5.328, 13.888, -3.379), FVector::OneVector);

    // The body mesh's material slot the eyes are drawn on. The entity script puts the MarsEyePlate look on it; the
    // slot reads the eyes' custom primitive data.
    UPROPERTY()
    FName EyesSlot = n"M_EyePlate";
}

// Whom the steward's eyes follow: the nearest player's head in front of it. It looks down from 2.3 m, so the range
// reaches further than a chef's.
struct FMars_Steward_Gaze
{
    UPROPERTY()
    float32 RangeCm = 1500.0f;

    UPROPERTY()
    float32 ConeHalfAngleDeg = 85.0f;
}

// What the face plate shows at one instant: the MarsStewardMaw look's animated inputs (Shaders/Looks/StewardMaw.ush).
struct FMars_Steward_MawFrame
{
    // The plate's glow; 0 is pure black.
    float32 Strength = 0.0f;

    // 0 shut .. 1 open.
    float32 EyeOpen = 0.0f;

    // 0 the resting eye .. 1 the evil one.
    float32 Evil = 0.0f;

    // 0 no mouth .. 1 the clenched grin.
    float32 Mouth = 0.0f;

    // 0 clenched .. 1 wide open.
    float32 Jaw = 0.0f;

    // The face's size about its mouth; 1 is the grin's.
    float32 Zoom = 1.0f;

    // How much of the world the plate hides: 1 all of it, 0 none.
    float32 Veil = 1.0f;

    // 0 the eyes glow as they do on the head .. 1 they burn.
    float32 Heat = 0.0f;

    // How far the view shudders, in half view widths.
    float32 Shake = 0.0f;

    // The head cocked in the view; negative leans its top to the view's left.
    float32 TiltRadians = 0.0f;
}

namespace constants_steward
{
    // On every steward's entity: how the Mars_Devour cheat finds them.
    const FName k_EntityTag = n"TAG_MarsSteward";

    // The mechanism channel that tells every steward the service has failed. Anything may assert it (the sandbox's fail
    // switch does, Mars_SandboxSteward.as); a steward devours a player each time it rises.
    const FName k_ServiceFailedChannel = n"Mechanism.Channel.ServiceFailed";

    // On whoever a steward may devour: the players monsters can hurt (AMars_PlayerCharacter's combat receiver).
    const FName k_VictimTag = n"TAG_MarsCombatTarget";
}

// The face plate: a square SizeCm wide, DistanceCm in front of the victim's eye. Just past the 10 cm near plane, so it is
// nearer than the first-person gloves and whatever they hold (drawn scaled toward the eye, FMars_FPHands_ViewSpec). It
// must cover the view: at a 90 degree field of view the view is twice the distance wide.
struct FMars_Steward_MawPlate
{
    UPROPERTY()
    float32 SizeCm = 60.0f;

    UPROPERTY()
    float32 DistanceCm = 12.0f;

    // The plate's light while the face shows. The look divides it by the view's exposure, so it is what reaches the
    // screen whatever the level's light: 1 is the tonemapper's near-white, where the teeth lose their shading.
    UPROPERTY()
    float32 Brightness = 0.7f;
}

// By the end of the grin: how hot the eyes burn and how far they have turned to the evil shape (both finish in the bite's
// first moments), and how far the head is cocked.
struct FMars_Steward_MawGrin
{
    UPROPERTY()
    float32 Heat = 0.7f;

    UPROPERTY()
    float32 Evil = 0.5f;

    UPROPERTY()
    float32 TiltDeg = -8.0f;
}

// The bite: where the victim's view is held once lifted (DistanceCm out of the face node along its +X, looking back at
// it), the face's Zoom while the open maw is held in view (GapeZoom) and as the jaws close on the view (Zoom), and how
// far the view shudders by the bite's end (half view widths).
struct FMars_Steward_MawBite
{
    UPROPERTY()
    float32 DistanceCm = 45.0f;

    UPROPERTY()
    float32 GapeZoom = 1.12f;

    UPROPERTY()
    float32 Zoom = 3.4f;

    UPROPERTY()
    float32 Shake = 0.02f;
}

// How the steward stages a devouring (the Devour feature runs its clock): where the victim's view is taken, and the face
// plate that fills it from Blink on.
struct FMars_Steward_Maw
{
    UPROPERTY()
    FMars_Devour_Timing Timing;

    UPROPERTY()
    FMars_Steward_MawPlate Plate;

    UPROPERTY()
    FMars_Steward_MawGrin Grin;

    UPROPERTY()
    FMars_Steward_MawBite Bite;

    // The plate lifts off the victim's view over this long once the victim is let go: the world comes back from black.
    UPROPERTY()
    float32 FadeBackSeconds = 0.8f;
}

// The face plate through the run, InAlpha 0..1 through InPhase. Blink is black (the cut from the steward's head to the
// plate). Grin opens the eyes at once, then splits the mouth into the clenched grin of needle teeth while the eyes
// narrow, catch fire and start to turn, the head cocks and the face creeps closer. Bite finishes the eyes' turn to evil,
// fully alight, as the jaws swing wide; the gaping maw is held in view (Bite.GapeZoom), shuddering, then comes down over
// the view (Bite.Zoom), snaps shut and goes black. Swallowed stays black. Seize and Lift have no plate. The plate hides the
// whole world throughout (Veil 1).
mixin FMars_Steward_MawFrame Get_Frame(const FMars_Steward_Maw& Self, EMars_Devour_Phase InPhase, float32 InAlpha)
{
    auto Frame = FMars_Steward_MawFrame();
    const float32 GrinZoom = 1.08f;
    const float32 GrinEyeOpen = 0.8f;
    const auto GrinTilt = float32(Math::DegreesToRadians(Self.Grin.TiltDeg));

    if (InPhase == EMars_Devour_Phase::Grin)
    {
        Frame.Strength = Self.Plate.Brightness;
        Frame.EyeOpen = Math::SmoothStep(0.0f, 0.1f, InAlpha) * Math::Lerp(1.0f, GrinEyeOpen, Math::SmoothStep(0.4f, 1.0f, InAlpha));
        Frame.Heat = Self.Grin.Heat * Math::SmoothStep(0.2f, 0.9f, InAlpha);
        Frame.Evil = Self.Grin.Evil * Math::SmoothStep(0.55f, 1.0f, InAlpha);
        Frame.Mouth = Math::SmoothStep(0.3f, 0.75f, InAlpha);
        Frame.TiltRadians = GrinTilt * Math::SmoothStep(0.2f, 1.0f, InAlpha);
        Frame.Zoom = Math::Lerp(1.0f, GrinZoom, InAlpha);
    }
    else if (InPhase == EMars_Devour_Phase::Bite)
    {
        // The jaws are wide by OpenAt and held in view to LungeFrom; the face then comes down over the view, the jaws
        // starting to shut at ShutFrom and shut by ShutAt, and the plate is black from BlackAt.
        const float32 OpenAt = 0.28f;
        const float32 LungeFrom = 0.5f;
        const float32 ShutFrom = 0.78f;
        const float32 ShutAt = 0.88f;
        const float32 BlackAt = 0.93f;

        const auto Turning = Math::SmoothStep(0.0f, 0.2f, InAlpha);
        Frame.Strength = InAlpha < BlackAt ? Self.Plate.Brightness : 0.0f;
        Frame.EyeOpen = Math::Lerp(GrinEyeOpen, 1.0f, Turning);
        Frame.Mouth = 1.0f;
        Frame.Evil = Math::Lerp(Self.Grin.Evil, 1.0f, Turning);
        Frame.Heat = Math::Lerp(Self.Grin.Heat, 1.0f, Turning);
        Frame.TiltRadians = GrinTilt * (1.0f - Math::SmoothStep(0.0f, 0.25f, InAlpha));
        Frame.Shake = Self.Bite.Shake * InAlpha;

        const auto Opening = Math::Clamp(InAlpha / OpenAt, 0.0f, 1.0f);
        const auto Shutting = Math::Clamp((InAlpha - ShutFrom) / (ShutAt - ShutFrom), 0.0f, 1.0f);
        Frame.Jaw = (1.0f - (1.0f - Opening) * (1.0f - Opening)) * (1.0f - Shutting * Shutting);

        const auto Gaping = Math::SmoothStep(0.0f, LungeFrom, InAlpha);
        const auto Lunge = Math::Clamp((InAlpha - LungeFrom) / (ShutAt - LungeFrom), 0.0f, 1.0f);
        Frame.Zoom = Math::Lerp(Math::Lerp(GrinZoom, Self.Bite.GapeZoom, Gaping), Self.Bite.Zoom, Lunge * Lunge);
    }

    return Frame;
}

class UMars_Steward_Config : UDataAsset
{
    UPROPERTY(Category = "Body")
    FMars_Steward_Body Body;

    UPROPERTY(Category = "Face")
    FMars_Steward_Face Face;

    UPROPERTY(Category = "Face")
    FMars_Steward_Gaze Gaze;

    UPROPERTY(Category = "Face")
    FMars_Eyes_Spec Eyes;

    UPROPERTY(Category = "Maw")
    FMars_Steward_Maw Maw;

    // All-or-nothing: reports the first failing rule. The gaze numbers are checked by the Gaze spec they fill.
    FMars_Validation Validate() const
    {
        if (Body.Mesh.IsNull())
        { return FMars_Validation("Body.Mesh is not set"); }

        // A NaN fails the comparison, so it is rejected too.
        if ((Body.Scale > 0.0f) == false)
        { return FMars_Validation(f"Body.Scale [{Body.Scale}] must be positive"); }

        if ((Body.ReferenceEyeHeightCm > 0.0f) == false)
        { return FMars_Validation(f"Body.ReferenceEyeHeightCm [{Body.ReferenceEyeHeightCm}] must be positive"); }

        // IsValid: finite, with a normalized rotation.
        if (Body.MeshOffset.IsValid() == false)
        { return FMars_Validation(f"Body.MeshOffset [{Body.MeshOffset}] is not finite or its rotation is not normalized"); }

        if (Body.MeshOffset.GetScale3D().Equals(FVector::OneVector) == false)
        { return FMars_Validation(f"Body.MeshOffset scale [{Body.MeshOffset.GetScale3D()}] must be one - the Scale field sizes the body"); }

        if (Face.Bone.IsNone())
        { return FMars_Validation("Face.Bone is not set"); }

        if (Face.Offset.IsValid() == false)
        { return FMars_Validation(f"Face.Offset [{Face.Offset}] is not finite or its rotation is not normalized"); }

        if (Face.Offset.GetScale3D().Equals(FVector::OneVector) == false)
        { return FMars_Validation(f"Face.Offset scale [{Face.Offset.GetScale3D()}] must be one - the Scale field sizes the face"); }

        if (Face.EyesSlot.IsNone())
        { return FMars_Validation("Face.EyesSlot is not set"); }

        const auto EyesValidation = Eyes.Validate();
        if (EyesValidation.IsValid() == false)
        { return FMars_Validation(f"Eyes: {EyesValidation.Get_Error()}"); }

        const auto TimingValidation = Maw.Timing.Validate();
        if (TimingValidation.IsValid() == false)
        { return FMars_Validation(f"Maw.Timing: {TimingValidation.Get_Error()}"); }

        // A NaN fails each comparison, so it is rejected too.
        if ((Maw.Bite.DistanceCm > 0.0f) == false)
        { return FMars_Validation(f"Maw.Bite.DistanceCm [{Maw.Bite.DistanceCm}] must be positive"); }

        if ((Maw.Plate.DistanceCm > 0.0f) == false)
        { return FMars_Validation(f"Maw.Plate.DistanceCm [{Maw.Plate.DistanceCm}] must be positive"); }

        if ((Maw.Plate.SizeCm >= Maw.Plate.DistanceCm * 2.0f) == false)
        { return FMars_Validation(f"Maw.Plate.SizeCm [{Maw.Plate.SizeCm}] must be at least twice Plate.DistanceCm [{Maw.Plate.DistanceCm}] to cover the view"); }

        if ((Maw.Bite.GapeZoom >= 1.0f) == false)
        { return FMars_Validation(f"Maw.Bite.GapeZoom [{Maw.Bite.GapeZoom}] must be at least 1"); }

        if ((Maw.Bite.Zoom >= Maw.Bite.GapeZoom) == false)
        { return FMars_Validation(f"Maw.Bite.Zoom [{Maw.Bite.Zoom}] must be at least Bite.GapeZoom [{Maw.Bite.GapeZoom}]"); }

        if ((Maw.Grin.Heat >= 0.0f && Maw.Grin.Heat <= 1.0f) == false)
        { return FMars_Validation(f"Maw.Grin.Heat [{Maw.Grin.Heat}] must be within 0..1"); }

        if ((Maw.Grin.Evil >= 0.0f && Maw.Grin.Evil <= 1.0f) == false)
        { return FMars_Validation(f"Maw.Grin.Evil [{Maw.Grin.Evil}] must be within 0..1"); }

        if ((Maw.Bite.Shake >= 0.0f) == false)
        { return FMars_Validation(f"Maw.Bite.Shake [{Maw.Bite.Shake}] is negative"); }

        if ((Maw.Plate.Brightness >= 0.0f) == false)
        { return FMars_Validation(f"Maw.Plate.Brightness [{Maw.Plate.Brightness}] is negative"); }

        if ((Maw.FadeBackSeconds >= 0.0f) == false)
        { return FMars_Validation(f"Maw.FadeBackSeconds [{Maw.FadeBackSeconds}] is negative"); }

        return FMars_Validation();
    }
}

namespace mars
{
    asset Mars_Steward_Config of UMars_Steward_Config
    {
        Body.Mesh = TSoftObjectPtr<USkeletalMesh>(FSoftObjectPath("/Game/Mars/Gameplay/Steward/Meshes/Steward_Mars_SK.Steward_Mars_SK"));
        Body.Idle = TSoftObjectPtr<UAnimSequence>(FSoftObjectPath("/Game/Mars/Gameplay/Steward/Anims/Steward_Idle_Mars_AS.Steward_Idle_Mars_AS"));

        // Tall ovals, paler than the chefs' amber: the concept's cream glow.
        Eyes.Style = utils_eyes::Style_ClassicOval().Def;
        Eyes.Style.Color = FLinearColor(1.0f, 0.9f, 0.72f, 1.0f);
        Eyes.Blink = FMars_Eyes_BlinkSpec();
        Eyes.Look = FMars_Eyes_LookSpec();

        // Longer than the kernel's defaults: the grin has time to catch fire, and the open maw is held before it bites.
        Maw.Timing.GrinSeconds = 1.6f;
        Maw.Timing.BiteSeconds = 1.1f;
    }
}
