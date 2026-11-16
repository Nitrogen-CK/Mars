// Every machine mirrors the grip ledger. The authority reconciles its own drain's changes as they arrive (each grant,
// release and refusal adds FMars_Tag_Control_NeedsGripMirror). A client binds its rep-notify once, and its first pass
// shows the ledger this machine composed. The ledger's first application is the state the copy was born into, taken
// once as it stands: another machine's standing grip is shown and claimed with its handle where the Pull stands,
// OnGripHolderChanged is raised once, and no refusal the ledger already counts is raised. Each later change is
// reconciled as it arrives, a changed Pull included: the reconcile compares the ledger with the one it last reconciled
// and, for refusals it had not seen, lets this machine's own grip go when it belongs to the refused entity - the local
// grip ends as EndManipulation ends it (reporting LetGo) and its interaction ends Failed, or, past the crossing (its
// Cross already reported), the pending engage clears and the handle settles back at once - then raises OnGripRefused
// once per refusal. A refusal naming the entity the ledger now shows gripping is old: that entity was granted since,
// and its grip stands. Each reconcile also follows who holds the grant (Follow_Holder): another machine's grip is shown
// and claimed here, this machine's own never is, whether or not the control has a Mover; when the holder it reads
// changed it raises OnGripHolderChanged once, before any refusal.
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

        // The authority mirrors its own drain's changes, each as it arrives. A client's copy binds once (only Add tags
        // it) and shows the ledger this machine composed, as it stands.
        const auto HasAuthority = utils_net::Get_HasAuthority(InHandle);
        if (HasAuthority)
        {
            Reconcile(Control, EMars_Net_Reconcile::AsItArrives);
            return;
        }

        InHandle.BindTo_OnRepNotify(FMars_Fragment_Control_Grip, FCk_DynamicFragment_OnRepNotify(this, n"OnGripLedgerReplicated"));
        Reconcile(Control, EMars_Net_Reconcile::AsItStands);
    }

    // An expected absence, not a defect: a notify can land on a control already ending.
    UFUNCTION()
    private void OnGripLedgerReplicated(FCk_Handle InHandle, FCk_DynamicFragment_RepNotifyInfo InInfo)
    {
        if (ck::Is_NOT_Valid(InHandle) || utils_entity_lifetime::Get_IsPendingDestroy(InHandle, ECk_EntityLifetime_DestructionPhase::BeginDestroy)
            || InHandle.Is_Control() == false)
        { return; }

        auto Control = InHandle.As_Control();
        if (Control.Get_Fragment(FMars_Fragment_Control_GripMirror).InitialState == EMars_Net_InitialState::Awaited)
        {
            Control.Get_Fragment(FMars_Fragment_Control_GripMirror).InitialState = EMars_Net_InitialState::Taken;
            Reconcile(Control, EMars_Net_Reconcile::AsItStands);
            return;
        }

        Reconcile(Control, EMars_Net_Reconcile::AsItArrives);
    }

    // Last is written before any broadcast: a handler may compose on another entity and move the fragment storage.
    private void Reconcile(FCk_Handle_Control& InControl, EMars_Net_Reconcile InHow)
    {
        const auto Ledger = InControl.Get_Fragment(FMars_Fragment_Control_Grip);
        auto& Mirror = InControl.Get_Fragment(FMars_Fragment_Control_GripMirror);
        auto Last = Mirror.Last;
        Mirror.Last = Ledger;

        // As it stands, every claim the ledger counts as refused came before this copy took its state: none can be this
        // machine's, and none is raised.
        if (InHow == EMars_Net_Reconcile::AsItStands)
        { Last.RefusalSerial = Ledger.RefusalSerial; }

        const auto HasNewRefusals = Ledger.RefusalSerial > Last.RefusalSerial;
        const auto Refused = Ledger.LastRefused;
        if (HasNewRefusals && ck::IsValid(Refused) && utils_control::Get_GrippedBy(Ledger) != Refused)
        { LetGo(InControl, Refused); }

        // After a refused grip let go, so the refused machine shows and claims the grip like any other.
        const auto PreviousHolder = InControl.Get_Fragment(FMars_Fragment_Control_Local).GripHolder;
        Follow_Holder(InControl, Ledger, Last);

        // As it stands another machine's grip is shown where its pull stands; as it arrives the shown handle springs
        // there from where a grip starts.
        if (InHow == EMars_Net_Reconcile::AsItStands && InControl.Get_GripHolder() == EMars_Control_GripHolder::AnotherMachine)
        { InControl.Get_Fragment(FMars_Fragment_Control_Local).MirroredGrip = FMars_Control_Spring(Ledger.Pull, 0.0f); }

        const auto Holder = InControl.Get_Fragment(FMars_Fragment_Control_Local).GripHolder;
        const auto HasNewHolder = Holder != PreviousHolder;
        if (HasNewHolder == false && HasNewRefusals == false)
        { return; }

        // Handlers dress the assembly and start its ticks: scope the script world to the control's.
        const auto WorldContext = FAngelscriptGameThreadScopeWorldContext(utils_entity_lifetime::Get_WorldForEntity(InControl));

        if (HasNewHolder && InControl.Has_Fragment(FMars_Fragment_Control_Signals))
        { InControl.Get_Fragment(FMars_Fragment_Control_Signals).OnGripHolderChanged.Broadcast(InControl, PreviousHolder, Holder); }

        if (HasNewRefusals == false)
        { return; }

        for (int32 Refusal = Last.RefusalSerial; Refusal < Ledger.RefusalSerial; ++Refusal)
        {
            if (InControl.Has_Fragment(FMars_Fragment_Control_Signals))
            { InControl.Get_Fragment(FMars_Fragment_Control_Signals).OnGripRefused.Broadcast(InControl, Refused); }
        }
    }

    // Who holds the grant now, against who held it at the last reconcile. Another machine's grip takes the Operated claim
    // and is shown (UMars_Processor_Control_MirroredGrip, from where a grip starts: the Mover's alpha, or without a Mover
    // the end the pull runs from; a new grant while one is shown carries on from where it is). When it ends the claim
    // goes, and a Mover settles back after a let-go or a lost gripper; after a crossing a returns-to-rest Mover settles and
    // any other is left where it is for the engage's MoveTo. A control without a Mover is shown and cleared the same way.
    private void Follow_Holder(FCk_Handle_Control& InControl, const FMars_Fragment_Control_Grip& InLedger, const FMars_Fragment_Control_Grip& InLast)
    {
        auto& Local = InControl.Get_Fragment(FMars_Fragment_Control_Local);
        const auto Previous = Local.GripHolder;
        const auto Holder = utils_control::Get_GripHolder(InLedger, Local.LastLocalGripper);
        Local.GripHolder = Holder;

        auto Interactable = Local.Interactable;
        auto Mover = Local.Mover;

        if (Holder == EMars_Control_GripHolder::AnotherMachine)
        {
            if (Previous != EMars_Control_GripHolder::AnotherMachine && ck::IsValid(Interactable))
            { Interactable.Request_Disable(FMars_Request_Interactable_Disable(EMars_Interactable_DisableReason::Operated)); }

            const auto IsNewGrant = Previous != EMars_Control_GripHolder::AnotherMachine || InLedger.GripSerial != InLast.GripSerial;
            if (IsNewGrant == false)
            { return; }

            if (Local.MirroredGrip.IsSet() == false)
            { Local.MirroredGrip = FMars_Control_Spring(InControl.Get_GripStartAlpha(), 0.0f); }

            if (InControl.Has_Fragment(FMars_Tag_Control_MirroringGrip) == false)
            { InControl.Add_Fragment(FMars_Tag_Control_MirroringGrip()); }

            return;
        }

        if (Previous != EMars_Control_GripHolder::AnotherMachine)
        { return; }

        if (ck::IsValid(Interactable))
        { Interactable.Request_Enable(FMars_Request_Interactable_Enable(EMars_Interactable_DisableReason::Operated)); }

        Local.MirroredGrip.Reset();
        InControl.Request_TryRemove(FMars_Tag_Control_MirroringGrip);

        if (Holder != EMars_Control_GripHolder::Nobody || ck::Is_NOT_Valid(Mover))
        { return; }

        const auto LeftForTheEngage = InLedger.LastRelease == EMars_Control_GripRelease::Crossed && InControl.Get_ReturnsToRest() == false;
        if (LeftForTheEngage)
        { return; }

        Mover.Request_Settle(FMars_Request_Mover_Settle());
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
