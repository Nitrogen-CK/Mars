// One frame of this machine's copy of the climbing pawn: its feet's height above the floor, its place relative to the
// base, its movement mode and whether its own Climber climbs.
struct FMars_TESTONLY_ClimberNet_Sample
{
    UPROPERTY()
    int32 Frame = 0;

    UPROPERTY()
    float64 FeetZ = 0.0;

    UPROPERTY()
    float64 X = 0.0;

    UPROPERTY()
    float64 Y = 0.0;

    UPROPERTY()
    EMovementMode Mode = EMovementMode::MOVE_None;

    UPROPERTY()
    bool IsClimbing = false;

    UPROPERTY()
    float32 DeltaSeconds = 0.0f;
}

// How evenly a copy rose, read from the climb's start in its samples to its first sample at the top.
struct FMars_TESTONLY_ClimberNet_Rise
{
    UPROPERTY()
    float64 Highest = 0.0;

    // Below the copy's own running maximum.
    UPROPERTY()
    float64 LargestDrop = 0.0;

    UPROPERTY()
    float64 LargestRise = 0.0;

    UPROPERTY()
    int32 NoRiseSamples = 0;

    UPROPERTY()
    float32 MeanFrameSeconds = 0.0f;
}

// Movement modes read from the climb's start in the samples to the last sample.
struct FMars_TESTONLY_ClimberNet_Modes
{
    UPROPERTY()
    int32 Flying = 0;

    UPROPERTY()
    int32 Falling = 0;

    UPROPERTY()
    int32 Walking = 0;
}

// Who moves the pawn on the server in a row whose owner is the host.
enum EMars_TESTONLY_ClimberNet_Possession
{
    // The host's own player controller possesses it: the owner and the authority in one.
    HostController,
    // The world has not exactly one local player controller: the pawn is moved with no controller.
    Nobody
}

// The climber net tests' course, on the player-combat pawn rig: each machine builds a platform 300 high (an engine
// cube, like the rig's floor) and the real ladder script against its face, both its own (neither replicates), with the
// ladder's out direction facing the pawn's spot. The machine that owns the pawn climbs it by Climber requests; every
// machine samples its own copy of the pawn once a frame inside its waits and logs one line.
UCLASS(Abstract)
class UMars_AutoTestRig_NetClimber : UMars_AutoTestRig_NetPlayerCombat
{
    default _TimeoutSeconds = 30.0f;

    // Foot of the climb line, top exit and platform, relative to the base (the ladder's default spec: Standoff 45,
    // Height 300, TopExitDepth 70; the ladder stands at +150 facing -X).
    protected const FVector k_LadderOffset = FVector(150.0, 0.0, 0.0);
    protected const float64 k_LineX = 105.0;
    protected const float64 k_ExitX = 220.0;
    protected const float64 k_PlatformHeight = 300.0;
    // "At the top": the feet this close below the platform.
    protected const float64 k_TopFeet = 285.0;
    // "On the platform" or "on the floor": the feet within this of its height.
    protected const float64 k_StandToleranceCm = 10.0;
    // "On the platform": within this of the exit in X and Y.
    protected const float64 k_ExitToleranceCm = 60.0;
    // A wait that samples gives up after this many course seconds, so a red row still logs its line.
    protected const float32 k_CourseDeadlineSeconds = 15.0f;

    protected FCk_Handle_Ladder _CourseLadder;
    protected TArray<FMars_TESTONLY_ClimberNet_Sample> _CourseSamples;
    protected bool _CourseEverClimbed = false;
    protected bool _CourseEverCandidate = false;
    // Frame counters (one counter for both PIE worlds); -1 before.
    protected int32 _CourseMountFrame = -1;
    protected int32 _CourseFirstFlyingFrame = -1;
    protected int32 _CourseFirstTopFrame = -1;
    protected int32 _CourseClimbEndFrame = -1;
    protected int32 _CourseFirstPlatformFrame = -1;
    // Summed frame times of this machine's samples since the last mark.
    protected float32 _CourseClockSeconds = 0.0f;

