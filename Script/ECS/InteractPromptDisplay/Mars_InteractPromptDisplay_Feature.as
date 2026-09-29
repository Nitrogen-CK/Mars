//--------------------------------------------------------------------------------------------------------------------------
// Dynamic Handle Definition
//--------------------------------------------------------------------------------------------------------------------------

asset Mars_InteractPromptDisplayHandle of UCkDynamic_HandleDefinition
{
    TypeName = "FCk_Handle_InteractPromptDisplay";
    RequiredFragments.Add(FMars_Feature_InteractPromptDisplay);
    Description = "An entity that manages stacked interact prompt display (lives on the player)";
}
struct FMars_Feature_InteractPromptDisplay {}

//--------------------------------------------------------------------------------------------------------------------------
// Signals
//--------------------------------------------------------------------------------------------------------------------------

delegate void FMars_Delegate_InteractPromptDisplay_OnPromptAppeared(
    FCk_Handle_InteractPromptDisplay InDisplay, FName InSlotKey, int32 InSortOrder, FCk_Handle_InteractPrompt InPrompt);
event void FMars_Delegate_InteractPromptDisplay_OnPromptAppeared_MC(
    FCk_Handle_InteractPromptDisplay InDisplay, FName InSlotKey, int32 InSortOrder, FCk_Handle_InteractPrompt InPrompt);

delegate void FMars_Delegate_InteractPromptDisplay_OnPromptRemoved(
    FCk_Handle_InteractPromptDisplay InDisplay, FName InSlotKey, int32 InSortOrder, FCk_Handle_InteractPrompt InPrompt);
event void FMars_Delegate_InteractPromptDisplay_OnPromptRemoved_MC(
    FCk_Handle_InteractPromptDisplay InDisplay, FName InSlotKey, int32 InSortOrder, FCk_Handle_InteractPrompt InPrompt);

delegate void FMars_Delegate_InteractPromptDisplay_OnPromptUpdated(
    FCk_Handle_InteractPromptDisplay InDisplay, FName InSlotKey, int32 InSortOrder, FCk_Handle_InteractPrompt InPrompt);
event void FMars_Delegate_InteractPromptDisplay_OnPromptUpdated_MC(
    FCk_Handle_InteractPromptDisplay InDisplay, FName InSlotKey, int32 InSortOrder, FCk_Handle_InteractPrompt InPrompt);

struct FMars_Fragment_InteractPromptDisplay_Signals
{
    FMars_Delegate_InteractPromptDisplay_OnPromptAppeared_MC OnPromptAppeared;
    FMars_Delegate_InteractPromptDisplay_OnPromptRemoved_MC OnPromptRemoved;
    FMars_Delegate_InteractPromptDisplay_OnPromptUpdated_MC OnPromptUpdated;
}

//--------------------------------------------------------------------------------------------------------------------------
// State
//--------------------------------------------------------------------------------------------------------------------------

// Stamped onto a prompt (by the display processor) when it joins a display, so a prompt text change can refresh that
// display.
struct FMars_Fragment_InteractPrompt_DisplayBinding
{
    UPROPERTY()
    FCk_Handle_InteractPromptDisplay Display;
}

// Entries are keyed by the prompt handle itself.
struct FMars_InteractPromptDisplay_Entry
{
    UPROPERTY()
    FCk_Handle_InteractPrompt PromptHandle;
}

// One slot per channel; only the top of a slot's stack is visible.
struct FMars_InteractPromptDisplay_Slot
{
    UPROPERTY()
    FName SlotKey;

    UPROPERTY()
    int32 SortOrder = 999;

    UPROPERTY()
    TArray<FMars_InteractPromptDisplay_Entry> Stack;
}

struct FMars_Fragment_InteractPromptDisplay
{
    UPROPERTY()
    TArray<FMars_InteractPromptDisplay_Slot> Slots;
}

//--------------------------------------------------------------------------------------------------------------------------
// Requests
//--------------------------------------------------------------------------------------------------------------------------

struct FMars_Request_InteractPromptDisplay_AddPrompt
{
    UPROPERTY()
    FCk_Handle_InteractPrompt Prompt;

    FMars_Request_InteractPromptDisplay_AddPrompt() {}

    FMars_Request_InteractPromptDisplay_AddPrompt(const FCk_Handle_InteractPrompt& InPrompt)
    {
        Prompt = InPrompt;
    }
}

// Removes the most recently added entry of that prompt.
struct FMars_Request_InteractPromptDisplay_RemovePrompt
{
    UPROPERTY()
    FCk_Handle_InteractPrompt Prompt;

    FMars_Request_InteractPromptDisplay_RemovePrompt() {}

    FMars_Request_InteractPromptDisplay_RemovePrompt(const FCk_Handle_InteractPrompt& InPrompt)
    {
        Prompt = InPrompt;
    }
}

// Re-broadcasts the slot whose top entry is that prompt.
struct FMars_Request_InteractPromptDisplay_RefreshPrompt
{
    UPROPERTY()
    FCk_Handle_InteractPrompt Prompt;

    FMars_Request_InteractPromptDisplay_RefreshPrompt() {}

    FMars_Request_InteractPromptDisplay_RefreshPrompt(const FCk_Handle_InteractPrompt& InPrompt)
    {
        Prompt = InPrompt;
    }
}

struct FMars_Fragment_InteractPromptDisplay_Requests
{
    UPROPERTY()
    TArray<FMars_Request_InteractPromptDisplay_AddPrompt> AddRequests;

    UPROPERTY()
    TArray<FMars_Request_InteractPromptDisplay_RemovePrompt> RemoveRequests;

    UPROPERTY()
    TArray<FMars_Request_InteractPromptDisplay_RefreshPrompt> RefreshRequests;
}
