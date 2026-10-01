UCLASS(Abstract)
class UMars_InteractPrompt_Widget : UCk_UserWidget_UE
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

        Set_Prompt(InPrompt.Get_PromptText(), InputAction, InPrompt.Get_PromptTextColor());
        Report_MissingIcon(InputAction);
        Show_Progress(InPrompt.Get_IsTimedInteraction());

        auto Interaction = InPrompt.Get_CurrentInteraction();
        auto TimeAttribute = ck::IsValid(Interaction)
            ? utils_interaction::Get_InteractionTimeAttribute(Interaction)
            : FCk_Handle_FloatAttribute();

        if (ck::IsValid(TimeAttribute))
        { ListenForHoldProgress(TimeAttribute); }
        else
        { StopHoldProgress(); }

        auto Control = FCk_Handle_Control();
        auto Target = FCk_Handle(InPrompt).As_InteractTarget(ECk_SanityCheck::UnChecked);
        if (ck::IsValid(Target) && Target.Has_Fragment(FMars_Fragment_InteractionContext)
            && Target.Get_InteractionCompletionPolicy() == ECk_Interaction_CompletionPolicy::ManuallyCompleted)
        { Control = Target.Get_Fragment(FMars_Fragment_InteractionContext).InteractableOwner.As_Control(ECk_SanityCheck::UnChecked); }

        if (ck::IsValid(Control))
        { ListenForManipulation(Control); }
        else
        { StopManipulation(); }
    }

    void Set_Prompt(FText InText, UInputAction InAction, FLinearColor InColor)
    {
        if (ck::IsValid(PromptText))
        {
            PromptText.SetText(InText);
            PromptText.SetColorAndOpacity(FSlateColor(InColor));
        }

        if (ck::IsValid(PromptIcon) && ck::IsValid(InAction))
        { PromptIcon.SetEnhancedInputAction(InAction); }
    }

    // Names the broken link once per widget when the key glyph cannot render: key resolution (profile / applied
    // contexts), brush lookup (CommonInput controller data for the current input type), or CommonUI collapsing the
    // action widget (e.g. Enhanced Input support off in CommonInputSettings).
    private bool _HasReportedMissingIcon = false;

    private void Report_MissingIcon(UInputAction InAction)
    {
        if (_HasReportedMissingIcon || ck::Is_NOT_Valid(PromptIcon))
        { return; }

        const auto Key = PromptIcon.Get_ResolvedKey();
        const auto Brush = UCk_Utils_KeyIcon_UE::Get_BrushForKey(GetOwningPlayer(), Key);
        const auto HasBrush = ck::IsValid(Brush.ResourceObject);
        const auto IconCollapsed = PromptIcon.GetVisibility() == ESlateVisibility::Collapsed;
        if (Key.IsValid() && HasBrush && IconCollapsed == false)
        { return; }

        _HasReportedMissingIcon = true;
        const FString KeyName = Key.IsValid() ? Key.ToString() : "Invalid";
        ck::Warning(f"[Mars_InteractPrompt] No key icon for [{InAction.GetName()}]: ResolvedKey=[{KeyName}] BrushFound=[{HasBrush}] IconCollapsed=[{IconCollapsed}]");
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
            Set_ProgressPercent(_ManipulatedControl.Get_ManipulationProgress());
            return;
        }

        StopManipulation();
        _ManipulatedControl = InControl;
        _ManipulatedControl.BindTo_OnManipulationProgress(FMars_Delegate_Control_OnManipulationProgress(this, n"OnManipulationProgress"));
        _ManipulatedControl.BindTo_OnManipulationChanged(FMars_Delegate_Control_OnManipulationChanged(this, n"OnManipulationChanged"));
        Set_ProgressPercent(_ManipulatedControl.Get_ManipulationProgress());
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
    private void OnManipulationChanged(FCk_Handle_Control InControl, bool InManipulating)
    {
        if (InManipulating == false)
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
