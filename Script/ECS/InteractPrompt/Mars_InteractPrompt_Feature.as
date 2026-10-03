//--------------------------------------------------------------------------------------------------------------------------
// Dynamic Handle Definition
//--------------------------------------------------------------------------------------------------------------------------

asset Mars_InteractPromptHandle of UCkDynamic_HandleDefinition
{
    TypeName = "FCk_Handle_InteractPrompt";
    RequiredFragments.Add(FMars_Feature_InteractPrompt);
    Description = "An entity that has interact prompt configuration (input action, text, color)";
}
struct FMars_Feature_InteractPrompt {}

//--------------------------------------------------------------------------------------------------------------------------
// Spec
//--------------------------------------------------------------------------------------------------------------------------

// The prompt of one InteractTarget; its channel and completion policy are the target's.
struct FMars_InteractPrompt_Spec
{
    UPROPERTY()
    TSoftObjectPtr<UInputAction> InputAction;

    UPROPERTY()
    FText PromptText;

    UPROPERTY()
    FLinearColor TextColor = constants_ui_colors::k_PromptText;
}

// A prompt without an action renders no key glyph, and one without text leaves the player a glyph with no verb.
mixin FMars_Validation Validate(const FMars_InteractPrompt_Spec& Self)
{
    if (Self.InputAction.IsNull())
    { return FMars_Validation("InteractPrompt has no InputAction"); }

    if (Self.PromptText.IsEmpty())
    { return FMars_Validation("InteractPrompt has an empty PromptText"); }

    return FMars_Validation();
}

//--------------------------------------------------------------------------------------------------------------------------
// Constants
//--------------------------------------------------------------------------------------------------------------------------

namespace constants_interact_prompt
{
    // Display order: the Use prompt first, every other channel after it.
    const int32 k_UseSortOrder = 0;
    const int32 k_OtherSortOrder = 999;
}

//--------------------------------------------------------------------------------------------------------------------------
// Params
//--------------------------------------------------------------------------------------------------------------------------

// The spec fields read after construction, plus the target's channel and completion policy (read from the target by Add).
// Text and color are mutable, so they live in FMars_Fragment_InteractPrompt.
struct FMars_Fragment_InteractPrompt_Params
{
    UPROPERTY()
    TSoftObjectPtr<UInputAction> InputAction;

    UPROPERTY()
    FGameplayTag Channel;

    // Anything but Instant shows a hold bar: Timed fills from the interaction time, ManuallyCompleted from the control's
    // manipulation progress.
    UPROPERTY()
    ECk_Interaction_CompletionPolicy CompletionPolicy = ECk_Interaction_CompletionPolicy::Instant;
}

//--------------------------------------------------------------------------------------------------------------------------
// State
//--------------------------------------------------------------------------------------------------------------------------

// Seeded from the spec; UpdateText requests change the text/color here.
struct FMars_Fragment_InteractPrompt
{
    UPROPERTY()
    FText PromptText;

    UPROPERTY()
    FLinearColor TextColor = constants_ui_colors::k_PromptText;

    // Set while the action can't be taken: the reason shows instead of PromptText, which keeps following UpdateText.
    UPROPERTY()
    TOptional<FText> BlockedText;

    // The in-progress interaction on this prompt's target, tracked while the prompt is displayed.
    UPROPERTY()
    FCk_Handle_Interaction CurrentInteraction;
}

//--------------------------------------------------------------------------------------------------------------------------
// Signals
//--------------------------------------------------------------------------------------------------------------------------

delegate void FMars_Delegate_InteractPrompt_OnChanged(FCk_Handle_InteractPrompt InPrompt);
event void FMars_Delegate_InteractPrompt_OnChanged_MC(FCk_Handle_InteractPrompt InPrompt);

struct FMars_Fragment_InteractPrompt_Signals
{
    FMars_Delegate_InteractPrompt_OnChanged_MC OnChanged;
}

//--------------------------------------------------------------------------------------------------------------------------
// Requests
//--------------------------------------------------------------------------------------------------------------------------

struct FMars_Request_InteractPrompt_UpdateText
{
    UPROPERTY()
    FText NewText;

    UPROPERTY()
    TOptional<FLinearColor> NewColor;

    FMars_Request_InteractPrompt_UpdateText(const FText& InNewText)
    {
        NewText = InNewText;
    }

    FMars_Request_InteractPrompt_UpdateText(const FText& InNewText, const FLinearColor& InNewColor)
    {
        NewText = InNewText;
        NewColor = TOptional<FLinearColor>(InNewColor);
    }
}

// The in-progress interaction on the prompt's target (invalid when it finishes), for the widget's hold bar.
struct FMars_Request_InteractPrompt_SetInteraction
{
    UPROPERTY()
    FCk_Handle_Interaction Interaction;

    FMars_Request_InteractPrompt_SetInteraction() {}

    FMars_Request_InteractPrompt_SetInteraction(const FCk_Handle_Interaction& InInteraction)
    {
        Interaction = InInteraction;
    }
}

// The reason the action can't be taken right now; the default-constructed request clears it.
struct FMars_Request_InteractPrompt_SetBlocked
{
    UPROPERTY()
    TOptional<FText> BlockedText;

    FMars_Request_InteractPrompt_SetBlocked() {}

    FMars_Request_InteractPrompt_SetBlocked(const FText& InBlockedText)
    {
        BlockedText = TOptional<FText>(InBlockedText);
    }
}

struct FMars_Fragment_InteractPrompt_Requests
{
    UPROPERTY()
    TArray<FMars_Request_InteractPrompt_UpdateText> UpdateRequests;

    UPROPERTY()
    TArray<FMars_Request_InteractPrompt_SetBlocked> SetBlockedRequests;

    UPROPERTY()
    TArray<FMars_Request_InteractPrompt_SetInteraction> SetInteractionRequests;
}
