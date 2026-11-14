// Once per Maw: the authority drops the mirror state (its drain and its tick publish the ledger). A machine without
// authority binds the ledger's rep-notify and reconciles once as it stands, which shows what this machine composed.
// The ledger's first application is the state the copy was born into and is taken once as it stands: the Maw where it
// is, a running action from its phase's start, no past flinch. Each later change is reconciled as it arrives, and the
// tick then plays the rise, the sink, the jaw's ease and the action's phase on this machine's clock.
// A reconcile raises OnActionPhase once per arrived action change (OnStance is the tick's); a phase that never arrived
// because two of the authority's writes reached this machine as one is not replayed.
class UMars_Processor_RootMaw_Mirror : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _MarkedDirtyBy = FMars_Tag_RootMaw_NeedsMirror;

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_RootMaw);
        Query.Require(FMars_Tag_RootMaw_NeedsMirror);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle)
    {
        InHandle.Request_TryRemove(FMars_Tag_RootMaw_NeedsMirror);
        auto Maw = InHandle.As_RootMaw();

        if (utils_net::Get_HasAuthority(InHandle))
        {
            Maw.Get_Fragment(FMars_Fragment_RootMaw_Local).Last = TOptional<FMars_Fragment_RootMaw_Net>();
            return;
        }

        InHandle.BindTo_OnRepNotify(FMars_Fragment_RootMaw_Net, FCk_DynamicFragment_OnRepNotify(this, n"OnLedgerReplicated"));
        Reconcile(Maw, EMars_RootMaw_Reconcile::AsItStands);
    }

    // An expected absence, not a defect: a notify can land on an entity already ending.
    UFUNCTION()
    private void OnLedgerReplicated(FCk_Handle InHandle, FCk_DynamicFragment_RepNotifyInfo InInfo)
    {
        if (ck::Is_NOT_Valid(InHandle) || utils_entity_lifetime::Get_IsPendingDestroy(InHandle, ECk_EntityLifetime_DestructionPhase::BeginDestroy)
            || InHandle.Is_RootMaw() == false)
        { return; }

        auto Maw = InHandle.As_RootMaw();
        if (Maw.Get_Fragment(FMars_Fragment_RootMaw_Local).InitialState == EMars_Net_InitialState::Awaited)
        {
            Maw.Get_Fragment(FMars_Fragment_RootMaw_Local).InitialState = EMars_Net_InitialState::Taken;
            Reconcile(Maw, EMars_RootMaw_Reconcile::AsItStands);
            return;
        }

        Reconcile(Maw, EMars_RootMaw_Reconcile::AsItArrives);
    }

    // Last is written before the state and any broadcast; then the stance and the gape, the flinch, the action. As it
    // stands, Emerge and the jaw are set to where the ledger has them; as it arrives, the tick runs them there.
    private void Reconcile(FCk_Handle_RootMaw& InMaw, EMars_RootMaw_Reconcile InHow)
    {
        const auto Ledger = InMaw.Get_Fragment(FMars_Fragment_RootMaw_Net);
        auto& Local = InMaw.Get_Fragment(FMars_Fragment_RootMaw_Local);
        if (ck::EnsureIfNot(Local.Last.IsSet(), f"[RootMaw] [{InMaw.ToString()}] has no mirror state off authority"))
        { return; }

        const auto Last = Local.Last.GetValue();
        Local.Last = TOptional<FMars_Fragment_RootMaw_Net>(Ledger);

        auto& Posture = InMaw.Get_Fragment(FMars_Fragment_RootMaw_Posture);
        auto& Mouth = InMaw.Get_Fragment(FMars_Fragment_RootMaw_Mouth);
        Posture.Stance = Ledger.Stance;
        Mouth.Gape = Ledger.Gape;
        if (InHow == EMars_RootMaw_Reconcile::AsItStands)
        {
            Posture.Emerge = Ledger.Stance == EMars_RootMaw_Stance::Emerged ? 1.0f : 0.0f;
            Mouth.JawOpen = Ledger.Gape;
        }

        if (Ledger.Flinch.Count != Last.Flinch.Count)
        { Reconcile_Flinch(InMaw, Ledger.Flinch, InHow); }

        if (utils_root_maw::Get_IsSameAction(Ledger.Action, Last.Action))
        { return; }

        Reconcile_Action(InMaw, Ledger.Action);

        // As it stands, only a running action is announced; as it arrives, every change is, None with what ended.
        const auto Phase = Ledger.Action.Phase;
        if (InHow == EMars_RootMaw_Reconcile::AsItStands && Phase == EMars_RootMaw_ActionPhase::None)
        { return; }

        const auto Kind = Phase == EMars_RootMaw_ActionPhase::None ? Last.Action.Kind : Ledger.Action.Kind;

        // Handlers react on the Maw (its look): scope the script world to its own.
        const auto WorldContext = FAngelscriptGameThreadScopeWorldContext(utils_entity_lifetime::Get_WorldForEntity(InMaw));
        utils_root_maw::Broadcast_ActionPhase(InMaw, Kind, Phase);
    }

    // The authority's flinch, field for field: as it arrives this copy's own flinch clock starts, the jaw pops wide
    // (found buried) or slams shut, and a windup starts over; as it stands a flinch that is over is not replayed.
    private void Reconcile_Flinch(FCk_Handle_RootMaw& InMaw, const FMars_RootMaw_NetFlinch& InFlinch, EMars_RootMaw_Reconcile InHow)
    {
        const auto FlinchSeconds = InMaw.Get_Spec().Vitals.FlinchSeconds;
        auto& Hurt = InMaw.Get_Fragment(FMars_Fragment_RootMaw_Hurt);
        Hurt.FlinchCount = InFlinch.Count;
        Hurt.FlinchFrom = InFlinch.From;
        Hurt.FlinchFoundIn = InFlinch.FoundIn;
        if (InHow == EMars_RootMaw_Reconcile::AsItStands)
        { return; }

        Hurt.FlinchLeft = FlinchSeconds;
        InMaw.Get_Fragment(FMars_Fragment_RootMaw_Mouth).JawOpen = InFlinch.FoundIn == EMars_RootMaw_Stance::Buried ? 1.0f : 0.0f;

        auto& Action = InMaw.Get_Fragment(FMars_Fragment_RootMaw_Action);
        if (Action.Phase == EMars_RootMaw_ActionPhase::Windup)
        {
            Action.PhaseElapsed = 0.0f;
            Action.JawAtStart = 0.0f;
        }
    }

    // The phase starts on this machine's clock; a windup gapes from where the jaw is now.
    private void Reconcile_Action(FCk_Handle_RootMaw& InMaw, const FMars_RootMaw_NetAction& InAction)
    {
        const auto JawOpen = InMaw.Get_JawOpen();
        auto& Action = InMaw.Get_Fragment(FMars_Fragment_RootMaw_Action);
        Action.Kind = InAction.Kind;
        Action.Phase = InAction.Phase;
        Action.Generation = InAction.Generation;
        Action.PhaseElapsed = 0.0f;
        if (InAction.Phase == EMars_RootMaw_ActionPhase::Windup)
        { Action.JawAtStart = JawOpen; }
    }
}
