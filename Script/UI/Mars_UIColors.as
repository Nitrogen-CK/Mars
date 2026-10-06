// Colours shared across widgets and features. A colour only one widget uses stays an EditDefaultsOnly property on that
// widget; one a second place needs moves here.
namespace constants_ui_colors
{
    // Interact prompt text for an action the player can take.
    const FLinearColor k_PromptText = FLinearColor(1.0f, 1.0f, 1.0f, 1.0f);

    // Interact prompt text for an action the player can't take right now (the prompt shows the reason).
    const FLinearColor k_PromptText_Blocked = FLinearColor(0.6f, 0.6f, 0.6f, 1.0f);

    // Parchment-kit moss greens: the hovered/active control tint and its pressed shade.
    const FLinearColor k_Moss = FLinearColor(0.55f, 0.72f, 0.30f, 1.0f);
    const FLinearColor k_MossDeep = FLinearColor(0.20f, 0.34f, 0.10f, 1.0f);
}
