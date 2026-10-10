// The Alive sub-SM's Operating state: the player holds a station (FMars_Fragment_Operator.Station is valid). Entering it
// tears Locomotion down - its movement and every free-roam interaction task - which is what locks the body in place and
// leaves the keys to the station. Leaving it any other way than the station's release (Alive -> Downed tears it down)
// releases the station from DoExitState.

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

    // A teardown that did not come from the station's release (Downed): release it, scoped to this player. It reaches the
    // arbiter on its next drain, so the back-ref may lag a frame; nothing re-enters Operating meanwhile (Alive is gone).
    UFUNCTION(BlueprintOverride)
    void DoExitState(FCk_Handle_SmState InHandle, ECk_Sm_NetContext InNetContext)
    {
        auto Player = ck::Ctx(InHandle);
        auto Station = Player.As_Operator().Get_Station();
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
        if (utils_player_sm::Get_IsOwningCopy(InHandle, InNetContext) == false)
        { return; }

        auto Player = ck::Ctx(InHandle);
        _Character = Cast<ACharacter>(utils_owning_actor::TryGet_EntityOwningActor_Recursive(Player));
        if (ck::Is_NOT_Valid(_Character))
        { return; }

        // Operating is entered only while the operator holds a station.
        auto Station = Player.As_Operator().Get_Station();
        if (ck::EnsureIfNot(ck::IsValid(Station), "[Operating] PoseLock entered with no station"))
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
        const auto bTeleport = true;
        _Character.SetActorLocationAndRotation(Location, Rotation, bTeleport);

        if (InAlpha >= 1.0f)
        { _Gliding = false; }
    }
}

//--------------------------------------------------------------------------------------------------------------------------
// Camera
//--------------------------------------------------------------------------------------------------------------------------

// Snaps the view to the stand's facing pitched by Camera.PitchOffset. Free: the yaw is fenced to Camera.YawHalfAngle each
// side of the stand's facing. Captured: the view is held still (the player viewpoint's Station hold; the station reads the
// look delta). A station with a View node also gets UMars_CameraLayer_Station, which blends the view to that node so the
// framing is the station's and not the operator's eye height. Exit removes the layer and restores the full yaw range, and
// releases the hold. No PlayerViewpoint (headless) = nothing to do.
class UMars_SmTask_Operating_Camera : UCk_SmTask_EntityScript
{
    default _TaskMode = ECk_SmTaskMode::EnterExitOnly;

    private FCk_Handle_PlayerViewpoint _Viewpoint;
    private FCk_Handle_Camera _Camera;
    // This task holds the viewpoint's Station hold.
    private bool _HoldsView = false;
    private bool _HasStationView = false;

    UFUNCTION(BlueprintOverride)
    void DoEnterTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        _HoldsView = false;
        _HasStationView = false;
        if (utils_player_sm::Get_IsOwningCopy(InHandle, InNetContext) == false)
        { return; }

        auto Player = ck::Ctx(InHandle);
        _Viewpoint = Player.As_PlayerViewpoint(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(_Viewpoint))
        { return; }

        _Camera = _Viewpoint.Get_Camera();
        if (ck::EnsureIfNot(ck::IsValid(_Camera), "[Operating] the player's viewpoint has no camera"))
        { return; }

        auto Station = Player.As_Operator().Get_Station();
        if (ck::EnsureIfNot(ck::IsValid(Station), "[Operating] Camera entered with no station"))
        { return; }

        const auto CameraSpec = Station.Get_Spec().Camera;
        const auto StandYaw = Station.Get_StandWorld().Rotator().Yaw;
        _Camera.Request_SnapBoomRotation(FRotator(CameraSpec.PitchOffset, StandYaw, 0.0));

