event void FMars_PlayerCharacter_OnGameplayComposed(FCk_Handle InEntity);

// The player's entity script: composes the player entity through the pawn on every machine that has the entity.
UCLASS(NotPlaceable)
class UMars_PlayerCharacter_EntityScript : UCk_EntityScript_WithActor_UE
{
    UFUNCTION(BlueprintOverride)
    ECk_EntityScript_ConstructionFlow DoConstruct(FCk_Handle& InHandle)
    {
        auto Actor = Cast<AMars_PlayerCharacter>(DoGet_Actor());
        if (ck::EnsureIfNot(ck::IsValid(Actor), "[PlayerCharacter] the entity script's Actor is not a player character"))
        { return ECk_EntityScript_ConstructionFlow::Finished; }

        Actor.Request_ComposeEntity(InHandle);
        return ECk_EntityScript_ConstructionFlow::Finished;
    }
}

class AMars_PlayerCharacter : AMars_Character
{
    UPROPERTY(DefaultComponent)
    UCk_EntityBridge_ActorComponent_UE EntityBridge;

    default bUseControllerRotationYaw = true;
    default bUseControllerRotationPitch = false;
    default bUseControllerRotationRoll = false;

    // A PlayerStart brushing a prop must not lose the player (UE's own character templates use this). Placement bugs
    // still show as an adjusted spawn location, not a missing pawn.
    default SpawnCollisionHandlingMethod = ESpawnActorCollisionHandlingMethod::AdjustIfPossibleButAlwaysSpawn;

    default CharacterMovement.bOrientRotationToMovement = false;
    default CharacterMovement.NavAgentProps.bCanCrouch = true;
    default CharacterMovement.bCanWalkOffLedgesWhenCrouching = true;

    // The engine's crouch code measures from the CLASS DEFAULT, not from this instance: standing up sets the capsule to
    // the class default's size, and both crouching and standing up re-place the mesh from the class default's offset.
    // With ACharacter's stock defaults (half height 88, radius 34, mesh at the capsule's centre) the first crouch left
    // the capsule 26 cm too tall for good and the body floating above the floor for everyone who sees it. So the class
    // defaults carry the standing capsule and the body's placement; ConstructionScript still applies Config and ensures
    // it agrees with them.
    default CapsuleComponent.CapsuleHalfHeight = FMars_PlayerCharacter_Body().CapsuleHalfHeight;
    default CapsuleComponent.CapsuleRadius = FMars_PlayerCharacter_Body().CapsuleRadius;
    default Mesh.RelativeLocation = FMars_TPBody_Spec().Get_BodyLocation(FMars_PlayerCharacter_Body().CapsuleHalfHeight, 0.0f);

    // Co-op correction tuning: smooth (rather than snap) corrections up to 20 m, correct the owner at most every 1.5 s
    // (0.5 s past 5 m off), and acknowledge good moves at most every 0.5 s. The client-authority radius
    // (Config.Movement.ClientAuthMaxError) keeps most moves from needing a correction at all.
    default CharacterMovement.NetworkMaxSmoothUpdateDistance = 2000.0f;
    default CharacterMovement.NetworkNoSmoothUpdateDistance = 5000.0f;
    default CharacterMovement.NetworkMinTimeBetweenClientAckGoodMoves = 0.5f;
    default CharacterMovement.NetworkMinTimeBetweenClientAdjustments = 1.5f;
    default CharacterMovement.NetworkMinTimeBetweenClientAdjustmentsLargeCorrection = 0.5f;
    default CharacterMovement.NetworkLargeClientCorrectionDistance = 500.0f;

    // The third-person chef body (Config.TPBody): everyone but its owner sees it; the owner sees the gloves below. Its
    // emote and strike montages must play on simulated proxies and the listen host (their notifies included), so it
    // always ticks.
    default Mesh.bOwnerNoSee = true;
    default Mesh.CastShadow = true;
    default Mesh.VisibilityBasedAnimTickOption = EVisibilityBasedAnimTickOption::AlwaysTickPoseAndRefreshBones;
    default Mesh.SetCollisionEnabled(ECollisionEnabled::NoCollision);

    // The CkCamera director's output sink. Its GetCameraView delivers the director's composed view to the player camera
    // manager; FollowView also moves the component onto that view each frame, so the gloves attached below render exactly
    // where the view renders. Its placement on the pawn is otherwise irrelevant (the director's anchor is Player.Head).
    UPROPERTY(DefaultComponent)
    UCk_CameraComponent CameraComponent;
    default CameraComponent._Placement = ECk_Camera_OutputComponentPlacement::FollowView;

    // Floating first-person gloves. Owner-only: other players see the full body. Mesh and anim class come from
    // Config.FPHandsVisual; UMars_FPHands_AnimInstance places each glove from the player entity's FPHands feature.
    UPROPERTY(DefaultComponent, Attach = CameraComponent)
    USkeletalMeshComponent FPHands;
    default FPHands.RelativeRotation = FRotator(0.0, -90.0, 0.0);
    default FPHands.bOnlyOwnerSee = true;
    default FPHands.CastShadow = false;
    default FPHands.bReceivesDecals = false;
    // The gloves are placed in view by the anim graph, so OnlyTickPoseWhenRendered deadlocks: never rendered at the
    // reference pose -> never ticks -> never placed -> never rendered, until the camera happens to sweep the ref-pose
    // bounds (the "look down once" bug). Owner-only and one mesh, so always ticking costs nothing.
    default FPHands.VisibilityBasedAnimTickOption = EVisibilityBasedAnimTickOption::AlwaysTickPoseAndRefreshBones;
    default FPHands.SetCollisionEnabled(ECollisionEnabled::NoCollision);

    // The chef's hat (Config.TPBody.Head.Hat), a cosmetic on the body's Hat socket: it follows the head and takes the body's
    // scale through the attachment. Hidden from the owner with the body. CharacterMesh0 is ACharacter's Mesh.
    UPROPERTY(DefaultComponent, Attach = CharacterMesh0, AttachSocket = Hat)
    UStaticMeshComponent Hat;
    default Hat.SetMobility(EComponentMobility::Movable);
    default Hat.bOwnerNoSee = true;
    default Hat.CastShadow = true;
    default Hat.bReceivesDecals = false;
    default Hat.SetCollisionEnabled(ECollisionEnabled::NoCollision);

    // The owner's held-item shadow, in the body's right hand (a bone is a valid socket; the AttachSocket warning before the
    // body mesh is assigned at spawn is harmless). Every machine draws the held item by its own world item on the hand
    // mount; on the owner's machine that one is first-person and casts no world shadow, so this draws the item's
    // Presentation mesh for the shadow alone (OwnerNoSee, WorldSpaceRepresentation set in ConstructionScript). Its mesh is
    // set only on the copy that is its player's own view, from the local held-item change (Refresh_HeldItemShadow), and
    // stays empty on every other copy; nothing about it replicates.
    UPROPERTY(DefaultComponent, Attach = CharacterMesh0, AttachSocket = grip_r)
    UStaticMeshComponent HeldItemShadow;
    default HeldItemShadow.SetMobility(EComponentMobility::Movable);
    default HeldItemShadow.bOwnerNoSee = true;
    default HeldItemShadow.CastShadow = true;
    default HeldItemShadow.bReceivesDecals = false;
    default HeldItemShadow.SetCollisionEnabled(ECollisionEnabled::NoCollision);

    UPROPERTY(ExposeOnSpawn)
    UMars_PlayerCharacter_Config Config = mars::Mars_PlayerCharacter_Config;

    private FCk_Handle_Gait _Gait;
    // The gait counters EmitSurfaceFx last played for, and the surface FX table's assets, loaded at composition and held
    // here so a footstep never loads one.
    private FMars_SurfaceFx_GaitCounts _SurfaceFxSeen;
    private TArray<UObject> _SurfaceFxAssets;
    // The gloves' hand node (the first-person swing node).
    private FCk_Handle_Transform _HandNode;
    // Player.BodyGrip follows the body's grip_r at unit scale. Player.HandMount is AttachPoint.Mars.Hand: under BodyGrip
    // at _HandMountBodyOffset until this copy is its player's own view, then under _HandNode at identity for good
    // (Refresh_HandMount).
    private FCk_Handle_SceneNode _BodyGrip;
    private FCk_Handle_Transform _HandMount;
    private FTransform _HandMountBodyOffset = FTransform::Identity;
    private bool _HandMountIsFirstPerson = false;
    private FCk_Handle_Sway _HandSway;
    private FCk_Handle_FPHands _Hands;
    // The melee swing of the hand (HandSwing): offsets the swing node the gloves and held item hang off, and is read by
    // Update_BodyHold to swing the body's arms.
    private FCk_Handle_HandSwing _HandSwing;
    // The bare fists (Punch): the owner's UMars_SmTask_PunchIntent throws them, the other machines' copies mirror each
    // jab (Multicast_PlayPunch); the gloves read them (FPHands) and Update_BodyHold throws the body's arms by them.
    private FCk_Handle_Punch _Punch;
    // A bare fist's blow plays a surface's light knock this loud (constants_surface_fx: between the light and the heavy
    // impact speeds), never the heavy hit of a held item's blow.
    private const float32 k_FistKnockIntensity = 220.0f;

