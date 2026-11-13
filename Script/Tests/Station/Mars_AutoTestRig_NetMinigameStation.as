// The net rig for a real station with no feed (a minigame station): its tests' shared steps. Both machines make the subject
// an operator (the Operator feature, an InputIntents and a hint display) and sample every frame. The server waits for the
// replicated spawn owner and spawns the station a test names (a protected hook: the class, its spawn params and the tag
// each machine finds its copy by) under it, as its own context, and tracks it; it hands over once it finds its copy, then
// again after k_ComposeSeconds, so a client copy has composed before the server acts. "Seated": the server reserves the
// station for the subject, waits until it reads operated and applies a seed sample (every row it keeps, released at
// k_SeedSerial). A remote press, hold, let-go or look is one remote sample the server applies from running totals. What
// the client compares against goes out in one test-only replicated report on the subject. The server ends by holding
// while the client asserts, then destroys its station; the client ends once its copy is gone. Ensures are 0 on both.

namespace constants_minigame_station_net_autotest
{
    // The remote state the server seeds: every row released at this serial, applied before the first press.
    const int32 k_SeedSerial = 7;
    // Frames the seed has to drain before the first press.
    const int32 k_SeedFrames = 10;
}

// A real mortar station that only tags its root, so each machine finds its copy.
class UMars_TESTONLY_NetMortarStation_EntityScript : UMars_MortarStation_EntityScript
{
    protected void AddVisuals(FCk_Handle_Transform& InRoot) override
    {
        Super::AddVisuals(InRoot);
        utils_entity_tag::Add(InRoot.H(), n"TAG_MarsTestNetMortarStation");
    }
}

// Whether a client's step continuation runs as the step arrives or a settle later.
enum EMars_TESTONLY_NetMinigameArrival
{
    Settled,
    Immediate
}

// What the server does after the continuation in which it first finds its copy: wait for a client copy to compose and
// hand over again, or nothing (the test has started its own wait there).
enum EMars_TESTONLY_NetMinigameFound
{
    AwaitCompose,
    TestContinues
}

// One operator row the rig sends: its running press serial and whether it is held.
struct FMars_TESTONLY_NetMinigameRemoteRow
{
    FGameplayTag Intent;
    int32 PressSerial = 0;
    EMars_InputIntents_Hold Hold = EMars_InputIntents_Hold::Released;
}

// What one step carries besides its number.
struct FMars_TESTONLY_NetMinigameStep
{
    int32 Step = 0;
    float32 Value = 0.0f;
    float64 Seconds = 0.0;
    int32 Count = 0;

    FMars_TESTONLY_NetMinigameStep() {}

    FMars_TESTONLY_NetMinigameStep(int32 InStep)
    {
        Step = InStep;
    }
}

// Written by the server only, through Get_Fragment + Request_MarkReplicationDirty (test-only).
struct FMars_Fragment_TESTONLY_NetMinigameReport
{
    UPROPERTY()
    int32 Serial = 0;

    UPROPERTY()
    int32 Step = 0;

    UPROPERTY()
    float32 Value = 0.0f;

    UPROPERTY()
    float64 Seconds = 0.0;

    UPROPERTY()
    int32 Count = 0;
}

UCLASS(Abstract)
class UMars_AutoTestRig_NetMinigameStation : UCk_AutoTest_NetBase
{
    default _TimeoutSeconds = 25.0f;

    protected const int32 k_SlowPolls = 5000;
    // The client asserts this long after a step arrived.
    protected const float32 k_ClientSettleSeconds = 1.0f;
    // The server holds this long after its last step before it ends, so the client asserts on a live station.
    protected const float32 k_ServerOutliveSeconds = 3.0f;
    // The server's last hold, while its station's destroy replicates.
    protected const float32 k_ServerHoldSeconds = 2.0f;
    // Long enough for a client's copy of a freshly spawned station to compose.
    protected const float32 k_ComposeSeconds = 2.0f;

    // This machine's copy of the station, once found and composed.
    protected FCk_Handle_Station _Station;
    // The server's spawn of the station.
    protected FCk_Handle _StationEntity;
    protected FCk_Handle_InputIntents _Intents;
    protected FCk_Handle_ActionHintDisplay _Display;
    // The frame counter of the first frame this machine found its copy.
    protected int64 _StationFoundFrame = -1;

