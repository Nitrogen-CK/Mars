// Stance SPLIT, nothing replicates here. A drop or a throw is the authority's: every machine that decides one fires
// Cue.Mars.HeldItemUse.Launch at the player's entity with its own aim (utils_held_item_use::Fire_LaunchCue), and the
// authority's drain launches the item as a World-mode world item under the replicated spawn owner; a client's own Drop
// or Throw request is dropped. ThrowArmed and the use interactable are owner-local (E): the HUD's throw-armed state and
// the use interactable live on the machine whose player holds the item, so their requests apply on every machine. A
// blow that lands on a zone another machine owns is the authority's too: the striking machine fires
// Cue.Mars.HeldItemUse.Strike at the player's entity (utils_held_item_use::Fire_StrikeCueFor), the authority's drain
// judges it against what it holds and deals it through the player's dealer from its own copy of the item's numbers; the
// tally of those claims is the authority's own and never replicates. A use that eats the held item is the authority's
// as well: the using machine asks through utils_held_item_use::Request_ConsumeFor, which fires
// Cue.Mars.HeldItemUse.Consume when it has no authority; the authority's drain judges it against what it holds and
// removes the item from its slot, whose replicated inventory tells every machine; that tally is the authority's own
// too.

//--------------------------------------------------------------------------------------------------------------------------
// Dynamic Handle Definition
//--------------------------------------------------------------------------------------------------------------------------

asset Mars_HeldItemUseHandle of UCkDynamic_HandleDefinition
{
    TypeName = "FCk_Handle_HeldItemUse";
    RequiredFragments.Add(FMars_Feature_HeldItemUse);
    Description = "Uses, drops and throws the item in the player's hands through a no-probe interactable on the player";
}
struct FMars_Feature_HeldItemUse {}

//--------------------------------------------------------------------------------------------------------------------------
// Enums
//--------------------------------------------------------------------------------------------------------------------------

// How a held item leaves the hands. Shared with FPHands, whose push pose differs per kind.
enum EMars_LaunchKind
{
    Drop,
    Throw
}

// Whose hand a launch leaves from.
enum EMars_HeldItemUse_LaunchOrigin
{
    // This machine's: its copy of the hand, or a Persistent item's mounted world item where it is.
    ThisMachine,
    // The launching machine's, carried in the aim and accepted (Get_AcceptedLaunchOrigin): a Persistent item's body is
    // moved there before it leaves (the Release's start pose).
    LaunchingMachine
}

// What a drop or throw of the held item would launch with right now. The launch and anything that predicts it read
// this one definition.
struct FMars_HeldItemUse_LaunchSolution
{
    // Where the item's body is when it leaves: the hand attach point, or a Persistent item's own mounted world item; either
    // taken from the launching machine's hand when the aim carries one the authority accepts (OriginFrom).
    UPROPERTY()
    FTransform Origin;

    UPROPERTY()
    EMars_HeldItemUse_LaunchOrigin OriginFrom = EMars_HeldItemUse_LaunchOrigin::ThisMachine;

    UPROPERTY()
    FVector LinearVelocity = FVector::ZeroVector;

    UPROPERTY()
    FVector AngularVelocityDeg = FVector::ZeroVector;
}

// How the held item's throw charges (its Throwable trait, or the defaults without one).
struct FMars_HeldItemUse_ThrowTuning
{
    // An uncharged throw's share of ThrowSpeed, 0..1.
    UPROPERTY()
    float32 MinThrowPower = constants_held_item_use::k_DefaultMinThrowPower;

    // Seconds from arming to a full charge; not positive charges at once.
    UPROPERTY()
    float32 ChargeSeconds = constants_held_item_use::k_DefaultThrowChargeSeconds;
}

// Why the authority refused a strike claim: the first check it failed, in the order the drain checks them.
enum EMars_HeldItemUse_StrikeRefusal
{
    // The player holds nothing, or nothing that strikes, or not the item the claim names.
    ItemMismatch,
    // The player's last applied blow is more recent than the held item's swing allows.
    TooSoon,
    // The address names no live zone with a hurtbox here.
    NoZone,
    // The contact is beyond the blade's reach from the striker's view, or away from every hurtbox of the zone.
    OutOfReach
}

// Why the authority refused a consume: the first check it failed, in the order the drain checks them.
enum EMars_HeldItemUse_ConsumeRefusal
{
    // The player holds nothing, or not the item the consume names.
    ItemMismatch,
    // The held item has no UseAction, or its use does not eat it.
    NotConsumable,
    // The held item is already leaving the hands: a launch or an earlier consume took it.
    Leaving,
    // The player's last applied consume is more recent than the held item's hold allows.
    TooSoon
}

