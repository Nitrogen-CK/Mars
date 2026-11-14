// A harness probe, not a feature: the smallest replicated entity whose one replicated script fragment can already hold
// its value in the frame it is spawned, composed with the same mirror recipe as the kernels (a ledger added only when
// none arrived, a Local holding what this machine composed and whether it has taken the state it was born into, a tag
// that wakes a mirror processor). It is the reference for how a mirror takes that state: once, as it stands, at the
// ledger's first application on this machine (or at its compose when the ledger was already there), and every later
// change as it arrives. Each machine records what it saw and in which frame: the construct, the mirror's first pass,
// every rep-notify and how it was taken, and the replication-complete promise. Nothing here decides anything; the tests
// read the record.

// The replicated ledger: one value, written by the authority only.
struct FMars_TESTONLY_Fragment_LateCopy_Net
{
    UPROPERTY()
    int32 Value = 0;
}

// Each machine's own: the ledger this machine composed and whether this copy has taken the state it was born into.
struct FMars_TESTONLY_Fragment_LateCopy_Local
{
    UPROPERTY()
    TOptional<FMars_TESTONLY_Fragment_LateCopy_Net> Last;

    UPROPERTY()
    EMars_Net_InitialState InitialState = EMars_Net_InitialState::Awaited;
}

// The authority's spawn value, which its compose writes into the ledger. Never on a copy without authority.
struct FMars_TESTONLY_Fragment_LateCopy_Spawn
{
    UPROPERTY()
    int32 ValueAtSpawn = 0;
}

// Added by the probe's compose, dropped by UMars_TESTONLY_Processor_LateCopy_Mirror on its first pass.
struct FMars_TESTONLY_Tag_LateCopy_NeedsMirror {}

// How a reading was taken: as it stands (the state the copy was born into) or as it arrives (a change).
enum EMars_TESTONLY_LateCopy_Reconcile
{
    AsItStands,
    AsItArrives
}

// When a copy without authority composes the probe's kernel: in its construct, as every kernel does, or only when the
// row asks, so its ledger can have been applied first.
enum EMars_TESTONLY_LateCopy_Compose
{
    AtConstruct,
    WhenAsked
}

// One reading: the frame it was taken in, the ledger's value then (-1 for both while it has not been taken) and how
// it was taken.
struct FMars_TESTONLY_LateCopy_Reading
{
    UPROPERTY()
    int32 Frame = -1;

    UPROPERTY()
    int32 Value = -1;

    UPROPERTY()
    EMars_TESTONLY_LateCopy_Reconcile Way = EMars_TESTONLY_LateCopy_Reconcile::AsItStands;

    FMars_TESTONLY_LateCopy_Reading() {}

    FMars_TESTONLY_LateCopy_Reading(int32 InFrame, int32 InValue, EMars_TESTONLY_LateCopy_Reconcile InWay)
    {
        Frame = InFrame;
        Value = InValue;
        Way = InWay;
    }
}

// What this machine saw. Plain data, never replicated.
struct FMars_TESTONLY_Fragment_LateCopy_Record
{
    // Whether the replicated ledger was already on the entity when the probe's kernel composed.
    UPROPERTY()
    bool HadLedgerAtCompose = false;

    // The copy's level as its compose left it.
    UPROPERTY()
    EMars_Net_InitialState InitialStateAtCompose = EMars_Net_InitialState::Awaited;

    UPROPERTY()
    int32 ConstructFrame = -1;

    UPROPERTY()
    FMars_TESTONLY_LateCopy_Reading Mirror;

    UPROPERTY()
    TArray<FMars_TESTONLY_LateCopy_Reading> Notifies;

    UPROPERTY()
    FMars_TESTONLY_LateCopy_Reading Promise;
}

namespace utils_late_copy_probe
{
    // Server only: a later write of the ledger, replicated as a change.
    void Write(FCk_Handle InProbe, int32 InValue)
    {
        auto Probe = InProbe;
        if (ck::EnsureIfNot(utils_net::Get_HasAuthority(Probe), f"[LateCopy] [{Probe.ToString()}] written without authority"))
        { return; }

        Probe.Get_Fragment(FMars_TESTONLY_Fragment_LateCopy_Net).Value = InValue;
        Probe.Request_MarkReplicationDirty(FMars_TESTONLY_Fragment_LateCopy_Net);
    }

    int32 Get_Frame()
    {
        return int32(utils_time::Get_FrameCounter());
    }

