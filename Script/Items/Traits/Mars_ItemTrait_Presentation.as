// Whether one glove or both hold the item. Every definition names it: Unset fails Validate.
enum EMars_ItemPresentation_Handedness
{
    Unset,
    // Only the right glove grips it, at the Hand attach point.
    OneHanded,
    // Both gloves hold it by its sides; the hold centres on screen.
    TwoHanded
}

struct FMars_ItemPresentation_Visual
{
    // Null = the item renders nothing.
    UPROPERTY()
    TSoftObjectPtr<UStaticMesh> Mesh;

    UPROPERTY()
    FVector MeshScale = FVector::OneVector;

    UPROPERTY()
    TSoftObjectPtr<UMaterialInterface> MaterialOverride;

    // Set: the mesh's slot 0 gets a dynamic instance with these ProtoGrid colours (Set_ProtoGridColors), on every visual of
    // the item - in the world, in the hand, in a slot.
    UPROPERTY()
    TOptional<FLinearColor> PrimaryColor;
}

// Where a two-handed item's gloves sit (without grip sockets).
enum EMars_HandGripLayout
{
    // Palms on its two side faces (a box carry).
    Sides,
    // Palms up under its underside, just inside its side faces (a tray, a slab).
    Cradle
}

// Where each glove takes hold of the item, in the item's own frame: its root, in cm at unit scale (the frame HeldOffset
// and the body use). A point is the grip bone's target, authored like a grip socket: X across the palm toward the index
// finger, Z out of the palm (utils_fphands::Make_GripRotation). The world item registers the points as its grip nodes
// (UMars_WorldItem_EntityScript::Resolve_GripPoints); they replace mesh sockets and the fitted Sides / Cradle grips.
struct FMars_ItemPresentation_GripPoints
{
    // Unset: the item declares no points (its visual mesh's grip sockets, else the fitted grips, apply).
    UPROPERTY()
    TOptional<FTransform> Right;

    // Two-handed items only, and only alongside Right.
    UPROPERTY()
    TOptional<FTransform> Left;
}

// How the first-person gloves hold the item.
struct FMars_ItemPresentation_Grip
{
    // Finger pose the gloves use while holding this item.
    UPROPERTY()
    EMars_HandGripPose Pose = EMars_HandGripPose::Cradle;

    // Two-handed, no grip sockets: where the gloves sit (FMars_FPHands_RestSpec's Cradle knobs for Cradle).
    UPROPERTY()
    EMars_HandGripLayout Layout = EMars_HandGripLayout::Sides;

    UPROPERTY()
    EMars_ItemPresentation_Handedness Handedness = EMars_ItemPresentation_Handedness::Unset;

    // Two-handed: half the distance between the palms. Unset measures the Mesh bounds (x MeshScale, through
    // Mounting.HeldOffset).
    UPROPERTY()
    TOptional<float32> HalfWidth;

    // The primitive the gloves' fingers close on, fitted to the Mesh bounds (finger contact).
    UPROPERTY()
    EMars_FPHands_GripShape Shape = EMars_FPHands_GripShape::Auto;

    // Mesh socket grips only (an authoring convenience for a mesh's Grip_R / Grip_L): turns that glove about the handle
    // (the socket's X axis), degrees, right-handed about the direction toward the tool's head. The palm stays on the
    // handle; what moves is which side the forearm comes from, so a stacked two-handed hold can bring the left arm across
    // the body and bend the right in from its side. Never applied to Points: an explicit point states its rotation.
    UPROPERTY()
    float32 SocketTwist_R = 0.0f;

    UPROPERTY()
    float32 SocketTwist_L = 0.0f;

    // Explicit grip points; set, they win over the visual mesh's grip sockets (and SocketTwist_R / _L do not apply).
    // Validate: Left needs Right, a TwoHanded item declares both or neither, a OneHanded item no Left, every point unit scale.
    UPROPERTY()
    FMars_ItemPresentation_GripPoints Points;
}

// Where the item sits on whatever holds it, and how it gets there.
struct FMars_ItemPresentation_Mounting
{
    UPROPERTY()
    EMars_WorldItem_Persistence Persistence = EMars_WorldItem_Persistence::Transient;