    private AStaticMeshActor _CoursePlatform;
    private APlayerController _CourseLocalController;
    private APawn _CourseLocalPreviousPawn;
    private FCk_Handle _CourseLadderEntity;

    protected void Begin_Course(FVector InBase)
    {
        Begin_Rig(InBase);
        Spawn_Platform();
        Spawn_Ladder();
    }

    // An engine cube 400 x 400 x 300 whose near face is the ladder's plane and whose top is the platform.
    private void Spawn_Platform()
    {
        const auto WorldContext = FAngelscriptGameThreadScopeWorldContext(Get_TestWorld());
        auto Cube = Cast<UStaticMesh>(LoadObject(UStaticMesh, "/Engine/BasicShapes/Cube.Cube"));
        _CoursePlatform = Cast<AStaticMeshActor>(SpawnActor(AStaticMeshActor, _Base + FVector(350.0, 0.0, 150.0)));
        if (ck::Is_NOT_Valid(_CoursePlatform) || ck::Is_NOT_Valid(Cube))
        {
            FinishFailure("the platform (the engine cube) did not spawn");
            return;
        }

        _CoursePlatform.StaticMeshComponent.SetMobility(EComponentMobility::Movable);
        _CoursePlatform.StaticMeshComponent.SetStaticMesh(Cube);
        _CoursePlatform.SetActorScale3D(FVector(4.0, 4.0, 3.0));
    }

    // The production ladder script under this machine's transient entity: it does not replicate, so each machine builds
    // its own from the same parameters, as a level would.
    private void Spawn_Ladder()
    {
        auto Params = UMars_Ladder_EntityScript::Params();
        Params.SpawnTransform = FTransform(FRotator(0.0, 180.0, 0.0), _Base + k_LadderOffset);
        Params.Ladder = FMars_Ladder_Spec();
        auto Owner = utils_net_spawn_test::Get_TransientEntity(Get_SubjectEntity());
        auto Pending = utils_entity_script::Request_SpawnEntity(Owner, UMars_Ladder_EntityScript, Params);
        utils_pending_entity_script::Promise_OnConstructed(Pending, FCk_Delegate_EntityScript_Constructed(this, n"OnCourseLadderConstructed"));
    }

    UFUNCTION()
    private void OnCourseLadderConstructed(FCk_Handle_EntityScript InEntityScriptHandle)
    {
        _CourseLadderEntity = FCk_Handle(InEntityScriptHandle);
        _CourseLadder = _CourseLadderEntity.As_Ladder();
    }

    protected FCk_Handle_Climber Get_CourseClimber()
    {
        if (ck::Is_NOT_Valid(_Player))
        { return FCk_Handle_Climber(); }

        return _Player.As_Climber(ECk_SanityCheck::UnChecked);
    }

    protected float64 Get_FeetAboveFloor()
    {
        return _Pawn.GetActorLocation().Z - _Pawn.CapsuleComponent.GetScaledCapsuleHalfHeight() - _Base.Z;
    }

    protected bool Get_IsOnFloor()
    {
        return ck::IsValid(_Pawn) && Math::Abs(Get_FeetAboveFloor()) <= k_StandToleranceCm
            && _Pawn.CharacterMovement.MovementMode == EMovementMode::MOVE_Walking;
    }

    protected bool Get_IsOnPlatform()
    {
        if (ck::Is_NOT_Valid(_Pawn))
        { return false; }

        const auto Offset = _Pawn.GetActorLocation() - _Base;
        return Math::Abs(Get_FeetAboveFloor() - k_PlatformHeight) <= k_StandToleranceCm
            && Math::Abs(Offset.X - k_ExitX) <= k_ExitToleranceCm && Math::Abs(Offset.Y) <= k_ExitToleranceCm
            && _Pawn.CharacterMovement.MovementMode == EMovementMode::MOVE_Walking;
    }

