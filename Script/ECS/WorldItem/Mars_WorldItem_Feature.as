//--------------------------------------------------------------------------------------------------------------------------
// Dynamic Handle Definition
//--------------------------------------------------------------------------------------------------------------------------

asset Mars_WorldItemHandle of UCkDynamic_HandleDefinition
{
    TypeName = "FCk_Handle_WorldItem";
    RequiredFragments.Add(FMars_Feature_WorldItem);
    Description = "An item presented outside an inventory: pickable with physics in the world, or a visual in the player's hand";
}
struct FMars_Feature_WorldItem {}

//--------------------------------------------------------------------------------------------------------------------------
// Enums
//--------------------------------------------------------------------------------------------------------------------------

enum EMars_WorldItem_Mode
{
    // Holder + Jolt body + pickup interactable + visual.
    World,
    // Visual only, scene-node attached under AttachTo (the hand, a cargo slot). No item, holder, body, probe or
    // interactable.
    Visual
}

enum EMars_WorldItem_Persistence
{
    // Stowing destroys the world item; a held visual / cargo visual is spawned as needed.
    Transient,
    // The world item IS the item's body: on stow it mounts to its carrier and moves between Carried / Held / World.
    Persistent
}

// Where a Persistent world item is right now.
enum EMars_WorldItem_Mount
{
    // A free Jolt body, pickable.
    World,
    // On the carrier's CarryPoint attach point (the back), or on the point the Carry named (a station dock).
    Carried,
    // On the carrier's Hand attach point.
    Held
}

//--------------------------------------------------------------------------------------------------------------------------
// Constants
//--------------------------------------------------------------------------------------------------------------------------

namespace constants_world_item
{
    // A pending arrival older than this is dropped unread, so a stale pose never animates a later visual.
    const float64 k_ArriveFromMaxAgeSeconds = 0.5;
}

//--------------------------------------------------------------------------------------------------------------------------
// Spawn params
//--------------------------------------------------------------------------------------------------------------------------

// One-shot world pose a Visual-mode item arrives from (hand -> slot, slot -> hand). Unset = spawn at rest.
struct FMars_WorldItem_Arrival
{
    UPROPERTY()
    bool IsSet = false;

    UPROPERTY()
    FTransform World;

    FMars_WorldItem_Arrival() {}

    FMars_WorldItem_Arrival(FTransform InWorld)
    {
        IsSet = true;
        World = InWorld;
    }
}

// Where an item visually was when someone started moving it, kept by whoever spawns its next visual (a cargo slot for a
// stow, HeldItem for a take) until that visual spawns. utils_world_item::Get_FreshArrival ages it out.
struct FMars_WorldItem_PendingArrival
{
    UPROPERTY()
    FCk_Handle_Item Item;

    UPROPERTY()
    FTransform World;

    UPROPERTY()
    float64 StampedAtSeconds = 0.0;

    FMars_WorldItem_PendingArrival() {}

    FMars_WorldItem_PendingArrival(const FCk_Handle_Item& InItem, const FTransform& InWorld, float64 InStampedAtSeconds)
    {
        Item = InItem;
        World = InWorld;
        StampedAtSeconds = InStampedAtSeconds;
    }
}

// A Visual-mode world item of Item following AttachTo at AttachOffset (utils_world_item::Request_SpawnVisual).
struct FMars_WorldItem_VisualSpec
{
    UPROPERTY()
    FCk_Handle_Item Item;

    UPROPERTY()
    FCk_Handle_Transform AttachTo;

    UPROPERTY()
    FTransform AttachOffset;

    // Unset = spawn at rest.
    UPROPERTY()
    FMars_WorldItem_Arrival ArriveFrom;

    FMars_WorldItem_VisualSpec() {}

    FMars_WorldItem_VisualSpec(const FCk_Handle_Item& InItem, const FCk_Handle_Transform& InAttachTo, const FTransform& InAttachOffset)
    {
        Item = InItem;
        AttachTo = InAttachTo;
        AttachOffset = InAttachOffset;
    }
}

// A World-mode world item of Definition seeded from it at World (unit scale), launched when a velocity is set
// (utils_world_item::Request_SpawnWorld).
struct FMars_WorldItem_WorldSpec
{
    UPROPERTY()
    TSoftObjectPtr<UCk_InventoryItem_Definition> Definition;

    UPROPERTY()
    FTransform World;

