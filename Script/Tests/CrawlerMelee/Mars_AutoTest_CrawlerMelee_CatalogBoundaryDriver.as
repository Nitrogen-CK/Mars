enum EMars_TESTONLY_CatalogBoundary { Windup, Strike, Recover, Candidate }

// Every damage request the crawler's dealer was sent: drained (dealt or rejected) or still queued.
mixin int32 Get_IssuedDamageRequests(const FCk_Handle_Crawler& Self)
{
    const auto Dealer = Self.Get_CombatDealer();
    auto Count = Dealer.Get_HitsDealt() + Dealer.Get_HitsRejected();
    if (Dealer.Has_Fragment(FMars_Fragment_DamageDealer_Requests))
    { Count += Dealer.Get_Fragment(FMars_Fragment_DamageDealer_Requests).DealDamageRequests.Num(); }

    return Count;
}

struct FMars_TESTONLY_CatalogBoundaryEvidence
{
    bool Fired = false;
    int64 Frame = 0;
    int32 DamageRequests = 0;
    EMars_Crawler_AttackPhase Phase = EMars_Crawler_AttackPhase::Idle;
    bool CandidatePending = false;
}

struct FMars_TESTONLY_CatalogBoundaryCommand
{
    FCk_Handle_Crawler Crawler;
    FCk_Handle_Health Health;
    EMars_TESTONLY_CatalogBoundary When = EMars_TESTONLY_CatalogBoundary::Strike;
    FMars_TESTONLY_CatalogBoundaryEvidence Evidence;
}

// Public damage is queued before the real Health -> BodyPart -> AttackTick chain. The only written fragment is this
// test-owned command/evidence record; the production kernel must cancel before a queued candidate can commit.
class UMars_TESTONLY_Processor_CrawlerMelee_CatalogBoundaryDriver : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _RunBefore.Add(n"/Script/Angelscript.Mars_Processor_Health_HandleRequests");
    default _RunBefore.Add(n"/Script/Angelscript.Mars_Processor_BodyPart_HandleRequests");
    default _RunBefore.Add(n"/Script/Angelscript.Mars_Processor_Crawler_AttackTick");

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query) {}

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle, FMars_TESTONLY_CatalogBoundaryCommand& InCommand)
    {
        if (InCommand.Evidence.Fired || ck::Is_NOT_Valid(InCommand.Crawler))
        { return; }

        const auto Crawler = InCommand.Crawler;
        const auto Action = Crawler.Get_AttackAction();
        if (ck::Is_NOT_Valid(Action) || Action.Get_LastReceipt().Get_HasAcceptedPose() == false)
        { return; }

        const auto Candidate = Crawler.Get_AttackCandidatePending();
        const auto Phase = Crawler.Get_AttackPhase();
        const auto Due = (InCommand.When == EMars_TESTONLY_CatalogBoundary::Windup && Phase == EMars_Crawler_AttackPhase::Windup) ||
            (InCommand.When == EMars_TESTONLY_CatalogBoundary::Strike && Phase == EMars_Crawler_AttackPhase::Strike) ||
            (InCommand.When == EMars_TESTONLY_CatalogBoundary::Recover && Phase == EMars_Crawler_AttackPhase::Recover) ||
            (InCommand.When == EMars_TESTONLY_CatalogBoundary::Candidate && Candidate);
        if (Due == false)
        { return; }

        InCommand.Evidence.Fired = true;
        InCommand.Evidence.Frame = utils_time::Get_FrameCounter();
        InCommand.Evidence.Phase = Phase;
        InCommand.Evidence.CandidatePending = Candidate;
        InCommand.Evidence.DamageRequests = Crawler.Get_IssuedDamageRequests();
        InCommand.Health.Request_ApplyDamage(FMars_Request_Health_ApplyDamage(FMars_DamageEvent(1000.0f, GameplayTags::DamageType_Mars_Sever)));
    }
}
