enum EMars_ChalkPauseAction
{
    Resume,
    Settings,
    ReturnToCamp,
    Leave
}

event void FMars_ChalkPauseActionRequested(EMars_ChalkPauseAction InAction);

UCLASS(Abstract)
class UMars_ChalkPause_Widget : UCk_ActivatableWidget_UE
{
    default bIsFocusable = true;
    default bIsBackHandler = true;

    UPROPERTY(meta = (BindWidget))
    UMars_Button_Widget Resume;

    UPROPERTY(meta = (BindWidget))
    UMars_Button_Widget Settings;

    UPROPERTY(meta = (BindWidget))
    UMars_Button_Widget ReturnToCamp;

    UPROPERTY(meta = (BindWidget))
    UMars_Button_Widget Leave;

    FMars_ChalkPauseActionRequested OnActionRequested;

    UFUNCTION(BlueprintOverride)
    void OnInitialized()
    {
        Resume.OnButtonBaseClicked.AddUFunction(this, n"OnResumeClicked");
        Settings.OnButtonBaseClicked.AddUFunction(this, n"OnSettingsClicked");
        ReturnToCamp.OnButtonBaseClicked.AddUFunction(this, n"OnReturnClicked");
        Leave.OnButtonBaseClicked.AddUFunction(this, n"OnLeaveClicked");
    }

    UFUNCTION(BlueprintOverride)
    UWidget BP_GetDesiredFocusTarget() const
    { return Resume; }

    UFUNCTION(BlueprintOverride)
    bool OnHandleBackAction()
    {
        OnActionRequested.Broadcast(EMars_ChalkPauseAction::Resume);
        return true;
    }

    void SetCanReturnToCamp(bool InCanReturn)
    {
        ReturnToCamp.SetVisibility(InCanReturn
            ? ESlateVisibility::Visible
            : ESlateVisibility::Collapsed);
    }

    UFUNCTION()
    private void OnResumeClicked(UCommonButtonBase InButton)
    { OnActionRequested.Broadcast(EMars_ChalkPauseAction::Resume); }

    UFUNCTION()
    private void OnSettingsClicked(UCommonButtonBase InButton)
    { OnActionRequested.Broadcast(EMars_ChalkPauseAction::Settings); }

    UFUNCTION()
    private void OnReturnClicked(UCommonButtonBase InButton)
    { OnActionRequested.Broadcast(EMars_ChalkPauseAction::ReturnToCamp); }

    UFUNCTION()
    private void OnLeaveClicked(UCommonButtonBase InButton)
    { OnActionRequested.Broadcast(EMars_ChalkPauseAction::Leave); }
}
