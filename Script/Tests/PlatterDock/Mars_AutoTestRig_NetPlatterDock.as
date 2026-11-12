// The PlatterDock net tests' shared steps, on the platter net rig (its carrier, its large platter on the floor at the
// test's X, its report and what "rides" means on a client). The server spawns a station under the replicated spawn owner
// 250 cm beside the platter: a test station whose two docks are requested in AddVisuals, or the real cutting station.
// Each machine finds its own copy of the station (the test station by its tag, the real one as the lifetime owner of a
// dock near the test's X) once its docks have composed, and records in order every signal either dock raises. The server
// docks and undocks the platter through the dock's own requests. One [PlatterDockNetTest] line per test per machine;
// ensures are 0 on both. The server destroys its station when it ends, and the client waits until its copy is gone.

namespace constants_platter_dock_autotest
{
    // The test station's docks, in its root's frame.
    const FVector k_InputLocal = FVector(0.0, -60.0, 72.0);
    const FVector k_OutputLocal = FVector(0.0, 60.0, 72.0);
}

enum EMars_TESTONLY_NetDockSignal
{
    Docked,
    Arrived,
    Undocked,
    DockRefused,
    UndockRefused
}

enum EMars_TESTONLY_NetDockStationKind
{
    TestStation,
    CuttingStation
}

// One signal a dock raised, as this machine recorded it.
struct FMars_TESTONLY_NetDockEvent
{
    EMars_PlatterDock_Role Role = EMars_PlatterDock_Role::Input;
    EMars_TESTONLY_NetDockSignal Signal = EMars_TESTONLY_NetDockSignal::Docked;
    EMars_PlatterDock_Refusal Refusal = EMars_PlatterDock_Refusal::Occupied;
}

// The bare test station with an Input dock that takes meat only and an Output dock, tagged on its root.
class UMars_TESTONLY_NetDockStation_EntityScript : UMars_TESTONLY_Station_EntityScript
{
    protected void AddVisuals(FCk_Handle_Transform& InRoot) override
    {
        utils_entity_tag::Add(InRoot.H(), n"TAG_MarsTestNetDockStation");

        const auto MeatOnly = FMars_PlatterDock_Policy(FGameplayTagQuery::MakeQuery_MatchTag(GameplayTags::Food_Meat), false);
        auto Setups = TArray<FMars_PlatterDock_Setup>();
        Setups.Add(Make_Setup(FMars_PlatterDock_Spec(EMars_PlatterDock_Role::Input, MeatOnly,
            FTransform(constants_platter_dock_autotest::k_InputLocal)), "input platter", n"NetDockStation_InputDockMarker"));
        Setups.Add(Make_Setup(FMars_PlatterDock_Spec(EMars_PlatterDock_Role::Output, FMars_PlatterDock_Policy(),
            FTransform(constants_platter_dock_autotest::k_OutputLocal)), "finished tray", n"NetDockStation_OutputDockMarker"));
        utils_platter_dock::Request_Docks(InRoot.H(), Setups);
    }

    private FMars_PlatterDock_Setup Make_Setup(FMars_PlatterDock_Spec InSpec, FString InName, FName InMarkerName) const
    {
        auto Setup = FMars_PlatterDock_Setup();
        Setup.Spec = InSpec;
        Setup.Spec.Prompt = utils_platter_dock::Make_PromptSpec();
        Setup.Words = FMars_PlatterDock_PromptWords(FText::FromString(InName), FText());
        Setup.MarkerName = InMarkerName;
        return Setup;
    }
}

UCLASS(Abstract)
class UMars_AutoTestRig_NetPlatterDock : UMars_AutoTestRig_NetPlatter
{
    default _TimeoutSeconds = 25.0f;

    protected const float64 k_MountToleranceCm = 0.01;
    // The server waits this long between two steps the client reads one second after each arrived.
    protected const float32 k_StepGapSeconds = 1.5f;

    protected EMars_TESTONLY_NetDockStationKind _StationKind = EMars_TESTONLY_NetDockStationKind::TestStation;

    // This machine's copy of the station and its docks, once its docks have composed.
    protected FCk_Handle _Station;
    protected FCk_Handle_PlatterDock _InputDock;
    protected FCk_Handle_PlatterDock _OutputDock;
    protected TArray<FMars_TESTONLY_NetDockEvent> _DockEvents;

    // Server: the frames between the station's spawn request and its constructed callback.
    protected int64 _SpawnFrame = -1;
    protected int64 _ConstructedFrame = -1;