    UPROPERTY()
    FVector LinearVelocity = FVector::ZeroVector;

    UPROPERTY()
    FVector AngularVelocityDeg = FVector::ZeroVector;

    FMars_WorldItem_WorldSpec() {}

    FMars_WorldItem_WorldSpec(TSoftObjectPtr<UCk_InventoryItem_Definition> InDefinition, const FTransform& InWorld)
    {
        Definition = InDefinition;
        World = InWorld;
    }

    FMars_WorldItem_WorldSpec(TSoftObjectPtr<UCk_InventoryItem_Definition> InDefinition,
                              const FTransform& InWorld,
                              FVector InLinearVelocity,
                              FVector InAngularVelocityDeg)
    {
        Definition = InDefinition;
        World = InWorld;
        LinearVelocity = InLinearVelocity;
        AngularVelocityDeg = InAngularVelocityDeg;
    }
}

//--------------------------------------------------------------------------------------------------------------------------
// Probe fit
//--------------------------------------------------------------------------------------------------------------------------

// A probe shape and its offset from the world item root (utils_world_item::Make_ProbeFit).
struct FMars_WorldItem_ProbeFit
{
    UPROPERTY()
    FCk_AnyShape Shape;

    UPROPERTY()
    FTransform Offset;

    FMars_WorldItem_ProbeFit() {}

    FMars_WorldItem_ProbeFit(FCk_AnyShape InShape, FTransform InOffset)
    {
        Shape = InShape;
        Offset = InOffset;
    }
}

// The mesh bounds (x MeshScale) every box fitted to the item uses (utils_world_item::Make_BoundsFit).
struct FMars_WorldItem_BoundsFit
{
    UPROPERTY()
    FVector HalfExtents;

    // From the world item root.
    UPROPERTY()
    FVector Centre;

    FMars_WorldItem_BoundsFit() {}

    FMars_WorldItem_BoundsFit(FVector InHalfExtents, FVector InCentre)
    {
        HalfExtents = InHalfExtents;
        Centre = InCentre;
    }
}

//--------------------------------------------------------------------------------------------------------------------------
// Transient fragments (drained by the WorldItem processors)
//--------------------------------------------------------------------------------------------------------------------------

// A launch applied once the Jolt body exists and reads Dynamic; drained by UMars_Processor_WorldItem_Launch.
struct FMars_Fragment_WorldItem_PendingLaunch
{
    UPROPERTY()
    FVector LinearVelocity = FVector::ZeroVector;

    UPROPERTY()
    FVector AngularVelocityDeg = FVector::ZeroVector;

    FMars_Fragment_WorldItem_PendingLaunch() {}

    FMars_Fragment_WorldItem_PendingLaunch(FVector InLinearVelocity, FVector InAngularVelocityDeg)
    {
        LinearVelocity = InLinearVelocity;
        AngularVelocityDeg = InAngularVelocityDeg;
    }
}

// Waiting for the body to read Kinematic before the scene-node attach (SetMotionType is deferred; attaching a Dynamic
// body's transform would fight the Jolt writeback for a frame). Overwritten by a newer Carry/Hold; removed by Release.
// Drained by UMars_Processor_WorldItem_Mount.
struct FMars_Fragment_WorldItem_PendingMount
{
    UPROPERTY()
    EMars_WorldItem_Mount Mount = EMars_WorldItem_Mount::World;

    UPROPERTY()
    FCk_Handle Carrier;

    UPROPERTY()
    FCk_Handle_Transform Node;

    UPROPERTY()
    FTransform Offset;

    FMars_Fragment_WorldItem_PendingMount() {}

    FMars_Fragment_WorldItem_PendingMount(EMars_WorldItem_Mount InMount, const FCk_Handle& InCarrier)
    {
        Mount = InMount;
        Carrier = InCarrier;
    }
}

// Drives the scene-node offset FromOffset -> ToOffset with OutCubic over Duration; ONE Request_UpdateOffset per frame.
// Drained by UMars_Processor_WorldItem_Arrive.
struct FMars_Fragment_WorldItem_Arrival
{
    UPROPERTY()
    FTransform FromOffset;

    UPROPERTY()
    FTransform ToOffset;

    UPROPERTY()
    float32 Duration = 0.0f;

    UPROPERTY()
    float32 Elapsed = 0.0f;
}