    protected void Mark_CourseClock()
    {
        _CourseClockSeconds = 0.0f;
    }

    protected bool Get_IsPastCourseDeadline()
    {
        return _CourseClockSeconds >= k_CourseDeadlineSeconds;
    }

    // Once a frame (a second call in one frame is skipped). Quiet while this machine has no copy of the pawn.
    protected void Sample_Copy()
    {
        if (ck::Is_NOT_Valid(_Pawn))
        { return; }

        const auto Frame = int32(utils_time::Get_FrameCounter());
        if (_CourseSamples.Num() > 0 && _CourseSamples[_CourseSamples.Num() - 1].Frame == Frame)
        { return; }

        const auto WorldContext = FAngelscriptGameThreadScopeWorldContext(Get_TestWorld());
        const auto Climber = Get_CourseClimber();
        const auto Location = _Pawn.GetActorLocation();

        auto Sample = FMars_TESTONLY_ClimberNet_Sample();
        Sample.Frame = Frame;
        Sample.FeetZ = Get_FeetAboveFloor();
        Sample.X = Location.X - _Base.X;
        Sample.Y = Location.Y - _Base.Y;
        Sample.Mode = _Pawn.CharacterMovement.MovementMode;
        Sample.IsClimbing = ck::IsValid(Climber) && Climber.Get_IsClimbing();
        Sample.DeltaSeconds = float32(Gameplay::GetWorldDeltaSeconds());

        const auto WasClimbing = _CourseSamples.Num() > 0 && _CourseSamples[_CourseSamples.Num() - 1].IsClimbing;
        _CourseSamples.Add(Sample);
        _CourseClockSeconds += Sample.DeltaSeconds;

        if (Sample.IsClimbing)
        { _CourseEverClimbed = true; }

        if (WasClimbing && Sample.IsClimbing == false && _CourseClimbEndFrame < 0)
        { _CourseClimbEndFrame = Frame; }

        if (ck::IsValid(Climber) && Climber.Get_HasCandidate())
        { _CourseEverCandidate = true; }

        if (_CourseFirstFlyingFrame < 0 && Sample.Mode == EMovementMode::MOVE_Flying)
        { _CourseFirstFlyingFrame = Frame; }

        if (_CourseFirstTopFrame < 0 && Sample.FeetZ >= k_TopFeet)
        { _CourseFirstTopFrame = Frame; }

        if (_CourseFirstPlatformFrame < 0 && Get_IsOnPlatform())
        { _CourseFirstPlatformFrame = Frame; }
    }

    protected bool Get_HasReachedTop()
    {
        return _CourseFirstTopFrame >= 0;
    }

    // Where the climb starts in the samples: the first that read MOVE_Flying or, on a copy that never did, the first
    // whose feet left the floor; -1 without either.
    protected int32 Get_ClimbStartIndex()
    {
        for (int32 Index = 0; Index < _CourseSamples.Num(); ++Index)
        {
            if (_CourseSamples[Index].Mode == EMovementMode::MOVE_Flying)
            { return Index; }
        }

        for (int32 Index = 0; Index < _CourseSamples.Num(); ++Index)
        {
            if (_CourseSamples[Index].FeetZ > k_StandToleranceCm)
            { return Index; }
        }

        return -1;
    }

    // The first sample at the top from InFrom; the last sample without one.
    protected int32 Get_FirstTopIndex(int32 InFrom)
    {
        for (int32 Index = InFrom; Index < _CourseSamples.Num(); ++Index)
        {
            if (_CourseSamples[Index].FeetZ >= k_TopFeet)
            { return Index; }
        }

        return _CourseSamples.Num() - 1;
    }

