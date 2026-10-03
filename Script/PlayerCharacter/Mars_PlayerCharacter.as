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

    // The chef's hat (Config.TPBody.Head.Hat), a cosmetic on the body's Hat socket: it follows the head and takes the body's
    // scale through the attachment. Hidden from the owner with the body. CharacterMesh0 is ACharacter's Mesh.
    UPROPERTY(DefaultComponent, Attach = CharacterMesh0, AttachSocket = Hat)
    UStaticMeshComponent Hat;
    default Hat.SetMobility(EComponentMobility::Movable);
    default Hat.bOwnerNoSee = true;
    default Hat.CastShadow = true;
    default Hat.bReceivesDecals = false;
    default Hat.SetCollisionEnabled(ECollisionEnabled::NoCollision);

    // The held item as other players see it: in the body's right hand (a bone is a valid socket; the AttachSocket warning
    // before the body mesh is assigned at spawn is harmless). Pawn-owned so OwnerNoSee works: the owner sees its
    // first-person item instead, and (WorldSpaceRepresentation, set in ConstructionScript) only this one's shadow.
    UPROPERTY(DefaultComponent, Attach = CharacterMesh0, AttachSocket = grip_r)
    UStaticMeshComponent BodyHeldItem;
    default BodyHeldItem.SetMobility(EComponentMobility::Movable);
    default BodyHeldItem.bOwnerNoSee = true;
    default BodyHeldItem.CastShadow = true;
    default BodyHeldItem.bReceivesDecals = false;
    default BodyHeldItem.SetCollisionEnabled(ECollisionEnabled::NoCollision);

    UPROPERTY(ExposeOnSpawn)
    UMars_PlayerCharacter_Config Config = mars::Mars_PlayerCharacter_Config;

    private FCk_Handle_Gait _Gait;
    private FCk_Handle_Transform _HandNode;
    private FCk_Handle_Sway _HandSway;
    private FCk_Handle_FPHands _Hands;
    // The body emote montage last played on this machine (Stop_FPEmote ends it); null when none.
    private UAnimMontage _BodyEmoteMontage;
    // The player entity's transform once constructed; invalid before (the eyes wait for it).
    private FCk_Handle_Transform _PlayerTransform;
    // The chef's face node carrying Gaze, Eyes and the eye plate; invalid while there are no eyes (see RefreshEyes).
    private FCk_Handle_Transform _Face;

    // What this player holds, for everyone (Mars_HeldView.as). The owner sets it (Request_SetHeldView); the server's copy
    // replicates to every client, late joiners included.
    UPROPERTY(Replicated, ReplicatedUsing = OnRep_HeldView)
    private FMars_HeldView _HeldView;

    // The arms' targets for _HeldView at full alpha, and the eased frame the anim instance reads (Update_BodyHold).
    private FMars_TPBody_HoldFrame _BodyHoldTarget;
    private FMars_TPBody_HoldFrame _BodyHoldFrame;

    // The body's grip bones: the gloves' grip axes, children of the hand bones ABP_Chef's IK moves.
    private const FName BodyGripBone_R = n"grip_r";
    private const FName BodyGripBone_L = n"grip_l";

    // The eye plate is the engine plane (100 uu). Taking its face as local +Z with U along local +X and V along local +Y:
    // the yaw and roll turn its face to the face node's +X with U along +Y, and the negative Y scale sends V down (the
    // look moves the shapes toward +U for a target on the face's right). Same recipe as UMars_EyesDummy_EntityScript.
    private const FRotator EyePlateRotation = FRotator(0.0, 90.0, -90.0);

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

        // The gloves render first-person; held items tag themselves as they attach under the hand (Mars_FPHands_View).
        const auto& View = Config.FPHands.View;
        const auto IsFirstPerson = View.FirstPersonRendering == ECk_EnableDisable::Enable;
        FPHands.SetFirstPersonPrimitiveType(IsFirstPerson ? EFirstPersonPrimitiveType::FirstPerson : EFirstPersonPrimitiveType::None);
        // The body and its held item stay hidden from the owner but cast the owner's shadow (the first-person shadow path).
        const auto BodyType = IsFirstPerson ? EFirstPersonPrimitiveType::WorldSpaceRepresentation : EFirstPersonPrimitiveType::None;
        Mesh.SetFirstPersonPrimitiveType(BodyType);
        BodyHeldItem.SetFirstPersonPrimitiveType(BodyType);
        CameraComponent.SetEnableFirstPersonScale(IsFirstPerson);
        CameraComponent.SetFirstPersonScale(View.FirstPersonScale);

        if (Config.FPHands.Mesh.IsNull() == false)
        { FPHands.SetSkeletalMeshAsset(System::LoadAsset_Blocking(Config.FPHands.Mesh)); }

        if (Config.FPHands.AnimClass.IsNull() == false)
        { FPHands.SetAnimInstanceClass(System::LoadClassAsset_Blocking(Config.FPHands.AnimClass)); }

        ConstructBody();
    }

    // Before PostInitializeComponents, so ACharacter caches this placement as the mesh's base (crouch offsets it).
    private void ConstructBody()
    {
        const auto& Body = Config.TPBody;
        const auto Validation = Body.Validate();
        if (ck::EnsureIfNot(Validation.IsValid, f"[PlayerCharacter] TPBody: {Validation.Get_Error()}"))
        { return; }

        Mesh.SetSkeletalMeshAsset(System::LoadAsset_Blocking(Body.Mesh));
        Mesh.SetAnimInstanceClass(System::LoadClassAsset_Blocking(Body.AnimClass));

        // MeshOffset is relative to the capsule's base; the capsule's origin is its centre.
        const auto FeetLocation = Body.MeshOffset.GetLocation() - FVector(0.0, 0.0, Config.CapsuleHalfHeight);
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
        // Resizes with the capsule, so a crouched player is a crouched-height body to those volumes.
        auto BodyProbeSpec = FCk_Probe_Spec(GameplayTags::ResolveGameplayTag(n"Probe.Mars.Player"));
        BodyProbeSpec.Set_MotionType(ECk_MotionType::Kinematic)
                     .Set_ResponsePolicy(ECk_ProbeResponse_Policy::Silent);
        auto BodyProbe = utils_body_probe::Create(PlayerTransform, BodyProbeSpec, this);
        utils_handle::Set_DebugName(FCk_Handle(BodyProbe), n"Player.Probe.Body");

        auto DownedSpec = FCk_ByteAttribute_Spec(GameplayTags::ByteAttribute_Mars_Player_Downed, 0);
        DownedSpec.Set_MinMax(ECk_MinMax::MinMax).Set_MinValue(0).Set_MaxValue(1);
        utils_byte_attribute::Add(Player, DownedSpec, ECk_Replication::DoesNotReplicate);

        // Hangs off the rendered view (the director's view anchor), so it carries the view's yaw in the same frame. The
        // pitch node in between is turned by the FPHands feature: the gloves take only part of the view's pitch
        // (Config.FPHands.Pitch) and stay low when the player looks up.
        auto ViewAnchor = Camera.Get_ViewAnchor();
        auto HandPitch = utils_scene_node::Create(ViewAnchor, FTransform::Identity);
        utils_handle::Set_DebugName(FCk_Handle(HandPitch), n"Player.HandPitch");
        auto HandPitchTransform = HandPitch.As_Transform();
        auto Hand = utils_scene_node::Create(HandPitchTransform, utils_fphands::Get_HandRestOffset(Config.FPHands, FMars_FPHands_Hold(), Config.HandOffset));
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
        auto HandsSpec = Config.FPHands;
        HandsSpec.Pitch.Node = HandPitch;
        _Hands = utils_fphands::Add(Player, HandsSpec, _HandNode);

        auto Back = utils_scene_node::Create(PlayerTransform, Config.BackOffset);
        utils_handle::Set_DebugName(FCk_Handle(Back), n"Player.Back");

        auto AttachPointsSpec = FMars_AttachPoints_Spec();
        AttachPointsSpec.Points.Add(FMars_AttachPoint_Entry(GameplayTags::AttachPoint_Mars_Hand, _HandNode));
        AttachPointsSpec.Points.Add(FMars_AttachPoint_Entry(GameplayTags::AttachPoint_Mars_Back, Back.As_Transform()));
        // Other characters' gazes look here: Player.Head is the bob node the camera director renders from, i.e. the eyes.
        AttachPointsSpec.Points.Add(FMars_AttachPoint_Entry(GameplayTags::AttachPoint_Mars_Head, HeadTransform));
        utils_attach_points::Add(Player, AttachPointsSpec);

        auto HotbarSpec = FMars_Hotbar_Spec();
        HotbarSpec.BagSlotCount = Config.BagSlotCount;
        utils_hotbar::Add(Player, HotbarSpec);
        auto HeldItem = utils_held_item::Add(Player);
        HeldItem.BindTo_OnHeldItemChanged(FMars_Delegate_HeldItem_OnHeldItemChanged(this, n"OnHeldItemChanged"));
        utils_held_item_use::Add(Player);
        utils_emote_wheel::Add(Player, Config.EmoteWheel);
        utils_climber::Add(Player, FMars_Climber_Spec(Config.ClimbSpeed));
        utils_operator::Add(Player);

        utils_state_machine::Add(Player, FCk_StateMachine_Spec(UMars_SmState_Alive));

        _PlayerTransform = PlayerTransform;
        RefreshEyes();
    }

    //----------------------------------------------------------------------------------------------------------------------
    // The chef's eyes: a face node following the head bone carries Gaze (looking at other players' heads), Eyes and the
    // eye plate. Only copies other players see have them: the owner's view sits at the face, and the plate (a
    // CkUnrealComponent outered to this actor) cannot be hidden from the owner by OwnerNoSee. Possession can land after
    // the entity is constructed (an owning client learns its controller by replication), so a controller change
    // re-decides.
    //----------------------------------------------------------------------------------------------------------------------

    // Server and owning client (APawn::NotifyControllerChanged); Possessed/Unpossessed fire on the server only. A pawn
    // being destroyed is unpossessed first (APawn::Destroyed) and must not grow eyes on its way out.
    UFUNCTION(BlueprintOverride)
    void ControllerChanged(AController OldController, AController NewController)
    {
        if (IsActorBeingDestroyed())
        { return; }

        RefreshEyes();
    }

    private void RefreshEyes()
    {
        if (ck::Is_NOT_Valid(_PlayerTransform))
        { return; }

        const auto WantsEyes = IsLocallyControlled() == false;
        const auto HasEyes = ck::IsValid(_Face);
        if (WantsEyes == HasEyes)
        { return; }

        if (WantsEyes)
        {
            ConstructEyes();
            return;
        }

        // The node's children (the plate, the gaze's sense node) go with it.
        utils_entity_lifetime::Request_DestroyEntity(FCk_Handle(_Face));
        _Face = FCk_Handle_Transform();
    }

    // Where cosmetics cannot run (a dedicated server) the face is only its node and the eyes' logic: no plate, no gaze.
    private void ConstructEyes()
    {
        const auto& FaceSpec = Config.TPBody.Head.Face;
        if (ck::EnsureIfNot(Mesh.DoesSocketExist(FaceSpec.Bone),
            f"[PlayerCharacter] TPBody: the body mesh has no [{FaceSpec.Bone}] bone for the eyes"))
        { return; }

        auto Face = utils_scene_node::CreateAndAttachToUnrealMesh(_PlayerTransform, Mesh, FaceSpec.Bone, FaceSpec.Offset);
        utils_handle::Set_DebugName(FCk_Handle(Face), n"Player.Face");
        _Face = Face.As_Transform();

        auto Plate = FCk_Handle_UnrealComponent();
        if (utils_net::Get_CanExecuteCosmeticEvents(_Face))
        {
            Plate = AddEyePlate(_Face);

            auto GazeSpec = FMars_Gaze_Spec();
            GazeSpec.DetectionFilter.AddTag(GameplayTags::Probe_Mars_Player);
            GazeSpec.AimPoint = GameplayTags::AttachPoint_Mars_Head;
            utils_gaze::Add(_Face, GazeSpec);
        }

        auto Eyes = utils_eyes::Add(_Face, Config.Eyes);
        if (ck::IsValid(Eyes) && ck::IsValid(Plate))
        { Eyes.Set_Plate(Plate); }
    }

    // Invalid when the MarsEyePlate look master is not generated (the eyes then have logic but nothing to draw on).
    private FCk_Handle_UnrealComponent AddEyePlate(FCk_Handle_Transform& InFace)
    {
        auto LookMaster = utils_usf::Get_LookMasterMaterial(mars_eyes::Look_EyePlate());
        if (ck::EnsureIfNot(ck::IsValid(LookMaster),
            "[PlayerCharacter] the MarsEyePlate look master is not generated - run Ck_Usf_GenerateLooks MarsEyePlate"))
        { return FCk_Handle_UnrealComponent(); }

        // Movable: the component is registered first and then receives the entity transform, which a Static component
        // refuses once the world has begun play.
        auto Archetype = NewObject(this, UStaticMeshComponent);
        Archetype.SetMobility(EComponentMobility::Movable);
        Archetype.SetStaticMesh(engine::load::Plane());
        Archetype.SetMaterial(0, LookMaster);
        Archetype.SetCollisionProfileName(collision::profile::NoCollision);
        Archetype.SetCastShadow(false);

        // The face node carries the body's scale; the plate undoes it so PlateSize is world cm.
        const auto& Size = Config.TPBody.Head.Face.PlateSize;
        const auto Scale = float64(Config.TPBody.Scale);
        const auto PlateScale = FVector(Size.X / (100.0 * Scale), -Size.Y / (100.0 * Scale), 1.0);
        auto PlateNode = utils_scene_node::Create(InFace, FTransform(EyePlateRotation, FVector::ZeroVector, PlateScale));
        utils_handle::Set_DebugName(FCk_Handle(PlateNode), n"Player.EyePlate");

        auto ComponentParams = utils_unreal_component::Make_Params_FromArchetype(
            Archetype, ECk_UnrealComponent_TickPolicy::DoNotTick, n"Player_EyePlate");
        return utils_unreal_component::Add(FCk_Handle(PlateNode), ComponentParams);
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Emotes and the strike. The HFSM tasks decide when (emote keys, the emote wheel, a held item's strike); the character
    // only plays the montages and carries them over the network. The machine that asks plays at once - the owner's
    // gloves, and its body for a listen host's view - and, when it is the owner, forwards to the server, which
    // multicasts. Each multicast skips the locally controlled copy (the owner already played it), so every machine
    // plays an emote exactly once. A call on a machine that does not control this character stays local.
    //----------------------------------------------------------------------------------------------------------------------

    // The one emote entry point. False while the gloves are busy (holding an item or reaching for something), or when
    // neither the gloves nor the body has a montage for it.
    UFUNCTION()
    bool Request_Emote(EMars_FPEmote InEmote)
    {
        if (ck::Is_NOT_Valid(_Hands) || _Hands.Get_Hold().IsHolding || _Hands.Get_Phase() != EMars_FPHands_Phase::None)
        { return false; }

        const auto IsOwner = IsLocallyControlled();
        const auto PlayedHands = IsOwner && PlayHandsEmote(InEmote);
        const auto PlayedBody = PlayBodyEmote(InEmote);
        if (PlayedHands == false && PlayedBody == false)
        { return false; }

        if (IsOwner)
        { Server_PlayEmote(InEmote); }

        return true;
    }

    // Hands the gloves back to the procedural placement (a reach or a newly held item takes over) and ends the body's
    // emote with them; the owner forwards the stop.
    void Stop_FPEmote()
    {
        auto AnimInstance = FPHands.GetAnimInstance();
        if (ck::IsValid(AnimInstance) && AnimInstance.IsAnyMontagePlaying())
        { AnimInstance.Montage_Stop(Config.FPHands.EmoteCancelBlendSeconds); }

        if (StopBodyEmote() && IsLocallyControlled())
        { Server_StopEmote(); }
    }

    // A held item's strike starts (UMars_SmTask_ItemUse_Strike): the body swings. The first-person swing is the item's.
    UFUNCTION()
    void Request_Strike()
    {
        if (ck::Is_NOT_Valid(PlayBodyMontage(Config.TPBody.Montages.StrikeMontage)))
        { return; }

        if (IsLocallyControlled())
        { Server_PlayStrike(); }
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

    UFUNCTION(Server)
    void Server_PlayStrike()
    {
        Multicast_PlayStrike();
    }

    UFUNCTION(NetMulticast)
    void Multicast_PlayStrike()
    {
        if (IsLocallyControlled())
        { return; }

        PlayBodyMontage(Config.TPBody.Montages.StrikeMontage);
    }

    private bool PlayHandsEmote(EMars_FPEmote InEmote)
    {
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

    private bool PlayBodyEmote(EMars_FPEmote InEmote)
    {
        const auto Index = int32(InEmote);
        const auto& Montages = Config.TPBody.Montages.EmoteMontages;
        if (Montages.IsValidIndex(Index) == false)
        { return false; }

        auto Montage = PlayBodyMontage(Montages[Index]);
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
    // The held item on the body (Mars_HeldView.as). The owner describes what its gloves hold; the view replicates and every
    // machine shows it on the body: the item on grip_r, the arms aimed by ABP_Chef's IK. The owner applies at once and,
    // as a client, forwards to the server, which stores the replicated copy and applies it too. OnRep skips the locally
    // controlled copy (the owner already applied it), so every machine applies each change once.
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    void Request_SetHeldView(FMars_HeldView InView)
    {
        auto View = InView;
        View.Serial = _HeldView.Serial + 1;
        _HeldView = View;
        ApplyHeldView();

        if (HasAuthority() == false)
        { Server_SetHeldView(View); }
    }

    UFUNCTION(Server)
    void Server_SetHeldView(FMars_HeldView InView)
    {
        _HeldView = InView;
        ApplyHeldView();
    }

    UFUNCTION()
    private void OnRep_HeldView()
    {
        if (IsLocallyControlled())
        { return; }

        ApplyHeldView();
    }

    // The eased arm targets, component space; UMars_Chef_AnimInstance reads them after Update_BodyHold.
    UFUNCTION()
    FMars_TPBody_HoldFrame Get_BodyHoldFrame() const
    {
        return _BodyHoldFrame;
    }

    // Eases the arms toward _HeldView's hold. Driven by UMars_Chef_AnimInstance's update (the body's anim always ticks,
    // see Mesh's VisibilityBasedAnimTickOption), so the arms move exactly as often as the pose is evaluated and the
    // character needs no actor tick. A body montage while holding is the strike (emotes refuse while holding): the arms
    // let go of the IK for its duration and the swing carries the item on grip_r.
    void Update_BodyHold(float32 InDeltaSeconds)
    {
        auto Target = _BodyHoldTarget;
        auto AnimInstance = Mesh.GetAnimInstance();
        if (ck::IsValid(AnimInstance) && AnimInstance.IsAnyMontagePlaying())
        {
            Target.Left.Alpha = 0.0f;
            Target.Right.Alpha = 0.0f;
        }

        const auto Speed = Config.TPBody.Hold.InterpSpeed;
        const auto Step = Speed <= 0.0f ? 1.0f : Math::Clamp(InDeltaSeconds * Speed, 0.0f, 1.0f);
        _BodyHoldFrame.Left = utils_held_view::Ease_Arm(_BodyHoldFrame.Left, Target.Left, Step);
        _BodyHoldFrame.Right = utils_held_view::Ease_Arm(_BodyHoldFrame.Right, Target.Right, Step);
    }

    // Shows _HeldView on the body: the item mesh relative to grip_r where the first-person system puts it relative to the
    // right glove's grip, and the arms' targets. Empty hands clear the mesh and lower both arms (they keep their last
    // targets while the alphas ease out).
    private void ApplyHeldView()
    {
        const auto& View = _HeldView;
        if (View.IsHolding == false)
        {
            BodyHeldItem.SetStaticMesh(nullptr);
            _BodyHoldTarget.Left.Alpha = 0.0f;
            _BodyHoldTarget.Right.Alpha = 0.0f;
            return;
        }

        const auto& Body = Config.TPBody;
        // The body's own palm thickness replaces the gloves' for the fitted grips; the rest of the layout is the gloves'.
        auto HandsSpec = Config.FPHands;
        HandsSpec.PalmSurfaceOffset = Body.Hold.PalmSurfaceOffset;

        UStaticMesh ItemMesh = nullptr;
        if (View.Mesh.IsNull() == false)
        { ItemMesh = System::LoadAsset_Blocking(View.Mesh); }

        // No material clears the override (the mesh's own material shows), as on the WorldItem visual.
        UMaterialInterface ItemMaterial = nullptr;
        if (View.Material.IsNull() == false)
        { ItemMaterial = System::LoadAsset_Blocking(View.Material); }

        BodyHeldItem.SetStaticMesh(ItemMesh);
        BodyHeldItem.SetMaterial(0, ItemMaterial);
        const auto ItemInGrip = utils_held_view::Get_ItemInGrip(HandsSpec, View);
        BodyHeldItem.SetRelativeTransform(utils_held_view::Get_BodyItemTransform(ItemInGrip, View.MeshScale, Body.Scale));

        auto Query = FMars_TPBody_HoldQuery();
        Query.Grips = utils_held_view::Get_GripTargets(HandsSpec, View.Grip);
        Query.IsTwoHanded = View.Grip.IsTwoHanded;
        Query.Hold = Body.Hold;
        Query.BodyScale = Body.Scale;
        Query.HandInGrip_R = Get_HandInGrip(BodyGripBone_R);
        Query.HandInGrip_L = Get_HandInGrip(BodyGripBone_L);
        _BodyHoldTarget = utils_held_view::Make_HoldFrame(Query);
    }

    // The grip bone's parent (the hand ABP_Chef's IK moves) relative to the grip bone, from the body's reference pose.
    private FTransform Get_HandInGrip(FName InGripBone)
    {
        const auto Index = Mesh.GetBoneIndex(InGripBone);
        if (ck::EnsureIfNot(Index >= 0, f"[PlayerCharacter] TPBody: the body mesh has no [{InGripBone}] bone for the held item"))
        { return FTransform::Identity; }

        return Mesh.GetRefPoseTransform(Index).Inverse();
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

        // Only the owner's held item is real (nothing about items replicates); everyone else learns it from _HeldView.
        if (IsLocallyControlled())
        { Request_SetHeldView(utils_held_view::Make(InNew)); }

        const auto NewRest = utils_fphands::Get_HandRestOffset(Config.FPHands, NewHold, Config.HandOffset);

        if (NewRest.Equals(PrevRest) || ck::Is_NOT_Valid(_HandSway))
        { return; }

        utils_sway::Request_SetRestOffset(_HandSway, FCk_Request_Sway_SetRestOffset(NewRest));
    }
}
