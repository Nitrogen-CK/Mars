event void FMars_WorldBoardHost_Event();

// Tree-less activatable that holds UI.Layer.GameMenu for as long as a world board is open, so the CkUI layout owns
// the input mode (GameAndUI, cursor shown) and Back routes through CommonUI. It never takes keyboard focus: the
// viewport keeps it, so navigation keys still reach the board's input profile.
class UMars_WorldBoardHost_Widget : UCk_ActivatableWidget_UE
{
    default bIsFocusable = false;
    default bSupportsActivationFocus = false;
    default bIsBackHandler = true;

    FMars_WorldBoardHost_Event OnClosed;
    FMars_WorldBoardHost_Event OnBackRequested;

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