    // QueryOnly by default. A carried support surface opts into its own physical profile.
    UPROPERTY()
    FName MountedBodyProfile = constants_world_item::k_MountedBodyProfile;

    // Persistent only: the carrier's attach point the item mounts to while carried and not held (AttachPoint.Mars.Back).
    UPROPERTY()
    FGameplayTag CarryPoint;

    UPROPERTY()
    FTransform CarryOffset;

    // Relative to the player's Hand attach point.
    UPROPERTY()
    FTransform HeldOffset;

    // Relative to a cargo slot node while stowed in a backpack.
    UPROPERTY()
    FTransform CargoOffset;

    // Seconds a mount transition / stow / take lerps. 0 snaps.
    UPROPERTY()
    float32 ArriveSeconds = 0.25f;
}

// The item lying in the world (a World-mode world item).
struct FMars_ItemPresentation_WorldItem
{
    // Pickup probe radius for an item without a Mesh. An item with one is picked up (and a backpack weighs on plates)
    // through a box fitted to the Mesh bounds.
    UPROPERTY()
    float32 PickupProbeRadius = 40.0f;

    // Null = the base WorldItem entity script. Set it only for an item family that needs behaviour of its own.
    UPROPERTY()
    TSubclassOf<UMars_WorldItem_EntityScript> ScriptClass;
}

// What an item looks like when it needs a physical representation - dropped in the world or held in the hand.
UCLASS(Meta = (DisplayName = "🎭 Presentation"))
class UMars_ItemTrait_Presentation : UCk_ItemTrait
{
    UPROPERTY()
    FMars_ItemPresentation_Visual Visual;

    UPROPERTY()
    FMars_ItemPresentation_Grip Grip;

    UPROPERTY()
    FMars_ItemPresentation_Mounting Mounting;

    UPROPERTY()
    FMars_ItemPresentation_WorldItem WorldItem;
}

// The gloves need to know how many hands hold the item.
mixin FMars_Validation Validate(const UMars_ItemTrait_Presentation Self)
{
    if (Self.Grip.Handedness == EMars_ItemPresentation_Handedness::Unset)
    { return FMars_Validation("Grip.Handedness is unset: name OneHanded or TwoHanded"); }

    return Self.Grip.Points.Validate(Self.Grip.Handedness);
}

// The grip points against the item's handedness (FMars_ItemPresentation_Grip::Points).
mixin FMars_Validation Validate(const FMars_ItemPresentation_GripPoints& Self, EMars_ItemPresentation_Handedness InHandedness)
{
    if (Self.Left.IsSet() && Self.Right.IsSet() == false)
    { return FMars_Validation("Grip.Points.Left is set without Grip.Points.Right"); }

    if (InHandedness == EMars_ItemPresentation_Handedness::OneHanded && Self.Left.IsSet())
    { return FMars_Validation("Grip.Points.Left is set on a OneHanded item: only the right glove holds it"); }

    if (InHandedness == EMars_ItemPresentation_Handedness::TwoHanded && Self.Right.IsSet() != Self.Left.IsSet())
    { return FMars_Validation("Grip.Points on a TwoHanded item name one hand: declare both points or neither"); }

    if (Self.Right.IsSet() && Self.Right.GetValue().GetScale3D().Equals(FVector::OneVector, 0.0001) == false)
    { return FMars_Validation(f"Grip.Points.Right has scale [{Self.Right.GetValue().GetScale3D()}]: a grip point is unit scale"); }

    if (Self.Left.IsSet() && Self.Left.GetValue().GetScale3D().Equals(FVector::OneVector, 0.0001) == false)
    { return FMars_Validation(f"Grip.Points.Left has scale [{Self.Left.GetValue().GetScale3D()}]: a grip point is unit scale"); }

    return FMars_Validation();
}

mixin bool Has_Presentation(const FCk_Handle_Item& Self)
{
    return Self.Has_ItemTrait(UMars_ItemTrait_Presentation);
}

mixin const UMars_ItemTrait_Presentation Get_Presentation(const FCk_Handle_Item& Self)
{
    return Self.Get_ItemTrait(UMars_ItemTrait_Presentation);
}
