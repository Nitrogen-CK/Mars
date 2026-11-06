// The cellar bat's art (Tools/Blender/mars_monsters/cellar_bat_r01, imported under /Game/ArtCandidates/CellarBat/R01): the
// skinned mesh, its root at the body centre in the flight bind pose, and the AnimBP that reparents to
// UMars_CellarBat_AnimInstance. Change the art and these together.
namespace utils_bat
{
    const FString CandidateMeshPath = "/Game/ArtCandidates/CellarBat/R01/Meshes/CellarBat_R01_Mars_SK.CellarBat_R01_Mars_SK";
    // The final AnimBP on the final skeleton (Tools/LevelDesign/cellar_bat_r01_review/cellar_bat_animbp_manifest_final.json).
    // CellarBat_R01_Mars_ABP is the 6b-2 prep build on the blockout skeleton, kept on disk.
    const FString CandidateAnimClassPath = "/Game/ArtCandidates/CellarBat/R01/Animation/CellarBat_R01_Final_Mars_ABP.CellarBat_R01_Final_Mars_ABP_C";

    // Sockets read off the mesh when it has them: the mouth (checked against the kernel's MouthOffset) and the perch contact
    // (pinned to the perch anchor while it hangs; it rides the pelvis and sits on the bar centre in RoostIdle).
    const FName MouthSocket = n"Mouth";
    const FName PerchSocket = n"Perch";

    // The candidate mesh's Mouth socket in its bind pose, root frame (head bone + (-4.455, 1.084, 0); Phase 5 readback
    // export/unreal_readback_final.json). The entity script puts it in the kernel's Spec.Swoop.Blow.MouthOffset before Add,
    // so the swoop sweeps from the drawn mouth headless as well; OnBodyAdded checks it against the live socket.
    const FVector CandidateMouthOffset = FVector(7.703, 0.0, 3.749);

    // A mouth socket further than this from the kernel's MouthOffset is reported (the blow would not land where it is drawn).
    const float64 MouthMismatchCm = 5.0;

    // How fast it turns over into (and out of) its hanging pose (turns a second).
    const float32 HangRate = 3.0f;

    // Banks up to this far (degrees) at its MaxTurnRate (the placeholder only: the AnimBP banks the real mesh).
    const float64 PlaceholderBankDegrees = 35.0;

    // The bank is the turn still to come: a heading that trails the root's yaw at BankFollowRate (FInterpTo speed), banked
    // fully when it trails by BankFullDegrees. The crowd agent's FaceAngle3D yaws the root at MaxTurnRate (360 deg/s), so a
    // path corner is a 0.2 s yaw burst (one frame at a capture's 3 fps): a bank read off the instantaneous turn rate is a
    // blip, this one lasts through the turn and eases out after it.
    const float32 BankFollowRate = 3.0f;
    const float64 BankFullDegrees = 40.0;

    // How fast the drawn bank follows its target (FInterpTo speed) and how fast the speed the blend space reads follows the
    // measured one (a frame-difference that drops to 0 on a frame the root did not move).
    const float32 BankSmoothRate = 8.0f;
    const float32 SpeedSmoothRate = 6.0f;

    // The altitude bob (presentation only, on the look node, never the root): a wingbeat-rate lift (BobHz, near the Hover
    // clip's 16 frames at 30 fps) plus a slow drift (DriftHz), both along world up, while it flies under its own wings;
    // faded in and out at BobFadeRate, none while it hangs, brakes for the perch, dives, falls or lies.
    const float64 BobAmplitudeCm = 4.0;
    const float64 BobHz = 1.9;
    const float64 DriftAmplitudeCm = 8.0;
    const float64 DriftHz = 0.37;
    const float32 BobFadeRate = 3.0f;

    bool Get_IsBobbingPhase(EMars_Bat_Phase InPhase)
    {
        return InPhase == EMars_Bat_Phase::Patrolling || InPhase == EMars_Bat_Phase::Approaching || InPhase == EMars_Bat_Phase::Returning ||
            InPhase == EMars_Bat_Phase::Hovering || InPhase == EMars_Bat_Phase::Searching || InPhase == EMars_Bat_Phase::Retreating ||
            InPhase == EMars_Bat_Phase::Recovering;
    }
}

