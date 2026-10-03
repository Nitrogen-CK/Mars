//--------------------------------------------------------------------------------------------------------------------------
// Dynamic Handle Definition
//--------------------------------------------------------------------------------------------------------------------------

asset Mars_EmoteWheelHandle of UCkDynamic_HandleDefinition
{
    TypeName = "FCk_Handle_EmoteWheel";
    RequiredFragments.Add(FMars_Feature_EmoteWheel);
    Description = "The player's emote wheel: the entries it offers, whether it is open and which sector its pointer hovers";
}
struct FMars_Feature_EmoteWheel {}

//--------------------------------------------------------------------------------------------------------------------------
// Enums
//--------------------------------------------------------------------------------------------------------------------------

// How a close ends the wheel.
enum EMars_EmoteWheel_CloseAction
{
    // Chooses the hovered entry when it is enabled; nothing otherwise.
    Choose,
    Cancel
}

//--------------------------------------------------------------------------------------------------------------------------
// Definition
//--------------------------------------------------------------------------------------------------------------------------

// One wheel sector. Sectors are laid out clockwise from the top in array order, all of equal size.
struct FMars_EmoteWheel_Entry
{
    // What a choice of this sector asks for; the emote player keys its animation on it.
    UPROPERTY(EditAnywhere, Category = "EmoteWheel")
    FGameplayTag Emote;

    UPROPERTY(EditAnywhere, Category = "EmoteWheel")
    FText DisplayName;

    // A tint-encoded icon (saturated red = the player-colour region), decoded by the icon material.
    UPROPERTY(EditAnywhere, Category = "EmoteWheel")
    TSoftObjectPtr<UTexture2D> Icon;

    // A disabled entry keeps its sector - the wheel never shrinks around it - and can be hovered, but not chosen.
    UPROPERTY(EditAnywhere, Category = "EmoteWheel")
    bool IsEnabled = true;
}

// The data the wheel is built from: add, remove or reorder entries here and the widget lays itself out again.
class UMars_EmoteWheel_Definition : UDataAsset
{
    UPROPERTY(EditAnywhere, Category = "EmoteWheel")
    TArray<FMars_EmoteWheel_Entry> Entries;
}

//--------------------------------------------------------------------------------------------------------------------------
// Spec
//--------------------------------------------------------------------------------------------------------------------------

// The pointer is virtual: while the wheel is open the look input moves it instead of the view, so mouse and stick
// select the same way and no cursor is needed.
struct FMars_EmoteWheel_Spec
{
    UPROPERTY()
    TSoftObjectPtr<UMars_EmoteWheel_Definition> Definition;

    // Look input (camera-intention units, about one per mouse count) from the centre to the rim.
    UPROPERTY()
    float32 PointerTravel = 40.0f;

    // The fraction of the radius around the centre that hovers nothing - releasing there cancels. Matches the centre
    // cancel button's share of the drawn wheel (the Disk material gets it too).
    UPROPERTY()
    float32 DeadZoneRatio = 0.25f;
}

mixin FMars_Validation Validate(const FMars_EmoteWheel_Spec& Self)
{
    if (Self.Definition.IsNull())
    { return FMars_Validation("Definition is not set"); }

    if (Self.PointerTravel <= 0.0f)
    { return FMars_Validation(f"PointerTravel [{Self.PointerTravel}] must be positive"); }

    if (Self.DeadZoneRatio < 0.0f || Self.DeadZoneRatio >= 1.0f)
    { return FMars_Validation(f"DeadZoneRatio [{Self.DeadZoneRatio}] is outside [0, 1)"); }

    return FMars_Validation();
}

//--------------------------------------------------------------------------------------------------------------------------
// Params
//--------------------------------------------------------------------------------------------------------------------------

// Entries are copied out of the Definition at Add, so the wheel never loads the asset again.
struct FMars_Fragment_EmoteWheel_Params
{
    UPROPERTY()
    FMars_EmoteWheel_Spec Spec;

    UPROPERTY()
    TArray<FMars_EmoteWheel_Entry> Entries;
}

