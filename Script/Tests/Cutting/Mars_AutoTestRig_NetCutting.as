// The cutting net tests' shared steps, on the station net rig. The server spawns a test cutting station under the replicated
// spawn owner: the base station (Authority input stance) with the Cutting kernel and a FoodBoard composed on its root and a
// test control state machine (Idle resets the hand; Operated runs the cutting station's own operator input and cut bridge),
// tagged so each machine finds its copy. The subject is the operator. Each machine records the chop signals and the board's
// cut answers its own copy raises, with the frame of each; a client also records the rep-notifies of the ledger.

namespace constants_cutting_net_autotest
{
    const float32 k_BoardHalfWidth = 30.0f;
    // Long enough that a strike and its recover each span several frames and replication updates.
    const float32 k_ChopSeconds = 0.25f;
    const float k_ToleranceCm = 0.01;
}

// What one machine's copy of the cleaver raised, in order.
enum EMars_TESTONLY_CuttingEvent
{
    Started,
    Landed
}

class UMars_TESTONLY_SmState_NetCutting_Idle : UCk_SmState_EntityScript
{
    UFUNCTION(BlueprintOverride)
    void DoDefineState(FCk_Handle_SmState_UnderConstruction& InHandle)
    {
        auto ToOperated = AddTransition(InHandle, UMars_TESTONLY_SmState_NetCutting_Operated);
        AddCondition(ToOperated, UMars_SmCondition_StationIsOperated);

        AddTask(InHandle, UMars_SmTask_Cutting_ResetOnEnter);
    }
}

class UMars_TESTONLY_SmState_NetCutting_Operated : UCk_SmState_EntityScript
{
    UFUNCTION(BlueprintOverride)
    void DoDefineState(FCk_Handle_SmState_UnderConstruction& InHandle)
    {
        auto ToIdle = AddTransition(InHandle, UMars_TESTONLY_SmState_NetCutting_Idle);
        AddCondition(ToIdle, UMars_SmCondition_StationIsNotOperated);

        AddTask(InHandle, UMars_SmTask_Cutting_OperatorInput);
        AddTask(InHandle, UMars_SmTask_Cutting_CutBridge);
    }
}

// The test cutting station: the base station with Cutting (its lateral node on the root) and an empty FoodBoard (its pile
// node on the root), tagged on its root.
class UMars_TESTONLY_NetCuttingStation_EntityScript : UMars_TESTONLY_Station_EntityScript
{
    protected void AddVisuals(FCk_Handle_Transform& InRoot) override
    {
        auto Handle = InRoot.H();
        utils_entity_tag::Add(Handle, n"TAG_MarsTestNetCuttingStation");

        auto Spec = FMars_Cutting_Spec(constants_cutting_net_autotest::k_BoardHalfWidth, constants_cutting_net_autotest::k_ChopSeconds);
        Spec.Nodes = FMars_Cutting_Nodes(utils_scene_node::Create(InRoot, FTransform::Identity));
        utils_cutting::Add(Handle, Spec);

        auto Tuners = FMars_FoodBoard_Tuners();
        Tuners.MaxHeldPieces = 32;
        Tuners.SeparationCm = 1.5f;
        Tuners.MaxCutsPerChop = 8;
        auto PileNode = utils_scene_node::Create(InRoot, FTransform(FVector(0.0, 0.0, 90.0))).As_Transform();
        utils_foodboard::Add(Handle, FMars_FoodBoard_Spec(Tuners, PileNode));
    }
}

// A harness fixture: the test cutting station whose authority asks one chop as it composes, so its drain starts the
// chop in the spawn frame. A copy is born into one chop started and none landed; the chop clock lands it later.
class UMars_TESTONLY_NetCuttingStation_BornChopping_EntityScript : UMars_TESTONLY_NetCuttingStation_EntityScript
{
    protected void AddVisuals(FCk_Handle_Transform& InRoot) override
    {
        Super::AddVisuals(InRoot);

        auto Handle = InRoot.H();
        if (utils_net::Get_HasAuthority(Handle) == false)
        { return; }

        auto Cutting = Handle.As_Cutting();
        Cutting.Request_Chop(FMars_Request_Cutting_Chop());
    }
}