    // The player SM (UMars_SmState_Alive) and whether this copy started it (TryStartPlayerSm).
    private FCk_Handle_StateMachine _Sm;
    private bool _SmStarted = false;
    // The player's entity; every copy composes its damage receiver on it (ConstructCombatReceiver).
    private FCk_Handle _PlayerEntity;

    // Native actor linkage precedes this pawn's gameplay assembly. Consumers of Mars features wait for this edge,
    // or read its cached handle after binding, rather than treating the entity bridge's promises as feature readiness.
    private FCk_Handle _GameplayComposedEntity;
    FMars_PlayerCharacter_OnGameplayComposed OnGameplayComposed;

    UFUNCTION()
    FCk_Handle Get_GameplayComposedEntity() const
    { return _GameplayComposedEntity; }
    // Whether this copy spawned what its own player sees of an armed throw (TryConstructThrowPreviewVisual).
    private bool _ThrowPreviewVisualConstructed = false;
    // The body emote montage last played on this machine (Request_StopEmote ends it); null when none.
    private UAnimMontage _BodyEmoteMontage;

    // How this copy's HeldItem grips what it holds (Mars_HeldView.as), derived on every copy from the local held-item change
    // (OnHeldItemChanged): the arms' hold and the hand mount's body offset both come from it.
    private FMars_HeldView_Grip _HeldGrip;

    // The query the arms' targets for _HeldGrip were built from (rebuilt around the swing's pose while the hand swings),
    // those targets at full alpha, and the eased frame the anim instance reads (Update_BodyHold).
    private FMars_TPBody_HoldQuery _BodyHoldQuery;
    private FMars_TPBody_HoldFrame _BodyHoldTarget;
    private FMars_TPBody_HoldFrame _BodyHoldFrame;

    // The body's grip bones: the gloves' grip axes, children of the hand bones ABP_Chef's IK moves.
    private const FName BodyGripBone_R = n"grip_r";
    private const FName BodyGripBone_L = n"grip_l";

    UFUNCTION(BlueprintOverride)
    void ConstructionScript()
    {
        const auto& Body = Config.Body;
        const auto ClassBody = FMars_PlayerCharacter_Body();
        ck::EnsureIfNot(Body.CapsuleHalfHeight == ClassBody.CapsuleHalfHeight && Body.CapsuleRadius == ClassBody.CapsuleRadius &&
                Config.TPBody.MeshOffset.GetLocation().Equals(FMars_TPBody_Spec().MeshOffset.GetLocation()),
            f"[PlayerCharacter] Config's capsule [{Body.CapsuleRadius} x {Body.CapsuleHalfHeight}] or body offset differs from the class defaults (FMars_PlayerCharacter_Body / FMars_TPBody_Spec defaults): crouching resets the capsule and the body to the class defaults, change them there");
        CapsuleComponent.SetCapsuleSize(Body.CapsuleRadius, Body.CapsuleHalfHeight);
        CameraComponent.SetRelativeLocation(FVector(0.0, 0.0, Config.View.EyeHeight.Height));

        const auto& Movement = Config.Movement;
        CharacterMovement.MaxWalkSpeed = Movement.Speeds.Walk;
        CharacterMovement.MaxWalkSpeedCrouched = Movement.Speeds.Crouch;
        CharacterMovement.MaxAcceleration = Movement.MaxAcceleration;
        CharacterMovement.BrakingDecelerationWalking = Movement.BrakingDecelerationWalking;
        CharacterMovement.JumpZVelocity = Movement.JumpZVelocity;
        CharacterMovement.GravityScale = Movement.GravityScale;
        CharacterMovement.AirControl = Movement.AirControl;
        CharacterMovement.SetCrouchedHalfHeight(Body.CrouchedHalfHeight);

        // The gloves render first-person; held items tag themselves as they attach under the hand (Mars_FPHands_View).
        const auto& View = Config.FPHandsView;
        const auto ViewValidation = View.Validate();
        ck::EnsureIfNot(ViewValidation.IsValid(), f"[PlayerCharacter] FPHandsView: {ViewValidation.Get_Error()}");
        const auto IsFirstPerson = View.FirstPersonRendering == ECk_EnableDisable::Enable;
        FPHands.SetFirstPersonPrimitiveType(IsFirstPerson ? EFirstPersonPrimitiveType::FirstPerson : EFirstPersonPrimitiveType::None);
        // The body and its held item stay hidden from the owner but cast the owner's shadow (the first-person shadow path).
        const auto BodyType = IsFirstPerson ? EFirstPersonPrimitiveType::WorldSpaceRepresentation : EFirstPersonPrimitiveType::None;
        Mesh.SetFirstPersonPrimitiveType(BodyType);
        HeldItemShadow.SetFirstPersonPrimitiveType(BodyType);
        CameraComponent.SetEnableFirstPersonScale(IsFirstPerson);
        CameraComponent.SetFirstPersonScale(View.FirstPersonScale);

        const auto& Visual = Config.FPHandsVisual;
        if (Visual.Mesh.IsNull() == false)
        { FPHands.SetSkeletalMeshAsset(System::LoadAsset_Blocking(Visual.Mesh)); }

        if (Visual.AnimClass.IsNull() == false)
        { FPHands.SetAnimInstanceClass(System::LoadClassAsset_Blocking(Visual.AnimClass)); }

        ConstructBody();

        // The native base (AMars_Character) installs it; CharacterMovement is statically the engine type.
        auto MarsMovement = Cast<UMars_CharacterMovementComponent>(CharacterMovement);
        if (ck::EnsureIfNot(ck::IsValid(MarsMovement), "[Mars_PlayerCharacter] the movement component is not a UMars_CharacterMovementComponent"))
        { return; }

        // 0 is the movement component's stock server-authoritative correction.
        MarsMovement.ClientAuthMaxError = Movement.ClientAuthMaxError.IsSet() ? Movement.ClientAuthMaxError.GetValue() : 0.0f;
    }

    // Before PostInitializeComponents, so ACharacter caches this placement as the mesh's base (the target its network
    // smoothing returns the mesh to). Crouching re-places the body from the class defaults (see the top of the class).
    private void ConstructBody()
    {
        const auto& Body = Config.TPBody;
        const auto Validation = Body.Validate();
        if (ck::EnsureIfNot(Validation.IsValid(), f"[PlayerCharacter] TPBody: {Validation.Get_Error()}"))
        { return; }

        Mesh.SetSkeletalMeshAsset(System::LoadAsset_Blocking(Body.Mesh));
        Mesh.SetAnimInstanceClass(System::LoadClassAsset_Blocking(Body.AnimClass));

        // MeshOffset is relative to the capsule's base; the capsule's origin is its centre.
        const auto FeetLocation = Body.Get_BodyLocation(Config.Body.CapsuleHalfHeight, 0.0f);
        Mesh.SetRelativeLocationAndRotation(FeetLocation, Body.MeshOffset.Rotator());
        Mesh.SetRelativeScale3D(FVector(Body.Scale, Body.Scale, Body.Scale));

        ConstructHat();
    }

    // The spec's socket wins over the declared AttachSocket; Offset is in unscaled body units (the hat inherits Scale).
    private void ConstructHat()
    {
        const auto& HatSpec = Config.TPBody.Head.Hat;
        if (HatSpec.Mesh.IsNull())
        {
            Hat.SetStaticMesh(nullptr);
            return;
        }

        ck::EnsureIfNot(Mesh.DoesSocketExist(HatSpec.Socket),
            f"[PlayerCharacter] TPBody: the body mesh has no [{HatSpec.Socket}] socket for the hat - it sits at the body's origin");

        if (Hat.GetAttachSocketName() != HatSpec.Socket)
        {
            Hat.AttachToComponent(Mesh, HatSpec.Socket,
                EAttachmentRule::KeepRelative, EAttachmentRule::KeepRelative, EAttachmentRule::KeepRelative, false);
        }

        Hat.SetRelativeTransform(HatSpec.Offset);
        Hat.SetStaticMesh(System::LoadAsset_Blocking(HatSpec.Mesh));
    }

    // BeginPlay, not ConstructionScript: the entity bridge needs a live world.
    UFUNCTION(BlueprintOverride)
    void BeginPlay()
    {
        EntityBridge.Request_SpawnLinkedEntity(UMars_PlayerCharacter_EntityScript);
    }