//--------------------------------------------------------------------------------------------------------------------------
// Spec
//--------------------------------------------------------------------------------------------------------------------------

// What the entity script composed for utils_world_item::Add. Holder and Pickup exist in World mode only; Body in World
// mode with a Mesh.
struct FMars_WorldItem_Spec
{
    UPROPERTY()
    EMars_WorldItem_Mode Mode = EMars_WorldItem_Mode::World;

    UPROPERTY()
    TSoftObjectPtr<UCk_InventoryItem_Definition> Definition;

    UPROPERTY()
    FCk_Handle_Inventory_DataOnly Holder;

    UPROPERTY()
    FCk_Handle_Interactable Pickup;

    UPROPERTY()
    FCk_Handle_JoltBody Body;

    // Visual mode: the offset lerp of a visual that arrives from somewhere.
    UPROPERTY()
    TOptional<FMars_Fragment_WorldItem_Arrival> Arrival;

    // World mode with a Body: the launch of a dropped or thrown item.
    UPROPERTY()
    TOptional<FMars_Fragment_WorldItem_PendingLaunch> Launch;
}

mixin FMars_Validation Validate(const FMars_WorldItem_Spec& Self)
{
    if (Self.Definition.IsNull())
    { return FMars_Validation("Definition is not set"); }

    if (Self.Mode == EMars_WorldItem_Mode::World)
    {
        if (ck::Is_NOT_Valid(Self.Holder) || ck::Is_NOT_Valid(Self.Pickup))
        { return FMars_Validation("a World-mode world item needs a Holder and a Pickup"); }

        if (Self.Arrival.IsSet())
        { return FMars_Validation("only a Visual-mode world item arrives"); }

        if (Self.Launch.IsSet() && ck::Is_NOT_Valid(Self.Body))
        { return FMars_Validation("a launch needs a Body"); }

        return FMars_Validation();
    }

    if (ck::IsValid(Self.Holder) || ck::IsValid(Self.Pickup) || ck::IsValid(Self.Body) || Self.Launch.IsSet())
    { return FMars_Validation("a Visual-mode world item has no Holder, Pickup, Body or Launch"); }

    return FMars_Validation();
}

//--------------------------------------------------------------------------------------------------------------------------
// Params
//--------------------------------------------------------------------------------------------------------------------------

struct FMars_Fragment_WorldItem_Params
{
    UPROPERTY()
    EMars_WorldItem_Mode Mode = EMars_WorldItem_Mode::World;

    // Soft: fragments must not hold strong UObject refs.
    UPROPERTY()
    TSoftObjectPtr<UCk_InventoryItem_Definition> Definition;
}

//--------------------------------------------------------------------------------------------------------------------------
// State
//--------------------------------------------------------------------------------------------------------------------------

// World mode owns a capacity-1 holder and the item entity lives inside it, so pickup and drop are entity-preserving
// transfers. Every handle is invalid in Visual mode.
struct FMars_Fragment_WorldItem
{
    UPROPERTY()
    FCk_Handle_Inventory_DataOnly Holder;

    UPROPERTY()
    FCk_Handle_Interactable Pickup;

    UPROPERTY()
    FCk_Handle_JoltBody Body;

    // Persistent only; always World for a Transient item.
    UPROPERTY()
    EMars_WorldItem_Mount Mount = EMars_WorldItem_Mount::World;

    // Valid while Carried / Held.
    UPROPERTY()
    FCk_Handle Carrier;
}

//--------------------------------------------------------------------------------------------------------------------------
// Item-side marker (on the ITEM entity, not the world item)
//--------------------------------------------------------------------------------------------------------------------------

// Stamped once by a Persistent world item on its item at seed/adopt; lives as long as the item.
struct FMars_Fragment_Item_PersistentWorldItem
{
    UPROPERTY()
    FCk_Handle_WorldItem WorldItem;
}

//--------------------------------------------------------------------------------------------------------------------------
// Signals
//--------------------------------------------------------------------------------------------------------------------------

delegate void FMars_Delegate_WorldItem_OnMountChanged(FCk_Handle_WorldItem InWorldItem, EMars_WorldItem_Mount InPrev, EMars_WorldItem_Mount InNew);
event void FMars_Delegate_WorldItem_OnMountChanged_MC(FCk_Handle_WorldItem InWorldItem, EMars_WorldItem_Mount InPrev, EMars_WorldItem_Mount InNew);

