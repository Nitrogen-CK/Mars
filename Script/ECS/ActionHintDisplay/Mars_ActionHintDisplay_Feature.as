//--------------------------------------------------------------------------------------------------------------------------
// Dynamic Handle Definitions
//--------------------------------------------------------------------------------------------------------------------------

asset Mars_ActionHintDisplayHandle of UCkDynamic_HandleDefinition
{
    TypeName = "FCk_Handle_ActionHintDisplay";
    RequiredFragments.Add(FMars_Feature_ActionHintDisplay);
    Description = "An entity that manages the contextual action-hint legend (lives on the player)";
}
struct FMars_Feature_ActionHintDisplay {}

asset Mars_ActionHintRowHandle of UCkDynamic_HandleDefinition
{
    TypeName = "FCk_Handle_ActionHintRow";
    RequiredFragments.Add(FMars_Feature_ActionHintRow);
    Description = "One row of an action-hint legend - a child entity of its ActionHintDisplay";
}
struct FMars_Feature_ActionHintRow {}

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
// Row
//--------------------------------------------------------------------------------------------------------------------------

// Set once when Request_RegisterHint mints the row; the display processor copies it into the row state on register.
struct FMars_Fragment_ActionHintRow_Params
{
    UPROPERTY()
    FMars_ActionHint_Spec Spec;
}

// Written only by the display processor. Sequence stays -1 until the row's register drains.
struct FMars_Fragment_ActionHintRow
{
    UPROPERTY()
    FMars_ActionHint_Spec Spec;

    UPROPERTY()
    int64 Sequence = -1;
}

//--------------------------------------------------------------------------------------------------------------------------
// State
//--------------------------------------------------------------------------------------------------------------------------

// Suppression never touches Hints, only what the display broadcasts, so a hidden row's owner can still unregister it.
struct FMars_Fragment_ActionHintDisplay
{
    // Registered rows, in registration order.
    UPROPERTY()
    TArray<FCk_Handle_ActionHintRow> Hints;

    UPROPERTY()
    int64 NextSequence = 0;

    UPROPERTY()
    int32 SuppressDepth = 0;

    // Rows whose Sequence is below it are hidden while SuppressDepth > 0.
    UPROPERTY()
    int64 SuppressWatermark = -1;
}

//--------------------------------------------------------------------------------------------------------------------------
// Signals
//--------------------------------------------------------------------------------------------------------------------------

delegate void FMars_Delegate_ActionHintDisplay_OnHintRegistered(
    FCk_Handle_ActionHintDisplay InDisplay, FCk_Handle_ActionHintRow InRow);
event void FMars_Delegate_ActionHintDisplay_OnHintRegistered_MC(
    FCk_Handle_ActionHintDisplay InDisplay, FCk_Handle_ActionHintRow InRow);

// The row is still alive when this fires; its destroy is requested right after.
delegate void FMars_Delegate_ActionHintDisplay_OnHintUnregistered(
    FCk_Handle_ActionHintDisplay InDisplay, FCk_Handle_ActionHintRow InRow);
event void FMars_Delegate_ActionHintDisplay_OnHintUnregistered_MC(
    FCk_Handle_ActionHintDisplay InDisplay, FCk_Handle_ActionHintRow InRow);

delegate void FMars_Delegate_ActionHintDisplay_OnHintUpdated(
    FCk_Handle_ActionHintDisplay InDisplay, FCk_Handle_ActionHintRow InRow);
event void FMars_Delegate_ActionHintDisplay_OnHintUpdated_MC(
    FCk_Handle_ActionHintDisplay InDisplay, FCk_Handle_ActionHintRow InRow);

struct FMars_Fragment_ActionHintDisplay_Signals
{
    FMars_Delegate_ActionHintDisplay_OnHintRegistered_MC OnHintRegistered;
    FMars_Delegate_ActionHintDisplay_OnHintUnregistered_MC OnHintUnregistered;
    FMars_Delegate_ActionHintDisplay_OnHintUpdated_MC OnHintUpdated;
}

//--------------------------------------------------------------------------------------------------------------------------
// Requests
//--------------------------------------------------------------------------------------------------------------------------

// Queued by Request_RegisterHint with the row it minted.
struct FMars_Request_ActionHintDisplay_Register
{
    UPROPERTY()
    FCk_Handle_ActionHintRow Row;

    FMars_Request_ActionHintDisplay_Register() {}

    FMars_Request_ActionHintDisplay_Register(const FCk_Handle_ActionHintRow& InRow)
    {
        Row = InRow;
    }
}

struct FMars_Request_ActionHintDisplay_Unregister
{
    UPROPERTY()
    FCk_Handle_ActionHintRow Row;

    FMars_Request_ActionHintDisplay_Unregister() {}

    FMars_Request_ActionHintDisplay_Unregister(const FCk_Handle_ActionHintRow& InRow)
    {
        Row = InRow;
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
    FCk_Handle_ActionHintRow Row;

    UPROPERTY()
    TOptional<FText> NewText;

    UPROPERTY()
    TOptional<FText> NewHoldLabel;

    FMars_Request_ActionHintDisplay_Update() {}

    FMars_Request_ActionHintDisplay_Update(const FCk_Handle_ActionHintRow& InRow)
    {
        Row = InRow;
    }

    FMars_Request_ActionHintDisplay_Update(const FCk_Handle_ActionHintRow& InRow, const FText& InNewText)
    {
        Row = InRow;
        NewText = TOptional<FText>(InNewText);
    }

    FMars_Request_ActionHintDisplay_Update(const FCk_Handle_ActionHintRow& InRow, const FText& InNewText, const FText& InNewHoldLabel)
    {
        Row = InRow;
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
