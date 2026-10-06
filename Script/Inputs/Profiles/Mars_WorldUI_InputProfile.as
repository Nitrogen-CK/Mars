// Enhanced Input bridge for the open world board: physical pointer, navigation, confirm, back and scroll are
// forwarded to the presenter's Slate virtual user. Back and Confirm reuse the CommonUI actions, so the same keys
// drive the screen modals above the board.
namespace mars
{
    asset Mars_IA_UI_Pointer of UCk_Boolean_InputAction
    {
    }

    asset Mars_IA_UI_NavUp of UCk_Boolean_InputAction
    {
    }

    asset Mars_IA_UI_NavDown of UCk_Boolean_InputAction
    {
    }

    asset Mars_IA_UI_NavLeft of UCk_Boolean_InputAction
    {
    }

    asset Mars_IA_UI_NavRight of UCk_Boolean_InputAction
    {
    }

    asset Mars_IA_UI_Scroll of UCk_Axis1d_InputAction
    {
    }

    asset Mars_IA_UI_AnyKey of UCk_Boolean_InputAction
    {
    }
}

class UMars_InputProfile_WorldUI : UMars_InputProfile
{
    private AMars_CampUiPresenter Presenter;
    private bool _TitleAdvanceInputHeld = false;

    UFUNCTION()
    void SetPresenter(AMars_CampUiPresenter InPresenter)
    { Presenter = InPresenter; }

    UFUNCTION(BlueprintOverride)
    void Setup(UEnhancedInputComponent InInputComponent)
    {
        Super::Setup(InInputComponent);
        Context = NewObject(this, UInputMappingContext);

        Context.MapKey(mars::Mars_IA_UI_Pointer, EKeys::LeftMouseButton);
        Context.MapKey(mars::Mars_IA_UI_NavUp, EKeys::Up);
        Context.MapKey(mars::Mars_IA_UI_NavUp, EKeys::Gamepad_DPad_Up);
        Context.MapKey(mars::Mars_IA_UI_NavDown, EKeys::Down);
        Context.MapKey(mars::Mars_IA_UI_NavDown, EKeys::Gamepad_DPad_Down);
        Context.MapKey(mars::Mars_IA_UI_NavLeft, EKeys::Left);
        Context.MapKey(mars::Mars_IA_UI_NavLeft, EKeys::Gamepad_DPad_Left);
        Context.MapKey(mars::Mars_IA_UI_NavRight, EKeys::Right);
        Context.MapKey(mars::Mars_IA_UI_NavRight, EKeys::Gamepad_DPad_Right);
        Context.MapKey(mars::Mars_IA_UI_Confirm, EKeys::Enter);
        Context.MapKey(mars::Mars_IA_UI_Confirm, EKeys::Gamepad_FaceButton_Bottom);
        Context.MapKey(mars::Mars_IA_UI_Back, EKeys::Escape);
        Context.MapKey(mars::Mars_IA_UI_Back, EKeys::Gamepad_FaceButton_Right);
        Context.MapKey(mars::Mars_IA_UI_AnyKey, EKeys::AnyKey);
        Context.MapKey(mars::Mars_IA_UI_Scroll, EKeys::MouseWheelAxis);

        BindPressRelease(InInputComponent, mars::Mars_IA_UI_Pointer, n"OnPointerPressed", n"OnPointerReleased");
        BindPressRelease(InInputComponent, mars::Mars_IA_UI_NavUp, n"OnNavigatePressed", n"OnNavigateReleased");
        BindPressRelease(InInputComponent, mars::Mars_IA_UI_NavDown, n"OnNavigatePressed", n"OnNavigateReleased");
        BindPressRelease(InInputComponent, mars::Mars_IA_UI_NavLeft, n"OnNavigatePressed", n"OnNavigateReleased");
        BindPressRelease(InInputComponent, mars::Mars_IA_UI_NavRight, n"OnNavigatePressed", n"OnNavigateReleased");
        BindPressRelease(InInputComponent, mars::Mars_IA_UI_Confirm, n"OnConfirmPressed", n"OnConfirmReleased");
        BindPressRelease(InInputComponent, mars::Mars_IA_UI_AnyKey, n"OnAnyKeyPressed", n"OnAnyKeyReleased");
        InInputComponent.BindAction(mars::Mars_IA_UI_Back, ETriggerEvent::Started,
            FEnhancedInputActionHandlerDynamicSignature(this, n"OnBack"));
        InInputComponent.BindAction(mars::Mars_IA_UI_Scroll, ETriggerEvent::Triggered,
            FEnhancedInputActionHandlerDynamicSignature(this, n"OnScroll"));
    }

    UFUNCTION(BlueprintOverride)
    void Deactivate(APlayerController InController)
    {
        _TitleAdvanceInputHeld = false;
        if (ck::IsValid(Presenter))
        { Presenter.UI_ReleaseInput(); }

        Super::Deactivate(InController);
    }