    // The probe's kernel, as a kernel's Add composes it: the ledger only when none arrived (the authority's holding its
    // spawn value), the Local holding the default this machine composed, and the tag that wakes the mirror. On a copy
    // without authority only the replicated application can have put the ledger here, so a copy that finds it was born
    // into it and has taken it: the mirror's first pass shows it as it stands.
    void Compose(FCk_Handle InProbe)
    {
        auto Probe = InProbe;
        if (ck::EnsureIfNot(Probe.Has_Fragment(FMars_TESTONLY_Fragment_LateCopy_Record),
            f"[LateCopy] [{Probe.ToString()}] composed without its record"))
        { return; }

        if (ck::EnsureIfNot(Probe.Has_Fragment(FMars_TESTONLY_Fragment_LateCopy_Local) == false,
            f"[LateCopy] [{Probe.ToString()}] composed twice"))
        { return; }

        const auto HadLedger = Probe.Has_Fragment(FMars_TESTONLY_Fragment_LateCopy_Net);

        auto Ledger = FMars_TESTONLY_Fragment_LateCopy_Net();
        auto Local = FMars_TESTONLY_Fragment_LateCopy_Local();
        Local.Last = TOptional<FMars_TESTONLY_Fragment_LateCopy_Net>(Ledger);

        if (HadLedger)
        { Local.InitialState = EMars_Net_InitialState::Taken; }
        else
        {
            if (Probe.Has_Fragment(FMars_TESTONLY_Fragment_LateCopy_Spawn))
            { Ledger.Value = Probe.Get_Fragment(FMars_TESTONLY_Fragment_LateCopy_Spawn).ValueAtSpawn; }

            Probe.Add_Fragment(Ledger, ECk_Replication::Replicates);
        }

        auto& Record = Probe.Get_Fragment(FMars_TESTONLY_Fragment_LateCopy_Record);
        Record.HadLedgerAtCompose = HadLedger;
        Record.InitialStateAtCompose = Local.InitialState;

        Probe.Add_Fragment(Local);
        Probe.Add_Fragment(FMars_TESTONLY_Tag_LateCopy_NeedsMirror());
    }
}

// The kernels' mirror shape: once per probe, woken by the tag. Every machine records its first pass, as it stands; a
// copy without authority binds the ledger's rep-notify. The first notify while the state is awaited is the ledger's
// first application, taken as it stands; every later one is taken as it arrives. It writes nothing but the record and
// the level.
class UMars_TESTONLY_Processor_LateCopy_Mirror : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _MarkedDirtyBy = FMars_TESTONLY_Tag_LateCopy_NeedsMirror;

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_TESTONLY_Fragment_LateCopy_Local);
        Query.Require(FMars_TESTONLY_Tag_LateCopy_NeedsMirror);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle)
    {
        InHandle.Request_TryRemove(FMars_TESTONLY_Tag_LateCopy_NeedsMirror);

        const auto Value = InHandle.Get_Fragment(FMars_TESTONLY_Fragment_LateCopy_Net).Value;
        InHandle.Get_Fragment(FMars_TESTONLY_Fragment_LateCopy_Record).Mirror
            = FMars_TESTONLY_LateCopy_Reading(utils_late_copy_probe::Get_Frame(), Value, EMars_TESTONLY_LateCopy_Reconcile::AsItStands);

        if (utils_net::Get_HasAuthority(InHandle))
        { return; }

        InHandle.BindTo_OnRepNotify(FMars_TESTONLY_Fragment_LateCopy_Net, FCk_DynamicFragment_OnRepNotify(this, n"OnLedgerReplicated"));
    }

    // An expected absence, not a defect: a notify can land on an entity already ending.
    UFUNCTION()
    private void OnLedgerReplicated(FCk_Handle InHandle, FCk_DynamicFragment_RepNotifyInfo InInfo)
    {
        if (ck::Is_NOT_Valid(InHandle) || utils_entity_lifetime::Get_IsPendingDestroy(InHandle, ECk_EntityLifetime_DestructionPhase::BeginDestroy)
            || InHandle.Has_Fragment(FMars_TESTONLY_Fragment_LateCopy_Record) == false)
        { return; }

        auto Probe = InHandle;
        auto Way = EMars_TESTONLY_LateCopy_Reconcile::AsItArrives;
        if (Probe.Get_Fragment(FMars_TESTONLY_Fragment_LateCopy_Local).InitialState == EMars_Net_InitialState::Awaited)
        {
            Probe.Get_Fragment(FMars_TESTONLY_Fragment_LateCopy_Local).InitialState = EMars_Net_InitialState::Taken;
            Way = EMars_TESTONLY_LateCopy_Reconcile::AsItStands;
        }

        const auto Value = Probe.Get_Fragment(FMars_TESTONLY_Fragment_LateCopy_Net).Value;
        Probe.Get_Fragment(FMars_TESTONLY_Fragment_LateCopy_Record).Notifies.Add(
            FMars_TESTONLY_LateCopy_Reading(utils_late_copy_probe::Get_Frame(), Value, Way));
    }
}

