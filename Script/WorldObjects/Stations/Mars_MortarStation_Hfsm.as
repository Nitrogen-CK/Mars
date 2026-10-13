// The mortar station's control layer: its own state machine (FMars_Station_Spec.MinigameStateClass =
// UMars_SmState_Mortar_Idle). It runs on the STATION entity (context = the station, which also carries the Mortar feature)
// and reads the station's operator; it only issues Mortar requests and registers the operator's legend rows. It owns no
// clock: the timing window, the strike and the grind are the kernel's.
//
//   Idle      ->Operated [StationIsOperated]
//   Operated  ->Idle     [StationIsNotOperated]   tasks: Mortar_Engage, Mortar_OperatorInput (Tick), Mortar_OperatorHints
//
// The batch persists across a leave and a re-enter: nothing is reset. The conditions are the shared station ones
// (Mars_Station_SmConditions.as). The player's Operating state owns the pose, the camera (Captured: the view stays still),
// the glove grips and the Leave intent; the operator's meter (UMars_MortarMeter_Widget, on the HUD) reads the kernel itself.

class UMars_SmState_Mortar_Idle : UCk_SmState_EntityScript
{
    UFUNCTION(BlueprintOverride)
    void DoDefineState(FCk_Handle_SmState_UnderConstruction& InHandle)
    {
        auto ToOperated = AddTransition(InHandle, UMars_SmState_Mortar_Operated);
        AddCondition(ToOperated, UMars_SmCondition_StationIsOperated);
    }
}

class UMars_SmState_Mortar_Operated : UCk_SmState_EntityScript
{
    UFUNCTION(BlueprintOverride)
    void DoDefineState(FCk_Handle_SmState_UnderConstruction& InHandle)
    {
        auto ToIdle = AddTransition(InHandle, UMars_SmState_Mortar_Idle);
        AddCondition(ToIdle, UMars_SmCondition_StationIsNotOperated);

        AddTask(InHandle, UMars_SmTask_Mortar_Engage);
        AddTask(InHandle, UMars_SmTask_Mortar_OperatorInput);
        AddTask(InHandle, UMars_SmTask_Mortar_OperatorHints);
    }
}

// The mortar's clocks run exactly as long as the Operated state: taking the station starts the timing window's pass, and
// leaving lets the pestle go. No Mortar on the context (a composition that failed and already ensured) = nothing to do.
class UMars_SmTask_Mortar_Engage : UCk_SmTask_EntityScript
{
    default _TaskMode = ECk_SmTaskMode::EnterExitOnly;

    UFUNCTION(BlueprintOverride)
    void DoEnterTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        auto Mortar = ck::Ctx(InHandle).As_Mortar(ECk_SanityCheck::UnChecked);
        if (ck::IsValid(Mortar))
        { Mortar.Request_Engage(FMars_Request_Mortar_Engage()); }
    }

    UFUNCTION(BlueprintOverride)
    void DoExitTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        auto Mortar = ck::Ctx(InHandle).As_Mortar(ECk_SanityCheck::UnChecked);
        if (ck::IsValid(Mortar))
        { Mortar.Request_Disengage(FMars_Request_Mortar_Disengage()); }
    }
}

// The operator's input, read off its InputIntents: Interact_Primary going down presses the pestle (a strike in the Crush
// phase, the grind in the Grind phase) and coming up releases it, one collect per rising edge of Interact_Secondary and
// one switch of seasoning per rising edge of Drop (R: the hands are empty at a station, so nothing else reads it here).
// All are seeded on enter, so a hold from before the station was taken never counts. No operator intents (headless) =
// nothing to read.
class UMars_SmTask_Mortar_OperatorInput : UCk_SmTask_EntityScript
{
    default _TaskMode = ECk_SmTaskMode::Tick;

    private FCk_Handle_Mortar _Mortar;
    private FCk_Handle_InputIntents _Intents;
    // The activation frame of the Interact_Primary hold last seen; unset while it is not held.
    private TOptional<int32> _SeenPrimaryFrame;
    // The same for Interact_Secondary.
    private TOptional<int32> _SeenCollectFrame;
    // The same for Drop.
    private TOptional<int32> _SeenSwitchFrame;

