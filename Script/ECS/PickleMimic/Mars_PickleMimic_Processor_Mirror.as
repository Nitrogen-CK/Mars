// Once per mimic: the authority drops the mirror state (its drain and its tick publish the ledger). A machine without
// authority binds the ledger's rep-notify and reconciles once as it stands, which shows what this machine composed.
// The ledger's first application is the state the copy was born into and is taken once as it stands: the mimic where
// it is, a running action from its phase's start, no past flinch. Each later change is reconciled as it arrives, and
// the tick then plays the stand, the tuck, the lid's ease and the action's phase on this machine's clock. A reconcile
// raises OnActionPhase once per arrived action change (OnStance is the tick's); a phase that never arrived because two
// of the authority's writes reached this machine as one is not replayed.
class UMars_Processor_PickleMimic_Mirror : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _MarkedDirtyBy = FMars_Tag_PickleMimic_NeedsMirror;

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_PickleMimic);
        Query.Require(FMars_Tag_PickleMimic_NeedsMirror);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle)
    {
        InHandle.Request_TryRemove(FMars_Tag_PickleMimic_NeedsMirror);
        auto Mimic = InHandle.As_PickleMimic();

        if (utils_net::Get_HasAuthority(InHandle))
        {
            Mimic.Get_Fragment(FMars_Fragment_PickleMimic_Local).Last = TOptional<FMars_Fragment_PickleMimic_Net>();
            return;
        }

        InHandle.BindTo_OnRepNotify(FMars_Fragment_PickleMimic_Net, FCk_DynamicFragment_OnRepNotify(this, n"OnLedgerReplicated"));
        Reconcile(Mimic, EMars_PickleMimic_Reconcile::AsItStands);
    }

    // An expected absence, not a defect: a notify can land on an entity already ending.
    UFUNCTION()
    private void OnLedgerReplicated(FCk_Handle InHandle, FCk_DynamicFragment_RepNotifyInfo InInfo)
    {
        if (ck::Is_NOT_Valid(InHandle) || utils_entity_lifetime::Get_IsPendingDestroy(InHandle, ECk_EntityLifetime_DestructionPhase::BeginDestroy)
            || InHandle.Is_PickleMimic() == false)
        { return; }

        auto Mimic = InHandle.As_PickleMimic();
        if (Mimic.Get_Fragment(FMars_Fragment_PickleMimic_Local).InitialState == EMars_Net_InitialState::Awaited)
        {
            Mimic.Get_Fragment(FMars_Fragment_PickleMimic_Local).InitialState = EMars_Net_InitialState::Taken;
            Reconcile(Mimic, EMars_PickleMimic_Reconcile::AsItStands);
            return;
        }

        Reconcile(Mimic, EMars_PickleMimic_Reconcile::AsItArrives);
    }

    // Last is written before the state and any broadcast; then the stance and the gape, the flinch, the action. As it
    // stands, Rise and the lid are set to where the ledger has them; as it arrives, the tick runs them there.
    private void Reconcile(FCk_Handle_PickleMimic& InMimic, EMars_PickleMimic_Reconcile InHow)
    {
        const auto Ledger = InMimic.Get_Fragment(FMars_Fragment_PickleMimic_Net);
        auto& Local = InMimic.Get_Fragment(FMars_Fragment_PickleMimic_Local);
        if (ck::EnsureIfNot(Local.Last.IsSet(), f"[PickleMimic] [{InMimic.ToString()}] has no mirror state off authority"))
        { return; }

        const auto Last = Local.Last.GetValue();
        Local.Last = TOptional<FMars_Fragment_PickleMimic_Net>(Ledger);

        auto& Posture = InMimic.Get_Fragment(FMars_Fragment_PickleMimic_Posture);
        auto& Mouth = InMimic.Get_Fragment(FMars_Fragment_PickleMimic_Mouth);
        Posture.Stance = Ledger.Stance;
        Mouth.Gape = Ledger.Gape;
        if (InHow == EMars_PickleMimic_Reconcile::AsItStands)
        {
            Posture.Rise = Ledger.Stance == EMars_PickleMimic_Stance::Standing ? 1.0f : 0.0f;
            Mouth.LidOpen = Ledger.Gape;
        }

        if (Ledger.Flinch.Count != Last.Flinch.Count)
        { Reconcile_Flinch(InMimic, Ledger.Flinch, InHow); }

        if (utils_pickle_mimic::Get_IsSameAction(Ledger.Action, Last.Action))
        { return; }

        Reconcile_Action(InMimic, Ledger.Action);

        // As it stands, only a running action is announced; as it arrives, every change is, None with what ended.
        const auto Phase = Ledger.Action.Phase;
        if (InHow == EMars_PickleMimic_Reconcile::AsItStands && Phase == EMars_PickleMimic_ActionPhase::None)
        { return; }

        const auto Kind = Phase == EMars_PickleMimic_ActionPhase::None ? Last.Action.Kind : Ledger.Action.Kind;

        // Handlers react on the mimic (its look): scope the script world to its own.
        const auto WorldContext = FAngelscriptGameThreadScopeWorldContext(utils_entity_lifetime::Get_WorldForEntity(InMimic));
        utils_pickle_mimic::Broadcast_ActionPhase(InMimic, Kind, Phase);
    }

    // The authority's flinch, field for field: as it arrives this copy's own flinch clock starts, the lid pops wide
    // (found tucked) or slams shut, and a windup starts over; as it stands a flinch that is over is not replayed.
    private void Reconcile_Flinch(FCk_Handle_PickleMimic& InMimic, const FMars_PickleMimic_NetFlinch& InFlinch, EMars_PickleMimic_Reconcile InHow)
    {
        const auto FlinchSeconds = InMimic.Get_Spec().Vitals.FlinchSeconds;
        auto& Hurt = InMimic.Get_Fragment(FMars_Fragment_PickleMimic_Hurt);
        Hurt.FlinchCount = InFlinch.Count;
        Hurt.FlinchFrom = InFlinch.From;
        Hurt.FlinchFoundIn = InFlinch.FoundIn;
        if (InHow == EMars_PickleMimic_Reconcile::AsItStands)
        { return; }

        Hurt.FlinchLeft = FlinchSeconds;
        InMimic.Get_Fragment(FMars_Fragment_PickleMimic_Mouth).LidOpen = InFlinch.FoundIn == EMars_PickleMimic_Stance::Tucked ? 1.0f : 0.0f;

        auto& Action = InMimic.Get_Fragment(FMars_Fragment_PickleMimic_Action);
        if (Action.Phase == EMars_PickleMimic_ActionPhase::Windup)
        {
            Action.PhaseElapsed = 0.0f;
            Action.LidAtStart = 0.0f;
        }
    }

    // The phase starts on this machine's clock; a windup gapes from where the lid is now.
    private void Reconcile_Action(FCk_Handle_PickleMimic& InMimic, const FMars_PickleMimic_NetAction& InAction)
    {
        const auto LidOpen = InMimic.Get_LidOpen();
        auto& Action = InMimic.Get_Fragment(FMars_Fragment_PickleMimic_Action);
        Action.Kind = InAction.Kind;
        Action.Phase = InAction.Phase;
        Action.Generation = InAction.Generation;
        Action.PhaseElapsed = 0.0f;
        if (InAction.Phase == EMars_PickleMimic_ActionPhase::Windup)
        { Action.LidAtStart = LidOpen; }
    }
}