UCLASS(Abstract)
class UMars_AutoTestRig_NetCutting : UMars_AutoTestRig_NetStation
{
    protected FCk_Handle_Cutting _Cutting;
    protected FCk_Handle_FoodBoard _Board;
    protected TArray<EMars_TESTONLY_CuttingEvent> _Events;
    // In parallel with _Events: the frame counter at each.
    protected TArray<int64> _EventFrames;
    protected TArray<float32> _HandAtLanding;
    protected int32 _CutsIssued = 0;
    // The frame counter when this machine first found its copy.
    protected int64 _FoundFrame = -1;
    // The copy's InitialState as this machine read it when it found the copy.
    protected EMars_Net_InitialState _InitialAtFind = EMars_Net_InitialState::Awaited;
    // Off authority: each rep-notify of the copy's ledger, its frame counter and the ledger as it then read.
    protected TArray<int64> _NotifyFrames;
    protected TArray<FMars_Fragment_Cutting> _NotifyLedgers;
    private bool _WasFound = false;

    // Server: the test cutting station at InLocation, under the spawn owner.
    protected void Spawn_ServerCuttingStation(FVector InLocation)
    {
        Spawn_ServerCuttingStationOfClass(InLocation, UMars_TESTONLY_NetCuttingStation_EntityScript);
    }

    // Server: a station of InClass (the test cutting station or a subclass) at InLocation, under the spawn owner.
    protected void Spawn_ServerCuttingStationOfClass(FVector InLocation, TSubclassOf<UCk_EntityScript_UE> InClass)
    {
        auto Spec = FMars_Station_Spec();
        Spec.MinigameStateClass = UMars_TESTONLY_SmState_NetCutting_Idle;
        Spec.InputStance = EMars_Station_InputStance::Authority;

        auto Owner = utils_mars_net::Get_ReplicatedSpawnOwner(Get_SubjectEntity());
        const auto Params = FMars_TESTONLY_StationSpawnParams(FTransform(FRotator::ZeroRotator, InLocation), Spec);
        utils_entity_script::Request_SpawnEntity(Owner, InClass, Params);
    }

    // This machine's cutting station has composed; the first time, its signals are recorded from here (and the server
    // tracks it).
    protected bool Get_IsCuttingStationFound()
    {
        // Once found, a station the server's cleanup destroyed is never found again.
        if (_WasFound)
        { return ck::IsValid(_Cutting); }

        for (auto Candidate : utils_entity_tag::ForEach_Entity(Get_SubjectEntity(), n"TAG_MarsTestNetCuttingStation"))
        {
            auto Station = Candidate.As_Station(ECk_SanityCheck::UnChecked);
            auto Cutting = Candidate.As_Cutting(ECk_SanityCheck::UnChecked);
            auto Board = Candidate.As_FoodBoard(ECk_SanityCheck::UnChecked);
            if (ck::Is_NOT_Valid(Station) || ck::Is_NOT_Valid(Cutting) || ck::Is_NOT_Valid(Board))
            { continue; }

            _WasFound = true;
            _Station = Station;
            _Cutting = Cutting;
            _Board = Board;
            _FoundFrame = utils_time::Get_FrameCounter();
            _InitialAtFind = Get_CuttingInitialState();
            if (utils_net::Get_HasAuthority(Get_SubjectEntity()) == false)
            {
                FCk_Handle Entity = Candidate;
                Entity.BindTo_OnRepNotify(FMars_Fragment_Cutting, FCk_DynamicFragment_OnRepNotify(this, n"OnRigLedgerNotify"));
            }

            _Cutting.BindTo_OnChopStarted(FMars_Delegate_Cutting_OnChopStarted(this, n"OnChopStarted"));
            _Cutting.BindTo_OnChopLanded(FMars_Delegate_Cutting_OnChopLanded(this, n"OnChopLanded"));
            _Board.BindTo_OnCutIssued(FMars_Delegate_FoodBoard_OnCutIssued(this, n"OnCutIssued"));
            if (utils_net::Get_HasAuthority(Get_SubjectEntity()))
            { Track_ForCleanup(Candidate); }

            return true;
        }

        return false;
    }

    // The lateral node's offset Y on this machine.
    protected float32 Get_NodeHand() const
    {
        if (ck::Is_NOT_Valid(_Cutting))
        { return 0.0f; }

        auto Node = _Cutting.Get_Spec().Nodes.LateralNode;
        return float32(utils_scene_node::Get_Offset_Location(Node).Y);
    }

    protected bool Get_IsNear(float32 InA, float32 InB) const
    {
        return Math::Abs(InA - InB) <= constants_cutting_net_autotest::k_ToleranceCm;
    }