    private float64 _X = 0.0;
    private int32 _EnsuresAtStart = 0;
    private float64 _BeginSeconds = 0.0;
    private TArray<FMars_TESTONLY_NetMinigameRemoteRow> _RemoteRows;
    private FVector _LookTotal = FVector::ZeroVector;
    private float32 _LookSeconds = 0.0f;
    private FCk_Handle_Timer _SampleTimer;
    private int64 _LastSampleFrame = -1;
    private int32 _AwaitedStep = 0;
    private EMars_TESTONLY_NetMinigameArrival _Arrival = EMars_TESTONLY_NetMinigameArrival::Settled;
    private FName _SeatedContinuation;
    private FString _EndText;

    //----------------------------------------------------------------------------------------------------------------------
    // Hooks
    //----------------------------------------------------------------------------------------------------------------------

    // Server: spawn the station at InTransform under InOwner (the class and its spawn params are the test's).
    protected FCk_Handle_PendingEntityScript Request_SpawnStation(FCk_Handle InOwner, FTransform InTransform)
    {
        ck::EnsureIfNot(false, f"[NetMinigameStation] {GetClass().GetName()} names no station to spawn");
        return FCk_Handle_PendingEntityScript();
    }

    // The tag the station's copy carries on its root.
    protected FName Get_StationTag() const
    {
        return NAME_None;
    }

    // Whether InStation's copy has composed what the test reads.
    protected bool Get_IsStationComposed(FCk_Handle_Station InStation)
    {
        return true;
    }

    // The rows a remote sample carries.
    protected TArray<FGameplayTag> Get_RemoteIntents() const
    {
        auto Intents = TArray<FGameplayTag>();
        Intents.Add(GameplayTags::Mars_Intent_Interact_Primary);
        Intents.Add(GameplayTags::Mars_Intent_Interact_Secondary);
        Intents.Add(GameplayTags::Mars_Intent_Drop);
        return Intents;
    }

    protected FString Get_LogTag() const
    {
        return "MinigameNetTest";
    }

    // Each machine, once, as it finds its composed copy.
    protected void On_StationFound() {}

    // Server, in the continuation in which it first finds its copy.
    protected EMars_TESTONLY_NetMinigameFound On_ServerStationFound()
    {
        return EMars_TESTONLY_NetMinigameFound::AwaitCompose;
    }

    // Server, k_ComposeSeconds after it found its copy, unless On_ServerStationFound continued the test itself.
    protected void On_ServerStationReady() {}

    // Each machine, on the first sample of every frame once it has its copy, with the frame's seconds. A frame can be
    // sampled twice, before and after its tick (at one game time); the first sample is taken.
    protected void On_Sample(float32 InDeltaSeconds) {}

    // Client, as a step arrives (or a settle later).
    protected void On_ClientStep(int32 InStep) {}

    //----------------------------------------------------------------------------------------------------------------------
    // Begin
    //----------------------------------------------------------------------------------------------------------------------

    // Call first, on both machines, with the test's own X.
    protected void Begin_MinigameRig(FCk_Handle InTestEntity, float64 InX)
    {
        _X = InX;
        _EnsuresAtStart = utils_ensure::Get_EnsureCount();
        _BeginSeconds = System::GetGameTimeInSeconds();

        auto Subject = Get_SubjectEntity();
        if (Subject.Has_Fragment(FMars_Fragment_TESTONLY_NetMinigameReport) == false)
        { Subject.Add_Fragment(FMars_Fragment_TESTONLY_NetMinigameReport(), ECk_Replication::Replicates); }

        utils_operator::Add(Subject);
        _Intents = Subject.As_InputIntents(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(_Intents))
        { _Intents = utils_input_intents::Add(Subject); }

        _Display = Subject.As_ActionHintDisplay(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(_Display))
        { _Display = utils_action_hint_display::Add(Subject); }

        _Intents.Request_ClearRemote(FMars_Request_InputIntents_ClearRemote());
        _SampleTimer = utils_timer::Create_Tick(InTestEntity, FCk_Delegate_Timer(this, n"OnRigSample"));

        if (Get_IsServer())
        { WaitUntil(n"Is_RigSpawnOwnerPublished", n"OnRigSpawnOwnerPublished", k_SlowPolls); }
    }