        const auto View = Station.Get_View();
        if (ck::IsValid(View))
        {
            auto Request = FCk_Request_Camera_AddLayer(UMars_CameraLayer_Station);
            Request.Set_StackingBehavior(ECk_Camera_StackingBehavior::OneOnly);
            Request.Set_BlendInTime(FCk_Time(utils_station::k_ViewBlendSeconds));
            Request.Set_CameraTarget(FCk_Camera_Target(View, ECk_Camera_TargetMode::ViewTarget));
            _Camera.Request_AddLayer(Request);
            _HasStationView = true;
        }

        if (CameraSpec.LookControl == EMars_Station_LookControl::Free)
        {
            _Camera.Request_Set_OrientationYawLimits(
                float32(StandYaw - CameraSpec.YawHalfAngle), float32(StandYaw + CameraSpec.YawHalfAngle));
        }
        else
        {
            _Viewpoint.Request_HoldView(FMars_Request_PlayerViewpoint_HoldView(EMars_PlayerViewpoint_ViewHolder::Station));
            _HoldsView = true;
        }
    }

    // Restoring the yaw limits creates an attribute-modifier entity; when the exit is the world being torn down (PIE stopped
    // while operating) the ECS world refuses new entities, so the restore is skipped: there is no camera left to free.
    UFUNCTION(BlueprintOverride)
    void DoExitTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        if (ck::IsValid(_Camera) && _Camera.Get_CanCreateEntity())
        {
            if (_HasStationView)
            {
                auto Request = FCk_Request_Camera_RemoveLayer(UMars_CameraLayer_Station);
                Request.Set_BlendOutTime(FCk_Time(utils_station::k_ViewBlendSeconds));
                _Camera.Request_RemoveLayer(Request);
            }

            _Camera.Request_Set_OrientationYawLimits(-180.0f, 180.0f);
        }

        if (_HoldsView && ck::IsValid(_Viewpoint))
        { _Viewpoint.Request_ReleaseView(FMars_Request_PlayerViewpoint_ReleaseView(EMars_PlayerViewpoint_ViewHolder::Station)); }

        _HoldsView = false;
        _HasStationView = false;
        _Camera = FCk_Handle_Camera();
        _Viewpoint = FCk_Handle_PlayerViewpoint();
    }
}

// The station view layer: its camera target (the station's View node, ViewTarget) carries the framing. The task above holds
// the view, so the layer does nothing on enter or exit.
class UMars_CameraLayer_Station : UCk_CameraLayer_EntityScript
{
}

//--------------------------------------------------------------------------------------------------------------------------
// Grip
//--------------------------------------------------------------------------------------------------------------------------

namespace utils_player_sm
{
    // The ticks past Get_GripLandSeconds after which a station grip the gloves have not taken never will be: the gloves
    // re-read the resolver only as they come to rest, release or return, and those edges reach the grip's watch a state
    // machine step and a drain later.
    const int32 k_GripLandGraceTicks = 2;

    // The longest InHands take to take a station's grip they will take: a push they are finishing (a drop or throw just
    // before Use) and a reach out (the gloves refuse a reach until a push ends, then reach again from rest).
    float32 Get_GripLandSeconds(const FCk_Handle_FPHands& InHands)
    {
        const auto& Spec = InHands.Get_Spec();
        return utils_fphands::Get_PushSeconds(Spec.Push) + Spec.Reach.Grab.OutSeconds;
    }
}

// Where Operating_Grip's watch on the gloves stands.
enum EMars_Operating_GripLanding
{
    // Nothing to watch: no gloves (headless), no grip, or the station already given up.
    Unwatched,
    // The grip interaction started; the gloves have not taken its reach yet.
    Waiting,
    // The gloves hold the grip.
    Landed
}

