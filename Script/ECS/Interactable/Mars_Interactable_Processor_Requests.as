// Drains focus changes in arrival order, then claim changes in arrival order, then completion consumes, then failure reports
// (each broadcast as OnInteractionFailed). Each focus change is applied and broadcast before the next one, so a listener
// reads the state its event describes. A Focus from the current focuser, and an Unfocus from anyone but the current
// focuser, change nothing and broadcast nothing.
//
// Claim changes apply as one batch: when they leave the set of disable reasons different, every target's framework flag is
// set from it (a disabled target refuses CanInteractWith, and Set_Enabled cancels its interactions), and
// OnEnableDisableChanged broadcasts only when the set went from empty to held or back; OnFocusableChanged broadcasts only
// when the set went from holding no focus-removing reason to holding one or back. A reason claimed and released in one
// drain changes nothing.
class UMars_Processor_Interactable_HandleRequests : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _MarkedDirtyBy = FMars_Fragment_Interactable_Requests;

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_Interactable);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle,
                       FMars_Fragment_Interactable_Requests& InRequests,
                       FMars_Fragment_Interactable& InState)
    {
        auto Self = InHandle.As_Interactable();

        TArray<FMars_Interactable_FocusChangeRequest> FocusChangeRequests = InRequests.FocusChangeRequests;
        TArray<FMars_Interactable_ClaimChangeRequest> ClaimChangeRequests = InRequests.ClaimChangeRequests;
        TArray<FMars_Request_Interactable_ConsumeCompletion> ConsumeCompletionRequests = InRequests.ConsumeCompletionRequests;
        TArray<FMars_Request_Interactable_ReportFailure> ReportFailureRequests = InRequests.ReportFailureRequests;

        // InRequests is invalid past this line; removing before broadcasting lets re-entrant requests survive.
        Self.Request_TryRemove(FMars_Fragment_Interactable_Requests);

        for (const auto& Request : FocusChangeRequests)
        {
            if (Request.Change == EMars_Interactable_FocusChange::Focus)
            { ApplyFocus(Self, InState, Request.Focuser); }
            else
            { ApplyUnfocus(Self, InState, Request.Focuser); }
        }

        if (ClaimChangeRequests.Num() > 0)
        { ApplyClaimChanges(Self, InState, ClaimChangeRequests); }

        for (const auto& Request : ConsumeCompletionRequests)
        {
            if (InState.Completion.IsSet() && InState.Completion.GetValue().Serial == Request.Serial)
            { InState.Completion.Reset(); }
        }

        if (Self.Has_Fragment(FMars_Fragment_Interactable_Signals) == false)
        { return; }

        for (const auto& Request : ReportFailureRequests)
        {
            Self.Get_Fragment(FMars_Fragment_Interactable_Signals).OnInteractionFailed.Broadcast(Self,
                FMars_Interactable_Failure(Request.Target, Request.Initiator, Request.Reason));
        }
    }

    private void ApplyFocus(FCk_Handle_Interactable& InSelf, FMars_Fragment_Interactable& InState, const FCk_Handle& InFocuser)
    {
        if (InState.Focuser == InFocuser)
        { return; }

        InState.Focuser = InFocuser;
        if (InSelf.Has_Fragment(FMars_Fragment_Interactable_Signals))
        { InSelf.Get_Fragment(FMars_Fragment_Interactable_Signals).OnFocused.Broadcast(InSelf, InFocuser); }
    }

    private void ApplyUnfocus(FCk_Handle_Interactable& InSelf, FMars_Fragment_Interactable& InState, const FCk_Handle& InUnfocuser)
    {
        // Compared by identity, not validity: a focuser destroyed while focusing still unfocuses itself.
        const auto IsFocused = InState.Focuser != FCk_Handle();
        if (IsFocused == false || InState.Focuser != InUnfocuser)
        { return; }

        InState.Focuser = FCk_Handle();
        if (InSelf.Has_Fragment(FMars_Fragment_Interactable_Signals))
        { InSelf.Get_Fragment(FMars_Fragment_Interactable_Signals).OnUnfocused.Broadcast(InSelf, InUnfocuser); }
    }

    private void ApplyClaimChanges(FCk_Handle_Interactable& InSelf, FMars_Fragment_Interactable& InState,
                                   const TArray<FMars_Interactable_ClaimChangeRequest>& InRequests)
    {
        const TArray<EMars_Interactable_DisableReason> Before = InState.DisableReasons;
        for (const auto& Request : InRequests)
        {
            if (Request.Change == EMars_Interactable_ClaimChange::Disable)
            { InState.DisableReasons.AddUnique(Request.Reason); }
            else if (InState.DisableReasons.Contains(Request.Reason))
            { InState.DisableReasons.Remove(Request.Reason); }
        }

        if (DoGet_IsSameSet(Before, InState.DisableReasons))
        { return; }

        const auto WasEnabled = Before.Num() == 0;
        const auto IsEnabled = InState.DisableReasons.Num() == 0;
        const auto EnableDisable = IsEnabled ? ECk_EnableDisable::Enable : ECk_EnableDisable::Disable;
        for (auto Target : InSelf.Get_AllInteractTargets())
        { utils_interact_target::Set_Enabled(Target, EnableDisable); }

        if (InSelf.Has_Fragment(FMars_Fragment_Interactable_Signals) == false)
        { return; }

        if (IsEnabled != WasEnabled)
        { InSelf.Get_Fragment(FMars_Fragment_Interactable_Signals).OnEnableDisableChanged.Broadcast(InSelf, EnableDisable); }

        const auto WasFocusable = DoGet_IsFocusable(Before);
        const auto IsFocusable = DoGet_IsFocusable(InState.DisableReasons);
        if (IsFocusable != WasFocusable)
        {
            const auto Focusable = IsFocusable ? ECk_EnableDisable::Enable : ECk_EnableDisable::Disable;
            InSelf.Get_Fragment(FMars_Fragment_Interactable_Signals).OnFocusableChanged.Broadcast(InSelf, Focusable);
        }
    }

    // Both hold each reason at most once.
    private bool DoGet_IsSameSet(const TArray<EMars_Interactable_DisableReason>& InA,
                                 const TArray<EMars_Interactable_DisableReason>& InB) const
    {
        if (InA.Num() != InB.Num())
        { return false; }

        for (const auto Reason : InA)
        {
            if (InB.Contains(Reason) == false)
            { return false; }
        }

        return true;
    }

    private bool DoGet_IsFocusable(const TArray<EMars_Interactable_DisableReason>& InReasons) const
    {
        for (const auto Reason : InReasons)
        {
            if (utils_interactable::Get_ClaimRemovesFocus(Reason))
            { return false; }
        }

        return true;
    }
}
