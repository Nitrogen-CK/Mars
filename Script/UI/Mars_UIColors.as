// Colours shared across widgets and features. A colour only one widget uses stays an EditDefaultsOnly property on that
// widget; one a second place needs moves here.
namespace constants_ui_colors
{
    // Interact prompt text for an action the player can take.
    const FLinearColor k_PromptText = FLinearColor(1.0f, 1.0f, 1.0f, 1.0f);

    // Interact prompt text for an action the player can't take right now (the prompt shows the reason).
    const FLinearColor k_PromptText_Blocked = FLinearColor(0.6f, 0.6f, 0.6f, 1.0f);
}
