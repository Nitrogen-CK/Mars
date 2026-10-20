// The shared shapes of every station's control tasks: the operator-input reader (UMars_SmTask_StationOperatorInput) and the
// operator's legend rows (UMars_SmTask_StationOperatorHints). They run on the STATION entity (context = the station) and read
// the station's operator; a station's own task subclasses one and overrides its hooks only.

// What one intent row did between two polls of a station's input task.
enum EMars_IntentEdge
{
    None,
    Pressed,
    Released,
    // A release and a fresh press between two polls (a new activation frame while one was already seen).
    ReleasedAndPressed
}

// One intent row's edges, polled: the activation frame of the hold last seen (unset while it is not held).
struct FMars_IntentEdge
{
    TOptional<int32> Seen;
}

// One look-delta reader: the look sequence last seen.
struct FMars_LookCursor
{
    int32 Seen = 0;
}

namespace utils_station
{
    // InEdge carries a press (alone, or after a release between two polls).
    bool Get_HasPress(EMars_IntentEdge InEdge)
    {
        return InEdge == EMars_IntentEdge::Pressed || InEdge == EMars_IntentEdge::ReleasedAndPressed;
    }

    // InEdge carries a release (alone, or before a press between two polls).
    bool Get_HasRelease(EMars_IntentEdge InEdge)
    {
        return InEdge == EMars_IntentEdge::Released || InEdge == EMars_IntentEdge::ReleasedAndPressed;
    }
}

// The edge from the frame last seen to InFrame, which becomes the frame seen.
mixin EMars_IntentEdge Advance_To(FMars_IntentEdge& Self, TOptional<int32> InFrame)
{
    if (InFrame == Self.Seen)
    { return EMars_IntentEdge::None; }

    const auto WasHeld = Self.Seen.IsSet();
    Self.Seen = InFrame;
    if (InFrame.IsSet() == false)
    { return EMars_IntentEdge::Released; }

    return WasHeld ? EMars_IntentEdge::ReleasedAndPressed : EMars_IntentEdge::Pressed;
}

mixin EMars_IntentEdge Advance(FMars_IntentEdge& Self, const FCk_Handle_InputIntents& InIntents, FGameplayTag InIntent)
{
    return Self.Advance_To(InIntents.TryGet_IntentActivationFrame(InIntent));
}

// A hold already going counts as seen, so only a fresh press is an edge.
mixin void Seed(FMars_IntentEdge& Self, const FCk_Handle_InputIntents& InIntents, FGameplayTag InIntent)
{
    Self.Seen = InIntents.TryGet_IntentActivationFrame(InIntent);
}

// True once per drained look delta (InIntents.Get_LookDelta() is that delta).
mixin bool Advance(FMars_LookCursor& Self, const FCk_Handle_InputIntents& InIntents)
{
    const auto Sequence = InIntents.Get_LookDeltaSequence();
    if (Sequence == Self.Seen)
    { return false; }

    Self.Seen = Sequence;
    return true;
}

// A delta drained before the seed never counts.
mixin void Seed(FMars_LookCursor& Self, const FCk_Handle_InputIntents& InIntents)
{
    Self.Seen = InIntents.Get_LookDeltaSequence();
}

// A station's operator-input reader: resolves the station and its operator's InputIntents on enter, lets the subclass cache
// its kernel (Bind) and seed its edges (Seed), and polls (Poll) every frame the intents exist. Seeding on enter means a
// hold or a look from before the station was taken never counts. No operator intents (headless) = no Seed and no Poll;
// Bind and Unbind run either way, so a subclass's exit request (a cancel, a lift) still goes out.
UCLASS(Abstract)
class UMars_SmTask_StationOperatorInput : UCk_SmTask_EntityScript
{
    default _TaskMode = ECk_SmTaskMode::Tick;

    protected FCk_Handle _Station;
    protected FCk_Handle_InputIntents _Intents;

    UFUNCTION(BlueprintOverride)
    void DoEnterTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        _Station = ck::Ctx(InHandle);
        Bind(_Station);

