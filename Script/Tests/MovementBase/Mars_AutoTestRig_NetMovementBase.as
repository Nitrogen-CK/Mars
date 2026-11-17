// What the host's pawn does on the course in a row whose owner is the host.
enum EMars_TESTONLY_MovementBaseNet_HostCourse
{
    // Climbs to the top and stands on the platform.
    ClimbToTheTop,
    // Climbs to the top, then walks toward the platform's centre for a moment.
    ClimbToTheTopAndWalk,
    // Climbs until its feet are k_MbJumpFeet above the floor, jumps off and lands on the floor.
    JumpOffAtHeight
}

// What the client's own pawn does in a row whose owner is the client.
enum EMars_TESTONLY_MovementBaseNet_ClientCourse
{
    // Stands still on the platform's top.
    StandOnThePlatform,
    // Walks along +X on the platform's top for a moment.
    WalkOnThePlatform,
    // Jumps on the platform's top and lands on it again.
    JumpOnThePlatform,
    // Stands on the platform's top until the host moves the pawn onto the pad.
    MovedOntoThePad,
    // Stands still on the rig's floor (an engine cube).
    StandOnTheFloor
}

// Whose controller moves the pawn in a row.
enum EMars_TESTONLY_MovementBaseNet_Owner
{
    Host,
    Client
}

// A movement component's counts since a row's window opened (FMars_CharacterMovement_NetCounts' fields, read-only in
// script); LargestClientError is the largest the component ever read.
struct FMars_TESTONLY_MovementBaseNet_WindowCounts
{
    UPROPERTY()
    int32 ClientMovesReceived = 0;

    UPROPERTY()
    int32 ClientMovesWithBase = 0;

    UPROPERTY()
    int32 CorrectionsMade = 0;

    UPROPERTY()
    float32 LargestClientError = 0.0f;

    UPROPERTY()
    int32 CorrectionsReceived = 0;

    UPROPERTY()
    int32 CorrectionsDropped = 0;
}

// Samples of a copy counted by how its machine sees the pawn's base.
struct FMars_TESTONLY_MovementBaseNet_NetBases
{
    UPROPERTY()
    int32 None = 0;

    UPROPERTY()
    int32 Crossing = 0;

    UPROPERTY()
    int32 PerMachine = 0;

    UPROPERTY()
    int32 Unresolved = 0;
}

// The movement-base net tests' steps, on the climber course: what a copy of a pawn does while the pawn stands on a
// surface each machine built for itself. In a host-owned row the host's own controller possesses the pawn and moves it
// over the course; the client samples its copy until it settled (one second of course clock with its place still, once
// the row's course reached its end on the copy) and asserts over that second. Each machine logs one line per row.
UCLASS(Abstract)
class UMars_AutoTestRig_NetMovementBase : UMars_AutoTestRig_NetClimber
{
    default _TimeoutSeconds = 30.0f;

    // The jump dismount's height.
    protected const float64 k_MbJumpFeet = 150.0;
    // A copy's place that moved less than this between two samples is still.
    protected const float64 k_MbStillEpsilonCm = 0.5;
    // The host walks this long, in course seconds.
    protected const float32 k_MbWalkSeconds = 0.3f;
    // The copy's walk counts as seen once it is this far along +X past the exit.
    protected const float64 k_MbWalkSeenCm = 25.0;
    // The server holds this long after its own end before the controllers go back, so the client has asserted.
    protected const float32 k_MbServerWatchSeconds = 3.0f;

    protected FString _MbRow;
    protected EMars_TESTONLY_MovementBaseNet_HostCourse _MbCourse = EMars_TESTONLY_MovementBaseNet_HostCourse::ClimbToTheTop;
    // Where the copy's settled second starts in the samples; -1 before.
    protected int32 _MbSettleStartIndex = -1;
    // Server: the pawn's X relative to the base when the walk started.
    protected float64 _MbWalkStartX = 0.0;
    // The frame counter when the jump was asked for, and when the copy's feet first passed k_MbJumpFeet; -1 before.
    protected int32 _MbJumpFrame = -1;
    protected int32 _MbPassedJumpFeetFrame = -1;

    // A client-owned row's pad: a second mesh part beside the platform, its top at the platform's height.
    protected const FVector k_MbPadOffset = FVector(350.0, 1200.0, 0.0);
    // The platform's centre, relative to the base: a client-owned row's start on the platform.
    protected const FVector k_MbPlatformCentre = FVector(350.0, 0.0, 0.0);
    // The client releases its jump after this long, in course seconds.
    protected const float32 k_MbJumpReleaseSeconds = 0.2f;
    // A jump counts once the feet are this far above the surface they left.
    protected const float64 k_MbJumpRiseCm = 20.0;
    // The client stands this long after its first settle: the settled second and two more.
    protected const float32 k_MbClientStandSeconds = 3.0f;

    protected EMars_TESTONLY_MovementBaseNet_Owner _MbOwner = EMars_TESTONLY_MovementBaseNet_Owner::Host;
    protected EMars_TESTONLY_MovementBaseNet_ClientCourse _MbClientCourse = EMars_TESTONLY_MovementBaseNet_ClientCourse::StandOnThePlatform;
    // A client-owned row's window: the movement component's counts and the sample count when it opened; -1 before.
    protected FMars_CharacterMovement_NetCounts _MbWindowCounts;
    protected int32 _MbWindowStartIndex = -1;
    // Server: the frame the host moved the pawn onto the pad. Client: the frame its pawn first stood on the pad and
    // the course seconds then. -1 before.
    protected int32 _MbPadMoveFrame = -1;
    protected int32 _MbOnPadFrame = -1;
    protected float32 _MbOnPadSeconds = -1.0f;
    // Client: the frame the jump was released; -1 before.
    protected int32 _MbJumpReleaseFrame = -1;

