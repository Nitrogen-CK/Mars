// The Alive sub-SM's Operating state: the player holds a station (FMars_Fragment_Operator.Station is valid).
//   Locomotion ->Operating [IsOperating]       (the station's Use interaction reserved it for this player)
//   Operating  ->Locomotion [IsNotOperating]   (the station released this player: Leave, the station's own SM, or a
//                                               destroyed station)
// Entering Operating tears Locomotion (and its movement task) down, which is what locks the body in place. Tasks, in order:
//   PoseLock     glide the capsule to the stand and decouple body yaw from the view
//   Camera       snap the view to the stand's facing at CameraPitchOffset; Free fences the yaw, Captured freezes it
//   Grip         start the station's grip interaction under its own Operate intent so the gloves Hold on the station
//                (the grip never touches the Use intent: E while operating cannot disturb the gloves)
//   LeaveIntent  Mars.Intent.Back pressed -> Operator.Request_Leave()
//   Hints        the "leave" legend row (owner key Station); a minigame adds its own rows
// Leaving Operating any other way (Alive -> Downed tears it down) releases the station from DoExitState.

// Polled on the context entity's Operator; false without one.
class UMars_SmCondition_IsOperating : UCk_SmCondition_Polled
{
    UFUNCTION(BlueprintOverride)
    bool DoEvaluate(FCk_Handle_SmCondition InHandle, FCk_Time InDeltaT) const
    {
        auto Operator = ck::Ctx(InHandle).As_Operator(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(Operator))
        { return false; }

        return Operator.Get_IsOperating();
    }
}

class UMars_SmCondition_IsNotOperating : UMars_SmCondition_IsOperating
{
    default _NegateResult = true;
}

class UMars_SmState_Operating : UCk_SmState_EntityScript
{
    UFUNCTION(BlueprintOverride)
    void DoDefineState(FCk_Handle_SmState_UnderConstruction& InHandle)
    {
        auto ToLocomotion = AddTransition(InHandle, UMars_SmState_Locomotion);
        AddCondition(ToLocomotion, UMars_SmCondition_IsNotOperating);

        AddTask(InHandle, UMars_SmTask_Operating_PoseLock);
        AddTask(InHandle, UMars_SmTask_Operating_Camera);
        AddTask(InHandle, UMars_SmTask_Operating_Grip);
        AddTask(InHandle, UMars_SmTask_Operating_LeaveIntent);
        AddTask(InHandle, UMars_SmTask_Operating_Hints);
    }

    UFUNCTION(BlueprintOverride)
    void DoEnterState(FCk_Handle_SmState InHandle, ECk_Sm_NetContext InNetContext)
    {
        ck::Trace("Player SM: Operating", n"PlayerSM", 2.0f, FLinearColor(1.0f, 0.4f, 0.9f, 1.0f));
    }

    // A teardown that did not come from the station's release (Downed): release it, scoped to this player. It reaches the
    // arbiter on its next drain, so the back-ref may lag a frame; nothing re-enters Operating meanwhile (Alive is gone).
    UFUNCTION(BlueprintOverride)
    void DoExitState(FCk_Handle_SmState InHandle, ECk_Sm_NetContext InNetContext)
    {
        auto Player = ck::Ctx(InHandle);
        auto Operator = Player.As_Operator(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(Operator))
        { return; }

        auto Station = Operator.Get_Station();
        if (ck::Is_NOT_Valid(Station) || Station.Get_IsOperatedBy(Player) == false)
        { return; }

        Station.Request_Release(FMars_Request_Station_Release(Player, EMars_Station_ReleaseReason::StationRequested));
    }
}

//--------------------------------------------------------------------------------------------------------------------------
// PoseLock
//--------------------------------------------------------------------------------------------------------------------------

// Glides the capsule to the stand (feet on the stand, facing its +X) over utils_station::Get_EngageSeconds, each step a
// teleport-set so the movement component does not drag against it, and keeps the body yaw off the view until exit. No
// actor (headless) = nothing to do.
class UMars_SmTask_Operating_PoseLock : UCk_SmTask_EntityScript
{
    default _TaskMode = ECk_SmTaskMode::Tick;

    private ACharacter _Character;
    private FVector _StartLocation;
    private FVector _TargetLocation;
    private float64 _StartYaw = 0.0;
    private float64 _DeltaYaw = 0.0;
    private float32 _GlideSeconds = 0.0f;
    private float32 _GlideElapsed = 0.0f;
    private bool _Gliding = false;

    UFUNCTION(BlueprintOverride)
    void DoEnterTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        _Gliding = false;

        auto Player = ck::Ctx(InHandle);
        _Character = Cast<ACharacter>(utils_owning_actor::TryGet_EntityOwningActor_Recursive(Player));
        if (ck::Is_NOT_Valid(_Character))
        { return; }

        auto Operator = Player.As_Operator(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(Operator))
        { return; }

        auto Station = Operator.Get_Station();
        if (ck::Is_NOT_Valid(Station))
        { return; }

        _Character.bUseControllerRotationYaw = false;
        _Character.CharacterMovement.StopMovementImmediately();