// Placeable enemy: the cellar bat, composed by utils_bat::Add on the root at SpawnTransform (the body centre; place it at the
// hang point, Spec.Roost.HangOffset under its perch). This script is the assembly: under the root it builds a presentation
// node that it turns over while the bat hangs (never the root, which the crowd agent owns) and hangs everything seen off
// it: the candidate skeletal mesh with its AnimBP, or, until those assets exist, a visible placeholder (a body and two wing
// slabs). Every frame it pushes the kernel's phase and telemetry into the anim instance.
class UMars_CellarBat_EntityScript : UCk_GenericEntityScript_UE
{
    default _ShowInPlaceActors = true;
    default _Replication = ECk_Replication::DoesNotReplicate;

    UPROPERTY(ExposeOnSpawn)
    FTransform SpawnTransform = FTransform::Identity;

    UPROPERTY(ExposeOnSpawn)
    FMars_Bat_Spec Spec;

    UPROPERTY(ExposeOnSpawn)
    bool WithVisuals = true;

    UPROPERTY()
    TSoftObjectPtr<USkeletalMesh> Mesh = TSoftObjectPtr<USkeletalMesh>(FSoftObjectPath(utils_bat::CandidateMeshPath));

    UPROPERTY()
    TSoftClassPtr<UAnimInstance> AnimClass = TSoftClassPtr<UAnimInstance>(FSoftObjectPath(utils_bat::CandidateAnimClassPath));

    // The art's Mouth socket in the mesh frame: replaces Spec.Swoop.Blow.MouthOffset before Add (unset: the Spec's own).
    UPROPERTY()
    TOptional<FVector> MouthSocketOffset = utils_bat::CandidateMouthOffset;

    // The AnimBP's clips carry the hang (RoostIdle, RoostAlert and Perch hang inverted from the pelvis with the root
    // upright), so the presentation node only levels the body and pins the Perch socket to the anchor. Off, or with no
    // AnimBP (the loop clip, the bind pose, the placeholder): the node turns the body over itself (roll 180).
    UPROPERTY()
    bool ClipsHang = true;

    // Played on a loop when AnimClass is unset or not loadable (a stand-in until the AnimBP exists; the review preset points
    // it at the blockout flap). Unset = the mesh holds its bind pose.
    UPROPERTY()
    TSoftObjectPtr<UAnimSequence> LoopClip;

    // The mesh's offset under the presentation node (the art's root is the body centre, so identity unless the import says
    // otherwise).
    UPROPERTY()
    FTransform MeshOffset = FTransform::Identity;

    // One log line per phase change, route outcome and swoop result, with the script's own clock and the bat's location
    // (the review preset turns it on; the PIE review reads them back from the log).
    UPROPERTY()
    bool LogPhases = false;

    // With LogPhases: one "[CellarBat] bank" line this often (s): root yaw and pitch, both turn-rate sources and the bank.
    private const float64 BankLogInterval = 0.2;

    private FCk_Handle_Bat _Bat;
    private float64 _Clock = 0.0;
    private FCk_Handle_SceneNode _LookNode;
    private USkeletalMeshComponent _Body;
    private UMars_CellarBat_AnimInstance _Anim;
    private bool _UsesPlaceholder = false;
    private float32 _Hang = 1.0f;
    private float32 _Down = 0.0f;
    private float32 _Bank = 0.0f;
    private TOptional<float64> _TrailingYaw;
    private float32 _Speed = 0.0f;
    private float32 _BobAlpha = 0.0f;
    private float64 _BobClock = 0.0;
    private FTransform _WrittenLook = FTransform::Identity;
    private TOptional<FVector> _PerchSocketLocal;
    private float64 _NextBankLog = 0.0;

    UFUNCTION(BlueprintOverride)
    ECk_EntityScript_ConstructionFlow DoConstruct(FCk_Handle& InHandle)
    {
        InHandle.Request_OverrideToSelf();
        utils_handle::Set_DebugName(InHandle, n"CellarBat");

        auto Root = utils_transform::Add(InHandle, SpawnTransform, ECk_Replication::DoesNotReplicate);
        auto Composed = Spec;
        if (MouthSocketOffset.IsSet())
        { Composed.Swoop.Blow.MouthOffset = MeshOffset.TransformPosition(MouthSocketOffset.GetValue()); }

        _Bat = utils_bat::Add(Root, Composed);
        if (ck::Is_NOT_Valid(_Bat))
        { return ECk_EntityScript_ConstructionFlow::Finished; }

        if (WithVisuals)
        {
            BuildLook(Root);
            utils_timer::Create_Tick(InHandle, FCk_Delegate_Timer(this, n"OnTick"));
        }

        if (LogPhases)
        { BindLogs(); }

        return ECk_EntityScript_ConstructionFlow::Finished;
    }

