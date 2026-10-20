UCLASS(Abstract)
class UMars_InteractPrompt_Widget : UMars_KeyGlyph_Widget
{
    UPROPERTY(meta = (BindWidget))
    UCommonTextBlock PromptText;

    UPROPERTY(meta = (BindWidget))
    UCk_InputActionWidget_UE PromptIcon;

    UPROPERTY(meta = (BindWidgetOptional))
    UImage Duration;

    UPROPERTY(meta = (BindWidgetOptional))
    UWidget DurationOverlay;

    UPROPERTY(EditDefaultsOnly, Category = "InteractPrompt|Hold")
    FName ProgressParameterName = n"Percent";

    private UMaterialInstanceDynamic _ProgressDMI;
    private FCk_Handle_FloatAttribute _HoldAttribute;
    // The Control behind a ManuallyCompleted prompt: its manipulation progress fills the bar (no time attribute exists).
    private FCk_Handle_Control _ManipulatedControl;

    UFUNCTION(BlueprintOverride)
    void Construct()
    {
        EnsureProgressDMI();
    }

    UFUNCTION(BlueprintOverride)
    void Destruct()
    {
        StopHoldProgress();
        StopManipulation();
    }

    void OnVisualUpdate(FCk_Handle_InteractPrompt InPrompt)
    {
        auto InputAction = InPrompt.Get_InputAction();
        if (ck::EnsureIfNot(ck::IsValid(InputAction), "[Mars_InteractPrompt] Prompt has no resolvable InputAction"))
        { return; }

        // The kernel names why the action is blocked; the widget words it.
        auto Text = InPrompt.Get_DisplayText();
        const auto Reason = InPrompt.Get_BlockedReason();
        if (Reason == EMars_InteractPrompt_BlockedReason::HandsFull)
        { Text = NSLOCTEXT("MarsInteraction", "HandsFullPrompt", "Hands full"); }
        else if (Reason == EMars_InteractPrompt_BlockedReason::HotbarFull)
        { Text = NSLOCTEXT("MarsInteraction", "HotbarFullPrompt", "Hotbar full"); }

        Set_Prompt(Text, InputAction, InPrompt.Get_DisplayTextColor());
        Report_MissingIcon(PromptIcon, InputAction);

        auto Interaction = InPrompt.Get_CurrentInteraction();
        auto TimeAttribute = ck::IsValid(Interaction)
            ? utils_interaction::Get_InteractionTimeAttribute(Interaction)
            : FCk_Handle_FloatAttribute();

        if (ck::IsValid(TimeAttribute))
        { ListenForHoldProgress(TimeAttribute); }
        else
        { StopHoldProgress(); }

        auto Target = InPrompt.As_InteractTarget(ECk_SanityCheck::UnChecked);
        auto Control = ck::IsValid(Target) ? Target.TryGet_ManipulatedControl() : FCk_Handle_Control();

        // A ring shows for a timed hold or a pulled control (empty until it fills): a WhileLive target is ManuallyCompleted
        // too, and nothing would fill it.
        Show_Progress(InPrompt.Get_CompletionPolicy() == ECk_Interaction_CompletionPolicy::Timed || ck::IsValid(Control));

        if (ck::IsValid(Control))
        { ListenForManipulation(Control); }
        else
        { StopManipulation(); }
    }

    void Set_Prompt(FText InText, UInputAction InAction, FLinearColor InColor)
    {
        PromptText.SetText(InText);
        PromptText.SetColorAndOpacity(FSlateColor(InColor));

        if (ck::IsValid(InAction))
        { PromptIcon.SetEnhancedInputAction(InAction); }
    }

    private void ListenForHoldProgress(FCk_Handle_FloatAttribute InTimeAttribute)
    {
        if (_HoldAttribute == InTimeAttribute)
        { return; }

        StopHoldProgress();
        _HoldAttribute = InTimeAttribute;
        utils_float_attribute::BindTo_OnValueChanged(_HoldAttribute, ECk_MinMaxCurrent::Current,
            FCk_Delegate_FloatAttribute_OnValueChanged(this, n"OnHoldProgressChanged"));
        Refresh_ProgressFromAttribute();
    }

