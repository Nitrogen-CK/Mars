// Pins a framework fact: a handle in a replicated fragment on one replicated actor (the test subject) that names an entity
// replicated under another (the spawn owner's relay actor) resolves on the client in the frame the write arrives, with no
// further rep-notify, also when the server wrote it in the frame its target finished construction. Two writes in one run:
// the first names a target that constructed a second earlier, and names it at its first notify; the second is written
// in its target's construction frame, carries a valid handle at its notify that never names the previous target, and
// names its own target by the end of that same frame.
// Not asserted, because it depends on timing: what the second write's handle named at its notify beyond "valid and not
// the previous target" (twice measured as an entity not yet findable as the target: the client's copy had not finished
// its DoConstruct), how many notifies each write took beyond one, and frame counts.
// Relied on by UMars_SmTask_WorldItem_StowIntoInitiator.DoTryGet_Refusal (Script/ECS/WorldItem/Mars_WorldItem_Hfsm.as),
// which compares FMars_Fragment_WorldItem_Net.LastRefused (a handle on a world item under the spawn owner naming a
// player's entity on its pawn) with its initiator by polling every frame, never waiting for another notify. Red means the
// framework changed how such a handle resolves on a client: re-check that refusal check (a handle that resolves only on
// a later frame or a later notify makes it miss a refusal or see it late).
// Surface: Ck.Replication.Net.AS_Replication_CrossActorHandleResolvesInTheFrameItArrives
class UCk_AutoTest_Net_Replication_CrossActorHandleResolvesInTheFrameItArrives : UCk_AutoTest_NetBase
{
    default _TimeoutSeconds = 26.0f;

    private const int32 k_PayloadFirst = 3201;
    private const int32 k_PayloadSecond = 3202;
    private const float32 k_DelayBeforeFirstWriteSeconds = 1.0f;
    private const float32 k_WatchEachWriteSeconds = 5.0f;
    private const int32 k_SlowPolls = 5000;
    // Frames the client watches the second write once it arrived (5 s at the pinned 60 fps).
    private const int32 k_WatchFrames = 300;
    // The client's whole window: past it, it asserts on what it has.
    private const int32 k_MaxFrames = 1150;

    private FCk_Handle _FirstTarget;
    private FCk_Handle _SecondTarget;

    private int32 _Frame = 0;
    private TArray<FMars_TESTONLY_Replication_WriteRecord> _Writes;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Subject = Get_SubjectEntity();
        if (ck::Is_NOT_Valid(Subject))
        { FinishFailure("subject entity not found"); return; }

        if (Subject.Has_Fragment(FMars_TESTONLY_Fragment_CrossActorRef) == false)
        { Subject.Add_Fragment(FMars_TESTONLY_Fragment_CrossActorRef(), ECk_Replication::Replicates); }

        _Writes.Add(FMars_TESTONLY_Replication_WriteRecord());
        _Writes.Add(FMars_TESTONLY_Replication_WriteRecord());

        if (utils_net::Get_HasAuthority(Subject) == false)
        {
            Subject.BindTo_OnRepNotify(FMars_TESTONLY_Fragment_CrossActorRef, FCk_DynamicFragment_OnRepNotify(this, n"OnRefNotify"));
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
        auto Pending = Spawn_Target(k_PayloadFirst);
        utils_pending_entity_script::Promise_OnConstructed(Pending, FCk_Delegate_EntityScript_Constructed(this, n"OnServerFirstConstructed"));
    }

    UFUNCTION()
    private void OnServerFirstConstructed(FCk_Handle_EntityScript InEntityScriptHandle)
    {
        _FirstTarget = FCk_Handle(InEntityScriptHandle);
        Track_ForCleanup(_FirstTarget);
        WaitSeconds(k_DelayBeforeFirstWriteSeconds, n"OnServerFirstWrite");
    }

    UFUNCTION()
    private void OnServerFirstWrite(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Write_Ref(_FirstTarget, 1);
        WaitSeconds(k_WatchEachWriteSeconds, n"OnServerSpawnSecond");
    }

    UFUNCTION()
    private void OnServerSpawnSecond(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        auto Pending = Spawn_Target(k_PayloadSecond);
        utils_pending_entity_script::Promise_OnConstructed(Pending, FCk_Delegate_EntityScript_Constructed(this, n"OnServerSecondConstructed"));
    }

    // The write lands in the second target's construction frame.
    UFUNCTION()
    private void OnServerSecondConstructed(FCk_Handle_EntityScript InEntityScriptHandle)
    {
        _SecondTarget = FCk_Handle(InEntityScriptHandle);
        Track_ForCleanup(_SecondTarget);
        Write_Ref(_SecondTarget, 2);
        WaitSeconds(k_WatchEachWriteSeconds, n"OnServerHeld");
    }

    UFUNCTION()
    private void OnServerHeld(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        FinishSuccess();
    }

    private FCk_Handle_PendingEntityScript Spawn_Target(int32 InPayload)
    {
        auto Owner = utils_mars_net::Get_ReplicatedSpawnOwner(Get_SubjectEntity());
        return utils_entity_script::Request_SpawnEntity(Owner, UMars_NetSmoke_EntityScript, UMars_NetSmoke_EntityScript::Params(InPayload));
    }

    private void Write_Ref(FCk_Handle InTarget, int32 InSerial)
    {
        auto Subject = Get_SubjectEntity();
        auto& Ref = Subject.Get_Fragment(FMars_TESTONLY_Fragment_CrossActorRef);
        Ref.Target = InTarget;
        Ref.Serial = InSerial;
        Subject.Request_MarkReplicationDirty(FMars_TESTONLY_Fragment_CrossActorRef);
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

        Record.AtFirstNotify = TOptional<EMars_TESTONLY_Replication_Seen>(Get_Seen(Serial));
    }

