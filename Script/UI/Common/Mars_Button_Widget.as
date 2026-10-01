// Unstyled CommonUI button for menus. Style is picked per instance/WBP (Style property); the label collapses when empty.
UCLASS(Abstract)
class UMars_Button_Widget : UCommonButtonBase
{
    UPROPERTY(meta = (BindWidgetOptional))
    UCommonTextBlock Text;

    UPROPERTY(EditAnywhere, Category = "Mars")
    FText ButtonText;

    UFUNCTION(BlueprintOverride)
    void PreConstruct(bool bIsDesignTime)
    { RefreshLabel(); }

    // Public so an owner can re-apply after setting ButtonText at runtime (PreConstruct has already run by then).
    void RefreshLabel()
    {
        if (ck::Is_NOT_Valid(Text))
        { return; }

        Text.SetText(ButtonText);
        Text.SetVisibility(ButtonText.IsEmpty()
            ? ESlateVisibility::Collapsed
            : ESlateVisibility::SelfHitTestInvisible);
    }
}