//--------------------------------------------------------------------------------------------------------------------------
// State
//--------------------------------------------------------------------------------------------------------------------------

struct FMars_Fragment_EmoteWheel
{
    UPROPERTY()
    bool IsOpen = false;

    // Screen space (X right, Y down), length <= 1 = the rim. Reset to the centre on every open.
    UPROPERTY()
    FVector2D Pointer;

    // Unset while the pointer is in the dead zone (or the wheel is closed).
    UPROPERTY()
    TOptional<int32> HoveredIndex;
}

//--------------------------------------------------------------------------------------------------------------------------
// Signals
//--------------------------------------------------------------------------------------------------------------------------

delegate void FMars_Delegate_EmoteWheel_OnOpened(FCk_Handle_EmoteWheel InWheel);
event void FMars_Delegate_EmoteWheel_OnOpened_MC(FCk_Handle_EmoteWheel InWheel);

// Fires after OnEmoteChosen when the close chose one. HoveredIndex is already unset.
delegate void FMars_Delegate_EmoteWheel_OnClosed(FCk_Handle_EmoteWheel InWheel);
event void FMars_Delegate_EmoteWheel_OnClosed_MC(FCk_Handle_EmoteWheel InWheel);

// Only while open; a close resets the hover silently (OnClosed covers it). Read the new hover with Get_HoveredIndex.
delegate void FMars_Delegate_EmoteWheel_OnHoveredChanged(FCk_Handle_EmoteWheel InWheel);
event void FMars_Delegate_EmoteWheel_OnHoveredChanged_MC(FCk_Handle_EmoteWheel InWheel);

delegate void FMars_Delegate_EmoteWheel_OnEmoteChosen(FCk_Handle_EmoteWheel InWheel, int32 InIndex, FGameplayTag InEmote);
event void FMars_Delegate_EmoteWheel_OnEmoteChosen_MC(FCk_Handle_EmoteWheel InWheel, int32 InIndex, FGameplayTag InEmote);

struct FMars_Fragment_EmoteWheel_Signals
{
    FMars_Delegate_EmoteWheel_OnOpened_MC OnOpened;
    FMars_Delegate_EmoteWheel_OnClosed_MC OnClosed;
    FMars_Delegate_EmoteWheel_OnHoveredChanged_MC OnHoveredChanged;
    FMars_Delegate_EmoteWheel_OnEmoteChosen_MC OnEmoteChosen;
}

//--------------------------------------------------------------------------------------------------------------------------
// Requests
//--------------------------------------------------------------------------------------------------------------------------

// AngelScript rejects a TArray of an empty struct, so it carries one placeholder field.
struct FMars_Request_EmoteWheel_Open
{
    UPROPERTY()
    bool Requested = true;

    FMars_Request_EmoteWheel_Open() {}
}

// Ignored while closed.
struct FMars_Request_EmoteWheel_MovePointer
{
    // Look-input units, screen space (X right, Y down).
    UPROPERTY()
    FVector2D Delta;

    FMars_Request_EmoteWheel_MovePointer() {}

    FMars_Request_EmoteWheel_MovePointer(FVector2D InDelta)
    {
        Delta = InDelta;
    }
}

struct FMars_Request_EmoteWheel_Close
{
    UPROPERTY()
    EMars_EmoteWheel_CloseAction Action = EMars_EmoteWheel_CloseAction::Cancel;

    FMars_Request_EmoteWheel_Close() {}

    FMars_Request_EmoteWheel_Close(EMars_EmoteWheel_CloseAction InAction)
    {
        Action = InAction;
    }
}

struct FMars_Fragment_EmoteWheel_Requests
{
    UPROPERTY()
    TArray<FMars_Request_EmoteWheel_Open> OpenRequests;

    UPROPERTY()
    TArray<FMars_Request_EmoteWheel_MovePointer> MovePointerRequests;

    UPROPERTY()
    TArray<FMars_Request_EmoteWheel_Close> CloseRequests;
}
