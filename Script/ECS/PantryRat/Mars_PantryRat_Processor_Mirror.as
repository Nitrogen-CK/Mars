// Once per rat: the authority drops the mirror state (its drain and its tick publish the ledger). A machine without
// authority binds the ledger's rep-notify and reconciles once as it stands, which shows what this machine composed
// (Emerge, announced to nobody). The ledger's first application is the state the copy was born into and is taken once
// as it stands: the phase written and announced once, a den entry or a corpse fade already at its end (a copy born
// while its rat enters the den shows nothing until the authority hides or retires it; born hidden it is hidden), every
// other phase started now. Each later change is reconciled as it arrives: its phase starts on this machine's clock,
// on which the tick then crouches and fades it. A reconcile raises OnPhaseChanged once (from the phase the copy
// showed); a phase that never arrived because two of the authority's writes reached this machine as one is not
// replayed. The lethal blow's impulse is written as it comes, both ways. A copy born into a corpse reads its hold
// over, so its body shows it fallen and topples nothing.
class UMars_Processor_PantryRat_Mirror : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _MarkedDirtyBy = FMars_Tag_PantryRat_NeedsMirror;

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_PantryRat);
        Query.Require(FMars_Tag_PantryRat_NeedsMirror);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle)
    {
        InHandle.Request_TryRemove(FMars_Tag_PantryRat_NeedsMirror);
        auto Rat = InHandle.As_PantryRat();

        if (utils_net::Get_HasAuthority(InHandle))
        {
            Rat.Get_Fragment(FMars_Fragment_PantryRat_Local).Last = TOptional<FMars_Fragment_PantryRat_Net>();
            return;
        }

        InHandle.BindTo_OnRepNotify(FMars_Fragment_PantryRat_Net, FCk_DynamicFragment_OnRepNotify(this, n"OnLedgerReplicated"));
        Reconcile(Rat, EMars_Net_Reconcile::AsItStands);
    }

    // An expected absence, not a defect: a notify can land on an entity already ending.
    UFUNCTION()
    private void OnLedgerReplicated(FCk_Handle InHandle, FCk_DynamicFragment_RepNotifyInfo InInfo)
    {
        if (ck::Is_NOT_Valid(InHandle) || utils_entity_lifetime::Get_IsPendingDestroy(InHandle, ECk_EntityLifetime_DestructionPhase::BeginDestroy)
            || InHandle.Is_PantryRat() == false)
        { return; }

        auto Rat = InHandle.As_PantryRat();
        if (Rat.Get_Fragment(FMars_Fragment_PantryRat_Local).InitialState == EMars_Net_InitialState::Awaited)
        {
            Rat.Get_Fragment(FMars_Fragment_PantryRat_Local).InitialState = EMars_Net_InitialState::Taken;
            Reconcile(Rat, EMars_Net_Reconcile::AsItStands);
            return;
        }

        Reconcile(Rat, EMars_Net_Reconcile::AsItArrives);
    }

    // Last is written before the state and any broadcast. As it stands, a fade out the copy was born into reads
    // finished; as it arrives, the phase starts now. The state is not read after the emit.
    private void Reconcile(FCk_Handle_PantryRat& InRat, EMars_Net_Reconcile InHow)
    {
        const auto Ledger = InRat.Get_Fragment(FMars_Fragment_PantryRat_Net);
        auto& Local = InRat.Get_Fragment(FMars_Fragment_PantryRat_Local);
        if (ck::EnsureIfNot(Local.Last.IsSet(), f"[PantryRat] [{InRat.ToString()}] has no mirror state off authority"))
        { return; }

        const auto Last = Local.Last.GetValue();
        Local.Last = TOptional<FMars_Fragment_PantryRat_Net>(Ledger);

        // A level, never announced: the drain writes it with the lethal hit, often before the phase moves.
        const auto Tuning = InRat.Get_Tuning();
        auto& State = InRat.Get_Fragment(FMars_Fragment_PantryRat);
        State.Death.HitImpulse = Ledger.HitImpulse;
        if (Ledger.Phase == Last.Phase)
        { return; }

        const auto WasDead = utils_pantry_rat::Get_IsDeadPhase(State.Phase);
        utils_pantry_rat::Set_Phase(State, Ledger.Phase);
        if (InHow == EMars_Net_Reconcile::AsItStands)
        { State.PhaseStartedAt = State.Clock - utils_pantry_rat::Get_FadeOutSeconds(Ledger.Phase, Tuning); }

        // The hold this copy was born into reads over; a death that arrives starts its hold now.
        if (utils_pantry_rat::Get_IsDeadPhase(Ledger.Phase) && WasDead == false)
        { State.Death.DiedAt = InHow == EMars_Net_Reconcile::AsItStands ? State.Clock - Tuning.DeathHoldSeconds : State.Clock; }

        utils_pantry_rat::Apply_ShownPresence(State, Tuning);

        // Handlers react on the rat (its look): scope the script world to its own.
        const auto WorldContext = FAngelscriptGameThreadScopeWorldContext(utils_entity_lifetime::Get_WorldForEntity(InRat));
        utils_pantry_rat::Emit_PhaseSteps(InRat);
    }
}
