// The third-person chef body: the character's inherited Mesh, hidden from its owner (who sees the first-person gloves)
// and seen by everyone else. Composed by AMars_PlayerCharacter from Config.TPBody; its emotes are montages played on the
// ABP's DefaultSlot (AMars_PlayerCharacter::Request_Emote), its held-item strike is the procedural HandSwing carried
// through the arms' IK (Mars_HeldView.as, AMars_PlayerCharacter::Request_Strike).

// The body's montages. EmoteMontages is indexed by EMars_FPEmote (the gloves' FMars_FPHands_EmoteSpec::Montages maps it).
struct FMars_TPBody_Montages
{
    UPROPERTY()
    TArray<TSoftObjectPtr<UAnimMontage>> EmoteMontages;

    // The ABP_Chef slot the emote montages play through.
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
    // between the two eye quads. Derived from SK_Chef's reference pose (the MiniChef body, 2026-10-09): head bone at
    // component (0, 1.5, 45), its X straight up, Y to the chef's left, Z out of the face. The eye quads (MiniChef_Eyes,
    // two 8.5 x 8.5 cm quads flush on the face plate over its painted eyes, centred at x +-6.4, z 58.4) have their
    // midpoint at component (0, 14.07, 58.37), facing +Y: Offset = FaceInComponent * Inverse(HeadInComponent), i.e. the
    // delta (0, 12.57, 13.37) in head axes. Gaze aims from here. Scale must stay one (the body's Scale sizes it).
    // (The LowPoly chef this body replaced: FRotator(87.138, 180, 0), FVector(8.26, 0, 15.09).)
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

    // Uniform scale of the body others see. It is smaller than the player it stands for (2026-10-12): the capsule is
    // 1.5 m and the view 110 cm up, but the MiniChef at that height (Scale 1.8828 = 150 / 79.67, the unscaled mesh's
    // top above its feet, hat excluded) read too big beside the 70 cm stations - 92 cm wide, its hat at 189 cm, its
    // face level with the viewer's eyes. At 1.5 the body tops out at 120 cm (hat 150 cm, 73 cm wide, inside the
    // capsule) and other players look slightly down at it. Only the look changes: the capsule, the view height
    // (Config.View.EyeHeight) and the reach stay the player's. The view sits 110 cm up, inside the hood (the face
    // centre is 58.37 * Scale = 88 cm up); below about 1.4 it would be above the hood's top.
    UPROPERTY()
    float32 Scale = 1.5f;

    // The Scale the locomotion clips were authored against. ABP_Chef plays BS_Chef_Locomotion at AuthoredScale / Scale
    // (Get_LocomotionPlayRate), so a body scaled up past its clips takes proportionally slower steps and one scaled
    // down takes quicker ones. The MiniChef's clips are built for its legs at Scale 1.8828; at Scale 1.5 the shorter
    // legs step 1.255 times as fast over the same ground (the LowPoly chef's clips were authored at 1.0969).
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
    if (HoldValidation.IsValid() == false)
    { return FMars_Validation(f"Hold: {HoldValidation.Get_Error()}"); }

    return FMars_Validation();
}
