// A harness fixture, not a feature: a crawler whose replicated attack ledger the authority holds at the row's values
// from its construct on, so the entity and that ledger leave the machine together, as a crawler already attacking
// reaches a player who joins. The ledger is held, not the attack: the crawler is passive and never attacks while it is
// held. Its attack tick keeps running and publishing; the hold writes after it in every frame, so what replicates is
// the held ledger until a row stops holding. A copy without authority composes as the real script does.

// On the authority's held crawler: the ledger it holds, whether it still holds it, and the frames it was written in
// (logged by the net rig).
struct FMars_TESTONLY_Fragment_Crawler_HeldLedger
{
    UPROPERTY()
    FMars_Fragment_Crawler_Net Ledger;

    UPROPERTY()
    bool Holding = true;

    UPROPERTY()
    int32 ConstructFrame = -1;

    UPROPERTY()
    int32 FirstHoldFrame = -1;
}

namespace utils_crawler_held
{
    // The ledger the fixture holds: a jab at generation 7, in Strike, not cancelled, no hurt.
    FMars_Fragment_Crawler_Net Make_HeldLedger()
    {
        auto Ledger = FMars_Fragment_Crawler_Net();
        Ledger.AttackId = GameplayTags::Attack_Mars_Jab;
        Ledger.AttackGeneration = 7;
        Ledger.Phase = EMars_Crawler_AttackPhase::Strike;
        Ledger.Cancelled = false;
        Ledger.HurtCount = 0;
        return Ledger;
    }

    // The authority's ledger overwritten with InLedger and marked to replicate. A crawler without a ledger (combat off)
    // is left alone.
    void Write(FCk_Handle InCrawler, FMars_Fragment_Crawler_Net InLedger)
    {
        auto Crawler = InCrawler;
        if (ck::EnsureIfNot(utils_net::Get_HasAuthority(Crawler), f"[CrawlerHeld] [{Crawler.ToString()}] written without authority"))
        { return; }

        if (Crawler.Has_Fragment(FMars_Fragment_Crawler_Net) == false)
        { return; }

        auto& Ledger = Crawler.Get_Fragment(FMars_Fragment_Crawler_Net);
        Ledger = InLedger;
        Crawler.Request_MarkReplicationDirty(FMars_Fragment_Crawler_Net);
    }
}

// Every frame, after the crawler's attack tick has published: the authority writes its held ledger back over what the
// tick published, while it holds.
class UMars_TESTONLY_Processor_Crawler_HoldLedger : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _RunAfter.Add(n"/Script/Angelscript.Mars_Processor_Crawler_AttackTick");

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_TESTONLY_Fragment_Crawler_HeldLedger);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle)
    {
        if (utils_net::Get_HasAuthority(InHandle) == false)
        { return; }

        auto& Held = InHandle.Get_Fragment(FMars_TESTONLY_Fragment_Crawler_HeldLedger);
        if (Held.Holding == false)
        { return; }

        if (Held.FirstHoldFrame < 0)
        { Held.FirstHoldFrame = int32(utils_time::Get_FrameCounter()); }

        const auto Ledger = Held.Ledger;
        utils_crawler_held::Write(InHandle, Ledger);
    }
}

// The real crawler script; with authority over a composed crawler it also holds the fixture's ledger from its construct
// on.
class UMars_TESTONLY_NetCrawler_HeldLedger_EntityScript : UMars_Crawler_EntityScript
{
    UFUNCTION(BlueprintOverride)
    ECk_EntityScript_ConstructionFlow DoConstruct(FCk_Handle& InHandle)
    {
        const auto Flow = Super::DoConstruct(InHandle);
        if (utils_net::Get_HasAuthority(InHandle) == false || InHandle.Is_Crawler() == false)
        { return Flow; }

        auto Held = FMars_TESTONLY_Fragment_Crawler_HeldLedger();
        Held.Ledger = utils_crawler_held::Make_HeldLedger();
        Held.ConstructFrame = int32(utils_time::Get_FrameCounter());
        InHandle.Add_Fragment(Held);

        // The ledger holds the row's values in the spawn frame, whichever processors run in it.
        utils_crawler_held::Write(InHandle, Held.Ledger);
        return Flow;
    }
}
