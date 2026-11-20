// A copy's show of the authority's attacks: only a combat-enabled copy without authority carries the show, and this
// processor is its only writer. Every frame it compares the ledger as the mirror last reconciled it (levels, never
// edges: two of the authority's writes inside one net update arrive as one) against what it shows:
//   - a new generation (neither the shown one nor the one taken as it stood) in Windup, Strike or Recover and not
//     cancelled: an action of its own still live is cancelled once and waited out; then a limb an earlier return left
//     unplanted goes back to the gait, the entry's clip is played on the copy's own player with its slots bound to the
//     same limbs (utils_crawler::Make_AttackPlaySpec, the player's own delivery), with the crawler as its owner, and
//     Admitted is cued. A new generation already over (Idle, Cooldown, CancelRecover) or cancelled is shown as it is
//     and nothing plays: a copy never starts an attack the authority has ended. With no seek, an attack first seen
//     late plays from its start;
//   - the shown generation: each newly reached Windup, Strike or Recover is cued once with that phase; a cancel while
//     its action is live cancels it once (the action's own return eases the body back) and cues Interrupted; Idle, or
//     a newer generation, uncancelled, cues Completed. The last of these is raised once;
//   - its action's OnFinished records the outcome, forgets the action and hands claimed limbs back to the gait; an
//     action gone without it is forgotten the same way, its outcome None.
// It never touches the root, the navigator, the dealer, a hit zone, a Health or anything the authority writes. Cues
// are raised only for an entry with a cue profile and only once something has bound them, as on the authority.
// The batch the show raises for its attack: its admission, a posed phase reached, its cancel or its completion.
enum EMars_Crawler_ShownCue
{
    Admitted,
    Phase,
    Interrupted,
    Completed
}

