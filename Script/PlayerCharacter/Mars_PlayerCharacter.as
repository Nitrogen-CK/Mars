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
    // Config.FPHands; UMars_FPHands_AnimInstance places each glove from the player entity's FPHands feature.
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

    UFUNCTION(BlueprintOverride)
    void ConstructionScript()
    {
        CapsuleComponent.SetCapsuleSize(Config.CapsuleRadius, Config.CapsuleHalfHeight);
        CameraComponent.SetRelativeLocation(FVector(0.0, 0.0, Config.EyeHeight.Height));

        CharacterMovement.MaxWalkSpeed = Config.WalkSpeed;
        CharacterMovement.MaxWalkSpeedCrouched = Config.CrouchSpeed;
        CharacterMovement.MaxAcceleration = Config.MaxAcceleration;
        CharacterMovement.BrakingDecelerationWalking = Config.BrakingDecelerationWalking;
        CharacterMovement.JumpZVelocity = Config.JumpZVelocity;
        CharacterMovement.GravityScale = Config.GravityScale;
        CharacterMovement.AirControl = Config.AirControl;
        CharacterMovement.SetCrouchedHalfHeight(Config.CrouchedHalfHeight);

        if (Config.FPHands.Mesh.IsNull() == false)
        { FPHands.SetSkeletalMeshAsset(System::LoadAsset_Blocking(Config.FPHands.Mesh)); }

        if (Config.FPHands.AnimClass.IsNull() == false)
        { FPHands.SetAnimInstanceClass(System::LoadClassAsset_Blocking(Config.FPHands.AnimClass)); }
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

        // The character's stride clock; the head and hand bobs below read it. The spec's tunables come from the config,
        // its motion source is this pawn's movement component.
        auto GaitSpec = Config.Gait;
        GaitSpec.Set_MovementComponent(CharacterMovement);
        _Gait = utils_gait::Add(Player, GaitSpec);

        // The view: a bob node on the eye node is the director's input anchor, so the rendered view bobs with the gait
        // (PEAK-style positional bob) and eases with the eye across a crouch. The director lives on the head node;
        // PlayerViewpoint keeps the handles.
        auto PlayerTransform = Player.As_Transform();
        auto Eye = utils_eye_height::Create(PlayerTransform, Config.EyeHeight, this);
        utils_handle::Set_DebugName(FCk_Handle(Eye), n"Player.Eye");
        auto EyeTransform = Eye.As_Transform();
        auto HeadBobSpec = Config.HeadBob;
        HeadBobSpec.Set_Gait(_Gait);
        auto Head = utils_bob::Create(EyeTransform, FTransform::Identity, HeadBobSpec);
        utils_handle::Set_DebugName(FCk_Handle(Head), n"Player.Head");

        auto CameraSpec = FCk_Camera_Spec(CameraComponent);
        CameraSpec.Set_Profile(utils_player_viewpoint::Make_CameraProfile(Config.Viewpoint));
        CameraSpec.Set_DriveControllerControlRotation(true);
        auto HeadTransform = Head.As_Transform();
        auto Camera = utils_camera::Add(HeadTransform, CameraSpec);

        utils_player_viewpoint::Add(Player, Camera, Config.Viewpoint);
        utils_interaction_resolver::Add(Player, Config.InteractionResolver, ECk_Replication::DoesNotReplicate);
        utils_interact_prompt_display::Add(Player);
        utils_action_hint_display::Add(Player);

        // Silent: volumes that filter on Probe.Mars.Player detect the player; the player detects nothing through it.
        auto BodyProbeSpec = FCk_Probe_Spec(GameplayTags::ResolveGameplayTag(n"Probe.Mars.Player"));
        BodyProbeSpec.Set_MotionType(ECk_MotionType::Kinematic)
                     .Set_ResponsePolicy(ECk_ProbeResponse_Policy::Silent);
        auto BodyProbeNode = utils_prefab::Create_ProbeNode_Capsule(
            PlayerTransform, CapsuleComponent.CapsuleHalfHeight, CapsuleComponent.CapsuleRadius, BodyProbeSpec);
        utils_handle::Set_DebugName(FCk_Handle(BodyProbeNode), n"Player.Probe.Body");

        auto DownedSpec = FCk_ByteAttribute_Spec(GameplayTags::ByteAttribute_Mars_Player_Downed, 0);
        DownedSpec.Set_MinMax(ECk_MinMax::MinMax).Set_MinValue(0).Set_MaxValue(1);
        utils_byte_attribute::Add(Player, DownedSpec, ECk_Replication::DoesNotReplicate);

        // Hangs off the rendered view (the director's view anchor), so it carries the view's pitch in the same frame.
        auto ViewAnchor = Camera.Get_ViewAnchor();
        auto Hand = utils_scene_node::Create(ViewAnchor, utils_fphands::Get_HandRestOffset(Config.FPHands, FMars_FPHands_Hold(), Config.HandOffset));
        utils_handle::Set_DebugName(FCk_Handle(Hand), n"Player.Hand");

        // Damped-spring lag of the hand behind the view. CkSway owns the Hand offset from here on; HandOffset is its rest.
        _HandSway = utils_sway::Add(Hand, Config.HandSway);

        // Locomotion bob under the swaying hand, in phase with the head; the held item and both gloves hang off it.
        auto HandTransform = Hand.As_Transform();
        auto HandBobSpec = Config.FPHands.Bob;
        HandBobSpec.Set_Gait(_Gait);
        auto HandBob = utils_bob::Create(HandTransform, FTransform::Identity, HandBobSpec);
        utils_handle::Set_DebugName(FCk_Handle(HandBob), n"Player.HandBob");
        _HandNode = HandBob.As_Transform();
        _Hands = utils_fphands::Add(Player, Config.FPHands, _HandNode);

        auto Back = utils_scene_node::Create(PlayerTransform, Config.BackOffset);
        utils_handle::Set_DebugName(FCk_Handle(Back), n"Player.Back");

        auto AttachPointsSpec = FMars_AttachPoints_Spec();
        AttachPointsSpec.Points.Add(FMars_AttachPoint_Entry(GameplayTags::AttachPoint_Mars_Hand, _HandNode));
        AttachPointsSpec.Points.Add(FMars_AttachPoint_Entry(GameplayTags::AttachPoint_Mars_Back, Back.As_Transform()));
        utils_attach_points::Add(Player, AttachPointsSpec);

        auto HotbarSpec = FMars_Hotbar_Spec();
        HotbarSpec.BagSlotCount = Config.BagSlotCount;
        utils_hotbar::Add(Player, HotbarSpec);
        auto HeldItem = utils_held_item::Add(Player);
        HeldItem.BindTo_OnHeldItemChanged(FMars_Delegate_HeldItem_OnHeldItemChanged(this, n"OnHeldItemChanged"));
        utils_held_item_use::Add(Player);
        utils_emote_wheel::Add(Player, Config.EmoteWheel);

        utils_state_machine::Add(Player, FCk_StateMachine_Spec(UMars_SmState_Alive));
    }

    // Plays an emote on the first-person gloves. False while they are busy (holding an item or reaching for something).
    UFUNCTION()
    bool Request_FPEmote(EMars_FPEmote InEmote)
    {
        if (ck::Is_NOT_Valid(_Hands) || _Hands.Get_Hold().IsHolding || _Hands.Get_Phase() != EMars_FPHands_Phase::None)
        { return false; }

        const auto Index = int32(InEmote);
        const auto& Montages = Config.FPHands.EmoteMontages;
        if (Montages.IsValidIndex(Index) == false || Montages[Index].IsNull())
        { return false; }

        auto AnimInstance = FPHands.GetAnimInstance();
        auto Montage = System::LoadAsset_Blocking(Montages[Index]);
        if (ck::Is_NOT_Valid(AnimInstance) || ck::Is_NOT_Valid(Montage))
        { return false; }

        AnimInstance.Montage_Play(Montage);
        return true;
    }

    // Hands the gloves back to the procedural placement (a reach or a newly held item takes over).
    void Stop_FPEmote()
    {
        auto AnimInstance = FPHands.GetAnimInstance();
        if (ck::IsValid(AnimInstance) && AnimInstance.IsAnyMontagePlaying())
        { AnimInstance.Montage_Stop(Config.FPHands.EmoteCancelBlendSeconds); }
    }

    // Empty hands and two-handed holds centre the Hand node between the gloves; one-handed items move it to the right.
    // The gloves' own hold (and the carry of a picked-up item) is the FPHands feature's; the rest offset is measured
    // here from the same item.
    UFUNCTION()
    private void OnHeldItemChanged(FCk_Handle_HeldItem InHeldItem, FCk_Handle_Item InPrev, FCk_Handle_Item InNew)
    {
        const auto PrevRest = utils_fphands::Get_HandRestOffset(Config.FPHands, _Hands.Get_Hold(), Config.HandOffset);
        _Hands.Request_SetHold(FMars_Request_FPHands_SetHold(InNew));

        const auto NewHold = utils_fphands::Make_Hold(InNew);
        if (NewHold.IsHolding)
        { Stop_FPEmote(); }

        const auto NewRest = utils_fphands::Get_HandRestOffset(Config.FPHands, NewHold, Config.HandOffset);

        if (NewRest.Equals(PrevRest) || ck::Is_NOT_Valid(_HandSway))
        { return; }

        utils_sway::Request_SetRestOffset(_HandSway, FCk_Request_Sway_SetRestOffset(NewRest));
    }
}