    // This machine's copy of the second (small) platter, once found; the server's spawn of it.
    protected FCk_Handle_Platter _SecondPlatter;
    protected FCk_Handle _SecondPlatterEntity;

    // Client: the frame of its last Act and the frame it first saw that Act's effect.
    protected int64 _ActFrame = -1;
    protected int64 _EffectFrame = -2;

    private FCk_Handle _ServerStation;
    private FCk_Handle_PlatterDock _AwaitedDock;
    private FCk_Handle_WorldItem _AwaitedHeld;
    private FString _DockEndText;

    protected void Log_Dock(FString InText)
    {
        const auto Machine = Get_MachineName();
        const auto TestName = GetClass().GetName();
        const auto Ensures = Get_EnsureDelta();
        Log(f"[PlatterDockNetTest] {TestName} {Machine}: {InText} ensures={Ensures}");
    }

    protected FVector Get_StationLocation()
    {
        return _FloorTop + FVector(0.0, 250.0, 0.0);
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Either machine
    //----------------------------------------------------------------------------------------------------------------------

    // This machine's copy of the station near the test's X; invalid while none is found.
    protected FCk_Handle Find_Station()
    {
        if (_StationKind == EMars_TESTONLY_NetDockStationKind::TestStation)
        {
            for (auto Candidate : utils_entity_tag::ForEach_Entity(Get_SubjectEntity(), n"TAG_MarsTestNetDockStation"))
            {
                if (Get_IsLive(Candidate) && Get_IsNear(Candidate, _FloorTop))
                { return Candidate; }
            }

            return FCk_Handle();
        }

        for (auto Candidate : utils_entity_tag::ForEach_Entity(Get_SubjectEntity(), n"TAG_MarsPlatterDock"))
        {
            if (Get_IsLive(Candidate) && Candidate.Is_Transform() && Get_IsNear(Candidate, _FloorTop))
            { return utils_entity_lifetime::Get_LifetimeOwner(Candidate); }
        }

        return FCk_Handle();
    }

    // Finds this machine's station once its docks have composed, and records their signals from then on.
    protected bool Try_FindDocks()
    {
        if (ck::IsValid(_InputDock) && ck::IsValid(_OutputDock))
        { return true; }

        const auto Station = Find_Station();
        if (Get_IsLive(Station) == false || utils_platter_dock::Get_AreDocksComposed(Station) == false)
        { return false; }

        _Station = Station;
        _InputDock = utils_platter_dock::Find_OnStation(Station, EMars_PlatterDock_Role::Input);
        _OutputDock = utils_platter_dock::Find_OnStation(Station, EMars_PlatterDock_Role::Output);
        Bind_Dock(_InputDock);
        Bind_Dock(_OutputDock);
        return true;
    }

    private void Bind_Dock(FCk_Handle_PlatterDock InDock)
    {
        auto Dock = InDock;
        Dock.BindTo_OnDocked(FMars_Delegate_PlatterDock_OnDocked(this, n"OnRigDocked"));
        Dock.BindTo_OnArrived(FMars_Delegate_PlatterDock_OnArrived(this, n"OnRigArrived"));
        Dock.BindTo_OnUndocked(FMars_Delegate_PlatterDock_OnUndocked(this, n"OnRigUndocked"));
        Dock.BindTo_OnDockRefused(FMars_Delegate_PlatterDock_OnDockRefused(this, n"OnRigDockRefused"));
        Dock.BindTo_OnUndockRefused(FMars_Delegate_PlatterDock_OnUndockRefused(this, n"OnRigUndockRefused"));
    }

    // The client steps only once it has its platter and its docks.
    protected bool Get_IsStepArrived(int32 InStep) override
    {
        return Try_FindDocks() && Super::Get_IsStepArrived(InStep);
    }

    protected int32 Get_Count(EMars_PlatterDock_Role InRole, EMars_TESTONLY_NetDockSignal InSignal)
    {
        auto Count = 0;
        for (const auto& Event : _DockEvents)
        {
            if (Event.Role == InRole && Event.Signal == InSignal)
            { ++Count; }
        }

        return Count;
    }

    // How many signals InRole's dock raised, of any kind.
    protected int32 Get_SignalCount(EMars_PlatterDock_Role InRole)
    {
        auto Count = 0;
        for (const auto& Event : _DockEvents)
        {
            if (Event.Role == InRole)
            { ++Count; }
        }

        return Count;
    }

    protected FString Describe_DockEvents()
    {
        FString Text;
        for (const auto& Event : _DockEvents)
        {
            Text += f"{Event.Role :n}.{Event.Signal :n}";
            if (Event.Signal == EMars_TESTONLY_NetDockSignal::DockRefused || Event.Signal == EMars_TESTONLY_NetDockSignal::UndockRefused)
            { Text += f"({Event.Refusal :n})"; }

            Text += " ";
        }

        return f"events=[{Text}]";
    }

    protected FCk_Handle_Item Get_PlatterItem()
    {
        return Get_PlatterWorldItem().Get_Item();
    }

    // Empty when this machine's platter is Carried by InDock at AttachPoint.Mars.Dock and settled; otherwise the first fault.
    protected FString Get_DockedFault(FCk_Handle_PlatterDock InDock)
    {
        auto WorldItem = Get_PlatterWorldItem();
        if (ck::Is_NOT_Valid(WorldItem))
        { return "no platter world item"; }

        const FCk_Handle DockEntity = InDock;
        if (WorldItem.Get_Mount() != EMars_WorldItem_Mount::Carried || WorldItem.Get_Carrier() != DockEntity)
        { return f"mount {WorldItem.Get_Mount() :n} by [{WorldItem.Get_Carrier().ToString()}]"; }

        if (WorldItem.Get_MountPoint() != GameplayTags::AttachPoint_Mars_Dock)
        { return f"mount point {WorldItem.Get_MountPoint().ToString()}"; }

        if (WorldItem.Get_IsSettled() == false)
        { return "not settled"; }

        return "";
    }

    // The platter root's location in InDock's node frame, as this machine reads it.
    protected FVector Get_PlatterInDock(FCk_Handle_PlatterDock InDock)
    {
        const auto DockWorld = utils_transform::Get_EntityCurrentTransform(InDock.Get_Node());
        const auto PlatterWorld = utils_transform::Get_EntityCurrentTransform(Get_PlatterRoot());
        return DockWorld.InverseTransformPosition(PlatterWorld.GetLocation());
    }

    protected FString Get_ShownLabel()
    {
        return _Station.As_Station().Get_ShownLabel();
    }

    // The rig's first platter is the large one: a second (small) platter on the same floor is never taken for it.
    protected FCk_Handle_Platter Find_PlatterNear() override
    {
        return Find_PlatterOfCapacityNear(Get_CapacityOf(mars_items::Platter_Large()));
    }

    protected int32 Get_CapacityOf(UCk_InventoryItem_Definition InDefinition)
    {
        const UMars_ItemTrait_Platter Trait = InDefinition.Get_ItemTraitByClass(UMars_ItemTrait_Platter);
        return Trait.Platter.Capacity;
    }

    // This machine's composed platter world item of InCapacity near the test's X; invalid while none is composed.
    protected FCk_Handle_Platter Find_PlatterOfCapacityNear(int32 InCapacity)
    {
        for (auto Candidate : utils_entity_tag::ForEach_Entity(Get_SubjectEntity(), n"TAG_MarsWorldItem"))
        {
            if (Get_IsLive(Candidate) == false || Candidate.Is_Transform() == false || Candidate.Is_Platter() == false
                || Candidate.Has_Fragment(FMars_Fragment_Platter_Params) == false || Get_IsNear(Candidate, _FloorTop) == false)
            { continue; }

            if (Candidate.As_Platter().Get_Capacity() == InCapacity)
            { return Candidate.As_Platter(); }
        }

        return FCk_Handle_Platter();
    }

    // This machine's copy of the second (small) platter, once found.
    protected bool Try_FindSecondPlatter()
    {
        if (ck::IsValid(_SecondPlatter))
        { return true; }

        _SecondPlatter = Find_PlatterOfCapacityNear(Get_CapacityOf(mars_items::Platter()));
        return ck::IsValid(_SecondPlatter);
    }

    protected FCk_Handle_WorldItem Get_SecondWorldItem()
    {
        FCk_Handle Entity = _SecondPlatter;
        return Entity.As_WorldItem(ECk_SanityCheck::UnChecked);
    }

    protected FCk_Handle_Item Get_SecondPlatterItem()
    {
        return Get_SecondWorldItem().Get_Item();
    }

    // Empty when InWorldItem is Held by the subject and settled on this machine; otherwise the first fault.
    protected FString Get_HeldBySubjectFault(FCk_Handle_WorldItem InWorldItem)
    {
        if (ck::Is_NOT_Valid(InWorldItem))
        { return "no world item"; }

        if (InWorldItem.Get_Mount() != EMars_WorldItem_Mount::Held || InWorldItem.Get_Carrier() != Get_SubjectEntity())
        { return f"mount {InWorldItem.Get_Mount() :n} by [{InWorldItem.Get_Carrier().ToString()}]"; }

        if (InWorldItem.Get_IsSettled() == false)
        { return "not settled"; }

        return "";
    }

    // The item in the subject's overflow slot on this machine; invalid while it is empty.
    protected FCk_Handle_Item Get_OverflowItem()
    {
        return _Carrier.Hotbar.Get_ItemAt(_Carrier.Hotbar.Get_OverflowIndex());
    }

    protected bool Get_LedgerNamesSubject(FCk_Handle_PlatterDock InDock)
    {
        return InDock.Get_LastRefused() == Get_SubjectEntity();
    }

    // InDock's refusal ledger as this machine reads it.
    protected FString Describe_Ledger(FCk_Handle_PlatterDock InDock)
    {
        return f"ledger=[serial={InDock.Get_RefusalSerial()} last={InDock.Get_LastRefusal() :n} namesSubject={Get_LedgerNamesSubject(InDock)}]";
    }

    // Client: the subject's InAction at InDock through the dock's Act (the cue), as the task fires it at the grip.
    protected void Act(FCk_Handle_PlatterDock InDock, EMars_PlatterDock_Action InAction)
    {
        auto Dock = InDock;
        _ActFrame = utils_time::Get_FrameCounter();
        utils_platter_dock::Request_ActFor(Dock, Get_SubjectEntity(), InAction);
    }

    // The frames between the last Act and the frame the test first saw its effect.
    protected FString Describe_ActFrames()
    {
        return f"actToEffectFrames={_EffectFrame - _ActFrame}";
    }

    protected void Record_EffectFrame()
    {
        if (_EffectFrame < _ActFrame)
        { _EffectFrame = utils_time::Get_FrameCounter(); }
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Server
    //----------------------------------------------------------------------------------------------------------------------

    protected void On_ServerDocksReady() {}

    protected void On_ServerDocked() {}

    protected void On_ServerUndocked() {}

    // Server: the test station (or the real cutting station) beside the platter, under the spawn owner and tracked;
    // On_ServerDocksReady once it is constructed, this machine finds its docks composed and, for the real station, its
    // feed is composed (a replicating station composes its feed once its docks have, after its construction ended).
    protected void Spawn_ServerStation()
    {
        auto Owner = utils_mars_net::Get_ReplicatedSpawnOwner(Get_SubjectEntity());
        auto Pending = FCk_Handle_PendingEntityScript();
        if (_StationKind == EMars_TESTONLY_NetDockStationKind::TestStation)
        {
            const auto Params = FMars_TESTONLY_StationSpawnParams(FTransform(Get_StationLocation()), FMars_Station_Spec());
            Pending = utils_entity_script::Request_SpawnEntity(Owner, UMars_TESTONLY_NetDockStation_EntityScript, Params);
        }
        else
        {
            auto Helper = Cast<UMars_AutoTestHelper_HeatStation>(NewObject(this, UMars_AutoTestHelper_HeatStation));
            Pending = Helper.Spawn_Cutting(Owner, Get_StationLocation());
        }

        _SpawnFrame = utils_time::Get_FrameCounter();
        _ServerStation = Pending.Get_EntityUnderConstruction();
        Track_ForCleanup(_ServerStation);
        utils_pending_entity_script::Promise_OnConstructed(Pending, FCk_Delegate_EntityScript_Constructed(this, n"OnRigStationConstructed"));
        WaitUntil(n"Is_RigServerDocksReady", n"OnRigServerDocksReady", k_SlowPolls);
    }

    UFUNCTION()
    private void OnRigStationConstructed(FCk_Handle_EntityScript InEntityScriptHandle)
    {
        _ConstructedFrame = utils_time::Get_FrameCounter();
    }

    UFUNCTION()
    private void Is_RigServerDocksReady(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        const auto IsFed = _StationKind == EMars_TESTONLY_NetDockStationKind::TestStation || (ck::IsValid(_ServerStation) && _ServerStation.Is_CookingFeed());
        Result.Set(_ConstructedFrame >= 0 && IsFed && Try_FindDocks());
    }

    UFUNCTION()
    private void OnRigServerDocksReady(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_True(_Station == _ServerStation, "the server finds the station it spawned");
        On_ServerDocksReady();
    }

    protected FString Describe_ConstructFrames()
    {
        return f"spawnToConstructedFrames={_ConstructedFrame - _SpawnFrame}";
    }

    // Server: the platter's item onto InDock; On_ServerDocked once the dock reports it arrived.
    protected void Dock_Platter(FCk_Handle_PlatterDock InDock)
    {
        _AwaitedDock = InDock;
        _AwaitedDock.Request_Dock(FMars_Request_PlatterDock_Dock(Get_PlatterItem()));
        WaitUntil(n"Is_RigPlatterArrived", n"OnRigPlatterArrived", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_RigPlatterArrived(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_AwaitedDock.Get_HasArrived());
    }

    UFUNCTION()
    private void OnRigPlatterArrived(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        On_ServerDocked();
    }

    // Server: InDock's undock of the platter's item into the subject's stow target.
    protected void Request_UndockToSubject(FCk_Handle_PlatterDock InDock)
    {
        auto Item = Get_PlatterItem();
        auto Target = _Carrier.Hotbar.TryGet_StowTarget(Item);
        Assert_True(ck::IsValid(Target), "the subject has a stow target for the platter");
        auto Dock = InDock;
        Dock.Request_Undock(FMars_Request_PlatterDock_Undock(Item, Target));
    }

    // Server: InDock's undock to the subject; On_ServerUndocked once the platter is Held and settled.
    protected void Undock_ToSubject(FCk_Handle_PlatterDock InDock)
    {
        Request_UndockToSubject(InDock);
        Await_Undocked();
    }

    protected void Await_Undocked()
    {
        WaitUntil(n"Is_RigPlatterHeldAgain", n"OnRigPlatterHeldAgain", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_RigPlatterHeldAgain(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto WorldItem = Get_PlatterWorldItem();
        auto Result = OutResult;
        Result.Set(ck::IsValid(WorldItem) && WorldItem.Get_Mount() == EMars_WorldItem_Mount::Held && WorldItem.Get_IsSettled());
    }

    UFUNCTION()
    private void OnRigPlatterHeldAgain(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        On_ServerUndocked();
    }

    protected void On_ServerSecondPlatterReady() {}

    protected void On_ServerHeld() {}

    // Server: the second (small) platter on the same floor, 150 cm from the first in X, under the spawn owner and tracked;
    // On_ServerSecondPlatterReady once this machine finds it.
    protected void Spawn_SecondPlatter()
    {
        auto Owner = utils_mars_net::Get_ReplicatedSpawnOwner(Get_SubjectEntity());
        const auto Root = FTransform(FRotator::ZeroRotator,
            _FloorTop + FVector(k_BesideCm, 0.0, constants_platter::k_FloorAboveBase + 0.5));
        _SecondPlatterEntity = utils_platter::Request_SpawnWorld(Owner, FMars_Platter_SpawnSpec(Root, mars_items::Platter()));
        Track_ForCleanup(_SecondPlatterEntity);
        WaitUntil(n"Is_RigSecondPlatterBuilt", n"OnRigSecondPlatterBuilt", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_RigSecondPlatterBuilt(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsLive(_SecondPlatterEntity) && _SecondPlatterEntity.Is_Platter()
            && _SecondPlatterEntity.Has_Fragment(FMars_Feature_WorldItem) && Try_FindSecondPlatter());
    }

    UFUNCTION()
    private void OnRigSecondPlatterBuilt(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_True(_SecondPlatter == _SecondPlatterEntity, "the server finds the second platter it spawned");
        On_ServerSecondPlatterReady();
    }

    // Server: the subject holds InWorldItem's platter (its item into the subject's stow target, the kernel path a pickup
    // takes); On_ServerHeld once it is Held by the subject and settled.
    protected void Hold_Platter(FCk_Handle_WorldItem InWorldItem)
    {
        Assert_True(Get_IsCarrierReady(_Carrier), "the server's carrier is ready");
        _AwaitedHeld = InWorldItem;
        Stow(InWorldItem);
        WaitUntil(n"Is_RigHeldBySubject", n"OnRigHeldBySubject", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_RigHeldBySubject(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_HeldBySubjectFault(_AwaitedHeld).IsEmpty());
    }

    UFUNCTION()
    private void OnRigHeldBySubject(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        On_ServerHeld();
    }

    // Server: On_ServerDocked once InDock reports its platter arrived, whoever docked it.
    protected void Await_Arrived(FCk_Handle_PlatterDock InDock)
    {
        _AwaitedDock = InDock;
        WaitUntil(n"Is_RigPlatterArrived", n"OnRigPlatterArrived", k_SlowPolls);
    }

    // Server: InItem onto InDock; On_ServerDocked once the dock reports it arrived.
    protected void Dock_Item(FCk_Handle_PlatterDock InDock, FCk_Handle_Item InItem)
    {
        auto Dock = InDock;
        Dock.Request_Dock(FMars_Request_PlatterDock_Dock(InItem));
        Await_Arrived(InDock);
    }

    // Server: step InStep with the rides as Publish_Rides writes them and InLocation.
    protected void Publish_RidesAndLocation(int32 InStep, FVector InLocation)
    {
        auto Report = Get_PlatterReport();
        Report.Step = InStep;
        Report.Location = InLocation;
        const auto Held = _Platter.Get_Held();
        Report.Count = Math::Min(Held.Num(), k_SlotCount);
        for (int32 Index = 0; Index < Report.Count; ++Index)
        { Set_Slot(Report, Index, Make_Slot(Held[Index], Get_Offset(Held[Index]))); }

        Write_PlatterReport(Report);
    }

    // The server's last step: it holds k_ServerOutliveSeconds while the client asserts, asserts no ensure, logs InText,
    // destroys its station and ends clean.
    protected void End_DockServer(FString InText)
    {
        _DockEndText = InText;
        WaitSeconds(k_ServerOutliveSeconds, n"OnRigDockServerOutlived");
    }

    UFUNCTION()
    private void OnRigDockServerOutlived(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_Equals_Int(Get_EnsureDelta(), 0, "no ensure on the server");
        Log_Dock(_DockEndText);
        if (Get_IsLive(_ServerStation))
        { utils_entity_lifetime::Request_DestroyEntity(_ServerStation); }

        End_Server();
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Client
    //----------------------------------------------------------------------------------------------------------------------

    // The client's last step: asserts no ensure, logs InText and waits until its station is gone and its X is clean.
    protected void End_DockClient(FString InText)
    {
        End_Sampling();
        Assert_Equals_Int(Get_EnsureDelta(), 0, "no ensure on the client");
        Log_Dock(InText);
        WaitUntil(n"Is_RigClientStationGone", n"OnRigClientStationGone", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_RigClientStationGone(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsLive(_Station) == false);
    }

    UFUNCTION()
    private void OnRigClientStationGone(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        End_Client();
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Handlers
    //----------------------------------------------------------------------------------------------------------------------

    private void Record(FCk_Handle_PlatterDock InDock, EMars_TESTONLY_NetDockSignal InSignal, EMars_PlatterDock_Refusal InRefusal)
    {
        auto Event = FMars_TESTONLY_NetDockEvent();
        Event.Role = InDock.Get_Role();
        Event.Signal = InSignal;
        Event.Refusal = InRefusal;
        _DockEvents.Add(Event);
    }

    UFUNCTION()
    private void OnRigDocked(FCk_Handle_PlatterDock InDock, FCk_Handle_Platter InPlatter)
    {
        Record(InDock, EMars_TESTONLY_NetDockSignal::Docked, EMars_PlatterDock_Refusal::Occupied);
    }

    UFUNCTION()
    private void OnRigArrived(FCk_Handle_PlatterDock InDock, FCk_Handle_Platter InPlatter)
    {
        Record(InDock, EMars_TESTONLY_NetDockSignal::Arrived, EMars_PlatterDock_Refusal::Occupied);
    }

    UFUNCTION()
    private void OnRigUndocked(FCk_Handle_PlatterDock InDock, FCk_Handle_Platter InPlatter)
    {
        Record(InDock, EMars_TESTONLY_NetDockSignal::Undocked, EMars_PlatterDock_Refusal::Occupied);
    }

    UFUNCTION()
    private void OnRigDockRefused(FCk_Handle_PlatterDock InDock, FCk_Handle_Item InItem, EMars_PlatterDock_Refusal InRefusal)
    {
        Record(InDock, EMars_TESTONLY_NetDockSignal::DockRefused, InRefusal);
    }

    UFUNCTION()
    private void OnRigUndockRefused(FCk_Handle_PlatterDock InDock, FCk_Handle_Item InItem, EMars_PlatterDock_Refusal InRefusal)
    {
        Record(InDock, EMars_TESTONLY_NetDockSignal::UndockRefused, InRefusal);
    }
}