struct FMars_Fragment_WorldItem_Signals
{
    FMars_Delegate_WorldItem_OnMountChanged_MC OnMountChanged;
}

//--------------------------------------------------------------------------------------------------------------------------
// Requests (Persistent items only)
//--------------------------------------------------------------------------------------------------------------------------

// World | Held -> Carried. Unset Point / Offset = the definition's CarryPoint / CarryOffset (the carrier's back, the hand);
// set, the carrier publishes Point and the item mounts there at Offset (a station dock).
struct FMars_Request_WorldItem_Carry
{
    UPROPERTY()
    FCk_Handle Carrier;

    UPROPERTY()
    TOptional<FGameplayTag> Point;

    UPROPERTY()
    TOptional<FTransform> Offset;

    FMars_Request_WorldItem_Carry() {}

    FMars_Request_WorldItem_Carry(const FCk_Handle& InCarrier)
    {
        Carrier = InCarrier;
    }

    FMars_Request_WorldItem_Carry(const FCk_Handle& InCarrier, FGameplayTag InPoint, const FTransform& InOffset)
    {
        Carrier = InCarrier;
        Point = TOptional<FGameplayTag>(InPoint);
        Offset = TOptional<FTransform>(InOffset);
    }
}

// What a Carry names instead of the definition's CarryPoint / CarryOffset; unset fields fall back to the definition. A
// Hold never overrides.
struct FMars_WorldItem_MountOverride
{
    UPROPERTY()
    TOptional<FGameplayTag> Point;

    UPROPERTY()
    TOptional<FTransform> Offset;

    FMars_WorldItem_MountOverride() {}

    FMars_WorldItem_MountOverride(TOptional<FGameplayTag> InPoint, TOptional<FTransform> InOffset)
    {
        Point = InPoint;
        Offset = InOffset;
    }
}

// What a Carry or Hold asks for before its attach node and offset are resolved (the drain's input, never a fragment).
struct FMars_WorldItem_MountRequest
{
    UPROPERTY()
    EMars_WorldItem_Mount Mount = EMars_WorldItem_Mount::Carried;

    UPROPERTY()
    FCk_Handle Carrier;

    UPROPERTY()
    FMars_WorldItem_MountOverride Override;

    FMars_WorldItem_MountRequest() {}

    FMars_WorldItem_MountRequest(EMars_WorldItem_Mount InMount, const FCk_Handle& InCarrier, const FMars_WorldItem_MountOverride& InOverride)
    {
        Mount = InMount;
        Carrier = InCarrier;
        Override = InOverride;
    }
}

// Carried -> Held.
struct FMars_Request_WorldItem_Hold
{
    UPROPERTY()
    FCk_Handle Carrier;

    FMars_Request_WorldItem_Hold() {}

    FMars_Request_WorldItem_Hold(const FCk_Handle& InCarrier)
    {
        Carrier = InCarrier;
    }
}

// Carried | Held -> World: the item is transferred from SourceInventory back into the world item's holder and the body
// is launched.
struct FMars_Request_WorldItem_Release
{
    UPROPERTY()
    FCk_Handle_Item Item;

    UPROPERTY()
    FCk_Handle_Inventory SourceInventory;

    UPROPERTY()
    FVector LinearVelocity = FVector::ZeroVector;

    UPROPERTY()
    FVector AngularVelocityDeg = FVector::ZeroVector;

    FMars_Request_WorldItem_Release() {}

    FMars_Request_WorldItem_Release(const FCk_Handle_Item& InItem,
                                    const FCk_Handle_Inventory& InSourceInventory,
                                    FVector InLinearVelocity,
                                    FVector InAngularVelocityDeg)
    {
        Item = InItem;
        SourceInventory = InSourceInventory;
        LinearVelocity = InLinearVelocity;
        AngularVelocityDeg = InAngularVelocityDeg;
    }
}

// Drain order Carry -> Hold -> Release (see UMars_Processor_WorldItem_HandleRequests).
struct FMars_Fragment_WorldItem_Requests
{
    UPROPERTY()
    TArray<FMars_Request_WorldItem_Carry> CarryRequests;

    UPROPERTY()
    TArray<FMars_Request_WorldItem_Hold> HoldRequests;

    UPROPERTY()
    TArray<FMars_Request_WorldItem_Release> ReleaseRequests;
}
