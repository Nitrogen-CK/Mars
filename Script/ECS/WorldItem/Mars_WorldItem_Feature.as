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
    // The world item IS the item's body: it mounts where its item lives and moves between World / Carried / Held.
    Persistent
}

// Where a Persistent world item is right now.
enum EMars_WorldItem_Mount
{
    // A free Jolt body, pickable: the item is in the world item's own holder.
    World,
    // On an attach point of the carrier whose inventory holds the item (the back, a cargo slot, a station dock).
    Carried,
    // On the Hand attach point of the carrier whose selected hotbar slot holds the item.
    Held
}

// How an item in a mounting inventory sits on that inventory's lifetime owner (FMars_Fragment_MountedInventory).
enum EMars_WorldItem_MountRule
{
    // On the attach point the item names: Presentation.Mounting.CarryPoint at its CarryOffset (a hotbar slot).
    ItemCarryPoint,
    // On Point at the item's Presentation.Mounting.CargoOffset (a pack's cargo slot).
    PointAtCargoOffset,
    // On Point at Offset (a station dock).
    PointAtOffset
}

// What the inventory a Persistent world item's item lives in says about where it belongs
// (utils_world_item::Resolve_Target).
enum EMars_WorldItem_Placement
{
    // The target names the mount.
    Resolved,
    // The item is gone or ending: its world item ends with it.
    ItemGone,
    // The inventory holding the item, or that inventory's owner, is gone or ending: the world item ends with it.
    CarrierGone,
    // The item sits in no inventory, in one that names no mount (FMars_Fragment_MountedInventory), or on a carrier that
    // publishes no attach point for it.
    Unmountable
}

//--------------------------------------------------------------------------------------------------------------------------
// Constants
//--------------------------------------------------------------------------------------------------------------------------

namespace constants_world_item
{
    // A pending arrival older than this is dropped unread, so a stale pose never animates a later visual or mount.
    const float64 k_ArriveFromMaxAgeSeconds = 0.5;

    // A Carried or Held body rides its carrier: against the carrier's own capsule it would shove the character every step.
    const FName k_MountedBodyProfile = n"IgnoreOnlyPawn";

    // What a world item's own body collides as when its script names nothing else.
    const FName k_DefaultBodyProfile = n"PhysicsActor";

    // Passes a mount or a launch waits on a body still setting up before it goes on without it (a mount commits bodiless,
    // a launch is dropped): a body is in the simulation within a few passes of its Add.
    const int32 k_BodySetupBudgetPasses = 120;
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

// A box over what the item spans: from its Presentation mesh (x MeshScale, utils_world_item::Make_BoundsFit), or from what
// a subclass's body is made of (a food item's joint).
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
// Mounts
//--------------------------------------------------------------------------------------------------------------------------

// A mount: World (no carrier), or Carried / Held on Carrier's Point at Offset. Both what a world item is committed to and
// what its item's inventory says it should be (utils_world_item::Resolve_Target).
struct FMars_WorldItem_MountTarget
{
    UPROPERTY()
    EMars_WorldItem_Mount Mount = EMars_WorldItem_Mount::World;

    UPROPERTY()
    FCk_Handle Carrier;

    UPROPERTY()
    FGameplayTag Point;

    UPROPERTY()
    FTransform Offset;

    FMars_WorldItem_MountTarget() {}

    FMars_WorldItem_MountTarget(EMars_WorldItem_Mount InMount, const FCk_Handle& InCarrier, FGameplayTag InPoint, const FTransform& InOffset)
    {
        Mount = InMount;
        Carrier = InCarrier;
        Point = InPoint;
        Offset = InOffset;
    }
}

// What Resolve_Target read from the world item's item and the inventory it lives in.
struct FMars_WorldItem_Resolution
{
    UPROPERTY()
    EMars_WorldItem_Placement Placement = EMars_WorldItem_Placement::Resolved;

    UPROPERTY()
    FMars_WorldItem_MountTarget Target;