    protected FMars_TESTONLY_ClimberNet_Rise Get_Rise()
    {
        auto Rise = FMars_TESTONLY_ClimberNet_Rise();
        for (const auto& Sample : _CourseSamples)
        { Rise.Highest = Math::Max(Rise.Highest, Sample.FeetZ); }

        const auto From = Get_ClimbStartIndex();
        if (From < 0)
        { return Rise; }

        const auto To = Get_FirstTopIndex(From);
        auto RunningMax = _CourseSamples[From].FeetZ;
        auto FrameSeconds = 0.0f;
        for (int32 Index = From + 1; Index <= To; ++Index)
        {
            const auto& Sample = _CourseSamples[Index];
            const auto Step = Sample.FeetZ - _CourseSamples[Index - 1].FeetZ;
            Rise.LargestRise = Math::Max(Rise.LargestRise, Step);
            if (Step <= 0.0)
            { Rise.NoRiseSamples += 1; }

            RunningMax = Math::Max(RunningMax, Sample.FeetZ);
            Rise.LargestDrop = Math::Max(Rise.LargestDrop, RunningMax - Sample.FeetZ);
            FrameSeconds += Sample.DeltaSeconds;
        }

        if (To > From)
        { Rise.MeanFrameSeconds = FrameSeconds / float32(To - From); }

        return Rise;
    }

    protected FMars_TESTONLY_ClimberNet_Modes Get_Modes()
    {
        auto Modes = FMars_TESTONLY_ClimberNet_Modes();
        const auto From = Get_ClimbStartIndex();
        if (From < 0)
        { return Modes; }

        for (int32 Index = From; Index < _CourseSamples.Num(); ++Index)
        {
            const auto Mode = _CourseSamples[Index].Mode;
            if (Mode == EMovementMode::MOVE_Flying)
            { Modes.Flying += 1; }
            else if (Mode == EMovementMode::MOVE_Falling)
            { Modes.Falling += 1; }
            else if (Mode == EMovementMode::MOVE_Walking)
            { Modes.Walking += 1; }
        }

        return Modes;
    }

    // Samples while this machine's Climber climbs that read another mode than MOVE_Flying.
    protected int32 Get_ClimbingSamplesNotFlying()
    {
        auto Count = 0;
        for (const auto& Sample : _CourseSamples)
        {
            if (Sample.IsClimbing && Sample.Mode != EMovementMode::MOVE_Flying)
            { Count += 1; }
        }

        return Count;
    }

    // Samples from the climb's start to the first one at the top that read MOVE_Falling.
    protected int32 Get_FallingSamplesBeforeTop()
    {
        const auto From = Get_ClimbStartIndex();
        if (From < 0)
        { return 0; }

        auto Count = 0;
        const auto To = Get_FirstTopIndex(From);
        for (int32 Index = From; Index <= To; ++Index)
        {
            if (_CourseSamples[Index].Mode == EMovementMode::MOVE_Falling)
            { Count += 1; }
        }

        return Count;
    }

    // Whether a sample from InFrame on read MOVE_Falling.
    protected bool Get_HasFallingSampleFrom(int32 InFrame)
    {
        for (const auto& Sample : _CourseSamples)
        {
            if (Sample.Frame >= InFrame && Sample.Mode == EMovementMode::MOVE_Falling)
            { return true; }
        }

        return false;
    }

    protected FString Describe_FirstFlyingSamples()
    {
        const auto From = Get_ClimbStartIndex();
        if (From < 0)
        { return ""; }

        auto Text = "";
        const auto To = Math::Min(From + 20, _CourseSamples.Num());
        for (int32 Index = From; Index < To; ++Index)
        {
            const auto& Sample = _CourseSamples[Index];
            const auto Mode = Sample.Mode == EMovementMode::MOVE_Flying ? "F"
                : (Sample.Mode == EMovementMode::MOVE_Falling ? "D" : (Sample.Mode == EMovementMode::MOVE_Walking ? "W" : "O"));
            const auto Climbing = Sample.IsClimbing ? "c" : "";
            Text += f"{Sample.Frame}:{Sample.FeetZ :.2}{Mode}{Climbing} ";
        }

        return Text;
    }

