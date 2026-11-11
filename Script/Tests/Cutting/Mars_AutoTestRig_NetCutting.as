// The cutting net tests' shared steps, on the station net rig. The server spawns a test cutting station under the replicated
// spawn owner: the base station (Authority input stance) with the Cutting kernel and a FoodBoard composed on its root and a
// test control state machine (Idle resets the hand; Operated runs the cutting station's own operator input and cut bridge),
// tagged so each machine finds its copy. The subject is the operator. Each machine records the chop signals and the board's
// cut answers its own copy raises.

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

UCLASS(Abstract)
class UMars_AutoTestRig_NetCutting : UMars_AutoTestRig_NetStation
{
    protected FCk_Handle_Cutting _Cutting;
    protected FCk_Handle_FoodBoard _Board;
    protected TArray<EMars_TESTONLY_CuttingEvent> _Events;
    protected TArray<float32> _HandAtLanding;
    protected int32 _CutsIssued = 0;
    private bool _WasFound = false;

    // Server: the test cutting station at InLocation, under the spawn owner.
    protected void Spawn_ServerCuttingStation(FVector InLocation)
    {
        auto Spec = FMars_Station_Spec();
        Spec.MinigameStateClass = UMars_TESTONLY_SmState_NetCutting_Idle;
        Spec.InputStance = EMars_Station_InputStance::Authority;

        auto Owner = utils_mars_net::Get_ReplicatedSpawnOwner(Get_SubjectEntity());
        const auto Params = FMars_TESTONLY_StationSpawnParams(FTransform(FRotator::ZeroRotator, InLocation), Spec);
        utils_entity_script::Request_SpawnEntity(Owner, UMars_TESTONLY_NetCuttingStation_EntityScript, Params);
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
    }

    UFUNCTION()
    private void OnChopLanded(FCk_Handle_Cutting InCutting)
    {
        _Events.Add(EMars_TESTONLY_CuttingEvent::Landed);
        _HandAtLanding.Add(InCutting.Get_HandLateral());
    }

    UFUNCTION()
    private void OnCutIssued(FCk_Handle_FoodBoard InBoard, FMars_FoodBoard_CutIssue InIssue)
    {
        _CutsIssued += 1;
    }
}