//--------------------------------------------------------------------------------------------------------------------------
// Constants
//--------------------------------------------------------------------------------------------------------------------------

namespace constants_held_item_use
{
    // Used when the held item has no Throwable trait.
    const float32 k_DefaultDropSpeed = 150.0f;
    const float32 k_DefaultThrowSpeed = 900.0f;

    // Used when the held item has no Throwable trait: an uncharged throw's share of ThrowSpeed, and how long it takes to
    // charge to the full ThrowSpeed.
    const float32 k_DefaultMinThrowPower = 0.35f;
    const float32 k_DefaultThrowChargeSeconds = 1.0f;

    // Spawn distance in front of the view when the player has no hand attach point.
    const float32 k_NoHandSpawnDistance = 60.0f;

    // A launching machine's origin is used while it lies within this of the authority's copy of the carrier: an arm's
    // reach from the capsule's centre to the hand (about 100) plus k_StrikeReachSlack's latency lead or trail. Distance
    // only: no line-of-sight check, so a claimed origin up to this far away may lie behind a wall (follow-up).
    const float32 k_LaunchOriginReach = 250.0f;

    // A claimed contact may lie this much past the held item's Reach + Radius from the striker's view: the striking machine
    // swept from its own eye (Mars_ItemUse_Hfsm's DoSwing), which leads or trails the authority's copy of it by the latency.
    const float32 k_StrikeReachSlack = 150.0f;

    // A claimed contact must lie within this of one of the zone's hurtbox nodes.
    const float32 k_StrikeZoneSlack = 250.0f;

    // Two applied blows of one player are at least this fraction of the held item's Windup + Recovery apart.
    const float32 k_StrikeMinIntervalFraction = 0.5f;

    // Two applied consumes of one player are at least this fraction of the held item's hold apart (a Timed use only).
    const float32 k_ConsumeMinIntervalFraction = 0.5f;
}

//--------------------------------------------------------------------------------------------------------------------------
// State
//--------------------------------------------------------------------------------------------------------------------------

// The authority's count of the strike claims it judged. Never replicated: a client's copy stays default.
struct FMars_HeldItemUse_StrikeTally
{
    UPROPERTY()
    int32 Applied = 0;

    UPROPERTY()
    int32 Refused = 0;

    UPROPERTY()
    TOptional<EMars_HeldItemUse_StrikeRefusal> LastRefusal;

    // The authority's clock (utils_mars_net::Get_ServerWorldSeconds) when the last claim was applied.
    UPROPERTY()
    TOptional<float64> LastAppliedAt;
}

// The authority's count of the consumes it judged. Never replicated: a client's copy stays default.
struct FMars_HeldItemUse_ConsumeTally
{
    UPROPERTY()
    int32 Applied = 0;

    UPROPERTY()
    int32 Refused = 0;

    UPROPERTY()
    TOptional<EMars_HeldItemUse_ConsumeRefusal> LastRefusal;

    // The authority's clock (utils_mars_net::Get_ServerWorldSeconds) when the last consume was applied.
    UPROPERTY()
    TOptional<float64> LastAppliedAt;
}

// Lives on the player. CurrentInteractable is the no-probe interactable whose single Primary.UsableItem target runs the
// held item's UseAction state; it is rebuilt whenever the held item changes.
struct FMars_Fragment_HeldItemUse
{
    UPROPERTY()
    FCk_Handle_Interactable CurrentInteractable;

    // Requested by the drop/throw input task once Drop has been held past the throw threshold; the hint row, the throw
    // preview and the gloves' lowering follow it, and the throw charges while it is set. The input task still decides
    // throw-vs-drop from its own flag (see UMars_SmTask_DropThrowIntent).
    UPROPERTY()
    bool ThrowArmed = false;

    // How far the armed throw has charged, 0..1: zero when it arms, filling over the held item's ChargeSeconds and held at
    // 1 (UMars_Processor_HeldItemUse_ChargeThrow). A throw leaves at Get_ThrowPower of the item's ThrowSpeed.
    UPROPERTY()
    float32 ThrowCharge = 0.0f;

    // The item a drop/throw already launched. Its world item adopts it a frame or more later, so a second launch of
    // the same item before the held item changes would spawn a world item whose adopt fails. The guard holds until the
    // hands change (LaunchedAtItemChange): an item taken back keeps its handle and launches again.
    UPROPERTY()
    FCk_Handle_Item LaunchedItem;