    FCk_Handle_Bat Get_Bat() const
    {
        return _Bat;
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Review log
    //----------------------------------------------------------------------------------------------------------------------

    private void BindLogs()
    {
        _Bat.BindTo_OnPhaseChanged(FMars_Delegate_Bat_OnPhaseChanged(this, n"OnLogPhaseChanged"));
        _Bat.BindTo_OnRouteOutcome(FMars_Delegate_Bat_OnRouteOutcome(this, n"OnLogRouteOutcome"));
        _Bat.BindTo_OnSwoopLanded(FMars_Delegate_Bat_OnSwoopLanded(this, n"OnLogSwoopLanded"));
        _Bat.BindTo_OnSwoopCancelled(FMars_Delegate_Bat_OnSwoopCancelled(this, n"OnLogSwoopCancelled"));
    }

    private FString Get_LogStamp() const
    {
        const auto Here = _Bat.Get_Location();
        return f"t={_Clock :.2} at ({Here.X :.0}, {Here.Y :.0}, {Here.Z :.0})";
    }

    UFUNCTION()
    private void OnLogPhaseChanged(FCk_Handle_Bat InBat, EMars_Bat_Phase InFrom, EMars_Bat_Phase InTo)
    {
        Log(f"[CellarBat] phase {InFrom} -> {InTo} {Get_LogStamp()}");
    }

    UFUNCTION()
    private void OnLogRouteOutcome(FCk_Handle_Bat InBat, int32 InGeneration, EMars_Bat_RouteOutcome InOutcome)
    {
        Log(f"[CellarBat] route {InGeneration} {InOutcome} in {_Bat.Get_Phase()} {Get_LogStamp()}");
    }

    UFUNCTION()
    private void OnLogSwoopLanded(FCk_Handle_Bat InBat, int32 InGeneration, FCk_Handle_HitZone InZone)
    {
        Log(f"[CellarBat] swoop {InGeneration} landed on [{InZone.ToString()}] {Get_LogStamp()}");
    }

    UFUNCTION()
    private void OnLogSwoopCancelled(FCk_Handle_Bat InBat, int32 InGeneration, EMars_Bat_SwoopCancel InReason)
    {
        Log(f"[CellarBat] swoop {InGeneration} cancelled {InReason} {Get_LogStamp()}");
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Assembly
    //----------------------------------------------------------------------------------------------------------------------

    private void BuildLook(FCk_Handle_Transform& InRoot)
    {
        _LookNode = utils_scene_node::Create(InRoot, FTransform::Identity);
        if (FApp::CanEverRender() == false)
        { return; }

        USkeletalMesh Loaded = Mesh.IsNull() ? nullptr : System::LoadAsset_Blocking(Mesh);
        if (ck::Is_NOT_Valid(Loaded))
        {
            Warning(f"[CellarBat] the candidate mesh [{Mesh.ToSoftObjectPath().ToString()}] is not loadable yet: drawing the placeholder body");
            BuildPlaceholder();
            return;
        }

        auto Params = utils_unreal_component::Make_Params(USkeletalMeshComponent, ECk_UnrealComponent_TickPolicy::DoNotTick, n"CellarBat_Body");
        auto BodyNode = utils_scene_node::Create(_LookNode.As_Transform(), MeshOffset);
        auto Part = utils_unreal_component::Add(BodyNode.H(), Params);
        utils_unreal_component::BindTo_OnAdded(Part, FCk_Delegate_UnrealComponent_OnAdded(this, n"OnBodyAdded"));
    }

    // A dark body and two wing slabs on the presentation node: visible, hangable and bankable, never mistaken for the art.
    private void BuildPlaceholder()
    {
        _UsesPlaceholder = true;
        auto Look = _LookNode.As_Transform();
        const auto Colour = FLinearColor(0.16f, 0.11f, 0.1f, 1.0f);

        auto BodyPart = FMars_MeshPart(FTransform(FRotator::ZeroRotator, FVector::ZeroVector, FVector(0.26, 0.16, 0.14)),
            engine::load::Sphere(), assets::load::ProtoGrid_Interactable_Mars_MI(), collision::profile::NoCollision, n"CellarBat_PlaceholderBody");
        BodyPart.PrimaryColor = Colour;
        BodyPart.Tint = EMars_MeshPart_Tint::ProtoGrid;
        Look.Add_MeshPart(this, BodyPart);

        for (int32 Side = -1; Side <= 1; Side += 2)
        {
            auto Wing = FMars_MeshPart(FTransform(FRotator::ZeroRotator, FVector(-2.0, 24.0 * Side, 2.0), FVector(0.22, 0.34, 0.015)),
                engine::load::Cube(), assets::load::ProtoGrid_Interactable_Mars_MI(), collision::profile::NoCollision,
                Side < 0 ? n"CellarBat_PlaceholderWingL" : n"CellarBat_PlaceholderWingR");
            Wing.PrimaryColor = Colour;
            Wing.Tint = EMars_MeshPart_Tint::ProtoGrid;
            Look.Add_MeshPart(this, Wing);
        }
    }

    UFUNCTION()
    private void OnBodyAdded(FCk_Handle_UnrealComponent InHandle)
    {
        _Body = Cast<USkeletalMeshComponent>(utils_unreal_component::Get_Component(InHandle));
        if (ck::EnsureIfNot(ck::IsValid(_Body), f"[CellarBat] [{_Bat.ToString()}] got no USkeletalMeshComponent for its body"))
        { return; }

        _Body.SetCollisionEnabled(ECollisionEnabled::NoCollision);
        _Body.SetSkeletalMeshAsset(System::LoadAsset_Blocking(Mesh));
        // Before the AnimBP poses it: the sockets are read (and the mouth checked) in the bind pose.
        ReadSockets();

        auto LoadedClass = AnimClass.IsNull() ? nullptr : System::LoadClassAsset_Blocking(AnimClass);
        if (ck::IsValid(LoadedClass))
        { _Body.SetAnimInstanceClass(LoadedClass); }
        else
        { PlayLoopClip(); }

        _Anim = Cast<UMars_CellarBat_AnimInstance>(_Body.GetAnimInstance());
        if (ck::IsValid(LoadedClass) && ck::Is_NOT_Valid(_Anim))
        { Warning(f"[CellarBat] the AnimBP [{AnimClass.ToSoftObjectPath().ToString()}] does not derive from UMars_CellarBat_AnimInstance: it gets no telemetry"); }
    }

    // No AnimBP: the stand-in loop when there is one, else the bind pose.
    private void PlayLoopClip()
    {
        UAnimSequence Clip = LoopClip.IsNull() ? nullptr : System::LoadAsset_Blocking(LoopClip);
        if (ck::IsValid(Clip))
        {
            const auto Looping = true;
            _Body.PlayAnimation(Clip, Looping);
            return;
        }

        if (AnimClass.IsNull() == false)
        { Warning(f"[CellarBat] the candidate AnimBP [{AnimClass.ToSoftObjectPath().ToString()}] is not loadable yet and no LoopClip loads: the mesh holds its bind pose"); }
    }

    private void ReadSockets()
    {
        if (_Body.DoesSocketExist(utils_bat::MouthSocket))
        {
            const auto Mouth = _Body.GetSocketTransform(utils_bat::MouthSocket, ERelativeTransformSpace::RTS_Component).GetLocation();
            const auto MouthOnRoot = MeshOffset.TransformPosition(Mouth);
            const auto Kernel = _Bat.Get_Spec().Swoop.Blow.MouthOffset;
            if ((MouthOnRoot - Kernel).Size() > utils_bat::MouthMismatchCm)
            { Warning(f"[CellarBat] the mesh's Mouth socket [{MouthOnRoot.ToString()}] is off the kernel's MouthOffset [{Kernel.ToString()}]: set Spec.Swoop.Blow.MouthOffset to it"); }
        }

        if (_Body.DoesSocketExist(utils_bat::PerchSocket))
        {
            const auto Perch = _Body.GetSocketTransform(utils_bat::PerchSocket, ERelativeTransformSpace::RTS_Component).GetLocation();
            _PerchSocketLocal = MeshOffset.TransformPosition(Perch);
        }
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Every frame
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void OnTick(FCk_Handle_Timer InHandle, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        FCk_Handle Entity = _Bat;
        if (ck::Is_NOT_Valid(_Bat) || utils_entity_lifetime::Get_IsPendingDestroy(Entity, ECk_EntityLifetime_DestructionPhase::BeginDestroy))
        { return; }

        const auto DeltaSeconds = float32(InDeltaT.Get_Seconds());
        _Clock += DeltaSeconds;
        const auto Phase = _Bat.Get_Phase();
        const auto Telemetry = _Bat.Get_Telemetry();
        const auto Bank = UpdateBank(Phase, DeltaSeconds);
        _Speed = Math::FInterpTo(_Speed, Telemetry.Speed, DeltaSeconds, utils_bat::SpeedSmoothRate);

        _BobClock += DeltaSeconds;
        _BobAlpha = Math::FInterpTo(_BobAlpha, utils_bat::Get_IsBobbingPhase(Phase) ? 1.0f : 0.0f, DeltaSeconds, utils_bat::BobFadeRate);
        _Hang = Math::FInterpConstantTo(_Hang, utils_bat::Get_IsHangingPhase(Phase) ? 1.0f : 0.0f, DeltaSeconds, utils_bat::HangRate);
        const auto Down = Phase == EMars_Bat_Phase::Landed || Phase == EMars_Bat_Phase::Dead;
        _Down = Math::FInterpConstantTo(_Down, Down ? 1.0f : 0.0f, DeltaSeconds, utils_bat::HangRate);
        if (Get_PoseHangsItself() && _PerchSocketLocal.IsSet())
        {
            // The clip's pose as last evaluated: the perch contact moves through the hang, the release and the swing.
            const auto Perch = _Body.GetSocketTransform(utils_bat::PerchSocket, ERelativeTransformSpace::RTS_Component).GetLocation();
            _PerchSocketLocal = MeshOffset.TransformPosition(Perch);
        }

        PoseLook(_Bank);
        if (LogPhases && _Clock >= _NextBankLog)
        {
            _NextBankLog = _Clock + BankLogInterval;
            const auto Rot = _Bat.Get_RootTransform().Rotator();
            const auto Trailing = _TrailingYaw.IsSet() ? _TrailingYaw.GetValue() : Rot.Yaw;
            Log(f"[CellarBat] bank {Phase} yaw={Rot.Yaw :.1} trailing={Trailing :.1} pitch={Rot.Pitch :.1} turnRate={Telemetry.SignedTurnRate :.1} raw={Bank :.2} bank={_Bank :.2} speed={Telemetry.Speed :.0} drawnSpeed={_Speed :.0} {Get_LogStamp()}");
        }

        if (ck::IsValid(_Anim))
        {
            auto Frame = FMars_CellarBat_AnimFrame();
            Frame.Phase = Phase;
            Frame.Speed = _Speed;
            Frame.TurnRate = Telemetry.SignedTurnRate;
            Frame.BankAlpha = _Bank;
            Frame.Pitch = Telemetry.Pitch;
            Frame.SwoopAlpha = _Bat.Get_SwoopFrame().Alpha;
            _Anim.Apply(Frame);
        }
    }

    // The bank target (see BankFollowRate): how far the trailing heading is behind the root's yaw, positive turning right.
    // Only in the air under its own wings; the trailing heading snaps to the root while it hangs, falls or lies.
    private float32 UpdateBank(EMars_Bat_Phase InPhase, float32 InDeltaSeconds)
    {
        const auto Yaw = _Bat.Get_RootTransform().Rotator().Yaw;
        const auto Flying = utils_bat::Get_IsHangingPhase(InPhase) == false && InPhase != EMars_Bat_Phase::Falling &&
            InPhase != EMars_Bat_Phase::Landed && InPhase != EMars_Bat_Phase::Dead;
        if (Flying == false || _TrailingYaw.IsSet() == false)
        { _TrailingYaw = Yaw; }

        const auto Behind = Math::FindDeltaAngleDegrees(_TrailingYaw.GetValue(), Yaw);
        const auto Step = Behind * Math::Clamp(float64(InDeltaSeconds * utils_bat::BankFollowRate), 0.0, 1.0);
        _TrailingYaw = FRotator::NormalizeAxis(_TrailingYaw.GetValue() + Step);

        const auto Bank = float32(Math::Clamp(Behind / utils_bat::BankFullDegrees, -1.0, 1.0));
        _Bank = Math::FInterpTo(_Bank, Bank, InDeltaSeconds, utils_bat::BankSmoothRate);
        return Bank;
    }

    // The final AnimBP's clips hang the body themselves; anything else is turned over by the node.
    private bool Get_PoseHangsItself() const
    {
        return ClipsHang && _UsesPlaceholder == false && ck::IsValid(_Anim) && ck::IsValid(_Body);
    }

    // The presentation node under the root. As it hangs: levelled (the crowd agent leaves the root pitched along its last
    // climb; only the root's yaw is kept), turned over about the body (roll 180) unless the clips hang it themselves, and,
    // when the mesh has a perch socket, shifted so that socket meets the perch anchor. In flight it rides the altitude
    // bob. The placeholder also banks into its turns.
    private void PoseLook(float32 InBank)
    {
        const auto Hang = utils_bat::Get_EaseInOut(_Hang);
        auto Roll = Get_PoseHangsItself() ? 0.0 : 180.0 * Hang;
        if (_UsesPlaceholder)
        { Roll += utils_bat::PlaceholderBankDegrees * InBank * (1.0 - Hang); }

        const auto Root = _Bat.Get_RootTransform();
        const auto RootRotation = Root.GetRotation();
        const auto Level = RootRotation.Inverse() * FQuat(FRotator(0.0, RootRotation.Rotator().Yaw, 0.0));
        // Levelled while it hangs and once it lies on the ground (the corpse keeps the root's last flight pitch otherwise).
        const auto LevelAlpha = Math::Max(Hang, utils_bat::Get_EaseInOut(_Down));
        const auto LookRotation = FQuat::Slerp(FQuat::Identity, Level, LevelAlpha) * FQuat(FRotator(0.0, 0.0, Roll));
        const auto Rotation = LookRotation.Rotator();
        auto Offset = FVector::ZeroVector;
        if (_PerchSocketLocal.IsSet() && Hang > 0.0f)
        {
            const auto AnchorLocal = Root.InverseTransformPosition(_Bat.Get_PerchAnchor());
            const auto Pinned = AnchorLocal - LookRotation.RotateVector(_PerchSocketLocal.GetValue());
            Offset = Pinned * Hang;
        }

        if (_BobAlpha > 0.001f)
        {
            const auto Bob = utils_bat::BobAmplitudeCm * Math::Sin(2.0 * PI * utils_bat::BobHz * _BobClock) +
                utils_bat::DriftAmplitudeCm * Math::Sin(2.0 * PI * utils_bat::DriftHz * _BobClock);
            Offset += RootRotation.UnrotateVector(FVector::UpVector) * (Bob * float64(_BobAlpha));
        }

        const auto Look = FTransform(Rotation, Offset);
        if (Look.Equals(_WrittenLook, 0.01))
        { return; }

        _WrittenLook = Look;
        utils_scene_node::Request_UpdateOffset(_LookNode, FCk_Request_SceneNode_UpdateRelativeTransform(Look));
    }
}

namespace utils_bat
{
    float32 Get_EaseInOut(float32 InAlpha)
    {
        const auto Alpha = Math::Clamp(InAlpha, 0.0f, 1.0f);
        return Alpha * Alpha * (3.0f - 2.0f * Alpha);
    }
}

//--------------------------------------------------------------------------------------------------------------------------
// Roost
//--------------------------------------------------------------------------------------------------------------------------

// Placeable perch: a roost one cellar bat can claim (utils_bat::Add_Roost; tagged TAG_MarsBatRoost). The origin is the
// perch anchor, the underside of whatever it hangs from; the bat's root hangs Spec.Roost.HangOffset under it. Destroying
// it takes the perch away: the bat reports OnPerchLost and hovers instead of landing. The bar drawn here is a marker
// without collision: the solid beam it hangs from is level geometry.
class UMars_BatRoost_EntityScript : UCk_GenericEntityScript_UE
{
    default _ShowInPlaceActors = true;
    default _Replication = ECk_Replication::DoesNotReplicate;

    UPROPERTY(ExposeOnSpawn)
    FTransform SpawnTransform = FTransform::Identity;

    UPROPERTY(ExposeOnSpawn)
    bool WithVisuals = true;

    // The marker bar along local X (cm).
    UPROPERTY(ExposeOnSpawn)
    float32 BarLength = 60.0f;

    UFUNCTION(BlueprintOverride)
    ECk_EntityScript_ConstructionFlow DoConstruct(FCk_Handle& InHandle)
    {
        InHandle.Request_OverrideToSelf();
        utils_handle::Set_DebugName(InHandle, n"BatRoost");

        auto Root = utils_transform::Add(InHandle, SpawnTransform, ECk_Replication::DoesNotReplicate);
        utils_bat::Add_Roost(InHandle);

        if (WithVisuals && FApp::CanEverRender())
        {
            auto Bar = FMars_MeshPart(FTransform(FRotator(0.0, 0.0, 90.0), FVector(0.0, 0.0, 3.0), FVector(0.06, 0.06, BarLength * 0.01)),
                engine::load::Cylinder(), assets::load::ProtoGrid_Interactable_Mars_MI(), collision::profile::NoCollision, n"BatRoost_Bar");
            Bar.PrimaryColor = FLinearColor(0.35f, 0.25f, 0.15f, 1.0f);
            Bar.Tint = EMars_MeshPart_Tint::ProtoGrid;
            Root.Add_MeshPart(this, Bar);
        }

        return ECk_EntityScript_ConstructionFlow::Finished;
    }
}

//--------------------------------------------------------------------------------------------------------------------------
// Flight volume
//--------------------------------------------------------------------------------------------------------------------------

// Placeable flight space: a CkVoxelNav volume of HalfExtents round the spawner (rotation and scale ignored), clearance
// Clearance (the bat's AgentRadius), tagged TAG_MarsBatFlightVolume so a bat with no Spec.Volume finds it. It bakes from
// the Jolt static world BuildDelaySeconds after it is set up, so the level's statics (LiveExtract at PIE start) are in.
class UMars_BatFlightVolume_EntityScript : UCk_GenericEntityScript_UE
{
    default _ShowInPlaceActors = true;
    default _Replication = ECk_Replication::DoesNotReplicate;

    UPROPERTY(ExposeOnSpawn)
    FTransform SpawnTransform = FTransform::Identity;

    UPROPERTY(ExposeOnSpawn)
    FVector HalfExtents = FVector(1000.0, 1000.0, 300.0);

    UPROPERTY(ExposeOnSpawn)
    float32 CellSize = 40.0f;

    UPROPERTY(ExposeOnSpawn)
    float32 Clearance = 40.0f;

    UPROPERTY(ExposeOnSpawn)
    float32 BuildDelaySeconds = 0.5f;

    private FCk_Handle_VoxelNavVolume _Volume;

    UFUNCTION(BlueprintOverride)
    ECk_EntityScript_ConstructionFlow DoConstruct(FCk_Handle& InHandle)
    {
        InHandle.Request_OverrideToSelf();
        utils_handle::Set_DebugName(InHandle, n"BatFlightVolume");

        utils_transform::Add(InHandle, SpawnTransform, ECk_Replication::DoesNotReplicate);
        const auto Centre = SpawnTransform.GetLocation();
        _Volume = utils_bat::Add_FlightVolume(InHandle, FMars_Bat_FlightVolume_Spec(FBox(Centre - HalfExtents, Centre + HalfExtents),
            CellSize, Clearance, ECk_EnableDisable::Disable));
        if (ck::Is_NOT_Valid(_Volume))
        { return ECk_EntityScript_ConstructionFlow::Finished; }

        auto TimerSpec = FCk_Timer_Spec(FCk_Time(Math::Max(BuildDelaySeconds, 0.0f)));
        TimerSpec.Set_StartingState(ECk_Timer_State::Running)
                 .Set_Behavior(ECk_Timer_Behavior::StopOnDone);
        auto Timer = utils_timer::Add(InHandle, TimerSpec);
        if (ck::IsValid(Timer))
        { Timer.BindTo_OnDone(FCk_Delegate_Timer(this, n"OnBuildDelayDone")); }

        return ECk_EntityScript_ConstructionFlow::Finished;
    }

    UFUNCTION()
    private void OnBuildDelayDone(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        if (ck::IsValid(_Volume))
        { utils_voxel_nav_volume::Request_Build(_Volume, FCk_Request_VoxelNavVolume_Build()); }
    }
}
