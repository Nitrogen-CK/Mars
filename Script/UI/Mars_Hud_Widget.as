UCLASS(Abstract)
class UMars_Hud_Widget : UCk_ActivatableWidget_UE
{
    UPROPERTY(meta = (BindWidget))
    UMars_InteractPromptBox_Widget InteractPromptBox;

    UPROPERTY(meta = (BindWidget))
    UMars_Crosshair_Widget Crosshair;

    // Optional so the game keeps running while the HUD WBP has not been given the child yet.
    UPROPERTY(meta = (BindWidgetOptional))
    UMars_ActionHintBox_Widget ActionHintBox;

    UPROPERTY(meta = (BindWidgetOptional))
    UMars_Hotbar_Widget Hotbar;
}