    // Called by UMars_PlayerCharacter_EntityScript while it constructs the entity, so every machine composes all of it
    // before anything observes the entity. The player entity replicates with the pawn (its driver is on the pawn; on a
    // client the request above is ignored and the server's entity arrives as a replica bound to this pawn), so it is
    // the replicated owner of the cues its owner fires (a drop, a throw) and of the replicated state machine below.
    // The interaction resolver, prompts, hints, hands and input are owner-local (stance E); the viewpoint is composed on
    // every copy and follows the pawn's aim where it is not controlled. The hotbar replicates (its slot roots are
    // children of this entity; the authority decides what they hold and what is selected) and HeldItem derives from it
    // on every machine.
    void Request_ComposeEntity(FCk_Handle InEntity)
    {
        FCk_Handle Player = InEntity;
        utils_handle::Set_DebugName(Player, n"Player");

        utils_input_intents::Add(Player);
        utils_team::Add(Player, ECk_Team_ID::One, ECk_Replication::DoesNotReplicate);
        auto Dealer = utils_damage_dealer::Add(Player, FMars_DamageDealer_Spec());
        Dealer.BindTo_OnDamageDealt(FMars_Delegate_DamageDealer_OnDamageDealt(this, n"OnDamageDealt"));

        // The fists deal their blows through the dealer above, from the viewpoint composed below. A rejected spec ensures
        // in Add and leaves the player without fists.
        _Punch = utils_punch::Add(Player, Config.Punch);
        if (ck::IsValid(_Punch))
        {
            _Punch.BindTo_OnThrown(FMars_Delegate_Punch_OnThrown(this, n"OnPunchThrown"));
            _Punch.BindTo_OnBlow(FMars_Delegate_Punch_OnBlow(this, n"OnPunchBlow"));
        }

        // The character's stride clock; the head and hand bobs below read it. The spec's tunables come from the config,
        // its motion source is this pawn's movement component.
        auto GaitSpec = Config.View.Gait;
        GaitSpec.Set_MovementComponent(CharacterMovement);
        _Gait = utils_gait::Add(Player, GaitSpec);
        ConstructSurfaceFx(Player);

        // The view: a bob node on the eye node is the director's input anchor, so the rendered view bobs with the gait
        // (a positional bob) and eases with the eye across a crouch. The director lives on the head node;
        // PlayerViewpoint keeps the handles.
        auto PlayerTransform = Player.As_Transform();
        auto EyeHeightSpec = Config.View.EyeHeight;
        EyeHeightSpec.Character = this;
        auto Eye = utils_eye_height::Create(PlayerTransform, EyeHeightSpec);
        utils_handle::Set_DebugName(Eye.H(), n"Player.Eye");
        auto EyeTransform = Eye.As_Transform();
        auto HeadBobSpec = Config.View.HeadBob;
        HeadBobSpec.Set_Gait(_Gait);
        auto Head = utils_bob::Create(EyeTransform, FTransform::Identity, HeadBobSpec);
        utils_handle::Set_DebugName(Head.H(), n"Player.Head");

        auto CameraSpec = FCk_Camera_Spec(CameraComponent);
        CameraSpec.Set_Profile(utils_player_viewpoint::Make_CameraProfile(Config.View.Viewpoint));
        CameraSpec.Set_DriveControllerControlRotation(true);
        auto HeadTransform = Head.As_Transform();
        auto Camera = utils_camera::Add(HeadTransform, CameraSpec);

        // On a copy this machine does not control, the view follows this pawn's replicated aim.
        auto ViewpointSpec = Config.View.Viewpoint;
        ViewpointSpec.Camera = Camera;
        ViewpointSpec.AimSource = this;
        utils_player_viewpoint::Add(Player, ViewpointSpec);
        utils_interaction_resolver::Add(Player, Config.InteractionResolver, ECk_Replication::DoesNotReplicate);
        utils_interact_prompt_display::Add(Player);
        utils_action_hint_display::Add(Player);

        // Silent: volumes that filter on Probe.Mars.Player detect the player; the player detects nothing through it.
        // Resizes with the capsule, so a crouched player is a crouched-height body to those volumes.
        auto BodyProbeSpec = FCk_Probe_Spec(GameplayTags::Probe_Mars_Player);
        BodyProbeSpec.Set_MotionType(ECk_MotionType::Kinematic)
                     .Set_ResponsePolicy(ECk_ProbeResponse_Policy::Silent);
        auto BodyProbe = utils_body_probe::Create(PlayerTransform, FMars_BodyProbe_Spec(BodyProbeSpec, this));
        utils_handle::Set_DebugName(BodyProbe.H(), n"Player.Probe.Body");
        _PlayerEntity = Player;
        if (Config.Combat.Enabled == ECk_EnableDisable::Enable)
        { ConstructCombatReceiver(Player); }
        TryConstructThrowPreviewVisual();

        auto DownedSpec = FCk_ByteAttribute_Spec(GameplayTags::ByteAttribute_Mars_Player_Downed, 0);
        DownedSpec.Set_MinMax(ECk_MinMax::MinMax).Set_MinValue(0).Set_MaxValue(1);
        utils_byte_attribute::Add(Player, DownedSpec, ECk_Replication::DoesNotReplicate);

        // Hangs off the rendered view (the director's view anchor), so it carries the view's yaw in the same frame. The
        // pitch node in between is turned by the FPHands feature: the gloves take only part of the view's pitch
        // (Config.FPHands.Pitch) and stay low when the player looks up.
        auto ViewAnchor = Camera.Get_ViewAnchor();
        auto HandPitch = utils_scene_node::Create(ViewAnchor, FTransform::Identity);
        utils_handle::Set_DebugName(HandPitch.H(), n"Player.HandPitch");
        auto HandPitchTransform = HandPitch.As_Transform();
        auto Hand = utils_scene_node::Create(HandPitchTransform, Config.FPHands.Rest.CenteredHandOffset);
        utils_handle::Set_DebugName(Hand.H(), n"Player.Hand");

        // Damped-spring lag of the hand behind the view. CkSway owns the Hand offset from here on; the centred rest is its
        // rest for every hold (a hold's lateral is the HandSide node's, below the bob, so it never kicks the spring).
        _HandSway = utils_sway::Add(Hand, Config.HandSway);

        // Locomotion bob under the swaying hand, in phase with the head; the swing node, the held item and both gloves
        // hang off it.
        auto HandTransform = Hand.As_Transform();
        auto HandBobSpec = Config.FPHands.Bob;
        HandBobSpec.Set_Gait(_Gait);
        auto HandBob = utils_bob::Create(HandTransform, FTransform::Identity, HandBobSpec);
        utils_handle::Set_DebugName(HandBob.H(), n"Player.HandBob");

        // The hand chain under the bob (utils_fphands::Create_HandChain). Player.HandSide takes the hold's lateral
        // (UMars_SmTask_HeldItemDrivesHands writes it): a plain node rather than the sway's rest, so the gloves' anim
        // instance can read the offset it actually carries each frame and hold the gloves still while it moves.
        // Player.HandSwing under it is the melee swing's (HandSwing owns its offset, identity at rest): both gloves and the
        // held item hang off it.
        const auto Chain = utils_fphands::Create_HandChain(HandBob.As_Transform(), "Player");
        _HandSwing = utils_hand_swing::Add(Player, FMars_HandSwing_Spec(Chain.Swing));
        _HandNode = Chain.Hand;
        auto HandsSpec = Config.FPHands;
        utils_fphands::Wire_HandChain(HandsSpec, Chain);
        HandsSpec.Pitch.Node = HandPitch;
        _Hands = utils_fphands::Add(Player, HandsSpec);

        auto Back = utils_scene_node::Create(PlayerTransform, Config.Inventory.BackOffset);
        utils_handle::Set_DebugName(Back.H(), n"Player.Back");

        auto Belt = utils_scene_node::Create(PlayerTransform, Config.Inventory.BeltOffset);
        utils_handle::Set_DebugName(Belt.H(), n"Player.Belt");

        // The one hand items mount on, on every copy: the body's hand until this copy is its player's own view.
        ConstructHandMount(PlayerTransform);

        auto AttachPointsSpec = FMars_AttachPoints_Spec();
        AttachPointsSpec.Points.Add(FMars_AttachPoint_Entry(GameplayTags::AttachPoint_Mars_Hand, _HandMount));
        AttachPointsSpec.Points.Add(FMars_AttachPoint_Entry(GameplayTags::AttachPoint_Mars_Back, Back.As_Transform()));
        AttachPointsSpec.Points.Add(FMars_AttachPoint_Entry(GameplayTags::AttachPoint_Mars_Belt, Belt.As_Transform()));
        // Other characters' gazes look here: Player.Head is the bob node the camera director renders from, i.e. the eyes.
        AttachPointsSpec.Points.Add(FMars_AttachPoint_Entry(GameplayTags::AttachPoint_Mars_Head, HeadTransform));
        utils_attach_points::Add(Player, AttachPointsSpec);

        auto HotbarSpec = FMars_Hotbar_Spec();
        HotbarSpec.BagSlotCount = Config.Inventory.BagSlotCount;
        utils_hotbar::Add(Player, HotbarSpec);
        auto HeldItem = utils_held_item::Add(Player);
        if (ck::IsValid(HeldItem))
        { HeldItem.BindTo_OnHeldItemChanged(FMars_Delegate_HeldItem_OnHeldItemChanged(this, n"OnHeldItemChanged")); }

        utils_held_item_use::Add(Player);
        utils_throw_preview::Add(Player, Config.Inventory.ThrowPreview);
        utils_emote_wheel::Add(Player, Config.EmoteWheel);
        utils_climber::Add(Player, FMars_Climber_Spec(Config.Movement.Speeds.Climb));
        utils_operator::Add(Player);
        utils_locomotion_speed::Add(Player, FMars_LocomotionSpeed_Spec(Config.Movement.Speeds.Walk, Config.Movement.Speeds.Sprint));

        // The chef's voice, on every copy: CkVoiceChat routes by the talker's entity on the server and plays a remote
        // chef's voice from its actor on each listener's machine, so every copy needs it. It joins the GameState's
        // proximity channel by name on the authority (Config.Voice); the Alive state opens its microphone on the owning
        // copy (UMars_SmTask_VoiceOpenMic).
        utils_voice_talker::Add(Player, Config.Voice.Talker);

        // Owning-client authoritative: the owner evaluates the conditions against its input and its transitions replicate
        // to the server and the other clients, so every copy runs the owner's states. It must not auto-start: the start
        // (TryStartPlayerSm) waits for local control, or the nested sub-SMs snapshot their net identity as a non-owning
        // client and freeze.
        auto SmSpec = FCk_StateMachine_Spec(UMars_SmState_Alive);
        SmSpec.Set_Replication(ECk_Replication::Replicates);
        SmSpec.Set_ReplicationModel(ECk_Sm_ReplicationModel::WithHistory);
        SmSpec.Set_AuthorityModel(ECk_Sm_AuthorityModel::OwningClientAuthoritative);
        SmSpec.Set_AutoStart(ECk_SmAutoStart::Disabled);
        _Sm = utils_state_machine::Add(Player, SmSpec);

        ConstructEyes(PlayerTransform);

        TryStartPlayerSm();
        Refresh_HandMount();

        // Last: every feature the HUD consumes has now been added, regardless of actor-link/possession ordering.
        _GameplayComposedEntity = Player;
        OnGameplayComposed.Broadcast(Player);
    }