    private bool _MbIsReadyToSettle = false;
    private FVector _MbStillPlace = FVector::ZeroVector;
    private float32 _MbStillSeconds = 0.0f;
    private EMars_TESTONLY_ClimberNet_Platform _MbPlatform = EMars_TESTONLY_ClimberNet_Platform::EngineCube;
    private FCk_Handle _MbPadEntity;
    private FCk_Handle_UnrealComponent _MbPadPart;

    // A host-owned row: the server spawns the pawn and the viewer, the host's controller moves the pawn over InCourse;
    // the client waits for its copy and samples it.
    protected void Begin_HostOwnedRow(FString InRow, FVector InBase, EMars_TESTONLY_MovementBaseNet_HostCourse InCourse)
    {
        _MbRow = InRow;
        _MbCourse = InCourse;
        Begin_Course(InBase);

        if (Get_IsServer() == false)
        {
            WaitUntil(n"Is_PawnComposed", n"OnMbComposed", k_SlowPolls);
            return;
        }

        Spawn_ServerPawn();
        Spawn_ServerViewer();
        WaitUntil(n"Is_ServerReadyWithViewer", n"OnMbComposed", k_SlowPolls);
    }

    // A client-owned row: the server spawns the pawn at the start (the platform's centre top, or the base on the floor
    // course) and hands it to the remote controller; the client moves its own pawn over InCourse while each machine
    // samples its copy. MovedOntoThePad: the host moves the pawn onto the pad a while after the client took it.
    protected void Begin_ClientOwnedRow(FString InRow, FVector InBase, EMars_TESTONLY_MovementBaseNet_ClientCourse InCourse)
    {
        _MbRow = InRow;
        _MbOwner = EMars_TESTONLY_MovementBaseNet_Owner::Client;
        _MbClientCourse = InCourse;
        _MbPlatform = InCourse == EMars_TESTONLY_MovementBaseNet_ClientCourse::StandOnTheFloor
            ? EMars_TESTONLY_ClimberNet_Platform::EngineCube
            : EMars_TESTONLY_ClimberNet_Platform::MeshPart;
        Begin_Course(InBase);
        if (InCourse == EMars_TESTONLY_MovementBaseNet_ClientCourse::MovedOntoThePad)
        { Spawn_MbPad(); }

        if (Get_IsServer() == false)
        {
            WaitUntil(n"Is_MbClientOwnedCopyReady", n"OnMbClientOwnedCopyReady", k_SlowPolls);
            return;
        }

        Spawn_ServerPawn();
        if (ck::Is_NOT_Valid(_Pawn))
        { return; }

        // No controller yet, so no move is sent from the spawn place.
        if (InCourse != EMars_TESTONLY_MovementBaseNet_ClientCourse::StandOnTheFloor)
        { Request_MbPlacePawnOn(Get_MbStart()); }

        WaitUntil(n"Is_MbClientOwnedServerReady", n"OnMbClientOwnedServerReady", k_SlowPolls);
    }

    // The row's checks on each machine, once its course ended there.
    protected void Assert_ServerRow() {}
    protected void Assert_ClientRow() {}

    protected EMars_TESTONLY_ClimberNet_Platform Get_PlatformKind() const override
    {
        return _MbPlatform;
    }

    // The climber rig's mesh-part box under this machine's transient entity, beside the platform: it does not
    // replicate, so each machine builds its own.
    private void Spawn_MbPad()
    {
        _MbPadEntity = utils_entity_lifetime::Request_CreateEntity(utils_net_spawn_test::Get_TransientEntity(Get_SubjectEntity()));
        auto Root = utils_transform::Add(_MbPadEntity, FTransform(FRotator::ZeroRotator, _Base + k_MbPadOffset),
            ECk_Replication::DoesNotReplicate);
        _MbPadPart = Root.Add_MeshPart(this, FMars_MeshPart(
            FTransform(FRotator::ZeroRotator, FVector(0.0, 0.0, 150.0), FVector(4.0, 4.0, 3.0)),
            engine::load::Cube(), nullptr, collision::profile::BlockAll, n"TestPad"));
    }

    // The pad's component was created, or the row has no pad.
    protected bool Get_IsMbPadReady()
    {
        if (_MbClientCourse != EMars_TESTONLY_MovementBaseNet_ClientCourse::MovedOntoThePad)
        { return true; }

        return ck::IsValid(_MbPadPart) && ck::IsValid(utils_unreal_component::Get_Component(_MbPadPart));
    }

    // Where the client-owned row's pawn starts, its feet's place.
    protected FVector Get_MbStart()
    {
        if (_MbClientCourse == EMars_TESTONLY_MovementBaseNet_ClientCourse::StandOnTheFloor)
        { return _Base; }

        return _Base + k_MbPlatformCentre + FVector(0.0, 0.0, k_PlatformHeight);
    }

    // Server: teleports the pawn so its feet stand just above InFeet.
    private void Request_MbPlacePawnOn(FVector InFeet)
    {
        const auto WorldContext = FAngelscriptGameThreadScopeWorldContext(Get_TestWorld());
        const auto HalfHeight = float64(_Pawn.CapsuleComponent.GetScaledCapsuleHalfHeight());
        FHitResult Hit;
        _Pawn.SetActorLocation(InFeet + FVector(0.0, 0.0, HalfHeight + 2.0), false, Hit, true);
    }

