UCLASS(Abstract)
class UMars_Hud_Widget : UCk_ActivatableWidget_UE
{
    UPROPERTY(meta = (BindWidget))
    UMars_InteractPromptBox_Widget InteractPromptBox;

    UPROPERTY(meta = (BindWidget))
    UMars_Crosshair_Widget Crosshair;
}
