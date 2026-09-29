UCLASS(Abstract)
class UMars_ActionHintBox_Widget : UCk_UserWidget_UE
{
    UPROPERTY(meta = (BindWidget))
    UPanelWidget HintContainer;

    UPROPERTY(EditDefaultsOnly, Category = "ActionHint")
    TSubclassOf<UMars_ActionHint_Widget> HintWidgetClass;

    private TMap<int64, UMars_ActionHint_Widget> _ActiveHints;
    private TMap<int64, int32> _SortOrders;
    private FCk_Handle_ActionHintDisplay _Display;

    UFUNCTION(BlueprintOverride)
    void PreConstruct(bool bIsDesignTime)
    {
        if (bIsDesignTime == false || ck::Is_NOT_Valid(HintContainer) || HintWidgetClass == nullptr)
        { return; }

        HintContainer.ClearChildren();
        for (int32 Index = 0; Index < 3; ++Index)
        {
            auto PreviewWidget = WidgetBlueprint::CreateWidget(HintWidgetClass, GetOwningPlayer());
            if (ck::IsValid(PreviewWidget))
            { HintContainer.AddChild(PreviewWidget); }
        }
    }

    UFUNCTION(BlueprintOverride)
    void Construct()
    {
        if (ck::IsValid(HintContainer))
        { HintContainer.ClearChildren(); }

        _ActiveHints.Empty();
        _SortOrders.Empty();
    }

    UFUNCTION(BlueprintOverride)
    void OnValidContextInjected(FCk_Handle InContextEntity)
    {
        _Display = InContextEntity.As_ActionHintDisplay(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(_Display))
        { return; }

        _Display.BindTo_OnHintRegistered(FMars_Delegate_ActionHintDisplay_OnHintRegistered(this, n"OnHintRegistered"));
        _Display.BindTo_OnHintUnregistered(FMars_Delegate_ActionHintDisplay_OnHintUnregistered(this, n"OnHintUnregistered"));
        _Display.BindTo_OnHintUpdated(FMars_Delegate_ActionHintDisplay_OnHintUpdated(this, n"OnHintUpdated"));

        // The signals are edge-only; converge on what the display already shows, suppressed rows excluded.
        auto VisibleHints = _Display.Get_VisibleHints();
        for (const auto& Row : VisibleHints)
        { OnHintRegistered(_Display, Row); }
    }

    UFUNCTION(BlueprintOverride)
    void OnContextCleared()
    {
        if (ck::IsValid(_Display))
        {
            _Display.UnbindFrom_OnHintRegistered(FMars_Delegate_ActionHintDisplay_OnHintRegistered(this, n"OnHintRegistered"));
            _Display.UnbindFrom_OnHintUnregistered(FMars_Delegate_ActionHintDisplay_OnHintUnregistered(this, n"OnHintUnregistered"));
            _Display.UnbindFrom_OnHintUpdated(FMars_Delegate_ActionHintDisplay_OnHintUpdated(this, n"OnHintUpdated"));
        }

        _Display = FCk_Handle_ActionHintDisplay();
        if (ck::IsValid(HintContainer))
        { HintContainer.ClearChildren(); }

        _ActiveHints.Empty();
        _SortOrders.Empty();
    }

    UFUNCTION()
    private void OnHintRegistered(FCk_Handle_ActionHintDisplay InDisplay, FCk_Handle_ActionHintRow InRow)
    {
        if (ck::Is_NOT_Valid(InRow))
        { return; }

        const auto Sequence = InRow.Get_Sequence();
        if (_ActiveHints.Contains(Sequence))
        { return; }

        if (ck::EnsureIfNot(HintWidgetClass != nullptr, "[Mars_ActionHintBox] HintWidgetClass is not set on the widget blueprint"))
        { return; }

        auto NewWidget = Cast<UMars_ActionHint_Widget>(WidgetBlueprint::CreateWidget(HintWidgetClass, GetOwningPlayer()));
        if (ck::Is_NOT_Valid(NewWidget))
        { return; }

        const auto Spec = InRow.Get_Spec();
        _ActiveHints.Add(Sequence, NewWidget);
        _SortOrders.Add(Sequence, Spec.SortOrder);
        NewWidget.OnVisualUpdate(Spec);

        RebuildContainer();
    }

    UFUNCTION()
    private void OnHintUnregistered(FCk_Handle_ActionHintDisplay InDisplay, FCk_Handle_ActionHintRow InRow)
    {
        if (ck::Is_NOT_Valid(InRow))
        { return; }

        const auto Sequence = InRow.Get_Sequence();
        if (_ActiveHints.Contains(Sequence) == false)
        { return; }

        _ActiveHints[Sequence].RemoveFromParent();
        _ActiveHints.Remove(Sequence);
        _SortOrders.Remove(Sequence);
    }

    UFUNCTION()
    private void OnHintUpdated(FCk_Handle_ActionHintDisplay InDisplay, FCk_Handle_ActionHintRow InRow)
    {
        if (ck::Is_NOT_Valid(InRow))
        { return; }

        const auto Sequence = InRow.Get_Sequence();
        if (_ActiveHints.Contains(Sequence) == false)
        { return; }

        _ActiveHints[Sequence].OnVisualUpdate(InRow.Get_Spec());
    }

    // Ordered by (SortOrder, Sequence): ties keep registration order, so equal-priority rows never swap between rebuilds.
    // Keyed by the row's Sequence, which the display assigns before the first broadcast of that row.
    private void RebuildContainer()
    {
        if (ck::Is_NOT_Valid(HintContainer))
        { return; }

        TArray<int64> SortedSequences;
        _ActiveHints.GetKeys(SortedSequences);

        for (int32 Current = 1; Current < SortedSequences.Num(); ++Current)
        {
            const auto Moving = SortedSequences[Current];
            auto Insert = Current;
            while (Insert > 0 && IsOrderedBefore(Moving, SortedSequences[Insert - 1]))
            {
                SortedSequences[Insert] = SortedSequences[Insert - 1];
                Insert -= 1;
            }
            SortedSequences[Insert] = Moving;
        }

        HintContainer.ClearChildren();
        for (auto Sequence : SortedSequences)
        { HintContainer.AddChild(_ActiveHints[Sequence]); }
    }

    private bool IsOrderedBefore(int64 InLeftSequence, int64 InRightSequence)
    {
        const auto LeftOrder = _SortOrders[InLeftSequence];
        const auto RightOrder = _SortOrders[InRightSequence];
        if (LeftOrder != RightOrder)
        { return LeftOrder < RightOrder; }

        return InLeftSequence < InRightSequence;
    }
}
