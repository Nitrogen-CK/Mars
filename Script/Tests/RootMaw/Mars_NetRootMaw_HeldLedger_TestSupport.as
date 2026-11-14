// A harness fixture, not a feature: a Root Maw whose replicated ledger the authority holds at a row's values
// from its spawn frame on, so the entity and that state leave the machine together, as a Maw already in that state
// reaches a player who joins. The ledger is held, not the creature: the Maw's own behaviour undoes a stance asked for
// in its first frames, and only what a copy is sent matters here. The authority drops what a held Maw is asked
// before its drain sees it: the drain publishes, and it runs in a frame's later passes (the spawn frame's among
// them), where a processor no marker wakes cannot write the ledger back. The authority's tick keeps running and
// publishing; the hold writes after it in every frame, so what replicates is the held ledger. A copy without
// authority composes as the real script does.

// On the authority's held Maw: the ledger it holds and the frames it was written in (logged by the net rig).
struct FMars_TESTONLY_Fragment_RootMaw_HeldLedger
{
    UPROPERTY()
    FMars_Fragment_RootMaw_Net Ledger;

    UPROPERTY()
    int32 ConstructFrame = -1;

    UPROPERTY()
    int32 FirstHoldFrame = -1;
}

namespace utils_root_maw_held
{
    // The authority's ledger overwritten with InLedger and marked to replicate.
    void Write(FCk_Handle InMaw, FMars_Fragment_RootMaw_Net InLedger)
    {
        auto Maw = InMaw;
        if (ck::EnsureIfNot(utils_net::Get_HasAuthority(Maw), f"[RootMawHeld] [{Maw.ToString()}] written without authority"))
        { return; }

        auto& Ledger = Maw.Get_Fragment(FMars_Fragment_RootMaw_Net);
        Ledger = InLedger;
        Maw.Request_MarkReplicationDirty(FMars_Fragment_RootMaw_Net);
    }
}

// In every pass that carries requests, before the Maw's drain: the authority drops what a held Maw was
// asked (its own state machine's asks among them), so its drain never runs on it and never publishes.
class UMars_TESTONLY_Processor_RootMaw_DropHeldRequests : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _MarkedDirtyBy = FMars_Fragment_RootMaw_Requests;
    default _RunBefore.Add(n"/Script/Angelscript.Mars_Processor_RootMaw_HandleRequests");

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_TESTONLY_Fragment_RootMaw_HeldLedger);
        Query.Require(FMars_Fragment_RootMaw_Requests);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle)
    {
        if (utils_net::Get_HasAuthority(InHandle) == false)
        { return; }

        InHandle.Request_TryRemove(FMars_Fragment_RootMaw_Requests);
    }
}

// Every frame, after the Maw's tick has published: the authority writes its held ledger back over what the tick
// published.
class UMars_TESTONLY_Processor_RootMaw_HoldLedger : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _RunAfter.Add(n"/Script/Angelscript.Mars_Processor_RootMaw_Tick");

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_TESTONLY_Fragment_RootMaw_HeldLedger);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle)
    {
        if (utils_net::Get_HasAuthority(InHandle) == false)
        { return; }

        auto& Held = InHandle.Get_Fragment(FMars_TESTONLY_Fragment_RootMaw_HeldLedger);
        if (Held.FirstHoldFrame < 0)
        { Held.FirstHoldFrame = int32(utils_time::Get_FrameCounter()); }

        const auto Ledger = Held.Ledger;
        utils_root_maw_held::Write(InHandle, Ledger);
    }
}

// The held Maw's spawn params, by the script's ExposeOnSpawn names.
struct FMars_NetRootMaw_Held_SpawnParams
{
    UPROPERTY()
    FTransform SpawnTransform = FTransform::Identity;

    UPROPERTY()
    FMars_RootMaw_Spec Spec;

    UPROPERTY()
    bool WithVisuals = false;

    UPROPERTY()
    FMars_Fragment_RootMaw_Net HeldLedger;
}

// The real Maw script; with authority over a composed Maw it also holds HeldLedger from its construct on.
class UMars_NetRootMaw_Held_EntityScript : UMars_RootMaw_EntityScript
{
    UPROPERTY(ExposeOnSpawn)
    FMars_Fragment_RootMaw_Net HeldLedger;

    UFUNCTION(BlueprintOverride)
    ECk_EntityScript_ConstructionFlow DoConstruct(FCk_Handle& InHandle)
    {
        const auto Flow = Super::DoConstruct(InHandle);
        if (utils_net::Get_HasAuthority(InHandle) == false || InHandle.Is_RootMaw() == false)
        { return Flow; }

        auto Held = FMars_TESTONLY_Fragment_RootMaw_HeldLedger();
        Held.Ledger = HeldLedger;
        Held.ConstructFrame = int32(utils_time::Get_FrameCounter());
        InHandle.Add_Fragment(Held);

        // The ledger holds the row's state in the spawn frame, whichever processors run in it.
        utils_root_maw_held::Write(InHandle, HeldLedger);
        return Flow;
    }
}