    protected void TearDown_Course() override
    {
        if (ck::IsValid(_MbPadEntity))
        { utils_entity_lifetime::Request_DestroyEntity(_MbPadEntity); }

        _MbPadEntity = FCk_Handle();
        _MbPadPart = FCk_Handle_UnrealComponent();
        Super::TearDown_Course();
    }

    //------------------------------------------------------------------------------------------------------------------
    // Reads
    //------------------------------------------------------------------------------------------------------------------

    protected FMars_TESTONLY_MovementBaseNet_NetBases Get_NetBases()
    {
        auto Counts = FMars_TESTONLY_MovementBaseNet_NetBases();
        const auto From = Math::Max(Get_ClimbStartIndex(), 0);
        for (int32 Index = From; Index < _CourseSamples.Num(); ++Index)
        {
            const auto NetBase = _CourseSamples[Index].NetBase;
            if (NetBase == EMars_Character_NetBase::None)
            { Counts.None += 1; }
            else if (NetBase == EMars_Character_NetBase::Crossing)
            { Counts.Crossing += 1; }
            else if (NetBase == EMars_Character_NetBase::PerMachine)
            { Counts.PerMachine += 1; }
            else
            { Counts.Unresolved += 1; }
        }

        return Counts;
    }

    // The largest distance in the plane between two consecutive samples from InFrom.
    protected float64 Get_LargestPlanarStep(int32 InFrom)
    {
        auto Largest = 0.0;
        for (int32 Index = Math::Max(InFrom, 0) + 1; Index < _CourseSamples.Num(); ++Index)
        {
            const auto& Previous = _CourseSamples[Index - 1];
            const auto& Sample = _CourseSamples[Index];
            const auto DX = Sample.X - Previous.X;
            const auto DY = Sample.Y - Previous.Y;
            Largest = Math::Max(Largest, Math::Sqrt(DX * DX + DY * DY));
        }

        return Largest;
    }

    // The first sample from the climb's start that reads MOVE_Walking; -1 without one.
    protected int32 Get_FirstWalkingIndexAfterClimb()
    {
        const auto From = Get_ClimbStartIndex();
        if (From < 0)
        { return -1; }

        for (int32 Index = From; Index < _CourseSamples.Num(); ++Index)
        {
            if (_CourseSamples[Index].Mode == EMovementMode::MOVE_Walking)
            { return Index; }
        }

        return -1;
    }

    // The first sample at or after InFrame; the sample count without one.
    protected int32 Get_IndexAtFrame(int32 InFrame)
    {
        for (int32 Index = 0; Index < _CourseSamples.Num(); ++Index)
        {
            if (_CourseSamples[Index].Frame >= InFrame)
            { return Index; }
        }

        return _CourseSamples.Num();
    }

    // Samples of the settled second that read another mode than InMode or another base than InNetBase.
    protected int32 Get_SettledSamplesNotReading(EMovementMode InMode, EMars_Character_NetBase InNetBase)
    {
        if (_MbSettleStartIndex < 0)
        { return -1; }

        auto Count = 0;
        for (int32 Index = _MbSettleStartIndex; Index < _CourseSamples.Num(); ++Index)
        {
            const auto& Sample = _CourseSamples[Index];
            if (Sample.Mode != InMode || Sample.NetBase != InNetBase)
            { Count += 1; }
        }

        return Count;
    }

    protected bool Get_HasSettledSampleWithABase()
    {
        if (_MbSettleStartIndex < 0)
        { return false; }

        for (int32 Index = _MbSettleStartIndex; Index < _CourseSamples.Num(); ++Index)
        {
            if (_CourseSamples[Index].HasMovementBase)
            { return true; }
        }

        return false;
    }

    protected int32 Get_SettledSampleCount()
    {
        return _MbSettleStartIndex < 0 ? 0 : _CourseSamples.Num() - _MbSettleStartIndex;
    }

    // A sample on the platform's top, inside its edges, in MOVE_Walking.
    protected bool Get_IsSampleOnPlatformTop(const FMars_TESTONLY_ClimberNet_Sample& InSample)
    {
        return Math::Abs(InSample.FeetZ - k_PlatformHeight) <= k_StandToleranceCm
            && InSample.X >= 180.0 && InSample.X <= 520.0 && Math::Abs(InSample.Y) <= 170.0
            && InSample.Mode == EMovementMode::MOVE_Walking;
    }

    protected bool Get_IsOnPlatformTop()
    {
        if (ck::Is_NOT_Valid(_Pawn))
        { return false; }

        const auto Offset = _Pawn.GetActorLocation() - _Base;
        return Math::Abs(Get_FeetAboveFloor() - k_PlatformHeight) <= k_StandToleranceCm
            && Offset.X >= 180.0 && Offset.X <= 520.0 && Math::Abs(Offset.Y) <= 170.0
            && _Pawn.CharacterMovement.MovementMode == EMovementMode::MOVE_Walking;
    }

    protected bool Get_IsOnPad()
    {
        if (ck::Is_NOT_Valid(_Pawn))
        { return false; }

        const auto Offset = _Pawn.GetActorLocation() - _Base;
        const auto DX = Offset.X - k_MbPadOffset.X;
        const auto DY = Offset.Y - k_MbPadOffset.Y;
        return Math::Abs(Get_FeetAboveFloor() - k_PlatformHeight) <= k_StandToleranceCm
            && Math::Sqrt(DX * DX + DY * DY) <= k_ExitToleranceCm
            && _Pawn.CharacterMovement.MovementMode == EMovementMode::MOVE_Walking;
    }

