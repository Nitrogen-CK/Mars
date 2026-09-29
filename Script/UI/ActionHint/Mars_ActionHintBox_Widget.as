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
        for (const auto& Entry : VisibleHints)
        { OnHintRegistered(_Display, Entry.Id, Entry.Spec); }
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
    private void OnHintRegistered(FCk_Handle_ActionHintDisplay InDisplay, FMars_ActionHint_ID InId, FMars_ActionHint_Spec InSpec)
    {
        if (_ActiveHints.Contains(InId.Value))
        { return; }

        if (ck::EnsureIfNot(HintWidgetClass != nullptr, "[Mars_ActionHintBox] HintWidgetClass is not set on the widget blueprint"))
        { return; }

        auto NewWidget = Cast<UMars_ActionHint_Widget>(WidgetBlueprint::CreateWidget(HintWidgetClass, GetOwningPlayer()));
        if (ck::Is_NOT_Valid(NewWidget))
        { return; }

        _ActiveHints.Add(InId.Value, NewWidget);
        _SortOrders.Add(InId.Value, InSpec.SortOrder);
        NewWidget.OnVisualUpdate(InSpec);

        RebuildContainer();
    }

    UFUNCTION()
    private void OnHintUnregistered(FCk_Handle_ActionHintDisplay InDisplay, FMars_ActionHint_ID InId)
    {
        if (_ActiveHints.Contains(InId.Value) == false)
        { return; }

        _ActiveHints[InId.Value].RemoveFromParent();
        _ActiveHints.Remove(InId.Value);
        _SortOrders.Remove(InId.Value);
    }

    UFUNCTION()
    private void OnHintUpdated(FCk_Handle_ActionHintDisplay InDisplay, FMars_ActionHint_ID InId, FMars_ActionHint_Spec InSpec)
    {
        if (_ActiveHints.Contains(InId.Value) == false)
        { return; }

        _ActiveHints[InId.Value].OnVisualUpdate(InSpec);
    }

    // Ordered by (SortOrder, Id): ties keep registration order, so equal-priority rows never swap between rebuilds.
    private void RebuildContainer()
    {
        if (ck::Is_NOT_Valid(HintContainer))
        { return; }

        TArray<int64> SortedIds;
        _ActiveHints.GetKeys(SortedIds);

        for (int32 Current = 1; Current < SortedIds.Num(); ++Current)
        {
            const auto Moving = SortedIds[Current];
            auto Insert = Current;
            while (Insert > 0 && IsOrderedBefore(Moving, SortedIds[Insert - 1]))
            {
                SortedIds[Insert] = SortedIds[Insert - 1];
                Insert -= 1;
            }
            SortedIds[Insert] = Moving;
        }

        HintContainer.ClearChildren();
        for (auto Id : SortedIds)
        { HintContainer.AddChild(_ActiveHints[Id]); }
    }

    private bool IsOrderedBefore(int64 InLeftId, int64 InRightId)
    {
        const auto LeftOrder = _SortOrders[InLeftId];
        const auto RightOrder = _SortOrders[InRightId];
        if (LeftOrder != RightOrder)
        { return LeftOrder < RightOrder; }

        return InLeftId < InRightId;
    }
}
