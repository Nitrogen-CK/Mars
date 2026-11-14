// A harness fixture, not a feature: a Pickle Mimic whose replicated ledger the authority holds at a row's values
// from its spawn frame on, so the entity and that state leave the machine together, as a mimic already in that state
// reaches a player who joins. The ledger is held, not the creature: the mimic's own behaviour undoes a stance asked for
// in its first frames, and only what a copy is sent matters here. The authority drops what a held mimic is asked
// before its drain sees it: the drain publishes, and it runs in a frame's later passes (the spawn frame's among
// them), where a processor no marker wakes cannot write the ledger back. The authority's tick keeps running and
// publishing; the hold writes after it in every frame, so what replicates is the held ledger. A copy without
// authority composes as the real script does.

// On the authority's held mimic: the ledger it holds and the frames it was written in (logged by the net rig).
struct FMars_TESTONLY_Fragment_PickleMimic_HeldLedger
{
    UPROPERTY()
    FMars_Fragment_PickleMimic_Net Ledger;

    UPROPERTY()
    int32 ConstructFrame = -1;

    UPROPERTY()
    int32 FirstHoldFrame = -1;
}

namespace utils_pickle_mimic_held
{
    // The authority's ledger overwritten with InLedger and marked to replicate.
    void Write(FCk_Handle InMimic, FMars_Fragment_PickleMimic_Net InLedger)
    {
        auto Mimic = InMimic;
        if (ck::EnsureIfNot(utils_net::Get_HasAuthority(Mimic), f"[PickleMimicHeld] [{Mimic.ToString()}] written without authority"))
        { return; }

        auto& Ledger = Mimic.Get_Fragment(FMars_Fragment_PickleMimic_Net);
        Ledger = InLedger;
        Mimic.Request_MarkReplicationDirty(FMars_Fragment_PickleMimic_Net);
    }
}

// In every pass that carries requests, before the mimic's drain: the authority drops what a held mimic was
// asked (its own state machine's asks among them), so its drain never runs on it and never publishes.
class UMars_TESTONLY_Processor_PickleMimic_DropHeldRequests : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _MarkedDirtyBy = FMars_Fragment_PickleMimic_Requests;
    default _RunBefore.Add(n"/Script/Angelscript.Mars_Processor_PickleMimic_HandleRequests");

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_TESTONLY_Fragment_PickleMimic_HeldLedger);
        Query.Require(FMars_Fragment_PickleMimic_Requests);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle)
    {
        if (utils_net::Get_HasAuthority(InHandle) == false)
        { return; }

        InHandle.Request_TryRemove(FMars_Fragment_PickleMimic_Requests);
    }
}

// Every frame, after the mimic's tick has published: the authority writes its held ledger back over what the tick
// published.
class UMars_TESTONLY_Processor_PickleMimic_HoldLedger : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _RunAfter.Add(n"/Script/Angelscript.Mars_Processor_PickleMimic_Tick");

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_TESTONLY_Fragment_PickleMimic_HeldLedger);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle)
    {
        if (utils_net::Get_HasAuthority(InHandle) == false)
        { return; }

        auto& Held = InHandle.Get_Fragment(FMars_TESTONLY_Fragment_PickleMimic_HeldLedger);
        if (Held.FirstHoldFrame < 0)
        { Held.FirstHoldFrame = int32(utils_time::Get_FrameCounter()); }

        const auto Ledger = Held.Ledger;
        utils_pickle_mimic_held::Write(InHandle, Ledger);
    }
}

// The held mimic's spawn params, by the script's ExposeOnSpawn names.
struct FMars_NetPickleMimic_Held_SpawnParams
{
    UPROPERTY()
    FTransform SpawnTransform = FTransform::Identity;

    UPROPERTY()
    FMars_PickleMimic_Spec Spec;

    UPROPERTY()
    bool WithVisuals = false;

    UPROPERTY()
    FMars_Fragment_PickleMimic_Net HeldLedger;
}

// The real mimic script; with authority over a composed mimic it also holds HeldLedger from its construct on.
class UMars_NetPickleMimic_Held_EntityScript : UMars_PickleMimic_EntityScript
{
    UPROPERTY(ExposeOnSpawn)
    FMars_Fragment_PickleMimic_Net HeldLedger;

    UFUNCTION(BlueprintOverride)
    ECk_EntityScript_ConstructionFlow DoConstruct(FCk_Handle& InHandle)
    {
        const auto Flow = Super::DoConstruct(InHandle);
        if (utils_net::Get_HasAuthority(InHandle) == false || InHandle.Is_PickleMimic() == false)
        { return Flow; }

        auto Held = FMars_TESTONLY_Fragment_PickleMimic_HeldLedger();
        Held.Ledger = HeldLedger;
        Held.ConstructFrame = int32(utils_time::Get_FrameCounter());
        InHandle.Add_Fragment(Held);

        // The ledger holds the row's state in the spawn frame, whichever processors run in it.
        utils_pickle_mimic_held::Write(InHandle, HeldLedger);
        return Flow;
    }
}
