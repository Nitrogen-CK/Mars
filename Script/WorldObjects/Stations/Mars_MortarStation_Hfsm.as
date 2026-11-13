// The mortar station's control layer: its own state machine (FMars_Station_Spec.MinigameStateClass =
// UMars_SmState_Mortar_Idle). It runs on the STATION entity (context = the station, which also carries the Mortar feature)
// and reads the station's operator; it only issues Mortar requests and registers the operator's legend rows. It owns no
// clock: the timing window, the strike and the grind are the kernel's.
//
//   Idle      ->Operated [StationIsOperated]
//   Operated  ->Idle     [StationIsNotOperated]   tasks: Mortar_Engage, Mortar_OperatorInput (Tick), Mortar_OperatorPestle
//                                                 (Tick), Mortar_OperatorHints
//
// Stance: the input task reads the operator on the authority alone (the station's InputStance), so a remote operator's
// collect and switch arrive in its input stream there. A remote operator's pestle is sent by its own machine as
// Cue.Mars.Mortar.Pestle with the sweep that machine shows (Mortar_OperatorPestle), so the strike is judged on what it saw.
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
        AddTask(InHandle, UMars_SmTask_Mortar_OperatorPestle);
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
// Grind phase) and coming up releases it (a release and a press between two polls send both, the release first: the
// kernel applies them in the order issued), one collect per press of Interact_Secondary and one switch of seasoning per
// press of Drop (R: the hands are empty at a station, so nothing else reads it here). The pestle is read only for this
// machine's own player (its InputIntents has a matcher): a remote operator's presses also arrive in its stream, but its
// pestle arrives as Cue.Mars.Mortar.Pestle with the sweep it saw (UMars_SmTask_Mortar_OperatorPestle).
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
        const auto IsOwnPlayer = ck::IsValid(_Intents.Get_Matcher());
        if (utils_input_intents::Get_HasRelease(Primary) && IsOwnPlayer)
        { _Mortar.Request_Pestle(FMars_Request_Mortar_Pestle(EMars_Mortar_PestleVerb::Release)); }

        if (utils_input_intents::Get_HasPress(Primary) && IsOwnPlayer)
        { _Mortar.Request_Pestle(FMars_Request_Mortar_Pestle(EMars_Mortar_PestleVerb::Press)); }

        if (utils_input_intents::Get_HasPress(_Collect.Advance(_Intents, GameplayTags::Mars_Intent_Interact_Secondary)))
        { _Mortar.Request_Collect(FMars_Request_Mortar_Collect()); }

        if (utils_input_intents::Get_HasPress(_Switch.Advance(_Intents, GameplayTags::Mars_Intent_Drop)))
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

// The operating machine's pestle, where the authority alone reads the operator: on a machine without authority over the
// station whose own player operates it (its InputIntents has a matcher), each frame's Interact_Primary edges go through
// utils_mortar::Request_PestleFor, a release before a press, the press carrying the sweep this machine shows, each act
// with the next of its own count (reset on enter). It seeds the edge once the matcher is there, predicts nothing, and
// sends nothing on exit. The authority and every other machine do nothing here.
class UMars_SmTask_Mortar_OperatorPestle : UCk_SmTask_EntityScript
{
    default _TaskMode = ECk_SmTaskMode::Tick;

    private FCk_Handle_Mortar _Mortar;
    private FCk_Handle _Operator;
    private FCk_Handle_InputIntents _Intents;
    private EMars_Mortar_PestleSeed _Seed = EMars_Mortar_PestleSeed::Unseeded;
    private FMars_IntentEdge _Primary;
    private int32 _Sequence = 0;

    UFUNCTION(BlueprintOverride)
    void DoEnterTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        Reset();

        auto Station = ck::Ctx(InHandle);
        if (utils_net::Get_HasAuthority(Station))
        { return; }

        auto Mortar = Station.As_Mortar(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(Mortar))
        { return; }

        _Operator = Station.As_Station().Get_Operator();
        _Intents = _Operator.As_InputIntents(ECk_SanityCheck::UnChecked);
        if (ck::IsValid(_Intents))
        { _Mortar = Mortar; }
    }

    // Must return Running every frame: a Succeeded/Failed result would end the task while Operated is still active.
    UFUNCTION(BlueprintOverride)
    ECk_SmTaskResult DoTick(FCk_Handle_SmTask InHandle, FCk_Time InDeltaT, ECk_Sm_NetContext InNetContext)
    {
        if (ck::Is_NOT_Valid(_Mortar) || ck::Is_NOT_Valid(_Intents) || ck::Is_NOT_Valid(_Intents.Get_Matcher()))
        { return ECk_SmTaskResult::Running; }

        if (_Seed == EMars_Mortar_PestleSeed::Unseeded)
        {
            _Primary.Seed(_Intents, GameplayTags::Mars_Intent_Interact_Primary);
            _Seed = EMars_Mortar_PestleSeed::Seeded;
            return ECk_SmTaskResult::Running;
        }

        const auto Primary = _Primary.Advance(_Intents, GameplayTags::Mars_Intent_Interact_Primary);
        if (utils_input_intents::Get_HasRelease(Primary))
        {
            ++_Sequence;
            utils_mortar::Request_PestleFor(_Mortar, FMars_Mortar_PestleAct(_Operator, EMars_Mortar_PestleVerb::Release, 0.0f, _Sequence));
        }

        if (utils_input_intents::Get_HasPress(Primary))
        {
            ++_Sequence;
            utils_mortar::Request_PestleFor(_Mortar, FMars_Mortar_PestleAct(_Operator, EMars_Mortar_PestleVerb::Press, _Mortar.Get_SweepSeconds(), _Sequence));
        }

        return ECk_SmTaskResult::Running;
    }

    UFUNCTION(BlueprintOverride)
    void DoExitTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        Reset();
    }

    private void Reset()
    {
        _Mortar = FCk_Handle_Mortar();
        _Operator = FCk_Handle();
        _Intents = FCk_Handle_InputIntents();
        _Seed = EMars_Mortar_PestleSeed::Unseeded;
        _Primary = FMars_IntentEdge();
        _Sequence = 0;
    }
}

// Whether the operating machine's pestle task has seeded its edge from the operator's intents.
enum EMars_Mortar_PestleSeed
{
    Unseeded,
    Seeded
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
