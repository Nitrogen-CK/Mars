class AMars_PlayerCharacter : ACk_Character_UE
{
    default bUseControllerRotationYaw = true;
    default bUseControllerRotationPitch = false;
    default bUseControllerRotationRoll = false;

    // A PlayerStart brushing a prop must not lose the player (UE's own character templates use this). Placement bugs
    // still show as an adjusted spawn location, not a missing pawn.
    default SpawnCollisionHandlingMethod = ESpawnActorCollisionHandlingMethod::AdjustIfPossibleButAlwaysSpawn;

    default CharacterMovement.bOrientRotationToMovement = false;
    default CharacterMovement.NavAgentProps.bCanCrouch = true;
    default CharacterMovement.bCanWalkOffLedgesWhenCrouching = true;

    default Mesh.SetVisibility(false, true);

    // The CkCamera director's output sink. Its GetCameraView delivers the director's composed view to the player camera
    // manager; FollowView also moves the component onto that view each frame, so the gloves attached below render exactly
    // where the view renders. Its placement on the pawn is otherwise irrelevant (the director's anchor is Player.Head).
    UPROPERTY(DefaultComponent)
    UCk_CameraComponent CameraComponent;
    default CameraComponent._Placement = ECk_Camera_OutputComponentPlacement::FollowView;

    // Floating first-person gloves. Owner-only: other players see the full body. Mesh and anim class come from
    // Config.FPHands.Visual; UMars_FPHands_AnimInstance places each glove from the player entity's FPHands feature.
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

    UPROPERTY(ExposeOnSpawn)
    UMars_PlayerCharacter_Config Config = mars::Mars_PlayerCharacter_Config;

    private FCk_Handle_Gait _Gait;
    private FCk_Handle_Transform _HandNode;
    private FCk_Handle_Sway _HandSway;
    private FCk_Handle_FPHands _Hands;

    // The Hand node rest offset last sent to _HandSway. The gloves' own hold only updates at their next drain, so a
    // second item change before it would compare against a stale rest.
    private FTransform _HandRestOffset;

    UFUNCTION(BlueprintOverride)
    void ConstructionScript()
    {
        const auto& Body = Config.Body;
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
        const auto& View = Config.FPHands.View;
        const auto IsFirstPerson = View.FirstPersonRendering == ECk_EnableDisable::Enable;
        FPHands.SetFirstPersonPrimitiveType(IsFirstPerson ? EFirstPersonPrimitiveType::FirstPerson : EFirstPersonPrimitiveType::None);
        CameraComponent.SetEnableFirstPersonScale(IsFirstPerson);
        CameraComponent.SetFirstPersonScale(View.FirstPersonScale);

        const auto& Visual = Config.FPHands.Visual;
        if (Visual.Mesh.IsNull() == false)
        { FPHands.SetSkeletalMeshAsset(System::LoadAsset_Blocking(Visual.Mesh)); }

        if (Visual.AnimClass.IsNull() == false)
        { FPHands.SetAnimInstanceClass(System::LoadClassAsset_Blocking(Visual.AnimClass)); }
    }

    // BeginPlay, not ConstructionScript: ck::TransientEntity() needs a live world.
    UFUNCTION(BlueprintOverride)
    void BeginPlay()
    {
        auto PendingEntity = utils_entity_script::Request_SpawnEntity(
            ck::TransientEntity(), UCk_EntityScript_WithActor_UE, FCk_EntityScript_WithActor_SpawnParams(this));

        utils_pending_entity_script::Promise_OnConstructed(
            PendingEntity, FCk_Delegate_EntityScript_Constructed(this, n"OnEntityConstructed"));
    }

    UFUNCTION()
    private void OnEntityConstructed(FCk_Handle_EntityScript InEntityScriptHandle)
    {
        FCk_Handle Player = InEntityScriptHandle;
        utils_handle::Set_DebugName(Player, n"Player");

        utils_input_intents::Add(Player);
        utils_team::Add(Player, ECk_Team_ID::One, ECk_Replication::DoesNotReplicate);
        utils_damage_dealer::Add(Player, FMars_DamageDealer_Spec());

        // The character's stride clock; the head and hand bobs below read it. The spec's tunables come from the config,
        // its motion source is this pawn's movement component.
        auto GaitSpec = Config.View.Gait;
        GaitSpec.Set_MovementComponent(CharacterMovement);
        _Gait = utils_gait::Add(Player, GaitSpec);

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

        auto ViewpointSpec = Config.View.Viewpoint;
        ViewpointSpec.Camera = Camera;
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

        auto DownedSpec = FCk_ByteAttribute_Spec(GameplayTags::ByteAttribute_Mars_Player_Downed, 0);
        DownedSpec.Set_MinMax(ECk_MinMax::MinMax).Set_MinValue(0).Set_MaxValue(1);
        utils_byte_attribute::Add(Player, DownedSpec, ECk_Replication::DoesNotReplicate);

        // Hangs off the rendered view (the director's view anchor), so it carries the view's pitch in the same frame.
        auto ViewAnchor = Camera.Get_ViewAnchor();
        _HandRestOffset = utils_fphands::Get_HandRestOffset(Config.FPHands.Rest, FMars_FPHands_Hold());
        auto Hand = utils_scene_node::Create(ViewAnchor, _HandRestOffset);
        utils_handle::Set_DebugName(Hand.H(), n"Player.Hand");

        // Damped-spring lag of the hand behind the view. CkSway owns the Hand offset from here on; _HandRestOffset is its rest.
        _HandSway = utils_sway::Add(Hand, Config.HandSway);

        // Locomotion bob under the swaying hand, in phase with the head; the held item and both gloves hang off it.
        auto HandTransform = Hand.As_Transform();
        auto HandBobSpec = Config.FPHands.Bob;
        HandBobSpec.Set_Gait(_Gait);
        auto HandBob = utils_bob::Create(HandTransform, FTransform::Identity, HandBobSpec);
        utils_handle::Set_DebugName(HandBob.H(), n"Player.HandBob");
        _HandNode = HandBob.As_Transform();
        auto HandsSpec = Config.FPHands;
        HandsSpec.HandNode = _HandNode;
        _Hands = utils_fphands::Add(Player, HandsSpec);

        auto Back = utils_scene_node::Create(PlayerTransform, Config.Inventory.BackOffset);
        utils_handle::Set_DebugName(Back.H(), n"Player.Back");

        auto AttachPointsSpec = FMars_AttachPoints_Spec();
        AttachPointsSpec.Points.Add(FMars_AttachPoint_Entry(GameplayTags::AttachPoint_Mars_Hand, _HandNode));
        AttachPointsSpec.Points.Add(FMars_AttachPoint_Entry(GameplayTags::AttachPoint_Mars_Back, Back.As_Transform()));
        // Other characters' gazes look here: Player.Head is the bob node the camera director renders from, i.e. the eyes.
        AttachPointsSpec.Points.Add(FMars_AttachPoint_Entry(GameplayTags::AttachPoint_Mars_Head, HeadTransform));
        utils_attach_points::Add(Player, AttachPointsSpec);

        auto HotbarSpec = FMars_Hotbar_Spec();
        HotbarSpec.BagSlotCount = Config.Inventory.BagSlotCount;
        utils_hotbar::Add(Player, HotbarSpec);
        auto HeldItem = utils_held_item::Add(Player);
        HeldItem.BindTo_OnHeldItemChanged(FMars_Delegate_HeldItem_OnHeldItemChanged(this, n"OnHeldItemChanged"));
        utils_held_item_use::Add(Player);
        utils_emote_wheel::Add(Player, Config.EmoteWheel);
        utils_climber::Add(Player, FMars_Climber_Spec(Config.Movement.Speeds.Climb));
        utils_operator::Add(Player);

        utils_state_machine::Add(Player, FCk_StateMachine_Spec(UMars_SmState_Alive));
    }

    // Empty hands and two-handed holds centre the Hand node between the gloves; one-handed items move it to the right.
    // The gloves' own hold (and the carry of a picked-up item) is the FPHands feature's; the rest offset is measured
    // here from the same item. Stays on the actor: the Hand node's sway handle is held only here.
    UFUNCTION()
    private void OnHeldItemChanged(FCk_Handle_HeldItem InHeldItem, FCk_Handle_Item InPrev, FCk_Handle_Item InNew)
    {
        _Hands.Request_SetHold(FMars_Request_FPHands_SetHold(InNew));

        const auto NewHold = utils_fphands::Make_Hold(InNew);
        if (NewHold.Kind != EMars_FPHands_HoldKind::Empty)
        { utils_fphands::Stop_Emote(_Hands); }

        const auto NewRest = utils_fphands::Get_HandRestOffset(Config.FPHands.Rest, NewHold);
        if (NewRest.Equals(_HandRestOffset))
        { return; }

        _HandRestOffset = NewRest;
        utils_sway::Request_SetRestOffset(_HandSway, FCk_Request_Sway_SetRestOffset(NewRest));
    }
}