    protected bool Get_IsServer()
    {
        return utils_net::Get_HasAuthority(Get_SubjectEntity());
    }

    protected FString Get_MachineName()
    {
        return Get_IsServer() ? "server" : "client";
    }

    protected int32 Get_EnsureDelta()
    {
        return utils_ensure::Get_EnsureCount() - _EnsuresAtStart;
    }

    protected float64 Get_TestSeconds()
    {
        return System::GetGameTimeInSeconds() - _BeginSeconds;
    }

    protected void Log_Minigame(FString InText)
    {
        const auto Machine = Get_MachineName();
        const auto TestName = GetClass().GetName();
        const auto Seconds = Get_TestSeconds();
        const auto Ensures = Get_EnsureDelta();
        const auto LogTag = Get_LogTag();
        Log(f"[{LogTag}] {TestName} {Machine}: {InText} t={Seconds} ensures={Ensures}");
    }

    protected bool Get_IsLive(FCk_Handle InEntity)
    {
        return ck::IsValid(InEntity) && utils_entity_lifetime::Get_IsPendingDestroy(InEntity, ECk_EntityLifetime_DestructionPhase::BeginDestroy) == false;
    }

    // This machine's copy of the station has composed; the first time, On_StationFound.
    protected bool Try_FindStation()
    {
        if (ck::IsValid(_Station))
        { return true; }

        for (auto Candidate : utils_entity_tag::ForEach_Entity(Get_SubjectEntity(), Get_StationTag()))
        {
            if (Get_IsLive(Candidate) == false)
            { continue; }

            auto Station = Candidate.As_Station(ECk_SanityCheck::UnChecked);
            if (ck::Is_NOT_Valid(Station) || Get_IsStationComposed(Station) == false)
            { continue; }

            _Station = Station;
            _StationFoundFrame = utils_time::Get_FrameCounter();
            On_StationFound();
            return true;
        }

        return false;
    }

    protected bool Get_IsSubjectOperating()
    {
        return ck::IsValid(_Station) && _Station.Get_IsOperatedBy(Get_SubjectEntity());
    }

    protected bool Get_IsStationFree()
    {
        return ck::IsValid(_Station) && _Station.Get_IsOperated() == false;
    }