    // The damage receiver, composed on every copy of the pawn on every machine: Health, the body zone, and a second
    // capsule probe named Probe.Mars.HitZone registered as the zone's hurtbox. That capsule follows the movement capsule
    // like the Probe.Mars.Player one (crouch and a blocked uncrouch included); the Probe.Mars.Player one stays for the
    // volumes that filter on it. A hit is applied by the machine with authority over the player's entity and reaches every
    // other copy through the Health's replicated ledger. The combat-target tags are stamped last, so nothing discovers
    // a half-built receiver (Refresh_CombatTargetTags). Downing at zero Health is still the state machine's decision
    // (Mars_PlayerCharacter_Hfsm_Combat.as), taken by the owning copy from the Health it reads. A rejected composition
    // ensures once (each Add on its own rejection) and is not retried.
    private void ConstructCombatReceiver(FCk_Handle& InPlayer)
    {
        auto PlayerTransform = InPlayer.As_Transform();

        auto Health = utils_health::Add(InPlayer, FMars_Health_Spec(Config.Combat.MaxHealth));
        if (ck::Is_NOT_Valid(Health))
        { return; }

        Health.BindTo_OnDamaged(FMars_Delegate_Health_OnDamaged(this, n"OnHurt"));

        auto Zone = utils_hit_zone::Add(InPlayer, utils_hit_zone::Make_FleshZoneSpec(GameplayTags::HitZone_Mars_Body, 1.0f));
        if (ck::Is_NOT_Valid(Zone))
        { return; }

        auto HurtboxProbeSpec = FCk_Probe_Spec(GameplayTags::Probe_Mars_HitZone);
        HurtboxProbeSpec.Set_MotionType(ECk_MotionType::Kinematic)
                        .Set_ResponsePolicy(ECk_ProbeResponse_Policy::Silent);
        auto HurtboxProbe = utils_body_probe::Create(PlayerTransform, FMars_BodyProbe_Spec(HurtboxProbeSpec, this));
        if (ck::Is_NOT_Valid(HurtboxProbe))
        { return; }

        utils_handle::Set_DebugName(HurtboxProbe.H(), n"Player.Probe.Hurtbox");
        auto Hurtbox = utils_hit_zone::AttachHurtbox(Zone, HurtboxProbe.H().As_Probe());
        if (ck::Is_NOT_Valid(Hurtbox))
        { return; }

        Refresh_CombatTargetTags();
    }

    // The receiver is whole: a Health and a zone with its hurtbox.
    private bool Get_IsCombatReceiverComposed() const
    {
        const auto Zone = _PlayerEntity.As_HitZone(ECk_SanityCheck::UnChecked);
        return ck::IsValid(_PlayerEntity.As_Health(ECk_SanityCheck::UnChecked)) && ck::IsValid(Zone) && Zone.Get_Hurtboxes().Num() > 0;
    }

    // Marks the pawn prey once its receiver is whole, only where this machine has authority over the player's entity.
    // TAG_MarsSharedCombatTarget goes on every pawn a player controls (the host's own, a joined player's), read by
    // a creature that is one creature on every machine. TAG_MarsCombatTarget goes only on the pawn this machine also
    // controls locally (the host's own, a standalone player's): it is read by a creature each machine still simulates
    // for itself, which may only choose the player whose machine shows it. Called when the receiver composes and when
    // the controller changes. Neither tag is removed: a pawn loses its controller only when it is destroyed.
    private void Refresh_CombatTargetTags()
    {
        if (ck::Is_NOT_Valid(_PlayerEntity) || Get_IsCombatReceiverComposed() == false)
        { return; }

        if (utils_net::Get_HasAuthority(_PlayerEntity) == false)
        { return; }

        if (utils_net::Get_IsEntityPlayerControlled(_PlayerEntity) != ECk_Utils_Net_IsPlayerControlled_Result::IsPlayerControlled)
        { return; }

        if (utils_entity_tag::Has(_PlayerEntity, n"TAG_MarsSharedCombatTarget") == false)
        { utils_entity_tag::Add(_PlayerEntity, n"TAG_MarsSharedCombatTarget"); }

        if (utils_net::Get_IsEntityLocallyControlled_ByPlayer(_PlayerEntity) != ECk_Utils_Net_IsLocallyControlled_Result::IsLocallyControlled)
        { return; }

        if (utils_entity_tag::Has(_PlayerEntity, n"TAG_MarsCombatTarget") == false)
        { utils_entity_tag::Add(_PlayerEntity, n"TAG_MarsCombatTarget"); }
    }

