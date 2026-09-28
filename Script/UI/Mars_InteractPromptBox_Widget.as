UCLASS(Abstract)
class UMars_InteractPromptBox_Widget : UCk_UserWidget_UE
{
    UPROPERTY(meta = (BindWidget))
    UPanelWidget PromptContainer;

    UPROPERTY(EditDefaultsOnly, Category = "InteractPrompt")
    TSubclassOf<UMars_InteractPrompt_Widget> PromptWidgetClass;

    private TMap<FName, UMars_InteractPrompt_Widget> _ActivePrompts;
    private TMap<FName, int32> _SortOrders;
    private FCk_Handle_InteractPromptDisplay _Display;

    UFUNCTION(BlueprintOverride)
    void PreConstruct(bool bIsDesignTime)
    {
        if (bIsDesignTime == false || ck::Is_NOT_Valid(PromptContainer) || PromptWidgetClass == nullptr)
        { return; }

        PromptContainer.ClearChildren();
        for (int32 Index = 0; Index < 3; ++Index)
        {
            auto PreviewWidget = WidgetBlueprint::CreateWidget(PromptWidgetClass, GetOwningPlayer());
            if (ck::IsValid(PreviewWidget))
            { PromptContainer.AddChild(PreviewWidget); }
        }
    }

    UFUNCTION(BlueprintOverride)
    void Construct()
    {
        if (ck::IsValid(PromptContainer))
        { PromptContainer.ClearChildren(); }

        _ActivePrompts.Empty();
        _SortOrders.Empty();
    }

    UFUNCTION(BlueprintOverride)
    void OnValidContextInjected(FCk_Handle InContextEntity)
    {
        _Display = InContextEntity.As_InteractPromptDisplay(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(_Display))
        { return; }

        _Display.BindTo_OnPromptAppeared(FMars_Delegate_InteractPromptDisplay_OnPromptAppeared(this, n"OnPromptAppeared"));
        _Display.BindTo_OnPromptRemoved(FMars_Delegate_InteractPromptDisplay_OnPromptRemoved(this, n"OnPromptRemoved"));
        _Display.BindTo_OnPromptUpdated(FMars_Delegate_InteractPromptDisplay_OnPromptUpdated(this, n"OnPromptUpdated"));

        // The signals are edge-only; converge on what the display already holds.
        auto Slots = _Display.Get_Slots();
        for (const auto& PromptSlot : Slots)
        {
            if (PromptSlot.Stack.IsEmpty() || ck::Is_NOT_Valid(PromptSlot.Stack.Last().PromptHandle))
            { continue; }

            OnPromptAppeared(_Display, PromptSlot.SlotKey, PromptSlot.SortOrder, PromptSlot.Stack.Last().PromptHandle);
        }
    }

    UFUNCTION(BlueprintOverride)
    void OnContextCleared()
    {
        if (ck::IsValid(_Display))
        {
            _Display.UnbindFrom_OnPromptAppeared(FMars_Delegate_InteractPromptDisplay_OnPromptAppeared(this, n"OnPromptAppeared"));
            _Display.UnbindFrom_OnPromptRemoved(FMars_Delegate_InteractPromptDisplay_OnPromptRemoved(this, n"OnPromptRemoved"));
            _Display.UnbindFrom_OnPromptUpdated(FMars_Delegate_InteractPromptDisplay_OnPromptUpdated(this, n"OnPromptUpdated"));
        }

        _Display = FCk_Handle_InteractPromptDisplay();
        if (ck::IsValid(PromptContainer))
        { PromptContainer.ClearChildren(); }

        _ActivePrompts.Empty();
        _SortOrders.Empty();
    }

    UFUNCTION()
    private void OnPromptAppeared(FCk_Handle_InteractPromptDisplay InDisplay, FName InSlotKey, int32 InSortOrder, FCk_Handle_InteractPrompt InPrompt)
    {
        if (_ActivePrompts.Contains(InSlotKey))
        { return; }

        if (ck::EnsureIfNot(PromptWidgetClass != nullptr, "[Mars_InteractPromptBox] PromptWidgetClass is not set on the widget blueprint"))
        { return; }

        auto NewWidget = Cast<UMars_InteractPrompt_Widget>(WidgetBlueprint::CreateWidget(PromptWidgetClass, GetOwningPlayer()));
        if (ck::Is_NOT_Valid(NewWidget))
        { return; }

        _ActivePrompts.Add(InSlotKey, NewWidget);
        _SortOrders.Add(InSlotKey, InSortOrder);
        NewWidget.OnVisualUpdate(InPrompt);

        RebuildContainer();
    }

    UFUNCTION()
    private void OnPromptRemoved(FCk_Handle_InteractPromptDisplay InDisplay, FName InSlotKey, int32 InSortOrder, FCk_Handle_InteractPrompt InPrompt)
    {
        if (_ActivePrompts.Contains(InSlotKey) == false)
        { return; }

        _ActivePrompts[InSlotKey].RemoveFromParent();
        _ActivePrompts.Remove(InSlotKey);
        _SortOrders.Remove(InSlotKey);
    }

    UFUNCTION()
    private void OnPromptUpdated(FCk_Handle_InteractPromptDisplay InDisplay, FName InSlotKey, int32 InSortOrder, FCk_Handle_InteractPrompt InPrompt)
    {
        if (_ActivePrompts.Contains(InSlotKey))
        { _ActivePrompts[InSlotKey].OnVisualUpdate(InPrompt); }
    }

    private void RebuildContainer()
    {
        if (ck::Is_NOT_Valid(PromptContainer))
        { return; }

        TArray<FName> SortedKeys;
        _ActivePrompts.GetKeys(SortedKeys);

        for (int32 First = 0; First < SortedKeys.Num(); ++First)
        {
            for (int32 Second = First + 1; Second < SortedKeys.Num(); ++Second)
            {
                if (_SortOrders[SortedKeys[Second]] < _SortOrders[SortedKeys[First]])
                {
                    auto Swap = SortedKeys[First];
                    SortedKeys[First] = SortedKeys[Second];
                    SortedKeys[Second] = Swap;
                }
            }
        }

        PromptContainer.ClearChildren();
        for (auto Key : SortedKeys)
        { PromptContainer.AddChild(_ActivePrompts[Key]); }
    }
}