// Starts the station's grip interaction so the gloves Hold on the station exactly as on a lever: the grip target joins the
// resolver, the interaction starts from the player, and the Hands sub-SM's resolver binds reach for it (timed) once it is
// a best Operate target.
//
// The grip has its own resolver intent and channel (InteractionIntent.Mars.Operate -> InteractionChannel.Mars.Operate):
// the resolver only resolves best targets for an OPEN intent (CkInteractionResolver_Processor.cpp DoUpdateCachedTargets
// loops the active intents), and this task is the only thing that opens and closes Operate. The grip never touches the
// Use intent, so E while operating (UMars_SmTask_UseIntentToResolver opening / closing Use) cannot disturb the gloves.
// Exit cancels the interaction, removes the target and closes Operate. The close needs only the resolver: the grip target
// dies with its station, and a station destroyed under the operator must not leave Operate open.
//
// The gloves must take the grip (Hold on its target) within utils_player_sm::Get_GripLandSeconds and k_GripLandGraceTicks
// more. A reach they refuse outright (out of reach: a two-handed hold; the subject gone; malformed), or one they never
// take, leaves the operator nothing to hold, so the operator leaves the station (Request_Leave, as Back does) instead of
// standing there Operating with the station held. A reach refused only for now (busy, superseded, a push starting, a pickup
// riding in) is asked again as the gloves come to rest; the bound covers that.
class UMars_SmTask_Operating_Grip : UCk_SmTask_EntityScript
{
    default _TaskMode = ECk_SmTaskMode::Tick;

    private FCk_Handle _Player;
    private FCk_Handle_InteractionResolver _Resolver;
    private FCk_Handle_InteractTarget _Target;
    private FCk_Handle_FPHands _Hands;
    private EMars_Operating_GripLanding _Landing = EMars_Operating_GripLanding::Unwatched;
    // How long the gloves have had to take the grip, and the ticks since that passed Get_GripLandSeconds.
    private float32 _WaitSeconds = 0.0f;
    private int32 _TicksPastBound = 0;

    UFUNCTION(BlueprintOverride)
    void DoEnterTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        _Landing = EMars_Operating_GripLanding::Unwatched;
        if (utils_player_sm::Get_IsOwningCopy(InHandle, InNetContext) == false)
        { return; }

        _Player = ck::Ctx(InHandle);
        _Resolver = _Player.As_InteractionResolver();

        auto Station = _Player.As_Operator().Get_Station();
        if (ck::EnsureIfNot(ck::IsValid(Station), "[Operating] Grip entered with no station"))
        { return; }

        // A station without a grip interactable leaves the gloves at rest.
        _Target = Station.Get_GripTarget();
        if (ck::Is_NOT_Valid(_Target))
        { return; }

        _Resolver.Request_AddInteractTarget(FCk_Request_InteractionResolver_AddInteractTarget(_Target));
        _Resolver.Request_StartIntent(FCk_Request_InteractionResolver_StartIntent(GameplayTags::InteractionIntent_Mars_Operate));
        _Target.Request_StartInteraction(FCk_Try_InteractTarget_StartInteraction(_Player, _Player));

        // Without gloves nothing takes the grip, and nothing has to.
        _Hands = _Player.As_FPHands(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(_Hands))
        { return; }

