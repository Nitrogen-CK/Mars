event void FMars_WorldBoardHost_Event();

// Tree-less activatable that holds UI.Layer.GameMenu for as long as a world board is open, so the CkUI layout owns
// the input mode (GameAndUI, cursor shown) and Back routes through CommonUI. It never takes keyboard focus: the
// viewport keeps it, so navigation keys still reach the board's input profile.
class UMars_WorldBoardHost_Widget : UCk_ActivatableWidget_UE
{
    default bIsFocusable = false;
    default bSupportsActivationFocus = false;
    default bIsBackHandler = true;

    // Stations forward physical mouse buttons through Enhanced Input to WidgetInteraction.
    // NoCapture drops ordinary viewport mouse-down events before that bridge sees them.
    UPROPERTY()
    bool bCaptureStationPointer = false;

    FMars_WorldBoardHost_Event OnClosed;
    FMars_WorldBoardHost_Event OnBackRequested;

    UFUNCTION(BlueprintOverride)
    FUIInputConfig GetDesiredInputConfig() const
    {
        FUIInputConfig Config;
        Config.InputMode = ECommonInputMode::All;
        Config.MouseCaptureMode = bCaptureStationPointer
            ? EMouseCaptureMode::CaptureDuringMouseDown
            : EMouseCaptureMode::NoCapture;
        Config.bHideCursorDuringViewportCapture = false;
        return Config;
    }

    UFUNCTION(BlueprintOverride)
    void OnDeactivated()
    { OnClosed.Broadcast(); }

    UFUNCTION(BlueprintOverride)
    bool OnHandleBackAction()
    {
        OnBackRequested.Broadcast();
        return true;
    }
}

// CommonUI selects desired input config only from activation-focus nodes. This
// station host participates without taking widget focus; the viewport receives it.
class UMars_StationWorldBoardHost_Widget : UMars_WorldBoardHost_Widget
{
    default bSupportsActivationFocus = true;
    default bCaptureStationPointer = true;
}