    // The inventory the item is in; invalid when it is in none.
    UPROPERTY()
    FCk_Handle_Inventory Inventory;
}

// How a mount arrives at its attach point: it stays where it was for DelaySeconds, then travels over Seconds with Easing. A
// mount taken at the gloves' grip passes the grip's remaining time and the gloves' return, so the item rides the gloves
// home (Request_ArriveNextMount). Unset = the presentation's ArriveSeconds, at once, OutCubic.
struct FMars_WorldItem_ArriveSpec
{
    UPROPERTY()
    float32 DelaySeconds = 0.0f;

    UPROPERTY()
    float32 Seconds = 0.25f;

    UPROPERTY()
    ECk_TweenEasing Easing = ECk_TweenEasing::OutCubic;

    FMars_WorldItem_ArriveSpec() {}

    FMars_WorldItem_ArriveSpec(float32 InDelaySeconds, float32 InSeconds, ECk_TweenEasing InEasing)
    {
        DelaySeconds = InDelaySeconds;
        Seconds = InSeconds;
        Easing = InEasing;
    }
}

// The next mount's arrival, kept until that mount is requested; aged by the time since StampedAtSeconds and dropped past
// constants_world_item::k_ArriveFromMaxAgeSeconds.
struct FMars_WorldItem_PendingArrive
{
    UPROPERTY()
    FMars_WorldItem_ArriveSpec Arrive;

    UPROPERTY()
    float64 StampedAtSeconds = 0.0;

    FMars_WorldItem_PendingArrive() {}

    FMars_WorldItem_PendingArrive(const FMars_WorldItem_ArriveSpec& InArrive, float64 InStampedAtSeconds)
    {
        Arrive = InArrive;
        StampedAtSeconds = InStampedAtSeconds;
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

    // Passes the launch has waited on a body still setting up (constants_world_item::k_BodySetupBudgetPasses bounds them).
    UPROPERTY()
    int32 WaitedPasses = 0;

    FMars_Fragment_WorldItem_PendingLaunch() {}

    FMars_Fragment_WorldItem_PendingLaunch(FVector InLinearVelocity, FVector InAngularVelocityDeg)
    {
        LinearVelocity = InLinearVelocity;
        AngularVelocityDeg = InAngularVelocityDeg;
    }
}

// Written by UMars_Processor_WorldItem_Reconcile, waiting for the body to read Kinematic before the scene-node attach
// (SetMotionType is deferred; attaching a Dynamic body's transform would fight the Jolt writeback for a frame). A body that
// failed setup, or is still setting up after constants_world_item::k_BodySetupBudgetPasses passes, is not waited for.
// Removed by a release's World commit. Drained by UMars_Processor_WorldItem_Mount.
struct FMars_Fragment_WorldItem_PendingMount
{
    UPROPERTY()
    FMars_WorldItem_MountTarget Target;

    UPROPERTY()
    FCk_Handle_Transform Node;

    // Unset = the presentation's arrival. Aged at the commit by the time since RequestedAtSeconds.
    UPROPERTY()
    TOptional<FMars_WorldItem_ArriveSpec> Arrive;

    UPROPERTY()
    float64 RequestedAtSeconds = 0.0;

    // Passes the mount has waited on a body still setting up.
    UPROPERTY()
    int32 WaitedPasses = 0;
}

// Holds the scene-node offset at FromOffset for DelaySeconds, then drives it FromOffset -> ToOffset with Easing over
// Duration; ONE Request_UpdateOffset per frame. Drained by UMars_Processor_WorldItem_Arrive.
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

    UPROPERTY()
    float32 DelaySeconds = 0.0f;

    UPROPERTY()
    ECk_TweenEasing Easing = ECk_TweenEasing::OutCubic;
}

// A release whose transfer back into the holder has not answered yet: the launch its World commit applies. Added by the
// Release drain, removed by the transfer's answer (UMars_Processor_WorldItem_HandleRequests).
struct FMars_Fragment_WorldItem_PendingRelease
{
    UPROPERTY()
    FVector LinearVelocity = FVector::ZeroVector;

    UPROPERTY()
    FVector AngularVelocityDeg = FVector::ZeroVector;

    FMars_Fragment_WorldItem_PendingRelease() {}

