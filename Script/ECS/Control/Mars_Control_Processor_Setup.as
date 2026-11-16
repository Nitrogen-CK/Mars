// One-shot per control. On the authority: a control that also has a MechanismSource asserts it while active. A client
// binds the ledger's rep-notify and its first pass shows the ledger this machine composed. The ledger's first
// application is the state the copy was born into, taken once as it stands: the handle is put at its pose at once
// unless another machine's grip is shown on it, OnActiveChanged announces a standing activation, and no engagement the
// ledger already counts is raised. Each later change is reconciled as it arrives: it moves the handle and broadcasts
// OnEngaged once per replicated engagement, then OnActiveChanged, the authority's order. The reconcile also clears the
// pending engage this client's own pull set (UMars_Processor_Control_Tick) once the ledger counts that engagement, so
// the next grip reads the new direction. The handle it moves as a change leaves any mirrored grip
// (UMars_Processor_Control_MirroredGrip).
class UMars_Processor_Control_Setup : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _MarkedDirtyBy = FMars_Tag_Control_NeedsSetup;

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_Control);
        Query.Require(FMars_Tag_Control_NeedsSetup);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle)
    {
        auto Control = InHandle.As_Control();

        if (utils_net::Get_HasAuthority(InHandle) == false)
        {
            InHandle.BindTo_OnRepNotify(FMars_Fragment_Control, FCk_DynamicFragment_OnRepNotify(this, n"OnLedgerReplicated"));
            Reconcile(Control, EMars_Net_Reconcile::AsItStands);
            Control.Request_TryRemove(FMars_Tag_Control_NeedsSetup);
            return;
        }

        Control.Request_TryRemove(FMars_Fragment_Control_Mirror);

        auto Source = InHandle.As_MechanismSource(ECk_SanityCheck::UnChecked);
        if (ck::IsValid(Source))
        {
            Control.BindTo_OnActiveChanged(FMars_Delegate_Control_OnActiveChanged(this, n"OnActiveChanged"));
            Source.Request_SetOutput(utils_mechanism_source::Make_SetOutput(Get_SourceOutput(Control.Get_Activation())));
        }

        // A momentary control that starts active still has to release; activating it arms the release timer.
        if (Control.Get_IsActive() && Control.Get_Fragment(FMars_Fragment_Control_Params).Behavior == EMars_Control_Behavior::Momentary)
        { Control.Request_SetActive(FMars_Request_Control_SetActive(EMars_Control_Activation::Active)); }

        Control.Request_TryRemove(FMars_Tag_Control_NeedsSetup);
    }

    // An expected absence, not a defect: a notify can land on a control already ending.
    UFUNCTION()
    private void OnLedgerReplicated(FCk_Handle InHandle, FCk_DynamicFragment_RepNotifyInfo InInfo)
    {
        if (ck::Is_NOT_Valid(InHandle) || utils_entity_lifetime::Get_IsPendingDestroy(InHandle, ECk_EntityLifetime_DestructionPhase::BeginDestroy)
            || InHandle.Is_Control() == false)
        { return; }

        auto Control = InHandle.As_Control();
        if (Control.Get_Fragment(FMars_Fragment_Control_Mirror).InitialState == EMars_Net_InitialState::Awaited)
        {
            Control.Get_Fragment(FMars_Fragment_Control_Mirror).InitialState = EMars_Net_InitialState::Taken;
            Reconcile(Control, EMars_Net_Reconcile::AsItStands);
            return;
        }

        Reconcile(Control, EMars_Net_Reconcile::AsItArrives);
    }

    private void Reconcile(FCk_Handle_Control& InControl, EMars_Net_Reconcile InHow)
    {
        const auto Ledger = InControl.Get_Fragment(FMars_Fragment_Control);
        auto& Mirror = InControl.Get_Fragment(FMars_Fragment_Control_Mirror);
        auto Last = Mirror.Last;
        Mirror.Last = Ledger;

        // As it stands, every engagement the ledger counts came before this copy took its state.
        if (InHow == EMars_Net_Reconcile::AsItStands)
        { Last.Engagements = Ledger.Engagements; }

        auto& Local = InControl.Get_Fragment(FMars_Fragment_Control_Local);
        if (Local.PendingEngage.IsSet() && Ledger.Engagements > Local.PendingEngage.GetValue().Engagements)
        {
            auto Timer = Local.PendingEngage.GetValue().Timer;
            if (ck::IsValid(Timer))
            { utils_entity_lifetime::Request_DestroyEntity(Timer); }

            Local.PendingEngage.Reset();
        }

        const auto Changed = Ledger.IsActive != Last.IsActive;

        // A returns-to-rest handle is not a state display, as on the authority. As it stands the handle is put at its
        // pose at once, unless another machine's standing grip is shown on it: the grip keeps the handle, and its end
        // settles it to the pose asked here. As it arrives the MoveTo takes the handle from a mirrored grip, whichever
        // of the two ledgers arrived first: a scrub after it would stop the tween where the grip left it.
        auto Mover = InControl.Get_Mover();
        if (Changed && ck::IsValid(Mover) && InControl.Get_ReturnsToRest() == false)
        {
            if (InHow == EMars_Net_Reconcile::AsItArrives)
            {
                Local.MirroredGrip.Reset();
                InControl.Request_TryRemove(FMars_Tag_Control_MirroringGrip);
            }
            else if (Local.MirroredGrip.IsSet() == false)
            { Mover.Request_Scrub(FMars_Request_Mover_Scrub(Ledger.IsActive ? 1.0f : 0.0f)); }

            Mover.Request_MoveTo(FMars_Request_Mover_MoveTo(Ledger.IsActive ? EMars_Mover_Pose::End : EMars_Mover_Pose::Start));
        }

        if (InControl.Has_Fragment(FMars_Fragment_Control_Signals) == false)
        { return; }

        // Handlers dress the assembly and start its ticks: scope the script world to the control's.
        const auto WorldContext = FAngelscriptGameThreadScopeWorldContext(utils_entity_lifetime::Get_WorldForEntity(InControl));

        for (int32 Engagement = Last.Engagements; Engagement < Ledger.Engagements; ++Engagement)
        { InControl.Get_Fragment(FMars_Fragment_Control_Signals).OnEngaged.Broadcast(InControl); }

        if (Changed)
        {
            const auto Activation = Ledger.IsActive ? EMars_Control_Activation::Active : EMars_Control_Activation::Inactive;
            InControl.Get_Fragment(FMars_Fragment_Control_Signals).OnActiveChanged.Broadcast(InControl, Activation);
        }
    }

    UFUNCTION()
    private void OnActiveChanged(FCk_Handle_Control InControl, EMars_Control_Activation InActivation)
    {
        auto Source = InControl.As_MechanismSource(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(Source))
        { return; }

        Source.Request_SetOutput(utils_mechanism_source::Make_SetOutput(Get_SourceOutput(InActivation)));
    }

    private EMars_MechanismSource_Output Get_SourceOutput(EMars_Control_Activation InActivation) const
    {
        return InActivation == EMars_Control_Activation::Active ? EMars_MechanismSource_Output::Asserted : EMars_MechanismSource_Output::Deasserted;
    }
}