    // What this copy's movement component takes on trust; -1 when it is not the project's component.
    protected float32 Get_ClientAuthMaxError()
    {
        auto Movement = Cast<UMars_CharacterMovementComponent>(_Pawn.CharacterMovement);
        return ck::IsValid(Movement) ? Movement.ClientAuthMaxError : -1.0f;
    }

    // Server: hands the pawn to the one player controller in its world that is local (the host's own), found by a scan
    // of the world's player controllers. False (nothing possessed) without exactly one.
    protected bool Request_ServerPossessByLocal(APawn InPawn)
    {
        const auto WorldContext = FAngelscriptGameThreadScopeWorldContext(Get_TestWorld());
        auto Controllers = TArray<AActor>();
        Gameplay::GetAllActorsOfClass(APlayerController, Controllers);

        APlayerController Local;
        auto Count = 0;
        for (auto Actor : Controllers)
        {
            auto Controller = Cast<APlayerController>(Actor);
            if (ck::Is_NOT_Valid(Controller) || Controller.IsLocalController() == false)
            { continue; }

            Local = Controller;
            Count += 1;
        }

        if (Count != 1)
        { return false; }

        _CourseLocalController = Local;
        _CourseLocalPreviousPawn = Local.GetControlledPawn();
        Local.Possess(InPawn);
        return true;
    }

    // Server: the host's own controller gets its old pawn back. Safe to call twice.
    protected void Request_ServerReturnLocal()
    {
        if (ck::Is_NOT_Valid(_CourseLocalController))
        { return; }

        if (ck::IsValid(_Pawn) && _CourseLocalController.GetControlledPawn() == _Pawn)
        { _CourseLocalController.UnPossess(); }

        if (ck::IsValid(_CourseLocalPreviousPawn) && _CourseLocalController.GetControlledPawn() != _CourseLocalPreviousPawn)
        { _CourseLocalController.Possess(_CourseLocalPreviousPawn); }

        _CourseLocalController = nullptr;
    }

    // The row's one log line on this machine.
    protected void Log_ClimberRow(FString InRow, FString InExtra)
    {
        if (ck::Is_NOT_Valid(_Pawn))
        {
            const auto Missing = f"[ClimberNetTest] {InRow} {Get_MachineName()} pawn=missing samples={_CourseSamples.Num()} ensures={Get_NewEnsures()} {InExtra}";
            Log(Missing);
            return;
        }

        const auto Rise = Get_Rise();
        const auto Modes = Get_Modes();
        const auto Offset = _Pawn.GetActorLocation() - _Base;
        const auto Climber = Get_CourseClimber();
        auto Dismount = "none";
        if (ck::IsValid(Climber) && Climber.Get_LastDismount().IsSet())
        { Dismount = f"{Climber.Get_LastDismount().GetValue() :n}"; }

        const auto FeetZ = Get_FeetAboveFloor();
        const auto Mode = _Pawn.CharacterMovement.MovementMode;
        const auto AuthMaxError = Get_ClientAuthMaxError();
        const auto First = Describe_FirstFlyingSamples();
        const auto Line = f"[ClimberNetTest] {InRow} {Get_MachineName()} highest={Rise.Highest :.2} drop={Rise.LargestDrop :.2} "
            + f"rise={Rise.LargestRise :.2} noRise={Rise.NoRiseSamples} meanFrame={Rise.MeanFrameSeconds :.4} "
            + f"flying={Modes.Flying} falling={Modes.Falling} walking={Modes.Walking} "
            + f"final=({Offset.X :.1},{Offset.Y :.1},{FeetZ :.1}) mode={Mode :n} climbed={_CourseEverClimbed} "
            + f"candidate={_CourseEverCandidate} lastDismount={Dismount} ensures={Get_NewEnsures()} "
            + f"authMaxError={AuthMaxError} samples={_CourseSamples.Num()} frames=[mount {_CourseMountFrame} "
            + f"flying {_CourseFirstFlyingFrame} top {_CourseFirstTopFrame} climbEnd {_CourseClimbEndFrame} "
            + f"platform {_CourseFirstPlatformFrame}] {InExtra} first=[{First}]";
        Log(Line);
    }