    // The movement component's counts since the window opened.
    protected FMars_TESTONLY_MovementBaseNet_WindowCounts Get_MbWindowCounts()
    {
        auto Counts = FMars_TESTONLY_MovementBaseNet_WindowCounts();
        const auto Movement = Get_CourseMovement();
        if (ck::Is_NOT_Valid(Movement))
        { return Counts; }

        const auto Now = Movement.Get_NetCounts();
        Counts.ClientMovesReceived = Now.ClientMovesReceived - _MbWindowCounts.ClientMovesReceived;
        Counts.ClientMovesWithBase = Now.ClientMovesWithBase - _MbWindowCounts.ClientMovesWithBase;
        Counts.CorrectionsMade = Now.CorrectionsMade - _MbWindowCounts.CorrectionsMade;
        Counts.LargestClientError = Now.LargestClientError;
        Counts.CorrectionsReceived = Now.CorrectionsReceived - _MbWindowCounts.CorrectionsReceived;
        Counts.CorrectionsDropped = Now.CorrectionsDropped - _MbWindowCounts.CorrectionsDropped;
        return Counts;
    }

    // Samples from the window's start that are not on the platform's top; -1 before the window.
    protected int32 Get_MbWindowSamplesOffPlatformTop()
    {
        if (_MbWindowStartIndex < 0)
        { return -1; }

        auto Count = 0;
        for (int32 Index = _MbWindowStartIndex; Index < _CourseSamples.Num(); ++Index)
        {
            if (Get_IsSampleOnPlatformTop(_CourseSamples[Index]) == false)
            { Count += 1; }
        }

        return Count;
    }

    // Whether a sample from the window's start read MOVE_Falling with the feet k_MbJumpRiseCm over the platform.
    protected bool Get_HasMbJumpSample()
    {
        for (int32 Index = Math::Max(_MbWindowStartIndex, 0); Index < _CourseSamples.Num(); ++Index)
        {
            const auto& Sample = _CourseSamples[Index];
            if (Sample.Mode == EMovementMode::MOVE_Falling && Sample.FeetZ >= k_PlatformHeight + k_MbJumpRiseCm)
            { return true; }
        }

        return false;
    }

    // The largest distance in the plane of a settled sample from the first settled one; -1 before the settle.
    protected float64 Get_MbSettledPlanarDrift()
    {
        if (_MbSettleStartIndex < 0)
        { return -1.0; }

        const auto& First = _CourseSamples[_MbSettleStartIndex];
        auto Largest = 0.0;
        for (int32 Index = _MbSettleStartIndex; Index < _CourseSamples.Num(); ++Index)
        {
            const auto DX = _CourseSamples[Index].X - First.X;
            const auto DY = _CourseSamples[Index].Y - First.Y;
            Largest = Math::Max(Largest, Math::Sqrt(DX * DX + DY * DY));
        }

        return Largest;
    }

    // The largest distance of a sample's feet from InHeight from InFrom on; -1 without a sample.
    protected float64 Get_MbLargestOffHeight(int32 InFrom, float64 InHeight)
    {
        if (InFrom < 0 || InFrom >= _CourseSamples.Num())
        { return -1.0; }

        auto Largest = 0.0;
        for (int32 Index = InFrom; Index < _CourseSamples.Num(); ++Index)
        { Largest = Math::Max(Largest, Math::Abs(_CourseSamples[Index].FeetZ - InHeight)); }

        return Largest;
    }

    // Samples from InFrom on that read another mode than MOVE_Walking.
    protected int32 Get_MbSamplesNotWalking(int32 InFrom)
    {
        auto Count = 0;
        for (int32 Index = Math::Max(InFrom, 0); Index < _CourseSamples.Num(); ++Index)
        {
            if (_CourseSamples[Index].Mode != EMovementMode::MOVE_Walking)
            { Count += 1; }
        }

        return Count;
    }

    protected FString Describe_MbWindow()
    {
        const auto Counts = Get_MbWindowCounts();
        return f"window=[from {_MbWindowStartIndex} moves {Counts.ClientMovesReceived} withBase {Counts.ClientMovesWithBase} "
            + f"corrected {Counts.CorrectionsMade} largestError {Counts.LargestClientError :.1} "
            + f"received {Counts.CorrectionsReceived} dropped {Counts.CorrectionsDropped}] "
            + f"pad=[move {_MbPadMoveFrame} reached {_MbOnPadFrame} at {_MbOnPadSeconds :.2}] jumpRelease={_MbJumpReleaseFrame} "
            + f"drift={Get_MbSettledPlanarDrift() :.2}";
    }

    protected FString Describe_Samples(int32 InFrom, int32 InCount)
    {
        auto Text = "";
        const auto From = Math::Max(InFrom, 0);
        const auto To = Math::Min(From + InCount, _CourseSamples.Num());
        for (int32 Index = From; Index < To; ++Index)
        {
            const auto& Sample = _CourseSamples[Index];
            const auto Mode = Sample.Mode == EMovementMode::MOVE_Flying ? "F"
                : (Sample.Mode == EMovementMode::MOVE_Falling ? "D" : (Sample.Mode == EMovementMode::MOVE_Walking ? "W" : "O"));
            const auto NetBase = Sample.NetBase == EMars_Character_NetBase::None ? "n"
                : (Sample.NetBase == EMars_Character_NetBase::Crossing ? "c"
                : (Sample.NetBase == EMars_Character_NetBase::PerMachine ? "p" : "u"));
            const auto HasBase = Sample.HasMovementBase ? "b" : "";
            Text += f"{Sample.Frame}:({Sample.X :.1},{Sample.FeetZ :.1}){Mode}{NetBase}{HasBase} ";
        }

        return Text;
    }