class UMars_Processor_Crawler_AttackShow : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_Crawler);
        Query.Require(FMars_Fragment_Crawler_AttackShow);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle)
    {
        if (utils_entity_lifetime::Get_IsPendingDestroy(InHandle, ECk_EntityLifetime_DestructionPhase::BeginDestroy))
        { return; }

        auto Crawler = InHandle.As_Crawler();
        const auto Local = Crawler.Get_Fragment(FMars_Fragment_Crawler_Local);
        if (ck::EnsureIfNot(Local.Last.IsSet(), f"[Crawler] [{Crawler.ToString()}] shows attacks without a mirror state"))
        { return; }

        const auto Ledger = Local.Last.GetValue();
        Forget_LostAction(Crawler);

        const auto Shown = Crawler.Get_Fragment(FMars_Fragment_Crawler_AttackShow).Generation;
        if (Ledger.AttackGeneration != Shown && Ledger.AttackGeneration != Local.StoodGeneration && Begin_Generation(Crawler, Ledger) == false)
        { return; }

        Show_Generation(Crawler, Ledger);
    }

    // True once InLedger's generation is the shown one; false while the copy waits for its own action to end.
    private bool Begin_Generation(FCk_Handle_Crawler& InCrawler, const FMars_Fragment_Crawler_Net& InLedger)
    {
        auto& Show = InCrawler.Get_Fragment(FMars_Fragment_Crawler_AttackShow);
        if (Show.Ended == false && Show.Generation != 0)
        {
            Show.Ended = true;
            Raise(InCrawler, EMars_Crawler_ShownCue::Completed, EMars_Crawler_AttackPhase::Idle);
        }

        if (utils_crawler::Get_IsOffensivePhase(InLedger.Phase) == false || InLedger.Cancelled)
        {
            Take_Generation(Show, InLedger);
            Show.Ended = true;
            return true;
        }

        if (Get_IsActionLive(Show))
        {
            if (Show.CancelRequested == false)
            {
                Show.CancelRequested = true;
                Show.Action.Request_Cancel(FCk_Request_ProceduralAction_Cancel());
            }

            return false;
        }

        const auto Entry = utils_crawler::Find_ResolvedAttack(InCrawler.Get_Spec().ResolvedAttacks, InLedger.AttackId);
        if (ck::EnsureIfNot(Entry.IsSet(), f"[Crawler] [{InCrawler.ToString()}] has no resolved attack [{InLedger.AttackId.ToString()}] to show"))
        {
            Take_Generation(Show, InLedger);
            Show.Ended = true;
            return true;
        }

        utils_crawler::Recover_UnplantedLimbs(InCrawler);
        FCk_Handle Owner = InCrawler;
        auto Action = utils_procedural_action::Create_FromClip(Owner, InCrawler.Get_ActionPlayer(), utils_crawler::Make_AttackPlaySpec(Entry.GetValue()));
        Take_Generation(Show, InLedger);
        Show.Phase = EMars_Crawler_AttackPhase::Idle;
        Show.Ended = false;
        Show.Action = Action;
        if (ck::IsValid(Action))
        {
            Show.Started += 1;
            utils_procedural_action::BindTo_OnFinished(Action, FCk_Delegate_ProceduralAction_OnFinished(this, n"OnActionFinished"));
        }

        Raise(InCrawler, EMars_Crawler_ShownCue::Admitted, EMars_Crawler_AttackPhase::Idle);
        return true;
    }

    private void Take_Generation(FMars_Fragment_Crawler_AttackShow& InOutShow, const FMars_Fragment_Crawler_Net& InLedger)
    {
        InOutShow.Generation = InLedger.AttackGeneration;
        InOutShow.AttackId = InLedger.AttackId;
        InOutShow.Phase = InLedger.Phase;
        InOutShow.CancelRequested = false;
    }

    private void Show_Generation(FCk_Handle_Crawler& InCrawler, const FMars_Fragment_Crawler_Net& InLedger)
    {
        auto& Show = InCrawler.Get_Fragment(FMars_Fragment_Crawler_AttackShow);
        if (InLedger.AttackGeneration != Show.Generation || Show.Ended)
        { return; }

        if (InLedger.Cancelled)
        {
            if (Get_IsActionLive(Show) && Show.CancelRequested == false)
            {
                Show.CancelRequested = true;
                Show.Action.Request_Cancel(FCk_Request_ProceduralAction_Cancel());
            }

            Show.Ended = true;
            Raise(InCrawler, EMars_Crawler_ShownCue::Interrupted, EMars_Crawler_AttackPhase::Idle);
            return;
        }

        if (utils_crawler::Get_IsOffensivePhase(InLedger.Phase) && int32(InLedger.Phase) > int32(Show.Phase))
        {
            Show.Phase = InLedger.Phase;
            Raise(InCrawler, EMars_Crawler_ShownCue::Phase, InLedger.Phase);
        }

        if (InLedger.Phase == EMars_Crawler_AttackPhase::Idle)
        {
            Show.Ended = true;
            Raise(InCrawler, EMars_Crawler_ShownCue::Completed, EMars_Crawler_AttackPhase::Idle);
        }
    }

    private bool Get_IsActionLive(const FMars_Fragment_Crawler_AttackShow& InShow) const
    {
        FCk_Handle Entity = InShow.Action;
        return ck::IsValid(Entity) && utils_entity_lifetime::Get_IsPendingDestroy(Entity, ECk_EntityLifetime_DestructionPhase::BeginDestroy) == false
            && InShow.Action.Get_State() != ECk_ProceduralAction_State::Finished;
    }

    // An action that went without its OnFinished (destroyed from outside) is forgotten as OnFinished would.
    private void Forget_LostAction(FCk_Handle_Crawler& InCrawler)
    {
        auto& Show = InCrawler.Get_Fragment(FMars_Fragment_Crawler_AttackShow);
        FCk_Handle Entity = Show.Action;
        if (Show.Action == FCk_Handle_ProceduralAction() || (ck::IsValid(Entity)
            && utils_entity_lifetime::Get_IsPendingDestroy(Entity, ECk_EntityLifetime_DestructionPhase::BeginDestroy) == false))
        { return; }

        Show.LastOutcome = ECk_ProceduralAction_Outcome::None;
        Show.Action = FCk_Handle_ProceduralAction();
        Show.CancelRequested = false;
        utils_crawler::Recover_UnplantedLimbs(InCrawler);
    }

    // One batch for the shown attack, inside the crawler's own world (a handler reacts on the crawler).
    private void Raise(FCk_Handle_Crawler& InCrawler, EMars_Crawler_ShownCue InWhat, EMars_Crawler_AttackPhase InPhase)
    {
        if (InCrawler.Has_Fragment(FMars_Fragment_Crawler_Signals) == false)
        { return; }

        const auto Show = InCrawler.Get_Fragment(FMars_Fragment_Crawler_AttackShow);
        const auto Entry = utils_crawler::Find_ResolvedAttack(InCrawler.Get_Spec().ResolvedAttacks, Show.AttackId);
        if (Entry.IsSet() == false || Entry.GetValue().Definition.CueProfile.IsValid() == false)
        { return; }

        auto Batch = utils_crawler::Make_ShownAttackCue(Show, Entry.GetValue(), InPhase);
        Batch.Admitted = InWhat == EMars_Crawler_ShownCue::Admitted;
        Batch.Interrupted = InWhat == EMars_Crawler_ShownCue::Interrupted;
        Batch.Completed = InWhat == EMars_Crawler_ShownCue::Completed;
        const auto WorldContext = FAngelscriptGameThreadScopeWorldContext(utils_entity_lifetime::Get_WorldForEntity(InCrawler));
        InCrawler.Get_Fragment(FMars_Fragment_Crawler_Signals).OnAttackCue.Broadcast(InCrawler, Batch);
    }

    // Fired by the copy's player for the action this show started; the action is the crawler's (its lifetime owner).
    UFUNCTION()
    private void OnActionFinished(FCk_Handle_ProceduralAction InAction, FCk_ProceduralAction_Terminal InTerminal)
    {
        FCk_Handle Entity = InAction;
        if (ck::Is_NOT_Valid(Entity))
        { return; }

        auto Owner = utils_entity_lifetime::Get_LifetimeOwner(Entity);
        if (ck::Is_NOT_Valid(Owner) || Owner.Has_Fragment(FMars_Fragment_Crawler_AttackShow) == false)
        { return; }

        auto Crawler = Owner.As_Crawler();
        auto& Show = Crawler.Get_Fragment(FMars_Fragment_Crawler_AttackShow);
        if (Show.Action != InAction)
        { return; }

        Show.LastOutcome = InTerminal.Get_Result().Get_Outcome();
        Show.Action = FCk_Handle_ProceduralAction();
        Show.CancelRequested = false;
        utils_crawler::Recover_UnplantedLimbs(Crawler);
    }
}
