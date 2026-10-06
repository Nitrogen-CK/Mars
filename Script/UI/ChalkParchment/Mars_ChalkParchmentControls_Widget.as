event void FMars_ChalkInput_OnChanged(FText InText);
event void FMars_ChalkInput_OnCommitted(FText InText, ETextCommit InMethod);

UCLASS(Abstract)
class UMars_ChalkInput_Widget : UUserWidget
{
    UPROPERTY(meta = (BindWidget))
    UEditableTextBox Input;

    UPROPERTY(meta = (BindWidgetOptional))
    UCommonTextBlock Label;

    UPROPERTY(meta = (BindWidgetOptional))
    UCommonTextBlock ErrorText;

    UPROPERTY(meta = (BindWidgetOptional))
    UImage InvalidOutline;

    UPROPERTY(meta = (BindWidgetOptional))
    UImage WarningIcon;

    UPROPERTY(EditAnywhere, Category = "Mars")
    FText LabelText;

    UPROPERTY(EditAnywhere, Category = "Mars")
    FText HintText;

    FMars_ChalkInput_OnChanged OnChanged;
    FMars_ChalkInput_OnCommitted OnCommitted;

    private bool _ApplyingValue = false;

    UFUNCTION(BlueprintOverride)
    void OnInitialized()
    {
        Input.OnTextChanged.AddUFunction(this, n"HandleTextChanged");
        Input.OnTextCommitted.AddUFunction(this, n"HandleTextCommitted");
        RefreshPresentation();
        if (ck::IsValid(ErrorText))
        { ErrorText.SetVisibility(ESlateVisibility::Collapsed); }
        if (ck::IsValid(InvalidOutline))
        { InvalidOutline.SetVisibility(ESlateVisibility::Collapsed); }
        if (ck::IsValid(WarningIcon))
        { WarningIcon.SetVisibility(ESlateVisibility::Collapsed); }
    }

    UFUNCTION(BlueprintOverride)
    void PreConstruct(bool bIsDesignTime)
    { RefreshPresentation(); }

    void SetValue(FText InText)
    {
        _ApplyingValue = true;
        Input.SetText(InText);
        _ApplyingValue = false;
    }

    FText GetValue() const
    { return Input.GetText(); }

    void SetError(FText InText)
    {
        if (ck::IsValid(ErrorText))
        {
            ErrorText.SetText(InText);
            ErrorText.SetVisibility(InText.IsEmpty()
                ? ESlateVisibility::Collapsed
                : ESlateVisibility::SelfHitTestInvisible);
        }
        if (ck::IsValid(InvalidOutline))
        {
            InvalidOutline.SetVisibility(InText.IsEmpty()
                ? ESlateVisibility::Collapsed
                : ESlateVisibility::HitTestInvisible);
        }
        if (ck::IsValid(WarningIcon))
        {
            WarningIcon.SetVisibility(InText.IsEmpty()
                ? ESlateVisibility::Collapsed
                : ESlateVisibility::HitTestInvisible);
        }
    }

    void RefreshPresentation()
    {
        if (ck::IsValid(Label))
        { Label.SetText(LabelText); }
        if (ck::IsValid(Input))
        { Input.SetHintText(HintText); }
    }

    UFUNCTION()
    void HandleTextChanged(const FText&in InText)
    {
        if (_ApplyingValue == false)
        { OnChanged.Broadcast(InText); }
    }

    UFUNCTION()
    void HandleTextCommitted(const FText&in InText, ETextCommit InMethod)
    { OnCommitted.Broadcast(InText, InMethod); }
}
