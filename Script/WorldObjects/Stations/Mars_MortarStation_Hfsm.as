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

// The operator's input: Interact_Primary going down presses the pestle (a strike in the Crush phase, the grind in the
// Grind phase) and coming up releases it (a release and a press between two polls send both: the kernel drains Release
// before Press), one collect per press of Interact_Secondary and one switch of seasoning per press of Drop (R: the hands
// are empty at a station, so nothing else reads it here).
class UMars_SmTask_Mortar_OperatorInput : UMars_SmTask_StationOperatorInput
{
    private FCk_Handle_Mortar _Mortar;
    private FMars_IntentEdge _Primary;
    private FMars_IntentEdge _Collect;
    private FMars_IntentEdge _Switch;

    protected void Bind(FCk_Handle InStation) override
    {
        _Mortar = InStation.As_Mortar(ECk_SanityCheck::UnChecked);
    }

    protected void Seed() override
    {
        _Primary.Seed(_Intents, GameplayTags::Mars_Intent_Interact_Primary);
        _Collect.Seed(_Intents, GameplayTags::Mars_Intent_Interact_Secondary);
        _Switch.Seed(_Intents, GameplayTags::Mars_Intent_Drop);
    }

    protected void Poll() override
    {
        if (ck::Is_NOT_Valid(_Mortar))
        { return; }

        const auto Primary = _Primary.Advance(_Intents, GameplayTags::Mars_Intent_Interact_Primary);
        if (utils_station::Get_HasRelease(Primary))
        { _Mortar.Request_Release(FMars_Request_Mortar_Release()); }

        if (utils_station::Get_HasPress(Primary))
        { _Mortar.Request_Press(FMars_Request_Mortar_Press()); }

        if (utils_station::Get_HasPress(_Collect.Advance(_Intents, GameplayTags::Mars_Intent_Interact_Secondary)))
        { _Mortar.Request_Collect(FMars_Request_Mortar_Collect()); }

        if (utils_station::Get_HasPress(_Switch.Advance(_Intents, GameplayTags::Mars_Intent_Drop)))
        { _Mortar.Request_SwitchSeasoning(FMars_Request_Mortar_SwitchSeasoning()); }
    }

    protected void Unbind() override
    {
        _Mortar = FCk_Handle_Mortar();
        _Primary = FMars_IntentEdge();
        _Collect = FMars_IntentEdge();
        _Switch = FMars_IntentEdge();
    }
}

// The operator's legend rows while operating, re-read on every step of the batch: the pestle's row (IA_Interact_Primary:
// "crush on the green" in the Crush phase, "hold to grind" in the Grind phase, gone once Done), "collect"
// (IA_Interact_Secondary) while the batch is Done, and the other seasoning's name (IA_Drop) while the batch is fresh.
class UMars_SmTask_Mortar_OperatorHints : UMars_SmTask_StationOperatorHints
{
    private const int32 k_PestleSortOrder = 5;
    private const int32 k_CollectSortOrder = 9;
    private const int32 k_SwitchSortOrder = 10;

    private FCk_Handle_Mortar _Mortar;
    private FCk_Handle_ActionHintRow _PestleRow;
    private FCk_Handle_ActionHintRow _CollectRow;
    private FCk_Handle_ActionHintRow _SwitchRow;

    protected FName Get_OwnerKey() const override
    {
        return n"Mortar";
    }

    // No Mortar on the context (a composition that failed and already ensured) = no rows.
    protected void Register_Rows() override
    {
        _Mortar = _Station.As_Mortar(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(_Mortar))
        { return; }

        _Mortar.BindTo_OnBatchChanged(FMars_Delegate_Mortar_OnBatchChanged(this, n"OnBatchChanged"));
        Refresh_Rows(_Mortar.Get_Batch());
    }

    protected void Unregister_Rows() override
    {
        if (ck::IsValid(_Mortar))
        { _Mortar.UnbindFrom_OnBatchChanged(FMars_Delegate_Mortar_OnBatchChanged(this, n"OnBatchChanged")); }

        _Mortar = FCk_Handle_Mortar();
        _PestleRow = FCk_Handle_ActionHintRow();
        _CollectRow = FCk_Handle_ActionHintRow();
        _SwitchRow = FCk_Handle_ActionHintRow();
    }

    UFUNCTION()
    private void OnBatchChanged(FCk_Handle_Mortar InMortar, FMars_Mortar_Batch InBatch)
    {
        Refresh_Rows(InBatch);
    }

    private void Refresh_Rows(const FMars_Mortar_Batch& InBatch)
    {
        if (InBatch.Phase == EMars_Mortar_Phase::Done)
        { _PestleRow = Clear_Row(_PestleRow); }
        else
        {
            const FString PestleText = InBatch.Phase == EMars_Mortar_Phase::Crush ? "crush on the green" : "hold to grind";
            _PestleRow = Show_Row(_PestleRow, Make_Row(mars::Mars_IA_Interact_Primary, PestleText, k_PestleSortOrder));
        }

        if (InBatch.Phase == EMars_Mortar_Phase::Done)
        { _CollectRow = Show_Row(_CollectRow, Make_Row(mars::Mars_IA_Interact_Secondary, "collect", k_CollectSortOrder)); }
        else
        { _CollectRow = Clear_Row(_CollectRow); }

        if (utils_mortar::Get_IsFresh(InBatch))
        {
            const FString SwitchText = InBatch.Seasoning == EMars_Mortar_Seasoning::Salt ? "switch to pepper" : "switch to salt";
            _SwitchRow = Show_Row(_SwitchRow, Make_Row(mars::Mars_IA_Drop, SwitchText, k_SwitchSortOrder));
        }
        else
        { _SwitchRow = Clear_Row(_SwitchRow); }
    }
}