        auto Operator = _Station.As_Station().Get_Operator();
        _Intents = Operator.As_InputIntents(ECk_SanityCheck::UnChecked);
        if (ck::IsValid(_Intents))
        { Seed(); }
    }

    // Must return Running every frame: a Succeeded/Failed result would end the task while Operated is still active.
    UFUNCTION(BlueprintOverride)
    ECk_SmTaskResult DoTick(FCk_Handle_SmTask InHandle, FCk_Time InDeltaT, ECk_Sm_NetContext InNetContext)
    {
        if (ck::IsValid(_Intents))
        { Poll(); }

        return ECk_SmTaskResult::Running;
    }

    UFUNCTION(BlueprintOverride)
    void DoExitTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        Unbind();
        _Station = FCk_Handle();
        _Intents = FCk_Handle_InputIntents();
    }

    // Cache the kernel handles the task drives (InStation is the context).
    protected void Bind(FCk_Handle InStation)
    {
    }

    // Seed every edge and look cursor from _Intents.
    protected void Seed()
    {
    }

    // One frame of input; _Intents is valid.
    protected void Poll()
    {
    }

    // Send any exit request, then drop the cached handles.
    protected void Unbind()
    {
    }
}

// A station's legend rows while operating, under its own owner key: resolves the operator's ActionHintDisplay on enter
// (none, headless = no rows and no Register_Rows), unregisters every row under the key on exit. Rows are registered once and
// re-texted on edges (the display drains registers before unregisters, so a row is never re-registered).
UCLASS(Abstract)
class UMars_SmTask_StationOperatorHints : UCk_SmTask_EntityScript
{
    default _TaskMode = ECk_SmTaskMode::EnterExitOnly;

    protected FCk_Handle _Station;
    protected FCk_Handle_ActionHintDisplay _Display;

    UFUNCTION(BlueprintOverride)
    void DoEnterTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        _Station = ck::Ctx(InHandle);
        if (ck::EnsureIfNot(Get_OwnerKey() != NAME_None, f"[Station] [{_Station.ToString()}] a hint task [{GetName()}] has no owner key: it registers no rows"))
        { return; }

        auto Operator = _Station.As_Station().Get_Operator();
        _Display = Operator.As_ActionHintDisplay(ECk_SanityCheck::UnChecked);
        if (ck::IsValid(_Display))
        { Register_Rows(); }
    }

    UFUNCTION(BlueprintOverride)
    void DoExitTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        Unregister_Rows();
        if (ck::IsValid(_Display))
        { _Display.Request_UnregisterHintsByOwner(FMars_Request_ActionHintDisplay_UnregisterByOwner(Get_OwnerKey())); }

        _Station = FCk_Handle();
        _Display = FCk_Handle_ActionHintDisplay();
    }

    // Every row this task registers carries it; the exit clears them all by it. Unique per task.
    protected FName Get_OwnerKey() const
    {
        return NAME_None;
    }

    // Register the rows and bind the signals that re-text them; _Display is valid.
    protected void Register_Rows()
    {
    }

    // Unbind the signals Register_Rows bound and drop the cached handles (the rows go with the owner key).
    protected void Unregister_Rows()
    {
    }

    protected FMars_ActionHint_Spec Make_Row(UInputAction InInputAction, const FString& InText, int32 InSortOrder) const
    {
        return FMars_ActionHint_Spec(InInputAction, FText::FromString(InText), InSortOrder, Get_OwnerKey());
    }

    // InRow reading InSpec's text: registered if it is not shown yet, re-texted otherwise. Returns the row to keep.
    protected FCk_Handle_ActionHintRow Show_Row(FCk_Handle_ActionHintRow InRow, const FMars_ActionHint_Spec& InSpec)
    {
        if (ck::Is_NOT_Valid(InRow))
        { return _Display.Request_RegisterHint(InSpec); }

        _Display.Request_UpdateHint(FMars_Request_ActionHintDisplay_Update(InRow, InSpec.Text));
        return InRow;
    }

    // InRow unregistered if it is shown. Returns the (invalid) row to keep.
    protected FCk_Handle_ActionHintRow Clear_Row(FCk_Handle_ActionHintRow InRow)
    {
        if (ck::IsValid(InRow))
        { _Display.Request_UnregisterHint(FMars_Request_ActionHintDisplay_Unregister(InRow)); }

        return FCk_Handle_ActionHintRow();
    }

    // InRow re-texted; nothing without a display or a row.
    protected void Retext_Row(FCk_Handle_ActionHintRow InRow, const FString& InText)
    {
        if (ck::Is_NOT_Valid(_Display) || ck::Is_NOT_Valid(InRow))
        { return; }

        _Display.Request_UpdateHint(FMars_Request_ActionHintDisplay_Update(InRow, FText::FromString(InText)));
    }
}