    UFUNCTION(BlueprintOverride)
    void DoEnterTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        auto StationEntity = ck::Ctx(InHandle);
        _Mortar = StationEntity.As_Mortar(ECk_SanityCheck::UnChecked);
        _Intents = FCk_Handle_InputIntents();

        auto Station = StationEntity.As_Station();
        auto Operator = Station.Get_Operator();
        _Intents = Operator.As_InputIntents(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(_Intents))
        { return; }

        _SeenPrimaryFrame = _Intents.TryGet_IntentActivationFrame(GameplayTags::Mars_Intent_Interact_Primary);
        _SeenCollectFrame = _Intents.TryGet_IntentActivationFrame(GameplayTags::Mars_Intent_Interact_Secondary);
        _SeenSwitchFrame = _Intents.TryGet_IntentActivationFrame(GameplayTags::Mars_Intent_Drop);
    }

    // Must return Running every frame: a Succeeded/Failed result would end the task while Operated is still active.
    UFUNCTION(BlueprintOverride)
    ECk_SmTaskResult DoTick(FCk_Handle_SmTask InHandle, FCk_Time InDeltaT, ECk_Sm_NetContext InNetContext)
    {
        if (ck::Is_NOT_Valid(_Mortar) || ck::Is_NOT_Valid(_Intents))
        { return ECk_SmTaskResult::Running; }

        const auto PrimaryFrame = _Intents.TryGet_IntentActivationFrame(GameplayTags::Mars_Intent_Interact_Primary);
        if (PrimaryFrame != _SeenPrimaryFrame)
        {
            // A new activation frame while one was already seen is a release and a press between two ticks: both are sent
            // (the kernel drains Release before Press).
            if (_SeenPrimaryFrame.IsSet())
            { _Mortar.Request_Release(FMars_Request_Mortar_Release()); }

            if (PrimaryFrame.IsSet())
            { _Mortar.Request_Press(FMars_Request_Mortar_Press()); }

            _SeenPrimaryFrame = PrimaryFrame;
        }

        const auto CollectFrame = _Intents.TryGet_IntentActivationFrame(GameplayTags::Mars_Intent_Interact_Secondary);
        if (CollectFrame != _SeenCollectFrame)
        {
            _SeenCollectFrame = CollectFrame;
            if (CollectFrame.IsSet())
            { _Mortar.Request_Collect(FMars_Request_Mortar_Collect()); }
        }

        const auto SwitchFrame = _Intents.TryGet_IntentActivationFrame(GameplayTags::Mars_Intent_Drop);
        if (SwitchFrame != _SeenSwitchFrame)
        {
            _SeenSwitchFrame = SwitchFrame;
            if (SwitchFrame.IsSet())
            { _Mortar.Request_SwitchSeasoning(FMars_Request_Mortar_SwitchSeasoning()); }
        }

        return ECk_SmTaskResult::Running;
    }

    UFUNCTION(BlueprintOverride)
    void DoExitTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        _Mortar = FCk_Handle_Mortar();
        _Intents = FCk_Handle_InputIntents();
        _SeenPrimaryFrame.Reset();
        _SeenCollectFrame.Reset();
        _SeenSwitchFrame.Reset();
    }
}

// The operator's legend rows while operating, under owner key k_OwnerKey, re-read on every step of the batch: the pestle's
// row (IA_Interact_Primary: "crush on the green" in the Crush phase, "hold to grind" in the Grind phase, gone once Done),
// "collect" (IA_Interact_Secondary) while the batch is Done, and the other seasoning's name (IA_Drop) while the batch is
// fresh. An operator without a display (headless) gets no rows.
class UMars_SmTask_Mortar_OperatorHints : UCk_SmTask_EntityScript
{
    default _TaskMode = ECk_SmTaskMode::EnterExitOnly;

    private const FName k_OwnerKey = n"Mortar";
    private const int32 k_PestleSortOrder = 5;
    private const int32 k_CollectSortOrder = 9;
    private const int32 k_SwitchSortOrder = 10;

    private FCk_Handle_Mortar _Mortar;
    private FCk_Handle_ActionHintDisplay _Display;
    private FCk_Handle_ActionHintRow _PestleRow;
    private FCk_Handle_ActionHintRow _CollectRow;
    private FCk_Handle_ActionHintRow _SwitchRow;