    FMars_Fragment_WorldItem_PendingRelease(FVector InLinearVelocity, FVector InAngularVelocityDeg)
    {
        LinearVelocity = InLinearVelocity;
        AngularVelocityDeg = InAngularVelocityDeg;
    }
}

//--------------------------------------------------------------------------------------------------------------------------
// Composition (a World-mode entity script's input to its shared tail)
//--------------------------------------------------------------------------------------------------------------------------

// What a World-mode entity script built for its body before the shared tail (holder, pickup, utils_world_item::Add) runs
// (UMars_WorldItem_EntityScript::Compose_WorldItem).
struct FMars_WorldItem_Composition
{
    // Invalid: the item rests where it was spawned.
    UPROPERTY()
    FCk_Handle_JoltBody Body;

    // The collision profile Body was built with: a released item goes back to it.
    UPROPERTY()
    FName BodyProfile = constants_world_item::k_DefaultBodyProfile;

    UPROPERTY()
    FMars_WorldItem_ProbeFit ProbeFit;

    // What the item's body spans, from the root: the gloves size and hand a reach for it from this, never from a mesh.
    UPROPERTY()
    FMars_WorldItem_BoundsFit BoundsFit;

    // Needs a Body.
    UPROPERTY()
    TOptional<FMars_Fragment_WorldItem_PendingLaunch> Launch;
}

//--------------------------------------------------------------------------------------------------------------------------
// Spec
//--------------------------------------------------------------------------------------------------------------------------

// A World-mode world item's parts: the holder its item lives in, the pickup, and what the entity script built for its body
// (the Composition's Body, BodyProfile, BoundsFit and Launch).
struct FMars_WorldItem_WorldParts
{
    UPROPERTY()
    FCk_Handle_Inventory_DataOnly Holder;

    UPROPERTY()
    FCk_Handle_Interactable Pickup;

    UPROPERTY()
    FMars_WorldItem_Composition Composition;

    FMars_WorldItem_WorldParts() {}

    FMars_WorldItem_WorldParts(const FCk_Handle_Inventory_DataOnly& InHolder, const FCk_Handle_Interactable& InPickup,
                               const FMars_WorldItem_Composition& InComposition)
    {
        Holder = InHolder;
        Pickup = InPickup;
        Composition = InComposition;
    }
}

// What the entity script composed for utils_world_item::Add: World mode sets World, Visual mode may set Arrival.
struct FMars_WorldItem_Spec
{
    UPROPERTY()
    EMars_WorldItem_Mode Mode = EMars_WorldItem_Mode::World;

    UPROPERTY()
    TSoftObjectPtr<UCk_InventoryItem_Definition> Definition;

    UPROPERTY()
    TOptional<FMars_WorldItem_WorldParts> World;

    // Visual mode: the offset lerp of a visual that arrives from somewhere.
    UPROPERTY()
    TOptional<FMars_Fragment_WorldItem_Arrival> Arrival;
}

mixin FMars_Validation Validate(const FMars_WorldItem_Spec& Self)
{
    if (Self.Definition.IsNull())
    { return FMars_Validation("Definition is not set"); }

    if (Self.Mode == EMars_WorldItem_Mode::Visual)
    {
        if (Self.World.IsSet())
        { return FMars_Validation("a Visual-mode world item has no World parts (Holder, Pickup, Body or Launch)"); }

        return FMars_Validation();
    }

    if (Self.Arrival.IsSet())
    { return FMars_Validation("only a Visual-mode world item arrives"); }

    if (Self.World.IsSet() == false)
    { return FMars_Validation("a World-mode world item needs its World parts"); }

    const auto& World = Self.World.GetValue();
    if (ck::Is_NOT_Valid(World.Holder) || ck::Is_NOT_Valid(World.Pickup))
    { return FMars_Validation("a World-mode world item needs a Holder and a Pickup"); }

    const auto& Composition = World.Composition;
    if (Composition.Launch.IsSet() && ck::Is_NOT_Valid(Composition.Body))
    { return FMars_Validation("a launch needs a Body"); }

    if (ck::IsValid(Composition.Body) && Composition.BodyProfile.IsNone())
    { return FMars_Validation("a Body needs the BodyProfile it was built with"); }

    if (ck::IsValid(Composition.Body))
    {
        const UCk_InventoryItem_Definition Definition = Self.Definition.Get();
        if (ck::IsValid(Definition))
        {
            const UMars_ItemTrait_Presentation Presentation = Definition.Get_ItemTraitByClass(UMars_ItemTrait_Presentation);
            if (ck::IsValid(Presentation) && Presentation.Mounting.MountedBodyProfile.IsNone())
            { return FMars_Validation("a Body needs its mounted collision profile"); }
        }
    }

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

    // Retained at composition: mount request and acknowledgement use the same profile name.
    UPROPERTY()
    FName MountedBodyProfile = constants_world_item::k_MountedBodyProfile;
}

//--------------------------------------------------------------------------------------------------------------------------
// State
//--------------------------------------------------------------------------------------------------------------------------

// World mode owns a capacity-1 holder and the item entity lives inside it, so pickup and drop are entity-preserving
// transfers. Every handle is invalid in Visual mode. Written by utils_world_item::Add / Add_Item and the WorldItem
// processors.
struct FMars_Fragment_WorldItem
{
    UPROPERTY()
    FCk_Handle_Inventory_DataOnly Holder;

