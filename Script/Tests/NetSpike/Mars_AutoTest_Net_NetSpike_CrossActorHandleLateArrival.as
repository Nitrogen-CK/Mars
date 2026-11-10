// Probe B of the handle spike: a replicated fragment on the test SUBJECT (its own replicated actor) holds a handle to an
// entity B spawned under the spawn owner (the relay actor): the geometry of a ledger on a pawn naming a world item. Two
// writes in one run. Write 1: B1 spawns, constructs, the server waits a second, then writes. Write 2: the server writes
// B2 in the frame B2 constructs, so the client's copy of B2's driver is not there or not linked when the write lands.
// The client logs, per write, the notifies that carried it, what the handle named at the first of them, the frame it
// first named its B, and whether that happened with no notify since the write arrived. It passes by recording: it logs
// one [NetSpike] B line and asserts only that it ran to the end.
// Surface: Ck.NetSpike.Net.AS_NetSpike_CrossActorHandleLateArrival
class UCk_AutoTest_Net_NetSpike_CrossActorHandleLateArrival : UCk_AutoTest_NetBase
{
    default _TimeoutSeconds = 26.0f;

    private const int32 k_PayloadB1 = 3201;
    private const int32 k_PayloadB2 = 3202;
    private const float32 k_DelayBeforeWrite1Seconds = 1.0f;
    private const float32 k_WatchEachWriteSeconds = 5.0f;
    private const int32 k_SlowPolls = 5000;
    // Frames the client watches each write once it arrived (5 s at the pinned 60 fps).
    private const int32 k_WatchFrames = 300;
    // The client's whole window: past it, it records what it has.
    private const int32 k_MaxFrames = 1150;

    private FCk_Handle _B1;
    private FCk_Handle _B2;

    private int32 _Frame = 0;
    private TArray<FMars_NetSpike_WriteRecord> _Writes;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Subject = Get_SubjectEntity();
        if (ck::Is_NOT_Valid(Subject))
        { FinishFailure("subject entity not found"); return; }

        if (Subject.Has_Fragment(FMars_Fragment_NetSpike_Ref) == false)
        { Subject.Add_Fragment(FMars_Fragment_NetSpike_Ref(), ECk_Replication::Replicates); }

        _Writes.Add(FMars_NetSpike_WriteRecord());
        _Writes.Add(FMars_NetSpike_WriteRecord());

        if (utils_net::Get_HasAuthority(Subject) == false)
        {
            Subject.BindTo_OnRepNotify(FMars_Fragment_NetSpike_Ref, FCk_DynamicFragment_OnRepNotify(this, n"OnRefNotify"));
            WaitUntil(n"Poll_Client", n"OnClientWatched", k_MaxFrames + 10);
            return;
        }

