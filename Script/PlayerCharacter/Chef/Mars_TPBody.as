// The third-person chef body: the character's inherited Mesh, hidden from its owner (who sees the first-person gloves)
// and seen by everyone else. Composed by AMars_PlayerCharacter from Config.TPBody; its emotes are montages played on the
// ABP's DefaultSlot (AMars_PlayerCharacter::Request_Emote), its held-item strike is the procedural HandSwing carried
// through the arms' IK (Mars_HeldView.as, AMars_PlayerCharacter::Request_Strike).

// The body's montages: one per EMars_FPEmote, as the gloves' FMars_FPHands_EmoteSpec::Montages. Each plays through the
// slot its montage names.
struct FMars_TPBody_Montages
{
    UPROPERTY()
    TMap<EMars_FPEmote, TSoftObjectPtr<UAnimMontage>> EmoteMontages;

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
    // between the two eye quads (SK_Chef's head bone has X up, Y to the chef's left, Z out of the face). Gaze aims from
    // here. Scale must stay one (the body's Scale sizes it).
    UPROPERTY()
    FTransform Offset = FTransform(FRotator(90.0, 180.0, 0.0), FVector(13.37, 0.0, 12.57), FVector::OneVector);

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

    // Uniform scale of the body others see. It is smaller than the player it stands for: at 1.5 the body tops out at
    // 120 cm (hat 150 cm, 73 cm wide, inside the 1.5 m capsule) and other players look slightly down at it. Only the look
    // changes: the capsule, the view height (Config.View.EyeHeight) and the reach stay the player's. The view sits 110 cm
    // up, inside the hood; below about 1.4 it would be above the hood's top.
    UPROPERTY()
    float32 Scale = 1.5f;

    // The Scale the locomotion clips were authored against. ABP_Chef plays BS_Chef_Locomotion at AuthoredScale / Scale
    // (Get_LocomotionPlayRate), so a body scaled up past its clips takes proportionally slower steps and one scaled
    // down takes quicker ones.
    UPROPERTY()
    float32 AuthoredScale = 1.8828f;

    UPROPERTY()
    FMars_TPBody_Montages Montages;

    UPROPERTY()
    FMars_TPBody_Head Head;

    // Where the hands hold an item other players see (Mars_HeldView.as).
    UPROPERTY()
    FMars_TPBody_Hold Hold;
}

// The body mesh's location relative to the capsule's centre, with its feet on the capsule's base. InCrouchDrop is how
// far the capsule's centre has dropped below its standing height (its half height shrinks by as much when the character
// crouches; 0 standing): the body rises by it relative to the centre, so its feet stay on the floor.
mixin FVector Get_BodyLocation(const FMars_TPBody_Spec& Self, float32 InCapsuleHalfHeight, float32 InCrouchDrop)
{
    return Self.MeshOffset.GetLocation() - FVector(0.0, 0.0, InCapsuleHalfHeight - InCrouchDrop);
}

// The blend space play rate that keeps the locomotion clips' footfalls on the ground at the config speeds (see AuthoredScale).
mixin float32 Get_LocomotionPlayRate(const FMars_TPBody_Spec& Self)
{
    return Self.AuthoredScale / Self.Scale;
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

    if ((Self.AuthoredScale > 0.0f) == false)
    { return FMars_Validation(f"AuthoredScale [{Self.AuthoredScale}] must be positive"); }

    if (Self.MeshOffset.GetScale3D().Equals(FVector::OneVector) == false)
    { return FMars_Validation(f"MeshOffset scale [{Self.MeshOffset.GetScale3D()}] must be one - the Scale field sizes the body"); }

    const auto EmoteCount = utils_fphands::Get_EmoteCount();
    for (int32 Value = 0; Value < EmoteCount; ++Value)
    {
        const auto Emote = EMars_FPEmote(Value);
        if (Self.Montages.EmoteMontages.Contains(Emote) == false)
        { return FMars_Validation(f"EmoteMontages has no montage for [{Emote :n}]"); }
    }

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
    if (HoldValidation.IsValid() == false)
    { return FMars_Validation(f"Hold: {HoldValidation.Get_Error()}"); }

    return FMars_Validation();
}