        const auto Stand = Station.Get_StandWorld();
        _StartLocation = _Character.GetActorLocation();
        _TargetLocation = Stand.GetLocation() + FVector(0.0, 0.0, _Character.CapsuleComponent.GetScaledCapsuleHalfHeight());
        _StartYaw = _Character.GetActorRotation().Yaw;
        // Shortest way round.
        _DeltaYaw = Stand.Rotator().Yaw - _StartYaw;
        while (_DeltaYaw > 180.0)
        { _DeltaYaw -= 360.0; }

        while (_DeltaYaw < -180.0)
        { _DeltaYaw += 360.0; }


        const auto Distance = float32((_TargetLocation - _StartLocation).Size());
        _GlideSeconds = utils_station::Get_EngageSeconds(Distance, float32(_DeltaYaw), Station.Get_Spec().EngageMaxSeconds);
        _GlideElapsed = 0.0f;
        _Gliding = true;

        if (_GlideSeconds <= 0.0f)
        { Apply_Pose(1.0f); }
    }

    // Must return Running every frame: a Succeeded/Failed result would end the task while Operating is still active.
    UFUNCTION(BlueprintOverride)
    ECk_SmTaskResult DoTick(FCk_Handle_SmTask InHandle, FCk_Time InDeltaT, ECk_Sm_NetContext InNetContext)
    {
        if (_Gliding == false || ck::Is_NOT_Valid(_Character))
        { return ECk_SmTaskResult::Running; }

        _GlideElapsed += float32(InDeltaT.Get_Seconds());
        Apply_Pose(Math::Clamp(_GlideElapsed / _GlideSeconds, 0.0f, 1.0f));
        return ECk_SmTaskResult::Running;
    }

    UFUNCTION(BlueprintOverride)
    void DoExitTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        _Gliding = false;

        if (ck::IsValid(_Character))
        { _Character.bUseControllerRotationYaw = true; }

        _Character = nullptr;
    }

    private void Apply_Pose(float32 InAlpha)
    {
        const auto Location = _StartLocation + (_TargetLocation - _StartLocation) * float64(InAlpha);
        const auto Rotation = FRotator(0.0, _StartYaw + _DeltaYaw * float64(InAlpha), 0.0);
        _Character.SetActorLocationAndRotation(Location, Rotation, true);

        if (InAlpha >= 1.0f)
        { _Gliding = false; }
    }
}

//--------------------------------------------------------------------------------------------------------------------------
// Camera
//--------------------------------------------------------------------------------------------------------------------------

// Snaps the view to the stand's facing pitched by CameraPitchOffset. Free: the yaw is fenced to CameraYawHalfAngle each
// side of the stand's facing. Captured: the orientation control is frozen (the station reads the look delta). Exit restores
// the full yaw range and the orientation control. No PlayerViewpoint (headless) = nothing to do.
class UMars_SmTask_Operating_Camera : UCk_SmTask_EntityScript
{
    default _TaskMode = ECk_SmTaskMode::EnterExitOnly;

    private FCk_Handle_Camera _Camera;
    private bool _Frozen = false;

    UFUNCTION(BlueprintOverride)
    void DoEnterTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        _Frozen = false;

        auto Player = ck::Ctx(InHandle);
        auto Viewpoint = Player.As_PlayerViewpoint(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(Viewpoint))
        { return; }

        _Camera = Viewpoint.Get_Camera();
        if (ck::Is_NOT_Valid(_Camera))
        { return; }

        auto Operator = Player.As_Operator(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(Operator))
        { return; }

        auto Station = Operator.Get_Station();
        if (ck::Is_NOT_Valid(Station))
        { return; }

        const auto Spec = Station.Get_Spec();
        const auto StandYaw = Station.Get_StandWorld().Rotator().Yaw;
        _Camera.Request_SnapBoomRotation(FRotator(Spec.CameraPitchOffset, StandYaw, 0.0));

        if (Spec.LookControl == EMars_Station_LookControl::Free)
        {
            _Camera.Request_Set_OrientationYawLimits(
                float32(StandYaw - Spec.CameraYawHalfAngle), float32(StandYaw + Spec.CameraYawHalfAngle));
        }
        else
        {
            _Camera.Request_Set_HasOrientationControl(false);
            _Frozen = true;
        }
    }

    UFUNCTION(BlueprintOverride)
    void DoExitTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        if (ck::IsValid(_Camera))
        {
            _Camera.Request_Set_OrientationYawLimits(-180.0f, 180.0f);
            if (_Frozen)
            { _Camera.Request_Set_HasOrientationControl(true); }
        }

        _Frozen = false;
        _Camera = FCk_Handle_Camera();
    }
}

//--------------------------------------------------------------------------------------------------------------------------
// Grip
//--------------------------------------------------------------------------------------------------------------------------

