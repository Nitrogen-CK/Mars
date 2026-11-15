// A harness fixture, not a feature: a Screaming Turnip root whose replicated ledger the authority holds at a row's
// values from its spawn frame on, so the entity and that state leave the machine together, as a root that has already
// screamed reaches a player who joins. The ledger is held, not the root: a scream is reached only by the tick's clock,
// seconds after the spawn, and only what a copy is sent matters here. Nothing asks a held root anything (its one
// request kind is sent by no production code), so no request is dropped. The authority's tick keeps running and
// publishing; the hold writes after it in every frame, so what replicates is the held ledger. A copy without authority
// composes as the real script does.

// On the authority's held root: the ledger it holds and the frames it was written in (logged by the net rig).
struct FMars_TESTONLY_Fragment_ScreamingTurnip_HeldLedger
{
    UPROPERTY()
    FMars_Fragment_ScreamingTurnip_Net Ledger;

    UPROPERTY()
    int32 ConstructFrame = -1;

    UPROPERTY()
    int32 FirstHoldFrame = -1;
}

namespace utils_screaming_turnip_held
{
    // The authority's ledger overwritten with InLedger and marked to replicate.
    void Write(FCk_Handle InRoot, FMars_Fragment_ScreamingTurnip_Net InLedger)
    {
        auto Root = InRoot;
        if (ck::EnsureIfNot(utils_net::Get_HasAuthority(Root), f"[ScreamingTurnipHeld] [{Root.ToString()}] written without authority"))
        { return; }

        auto& Ledger = Root.Get_Fragment(FMars_Fragment_ScreamingTurnip_Net);
        Ledger = InLedger;
        Root.Request_MarkReplicationDirty(FMars_Fragment_ScreamingTurnip_Net);
    }
}

// Every frame, after the root's tick has published: the authority writes its held ledger back over what the tick
// published.
class UMars_TESTONLY_Processor_ScreamingTurnip_HoldLedger : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _RunAfter.Add(n"/Script/Angelscript.Mars_Processor_ScreamingTurnip_Tick");

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_TESTONLY_Fragment_ScreamingTurnip_HeldLedger);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle)
    {
        if (utils_net::Get_HasAuthority(InHandle) == false)
        { return; }

        auto& Held = InHandle.Get_Fragment(FMars_TESTONLY_Fragment_ScreamingTurnip_HeldLedger);
        if (Held.FirstHoldFrame < 0)
        { Held.FirstHoldFrame = int32(utils_time::Get_FrameCounter()); }

        const auto Ledger = Held.Ledger;
        utils_screaming_turnip_held::Write(InHandle, Ledger);
    }
}

// The held root's spawn params, by the scripts' ExposeOnSpawn names (the others keep their defaults).
struct FMars_NetScreamingTurnip_Held_SpawnParams
{
    UPROPERTY()
    FTransform SpawnTransform = FTransform::Identity;

    UPROPERTY()
    TSoftObjectPtr<UCk_InventoryItem_Definition> Definition;

    UPROPERTY()
    EMars_WorldItem_Mode Mode = EMars_WorldItem_Mode::World;

    UPROPERTY()
    FMars_ScreamingTurnip_Vocal Vocal;

    UPROPERTY()
    FMars_Fragment_ScreamingTurnip_Net HeldLedger;
}

// The real root script; with authority over a World-mode item that composed the kernel it also holds HeldLedger from
// its construct on.
class UMars_NetScreamingTurnip_Held_EntityScript : UMars_ScreamingTurnip_EntityScript
{
    UPROPERTY(ExposeOnSpawn)
    FMars_Fragment_ScreamingTurnip_Net HeldLedger;

    UFUNCTION(BlueprintOverride)
    ECk_EntityScript_ConstructionFlow DoConstruct(FCk_Handle& InHandle)
    {
        const auto Flow = Super::DoConstruct(InHandle);
        if (utils_net::Get_HasAuthority(InHandle) == false || Mode != EMars_WorldItem_Mode::World
            || InHandle.Is_ScreamingTurnip() == false)
        { return Flow; }

        auto Held = FMars_TESTONLY_Fragment_ScreamingTurnip_HeldLedger();
        Held.Ledger = HeldLedger;
        Held.ConstructFrame = int32(utils_time::Get_FrameCounter());
        InHandle.Add_Fragment(Held);

        // The ledger holds the row's state in the spawn frame, whichever processors run in it.
        utils_screaming_turnip_held::Write(InHandle, HeldLedger);
        return Flow;
    }
}