    // What this machine's own player sees of an armed throw (UMars_ThrowPreview_EntityScript, owned by the player's entity),
    // on the locally controlled copy only; the ThrowPreview kernel itself is on every copy. It waits for local control,
    // which only resolves after possession, and for the kernel (the first call, in the construct, comes before the
    // entity composes it). One-shot.
    private void TryConstructThrowPreviewVisual()
    {
        if (_ThrowPreviewVisualConstructed || ck::Is_NOT_Valid(_PlayerEntity) || _PlayerEntity.Is_ThrowPreview() == false)
        { return; }

        if (utils_net::Get_IsEntityLocallyControlled_ByPlayer(_PlayerEntity) != ECk_Utils_Net_IsLocallyControlled_Result::IsLocallyControlled)
        { return; }

        _ThrowPreviewVisualConstructed = true;
        auto Params = UMars_ThrowPreview_EntityScript::Params();
        Params.Preview = _PlayerEntity.As_ThrowPreview();
        utils_entity_script::Request_SpawnEntity(_PlayerEntity, UMars_ThrowPreview_EntityScript, Params);
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Hit feedback: a blow this player lands, on a zone or on the world, and a blow that lands on this player play the
    // surface's impact (SurfaceFx) at the contact and shake this player's camera: the striker's by the item's
    // Strike.HitShake, the victim's by Config.Combat.HurtShake. The striker's zone cue is the dealer's OnDamageDealt, not
    // Health.OnDamaged: a leg hit spills to the body and damages twice. Every zone plays as flesh until a zone names its
    // surface; the world plays its phys mat's surface. A bare fist's blow (a Punch jab: its causer is the dealer itself,
    // no item) plays the surface's light knock instead of the heavy hit, and shakes nothing.
    //----------------------------------------------------------------------------------------------------------------------

    // A held item's strike was stopped by the world (a wall, a prop) short of any zone (UMars_SmTask_ItemUse_Strike).
    void Play_StrikeWorldHit(FCk_ShapeCast_Result InHit, FCk_Handle_Item InItem)
    {
        if (ck::Is_NOT_Valid(_PlayerEntity) || utils_net::Get_CanExecuteCosmeticEvents(_PlayerEntity) == false)
        { return; }

        auto Contact = FMars_SurfaceFx_Contact();
        Contact.Location = InHit.Get_HitLocation();
        Contact.Normal = InHit.Get_SurfaceNormal();
        PlayImpactFx(_PlayerEntity, utils_surface_fx::Get_SurfaceTags(InHit.Get_PhysicalMaterial().Get()), Contact);
        PlayStrikeShake(_PlayerEntity, InItem);
    }

    UFUNCTION()
    private void OnDamageDealt(FCk_Handle_DamageDealer InDealer, FCk_Handle_HitZone InZone, FMars_DamageEvent InEvent)
    {
        if (utils_net::Get_CanExecuteCosmeticEvents(InDealer) == false)
        { return; }

        const auto Flesh = GameplayTag::MakeContainerFromTag(GameplayTags::Surface_Flesh);
        if (InEvent.Source.Causer == InEvent.Source.Instigator)
        {
            PlayKnockFx(InDealer, Flesh, Make_Contact(InEvent));
            return;
        }

        PlayImpactFx(InDealer, Flesh, Make_Contact(InEvent));
        PlayStrikeShake(InDealer, InEvent.Source.Causer.As_Item(ECk_SanityCheck::UnChecked));
    }

    // A jab's blow (Punch.OnBlow, the thrower's own copy only). A zone hit plays through the dealer's OnDamageDealt; a
    // fist the world stops knocks on its surface.
    UFUNCTION()
    private void OnPunchBlow(FCk_Handle_Punch InPunch, EMars_Hand InHand, FCk_ShapeCast_Result InHit)
    {
        if (InHit.Get_HitKind() != ECk_ProbeTrace_HitKind::World || utils_net::Get_CanExecuteCosmeticEvents(InPunch) == false)
        { return; }

        auto Contact = FMars_SurfaceFx_Contact();
        Contact.Location = InHit.Get_HitLocation();
        Contact.Normal = InHit.Get_SurfaceNormal();
        PlayKnockFx(InPunch, utils_surface_fx::Get_SurfaceTags(InHit.Get_PhysicalMaterial().Get()), Contact);
    }

    // Every copy's receiver binds this (ConstructCombatReceiver): the impact plays on every machine that shows cosmetics,
    // the camera shakes only on the machine that controls the victim.
    UFUNCTION()
    private void OnHurt(FCk_Handle_Health InHealth, FMars_DamageEvent InEvent, float32 InApplied, float32 InRemaining)
    {
        if (utils_net::Get_CanExecuteCosmeticEvents(InHealth) == false)
        { return; }

        PlayImpactFx(InHealth, GameplayTag::MakeContainerFromTag(GameplayTags::Surface_Flesh), Make_Contact(InEvent));
        if (utils_net::Get_IsEntityLocallyControlled_ByPlayer(InHealth) == ECk_Utils_Net_IsLocallyControlled_Result::IsLocallyControlled)
        { utils_surface_fx::Play_Shake(Config.Combat.HurtShake); }
    }

    private void PlayImpactFx(FCk_Handle InPlayer, FGameplayTagContainer InSurfaceTags, FMars_SurfaceFx_Contact InContact)
    {
        utils_surface_fx::Play(Make_ImpactEvent(InPlayer, InSurfaceTags, InContact));
    }

    // A bare fist's blow: the surface's light knock.
    private void PlayKnockFx(FCk_Handle InPlayer, FGameplayTagContainer InSurfaceTags, FMars_SurfaceFx_Contact InContact)
    {
        auto Event = Make_ImpactEvent(InPlayer, InSurfaceTags, InContact);
        Event.Intensity = k_FistKnockIntensity;
        utils_surface_fx::Play(Event);
    }

    private FMars_SurfaceFx_Event Make_ImpactEvent(FCk_Handle InPlayer, FGameplayTagContainer InSurfaceTags, FMars_SurfaceFx_Contact InContact) const
    {
        auto Event = FMars_SurfaceFx_Event();
        Event.Kind = GameplayTags::SurfaceFx_Impact;
        Event.SurfaceTags = InSurfaceTags;
        Event.Contact = InContact;
        // A held item's blow, and a blow taken, always play the surface's heavy hit, never the light knock.
        Event.Intensity = constants_surface_fx::k_ImpactHeavyMinSpeed;
        Event.Instigator = InPlayer;
        return Event;
    }

    // InItem's Strike.HitShake, on the striker's own machine only.
    private void PlayStrikeShake(FCk_Handle InPlayer, FCk_Handle_Item InItem)
    {
        if (ck::Is_NOT_Valid(InItem) || InItem.Has_Strike() == false)
        { return; }

        if (utils_net::Get_IsEntityLocallyControlled_ByPlayer(InPlayer) != ECk_Utils_Net_IsLocallyControlled_Result::IsLocallyControlled)
        { return; }

        utils_surface_fx::Play_Shake(InItem.Get_Strike().HitShake);
    }

    private FMars_SurfaceFx_Contact Make_Contact(const FMars_DamageEvent& InEvent) const
    {
        auto Contact = FMars_SurfaceFx_Contact();
        Contact.Location = InEvent.Hit.Location;
        Contact.Normal = InEvent.Hit.Normal;
        return Contact;
    }

    // The owning client (or the listen host, for its own pawn) is the SM's only start authority. Called when the entity is
    // ready, when the controller changes, and every tick until it starts: local control only resolves a few frames after
    // possession. One-shot.
    private void TryStartPlayerSm()
    {
        if (_SmStarted || ck::Is_NOT_Valid(_Sm))
        { return; }

        if (utils_net::Get_IsEntityLocallyControlled_ByPlayer(_Sm) != ECk_Utils_Net_IsLocallyControlled_Result::IsLocallyControlled)
        { return; }

        utils_state_machine::Request_Start(_Sm);
        _SmStarted = true;
    }

    UFUNCTION(BlueprintOverride)
    void ControllerChanged(AController OldController, AController NewController)
    {
        TryStartPlayerSm();
        Refresh_CombatTargetTags();
        TryConstructThrowPreviewVisual();
        Refresh_HandMount();
    }

    UFUNCTION(BlueprintOverride)
    void Tick(float DeltaSeconds)
    {
        TryStartPlayerSm();
        TryConstructThrowPreviewVisual();
        Refresh_HandMount();
        EmitSurfaceFx();
    }

    //----------------------------------------------------------------------------------------------------------------------
    // The hand mount (AttachPoint.Mars.Hand): one node per copy that every held item mounts on, so an item is drawn once,
    // by its own entity script, wherever this machine shows the hand. On the copy that is its player's own view it is the
    // gloves' first-person hand; on every other copy it is the body's right hand, placed where the gloves' hand node
    // would be relative to the right glove's grip, so an item sits on grip_r as the first-person item sits on the glove.
    //----------------------------------------------------------------------------------------------------------------------

    // This copy is its player's own view: locally controlled by a player. Sampled live; the hand mount latches it once
    // (Get_IsHandMountFirstPerson), and everything first-person reads the latch.
    bool Get_IsLocalPlayerView() const
    {
        if (ck::Is_NOT_Valid(_PlayerEntity))
        { return false; }

        return utils_net::Get_IsEntityLocallyControlled_ByPlayer(_PlayerEntity) == ECk_Utils_Net_IsLocallyControlled_Result::IsLocallyControlled;
    }

    // The hand mount has moved under the gloves' hand node: the first time this copy was its player's own view
    // (Get_IsLocalPlayerView), for good. The one sample of "this copy shows its player's first-person hand": the parent
    // walk that renders first-person (utils_fphands::Get_IsFirstPersonHandNode), the gloves' tick and the carry-in of a
    // held visual (utils_fphands::Get_IsFirstPersonView) read it, so an unpossess changes none of them.
    bool Get_IsHandMountFirstPerson() const
    {
        return _HandMountIsFirstPerson;
    }

    // AttachPoint.Mars.Hand.
    FCk_Handle_Transform Get_HandMount() const
    {
        return _HandMount;
    }

    // The scene node following the body's grip_r at unit scale. Test-only (the hand-mount rows read the mount's parent).
    FCk_Handle_SceneNode Get_BodyGrip() const
    {
        return _BodyGrip;
    }

    // The hand mount's offset under BodyGrip for the item held now (OnHeldItemChanged). Test-only (the body-hand rows'
    // expected placement).
    FTransform Get_HandMountBodyOffset() const
    {
        return _HandMountBodyOffset;
    }

    // BodyGrip follows the socket at unit scale: its offset undoes the scale the socket carries (the body's Scale), measured
    // here. A body mesh without grip_r ensures and the hand mount rides the player's root instead.
    private void ConstructHandMount(FCk_Handle_Transform& InPlayerTransform)
    {
        if (ck::EnsureIfNot(Mesh.DoesSocketExist(BodyGripBone_R),
            f"[PlayerCharacter] TPBody: the body mesh has no [{BodyGripBone_R}] bone for the hand mount - held items ride the player's root"))
        { _BodyGrip = utils_scene_node::Create(InPlayerTransform, FTransform::Identity); }
        else
        {
            const auto SocketScale = Mesh.GetSocketTransform(BodyGripBone_R).GetScale3D();
            const auto IsUniform = SocketScale.X > KINDA_SMALL_NUMBER && SocketScale.Equals(FVector(SocketScale.X, SocketScale.X, SocketScale.X), 0.001);
            ck::EnsureIfNot(IsUniform, f"[PlayerCharacter] TPBody: grip_r's world scale [{SocketScale}] is not uniform and positive - the hand mount takes its X");
            const auto Unscale = 1.0 / Math::Max(SocketScale.X, KINDA_SMALL_NUMBER);
            _BodyGrip = utils_scene_node::CreateAndAttachToUnrealMesh(InPlayerTransform, Mesh, BodyGripBone_R,
                FTransform(FQuat::Identity, FVector::ZeroVector, FVector(Unscale, Unscale, Unscale)));
        }

        utils_handle::Set_DebugName(_BodyGrip.H(), n"Player.BodyGrip");
        _HandMountBodyOffset = Make_HandMountBodyOffset(_HeldGrip);
        auto BodyGripTransform = _BodyGrip.As_Transform();
        auto HandMount = utils_scene_node::Create(BodyGripTransform, _HandMountBodyOffset);
        utils_handle::Set_DebugName(HandMount.H(), n"Player.HandMount");
        _HandMount = HandMount.As_Transform();
    }

    // One-way: the first time this copy is its player's own view, the hand mount moves under the gloves' hand node at
    // identity (detach, then add: utils_scene_node::Add never re-parents an attached node) and what it carries is drawn
    // first-person from then on. Called at composition, when the controller changes and every tick until it moves: local
    // control only resolves a few frames after possession.
    private void Refresh_HandMount()
    {
        if (_HandMountIsFirstPerson || ck::Is_NOT_Valid(_HandMount) || ck::Is_NOT_Valid(_HandNode) || Get_IsLocalPlayerView() == false)
        { return; }

        _HandMountIsFirstPerson = true;
        auto SceneNode = _HandMount.H().As_SceneNode();
        utils_scene_node::Request_Detach(SceneNode);
        auto FirstPersonNode = utils_scene_node::Add(_HandMount, _HandNode, FTransform::Identity);
        // A body offset requested earlier this frame must not land on the first-person mount: the last request wins.
        utils_scene_node::Request_UpdateOffset(FirstPersonNode, FCk_Request_SceneNode_UpdateRelativeTransform(FTransform::Identity));
        utils_fphands::Apply_FirstPersonTypeToMounted(_HandMount);
        Refresh_HeldItemShadow(Get_HeldItemNow());
    }

    // Every copy, late joiners included (HeldItem follows the replicated hotbar): the hold is derived here from the item,
    // including the refresh when a persistent body links after the selection (its fit changes the hold). It aims the arms
    // (Apply_BodyHold), sets the owner's shadow and moves the hand mount's body offset; once the mount is first-person it
    // stays at identity.
    UFUNCTION()
    private void OnHeldItemChanged(FCk_Handle_HeldItem InHeldItem, FCk_Handle_Item InPrev, FCk_Handle_Item InNew)
    {
        _HeldGrip = utils_held_view::Make_Grip(InNew);
        _HandMountBodyOffset = Make_HandMountBodyOffset(_HeldGrip);
        Apply_BodyHold();
        Refresh_HeldItemShadow(InNew);
        if (_HandMountIsFirstPerson)
        { return; }

        auto SceneNode = _HandMount.H().As_SceneNode();
        utils_scene_node::Request_UpdateOffset(SceneNode, FCk_Request_SceneNode_UpdateRelativeTransform(_HandMountBodyOffset));
    }

    // Where the gloves' hand node is relative to the right glove's grip for InGrip, with the body's palm
    // (utils_held_view::Get_BodyHandMountOffset): an item at HeldOffset on the mount sits on grip_r as the first-person item
    // sits on the right glove. Empty hands (and an item with no Presentation) take the empty hold's right rest grip.
    private FTransform Make_HandMountBodyOffset(const FMars_HeldView_Grip& InGrip) const
    {
        return utils_held_view::Get_BodyHandMountOffset(Make_BodyHandsSpec(), InGrip);
    }

    // What this copy's HeldItem holds now; invalid before composition and with empty hands.
    private FCk_Handle_Item Get_HeldItemNow() const
    {
        if (ck::Is_NOT_Valid(_PlayerEntity))
        { return FCk_Handle_Item(); }

        const auto HeldItem = _PlayerEntity.As_HeldItem(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(HeldItem))
        { return FCk_Handle_Item(); }

        return HeldItem.Get_CurrentItem();
    }

    // The gloves' layout with the body's own palm thickness for the fitted grips.
    private FMars_FPHands_Spec Make_BodyHandsSpec() const
    {
        auto HandsSpec = Config.FPHands;
        HandsSpec.Rest.PalmSurfaceOffset = Config.TPBody.Hold.PalmSurfaceOffset;
        return HandsSpec;
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Footsteps and landings (Mars_SurfaceFx.as): the gait is the one stride clock, so a step plays at its footfall, on the
    // bob's dip. Every copy runs its own gait from its movement component, so every machine hears every player without
    // anything replicating; Play makes another player's steps quieter and culls them beyond earshot.
    //----------------------------------------------------------------------------------------------------------------------

    private void ConstructSurfaceFx(FCk_Handle& InPlayer)
    {
        _SurfaceFxSeen = utils_surface_fx::Get_GaitCounts(_Gait);
        if (utils_net::Get_CanExecuteCosmeticEvents(InPlayer) == false)
        { return; }

        const auto Table = utils_surface_fx::Get_Table();
        const auto Validation = Table.Validate();
        if (ck::EnsureIfNot(Validation.IsValid(), f"[PlayerCharacter] SurfaceFx: {Validation.Get_Error()}"))
        { return; }

        utils_surface_fx::Load_Assets(Table, _SurfaceFxAssets);
    }

    // One footstep per gait footfall and one landing per landing since the last tick, on the surface under the capsule.
    private void EmitSurfaceFx()
    {
        if (ck::Is_NOT_Valid(_Gait))
        { return; }

        const auto Counts = utils_surface_fx::Get_GaitCounts(_Gait);
        const auto Emits = utils_surface_fx::Get_GaitEmits(_SurfaceFxSeen, Counts);
        _SurfaceFxSeen = Counts;
        if (Emits.Footsteps == 0 && Emits.Lands == 0)
        { return; }

        if (utils_net::Get_CanExecuteCosmeticEvents(_Gait) == false)
        { return; }

        auto Query = FMars_SurfaceFx_GroundQuery();
        Query.Origin = GetActorLocation();
        Query.DepthCm = CapsuleComponent.GetScaledCapsuleHalfHeight() + constants_surface_fx::k_GroundProbeMarginCm;
        Query.Ignored.Add(this);

        auto Ground = FMars_SurfaceFx_Ground();
        if (utils_surface_fx::TryGet_SurfaceUnder(Query, Ground) == false)
        { return; }

        auto Event = FMars_SurfaceFx_Event();
        Event.SurfaceTags = Ground.SurfaceTags;
        Event.Contact = Ground.Contact;
        Event.Instigator = _Gait;

        Event.Kind = GameplayTags::SurfaceFx_Land;
        Event.Intensity = float32(_Gait.Get_LastLandImpactSpeed());
        for (int32 Index = 0; Index < Emits.Lands; ++Index)
        { utils_surface_fx::Play(Event); }

        Event.Kind = GameplayTags::SurfaceFx_Footstep;
        Event.Intensity = float32(_Gait.Get_SpeedRatio());
        for (int32 Index = 0; Index < Emits.Footsteps; ++Index)
        { utils_surface_fx::Play(Event); }
    }

    //----------------------------------------------------------------------------------------------------------------------
    // The chef's eyes: drawn by the body mesh's eye slot (Config.TPBody.Head.Face.EyesSlot, SK_Chef's M_EyePlate), so
    // they are part of the body - hidden from the owner by OwnerNoSee and seen by everyone else - and every copy composes
    // them, whoever possesses it. A face node following the head bone carries Gaze (looking at other players' heads) and
    // Eyes, which write their values into the body's custom primitive data.
    //----------------------------------------------------------------------------------------------------------------------

    // Where cosmetics cannot run (a dedicated server) the face is only its node and the eyes' logic: no look, no gaze.
    private void ConstructEyes(FCk_Handle_Transform& InPlayerTransform)
    {
        const auto& FaceSpec = Config.TPBody.Head.Face;
        if (ck::EnsureIfNot(Mesh.DoesSocketExist(FaceSpec.Bone),
            f"[PlayerCharacter] TPBody: the body mesh has no [{FaceSpec.Bone}] bone for the eyes"))
        { return; }

        auto FaceNode = utils_scene_node::CreateAndAttachToUnrealMesh(InPlayerTransform, Mesh, FaceSpec.Bone, FaceSpec.Offset);
        utils_handle::Set_DebugName(FaceNode.H(), n"Player.Face");
        auto Face = FaceNode.As_Transform();

        auto EyesSlot = ck::INDEX_NONE();
        if (utils_net::Get_CanExecuteCosmeticEvents(Face))
        {
            EyesSlot = SetUpEyesSlot(FaceSpec.EyesSlot);

            auto GazeSpec = FMars_Gaze_Spec();
            GazeSpec.DetectionFilter.AddTag(GameplayTags::Probe_Mars_Player);
            GazeSpec.AimPoint = GameplayTags::AttachPoint_Mars_Head;
            utils_gaze::Add(Face, GazeSpec);
        }

        auto Eyes = utils_eyes::Add(Face, Config.Eyes);
        if (ck::IsValid(Eyes) && EyesSlot != ck::INDEX_NONE())
        { Eyes.Request_SetPlatePrimitive(FMars_Request_Eyes_SetPlatePrimitive(Mesh, EyesSlot)); }
    }

    // Puts the eye-plate look on the body's eye slot (replacing the imported placeholder material) and returns the
    // slot's index. INDEX_NONE (after an ensure) when the body mesh has no such slot or the MarsEyePlate look master is
    // not generated; the eyes then have logic but nothing to draw on.
    private int32 SetUpEyesSlot(FName InSlotName)
    {
        const auto SlotIndex = Mesh.GetMaterialIndex(InSlotName);
        if (ck::EnsureIfNot(SlotIndex != ck::INDEX_NONE(),
            f"[PlayerCharacter] TPBody: the body mesh has no [{InSlotName}] material slot for the eyes - re-import SK_Chef with its Eyes_LP"))
        { return ck::INDEX_NONE(); }

        auto LookMaster = utils_usf::Get_LookMasterMaterial(utils_eyes::Look_EyePlate());
        if (ck::EnsureIfNot(ck::IsValid(LookMaster),
            "[PlayerCharacter] the MarsEyePlate look master is not generated - run Ck_Usf_GenerateLooks MarsEyePlate"))
        { return ck::INDEX_NONE(); }

        Mesh.SetMaterial(SlotIndex, LookMaster);
        return SlotIndex;
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Emotes and the strike. The HFSM tasks decide when (emote keys, the emote wheel, a held item's strike and its
    // cancel); the character only plays the emote montages or starts and cancels the hand swing, and carries them over
    // the network. The machine that asks plays at once - the owner's gloves, and its body for a listen host's view -
    // and, when it is the owner, forwards to the server, which multicasts. Each multicast skips the locally controlled
    // copy (the owner already played it), so every machine plays each exactly once. A call on a machine that does not
    // control this character stays local.
    //----------------------------------------------------------------------------------------------------------------------

    // The one emote entry point. False while the gloves are busy (holding an item, or out of Rest), or when neither the
    // gloves nor the body has a montage for it.
    UFUNCTION()
    bool Request_Emote(EMars_FPEmote InEmote)
    {
        if (ck::Is_NOT_Valid(_Hands) || _Hands.Get_Hold().Kind != EMars_FPHands_HoldKind::Empty
            || _Hands.Get_Phase() != EMars_FPHands_Phase::None)
        { return false; }

        const auto IsOwner = IsLocallyControlled();
        const auto PlayedHands = IsOwner && utils_fphands::Play_Emote(_Hands, InEmote);
        const auto PlayedBody = PlayBodyEmote(InEmote);
        if (PlayedHands == false && PlayedBody == false)
        { return false; }

        if (IsOwner)
        { Server_PlayEmote(InEmote); }

        return true;
    }

    // Ends the body's emote; the gloves' own is stopped by utils_fphands::Stop_Emote, which calls this. The owner
    // forwards the stop.
    void Request_StopEmote()
    {
        if (StopBodyEmote() && IsLocallyControlled())
        { Server_StopEmote(); }
    }

    // A held item's strike starts (UMars_SmTask_ItemUse_Strike): the hand swings InRequest's arc. Here that moves the
    // owner's gloves and held item (the swing node) and, through Update_BodyHold, this copy's body; the request is
    // carried to the other machines, whose bodies swing the same arc. Nothing swings before the entity is composed.
    UFUNCTION()
    void Request_Strike(FMars_Request_HandSwing_Start InRequest)
    {
        if (ck::Is_NOT_Valid(_HandSwing))
        { return; }

        _HandSwing.Request_Start(InRequest);

        if (IsLocallyControlled())
        { Server_PlayStrike(InRequest); }
    }

    // A fist was thrown here (Punch.OnThrown). The owner's own jab (a Throw whose turn came) is carried to the other
    // machines, whose copies mirror it on their bodies; a mirrored jab arrives on a copy this machine does not control,
    // and is not carried on.
    UFUNCTION()
    private void OnPunchThrown(FCk_Handle_Punch InPunch, EMars_Hand InHand)
    {
        if (IsLocallyControlled())
        { Server_PlayPunch(InHand); }
    }

    // Unreliable, both ways: a jab is a quarter-second cosmetic on the other machines, thrown several times a second. A
    // lost one is skipped, and the next names its own hand.
    UFUNCTION(Server, Unreliable)
    void Server_PlayPunch(EMars_Hand InHand)
    {
        Multicast_PlayPunch(InHand);
    }

    // The owner's copy already threw it. A copy whose entity is not composed yet shows no jab.
    UFUNCTION(NetMulticast, Unreliable)
    void Multicast_PlayPunch(EMars_Hand InHand)
    {
        if (IsLocallyControlled() || ck::Is_NOT_Valid(_Punch))
        { return; }

        _Punch.Request_Mirror(FMars_Request_Punch_Mirror(InHand));
}

    // A strike abandoned mid-swing (UMars_SmTask_ItemUse_Strike's exit): the hand recovers from where it is, here and,
    // carried as the start was, on every other machine.
    UFUNCTION()
    void Request_CancelStrike()
    {
        if (ck::Is_NOT_Valid(_HandSwing))
        { return; }

        _HandSwing.Request_Cancel(FMars_Request_HandSwing_Cancel());

        if (IsLocallyControlled())
        { Server_CancelStrike(); }
    }

    UFUNCTION(Server)
    void Server_PlayEmote(EMars_FPEmote InEmote)
    {
        Multicast_PlayEmote(InEmote);
    }

    // The owner's gloves never replay here: the owner is the one copy that is skipped.
    UFUNCTION(NetMulticast)
    void Multicast_PlayEmote(EMars_FPEmote InEmote)
    {
        if (IsLocallyControlled())
        { return; }

        PlayBodyEmote(InEmote);
    }

    UFUNCTION(Server)
    void Server_StopEmote()
    {
        Multicast_StopEmote();
    }

    UFUNCTION(NetMulticast)
    void Multicast_StopEmote()
    {
        if (IsLocallyControlled())
        { return; }

        StopBodyEmote();
    }

    // The owning client's operator input while it operates (UMars_SmTask_Operating_SendInput), applied to the authority's
    // copy of this player's InputIntents. Unreliable: each sample carries totals, so the next one makes up a lost one. Kept
    // only while this player operates a station that reads its operator on the authority
    // (utils_station::Get_TakesRemoteInput): a sample sent before the release reached the client would otherwise leave a
    // hold and a look total behind for the next station. A sample that arrives before this copy composed its entity is
    // dropped (the next one seeds).
    UFUNCTION(Server, Unreliable)
    void Server_OperatorInput(FMars_InputIntents_RemoteSample InSample)
    {
        auto Intents = _PlayerEntity.As_InputIntents(ECk_SanityCheck::UnChecked);
        auto Operator = _PlayerEntity.As_Operator(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(Intents) || ck::Is_NOT_Valid(Operator) || utils_station::Get_TakesRemoteInput(Operator.Get_Station()) == false)
        { return; }

        Intents.Request_ApplyRemoteSample(FMars_Request_InputIntents_ApplyRemoteSample(InSample));
    }

    // The owning client's pull of the control it grips (UMars_SmTask_ManipulateControl), paced by the Control's rule and
    // issued on every control the authority granted this player and it still holds (utils_control::Get_HeldControls);
    // the drain applies it only from the current gripper. Unreliable: each report is an absolute pull, so a lost one
    // costs one step of a remote handle's motion and nothing is resent. A player that holds nothing issues nothing.
    UFUNCTION(Server, Unreliable)
    void Server_ControlPull(float32 InPull)
    {
        auto Controls = utils_control::Get_HeldControls(_PlayerEntity);
        for (int32 Index = 0; Index < Controls.Num(); ++Index)
        { Controls[Index].Request_ReportPull(FMars_Request_Control_ReportPull(_PlayerEntity, InPull)); }
    }

    UFUNCTION(Server)
    void Server_PlayStrike(FMars_Request_HandSwing_Start InRequest)
    {
        Multicast_PlayStrike(InRequest);
    }

    // A copy whose entity is not composed yet (the swing arrived before its construction) shows no swing.
    UFUNCTION(NetMulticast)
    void Multicast_PlayStrike(FMars_Request_HandSwing_Start InRequest)
    {
        if (IsLocallyControlled() || ck::Is_NOT_Valid(_HandSwing))
        { return; }

        _HandSwing.Request_Start(InRequest);
    }

    UFUNCTION(Server)
    void Server_CancelStrike()
    {
        Multicast_CancelStrike();
    }

    // A copy at rest ignores the cancel (the swing kernel's rule).
    UFUNCTION(NetMulticast)
    void Multicast_CancelStrike()
    {
        if (IsLocallyControlled() || ck::Is_NOT_Valid(_HandSwing))
        { return; }

        _HandSwing.Request_Cancel(FMars_Request_HandSwing_Cancel());
    }

    private bool PlayBodyEmote(EMars_FPEmote InEmote)
    {
        const auto& Montages = Config.TPBody.Montages.EmoteMontages;
        if (Montages.Contains(InEmote) == false)
        { return false; }

        auto Montage = PlayBodyMontage(Montages[InEmote]);
        if (ck::Is_NOT_Valid(Montage))
        { return false; }

        _BodyEmoteMontage = Montage;
        return true;
    }

    // True when it stopped a body emote that was still playing.
    private bool StopBodyEmote()
    {
        auto Montage = _BodyEmoteMontage;
        _BodyEmoteMontage = nullptr;

        auto AnimInstance = Mesh.GetAnimInstance();
        if (ck::Is_NOT_Valid(AnimInstance) || ck::Is_NOT_Valid(Montage) || AnimInstance.Montage_IsPlaying(Montage) == false)
        { return false; }

        AnimInstance.Montage_Stop(Config.TPBody.Montages.EmoteCancelBlendSeconds, Montage);
        return true;
    }

    // Null when the montage is unset or did not load, or the body has no anim instance (yet).
    private UAnimMontage PlayBodyMontage(TSoftObjectPtr<UAnimMontage> InMontage)
    {
        if (InMontage.IsNull())
        { return nullptr; }

        auto AnimInstance = Mesh.GetAnimInstance();
        auto Montage = System::LoadAsset_Blocking(InMontage);
        if (ck::Is_NOT_Valid(AnimInstance) || ck::Is_NOT_Valid(Montage))
        { return nullptr; }

        AnimInstance.Montage_Play(Montage);
        return Montage;
    }

    //----------------------------------------------------------------------------------------------------------------------
    // The held item on the body (Mars_HeldView.as). Every copy derives the hold from its own HeldItem (OnHeldItemChanged):
    // the item itself is on the hand mount, drawn by its own world item; ABP_Chef's IK aims the arms at the hold. Nothing
    // about it replicates.
    //----------------------------------------------------------------------------------------------------------------------

    // The eased arm targets, component space; UMars_Chef_AnimInstance reads them after Update_BodyHold.
    UFUNCTION()
    FMars_TPBody_HoldFrame Get_BodyHoldFrame() const
    {
        return _BodyHoldFrame;
    }

    // Eases the arms toward _HeldGrip's hold. Driven by UMars_Chef_AnimInstance's update (the body's anim always ticks,
    // see Mesh's VisibilityBasedAnimTickOption), so the arms move exactly as often as the pose is evaluated and the
    // character needs no actor tick. While the hand swings (a held item's strike), the hold is rebuilt around the
    // swing's pose every update and taken as is: the swing is the motion, and easing it would blunt the blow. With empty
    // hands the fists' jabs (Punch) throw the arms the same way, each arm by its own fist.
    void Update_BodyHold(float32 InDeltaSeconds)
    {
        auto Target = _BodyHoldTarget;
        const auto& Speed = Config.TPBody.Hold.InterpSpeed;
        auto Step = Speed.IsSet() ? Math::Clamp(InDeltaSeconds * Speed.GetValue(), 0.0f, 1.0f) : 1.0f;
        const auto IsEmptyHanded = _HeldGrip.Kind == EMars_FPHands_HoldKind::Empty;
        if (IsEmptyHanded == false && ck::IsValid(_HandSwing) && _HandSwing.Get_IsSwinging())
        {
            auto Query = _BodyHoldQuery;
            Query.Swing = _HandSwing.Get_Pose();
            Target = utils_held_view::Make_HoldFrame(Query);
            Step = 1.0f;
        }
        else if (IsEmptyHanded && ck::IsValid(_Punch) && _Punch.Get_IsPunching())
        {
            Target = utils_held_view::Make_PunchFrame(Make_BodyPunchQuery());
            Step = 1.0f;
        }

        _BodyHoldFrame.Left = utils_held_view::Ease_Arm(_BodyHoldFrame.Left, Target.Left, Step);
        _BodyHoldFrame.Right = utils_held_view::Ease_Arm(_BodyHoldFrame.Right, Target.Right, Step);
    }

    // The body's jabs this update: each fist's travel eased as the gloves ease it (Config.FPHands.Punch), with the
    // gloves' punch rotations, on the body's own arms.
    private FMars_TPBody_PunchQuery Make_BodyPunchQuery()
    {
        const auto& Gloves = Config.FPHands.Punch;
        const auto Alpha_R = utils_fphands::Get_PunchAlpha(Gloves, _Punch.Get_Stroke(EMars_Hand::Right), _Punch.Get_StrokeAlpha(EMars_Hand::Right));
        const auto Alpha_L = utils_fphands::Get_PunchAlpha(Gloves, _Punch.Get_Stroke(EMars_Hand::Left), _Punch.Get_StrokeAlpha(EMars_Hand::Left));

        auto Query = FMars_TPBody_PunchQuery();
        Query.Hold = Config.TPBody.Hold;
        Query.Punch = Config.TPBody.Punch;
        Query.Right = FMars_TPBody_PunchArm(Alpha_R, Gloves.GripRotation_R, Get_HandInGrip(BodyGripBone_R));
        Query.Left = FMars_TPBody_PunchArm(Alpha_L, Gloves.GripRotation_L, Get_HandInGrip(BodyGripBone_L));
        return Query;
    }

    // The arms' targets for _HeldGrip. Empty hands lower both arms (they keep their last targets while the alphas ease out).
    private void Apply_BodyHold()
    {
        const auto& Grip = _HeldGrip;
        if (Grip.Kind == EMars_FPHands_HoldKind::Empty)
        {
            _BodyHoldTarget.Left.Alpha = 0.0f;
            _BodyHoldTarget.Right.Alpha = 0.0f;
            return;
        }

        const auto& Body = Config.TPBody;
        const auto HandsSpec = Make_BodyHandsSpec();
        auto Query = FMars_TPBody_HoldQuery();
        Query.Grips = utils_held_view::Get_GripTargets(HandsSpec, Grip);
        Query.Kind = Grip.Kind;
        Query.IsSocketGrip = Grip.HasSocketGrips;
        Query.Hold = Body.Hold;
        Query.BodyScale = Body.Scale;
        Query.HandInGrip_R = Get_HandInGrip(BodyGripBone_R);
        Query.HandInGrip_L = Get_HandInGrip(BodyGripBone_L);
        _BodyHoldQuery = Query;
        _BodyHoldTarget = utils_held_view::Make_HoldFrame(Query);
    }

    // On the copy that is its player's own view (the hand mount is first-person), HeldItemShadow draws InItem's
    // Presentation mesh relative to grip_r where the first-person item sits relative to the right glove's grip, so the
    // owner's held item still casts a shadow. Nothing for empty hands, and nothing on every other copy, where the item's
    // own world item is in the body's hand. Refreshed on every held-item change and when the mount turns first-person.
    private void Refresh_HeldItemShadow(const FCk_Handle_Item& InItem)
    {
        if (_HandMountIsFirstPerson == false || _HeldGrip.Kind == EMars_FPHands_HoldKind::Empty || ck::Is_NOT_Valid(InItem)
            || InItem.Has_Presentation() == false)
        {
            HeldItemShadow.SetStaticMesh(nullptr);
            return;
        }

        const auto Presentation = InItem.Get_Presentation();
        UStaticMesh ItemMesh = nullptr;
        if (Presentation.Visual.Mesh.IsNull() == false)
        { ItemMesh = System::LoadAsset_Blocking(Presentation.Visual.Mesh); }

        // No material clears the override (the mesh's own material shows), as on the WorldItem visual.
        UMaterialInterface ItemMaterial = nullptr;
        if (Presentation.Visual.MaterialOverride.IsNull() == false)
        { ItemMaterial = System::LoadAsset_Blocking(Presentation.Visual.MaterialOverride); }

        HeldItemShadow.SetStaticMesh(ItemMesh);
        HeldItemShadow.SetMaterial(0, ItemMaterial);
        const auto ItemInGrip = utils_held_view::Get_ItemInGrip(Make_BodyHandsSpec(), Presentation.Mounting.HeldOffset, _HeldGrip);
        HeldItemShadow.SetRelativeTransform(utils_held_view::Get_BodyItemTransform(ItemInGrip, Presentation.Visual.MeshScale, Config.TPBody.Scale));
    }

    // The grip bone's parent (the hand ABP_Chef's IK moves) relative to the grip bone, from the body's reference pose.
    private FTransform Get_HandInGrip(FName InGripBone)
    {
        const auto Index = Mesh.GetBoneIndex(InGripBone);
        if (ck::EnsureIfNot(Index >= 0, f"[PlayerCharacter] TPBody: the body mesh has no [{InGripBone}] bone for the held item"))
        { return FTransform::Identity; }

        return Mesh.GetRefPoseTransform(Index).Inverse();
    }
}
