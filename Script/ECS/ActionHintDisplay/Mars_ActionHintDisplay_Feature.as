//--------------------------------------------------------------------------------------------------------------------------
// Dynamic Handle Definition
//--------------------------------------------------------------------------------------------------------------------------

asset Mars_ActionHintDisplayHandle of UCkDynamic_HandleDefinition
{
    TypeName = "FCk_Handle_ActionHintDisplay";
    RequiredFragments.Add(FMars_Feature_ActionHintDisplay);
    Description = "An entity that manages the contextual action-hint legend (lives on the player)";
}
struct FMars_Feature_ActionHintDisplay {}

//--------------------------------------------------------------------------------------------------------------------------
// ID
//--------------------------------------------------------------------------------------------------------------------------

struct FMars_ActionHint_ID
{
    UPROPERTY()
    int64 Value = -1;
}

//--------------------------------------------------------------------------------------------------------------------------
// Spec
//--------------------------------------------------------------------------------------------------------------------------

// One legend row. OwnerKey groups rows for bulk removal: a hint source exits with one UnregisterByOwner.
struct FMars_ActionHint_Spec
{
    // Observed, not owned: the input profile or asset registry keeps the action alive.
    UPROPERTY()
    TWeakObjectPtr<UInputAction> InputAction;

    UPROPERTY()
    FText Text;

    // Empty = no sub-label under the glyph.
    UPROPERTY()
    FText HoldLabel;

    UPROPERTY()
    int32 SortOrder = 999;

    UPROPERTY()
    FName OwnerKey;

    FMars_ActionHint_Spec() {}

    FMars_ActionHint_Spec(UInputAction InInputAction, FText InText, int32 InSortOrder, FName InOwnerKey)
    {
        InputAction = InInputAction;
        Text = InText;
        SortOrder = InSortOrder;
        OwnerKey = InOwnerKey;
    }

    FMars_ActionHint_Spec(UInputAction InInputAction, FText InText, FText InHoldLabel, int32 InSortOrder, FName InOwnerKey)
    {
        InputAction = InInputAction;
        Text = InText;
        HoldLabel = InHoldLabel;
        SortOrder = InSortOrder;
        OwnerKey = InOwnerKey;
    }
}

//--------------------------------------------------------------------------------------------------------------------------
// State
//--------------------------------------------------------------------------------------------------------------------------

struct FMars_ActionHintDisplay_Entry
{
    UPROPERTY()
    FMars_ActionHint_ID Id;

    UPROPERTY()
    FMars_ActionHint_Spec Spec;
}

// Suppression never touches Hints, only what the display broadcasts, so a hidden row's owner can still unregister it.
struct FMars_Fragment_ActionHintDisplay
{
    UPROPERTY()
    TArray<FMars_ActionHintDisplay_Entry> Hints;

    UPROPERTY()
    int64 NextId = 0;

    UPROPERTY()
    int32 SuppressDepth = 0;

    // Ids below it are hidden while SuppressDepth > 0.
    UPROPERTY()
    int64 SuppressWatermark = -1;
}

//--------------------------------------------------------------------------------------------------------------------------
// Signals
//--------------------------------------------------------------------------------------------------------------------------

delegate void FMars_Delegate_ActionHintDisplay_OnHintRegistered(
    FCk_Handle_ActionHintDisplay InDisplay, FMars_ActionHint_ID InId, FMars_ActionHint_Spec InSpec);
event void FMars_Delegate_ActionHintDisplay_OnHintRegistered_MC(
    FCk_Handle_ActionHintDisplay InDisplay, FMars_ActionHint_ID InId, FMars_ActionHint_Spec InSpec);

delegate void FMars_Delegate_ActionHintDisplay_OnHintUnregistered(
    FCk_Handle_ActionHintDisplay InDisplay, FMars_ActionHint_ID InId);
event void FMars_Delegate_ActionHintDisplay_OnHintUnregistered_MC(
    FCk_Handle_ActionHintDisplay InDisplay, FMars_ActionHint_ID InId);

delegate void FMars_Delegate_ActionHintDisplay_OnHintUpdated(
    FCk_Handle_ActionHintDisplay InDisplay, FMars_ActionHint_ID InId, FMars_ActionHint_Spec InSpec);