    protected FString Get_EventsText() const
    {
        auto Text = "";
        for (auto Event : _Events)
        { Text += f"{Event :n} "; }

        return Text;
    }

    // This machine's copy's level now; Awaited while there is none.
    protected EMars_Net_InitialState Get_CuttingInitialState()
    {
        if (ck::Is_NOT_Valid(_Cutting) || _Cutting.Has_Fragment(FMars_Fragment_Cutting_Local) == false)
        { return EMars_Net_InitialState::Awaited; }

        return _Cutting.Get_Fragment(FMars_Fragment_Cutting_Local).InitialState;
    }

    protected int32 Get_EventCount(EMars_TESTONLY_CuttingEvent InKind) const
    {
        auto Count = 0;
        for (const auto Event : _Events)
        {
            if (Event == InKind)
            { ++Count; }
        }

        return Count;
    }

    protected bool Get_HasFirstNotify() const
    {
        return _NotifyFrames.Num() > 0;
    }

    // The ledger the first recorded rep-notify read; the composed default while none is recorded.
    protected FMars_Fragment_Cutting Get_FirstNotifyLedger() const
    {
        if (_NotifyLedgers.Num() == 0)
        { return FMars_Fragment_Cutting(); }

        return _NotifyLedgers[0];
    }

    protected int64 Get_FirstNotifyFrame() const
    {
        if (_NotifyFrames.Num() == 0)
        { return -1; }

        return _NotifyFrames[0];
    }

    // Events recorded in InFrame.
    protected int32 Get_EventsInFrame(int64 InFrame) const
    {
        auto Count = 0;
        for (const auto Frame : _EventFrames)
        {
            if (Frame == InFrame)
            { ++Count; }
        }

        return Count;
    }

    protected FString Describe_Find()
    {
        auto Notifies = "";
        for (int32 Index = 0; Index < _NotifyFrames.Num(); ++Index)
        { Notifies += f"{_NotifyFrames[Index]}:{_NotifyLedgers[Index].ChopSerial}/{_NotifyLedgers[Index].LandSerial} "; }

        auto Events = "";
        for (int32 Index = 0; Index < _Events.Num(); ++Index)
        { Events += f"{_Events[Index] :n}@{_EventFrames[Index]} "; }

        return f"found@{_FoundFrame} initialAtFind={_InitialAtFind :n} initial={Get_CuttingInitialState() :n} notifies=[{Notifies}] events=[{Events}]";
    }

    // Exactly one start, then one landing.
    protected bool Get_IsOneChop() const
    {
        return _Events.Num() == 2 && _Events[0] == EMars_TESTONLY_CuttingEvent::Started
            && _Events[1] == EMars_TESTONLY_CuttingEvent::Landed;
    }

    UFUNCTION()
    protected void Is_CuttingStationFound(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsCuttingStationFound());
    }

    UFUNCTION()
    protected void Is_CuttingHeldBySubject(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsCuttingStationFound() && _Station.Get_IsOperatedBy(Get_SubjectEntity()));
    }

    UFUNCTION()
    protected void Is_TwoEventsRaised(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_Events.Num() >= 2);
    }

    UFUNCTION()
    private void OnChopStarted(FCk_Handle_Cutting InCutting)
    {
        _Events.Add(EMars_TESTONLY_CuttingEvent::Started);
        _EventFrames.Add(utils_time::Get_FrameCounter());
    }

    UFUNCTION()
    private void OnChopLanded(FCk_Handle_Cutting InCutting)
    {
        _Events.Add(EMars_TESTONLY_CuttingEvent::Landed);
        _EventFrames.Add(utils_time::Get_FrameCounter());
        _HandAtLanding.Add(InCutting.Get_HandLateral());
    }

    // A notify can land on a station already ending.
    UFUNCTION()
    private void OnRigLedgerNotify(FCk_Handle InHandle, FCk_DynamicFragment_RepNotifyInfo InInfo)
    {
        if (ck::Is_NOT_Valid(InHandle) || InHandle.Has_Fragment(FMars_Fragment_Cutting) == false)
        { return; }

        _NotifyFrames.Add(utils_time::Get_FrameCounter());
        _NotifyLedgers.Add(InHandle.Get_Fragment(FMars_Fragment_Cutting));
    }

    UFUNCTION()
    private void OnCutIssued(FCk_Handle_FoodBoard InBoard, FMars_FoodBoard_CutIssue InIssue)
    {
        _CutsIssued += 1;
    }
}