    // This machine's text of the subject's visible row under InOwnerKey on InAction; unset while it shows none.
    protected TOptional<FString> TryGet_Row(FName InOwnerKey, UInputAction InAction)
    {
        if (ck::Is_NOT_Valid(_Display))
        { return TOptional<FString>(); }

        for (auto Row : _Display.Get_VisibleHints())
        {
            const auto Spec = Row.Get_Spec();
            if (Spec.OwnerKey == InOwnerKey && Spec.InputAction.Get() == InAction)
            { return TOptional<FString>(Spec.Text.ToString()); }
        }

        return TOptional<FString>();
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Report
    //----------------------------------------------------------------------------------------------------------------------

    protected FMars_Fragment_TESTONLY_NetMinigameReport Get_Report()
    {
        return Get_SubjectEntity().Get_Fragment(FMars_Fragment_TESTONLY_NetMinigameReport);
    }

    // Server: InStep out to the client.
    protected void Report_Step(const FMars_TESTONLY_NetMinigameStep& InStep)
    {
        auto Subject = Get_SubjectEntity();
        auto& Report = Subject.Get_Fragment(FMars_Fragment_TESTONLY_NetMinigameReport);
        Report.Serial += 1;
        Report.Step = InStep.Step;
        Report.Value = InStep.Value;
        Report.Seconds = InStep.Seconds;
        Report.Count = InStep.Count;
        Subject.Request_MarkReplicationDirty(FMars_Fragment_TESTONLY_NetMinigameReport);
        Log_Minigame(f"step {InStep.Step} value={InStep.Value} seconds={InStep.Seconds} count={InStep.Count}");
    }

    // Client: On_ClientStep(InStep) once this machine has its copy and the report's step reached InStep, as it arrives or
    // k_ClientSettleSeconds later.
    protected void Await_Step(int32 InStep, EMars_TESTONLY_NetMinigameArrival InArrival)
    {
        _AwaitedStep = InStep;
        _Arrival = InArrival;
        WaitUntil(n"Is_RigStepArrived", n"OnRigStepArrived", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_RigStepArrived(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Try_FindStation() && Get_Report().Step >= _AwaitedStep);
    }

    UFUNCTION()
    private void OnRigStepArrived(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Log_Minigame(f"step {_AwaitedStep} arrived frame={utils_time::Get_FrameCounter()}");
        if (_Arrival == EMars_TESTONLY_NetMinigameArrival::Immediate)
        {
            On_ClientStep(_AwaitedStep);
            return;
        }

        WaitSeconds(k_ClientSettleSeconds, n"OnRigStepSettled");
    }

    UFUNCTION()
    private void OnRigStepSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        On_ClientStep(_AwaitedStep);
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Server
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void Is_RigSpawnOwnerPublished(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(utils_mars_net::Get_HasReplicatedSpawnOwner(Get_SubjectEntity()));
    }

    // The station at the test's X, its own context, tracked.
    UFUNCTION()
    private void OnRigSpawnOwnerPublished(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        auto Owner = utils_mars_net::Get_ReplicatedSpawnOwner(Get_SubjectEntity());
        auto Pending = Request_SpawnStation(Owner, FTransform(FRotator::ZeroRotator, Get_StationLocation()));
        _StationEntity = Pending.Get_EntityUnderConstruction();
        _StationEntity.Request_OverrideToSelf();
        Track_ForCleanup(_StationEntity);
        WaitUntil(n"Is_RigServerStationFound", n"OnRigServerStationFound", k_SlowPolls);
    }

    protected FVector Get_StationLocation()
    {
        return FVector(_X, 0.0, 0.0);
    }

    UFUNCTION()
    private void Is_RigServerStationFound(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsLive(_StationEntity) && Try_FindStation());
    }

    UFUNCTION()
    private void OnRigServerStationFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_True(_Station == _StationEntity, "the server finds the station it spawned");
        if (On_ServerStationFound() == EMars_TESTONLY_NetMinigameFound::AwaitCompose)
        { WaitSeconds(k_ComposeSeconds, n"OnRigServerStationReady"); }
    }

    UFUNCTION()
    private void OnRigServerStationReady(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        On_ServerStationReady();
    }

    // Server: seats the subject, seeds its remote state, then InContinuation.
    protected void Seat_SubjectThen(FName InContinuation)
    {
        _Station.Request_Reserve(FMars_Request_Station_Reserve(Get_SubjectEntity()));
        Await_OperatingThenSeed(InContinuation);
    }