// Starts the station's grip interaction so the gloves Hold on the station exactly as on a lever: the grip target joins the
// resolver, the interaction starts from the player, and the Hands sub-SM's resolver binds reach for it (timed) once it is
// a best Operate target.
//
// The grip has its own resolver intent and channel (InteractionIntent.Mars.Operate -> InteractionChannel.Mars.Operate):
// the resolver only resolves best targets for an OPEN intent (CkInteractionResolver_Processor.cpp DoUpdateCachedTargets
// loops the active intents), and this task is the only thing that opens and closes Operate. The grip never touches the
// Use intent, so E while operating (UMars_SmTask_UseIntentToResolver opening / closing Use) cannot disturb the gloves.
// Exit cancels the interaction, removes the target and closes Operate.
class UMars_SmTask_Operating_Grip : UCk_SmTask_EntityScript
{
    default _TaskMode = ECk_SmTaskMode::EnterExitOnly;

    private FCk_Handle _Player;
    private FCk_Handle_InteractionResolver _Resolver;
    private FCk_Handle_InteractTarget _Target;

    UFUNCTION(BlueprintOverride)
    void DoEnterTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        _Player = ck::Ctx(InHandle);
        _Resolver = _Player.As_InteractionResolver(ECk_SanityCheck::UnChecked);

        auto Operator = _Player.As_Operator(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(Operator) || ck::Is_NOT_Valid(_Resolver))
        { return; }

        auto Station = Operator.Get_Station();
        if (ck::Is_NOT_Valid(Station))
        { return; }

        _Target = Station.Get_GripTarget();
        if (ck::Is_NOT_Valid(_Target))
        { return; }

        _Resolver.Request_AddInteractTarget(FCk_Request_InteractionResolver_AddInteractTarget(_Target));
        _Resolver.Request_StartIntent(FCk_Request_InteractionResolver_StartIntent(
            GameplayTags::ResolveGameplayTag(n"InteractionIntent.Mars.Operate")));
        _Target.Request_StartInteraction(FCk_Try_InteractTarget_StartInteraction(_Player, _Player));
    }

    UFUNCTION(BlueprintOverride)
    void DoExitTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        if (ck::IsValid(_Target))
        { _Target.Request_CancelInteraction(FCk_Request_InteractTarget_CancelInteraction(_Player)); }

        if (ck::IsValid(_Resolver) && ck::IsValid(_Target))
        {
            _Resolver.Request_RemoveInteractTarget(FCk_Request_InteractionResolver_RemoveInteractTarget(_Target));
            _Resolver.Request_StopIntent(FCk_Request_InteractionResolver_StopIntent(
                GameplayTags::ResolveGameplayTag(n"InteractionIntent.Mars.Operate")));
        }

        _Player = FCk_Handle();
        _Resolver = FCk_Handle_InteractionResolver();
        _Target = FCk_Handle_InteractTarget();
    }
}

//--------------------------------------------------------------------------------------------------------------------------
// LeaveIntent
//--------------------------------------------------------------------------------------------------------------------------

// Mars.Intent.Back pressed -> the operator asks its station to release it.
class UMars_SmTask_Operating_LeaveIntent : UMars_SmTask_IntentEdges
{
    private FCk_Handle_Operator _Operator;
    private FGameplayTag _BackIntent;

    UFUNCTION(BlueprintOverride)
    void DoEnterTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        _Operator = ck::Ctx(InHandle).As_Operator(ECk_SanityCheck::UnChecked);
        _BackIntent = GameplayTags::ResolveGameplayTag(n"Mars.Intent.Back");

        Super::DoEnterTask(InHandle, InNetContext);
    }

    UFUNCTION(BlueprintOverride)
    void DoExitTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        Super::DoExitTask(InHandle, InNetContext);

        _Operator = FCk_Handle_Operator();
    }

    protected void OnIntentPressed(FGameplayTag InIntent) override
    {
        if (InIntent != _BackIntent || ck::Is_NOT_Valid(_Operator))
        { return; }

        _Operator.Request_Leave();
    }
}

//--------------------------------------------------------------------------------------------------------------------------
// Hints
//--------------------------------------------------------------------------------------------------------------------------

// Owns the legend rows keyed k_OwnerKey while operating: "leave" on IA_Back. A station's minigame registers its own rows
// under the same key (the exit's owner-unregister clears them too).
class UMars_SmTask_Operating_Hints : UCk_SmTask_EntityScript
{
    default _TaskMode = ECk_SmTaskMode::EnterExitOnly;

    private const FName k_OwnerKey = n"Station";

    private FCk_Handle_ActionHintDisplay _Display;

    UFUNCTION(BlueprintOverride)
    void DoEnterTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        _Display = ck::Ctx(InHandle).As_ActionHintDisplay(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(_Display))
        { return; }

        _Display.Request_RegisterHint(FMars_ActionHint_Spec(mars::Mars_IA_Back, FText::FromString("leave"), 9, k_OwnerKey));
    }

    UFUNCTION(BlueprintOverride)
    void DoExitTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        if (ck::IsValid(_Display))
        { _Display.Request_UnregisterHintsByOwner(FMars_Request_ActionHintDisplay_UnregisterByOwner(k_OwnerKey)); }

        _Display = FCk_Handle_ActionHintDisplay();
    }
}