    // The held item's change count when LaunchedItem was launched.
    UPROPERTY()
    int32 LaunchedAtItemChange = 0;

    // The item a consume already took. Its inventory removes it a frame or more later, so a second consume or a launch
    // of it in between must not act on it. It needs no reset: the item is destroyed.
    UPROPERTY()
    FCk_Handle_Item ConsumedItem;

    UPROPERTY()
    FMars_HeldItemUse_StrikeTally Strikes;

    UPROPERTY()
    FMars_HeldItemUse_ConsumeTally Consumes;
}

//--------------------------------------------------------------------------------------------------------------------------
// Signals
//--------------------------------------------------------------------------------------------------------------------------

delegate void FMars_Delegate_HeldItemUse_OnThrowArmedChanged(FCk_Handle_HeldItemUse InUse, bool InArmed);
event void FMars_Delegate_HeldItemUse_OnThrowArmedChanged_MC(FCk_Handle_HeldItemUse InUse, bool InArmed);

// The held item has just been dropped or thrown. It is still the held item (and the hands' hold) when this fires; the
// world item adopts it a frame or more later.
delegate void FMars_Delegate_HeldItemUse_OnItemLaunched(FCk_Handle_HeldItemUse InUse, FCk_Handle_Item InItem, EMars_LaunchKind InKind);
event void FMars_Delegate_HeldItemUse_OnItemLaunched_MC(FCk_Handle_HeldItemUse InUse, FCk_Handle_Item InItem, EMars_LaunchKind InKind);

struct FMars_Fragment_HeldItemUse_Signals
{
    FMars_Delegate_HeldItemUse_OnThrowArmedChanged_MC OnThrowArmedChanged;
    FMars_Delegate_HeldItemUse_OnItemLaunched_MC OnItemLaunched;
}

//--------------------------------------------------------------------------------------------------------------------------
// Requests
//--------------------------------------------------------------------------------------------------------------------------

// AngelScript rejects a TArray of an empty struct ("Subtype is an empty struct", Bind_TArray.cpp), so the payload-less
// requests carry one placeholder field.
struct FMars_Request_HeldItemUse_RefreshFromHeldItem
{
    UPROPERTY()
    bool Requested = true;

    FMars_Request_HeldItemUse_RefreshFromHeldItem() {}
}

// Where a launch goes and how hard, taken from the launching machine: the authority cannot know a client's view, nor
// how far that client charged its throw (the charge runs on the owner's copy).
struct FMars_HeldItemUse_Aim
{
    UPROPERTY()
    FVector Forward = FVector::ForwardVector;

    UPROPERTY()
    FVector PawnVelocity = FVector::ZeroVector;

    // A throw's share of the held item's ThrowSpeed (Get_ThrowPower where it was charged); a drop ignores it.
    UPROPERTY()
    float32 ThrowPower = 1.0f;

    // Where the launching machine's hand is (Get_OwnLaunchOrigin there): only the owner places the first-person hand; other
    // machines hold it in the body's hand. Unset, past k_LaunchOriginReach of the authority's pawn, or on the machine that
    // controls the carrier (where it is its own hand already): the authority's own.
    // A Persistent item leaves from HeldOffset on it (its world item's Release start pose).
    UPROPERTY()
    TOptional<FTransform> Origin;

    FMars_HeldItemUse_Aim() {}

    FMars_HeldItemUse_Aim(FVector InForward, FVector InPawnVelocity)
    {
        Forward = InForward;
        PawnVelocity = InPawnVelocity;
    }
}

// One launch: its kind and its aim (unset: the drain reads the player's view where it runs). The payload of
// Cue.Mars.HeldItemUse.Launch, and what the drain launches from.
struct FMars_HeldItemUse_Launch
{
    UPROPERTY()
    EMars_LaunchKind Kind = EMars_LaunchKind::Drop;

    UPROPERTY()
    TOptional<FMars_HeldItemUse_Aim> Aim;

    FMars_HeldItemUse_Launch() {}

    FMars_HeldItemUse_Launch(EMars_LaunchKind InKind, const FMars_HeldItemUse_Aim& InAim)
    {
        Kind = InKind;
        Aim = TOptional<FMars_HeldItemUse_Aim>(InAim);
    }
}

// Aim unset: the drain reads the player's view (a request issued on the authority itself, as the tests do).
struct FMars_Request_HeldItemUse_Drop
{
    UPROPERTY()
    bool Requested = true;

