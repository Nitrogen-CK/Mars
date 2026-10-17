// The per-world driver that turns the run's solved result into placed anchors' candidates: it finds every anchor
// through its entity tag, whenever it appears, and resolves it once (Mars_AnchorResolver_EntityScript.as).

//--------------------------------------------------------------------------------------------------------------------------
// Dynamic Handle Definition
//--------------------------------------------------------------------------------------------------------------------------

asset Mars_AnchorResolverHandle of UCkDynamic_HandleDefinition
{
    TypeName = "FCk_Handle_AnchorResolver";
    RequiredFragments.Add(FMars_Feature_AnchorResolver);
    Description = "Per-world driver that resolves every placed anchor from the run's solved result";
}
struct FMars_Feature_AnchorResolver {}

//--------------------------------------------------------------------------------------------------------------------------
// Spec
//--------------------------------------------------------------------------------------------------------------------------

struct FMars_AnchorResolver_Spec
{
    UPROPERTY()
    FMars_AnchorRun_Result Result;
}

// What UMars_AnchorResolver_EntityScript is spawned with (injection matches the `Resolver` property by name), so
// callers need no generated params namespace.
struct FMars_AnchorResolver_SpawnParams
{
    UPROPERTY()
    FMars_AnchorResolver_Spec Resolver;

    FMars_AnchorResolver_SpawnParams() {}

    FMars_AnchorResolver_SpawnParams(FMars_AnchorRun_Result InResult)
    {
        Resolver.Result = InResult;
    }
}

//--------------------------------------------------------------------------------------------------------------------------
// Params and state
//--------------------------------------------------------------------------------------------------------------------------

struct FMars_AnchorLedger_Entry
{
    UPROPERTY()
    FGameplayTag AnchorId;

    UPROPERTY()
    EMars_Anchor_Role Role = EMars_Anchor_Role::None;

    UPROPERTY()
    int32 RowIndex = 0;

    UPROPERTY()
    bool Pinned = false;

    UPROPERTY()
    bool RoleMismatch = false;

    // The row's class name, or "Nothing".
    UPROPERTY()
    FString ScriptName;

    UPROPERTY()
    FCk_Handle_Anchor Anchor;
}

struct FMars_Fragment_AnchorResolver_Params
{
    UPROPERTY()
    FMars_AnchorRun_Result Result;
}

struct FMars_Fragment_AnchorResolver
{
    // Sorted by AnchorId (the lowercase tag string).
    UPROPERTY()
    TArray<FMars_AnchorLedger_Entry> Ledger;
}

//--------------------------------------------------------------------------------------------------------------------------
// Signals
//--------------------------------------------------------------------------------------------------------------------------

delegate void FMars_Delegate_AnchorResolver_OnAnchorResolved(FCk_Handle_AnchorResolver InResolver, FMars_AnchorLedger_Entry InEntry);
event void FMars_Delegate_AnchorResolver_OnAnchorResolved_MC(FCk_Handle_AnchorResolver InResolver, FMars_AnchorLedger_Entry InEntry);

struct FMars_Fragment_AnchorResolver_Signals
{
    FMars_Delegate_AnchorResolver_OnAnchorResolved_MC OnAnchorResolved;
}

//--------------------------------------------------------------------------------------------------------------------------
// Requests
//--------------------------------------------------------------------------------------------------------------------------

struct FMars_Request_AnchorResolver_ResolveAnchor
{
    UPROPERTY()
    FCk_Handle_Anchor Anchor;

    FMars_Request_AnchorResolver_ResolveAnchor() {}

    FMars_Request_AnchorResolver_ResolveAnchor(FCk_Handle_Anchor InAnchor)
    {
        Anchor = InAnchor;
    }
}

struct FMars_Fragment_AnchorResolver_Requests
{
    UPROPERTY()
    TArray<FMars_Request_AnchorResolver_ResolveAnchor> ResolveAnchor;
}
