// A placed level ingredient that becomes one candidate at run start. The anchor never decides: the run's resolver
// (Script/ECS/AnchorResolver) picks its row and requests the resolve, and the anchor spawns that row's entity script as
// its own child (destroying the anchor destroys the candidate).

//--------------------------------------------------------------------------------------------------------------------------
// Dynamic Handle Definition
//--------------------------------------------------------------------------------------------------------------------------

asset Mars_AnchorHandle of UCkDynamic_HandleDefinition
{
    TypeName = "FCk_Handle_Anchor";
    RequiredFragments.Add(FMars_Feature_Anchor);
    Description = "A placed level ingredient that resolves at run start into one candidate entity script, or nothing";
}
struct FMars_Feature_Anchor {}

enum EMars_Anchor_Family
{
    Spawn,
    Hunt,
    Threat,
    Trap,
    Route,
    Forage,
    Cache,
    Omen,
    Traversal,
    Rest
}

// Idle until the resolver resolves it; Spawned once resolved (also when its row spawns nothing); Cleared after a clear.
enum EMars_Anchor_State
{
    Idle,
    Spawned,
    Cleared
}

//--------------------------------------------------------------------------------------------------------------------------
// Tables
//--------------------------------------------------------------------------------------------------------------------------

// One candidate. An unset Script is the Nothing row. Script classes are always loaded, so the table (a data asset,
// never a fragment) holds them directly.
struct FMars_AnchorTable_Row
{
    UPROPERTY()
    TSubclassOf<UCk_EntityScript_UE> Script;

    UPROPERTY()
    float32 Weight = 1.0f;

    UPROPERTY()
    EMars_Anchor_Role Role = EMars_Anchor_Role::Other;

    FMars_AnchorTable_Row() {}

    FMars_AnchorTable_Row(TSubclassOf<UCk_EntityScript_UE> InScript, float32 InWeight, EMars_Anchor_Role InRole)
    {
        Script = InScript;
        Weight = InWeight;
        Role = InRole;
    }
}

class UMars_AnchorTable_Def : UDataAsset
{
    UPROPERTY()
    EMars_Anchor_Family Family = EMars_Anchor_Family::Route;

    UPROPERTY()
    TArray<FMars_AnchorTable_Row> Rows;
}

//--------------------------------------------------------------------------------------------------------------------------
// What a candidate receives
//--------------------------------------------------------------------------------------------------------------------------

// Every candidate declares an ExposeOnSpawn property named exactly `Anchor` of this type, beside its SpawnTransform.
struct FMars_Anchor_Context
{
    UPROPERTY(meta = (Categories = "Anchor"))
    FGameplayTag AnchorId;

    UPROPERTY()
    FGameplayTag Channel;

    UPROPERTY()
    float32 SpanCm = 400.0f;

    UPROPERTY()
    float32 HomeRadiusCm = 1000.0f;

    UPROPERTY()
    int32 RunSeed = 0;
}

// Spawn params passed to every candidate. Injection matches by property name; an AngelScript class ignores a field it
// does not declare (CkEntityScript_Utils.cpp: only Blueprint classes ensure on a missing field).
struct FMars_Anchor_SpawnParams
{
    UPROPERTY()
    FTransform SpawnTransform;

    UPROPERTY()
    FMars_Anchor_Context Anchor;

    FMars_Anchor_SpawnParams() {}

    FMars_Anchor_SpawnParams(FTransform InSpawnTransform, FMars_Anchor_Context InAnchor)
    {
        SpawnTransform = InSpawnTransform;
        Anchor = InAnchor;
    }
}

//--------------------------------------------------------------------------------------------------------------------------
// Spec
//--------------------------------------------------------------------------------------------------------------------------

struct FMars_Anchor_Spec
{
    UPROPERTY(meta = (Categories = "Anchor"))
    FGameplayTag AnchorId;

    UPROPERTY()
    EMars_Anchor_Family Family = EMars_Anchor_Family::Route;

    UPROPERTY()
    TSoftObjectPtr<UMars_AnchorTable_Def> Table;

    // The anchor's world transform; the candidate spawns here.
    UPROPERTY()
    FTransform Transform;

    UPROPERTY()
    FGameplayTag Channel;