event void FMars_Delegate_ActionHintDisplay_OnHintUpdated_MC(
    FCk_Handle_ActionHintDisplay InDisplay, FMars_ActionHint_ID InId, FMars_ActionHint_Spec InSpec);

struct FMars_Fragment_ActionHintDisplay_Signals
{
    FMars_Delegate_ActionHintDisplay_OnHintRegistered_MC OnHintRegistered;
    FMars_Delegate_ActionHintDisplay_OnHintUnregistered_MC OnHintUnregistered;
    FMars_Delegate_ActionHintDisplay_OnHintUpdated_MC OnHintUpdated;
}

//--------------------------------------------------------------------------------------------------------------------------
// Requests
//--------------------------------------------------------------------------------------------------------------------------

struct FMars_Request_ActionHintDisplay_Register
{
    UPROPERTY()
    FMars_ActionHint_Spec Spec;

    UPROPERTY()
    FMars_ActionHint_ID PreAssignedId;

    FMars_Request_ActionHintDisplay_Register() {}

    FMars_Request_ActionHintDisplay_Register(const FMars_ActionHint_Spec& InSpec)
    {
        Spec = InSpec;
    }
}

struct FMars_Request_ActionHintDisplay_Unregister
{
    UPROPERTY()
    FMars_ActionHint_ID Id;

    FMars_Request_ActionHintDisplay_Unregister() {}

    FMars_Request_ActionHintDisplay_Unregister(const FMars_ActionHint_ID& InId)
    {
        Id = InId;
    }
}

struct FMars_Request_ActionHintDisplay_UnregisterByOwner
{
    UPROPERTY()
    FName OwnerKey;

    FMars_Request_ActionHintDisplay_UnregisterByOwner() {}

    FMars_Request_ActionHintDisplay_UnregisterByOwner(FName InOwnerKey)
    {
        OwnerKey = InOwnerKey;
    }
}

// Unset optionals leave the row's current value alone.
struct FMars_Request_ActionHintDisplay_Update
{
    UPROPERTY()
    FMars_ActionHint_ID Id;

    UPROPERTY()
    TOptional<FText> NewText;

    UPROPERTY()
    TOptional<FText> NewHoldLabel;

    FMars_Request_ActionHintDisplay_Update() {}

    FMars_Request_ActionHintDisplay_Update(const FMars_ActionHint_ID& InId)
    {
        Id = InId;
    }

    FMars_Request_ActionHintDisplay_Update(const FMars_ActionHint_ID& InId, const FText& InNewText)
    {
        Id = InId;
        NewText = TOptional<FText>(InNewText);
    }

    FMars_Request_ActionHintDisplay_Update(const FMars_ActionHint_ID& InId, const FText& InNewText, const FText& InNewHoldLabel)
    {
        Id = InId;
        NewText = TOptional<FText>(InNewText);
        NewHoldLabel = TOptional<FText>(InNewHoldLabel);
    }
}

// Ref-counted: the watermark is taken on the 0->1 edge and released on the 1->0 edge.
struct FMars_Request_ActionHintDisplay_SetSuppressed
{
    UPROPERTY()
    bool Suppressed = false;

    FMars_Request_ActionHintDisplay_SetSuppressed() {}

    FMars_Request_ActionHintDisplay_SetSuppressed(bool InSuppressed)
    {
        Suppressed = InSuppressed;
    }
}

struct FMars_Fragment_ActionHintDisplay_Requests
{
    UPROPERTY()
    TArray<FMars_Request_ActionHintDisplay_Register> RegisterRequests;

    UPROPERTY()
    TArray<FMars_Request_ActionHintDisplay_Update> UpdateRequests;

    UPROPERTY()
    TArray<FMars_Request_ActionHintDisplay_Unregister> UnregisterRequests;

    UPROPERTY()
    TArray<FMars_Request_ActionHintDisplay_UnregisterByOwner> UnregisterByOwnerRequests;

    UPROPERTY()
    TArray<FMars_Request_ActionHintDisplay_SetSuppressed> SuppressRequests;
}
