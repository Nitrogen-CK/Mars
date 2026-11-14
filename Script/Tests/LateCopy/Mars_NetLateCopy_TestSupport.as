// A harness probe, not a feature: the smallest replicated entity whose one replicated script fragment can already hold
// its value in the frame it is spawned, composed with the same mirror recipe as the kernels (a ledger added only when
// none arrived, a Local holding what this machine composed, a tag that wakes a mirror processor). Each machine records
// what it saw and in which frame: the construct, the mirror's first pass, every rep-notify and the replication-complete
// promise. Nothing here decides anything; the tests read the record.

// The replicated ledger: one value, written by the authority only.
struct FMars_TESTONLY_Fragment_LateCopy_Net
{
    UPROPERTY()
    int32 Value = 0;
}

// Each machine's own: the ledger this machine composed.
struct FMars_TESTONLY_Fragment_LateCopy_Local
{
    UPROPERTY()
    TOptional<FMars_TESTONLY_Fragment_LateCopy_Net> Last;
}

// Added by the probe's construct, dropped by UMars_TESTONLY_Processor_LateCopy_Mirror on its first pass.
struct FMars_TESTONLY_Tag_LateCopy_NeedsMirror {}

// One reading: the frame it was taken in and the ledger's value then (-1 for both while it has not been taken).
struct FMars_TESTONLY_LateCopy_Reading
{
    UPROPERTY()
    int32 Frame = -1;

    UPROPERTY()
    int32 Value = -1;

    FMars_TESTONLY_LateCopy_Reading() {}

    FMars_TESTONLY_LateCopy_Reading(int32 InFrame, int32 InValue)
    {
        Frame = InFrame;
        Value = InValue;
    }
}

// What this machine saw. Plain data, never replicated.
struct FMars_TESTONLY_Fragment_LateCopy_Record
{
    // Whether the replicated ledger was already on the entity before its construct added anything.
    UPROPERTY()
    bool HadLedgerAtConstruct = false;

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
}

// The kernels' mirror shape: once per probe, woken by the tag. A copy without authority binds the ledger's rep-notify;
// every machine records its first pass. It writes nothing but the record.
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
            = FMars_TESTONLY_LateCopy_Reading(utils_late_copy_probe::Get_Frame(), Value);

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
        const auto Value = Probe.Get_Fragment(FMars_TESTONLY_Fragment_LateCopy_Net).Value;
        Probe.Get_Fragment(FMars_TESTONLY_Fragment_LateCopy_Record).Notifies.Add(
            FMars_TESTONLY_LateCopy_Reading(utils_late_copy_probe::Get_Frame(), Value));
    }
}

// The spawn params, by the script's ExposeOnSpawn names, so no call site waits for the generated ones.
struct FMars_NetLateCopy_Probe_SpawnParams
{
    UPROPERTY()
    FTransform SpawnTransform = FTransform::Identity;

    UPROPERTY()
    int32 ValueAtSpawn = 0;

    FMars_NetLateCopy_Probe_SpawnParams() {}

    FMars_NetLateCopy_Probe_SpawnParams(FTransform InSpawnTransform, int32 InValueAtSpawn)
    {
        SpawnTransform = InSpawnTransform;
        ValueAtSpawn = InValueAtSpawn;
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

    UFUNCTION(BlueprintOverride)
    ECk_EntityScript_ConstructionFlow DoConstruct(FCk_Handle& InHandle)
    {
        const auto HadLedger = InHandle.Has_Fragment(FMars_TESTONLY_Fragment_LateCopy_Net);

        utils_transform::Add(InHandle, SpawnTransform, ECk_Replication::Replicates);
        utils_entity_tag::Add(InHandle, n"TAG_MarsTestNetLateCopy");

        auto Record = FMars_TESTONLY_Fragment_LateCopy_Record();
        Record.HadLedgerAtConstruct = HadLedger;
        Record.ConstructFrame = utils_late_copy_probe::Get_Frame();
        InHandle.Add_Fragment(Record);

        // A copy composes the default, as every kernel's Add does; only the authority knows the spawn value.
        auto Ledger = FMars_TESTONLY_Fragment_LateCopy_Net();
        if (utils_net::Get_HasAuthority(InHandle))
        { Ledger.Value = ValueAtSpawn; }

        auto Local = FMars_TESTONLY_Fragment_LateCopy_Local();
        Local.Last = TOptional<FMars_TESTONLY_Fragment_LateCopy_Net>(Ledger);

        if (HadLedger == false)
        { InHandle.Add_Fragment(Ledger, ECk_Replication::Replicates); }

        InHandle.Add_Fragment(Local);
        InHandle.Add_Fragment(FMars_TESTONLY_Tag_LateCopy_NeedsMirror());

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
        const auto Value = Probe.Get_Fragment(FMars_TESTONLY_Fragment_LateCopy_Net).Value;
        Probe.Get_Fragment(FMars_TESTONLY_Fragment_LateCopy_Record).Promise
            = FMars_TESTONLY_LateCopy_Reading(utils_late_copy_probe::Get_Frame(), Value);
    }
}