    UFUNCTION(BlueprintOverride)
    void DoEnterTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        _Display = FCk_Handle_ActionHintDisplay();

        auto StationEntity = ck::Ctx(InHandle);
        auto Station = StationEntity.As_Station();
        auto Operator = Station.Get_Operator();
        _Display = Operator.As_ActionHintDisplay(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(_Display))
        { return; }

        _Mortar = StationEntity.As_Mortar(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(_Mortar))
        { return; }

        _Mortar.BindTo_OnBatchChanged(FMars_Delegate_Mortar_OnBatchChanged(this, n"OnBatchChanged"));
        Refresh_Rows(_Mortar.Get_Batch());
    }

    UFUNCTION(BlueprintOverride)
    void DoExitTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        if (ck::IsValid(_Mortar))
        { _Mortar.UnbindFrom_OnBatchChanged(FMars_Delegate_Mortar_OnBatchChanged(this, n"OnBatchChanged")); }

        if (ck::IsValid(_Display))
        { _Display.Request_UnregisterHintsByOwner(FMars_Request_ActionHintDisplay_UnregisterByOwner(k_OwnerKey)); }

        _Mortar = FCk_Handle_Mortar();
        _Display = FCk_Handle_ActionHintDisplay();
        _PestleRow = FCk_Handle_ActionHintRow();
        _CollectRow = FCk_Handle_ActionHintRow();
        _SwitchRow = FCk_Handle_ActionHintRow();
    }

    UFUNCTION()
    private void OnBatchChanged(FCk_Handle_Mortar InMortar, FMars_Mortar_Batch InBatch)
    {
        if (ck::Is_NOT_Valid(_Display))
        { return; }

        Refresh_Rows(InBatch);
    }

    private void Refresh_Rows(const FMars_Mortar_Batch& InBatch)
    {
        if (InBatch.Phase == EMars_Mortar_Phase::Done)
        { _PestleRow = Clear_Row(_PestleRow); }
        else
        {
            const FString PestleText = InBatch.Phase == EMars_Mortar_Phase::Crush ? "crush on the green" : "hold to grind";
            _PestleRow = Show_Row(_PestleRow, FMars_ActionHint_Spec(mars::Mars_IA_Interact_Primary, FText::FromString(PestleText), k_PestleSortOrder, k_OwnerKey));
        }

        if (InBatch.Phase == EMars_Mortar_Phase::Done)
        { _CollectRow = Show_Row(_CollectRow, FMars_ActionHint_Spec(mars::Mars_IA_Interact_Secondary, FText::FromString("collect"), k_CollectSortOrder, k_OwnerKey)); }
        else
        { _CollectRow = Clear_Row(_CollectRow); }

        if (utils_mortar::Get_IsFresh(InBatch))
        {
            const FString SwitchText = InBatch.Seasoning == EMars_Mortar_Seasoning::Salt ? "switch to pepper" : "switch to salt";
            _SwitchRow = Show_Row(_SwitchRow, FMars_ActionHint_Spec(mars::Mars_IA_Drop, FText::FromString(SwitchText), k_SwitchSortOrder, k_OwnerKey));
        }
        else
        { _SwitchRow = Clear_Row(_SwitchRow); }
    }

    // InRow reading InSpec's text: registered if it is not shown yet, re-texted otherwise. Returns the row to keep.
    private FCk_Handle_ActionHintRow Show_Row(FCk_Handle_ActionHintRow InRow, const FMars_ActionHint_Spec& InSpec)
    {
        if (ck::Is_NOT_Valid(InRow))
        { return _Display.Request_RegisterHint(InSpec); }

        _Display.Request_UpdateHint(FMars_Request_ActionHintDisplay_Update(InRow, InSpec.Text));
        return InRow;
    }

    private FCk_Handle_ActionHintRow Clear_Row(FCk_Handle_ActionHintRow InRow)
    {
        if (ck::IsValid(InRow))
        { _Display.Request_UnregisterHint(FMars_Request_ActionHintDisplay_Unregister(InRow)); }

        return FCk_Handle_ActionHintRow();
    }
}