    // One call per frame: per write, the frame it arrived and the first frame its handle named its target.
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

            if (Record.FirstMatchFrame.IsSet() == false && Get_Seen(Serial) == EMars_TESTONLY_Replication_Seen::Match)
            {
                Record.FirstMatchFrame = TOptional<int32>(_Frame);
                Record.NotifiesAtMatch = Record.Notifies;
            }
        }

        const auto SecondWatched = _Writes[1].SeenFrame.IsSet() && _Frame - _Writes[1].SeenFrame.GetValue() >= k_WatchFrames;
        auto Result = OutResult;
        Result.Set(SecondWatched || _Frame >= k_MaxFrames);
    }

    UFUNCTION()
    private void OnClientWatched(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto End = Get_Seen(Get_Ref().Serial);
        Log(f"[MarsNet] cross-actor handle on the client: first:{Describe(0)} | inConstructionFrame:{Describe(1)} | end={End :n} frames={_Frame}");

        const auto& First = _Writes[0];
        Assert_True(First.SeenFrame.IsSet(), "the write naming a constructed target reached the client");
        Assert_True(First.Notifies >= 1, "that write arrived with a rep-notify");
        Assert_True(First.AtFirstNotify == EMars_TESTONLY_Replication_Seen::Match, "that write's handle named its target at its first notify");

        const auto& Second = _Writes[1];
        Assert_True(Second.SeenFrame.IsSet(), "the write made in its target's construction frame reached the client");
        Assert_True(Second.Notifies >= 1, "that write arrived with a rep-notify");
        Assert_True(Second.AtFirstNotify.IsSet()
            && Second.AtFirstNotify.GetValue() != EMars_TESTONLY_Replication_Seen::Invalid
            && Second.AtFirstNotify.GetValue() != EMars_TESTONLY_Replication_Seen::Stale,
            "that write's handle was valid at its first notify and did not name the previous target");
        Assert_True(Second.FirstMatchFrame.IsSet(), "that write's handle came to name its target on the client");
        if (Second.SeenFrame.IsSet() && Second.FirstMatchFrame.IsSet())
        {
            Assert_Equals_Int(Second.FirstMatchFrame.GetValue() - Second.SeenFrame.GetValue(), 0,
                "that write's handle named its target in the frame the write arrived");
            Assert_Equals_Int(Second.NotifiesAtMatch - Second.NotifiesAtSeen, 0,
                "it named its target with no further notify");
        }

        Assert_True(End == EMars_TESTONLY_Replication_Seen::Match, "the handle still names the second target at the end");
        FinishSuccess();
    }

    // notifies, what the first notify carrying the write saw, frames from arrival to the first frame naming its target,
    // and the notifies that landed in between.
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

    private FMars_TESTONLY_Fragment_CrossActorRef Get_Ref()
    {
        return Get_SubjectEntity().Get_Fragment(FMars_TESTONLY_Fragment_CrossActorRef);
    }

    // What the stored handle names right now, against this machine's copy of the target the InSerial write named.
    private EMars_TESTONLY_Replication_Seen Get_Seen(int32 InSerial)
    {
        const auto Target = Get_Ref().Target;
        if (ck::Is_NOT_Valid(Target))
        { return EMars_TESTONLY_Replication_Seen::Invalid; }

        const auto Expected = Find_Target(InSerial == 1 ? k_PayloadFirst : k_PayloadSecond);
        if (ck::IsValid(Expected) && Target == Expected)
        { return EMars_TESTONLY_Replication_Seen::Match; }

        if (InSerial == 2 && Target == Find_Target(k_PayloadFirst))
        { return EMars_TESTONLY_Replication_Seen::Stale; }

        return EMars_TESTONLY_Replication_Seen::Other;
    }

    // This machine's smoke entity whose DoConstruct received InPayload; invalid while it has not arrived.
    private FCk_Handle Find_Target(int32 InPayload)
    {
        for (auto Candidate : utils_entity_tag::ForEach_Entity(Get_SubjectEntity(), n"TAG_MarsNetSmoke"))
        {
            if (Candidate.Has_Fragment(FMars_Fragment_NetSmoke_Local) == false)
            { continue; }

            if (Candidate.Get_Fragment(FMars_Fragment_NetSmoke_Local).Payload == InPayload)
            { return Candidate; }
        }

        return FCk_Handle();
    }
}

// The replicated reference under test, composed on the subject on both machines: a handle to another replicated entity,
// and a serial that says which write it is. The test writes it on the server through Get_Fragment +
// Request_MarkReplicationDirty, which only a feature's processors may do in game code.
struct FMars_TESTONLY_Fragment_CrossActorRef
{
    UPROPERTY()
    FCk_Handle Target;

    UPROPERTY()
    int32 Serial = 0;
}

// What the replicated handle named when the client looked: nothing, its own target, the previous write's target, or
// another entity.
enum EMars_TESTONLY_Replication_Seen
{
    Invalid,
    Match,
    Stale,
    Other
}

struct FMars_TESTONLY_Replication_WriteRecord
{
    int32 Notifies = 0;
    TOptional<EMars_TESTONLY_Replication_Seen> AtFirstNotify;
    TOptional<int32> SeenFrame;
    int32 NotifiesAtSeen = 0;
    TOptional<int32> FirstMatchFrame;
    int32 NotifiesAtMatch = 0;
}