    //------------------------------------------------------------------------------------------------------------------
    // The owner's steps
    //------------------------------------------------------------------------------------------------------------------

    // This machine controls the pawn, it is Alive and standing on the floor, and its ladder has constructed.
    UFUNCTION()
    protected void Is_OwnerReadyToMount(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Sample_Copy();
        Result.Set(ck::IsValid(_Pawn) && _Pawn.IsLocallyControlled() && Get_IsInState(UMars_SmState_Alive) && Get_IsOnFloor()
            && ck::IsValid(_CourseLadder) && ck::IsValid(Get_CourseClimber()));
    }

    // Mounts this machine's ladder from the front, as the Climber's own requests.
    protected void Request_OwnerMount()
    {
        _CourseMountFrame = int32(utils_time::Get_FrameCounter());
        Mark_CourseClock();
        auto Climber = Get_CourseClimber();
        Climber.Request_Mount(FMars_Request_Climber_Mount(_CourseLadder, EMars_Ladder_Zone::Front));
    }

    UFUNCTION()
    protected void Is_OwnerClimbingFlying(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Sample_Copy();
        const auto Climber = Get_CourseClimber();
        Result.Set(Get_IsPastCourseDeadline() || (ck::IsValid(Climber) && Climber.Get_IsClimbing()
            && _Pawn.CharacterMovement.MovementMode == EMovementMode::MOVE_Flying));
    }

    // Pushes up every poll until the climb ends.
    UFUNCTION()
    protected void Is_OwnerClimbEnded(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Sample_Copy();
        auto Climber = Get_CourseClimber();
        if (ck::Is_NOT_Valid(Climber) || Climber.Get_IsClimbing() == false || Get_IsPastCourseDeadline())
        {
            Result.Set(true);
            return;
        }

        Climber.Request_Climb(FMars_Request_Climber_Climb(1.0f));
        Result.Set(false);
    }

    // A settle that keeps sampling: true once k_SettleSeconds of course clock have passed since the last mark.
    UFUNCTION()
    protected void Is_CourseSettled(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Sample_Copy();
        Result.Set(_CourseClockSeconds >= k_SettleSeconds);
    }

    //------------------------------------------------------------------------------------------------------------------
    // The end
    //------------------------------------------------------------------------------------------------------------------

    // Server: the client has had its time to assert; each controller gets its old pawn back, then the hold.
    UFUNCTION()
    protected void OnCourseServerClientAsserted(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Request_ServerReturnLocal();
        Request_ServerReturnRemote();
        WaitSeconds(k_ServerHoldSeconds, n"OnCourseServerHeld");
    }

    UFUNCTION()
    protected void OnCourseServerHeld(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        TearDown_Course();
        FinishSuccess();
    }

    protected void TearDown_Course()
    {
        Request_ServerReturnLocal();
        TearDown();
        if (ck::IsValid(_CourseLadderEntity))
        { utils_entity_lifetime::Request_DestroyEntity(_CourseLadderEntity); }

        if (ck::IsValid(_CoursePlatform))
        { _CoursePlatform.DestroyActor(); }

        _CourseLadderEntity = FCk_Handle();
        _CourseLadder = FCk_Handle_Ladder();
        _CoursePlatform = nullptr;
    }

    UFUNCTION(BlueprintOverride)
    void DoEndPlay(FCk_Handle InHandle)
    {
        Super::DoEndPlay(InHandle);
        TearDown_Course();
    }
}