    // Server: once the subject operates the station (however it got there), seeds its remote state, then InContinuation.
    protected void Await_OperatingThenSeed(FName InContinuation)
    {
        _SeatedContinuation = InContinuation;
        WaitUntil(n"Is_RigSubjectOperating", n"OnRigSubjectOperating", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_RigSubjectOperating(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsSubjectOperating());
    }

    UFUNCTION()
    private void OnRigSubjectOperating(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Reset_RemoteRows();
        Apply_RemoteSample();
        WaitFrames(constants_minigame_station_net_autotest::k_SeedFrames, _SeatedContinuation);
    }

    // Server: the subject leaves the station (the station's own release, as the operator asks it).
    protected void Release_Subject()
    {
        _Station.Request_Release(FMars_Request_Station_Release(Get_SubjectEntity(), EMars_Station_ReleaseReason::OperatorRequested));
    }

    private void Reset_RemoteRows()
    {
        _RemoteRows.Empty();
        _LookTotal = FVector::ZeroVector;
        _LookSeconds = 0.0f;
        for (const auto& Intent : Get_RemoteIntents())
        {
            auto Row = FMars_TESTONLY_NetMinigameRemoteRow();
            Row.Intent = Intent;
            Row.PressSerial = constants_minigame_station_net_autotest::k_SeedSerial;
            _RemoteRows.Add(Row);
        }
    }

    // Server: one remote sample carrying the look total, its seconds and every row as it stands now.
    protected void Apply_RemoteSample()
    {
        auto Sample = FMars_InputIntents_RemoteSample();
        Sample.LookTotal = _LookTotal;
        Sample.LookSeconds = _LookSeconds;
        for (const auto& Row : _RemoteRows)
        { Sample.Intents.Add(FMars_InputIntents_RemoteIntent(Row.Intent, Row.PressSerial, Row.Hold)); }

        _Intents.Request_ApplyRemoteSample(FMars_Request_InputIntents_ApplyRemoteSample(Sample));
    }

    // Server: a remote look of InDegrees (X yaw right+, Y pitch down+) that took InSeconds on the sender, in one sample.
    protected void Look_Remote(FVector InDegrees, float32 InSeconds)
    {
        _LookTotal += InDegrees;
        _LookSeconds += InSeconds;
        Apply_RemoteSample();
    }

    // Server: InIntent goes down (one press more, held), in one sample.
    protected void Hold_Remote(FGameplayTag InIntent)
    {
        Edit_RemoteRow(InIntent, 1, EMars_InputIntents_Hold::Held);
        Apply_RemoteSample();
    }

    // Server: InIntent comes up (no press more, released), in one sample.
    protected void LetGo_Remote(FGameplayTag InIntent)
    {
        Edit_RemoteRow(InIntent, 0, EMars_InputIntents_Hold::Released);
        Apply_RemoteSample();
    }

    // Server: InIntent pressed and released between two samples (one press more, released), in one sample.
    protected void Press_Remote(FGameplayTag InIntent)
    {
        Edit_RemoteRow(InIntent, 1, EMars_InputIntents_Hold::Released);
        Apply_RemoteSample();
    }

    private void Edit_RemoteRow(FGameplayTag InIntent, int32 InPresses, EMars_InputIntents_Hold InHold)
    {
        for (int32 Index = 0; Index < _RemoteRows.Num(); ++Index)
        {
            if (_RemoteRows[Index].Intent != InIntent)
            { continue; }

            auto Row = _RemoteRows[Index];
            Row.PressSerial += InPresses;
            Row.Hold = InHold;
            _RemoteRows[Index] = Row;
            return;
        }

        ck::EnsureIfNot(false, f"[NetMinigameStation] keeps no remote row for {InIntent.ToString()}");
    }

    //----------------------------------------------------------------------------------------------------------------------
    // The sampler
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void OnRigSample(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Frame = utils_time::Get_FrameCounter();
        if (Frame == _LastSampleFrame)
        { return; }

        _LastSampleFrame = Frame;
        if (Try_FindStation())
        { On_Sample(float32(InDeltaT.Get_Seconds())); }
    }

    private void End_Sampling()
    {
        if (ck::Is_NOT_Valid(_SampleTimer))
        { return; }

        utils_timer::UnbindFrom_OnUpdate(_SampleTimer, FCk_Delegate_Timer(this, n"OnRigSample"));
        utils_entity_lifetime::Request_DestroyEntity(_SampleTimer.H());
        _SampleTimer = FCk_Handle_Timer();
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Endings
    //----------------------------------------------------------------------------------------------------------------------

    // The server's last step: it holds k_ServerOutliveSeconds while the client asserts, asserts no ensure, logs InText,
    // destroys its station and holds while that replicates.
    protected void End_MinigameServer(FString InText)
    {
        _EndText = InText;
        WaitSeconds(k_ServerOutliveSeconds, n"OnRigServerOutlived");
    }

    UFUNCTION()
    private void OnRigServerOutlived(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_Equals_Int(Get_EnsureDelta(), 0, "no ensure on the server");
        Log_Minigame(_EndText);
        End_Sampling();
        if (Get_IsLive(_StationEntity))
        { utils_entity_lifetime::Request_DestroyEntity(_StationEntity); }

        WaitSeconds(k_ServerHoldSeconds, n"OnRigServerEnded");
    }

    UFUNCTION()
    private void OnRigServerEnded(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        FinishSuccess();
    }

    // The client's last step: asserts no ensure, logs InText and waits until its copy of the station is gone.
    protected void End_MinigameClient(FString InText)
    {
        End_Sampling();
        Assert_Equals_Int(Get_EnsureDelta(), 0, "no ensure on the client");
        Log_Minigame(InText);
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
        FinishSuccess();
    }
}