    private void BindPressRelease(UEnhancedInputComponent InInputComponent, UInputAction InAction,
        FName InPressed, FName InReleased)
    {
        InInputComponent.BindAction(InAction, ETriggerEvent::Started,
            FEnhancedInputActionHandlerDynamicSignature(this, InPressed));
        InInputComponent.BindAction(InAction, ETriggerEvent::Completed,
            FEnhancedInputActionHandlerDynamicSignature(this, InReleased));
        InInputComponent.BindAction(InAction, ETriggerEvent::Canceled,
            FEnhancedInputActionHandlerDynamicSignature(this, InReleased));
    }

    private bool Get_CanForwardInput() const
    { return ck::IsValid(OwningController) && ck::IsValid(Presenter); }

    // The title page advances on any key; the key that advanced it is swallowed until released.
    private bool ConsumeTitleAdvance()
    {
        if (_TitleAdvanceInputHeld)
        { return true; }
        if (Get_CanForwardInput() && Presenter.UI_TryAdvanceTitle())
        {
            _TitleAdvanceInputHeld = true;
            return true;
        }
        return false;
    }

    private FKey Get_NavigationKey(const UInputAction InAction) const
    {
        if (InAction == mars::Mars_IA_UI_NavUp)
        { return EKeys::Up; }
        if (InAction == mars::Mars_IA_UI_NavDown)
        { return EKeys::Down; }
        if (InAction == mars::Mars_IA_UI_NavLeft)
        { return EKeys::Left; }
        if (InAction == mars::Mars_IA_UI_NavRight)
        { return EKeys::Right; }
        return FKey();
    }

    UFUNCTION()
    private void OnPointerPressed(FInputActionValue ActionValue, float32 ElapsedTime,
        float32 TriggeredTime, const UInputAction SourceAction)
    {
        if (ConsumeTitleAdvance())
        { return; }
        if (Get_CanForwardInput())
        { Presenter.UI_PointerPressed(); }
    }

    UFUNCTION()
    private void OnPointerReleased(FInputActionValue ActionValue, float32 ElapsedTime,
        float32 TriggeredTime, const UInputAction SourceAction)
    {
        if (Get_CanForwardInput())
        { Presenter.UI_PointerReleased(); }
    }

    UFUNCTION()
    private void OnNavigatePressed(FInputActionValue ActionValue, float32 ElapsedTime,
        float32 TriggeredTime, const UInputAction SourceAction)
    {
        if (ConsumeTitleAdvance())
        { return; }
        const auto Key = Get_NavigationKey(SourceAction);
        if (Get_CanForwardInput() && Key.IsValid())
        { Presenter.UI_KeyPressed(Key); }
    }

    UFUNCTION()
    private void OnNavigateReleased(FInputActionValue ActionValue, float32 ElapsedTime,
        float32 TriggeredTime, const UInputAction SourceAction)
    {
        const auto Key = Get_NavigationKey(SourceAction);
        if (Get_CanForwardInput() && Key.IsValid())
        { Presenter.UI_KeyReleased(Key); }
    }

    UFUNCTION()
    private void OnConfirmPressed(FInputActionValue ActionValue, float32 ElapsedTime,
        float32 TriggeredTime, const UInputAction SourceAction)
    {
        if (ConsumeTitleAdvance())
        { return; }
        if (Get_CanForwardInput())
        { Presenter.UI_KeyPressed(EKeys::Enter); }
    }

    UFUNCTION()
    private void OnConfirmReleased(FInputActionValue ActionValue, float32 ElapsedTime,
        float32 TriggeredTime, const UInputAction SourceAction)
    {
        if (Get_CanForwardInput())
        { Presenter.UI_KeyReleased(EKeys::Enter); }
    }

    UFUNCTION()
    private void OnBack(FInputActionValue ActionValue, float32 ElapsedTime,
        float32 TriggeredTime, const UInputAction SourceAction)
    {
        if (ConsumeTitleAdvance())
        { return; }
        if (Get_CanForwardInput())
        { Presenter.UI_Back(); }
    }

    UFUNCTION()
    private void OnAnyKeyPressed(FInputActionValue ActionValue, float32 ElapsedTime,
        float32 TriggeredTime, const UInputAction SourceAction)
    { ConsumeTitleAdvance(); }

    UFUNCTION()
    private void OnAnyKeyReleased(FInputActionValue ActionValue, float32 ElapsedTime,
        float32 TriggeredTime, const UInputAction SourceAction)
    { _TitleAdvanceInputHeld = false; }

    UFUNCTION()
    private void OnScroll(FInputActionValue ActionValue, float32 ElapsedTime,
        float32 TriggeredTime, const UInputAction SourceAction)
    {
        if (Get_CanForwardInput())
        { Presenter.UI_Scroll(ActionValue.GetAxis1D()); }
    }
}
