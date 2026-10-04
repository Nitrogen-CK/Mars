// The third-person chef body: the character's inherited Mesh, hidden from its owner (who sees the first-person gloves)
// and seen by everyone else. Composed by AMars_PlayerCharacter from Config.TPBody; its emotes and strike are montages
// played on the ABP's DefaultSlot (AMars_PlayerCharacter::Request_Emote / Request_Strike).

// The body's montages. EmoteMontages is indexed by EMars_FPEmote, like FMars_FPHands_Spec::EmoteMontages.
struct FMars_TPBody_Montages
{
    UPROPERTY()
    TArray<TSoftObjectPtr<UAnimMontage>> EmoteMontages;

    // Played on the body as a held item's strike starts (UMars_SmTask_ItemUse_Strike).
    UPROPERTY()
    TSoftObjectPtr<UAnimMontage> StrikeMontage;

    // The ABP_Chef slot the emote and strike montages play through.
    UPROPERTY()
    FName EmoteSlot = n"DefaultSlot";

    UPROPERTY()
    float32 EmoteCancelBlendSeconds = 0.2f;
}

// The chef's hat: a cosmetic static mesh on a body socket, so it follows the head and takes the body's Scale.
struct FMars_TPBody_Hat
{
    // Optional: no mesh, no hat.
    UPROPERTY()
    TSoftObjectPtr<UStaticMesh> Mesh;

    // On the body mesh (SK_Chef's Hat socket rides the head bone at the hat's base).
    UPROPERTY()
    FName Socket = n"Hat";

    // The hat relative to the socket, in unscaled body units. Identity when the socket already lines the hat up.
    UPROPERTY()
    FTransform Offset = FTransform::Identity;
}

// Where the eyes sit on the chef. They are drawn by the body mesh itself (EyesSlot); AMars_PlayerCharacter composes Gaze
// and Eyes on a face node that follows Bone, and the eyes write the body's custom primitive data.
struct FMars_TPBody_Face
{
    UPROPERTY()
    FName Bone = n"head";

    // The face node relative to Bone, in unscaled body units: +X out of the face, +Y the chef's right, +Z up, midway
    // between the two eye quads. Derived from SK_Chef's reference pose (2026-10-03): head bone at component (0, -7, 62),
    // its X along the neck (up, tilted 2.862 deg back), Y to the chef's left, Z out of the face. The eye quads (Eyes_LP,
    // two ~5.9 x 5.5 cm quads flush on the face plate, centred at x +-6.1, z 71.0, wrapping its curve back to y 6.89)
    // have their midpoint at component (0, 6.89, 71.0), facing +Y: Offset = FaceInComponent * Inverse(HeadInComponent),
    // i.e. the delta (0, 13.89, 9.0) in head axes. Gaze aims from here. Scale must stay one (the body's Scale sizes it).
    UPROPERTY()
    FTransform Offset = FTransform(FRotator(87.138, 180.0, 0.0), FVector(8.29, 0.0, 14.32), FVector::OneVector);

    // The body mesh's material slot the eyes are drawn on (SK_Chef's Eyes_LP quads). The character replaces its
    // material with the MarsEyePlate look; the slot reads the eyes' custom primitive data.
    UPROPERTY()
    FName EyesSlot = n"M_EyePlate";
}

// The cosmetics that ride the chef's head: the hat on its socket and the face node carrying the eyes.
struct FMars_TPBody_Head
{
    UPROPERTY()
    FMars_TPBody_Hat Hat;

    UPROPERTY()
    FMars_TPBody_Face Face;
}

struct FMars_TPBody_Spec
{
    UPROPERTY()
    TSoftObjectPtr<USkeletalMesh> Mesh;

    UPROPERTY()
    TSoftClassPtr<UAnimInstance> AnimClass;