    UPROPERTY()
    float32 SpanCm = 400.0f;

    UPROPERTY()
    float32 HomeRadiusCm = 1000.0f;

    // Debug: always wins over the resolver's draw; the ledger marks it.
    UPROPERTY()
    TOptional<int32> PinnedRow;
}

mixin FMars_Validation Validate(const FMars_Anchor_Spec& Self)
{
    if (Self.AnchorId.IsValid() == false)
    { return FMars_Validation("anchor id must be set"); }

    if (Self.Table.IsNull())
    { return FMars_Validation("anchor table must be set"); }

    if (Self.SpanCm <= 0.0f || Self.HomeRadiusCm <= 0.0f)
    { return FMars_Validation("anchor span and home radius must be positive"); }

    if (Self.PinnedRow.IsSet() && Self.PinnedRow.GetValue() < 0)
    { return FMars_Validation("a pinned row cannot be negative"); }

    if (Self.Family == EMars_Anchor_Family::Route && Self.Channel.IsValid() == false)
    { return FMars_Validation("a route anchor needs a channel"); }

    return FMars_Validation();
}

//--------------------------------------------------------------------------------------------------------------------------
// Params
//--------------------------------------------------------------------------------------------------------------------------

struct FMars_Fragment_Anchor_Params
{
    UPROPERTY(meta = (Categories = "Anchor"))
    FGameplayTag AnchorId;

    UPROPERTY()
    EMars_Anchor_Family Family = EMars_Anchor_Family::Route;

    UPROPERTY()
    TSoftObjectPtr<UMars_AnchorTable_Def> Table;

    UPROPERTY()
    FTransform Transform;

    UPROPERTY()
    FGameplayTag Channel;

    UPROPERTY()
    float32 SpanCm = 400.0f;

    UPROPERTY()
    float32 HomeRadiusCm = 1000.0f;

    UPROPERTY()
    TOptional<int32> PinnedRow;
}

//--------------------------------------------------------------------------------------------------------------------------
// State
//--------------------------------------------------------------------------------------------------------------------------

struct FMars_Fragment_Anchor
{
    UPROPERTY()
    EMars_Anchor_State State = EMars_Anchor_State::Idle;

    UPROPERTY()
    EMars_Anchor_Role Role = EMars_Anchor_Role::None;

    UPROPERTY()
    TOptional<int32> RowIndex;

    // Invalid for a Nothing row.
    UPROPERTY()
    FCk_Handle Spawned;
}

//--------------------------------------------------------------------------------------------------------------------------
// Signals
//--------------------------------------------------------------------------------------------------------------------------

delegate void FMars_Delegate_Anchor_OnResolved(FCk_Handle_Anchor InAnchor, int32 InRowIndex);
event void FMars_Delegate_Anchor_OnResolved_MC(FCk_Handle_Anchor InAnchor, int32 InRowIndex);

struct FMars_Fragment_Anchor_Signals
{
    FMars_Delegate_Anchor_OnResolved_MC OnResolved;
}

//--------------------------------------------------------------------------------------------------------------------------
// Requests
//--------------------------------------------------------------------------------------------------------------------------

struct FMars_Request_Anchor_Resolve
{
    UPROPERTY()
    int32 RowIndex = 0;

    UPROPERTY()
    EMars_Anchor_Role Role = EMars_Anchor_Role::None;

    UPROPERTY()
    FMars_Anchor_Context Context;

    FMars_Request_Anchor_Resolve() {}

    FMars_Request_Anchor_Resolve(int32 InRowIndex, EMars_Anchor_Role InRole, FMars_Anchor_Context InContext)
    {
        RowIndex = InRowIndex;
        Role = InRole;
        Context = InContext;
    }
}

struct FMars_Request_Anchor_Clear
{
    UPROPERTY()
    int32 _Placeholder = 0;

    FMars_Request_Anchor_Clear() {}
}

// Applied in this order: every Clear, then every Resolve.
struct FMars_Fragment_Anchor_Requests
{
    UPROPERTY()
    TArray<FMars_Request_Anchor_Resolve> Resolve;

    UPROPERTY()
    TArray<FMars_Request_Anchor_Clear> Clear;
}
