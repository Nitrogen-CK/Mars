// The combat request drain (armed crawlers only). In order: the last SetAggression (off clears the combat target and,
// during Windup, Strike or Recover, queues a Disabled cancel), then the last SetCombatTarget (a change bumps the target
// generation and, during an attack, queues a TargetLost cancel), then the first cancel reason, then the last start. A
// start kept beside a cancel is rejected by the attack tick (CancelPending), never admitted. The brain's HasCombatTarget
// fact is Aggressive && a valid target, written whenever either changes: a passive crawler given a target explicitly
// never raises it, so its behaviour never engages, while a direct start still attacks. Everything is written before
// OnTargetChanged broadcasts, once, from the target before the drain to the target after it.
class UMars_Processor_Crawler_HandleRequests : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _MarkedDirtyBy = FMars_Fragment_Crawler_Requests;

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_Crawler);
        Query.Require(FMars_Fragment_Crawler_Attack);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle, FMars_Fragment_Crawler_Requests& InRequests)
    {
        auto Self = InHandle.As_Crawler();

        TArray<FMars_Request_Crawler_SetAggression> SetAggressionRequests = InRequests.SetAggressionRequests;
        TArray<FMars_Request_Crawler_SetCombatTarget> SetCombatTargetRequests = InRequests.SetCombatTargetRequests;
        TArray<FMars_Request_Crawler_StartAttack> StartAttackRequests = InRequests.StartAttackRequests;
        TArray<FMars_Request_Crawler_CancelAttack> CancelAttackRequests = InRequests.CancelAttackRequests;
        TArray<FMars_Request_Crawler_PrepareAttack> PrepareAttackRequests = InRequests.PrepareAttackRequests;

        // InRequests is invalid past this line; removing before broadcasting lets re-entrant requests survive.
        Self.Request_TryRemove(FMars_Fragment_Crawler_Requests);

        if (utils_entity_lifetime::Get_IsPendingDestroy(InHandle, ECk_EntityLifetime_DestructionPhase::BeginDestroy))
        { return; }

        auto& Intents = Self.Get_Fragment(FMars_Fragment_Crawler_AttackIntents);
        const auto OldTarget = Self.Get_CombatTarget();
        const auto WasAggressive = Self.Get_IsAggressive();

        if (SetAggressionRequests.Num() > 0)
        {
            const auto Aggressive = SetAggressionRequests.Last().Aggression == ECk_EnableDisable::Enable;
            Self.Get_Fragment(FMars_Fragment_Crawler_CombatTarget).Aggressive = Aggressive;

            if (Aggressive == false)
            { ChangeTarget(Self, FCk_Handle(), EMars_Crawler_AttackCancel::Disabled); }
        }

        if (SetCombatTargetRequests.Num() > 0)
        { ChangeTarget(Self, SetCombatTargetRequests.Last().Target, EMars_Crawler_AttackCancel::TargetLost); }

        const auto NewTarget = Self.Get_CombatTarget();
        const auto TargetChanged = NewTarget != OldTarget;
        const auto IsAggressive = Self.Get_IsAggressive();

        if (TargetChanged || IsAggressive != WasAggressive)
        {
            auto Brain = Self.Get_Brain();
            Brain.Request_SetFact(FMars_Request_Brain_SetFact(utils_crawler::Get_HasCombatTargetFact(), IsAggressive && ck::IsValid(NewTarget)));
        }

        if (CancelAttackRequests.Num() > 0 && Intents.PendingCancel.IsSet() == false)
        { Intents.PendingCancel = TOptional<EMars_Crawler_AttackCancel>(CancelAttackRequests[0].Reason); }

        if (StartAttackRequests.Num() > 0)
        { Intents.PendingStart = TOptional<FMars_Request_Crawler_StartAttack>(StartAttackRequests.Last()); }

        if (PrepareAttackRequests.Num() > 0)
        { Intents.PendingPrepare = TOptional<FMars_Request_Crawler_PrepareAttack>(PrepareAttackRequests.Last()); }

        if (TargetChanged && Self.Has_Fragment(FMars_Fragment_Crawler_Signals))
        { Self.Get_Fragment(FMars_Fragment_Crawler_Signals).OnTargetChanged.Broadcast(Self, OldTarget, NewTarget); }
    }

    // A changed target bumps the generation and, when an attack is in flight and nothing has cancelled it in this drain
    // yet, cancels it with InCancel.
    private void ChangeTarget(FCk_Handle_Crawler& InSelf, FCk_Handle InTarget, EMars_Crawler_AttackCancel InCancel)
    {
        auto& CombatTarget = InSelf.Get_Fragment(FMars_Fragment_Crawler_CombatTarget);
        if (CombatTarget.Target == InTarget)
        { return; }

        CombatTarget.Target = InTarget;
        ++CombatTarget.TargetGeneration;

        auto& Intents = InSelf.Get_Fragment(FMars_Fragment_Crawler_AttackIntents);
        if (utils_crawler::Get_IsOffensivePhase(InSelf.Get_AttackPhase()) && Intents.PendingCancel.IsSet() == false)
        { Intents.PendingCancel = TOptional<EMars_Crawler_AttackCancel>(InCancel); }
    }
}
