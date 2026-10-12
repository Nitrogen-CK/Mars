// The service steward's look: the body mesh and its idle, where its eyes sit and how they behave. Read by
// UMars_Steward_EntityScript. The mesh, its eye plate and the numbers below come out of one pipeline: the Blender
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
    // eyes 229 cm up), so this is 1; it is the one number to change to try another height.
    UPROPERTY()
    float32 Scale = 1.0f;
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

    // All-or-nothing: reports the first failing rule. The gaze numbers are checked by the Gaze spec they fill.
    FMars_Validation Validate() const
    {
        if (Body.Mesh.IsNull())
        { return FMars_Validation("Body.Mesh is not set"); }

        // A NaN fails the comparison, so it is rejected too.
        if ((Body.Scale > 0.0f) == false)
        { return FMars_Validation(f"Body.Scale [{Body.Scale}] must be positive"); }

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
    }
}