        WaitUntil(n"Is_ReplicatedSpawnOwnerPublished", n"OnServerOwnerPublished", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ReplicatedSpawnOwnerPublished(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(utils_mars_net::Get_HasReplicatedSpawnOwner(Get_SubjectEntity()));
    }

    UFUNCTION()
    private void OnServerOwnerPublished(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        auto Pending = Spawn_B(k_PayloadB1, 0.0);
        utils_pending_entity_script::Promise_OnConstructed(Pending, FCk_Delegate_EntityScript_Constructed(this, n"OnServerB1Constructed"));
    }

    UFUNCTION()
    private void OnServerB1Constructed(FCk_Handle_EntityScript InEntityScriptHandle)
    {
        _B1 = FCk_Handle(InEntityScriptHandle);
        Track_ForCleanup(_B1);
        WaitSeconds(k_DelayBeforeWrite1Seconds, n"OnServerWrite1");
    }

    UFUNCTION()
    private void OnServerWrite1(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Write_Ref(_B1, 1);
        WaitSeconds(k_WatchEachWriteSeconds, n"OnServerSpawnB2");
    }

    UFUNCTION()
    private void OnServerSpawnB2(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        auto Pending = Spawn_B(k_PayloadB2, 300.0);
        utils_pending_entity_script::Promise_OnConstructed(Pending, FCk_Delegate_EntityScript_Constructed(this, n"OnServerB2Constructed"));
    }

    // The write lands in B2's construction frame.
    UFUNCTION()
    private void OnServerB2Constructed(FCk_Handle_EntityScript InEntityScriptHandle)
    {
        _B2 = FCk_Handle(InEntityScriptHandle);
        Track_ForCleanup(_B2);
        Write_Ref(_B2, 2);
        WaitSeconds(k_WatchEachWriteSeconds, n"OnServerHeld");
    }

    UFUNCTION()
    private void OnServerHeld(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        FinishSuccess();
    }

    private FCk_Handle_PendingEntityScript Spawn_B(int32 InPayload, float64 InY)
    {
        auto Owner = utils_mars_net::Get_ReplicatedSpawnOwner(Get_SubjectEntity());
        auto Params = FMars_NetSpike_SpawnParams(FVector(15000.0, InY, 0.0), InPayload);
        return utils_entity_script::Request_SpawnEntity(Owner, UMars_NetSpike_EntityScript, Params);
    }

    private void Write_Ref(FCk_Handle InTarget, int32 InSerial)
    {
        auto Subject = Get_SubjectEntity();
        auto& Ref = Subject.Get_Fragment(FMars_Fragment_NetSpike_Ref);
        Ref.Target = InTarget;
        Ref.Serial = InSerial;
        Subject.Request_MarkReplicationDirty(FMars_Fragment_NetSpike_Ref);
    }

    UFUNCTION()
    private void OnRefNotify(FCk_Handle InHandle, FCk_DynamicFragment_RepNotifyInfo InInfo)
    {
        const auto Serial = Get_Ref().Serial;
        if (Serial < 1 || Serial > 2)
        { return; }

        auto& Record = _Writes[Serial - 1];
        Record.Notifies += 1;
        if (Record.AtFirstNotify.IsSet())
        { return; }

        Record.AtFirstNotify = TOptional<EMars_NetSpike_Seen>(Get_Seen(Serial));
    }

    // One call per frame: per write, the frame it arrived and the first frame its handle named its B.
    UFUNCTION()
    private void Poll_Client(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        _Frame += 1;
        const auto Serial = Get_Ref().Serial;
        if (Serial >= 1 && Serial <= 2)
        {
            auto& Record = _Writes[Serial - 1];
            if (Record.SeenFrame.IsSet() == false)
            {
                Record.SeenFrame = TOptional<int32>(_Frame);
                Record.NotifiesAtSeen = Record.Notifies;
            }

            if (Record.FirstMatchFrame.IsSet() == false && Get_Seen(Serial) == EMars_NetSpike_Seen::Match)
            {
                Record.FirstMatchFrame = TOptional<int32>(_Frame);
                Record.NotifiesAtMatch = Record.Notifies;
            }
        }

        const auto Write2Watched = _Writes[1].SeenFrame.IsSet() && _Frame - _Writes[1].SeenFrame.GetValue() >= k_WatchFrames;
        auto Result = OutResult;
        Result.Set(Write2Watched || _Frame >= k_MaxFrames);
    }

    UFUNCTION()
    private void OnClientWatched(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto B1 = Describe(0);
        const auto B2 = Describe(1);
        const auto End = Get_Seen(Get_Ref().Serial);
        Log(f"[NetSpike] B B1:{B1} | B2:{B2} | end={End :n} frames={_Frame}");
        FinishSuccess();
    }

    // notifies, what the first notify carrying the write saw, frames from arrival to the first frame naming its B, and
    // whether a notify landed between the write's arrival and that frame (none = the poll alone saw the handle resolve).
    private FString Describe(int32 InIndex) const
    {
        const auto& Record = _Writes[InIndex];
        if (Record.SeenFrame.IsSet() == false)
        { return f"notArrived notifies={Record.Notifies}"; }

        const auto AtNotify = Record.AtFirstNotify.IsSet() ? f"{Record.AtFirstNotify.GetValue() :n}" : "noNotify";
        if (Record.FirstMatchFrame.IsSet() == false)
        { return f"notifies={Record.Notifies} atFirstNotify={AtNotify} match=never"; }

        const auto Frames = Record.FirstMatchFrame.GetValue() - Record.SeenFrame.GetValue();
        const auto NotifiesBetween = Record.NotifiesAtMatch - Record.NotifiesAtSeen;
        return f"notifies={Record.Notifies} atFirstNotify={AtNotify} matchFramesAfterArrival={Frames} notifiesBetweenArrivalAndMatch={NotifiesBetween}";
    }

    private FMars_Fragment_NetSpike_Ref Get_Ref()
    {
        return Get_SubjectEntity().Get_Fragment(FMars_Fragment_NetSpike_Ref);
    }

    // What the stored handle names right now, against this machine's copy of the B the InSerial write named.
    private EMars_NetSpike_Seen Get_Seen(int32 InSerial)
    {
        const auto Target = Get_Ref().Target;
        if (ck::Is_NOT_Valid(Target))
        { return EMars_NetSpike_Seen::Invalid; }

        const auto Expected = utils_net_spike::Find(Get_SubjectEntity(), InSerial == 1 ? k_PayloadB1 : k_PayloadB2);
        if (ck::IsValid(Expected) && Target == Expected)
        { return EMars_NetSpike_Seen::Match; }

        if (InSerial == 2 && Target == utils_net_spike::Find(Get_SubjectEntity(), k_PayloadB1))
        { return EMars_NetSpike_Seen::Stale; }

        return EMars_NetSpike_Seen::Other;
    }
}

// What a replicated handle named when the probe looked: nothing, its own target, the previous write's target, or
// something else.
enum EMars_NetSpike_Seen
{
    Invalid,
    Match,
    Stale,
    Other
}

struct FMars_NetSpike_WriteRecord
{
    int32 Notifies = 0;
    TOptional<EMars_NetSpike_Seen> AtFirstNotify;
    TOptional<int32> SeenFrame;
    int32 NotifiesAtSeen = 0;
    TOptional<int32> FirstMatchFrame;
    int32 NotifiesAtMatch = 0;
}
