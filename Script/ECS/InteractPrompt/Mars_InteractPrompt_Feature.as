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

struct FMars_InteractPrompt_Spec
{
    UPROPERTY()
    TSoftObjectPtr<UInputAction> InputAction;

    UPROPERTY()
    FText PromptText;

    UPROPERTY()
    FLinearColor TextColor = FLinearColor(1.0f, 1.0f, 1.0f, 1.0f);

    UPROPERTY()
    int32 SortOrder = 999;

    // Stamped at composition from the target's completion policy; the widget shows a hold bar.
    UPROPERTY()
    bool IsTimedInteraction = false;
}

//--------------------------------------------------------------------------------------------------------------------------
// Params
//--------------------------------------------------------------------------------------------------------------------------

// The spec fields read after construction. Text and color are mutable, so they live in FMars_Fragment_InteractPrompt.
struct FMars_Fragment_InteractPrompt_Params
{
    UPROPERTY()
    TSoftObjectPtr<UInputAction> InputAction;

    UPROPERTY()
    int32 SortOrder = 999;

    UPROPERTY()
    bool IsTimedInteraction = false;
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
    FLinearColor TextColor = FLinearColor(1.0f, 1.0f, 1.0f, 1.0f);

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

struct FMars_Fragment_InteractPrompt_Requests
{
    UPROPERTY()
    TArray<FMars_Request_InteractPrompt_UpdateText> UpdateRequests;

    UPROPERTY()
    TArray<FMars_Request_InteractPrompt_SetInteraction> SetInteractionRequests;
}