    private void StopHoldProgress()
    {
        if (ck::IsValid(_HoldAttribute))
        {
            utils_float_attribute::UnbindFrom_OnValueChanged(_HoldAttribute, ECk_MinMaxCurrent::Current,
                FCk_Delegate_FloatAttribute_OnValueChanged(this, n"OnHoldProgressChanged"));
        }

        _HoldAttribute = FCk_Handle_FloatAttribute();
        Set_ProgressPercent(0.0f);
    }

    // Idempotent on the same control; a repeat re-seeds the bar, which the hold-attribute path above has just zeroed.
    private void ListenForManipulation(FCk_Handle_Control InControl)
    {
        if (_ManipulatedControl == InControl)
        {
            Refresh_ManipulationBar();
            return;
        }

        StopManipulation();
        _ManipulatedControl = InControl;
        _ManipulatedControl.BindTo_OnManipulationProgress(FMars_Delegate_Control_OnManipulationProgress(this, n"OnManipulationProgress"));
        _ManipulatedControl.BindTo_OnManipulationChanged(FMars_Delegate_Control_OnManipulationChanged(this, n"OnManipulationChanged"));
        Refresh_ManipulationBar();
    }

    // Unset progress means not gripped: the ring stays, empty, until the control is held.
    private void Refresh_ManipulationBar()
    {
        Set_ProgressPercent(_ManipulatedControl.TryGet_ManipulationProgress().Get(0.0f));
    }

    private void StopManipulation()
    {
        if (ck::IsValid(_ManipulatedControl))
        {
            _ManipulatedControl.UnbindFrom_OnManipulationProgress(FMars_Delegate_Control_OnManipulationProgress(this, n"OnManipulationProgress"));
            _ManipulatedControl.UnbindFrom_OnManipulationChanged(FMars_Delegate_Control_OnManipulationChanged(this, n"OnManipulationChanged"));
        }

        _ManipulatedControl = FCk_Handle_Control();

        if (ck::Is_NOT_Valid(_HoldAttribute))
        { Set_ProgressPercent(0.0f); }
    }

    UFUNCTION()
    private void OnManipulationProgress(FCk_Handle_Control InControl, float32 InProgress)
    {
        Set_ProgressPercent(InProgress);
    }

    UFUNCTION()
    private void OnManipulationChanged(FCk_Handle_Control InControl, EMars_Control_Grip InGrip)
    {
        if (InGrip == EMars_Control_Grip::Released)
        { Set_ProgressPercent(0.0f); }
    }

    UFUNCTION()
    private void OnHoldProgressChanged(FCk_Handle InAttributeOwnerEntity, FCk_Payload_FloatAttribute_OnValueChanged InPayload)
    {
        Refresh_ProgressFromAttribute();
    }

    private void Refresh_ProgressFromAttribute()
    {
        if (ck::Is_NOT_Valid(_HoldAttribute))
        { return; }

        const auto Current = utils_float_attribute::Get_FinalValue(_HoldAttribute, ECk_MinMaxCurrent::Current);
        const auto Max = utils_float_attribute::Get_FinalValue(_HoldAttribute, ECk_MinMaxCurrent::Max);
        Set_ProgressPercent(Max > 0.0f ? Math::Clamp(Current / Max, 0.0f, 1.0f) : 0.0f);
    }

    private void Set_ProgressPercent(float32 InPercent)
    {
        EnsureProgressDMI();
        if (ck::IsValid(_ProgressDMI))
        { _ProgressDMI.SetScalarParameterValue(ProgressParameterName, InPercent); }
    }

    private void EnsureProgressDMI()
    {
        if (ck::IsValid(_ProgressDMI) || ck::Is_NOT_Valid(Duration))
        { return; }

        _ProgressDMI = Duration.GetDynamicMaterial();
    }

    private void Show_Progress(bool InVisible)
    {
        const auto NewVisibility = InVisible ? ESlateVisibility::HitTestInvisible : ESlateVisibility::Collapsed;
        if (ck::IsValid(DurationOverlay))
        { DurationOverlay.SetVisibility(NewVisibility); }
        else if (ck::IsValid(Duration))
        { Duration.SetVisibility(NewVisibility); }
    }
}
