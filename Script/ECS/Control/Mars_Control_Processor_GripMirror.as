// Every machine mirrors the grip ledger. A client binds its rep-notify once and reconciles then and on every arrival; the
// authority reconciles when its own drain refuses a claim (it adds FMars_Tag_Control_NeedsGripMirror). Each reconcile
// compares the ledger with the one it last reconciled (seeded by Add from the ledger as it arrived, so a machine that binds
// late raises nothing old) and, for refusals it had not seen: lets this machine's own grip go when it belongs to the
// refused entity - the local grip ends as EndManipulation ends it (reporting LetGo) and its interaction ends Failed, or,
// past the crossing (its Cross already reported), the pending engage clears and the handle settles back at once - then
// raises OnGripRefused once per refusal. A refusal
// naming the entity the ledger now shows gripping is old: that entity was granted since, and its grip stands.
class UMars_Processor_Control_GripMirror : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _MarkedDirtyBy = FMars_Tag_Control_NeedsGripMirror;
    default _RunAfter.Add(n"/Script/Angelscript.Mars_Processor_Control_HandleRequests");

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_Control);
        Query.Require(FMars_Tag_Control_NeedsGripMirror);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle)
    {
        InHandle.Request_TryRemove(FMars_Tag_Control_NeedsGripMirror);
        auto Control = InHandle.As_Control();

        // Only Add tags a client's copy, once.
        if (utils_net::Get_HasAuthority(InHandle) == false)
        { InHandle.BindTo_OnRepNotify(FMars_Fragment_Control_Grip, FCk_DynamicFragment_OnRepNotify(this, n"OnGripLedgerReplicated")); }

        Reconcile(Control);
    }

    UFUNCTION()
    private void OnGripLedgerReplicated(FCk_Handle InHandle, FCk_DynamicFragment_RepNotifyInfo InInfo)
    {
        auto Control = InHandle.As_Control();
        Reconcile(Control);
    }

    // Last is written before any broadcast: a handler may compose on another entity and move the fragment storage.
    private void Reconcile(FCk_Handle_Control& InControl)
    {
        const auto Ledger = InControl.Get_Fragment(FMars_Fragment_Control_Grip);
        auto& Mirror = InControl.Get_Fragment(FMars_Fragment_Control_GripMirror);
        const auto Last = Mirror.Last;
        Mirror.Last = Ledger;

        if (Ledger.RefusalSerial <= Last.RefusalSerial)
        { return; }

        const auto Refused = Ledger.LastRefused;
        if (ck::IsValid(Refused) && utils_control::Get_GrippedBy(Ledger) != Refused)
        { LetGo(InControl, Refused); }

        if (InControl.Has_Fragment(FMars_Fragment_Control_Signals) == false)
        { return; }

        for (int32 Refusal = Last.RefusalSerial; Refusal < Ledger.RefusalSerial; ++Refusal)
        { InControl.Get_Fragment(FMars_Fragment_Control_Signals).OnGripRefused.Broadcast(InControl, Refused); }
    }

    // This machine's grip, or its pending engage, when it belongs to InRefused; nothing otherwise.
    private void LetGo(FCk_Handle_Control& InControl, FCk_Handle InRefused)
    {
        auto& Local = InControl.Get_Fragment(FMars_Fragment_Control_Local);
        auto Mover = Local.Mover;

        if (Local.Manipulation.IsSet() && Local.Manipulation.GetValue().Gripper == InRefused)
        {
            auto Interaction = Local.Manipulation.GetValue().Interaction;
            Local.Manipulation.Reset();
            InControl.Request_TryRemove(FMars_Tag_Control_Manipulating);

            if (ck::IsValid(Mover))
            { Mover.Request_Settle(FMars_Request_Mover_Settle()); }

            if (ck::IsValid(Interaction))
            { utils_interaction::Request_EndInteraction(Interaction, FCk_Request_Interaction_EndInteraction(ECk_SucceededFailed::Failed)); }

            utils_control::Request_GripFor(InControl, InRefused, EMars_Control_GripVerb::LetGo);

            if (InControl.Has_Fragment(FMars_Fragment_Control_Signals))
            { InControl.Get_Fragment(FMars_Fragment_Control_Signals).OnManipulationChanged.Broadcast(InControl, EMars_Control_Grip::Released); }

            if (InControl.Has_Fragment(FMars_Fragment_Control_Signals))
            { InControl.Get_Fragment(FMars_Fragment_Control_Signals).OnManipulationProgress.Broadcast(InControl, 0.0f); }

            return;
        }

        if (Local.PendingEngage.IsSet() && Local.PendingEngage.GetValue().Gripper == InRefused)
        {
            auto Timer = Local.PendingEngage.GetValue().Timer;
            Local.PendingEngage.Reset();
            if (ck::IsValid(Timer))
            { utils_entity_lifetime::Request_DestroyEntity(Timer); }

            if (ck::IsValid(Mover))
            { Mover.Request_Settle(FMars_Request_Mover_Settle()); }
        }
    }
}