        _Hands.BindTo_OnReachRefused(FMars_Delegate_FPHands_OnReachRefused(this, n"OnReachRefused"));
        _Landing = EMars_Operating_GripLanding::Waiting;
        _WaitSeconds = 0.0f;
        _TicksPastBound = 0;
    }

    // Must return Running every frame: a Succeeded/Failed result would end the task while Operating is still active.
    UFUNCTION(BlueprintOverride)
    ECk_SmTaskResult DoTick(FCk_Handle_SmTask InHandle, FCk_Time InDeltaT, ECk_Sm_NetContext InNetContext)
    {
        if (_Landing != EMars_Operating_GripLanding::Waiting)
        { return ECk_SmTaskResult::Running; }

        if (_Hands.Get_Phase() == EMars_FPHands_Phase::Hold && _Hands.Get_IsReachTarget(_Target))
        {
            Stop_Watching(EMars_Operating_GripLanding::Landed);
            return ECk_SmTaskResult::Running;
        }

        _WaitSeconds += float32(InDeltaT.Get_Seconds());
        if (_WaitSeconds < utils_player_sm::Get_GripLandSeconds(_Hands))
        { return ECk_SmTaskResult::Running; }

        _TicksPastBound += 1;
        if (_TicksPastBound < utils_player_sm::k_GripLandGraceTicks)
        { return ECk_SmTaskResult::Running; }

        Give_Up();
        return ECk_SmTaskResult::Running;
    }

    UFUNCTION(BlueprintOverride)
    void DoExitTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        Stop_Watching(EMars_Operating_GripLanding::Unwatched);

        if (ck::IsValid(_Target))
        { _Target.Request_CancelInteraction(FCk_Request_InteractTarget_CancelInteraction(_Player)); }

        if (ck::IsValid(_Resolver))
        {
            if (ck::IsValid(_Target))
            { _Resolver.Request_RemoveInteractTarget(FCk_Request_InteractionResolver_RemoveInteractTarget(_Target)); }

            _Resolver.Request_StopIntent(FCk_Request_InteractionResolver_StopIntent(GameplayTags::InteractionIntent_Mars_Operate));
        }

        _Player = FCk_Handle();
        _Resolver = FCk_Handle_InteractionResolver();
        _Target = FCk_Handle_InteractTarget();
        _Hands = FCk_Handle_FPHands();
    }

    // The operator gives the station up: the station releases it (OperatorRequested) and this state exits.
    private void Give_Up()
    {
        Stop_Watching(EMars_Operating_GripLanding::Unwatched);

        auto Operator = _Player.As_Operator();
        Operator.Request_Leave();
    }

    private void Stop_Watching(EMars_Operating_GripLanding InLanding)
    {
        if (ck::IsValid(_Hands))
        { _Hands.UnbindFrom_OnReachRefused(FMars_Delegate_FPHands_OnReachRefused(this, n"OnReachRefused")); }

        _Landing = InLanding;
    }

    UFUNCTION()
    private void OnReachRefused(FCk_Handle_FPHands InHands, FCk_Handle_InteractTarget InTarget, EMars_FPHands_ReachKind InKind,
        EMars_FPHands_ReachRefusal InReason)
    {
        if (_Landing != EMars_Operating_GripLanding::Waiting || InTarget != _Target)
        { return; }

        const auto IsFinal = InReason == EMars_FPHands_ReachRefusal::OutOfReach || InReason == EMars_FPHands_ReachRefusal::SubjectGone
            || InReason == EMars_FPHands_ReachRefusal::Malformed;
        if (IsFinal)
        { Give_Up(); }
    }
}

//--------------------------------------------------------------------------------------------------------------------------
// LeaveIntent
//--------------------------------------------------------------------------------------------------------------------------

// Mars.Intent.Back pressed -> the operator asks its station to release it.
class UMars_SmTask_Operating_LeaveIntent : UMars_SmTask_IntentEdges
{
    private FCk_Handle_Operator _Operator;

    UFUNCTION(BlueprintOverride)
    void DoEnterTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        _Operator = ck::Ctx(InHandle).As_Operator();

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
        if (InIntent != GameplayTags::Mars_Intent_Back)
        { return; }

        _Operator.Request_Leave();
    }
}

//--------------------------------------------------------------------------------------------------------------------------
// Hints
//--------------------------------------------------------------------------------------------------------------------------

// Owns the legend rows keyed k_OwnerKey while operating: "leave" on IA_Back. The shared station-feed rows register under
// the same key (StationFeed_OperatorHints, which unregisters its own on exit); each station's minigame rows use their own
// key (Cutting, Searing, Fry, Tumbler) and their own task's exit unregisters them.
class UMars_SmTask_Operating_Hints : UCk_SmTask_EntityScript
{
    default _TaskMode = ECk_SmTaskMode::EnterExitOnly;

    private const FName k_OwnerKey = n"Station";

    private FCk_Handle_ActionHintDisplay _Display;

    UFUNCTION(BlueprintOverride)
    void DoEnterTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        if (utils_player_sm::Get_IsOwningCopy(InHandle, InNetContext) == false)
        { return; }

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
