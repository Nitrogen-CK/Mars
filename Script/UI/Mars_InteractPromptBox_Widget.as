UCLASS(Abstract)
class UMars_InteractPromptBox_Widget : UCk_UserWidget_UE
{
    UPROPERTY(meta = (BindWidget))
    UPanelWidget PromptContainer;

    UPROPERTY(EditDefaultsOnly, Category = "InteractPrompt")
    TSubclassOf<UMars_InteractPrompt_Widget> PromptWidgetClass;

    private TMap<FName, UMars_InteractPrompt_Widget> _ActivePrompts;
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
        PromptContainer.ClearChildren();

        _ActivePrompts.Empty();
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

            OnPromptAppeared(_Display, FMars_InteractPromptDisplay_SlotEvent(PromptSlot.SlotKey, PromptSlot.SortOrder, PromptSlot.Stack.Last().PromptHandle));
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
        PromptContainer.ClearChildren();

        _ActivePrompts.Empty();
    }

    UFUNCTION()
    private void OnPromptAppeared(FCk_Handle_InteractPromptDisplay InDisplay, FMars_InteractPromptDisplay_SlotEvent InEvent)
    {
        if (_ActivePrompts.Contains(InEvent.SlotKey))
        { return; }

        if (ck::EnsureIfNot(PromptWidgetClass != nullptr, "[Mars_InteractPromptBox] PromptWidgetClass is not set on the widget blueprint"))
        { return; }

        auto NewWidget = Cast<UMars_InteractPrompt_Widget>(WidgetBlueprint::CreateWidget(PromptWidgetClass, GetOwningPlayer()));
        if (ck::EnsureIfNot(ck::IsValid(NewWidget), f"[Mars_InteractPromptBox] Could not create the prompt widget for slot [{InEvent.SlotKey.ToString()}]"))
        { return; }

        _ActivePrompts.Add(InEvent.SlotKey, NewWidget);
        NewWidget.OnVisualUpdate(InEvent.Prompt);

        RebuildContainer(InDisplay);
    }

    UFUNCTION()
    private void OnPromptRemoved(FCk_Handle_InteractPromptDisplay InDisplay, FMars_InteractPromptDisplay_SlotEvent InEvent)
    {
        if (_ActivePrompts.Contains(InEvent.SlotKey) == false)
        { return; }

        _ActivePrompts[InEvent.SlotKey].RemoveFromParent();
        _ActivePrompts.Remove(InEvent.SlotKey);
    }

    UFUNCTION()
    private void OnPromptUpdated(FCk_Handle_InteractPromptDisplay InDisplay, FMars_InteractPromptDisplay_SlotEvent InEvent)
    {
        if (_ActivePrompts.Contains(InEvent.SlotKey))
        { _ActivePrompts[InEvent.SlotKey].OnVisualUpdate(InEvent.Prompt); }
    }

    // In the display's own slot order: SortOrder, ties in arrival order, so equal-priority prompts never swap between
    // rebuilds.
    private void RebuildContainer(const FCk_Handle_InteractPromptDisplay& InDisplay)
    {
        PromptContainer.ClearChildren();

        auto Slots = InDisplay.Get_Slots();
        for (const auto& PromptSlot : Slots)
        {
            if (_ActivePrompts.Contains(PromptSlot.SlotKey))
            { PromptContainer.AddChild(_ActivePrompts[PromptSlot.SlotKey]); }
        }
    }
}