    UPROPERTY()
    FCk_Handle_Interactable Pickup;

    UPROPERTY()
    FCk_Handle_JoltBody Body;

    // The profile Body was built with; a mount swaps it for its retained mounted profile and a release
    // restores it.
    UPROPERTY()
    FName BodyProfile = constants_world_item::k_DefaultBodyProfile;

    // The profile the body last confirmed (a completed SetCollisionProfile request: the body has no read-back); unset
    // until the first mount.
    UPROPERTY()
    TOptional<FName> AppliedBodyProfile;

    // Zero in Visual mode.
    UPROPERTY()
    FMars_WorldItem_BoundsFit BoundsFit;

    // Persistent only: the item this world item is the body of, linked once its holder seeded or adopted it
    // (utils_world_item::Add_Item). Unset before then, and always for a Transient or Visual-mode world item.
    UPROPERTY()
    TOptional<FCk_Handle_Item> Item;

    // The committed mount. Always World for a Transient item.
    UPROPERTY()
    FMars_WorldItem_MountTarget Committed;

    // How the next mount arrives (Request_ArriveNextMount); taken by the reconcile's next mount request.
    UPROPERTY()
    TOptional<FMars_WorldItem_PendingArrive> NextArrive;

    // The inventory the reconcile last reported as naming no mount for the item: it ensures once per placement.
    UPROPERTY()
    TOptional<FCk_Handle_Inventory> ReportedUnmountedIn;
}

//--------------------------------------------------------------------------------------------------------------------------
// Item-side marker (on the ITEM entity, not the world item)
//--------------------------------------------------------------------------------------------------------------------------

// Stamped once by utils_world_item::Add_Item on a Persistent world item's item; lives as long as the item.
struct FMars_Fragment_Item_PersistentWorldItem
{
    UPROPERTY()
    FCk_Handle_WorldItem WorldItem;
}

//--------------------------------------------------------------------------------------------------------------------------
// Inventory-side marker (on an INVENTORY entity: its items mount on its lifetime owner)
//--------------------------------------------------------------------------------------------------------------------------

// Stamped by whoever composes an inventory whose Persistent items ride its lifetime owner (the carrier), which publishes
// the attach point (utils_world_item::Add_MountedInventory): the hotbar's slots, a pack's cargo slots, a station's docks.
// An inventory without it holds no Persistent item but its world item's own holder.
struct FMars_Fragment_MountedInventory
{
    UPROPERTY()
    EMars_WorldItem_MountRule Rule = EMars_WorldItem_MountRule::ItemCarryPoint;

    // PointAtCargoOffset and PointAtOffset only.
    UPROPERTY()
    FGameplayTag Point;

    // PointAtOffset only.
    UPROPERTY()
    FTransform Offset;

    FMars_Fragment_MountedInventory() {}