    // The body relative to the capsule's base (its feet), X forward. The character adds the -CapsuleHalfHeight drop
    // itself, so a capsule resize keeps the feet on the floor. Yaw -90 turns a mesh that faces +Y (the chef faces -Y in
    // Blender, +Y once imported) to the actor's forward; it must match the import's facing. Scale is the Scale field's
    // (this one must stay 1).
    UPROPERTY()
    FTransform MeshOffset = FTransform(FRotator(0.0, -90.0, 0.0), FVector::ZeroVector, FVector::OneVector);

    // Uniform body scale. The chef stands 1 m without its hat:
    //   Scale = 100 / ChefTopCm = 100 / 91.167 = 1.0969
    // (ChefTopCm: the unscaled mesh's top above its feet, hat excluded). The capsule (Config.CapsuleHalfHeight 50) is
    // the chef's height, and the view sits at the chef's face centre (unscaled 71.1 cm above the feet):
    //   EyeHeight.Height = 71.1 * Scale - CapsuleHalfHeight = 78.0 - 50 = 28
    // (EyeHeight is measured from the capsule centre). Re-derive all three when the chef mesh or the capsule changes.
    UPROPERTY()
    float32 Scale = 1.0969f;

    UPROPERTY()
    FMars_TPBody_Montages Montages;

    UPROPERTY()
    FMars_TPBody_Head Head;

    // Where the hands hold an item other players see (Mars_HeldView.as).
    UPROPERTY()
    FMars_TPBody_Hold Hold;
}

mixin FMars_Validation Validate(const FMars_TPBody_Spec& Self)
{
    if (Self.Mesh.IsNull())
    { return FMars_Validation("Mesh is not set"); }

    if (Self.AnimClass.IsNull())
    { return FMars_Validation("AnimClass is not set"); }

    // A NaN fails the comparison, so it is rejected too.
    if ((Self.Scale > 0.0f) == false)
    { return FMars_Validation(f"Scale [{Self.Scale}] must be positive"); }

    if (Self.MeshOffset.GetScale3D().Equals(FVector::OneVector) == false)
    { return FMars_Validation(f"MeshOffset scale [{Self.MeshOffset.GetScale3D()}] must be one - the Scale field sizes the body"); }

    const auto EmoteCount = utils_fphands::Get_EmoteCount();
    if (Self.Montages.EmoteMontages.Num() != EmoteCount)
    { return FMars_Validation(f"EmoteMontages has [{Self.Montages.EmoteMontages.Num()}] entries, EMars_FPEmote has [{EmoteCount}]"); }

    if (Self.Montages.EmoteCancelBlendSeconds < 0.0f)
    { return FMars_Validation(f"EmoteCancelBlendSeconds [{Self.Montages.EmoteCancelBlendSeconds}] is negative"); }

    const auto& Hat = Self.Head.Hat;
    if (Hat.Mesh.IsNull() == false && Hat.Socket.IsNone())
    { return FMars_Validation("Head.Hat.Socket is not set (the hat mesh needs a socket)"); }

    // IsValid: finite, with a normalized rotation.
    if (Hat.Offset.IsValid() == false)
    { return FMars_Validation(f"Head.Hat.Offset [{Hat.Offset}] is not finite or its rotation is not normalized"); }

    const auto& Face = Self.Head.Face;
    if (Face.Bone.IsNone())
    { return FMars_Validation("Head.Face.Bone is not set"); }

    if (Face.Offset.IsValid() == false)
    { return FMars_Validation(f"Head.Face.Offset [{Face.Offset}] is not finite or its rotation is not normalized"); }

    if (Face.Offset.GetScale3D().Equals(FVector::OneVector) == false)
    { return FMars_Validation(f"Head.Face.Offset scale [{Face.Offset.GetScale3D()}] must be one - the Scale field sizes the face"); }

    if (Face.EyesSlot.IsNone())
    { return FMars_Validation("Head.Face.EyesSlot is not set"); }

    const auto HoldValidation = Self.Hold.Validate();
    if (HoldValidation.IsValid == false)
    { return FMars_Validation(f"Hold: {HoldValidation.Get_Error()}"); }

    return FMars_Validation();
}