    // The row's one line on this machine: the climber course's fields, then how this machine saw the base.
    protected void Log_MovementBaseRow(FString InExtra)
    {
        if (ck::Is_NOT_Valid(_Pawn))
        {
            const auto Missing = f"[MovementBaseNetTest] {_MbRow} {Get_MachineName()} pawn=missing samples={_CourseSamples.Num()} ensures={Get_NewEnsures()} {InExtra}";
            Log(Missing);
            return;
        }

        const auto Rise = Get_Rise();
        const auto Modes = Get_Modes();
        const auto NetBases = Get_NetBases();
        const auto Offset = _Pawn.GetActorLocation() - _Base;
        const auto Climber = Get_CourseClimber();
        auto Dismount = "none";
        if (ck::IsValid(Climber) && Climber.Get_LastDismount().IsSet())
        { Dismount = f"{Climber.Get_LastDismount().GetValue() :n}"; }

        const auto Start = Get_ClimbStartIndex();
        auto ModeBefore = "none";
        if (_CourseSamples.Num() > 0)
        { ModeBefore = f"{_CourseSamples[Math::Max(Start - 1, 0)].Mode :n}"; }

        auto LastNetBase = "none";
        auto LastHasBase = false;
        if (_CourseSamples.Num() > 0)
        {
            LastNetBase = f"{_CourseSamples[_CourseSamples.Num() - 1].NetBase :n}";
            LastHasBase = _CourseSamples[_CourseSamples.Num() - 1].HasMovementBase;
        }

        const auto FirstWalking = Get_FirstWalkingIndexAfterClimb();
        const auto FirstWalkingFrame = FirstWalking >= 0 ? _CourseSamples[FirstWalking].Frame : -1;
        const auto FeetZ = Get_FeetAboveFloor();
        const auto Mode = _Pawn.CharacterMovement.MovementMode;
        const auto NowNetBase = _Pawn.Get_NetBase();
        const auto Step = Get_LargestPlanarStep(Start);
        const auto First = Describe_Samples(Start, 20);
        const auto Last = Describe_Samples(_CourseSamples.Num() - 10, 10);
        const auto Net = Describe_NetDiagnostics();
        const auto Line = f"[MovementBaseNetTest] {_MbRow} {Get_MachineName()} highest={Rise.Highest :.2} drop={Rise.LargestDrop :.2} "
            + f"flying={Modes.Flying} falling={Modes.Falling} walking={Modes.Walking} "
            + f"final=({Offset.X :.1},{Offset.Y :.1},{FeetZ :.1}) mode={Mode :n} netBase={NowNetBase :n} "
            + f"lastSample=[netBase={LastNetBase} hasBase={LastHasBase}] climbed={_CourseEverClimbed} "
            + f"lastDismount={Dismount} ensures={Get_NewEnsures()} samples={_CourseSamples.Num()} "
            + f"bases=[none {NetBases.None} crossing {NetBases.Crossing} perMachine {NetBases.PerMachine} "
            + f"unresolved {NetBases.Unresolved}] largestStep={Step :.2} modeBeforeMount={ModeBefore} "
            + f"settled={Get_SettledSampleCount()} frames=[mount {_CourseMountFrame} flying {_CourseFirstFlyingFrame} "
            + f"top {_CourseFirstTopFrame} climbEnd {_CourseClimbEndFrame} platform {_CourseFirstPlatformFrame} "
            + f"jump {_MbJumpFrame} passedJumpFeet {_MbPassedJumpFeetFrame} firstWalking {FirstWalkingFrame}] {InExtra} "
            + f"{Net} first=[{First}] last=[{Last}]";
        Log(Line);
    }

    //------------------------------------------------------------------------------------------------------------------
    // Both machines
    //------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    protected void OnMbComposed(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        if (Get_IsServer())
        {
            WaitSeconds(k_ComposeSeconds, n"OnMbServerComposeWaited");
            return;
        }