// The spawn params, by the script's ExposeOnSpawn names, so no call site waits for the generated ones.
struct FMars_NetLateCopy_Probe_SpawnParams
{
    UPROPERTY()
    FTransform SpawnTransform = FTransform::Identity;

    UPROPERTY()
    int32 ValueAtSpawn = 0;

    UPROPERTY()
    EMars_TESTONLY_LateCopy_Compose Compose = EMars_TESTONLY_LateCopy_Compose::AtConstruct;

    FMars_NetLateCopy_Probe_SpawnParams() {}

    FMars_NetLateCopy_Probe_SpawnParams(FTransform InSpawnTransform, int32 InValueAtSpawn, EMars_TESTONLY_LateCopy_Compose InCompose)
    {
        SpawnTransform = InSpawnTransform;
        ValueAtSpawn = InValueAtSpawn;
        Compose = InCompose;
    }
}

class UMars_NetLateCopy_Probe_EntityScript : UCk_GenericEntityScript_UE
{
    // Stance A: the server spawns it under the spawn owner; the entity, its transform and its ledger replicate.
    default _Replication = ECk_Replication::Replicates;

    UPROPERTY(ExposeOnSpawn)
    FTransform SpawnTransform = FTransform::Identity;

    // The ledger's value in the spawn frame, on the authority only.
    UPROPERTY(ExposeOnSpawn)
    int32 ValueAtSpawn = 0;

    // A copy without authority composes the kernel in its construct or when the row calls Compose; the authority
    // always composes in its construct.
    UPROPERTY(ExposeOnSpawn)
    EMars_TESTONLY_LateCopy_Compose Compose = EMars_TESTONLY_LateCopy_Compose::AtConstruct;

    UFUNCTION(BlueprintOverride)
    ECk_EntityScript_ConstructionFlow DoConstruct(FCk_Handle& InHandle)
    {
        utils_transform::Add(InHandle, SpawnTransform, ECk_Replication::Replicates);
        utils_entity_tag::Add(InHandle, n"TAG_MarsTestNetLateCopy");

        auto Record = FMars_TESTONLY_Fragment_LateCopy_Record();
        Record.ConstructFrame = utils_late_copy_probe::Get_Frame();
        InHandle.Add_Fragment(Record);

        // Only the authority knows the spawn value; a copy composes the default, as every kernel's Add does.
        const auto HasAuthority = utils_net::Get_HasAuthority(InHandle);
        if (HasAuthority)
        {
            auto Spawn = FMars_TESTONLY_Fragment_LateCopy_Spawn();
            Spawn.ValueAtSpawn = ValueAtSpawn;
            InHandle.Add_Fragment(Spawn);
        }

        if (HasAuthority || Compose == EMars_TESTONLY_LateCopy_Compose::AtConstruct)
        { utils_late_copy_probe::Compose(InHandle); }

        utils_entity_replication_driver::Promise_OnReplicationComplete(InHandle,
            FCk_Delegate_EntityReplicationDriver_OnReplicationComplete(this, n"OnReplicationComplete"));

        return ECk_EntityScript_ConstructionFlow::Finished;
    }

    // An expected absence, not a defect: the promise can fire on an entity already ending.
    UFUNCTION()
    private void OnReplicationComplete(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(InHandle) || InHandle.Has_Fragment(FMars_TESTONLY_Fragment_LateCopy_Record) == false)
        { return; }

        auto Probe = InHandle;
        const auto Value = Probe.Has_Fragment(FMars_TESTONLY_Fragment_LateCopy_Net)
            ? Probe.Get_Fragment(FMars_TESTONLY_Fragment_LateCopy_Net).Value : -1;
        Probe.Get_Fragment(FMars_TESTONLY_Fragment_LateCopy_Record).Promise
            = FMars_TESTONLY_LateCopy_Reading(utils_late_copy_probe::Get_Frame(), Value, EMars_TESTONLY_LateCopy_Reconcile::AsItStands);
    }
}