    UPROPERTY()
    TOptional<FMars_HeldItemUse_Aim> Aim;

    FMars_Request_HeldItemUse_Drop() {}

    FMars_Request_HeldItemUse_Drop(TOptional<FMars_HeldItemUse_Aim> InAim)
    {
        Aim = InAim;
    }
}

struct FMars_Request_HeldItemUse_Throw
{
    UPROPERTY()
    bool Requested = true;

    UPROPERTY()
    TOptional<FMars_HeldItemUse_Aim> Aim;

    FMars_Request_HeldItemUse_Throw() {}

    FMars_Request_HeldItemUse_Throw(TOptional<FMars_HeldItemUse_Aim> InAim)
    {
        Aim = InAim;
    }
}

// One blow claimed to the authority: the address of the zone it landed on (ZoneRoot, ZoneIndex), the definition of the
// item swung, the contact and the impulse the striking machine gave it. It carries no damage: the authority deals from
// its own copy of the held item. The payload of Cue.Mars.HeldItemUse.Strike.
struct FMars_HeldItemUse_Strike
{
    UPROPERTY()
    FCk_Handle ZoneRoot;

    UPROPERTY()
    int32 ZoneIndex = 0;

    UPROPERTY()
    TSoftObjectPtr<UCk_InventoryItem_Definition> Item;

    UPROPERTY()
    FVector Location = FVector::ZeroVector;

    UPROPERTY()
    FVector Normal = FVector::ZeroVector;

    UPROPERTY()
    FVector Impulse = FVector::ZeroVector;

    FMars_HeldItemUse_Strike() {}
}

struct FMars_Request_HeldItemUse_Strike
{
    UPROPERTY()
    FMars_HeldItemUse_Strike Strike;

    FMars_Request_HeldItemUse_Strike() {}

    FMars_Request_HeldItemUse_Strike(const FMars_HeldItemUse_Strike& InStrike)
    {
        Strike = InStrike;
    }
}

// What one swing's sweep found, as the strike task has it: the item swung, the sweep's result and the blow's impulse.
struct FMars_HeldItemUse_Swing
{
    UPROPERTY()
    FCk_Handle_Item Item;

    UPROPERTY()
    FCk_ShapeCast_Result Result;

    UPROPERTY()
    FVector Impulse = FVector::ZeroVector;

    FMars_HeldItemUse_Swing() {}

    FMars_HeldItemUse_Swing(FCk_Handle_Item InItem, const FCk_ShapeCast_Result& InResult, FVector InImpulse)
    {
        Item = InItem;
        Result = InResult;
        Impulse = InImpulse;
    }
}

// A use that eats the held item, asked of the authority: the item the using machine ate, by definition. It names no
// slot and no handle: the one item is the one the authority's HeldItem holds. The payload of
// Cue.Mars.HeldItemUse.Consume.
struct FMars_Request_HeldItemUse_Consume
{
    UPROPERTY()
    TSoftObjectPtr<UCk_InventoryItem_Definition> Item;

    FMars_Request_HeldItemUse_Consume() {}

    FMars_Request_HeldItemUse_Consume(TSoftObjectPtr<UCk_InventoryItem_Definition> InItem)
    {
        Item = InItem;
    }
}

struct FMars_Request_HeldItemUse_SetThrowArmed
{
    UPROPERTY()
    bool Armed = false;

    FMars_Request_HeldItemUse_SetThrowArmed() {}

    FMars_Request_HeldItemUse_SetThrowArmed(bool InArmed)
    {
        Armed = InArmed;
    }
}

// Drained Refresh -> Drop -> Throw -> Strike -> Consume -> SetThrowArmed; see the processor.
struct FMars_Fragment_HeldItemUse_Requests
{
    UPROPERTY()
    TArray<FMars_Request_HeldItemUse_RefreshFromHeldItem> RefreshFromHeldItemRequests;

    UPROPERTY()
    TArray<FMars_Request_HeldItemUse_Drop> DropRequests;

    UPROPERTY()
    TArray<FMars_Request_HeldItemUse_Throw> ThrowRequests;

    UPROPERTY()
    TArray<FMars_Request_HeldItemUse_Strike> StrikeRequests;

    UPROPERTY()
    TArray<FMars_Request_HeldItemUse_Consume> ConsumeRequests;

    UPROPERTY()
    TArray<FMars_Request_HeldItemUse_SetThrowArmed> SetThrowArmedRequests;
}