        Mark_CourseClock();
        WaitUntil(n"Is_MbCopySettled", n"OnMbClientCopySettled", k_SlowPolls);
    }

    //------------------------------------------------------------------------------------------------------------------
    // Server
    //------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    protected void OnMbServerComposeWaited(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        if (Request_ServerPossessByLocal(_Pawn) == false)
        {
            Log_MovementBaseRow("possession=none");
            FinishFailure("the server's world has not exactly one local player controller to move the pawn");
            return;
        }

        WaitUntil(n"Is_OwnerReadyToMount", n"OnMbServerReady", k_SlowPolls);
    }

    UFUNCTION()
    protected void OnMbServerReady(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Request_OwnerMount();
        WaitUntil(n"Is_OwnerClimbingFlying", n"OnMbServerClimbing", k_SlowPolls);
    }

    UFUNCTION()
    protected void OnMbServerClimbing(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        if (Get_IsPastCourseDeadline())
        {
            Log_MovementBaseRow("mounted=never");
            FinishFailure("the server's Climber was asked to mount and never climbed in MOVE_Flying");
            return;
        }

        if (_MbCourse == EMars_TESTONLY_MovementBaseNet_HostCourse::JumpOffAtHeight)
        {
            WaitUntil(n"Is_MbServerAtJumpHeight", n"OnMbServerAtJumpHeight", k_SlowPolls);
            return;
        }

        WaitUntil(n"Is_OwnerClimbEnded", n"OnMbServerClimbEnded", k_SlowPolls);
    }

    UFUNCTION()
    protected void OnMbServerClimbEnded(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Mark_CourseClock();
        if (_MbCourse == EMars_TESTONLY_MovementBaseNet_HostCourse::ClimbToTheTopAndWalk)
        {
            WaitUntil(n"Is_CourseSettled", n"OnMbServerReadyToWalk", k_SlowPolls);
            return;
        }

        WaitUntil(n"Is_CourseSettled", n"OnMbServerEnded", k_SlowPolls);
    }

    UFUNCTION()
    protected void OnMbServerReadyToWalk(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _MbWalkStartX = _Pawn.GetActorLocation().X - _Base.X;
        Mark_CourseClock();
        WaitUntil(n"Is_MbServerWalked", n"OnMbServerWalked", k_SlowPolls);
    }

    // Walks toward the platform's centre every poll for k_MbWalkSeconds of course clock.
    UFUNCTION()
    protected void Is_MbServerWalked(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Sample_Copy();
        if (_CourseClockSeconds >= k_MbWalkSeconds)
        {
            Result.Set(true);
            return;
        }

        _Pawn.AddMovementInput(FVector(1.0, 0.0, 0.0), 1.0f);
        Result.Set(false);
    }

    UFUNCTION()
    protected void OnMbServerWalked(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Mark_CourseClock();
        WaitUntil(n"Is_CourseSettled", n"OnMbServerEnded", k_SlowPolls);
    }

    // Pushes up every poll until the feet are k_MbJumpFeet above the floor, the climb ended, or the deadline passed.
    UFUNCTION()
    protected void Is_MbServerAtJumpHeight(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Sample_Copy();
        auto Climber = Get_CourseClimber();
        if (ck::Is_NOT_Valid(Climber) || Climber.Get_IsClimbing() == false || Get_IsPastCourseDeadline()
            || Get_FeetAboveFloor() >= k_MbJumpFeet)
        {
            Result.Set(true);
            return;
        }

        Climber.Request_Climb(FMars_Request_Climber_Climb(1.0f));
        Result.Set(false);
    }

    UFUNCTION()
    protected void OnMbServerAtJumpHeight(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _MbJumpFrame = int32(utils_time::Get_FrameCounter());
        auto Climber = Get_CourseClimber();
        Climber.Request_Dismount(FMars_Request_Climber_Dismount(EMars_Climber_Dismount::Jump));
        Mark_CourseClock();
        WaitUntil(n"Is_MbServerLanded", n"OnMbServerLanded", k_SlowPolls);
    }

    UFUNCTION()
    protected void Is_MbServerLanded(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Sample_Copy();
        Result.Set(Get_IsPastCourseDeadline() || (Get_HasFallingSampleFrom(_MbJumpFrame) && Get_IsOnFloor()));
    }

    UFUNCTION()
    protected void OnMbServerLanded(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Mark_CourseClock();
        WaitUntil(n"Is_CourseSettled", n"OnMbServerEnded", k_SlowPolls);
    }

    UFUNCTION()
    protected void OnMbServerEnded(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Log_MovementBaseRow(f"walkStartX={_MbWalkStartX :.1}");
        Assert_ServerRow();
        Assert_Equals_Int(Get_NewEnsures(), 0, "no ensure on the server");
        WaitSeconds(k_MbServerWatchSeconds, n"OnCourseServerClientAsserted");
    }

    //------------------------------------------------------------------------------------------------------------------
    // Client
    //------------------------------------------------------------------------------------------------------------------

    // Whether the row's course has reached its end on this copy, so its place may settle; notes when the copy's feet
    // first passed the jump's height.
    protected bool Track_IsCopyCourseAtItsEnd()
    {
        if (_MbOwner == EMars_TESTONLY_MovementBaseNet_Owner::Client)
        { return Get_IsClientCourseAtItsEnd(); }

        if (_MbCourse == EMars_TESTONLY_MovementBaseNet_HostCourse::JumpOffAtHeight)
        {
            if (_MbPassedJumpFeetFrame < 0 && Get_FeetAboveFloor() >= k_MbJumpFeet)
            { _MbPassedJumpFeetFrame = int32(utils_time::Get_FrameCounter()); }

            return _MbPassedJumpFeetFrame >= 0 && Math::Abs(Get_FeetAboveFloor()) <= k_StandToleranceCm;
        }

        if (_MbCourse == EMars_TESTONLY_MovementBaseNet_HostCourse::ClimbToTheTopAndWalk)
        { return Get_HasReachedTop() && _Pawn.GetActorLocation().X - _Base.X >= k_ExitX + k_MbWalkSeenCm; }

        return Get_HasReachedTop();
    }

    // The copy's course reached its end and its place has been still for k_SettleSeconds since, or the deadline passed.
    UFUNCTION()
    protected void Is_MbCopySettled(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        const auto Samples = _CourseSamples.Num();
        Sample_Copy();
        if (_CourseSamples.Num() == Samples)
        {
            Result.Set(Get_IsPastCourseDeadline());
            return;
        }

        const auto& Sample = _CourseSamples[_CourseSamples.Num() - 1];
        const auto Place = FVector(Sample.X, Sample.Y, Sample.FeetZ);
        if (_MbIsReadyToSettle == false)
        {
            _MbIsReadyToSettle = Track_IsCopyCourseAtItsEnd();
            if (_MbIsReadyToSettle)
            { Restart_Settle(Place); }
        }
        else if ((Place - _MbStillPlace).Size() > k_MbStillEpsilonCm)
        { Restart_Settle(Place); }
        else
        { _MbStillSeconds += Sample.DeltaSeconds; }

        Result.Set(Get_IsPastCourseDeadline() || (_MbIsReadyToSettle && _MbStillSeconds >= k_SettleSeconds));
    }

    private void Restart_Settle(FVector InPlace)
    {
        _MbStillPlace = InPlace;
        _MbStillSeconds = 0.0f;
        _MbSettleStartIndex = _CourseSamples.Num() - 1;
    }

    UFUNCTION()
    protected void OnMbClientCopySettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto IsLocal = ck::IsValid(_Pawn) && _Pawn.IsLocallyControlled();
        Log_MovementBaseRow(f"local={IsLocal}");
        Assert_True(ck::IsValid(_Pawn) && IsLocal == false, "the client does not control the pawn it watches");
        Assert_True(_MbSettleStartIndex >= 0, "the client's copy reached the course's end and settled");
        Assert_ClientRow();
        Assert_Equals_Int(Get_NewEnsures(), 0, "no ensure on the client");
        TearDown_Course();
        FinishSuccess();
    }

    //------------------------------------------------------------------------------------------------------------------
    // Client-owned rows
    //------------------------------------------------------------------------------------------------------------------

    // The counts and the samples from here are the row's window.
    protected void Open_MbWindow()
    {
        _MbWindowStartIndex = _CourseSamples.Num();
        const auto Movement = Get_CourseMovement();
        if (ck::IsValid(Movement))
        { _MbWindowCounts = Movement.Get_NetCounts(); }
    }

    // Whether this copy has done the client's course, so its place may settle.
    protected bool Get_IsClientCourseAtItsEnd()
    {
        if (_MbClientCourse == EMars_TESTONLY_MovementBaseNet_ClientCourse::StandOnTheFloor)
        { return Get_IsOnFloor(); }

        if (_MbClientCourse == EMars_TESTONLY_MovementBaseNet_ClientCourse::WalkOnThePlatform)
        { return Get_IsOnPlatformTop() && _Pawn.GetActorLocation().X - _Base.X >= k_MbPlatformCentre.X + k_MbWalkSeenCm; }

        if (_MbClientCourse == EMars_TESTONLY_MovementBaseNet_ClientCourse::JumpOnThePlatform)
        { return Get_HasMbJumpSample() && Get_IsOnPlatformTop(); }

        if (_MbClientCourse == EMars_TESTONLY_MovementBaseNet_ClientCourse::MovedOntoThePad)
        { return _MbPadMoveFrame >= 0 && Get_IsOnPad(); }

        return Get_IsOnPlatformTop();
    }

    // Server: the pawn's copy composed and every surface of the row has its component.
    UFUNCTION()
    protected void Is_MbClientOwnedServerReady(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsPawnComposed() && Get_IsPlatformReady() && Get_IsMbPadReady());
    }

    UFUNCTION()
    protected void OnMbClientOwnedServerReady(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_ComposeSeconds, n"OnMbClientOwnedServerComposeWaited");
    }

    UFUNCTION()
    protected void OnMbClientOwnedServerComposeWaited(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        if (Request_ServerPossessByRemote(_Pawn) == false)
        {
            Log_MovementBaseRow("remoteController=none");
            FinishFailure("the server's world has not exactly one player controller that is not local");
            return;
        }

        Open_MbWindow();
        Mark_CourseClock();
        if (_MbClientCourse == EMars_TESTONLY_MovementBaseNet_ClientCourse::MovedOntoThePad)
        {
            WaitUntil(n"Is_MbServerPadMoveDue", n"OnMbServerPadMoveDue", k_SlowPolls);
            return;
        }

        WaitUntil(n"Is_MbCopySettled", n"OnMbClientOwnedServerSettled", k_SlowPolls);
    }

    // Samples the copy while the client has had the pawn for k_ComposeSeconds of course clock.
    UFUNCTION()
    protected void Is_MbServerPadMoveDue(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Sample_Copy();
        Result.Set(_CourseClockSeconds >= k_ComposeSeconds);
    }

    UFUNCTION()
    protected void OnMbServerPadMoveDue(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _MbPadMoveFrame = int32(utils_time::Get_FrameCounter());
        Request_MbPlacePawnOn(_Base + k_MbPadOffset + FVector(0.0, 0.0, k_PlatformHeight));
        Mark_CourseClock();
        WaitUntil(n"Is_MbCopySettled", n"OnMbClientOwnedServerSettled", k_SlowPolls);
    }

    // Watches the copy for k_MbServerWatchSeconds more, so a copy that drifts or is moved after its settle is caught.
    UFUNCTION()
    protected void OnMbClientOwnedServerSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Mark_CourseClock();
        WaitUntil(n"Is_MbServerWatched", n"OnMbClientOwnedServerWatched", k_SlowPolls);
    }

    UFUNCTION()
    protected void Is_MbServerWatched(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Sample_Copy();
        Result.Set(_CourseClockSeconds >= k_MbServerWatchSeconds);
    }

    UFUNCTION()
    protected void OnMbClientOwnedServerWatched(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Log_MovementBaseRow(Describe_MbWindow());
        Assert_True(_MbSettleStartIndex >= 0, "the server's copy did the client's course and settled");
        Assert_ServerRow();
        Assert_Equals_Int(Get_NewEnsures(), 0, "no ensure on the server");
        // The client asserts first: handing the pawn back makes its copy a non-owning one.
        WaitSeconds(k_MbServerWatchSeconds, n"OnCourseServerClientAsserted");
    }

    // Client: its copy of the pawn, found by the start, has composed, every surface of the row has its component, and
    // the client controls the pawn.
    UFUNCTION()
    protected void Is_MbClientOwnedCopyReady(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        if (ck::Is_NOT_Valid(_Pawn))
        { _Pawn = DoFind_PawnNear(Get_MbStart()); }

        Result.Set(Get_IsPawnComposed() && Get_IsPlatformReady() && Get_IsMbPadReady() && _Pawn.IsLocallyControlled()
            && Get_IsInState(UMars_SmState_Alive));
    }

    UFUNCTION()
    protected void OnMbClientOwnedCopyReady(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Open_MbWindow();
        Mark_CourseClock();
        if (_MbClientCourse == EMars_TESTONLY_MovementBaseNet_ClientCourse::WalkOnThePlatform)
        {
            WaitUntil(n"Is_MbClientWalked", n"OnMbClientCourseDone", k_SlowPolls);
            return;
        }

        if (_MbClientCourse == EMars_TESTONLY_MovementBaseNet_ClientCourse::JumpOnThePlatform)
        {
            _MbJumpFrame = int32(utils_time::Get_FrameCounter());
            _Pawn.Jump();
            WaitUntil(n"Is_MbClientLanded", n"OnMbClientCourseDone", k_SlowPolls);
            return;
        }

        if (_MbClientCourse == EMars_TESTONLY_MovementBaseNet_ClientCourse::MovedOntoThePad)
        {
            WaitUntil(n"Is_MbClientOnPad", n"OnMbClientCourseDone", k_SlowPolls);
            return;
        }

        WaitUntil(n"Is_CourseSettled", n"OnMbClientStandSettled", k_SlowPolls);
    }

    UFUNCTION()
    protected void OnMbClientStandSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Mark_CourseClock();
        WaitUntil(n"Is_MbClientStood", n"OnMbClientOwnedEnded", k_SlowPolls);
    }

    UFUNCTION()
    protected void Is_MbClientStood(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Sample_Copy();
        Result.Set(_CourseClockSeconds >= k_MbClientStandSeconds);
    }

    // Walks along +X every poll for k_MbWalkSeconds of course clock.
    UFUNCTION()
    protected void Is_MbClientWalked(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Sample_Copy();
        if (_CourseClockSeconds >= k_MbWalkSeconds)
        {
            Result.Set(true);
            return;
        }

        _Pawn.AddMovementInput(FVector(1.0, 0.0, 0.0), 1.0f);
        Result.Set(false);
    }

    // Releases the jump after k_MbJumpReleaseSeconds; done once the pawn rose and stands on the platform's top again.
    UFUNCTION()
    protected void Is_MbClientLanded(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Sample_Copy();
        if (_MbJumpReleaseFrame < 0 && _CourseClockSeconds >= k_MbJumpReleaseSeconds)
        {
            _MbJumpReleaseFrame = int32(utils_time::Get_FrameCounter());
            _Pawn.StopJumping();
        }

        Result.Set(Get_IsPastCourseDeadline() || (_MbJumpReleaseFrame >= 0 && Get_HasMbJumpSample() && Get_IsOnPlatformTop()));
    }

    UFUNCTION()
    protected void Is_MbClientOnPad(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Sample_Copy();
        if (_MbOnPadFrame < 0 && Get_IsOnPad())
        {
            _MbOnPadFrame = int32(utils_time::Get_FrameCounter());
            _MbOnPadSeconds = _CourseClockSeconds;
        }

        Result.Set(Get_IsPastCourseDeadline() || _MbOnPadFrame >= 0);
    }

    UFUNCTION()
    protected void OnMbClientCourseDone(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Mark_CourseClock();
        WaitUntil(n"Is_CourseSettled", n"OnMbClientOwnedEnded", k_SlowPolls);
    }

    UFUNCTION()
    protected void OnMbClientOwnedEnded(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto IsLocal = ck::IsValid(_Pawn) && _Pawn.IsLocallyControlled();
        Log_MovementBaseRow(Describe_MbWindow() + f" local={IsLocal}");
        Assert_True(IsLocal, "the client controls the pawn it moves");
        Assert_ClientRow();
        Assert_Equals_Int(Get_NewEnsures(), 0, "no ensure on the client");
        Mark_CourseClock();
        WaitUntil(n"Is_MbClientHandedBack", n"OnMbClientHandedBack", k_SlowPolls);
    }

    // The client keeps its course until the server took the pawn back: the server still watches its copy, which
    // follows the client's pawn, and that pawn would fall with its surface gone.
    UFUNCTION()
    protected void Is_MbClientHandedBack(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Sample_Copy();
        Result.Set(ck::Is_NOT_Valid(_Pawn) || _Pawn.IsLocallyControlled() == false || Get_IsPastCourseDeadline());
    }

    UFUNCTION()
    protected void OnMbClientHandedBack(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        TearDown_Course();
        FinishSuccess();
    }
}
