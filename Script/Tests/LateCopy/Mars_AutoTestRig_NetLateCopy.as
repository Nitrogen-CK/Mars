// The late-copy probe net tests' shared steps: the server spawns the probe under the replicated spawn owner at the
// row's base with the row's spawn value and tracks it for cleanup; each machine finds its copy by tag near the base and
// logs what its copy recorded, and which path brought the final value to its mirror.
UCLASS(Abstract)
class UMars_AutoTestRig_NetLateCopy : UCk_AutoTest_NetBase
{
    default _TimeoutSeconds = 20.0f;

    protected const int32 k_SlowPolls = 5000;
    // A client asserts once the last server step has had this long to arrive.
    protected const float32 k_SettleSeconds = 1.0f;
    // The server waits this long after it finds its probe, so the client's copy has composed.
    protected const float32 k_ComposeSeconds = 2.0f;
    // The server holds this long after its last write before it finishes and its cleanup replicates.
    protected const float32 k_ServerHoldSeconds = 2.0f;
    protected const float64 k_NearCm = 400.0;
    protected const int32 k_FinalValue = 7;

    protected FVector _Base = FVector::ZeroVector;
    protected FCk_Handle _Probe;
    protected int32 _EnsuresAtStart = 0;

    protected void Begin_Rig(FVector InBase)
    {
        _Base = InBase;
        _EnsuresAtStart = utils_ensure::Get_EnsureCount();
    }

    protected bool Get_IsServer()
    {
        return utils_net::Get_HasAuthority(Get_SubjectEntity());
    }

    protected int32 Get_NewEnsures() const
    {
        return utils_ensure::Get_EnsureCount() - _EnsuresAtStart;
    }

    protected FString Get_MachineName()
    {
        return Get_IsServer() ? "server" : "client";
    }

    UFUNCTION()
    protected void Is_ReplicatedSpawnOwnerPublished(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(utils_mars_net::Get_HasReplicatedSpawnOwner(Get_SubjectEntity()));
    }

    // Server: the probe at the base, under the replicated spawn owner, its ledger holding InValueAtSpawn from its spawn
    // frame.
    protected void Spawn_ServerProbe(int32 InValueAtSpawn)
    {
        utils_entity_script::Request_SpawnEntity(utils_mars_net::Get_ReplicatedSpawnOwner(Get_SubjectEntity()),
            UMars_NetLateCopy_Probe_EntityScript,
            FMars_NetLateCopy_Probe_SpawnParams(FTransform(FRotator::ZeroRotator, _Base), InValueAtSpawn));
    }

    UFUNCTION()
    protected void Is_ProbeFound(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsProbeFound());
    }

    UFUNCTION()
    protected void Is_LedgerFinal(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsProbeFound() && Get_LedgerValue() == k_FinalValue);
    }

    // This machine's copy of the probe near the base has composed (the server tracks it the first time).
    protected bool Get_IsProbeFound()
    {
        if (ck::IsValid(_Probe))
        { return true; }

        for (auto Candidate : utils_entity_tag::ForEach_Entity(Get_SubjectEntity(), n"TAG_MarsTestNetLateCopy"))
        {
            if (Get_IsNear(Candidate) == false)
            { continue; }

            if (Candidate.Has_Fragment(FMars_TESTONLY_Fragment_LateCopy_Record) == false)
            { continue; }

            _Probe = Candidate;
            if (Get_IsServer())
            { Track_ForCleanup(Candidate); }

            return true;
        }

        return false;
    }

    protected bool Get_IsNear(FCk_Handle InEntity)
    {
        const auto Transform = InEntity.As_Transform(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(Transform))
        { return false; }

        auto Offset = utils_transform::Get_EntityCurrentTransform(Transform).GetLocation() - _Base;
        Offset.Z = 0.0;
        return Offset.Size() < k_NearCm;
    }

    // The ledger's value on this machine's copy; -1 until the probe is found or while it has no ledger.
    protected int32 Get_LedgerValue()
    {
        if (ck::Is_NOT_Valid(_Probe) || _Probe.Has_Fragment(FMars_TESTONLY_Fragment_LateCopy_Net) == false)
        { return -1; }

        return _Probe.Get_Fragment(FMars_TESTONLY_Fragment_LateCopy_Net).Value;
    }

    protected FMars_TESTONLY_Fragment_LateCopy_Record Get_Record()
    {
        if (ck::Is_NOT_Valid(_Probe) || _Probe.Has_Fragment(FMars_TESTONLY_Fragment_LateCopy_Record) == false)
        { return FMars_TESTONLY_Fragment_LateCopy_Record(); }

        return _Probe.Get_Fragment(FMars_TESTONLY_Fragment_LateCopy_Record);
    }

    // stood: the mirror's first pass already read the final value; arrived: it read the default and a notify
    // brought the final value; anything else is spelled out.
    protected FString Get_Path()
    {
        const auto Record = Get_Record();
        if (Record.Mirror.Frame < 0)
        { return "noMirror"; }

        if (Record.Mirror.Value == k_FinalValue)
        { return "stood"; }

        if (Record.Mirror.Value != 0)
        { return "other"; }

        for (auto Notify : Record.Notifies)
        {
            if (Notify.Value == k_FinalValue)
            { return "arrived"; }
        }

        return "pending";
    }

    // Every recorded notify was taken at or after the construct.
    protected bool Get_AreNotifiesAfterConstruct()
    {
        const auto Record = Get_Record();
        for (auto Notify : Record.Notifies)
        {
            if (Notify.Frame < Record.ConstructFrame)
            { return false; }
        }

        return true;
    }

    // The row's one log line on this machine: what its copy recorded, in which frames, and the path.
    protected void Log_Row(FString InRow)
    {
        const auto Record = Get_Record();
        const auto IsFound = ck::IsValid(_Probe);
        const auto HasAuthority = IsFound && utils_net::Get_HasAuthority(_Probe);

        FString NotifiesText = "";
        for (auto Notify : Record.Notifies)
        { NotifiesText += f" {Notify.Frame}:{Notify.Value}"; }

        const auto Line = f"[LateCopyNetTest] {InRow} {Get_MachineName()} found={IsFound} authority={HasAuthority} hadLedgerAtConstruct={Record.HadLedgerAtConstruct} constructFrame={Record.ConstructFrame} mirror=[{Record.Mirror.Frame} {Record.Mirror.Value}] notifies={Record.Notifies.Num()} [{NotifiesText} ] promise=[{Record.Promise.Frame} {Record.Promise.Value}] ledger={Get_LedgerValue()} ensures={Get_NewEnsures()} path={Get_Path()} frame={utils_late_copy_probe::Get_Frame()}";
        Log(Line);
    }
}
