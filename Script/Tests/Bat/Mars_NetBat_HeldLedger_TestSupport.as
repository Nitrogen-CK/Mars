// A harness fixture, not a feature: a Cellar Bat whose replicated ledger the authority holds at a row's values from its
// spawn frame on, so the entity and that state leave the machine together, as a bat already in that phase reaches a
// player who joins. The ledger is held, not the bat: the bat's own state machine asks for its roost phase as it enters
// it, undoing a phase asked for in its first frames, and only what a copy is sent matters here. The authority drops
// what a held bat is asked before its drain sees it: the drain publishes, and it runs in a frame's later passes (the
// spawn frame's among them), where a processor no marker wakes cannot write the ledger back. The authority's tick
// keeps running and publishing; the hold writes after it in every frame, so what replicates is the held ledger. A copy
// without authority composes as the real script does. A row may also move the held bat's root as it composes, so its
// copy is born away from its spawn place, as a bat that has flown reaches a player who joins.

// On the authority's held bat: the ledger it holds and the frames it was written in (logged by the net rig).
struct FMars_TESTONLY_Fragment_Bat_HeldLedger
{
    UPROPERTY()
    FMars_Fragment_Bat_Net Ledger;

    UPROPERTY()
    int32 ConstructFrame = -1;

    UPROPERTY()
    int32 FirstHoldFrame = -1;
}

namespace utils_bat_held
{
    // The authority's ledger overwritten with InLedger and marked to replicate.
    void Write(FCk_Handle InBat, FMars_Fragment_Bat_Net InLedger)
    {
        auto Bat = InBat;
        if (ck::EnsureIfNot(utils_net::Get_HasAuthority(Bat), f"[BatHeld] [{Bat.ToString()}] written without authority"))
        { return; }

        auto& Ledger = Bat.Get_Fragment(FMars_Fragment_Bat_Net);
        Ledger = InLedger;
        Bat.Request_MarkReplicationDirty(FMars_Fragment_Bat_Net);
    }
}

// In every pass that carries requests, before the bat's drain: the authority drops what a held bat was asked (its own
// state machine's asks among them), so its drain never runs on it and never publishes.
class UMars_TESTONLY_Processor_Bat_DropHeldRequests : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _MarkedDirtyBy = FMars_Fragment_Bat_Requests;
    default _RunBefore.Add(n"/Script/Angelscript.Mars_Processor_Bat_HandleRequests");

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_TESTONLY_Fragment_Bat_HeldLedger);
        Query.Require(FMars_Fragment_Bat_Requests);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle)
    {
        if (utils_net::Get_HasAuthority(InHandle) == false)
        { return; }

        InHandle.Request_TryRemove(FMars_Fragment_Bat_Requests);
    }
}

// Every frame, after the bat's tick has published: the authority writes its held ledger back over what the tick
// published.
class UMars_TESTONLY_Processor_Bat_HoldLedger : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _RunAfter.Add(n"/Script/Angelscript.Mars_Processor_Bat_Tick");

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_TESTONLY_Fragment_Bat_HeldLedger);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle)
    {
        if (utils_net::Get_HasAuthority(InHandle) == false)
        { return; }

        auto& Held = InHandle.Get_Fragment(FMars_TESTONLY_Fragment_Bat_HeldLedger);
        if (Held.FirstHoldFrame < 0)
        { Held.FirstHoldFrame = int32(utils_time::Get_FrameCounter()); }

        const auto Ledger = Held.Ledger;
        utils_bat_held::Write(InHandle, Ledger);
    }
}

// The held bat's spawn params, by the script's ExposeOnSpawn names.
struct FMars_NetBat_Held_SpawnParams
{
    UPROPERTY()
    FTransform SpawnTransform = FTransform::Identity;

    UPROPERTY()
    FMars_Bat_Spec Spec;

    UPROPERTY()
    bool WithVisuals = false;

    UPROPERTY()
    FMars_Fragment_Bat_Net HeldLedger;

    UPROPERTY()
    FVector HeldRootOffset = FVector::ZeroVector;
}

// The real bat script; with authority over a composed bat it also holds HeldLedger from its construct on and, with a
// non-zero HeldRootOffset, moves its root that far from its spawn place.
class UMars_NetBat_Held_EntityScript : UMars_CellarBat_EntityScript
{
    UPROPERTY(ExposeOnSpawn)
    FMars_Fragment_Bat_Net HeldLedger;

    UPROPERTY(ExposeOnSpawn)
    FVector HeldRootOffset = FVector::ZeroVector;

    UFUNCTION(BlueprintOverride)
    ECk_EntityScript_ConstructionFlow DoConstruct(FCk_Handle& InHandle)
    {
        const auto Flow = Super::DoConstruct(InHandle);
        if (utils_net::Get_HasAuthority(InHandle) == false || InHandle.Is_Bat() == false)
        { return Flow; }

        auto Held = FMars_TESTONLY_Fragment_Bat_HeldLedger();
        Held.Ledger = HeldLedger;
        Held.ConstructFrame = int32(utils_time::Get_FrameCounter());
        InHandle.Add_Fragment(Held);

        // The ledger holds the row's state in the spawn frame, whichever processors run in it.
        utils_bat_held::Write(InHandle, HeldLedger);

        if (HeldRootOffset.IsNearlyZero() == false)
        {
            auto Root = InHandle.As_Transform();
            utils_transform::Request_SetLocation(Root, FCk_Request_Transform_SetLocation(SpawnTransform.GetLocation() + HeldRootOffset));
        }

        return Flow;
    }
}