    FMars_Fragment_MountedInventory(EMars_WorldItem_MountRule InRule, FGameplayTag InPoint, const FTransform& InOffset)
    {
        Rule = InRule;
        Point = InPoint;
        Offset = InOffset;
    }
}

//--------------------------------------------------------------------------------------------------------------------------
// Signals
//--------------------------------------------------------------------------------------------------------------------------

delegate void FMars_Delegate_WorldItem_OnMountChanged(FCk_Handle_WorldItem InWorldItem, EMars_WorldItem_Mount InPrev, EMars_WorldItem_Mount InNew);
event void FMars_Delegate_WorldItem_OnMountChanged_MC(FCk_Handle_WorldItem InWorldItem, EMars_WorldItem_Mount InPrev, EMars_WorldItem_Mount InNew);

// The world item came to rest on its committed mount (Get_IsSettled): the end of a mount's arrival, a mount committed
// without travel, or a release's World commit. Once per commit.
delegate void FMars_Delegate_WorldItem_OnMountSettled(FCk_Handle_WorldItem InWorldItem, EMars_WorldItem_Mount InMount, FCk_Handle InCarrier);
event void FMars_Delegate_WorldItem_OnMountSettled_MC(FCk_Handle_WorldItem InWorldItem, EMars_WorldItem_Mount InMount, FCk_Handle InCarrier);

// Why a Release left the world item where it was (OnReleaseRefused).
enum EMars_WorldItem_ReleaseRefusal
{
    // Not a Persistent world item linked to its item and mounted (Carried or Held).
    NotMounted,
    // Its last release has not answered yet.
    InFlight,
    // Its item is in no inventory but its own holder.
    NotAway,
    // The transfer back into its holder failed: it stays mounted.
    TransferFailed
}

// A Release that changed nothing: the world item stays on its mount. The answer to every release that does not end in the
// World commit (OnMountSettled with World).
delegate void FMars_Delegate_WorldItem_OnReleaseRefused(FCk_Handle_WorldItem InWorldItem, EMars_WorldItem_ReleaseRefusal InReason);
event void FMars_Delegate_WorldItem_OnReleaseRefused_MC(FCk_Handle_WorldItem InWorldItem, EMars_WorldItem_ReleaseRefusal InReason);

struct FMars_Fragment_WorldItem_Signals
{
    FMars_Delegate_WorldItem_OnMountChanged_MC OnMountChanged;
    FMars_Delegate_WorldItem_OnMountSettled_MC OnMountSettled;
    FMars_Delegate_WorldItem_OnReleaseRefused_MC OnReleaseRefused;
}

//--------------------------------------------------------------------------------------------------------------------------
// Requests (Persistent items only)
//--------------------------------------------------------------------------------------------------------------------------

// The next mount (wherever the item goes next) arrives this way: a pickup or a take at the gloves' grip rides them home.
struct FMars_Request_WorldItem_ArriveNextMount
{
    UPROPERTY()
    FMars_WorldItem_ArriveSpec Arrive;

    FMars_Request_WorldItem_ArriveNextMount() {}

    FMars_Request_WorldItem_ArriveNextMount(const FMars_WorldItem_ArriveSpec& InArrive)
    {
        Arrive = InArrive;
    }
}

// Carried | Held -> World: the item is transferred from whatever inventory holds it back into the world item's holder, and
// once that transfer answers, the body is launched with these velocities.
struct FMars_Request_WorldItem_Release
{
    UPROPERTY()
    FVector LinearVelocity = FVector::ZeroVector;

    UPROPERTY()
    FVector AngularVelocityDeg = FVector::ZeroVector;

    FMars_Request_WorldItem_Release() {}

    FMars_Request_WorldItem_Release(FVector InLinearVelocity, FVector InAngularVelocityDeg)
    {
        LinearVelocity = InLinearVelocity;
        AngularVelocityDeg = InAngularVelocityDeg;
    }
}

// Drain order ArriveNextMount -> Release (see UMars_Processor_WorldItem_HandleRequests).
struct FMars_Fragment_WorldItem_Requests
{
    UPROPERTY()
    TArray<FMars_Request_WorldItem_ArriveNextMount> ArriveNextMountRequests;

    UPROPERTY()
    TArray<FMars_Request_WorldItem_Release> ReleaseRequests;
}
