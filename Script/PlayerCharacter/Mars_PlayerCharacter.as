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

    UPROPERTY(DefaultComponent)
    UCameraComponent FirstPersonCamera;
    default FirstPersonCamera.bUsePawnControlRotation = true;

    // Floating first-person gloves. Owner-only: other players see the full body. Mesh and anim class come from
    // Config.FPHands; UMars_FPHands_AnimInstance places each glove on the targets from Get_FPHandTargets.
    UPROPERTY(DefaultComponent, Attach = FirstPersonCamera)
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

    private FCk_Handle _PlayerEntity;
    private FCk_Handle_Transform _HandNode;
    private FMars_FPHands_Reach _Reach;
    private FMars_FPHands_Carry _Carry;
    private FCk_Handle_Sway _HandSway;
    private FMars_FPHands_Hold _Hold;

    UFUNCTION(BlueprintOverride)
    void ConstructionScript()
    {
        CapsuleComponent.SetCapsuleSize(Config.CapsuleRadius, Config.CapsuleHalfHeight);
        FirstPersonCamera.SetRelativeLocation(FVector(0.0, 0.0, Config.EyeHeight));

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
        _PlayerEntity = Player;

        utils_input_intents::Add(Player);
        utils_player_viewpoint::Add(Player, FirstPersonCamera.GetWorldTransform(), Config.Viewpoint);
        auto Resolver = utils_interaction_resolver::Add(Player, Config.InteractionResolver, ECk_Replication::DoesNotReplicate);
        Resolver.BindTo_OnBestTargetsChanged(
            FCk_Delegate_InteractionResolver_OnBestTargetsChanged(this, n"OnBestTargetsChanged_FPHands"));
        utils_interact_prompt_display::Add(Player);
        utils_action_hint_display::Add(Player);

        // Silent: volumes that filter on Probe.Mars.Player detect the player; the player detects nothing through it.
        auto PlayerTransform = Player.As_Transform();
        auto BodyProbeSpec = FCk_Probe_Spec(GameplayTags::ResolveGameplayTag(n"Probe.Mars.Player"));
        BodyProbeSpec.Set_MotionType(ECk_MotionType::Kinematic)
                     .Set_ResponsePolicy(ECk_ProbeResponse_Policy::Silent);
        auto BodyProbeNode = utils_prefab::Create_ProbeNode_Capsule(
            PlayerTransform, CapsuleComponent.CapsuleHalfHeight, CapsuleComponent.CapsuleRadius, BodyProbeSpec);
        utils_handle::Set_DebugName(FCk_Handle(BodyProbeNode), n"Player.Probe.Body");

        auto DownedSpec = FCk_ByteAttribute_Spec(GameplayTags::ByteAttribute_Mars_Player_Downed, 0);
        DownedSpec.Set_MinMax(ECk_MinMax::MinMax).Set_MinValue(0).Set_MaxValue(1);
        utils_byte_attribute::Add(Player, DownedSpec, ECk_Replication::DoesNotReplicate);

        // Follows the first-person camera; only the held item's mesh is visible under it.
        auto Hand = utils_scene_node::CreateAndAttachToUnrealComponent(PlayerTransform, FirstPersonCamera,
            mars_fphands::Get_HandRestOffset(Config.FPHands, _Hold, Config.HandOffset));
        utils_handle::Set_DebugName(FCk_Handle(Hand), n"Player.Hand");

        // Damped-spring lag of the hand behind the camera. CkSway owns the Hand offset from here on; HandOffset is its rest.
        _HandSway = utils_sway::Add(Hand, Config.HandSway);

        // Locomotion bob under the swaying hand; the held item and both gloves hang off it.
        auto HandBob = utils_scene_node::Create(Hand.As_Transform(), FTransform::Identity);
        utils_handle::Set_DebugName(FCk_Handle(HandBob), n"Player.HandBob");
        utils_hand_bob::Add(HandBob, Config.FPHands.Bob);
        _HandNode = HandBob.As_Transform();

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

        utils_state_machine::Add(Player, FCk_StateMachine_Spec(UMars_SmState_Alive));
    }

    // Where each first-person glove's grip bone goes this frame, relative to the swaying, bobbing hand node
    // (OutHandWorld). False until the player entity is constructed.
    bool Get_FPHandTargets(FTransform& OutHandWorld, FMars_FPHands_HandTarget& OutLeft, FMars_FPHands_HandTarget& OutRight)
    {
        if (ck::Is_NOT_Valid(_HandNode))
        { return false; }

        OutHandWorld = utils_transform::Get_EntityCurrentTransform(_HandNode);
        mars_fphands::Make_Targets(Config.FPHands, _Hold, _Reach, OutHandWorld,
            utils_hand_bob::Get_ArmSwing_Left(_HandNode), utils_hand_bob::Get_ArmSwing_Right(_HandNode), OutLeft, OutRight);
        return true;
    }

    // Plays an emote on the first-person gloves. False while they are busy (holding an item or reaching for something).
    UFUNCTION()
    bool Request_FPEmote(EMars_FPEmote InEmote)
    {
        if (_Hold.IsHolding || _Reach.Phase != EMars_FPHands_ReachPhase::None)
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

    // What each glove's fingers close on this frame (invalid = keep the authored pose): a reaching glove near contact
    // closes on its target, a holding glove on its item.
    void Get_FPHandContactShapes(const FTransform& InHandWorld, FMars_FPHands_ContactShape& OutLeft, FMars_FPHands_ContactShape& OutRight)
    {
        OutLeft = Make_ContactShape(InHandWorld, false);
        OutRight = Make_ContactShape(InHandWorld, true);
    }

    private FMars_FPHands_ContactShape Make_ContactShape(const FTransform& InHandWorld, bool InIsRightHand)
    {
        const auto& Spec = Config.FPHands;
        if (mars_fphands_reach::Is_Reaching(_Reach, InIsRightHand)
            && mars_fphands_reach::Get_Alpha(_Reach, Spec.Reach) > 0.6f)
        {
            const auto& Target = _Reach.Target;
            if (ck::IsValid(Target.ShapeMesh))
            { return mars_fphands_contact::Make_BoundsShape(Target.ShapeMesh, Target.ShapeScale, Target.ShapeType, Target.AnchorWorld); }

            if (Target.Layout == EMars_FPHands_GripLayout::Authored)
            {
                auto IsAuthored = false;
                return mars_fphands_contact::Make_SocketShape(Spec.Contact,
                    mars_fphands_grips::Get_WorldGrip(Spec, Target, InHandWorld, InIsRightHand, IsAuthored));
            }
            return FMars_FPHands_ContactShape();
        }

        const auto HoldsWithThisHand = _Hold.IsHolding && (_Hold.IsTwoHanded || InIsRightHand);
        if (HoldsWithThisHand && ck::IsValid(_Hold.ShapeMesh))
        { return mars_fphands_contact::Make_BoundsShape(_Hold.ShapeMesh, _Hold.ShapeScale, _Hold.ShapeType, _Hold.ShapeOffset * InHandWorld); }

        return FMars_FPHands_ContactShape();
    }

    // Advances the gloves' reach and focus lean. Called by the gloves' anim instance, so it only runs where they render.
    void Tick_FPHands(float32 InDeltaSeconds)
    {
        if (ck::Is_NOT_Valid(_HandNode))
        { return; }

        // Re-resolve what to lean toward whenever the focused interactable changes.
        auto Focused = mars_interaction_focus::Get(_PlayerEntity);
        if (Focused != _Reach.FocusedFor)
        {
            _Reach.FocusedFor = Focused;
            _Reach.FocusTarget = ck::IsValid(Focused)
                ? Resolve_ReachTarget(Focused, Get_InteractableOwner(Focused))
                : FMars_FPHands_ReachTarget();
        }

        mars_fphands_reach::Tick(_Reach, Config.FPHands.Reach, InDeltaSeconds, ck::IsValid(Focused));
        Tick_Carry(InDeltaSeconds);

        // The grab ended without the item landing in the hands: don't let a later equip spawn at the pickup spot.
        if (_Reach.Phase == EMars_FPHands_ReachPhase::None && _PlayerEntity.Has_Fragment(FMars_Fragment_HeldItem_SpawnFrom))
        {
            auto HeldItem = _PlayerEntity.As_HeldItem();
            HeldItem.Clear_NextSpawnFrom();
        }
    }

    // How far the reaching gloves fall short of their grips (world, averaged over the gloves in use).
    private FVector Get_GloveShortfall(const FTransform& InHandWorld)
    {
        auto Left = FMars_FPHands_HandTarget();
        auto Right = FMars_FPHands_HandTarget();
        mars_fphands::Make_Targets(Config.FPHands, _Hold, _Reach, InHandWorld, FVector::ZeroVector, FVector::ZeroVector, Left, Right);

        auto Sum = FVector::ZeroVector;
        auto Count = 0;
        for (int32 Side = 0; Side < 2; ++Side)
        {
            const auto IsRight = Side == 1;
            if (mars_fphands_grips::Uses(_Reach.Target, IsRight) == false)
            { continue; }

            auto IsAuthored = false;
            const auto Wanted = mars_fphands_grips::Get_WorldGrip(Config.FPHands, _Reach.Target, InHandWorld, IsRight, IsAuthored);
            const auto Reached = (IsRight ? Right.ReachGrip : Left.ReachGrip) * InHandWorld;
            Sum += Reached.GetLocation() - Wanted.GetLocation();
            ++Count;
        }
        return Count > 0 ? Sum / Count : FVector::ZeroVector;
    }

    // The offset request applies on the next ECS update, so the carry is evaluated one frame ahead to stay in step
    // with the gloves (which the anim graph places this frame).
    private void Tick_Carry(float32 InDeltaSeconds)
    {
        if (_Carry.IsActive == false)
        { return; }

        auto Presentation = _PlayerEntity.As_HeldItem().Get_PresentationEntity();
        if (ck::Is_NOT_Valid(Presentation) || utils_scene_node::Has(Presentation) == false)
        {
            // Not spawned yet; give up once the grab is over.
            _Carry.IsActive = _Reach.Phase == EMars_FPHands_ReachPhase::Grab;
            return;
        }

        auto Ahead = _Reach;
        Ahead.Time += InDeltaSeconds;
        const auto Weight = mars_fphands_reach::Get_CarryWeight(Ahead, Config.FPHands.Reach);
        auto Offset = _Carry.HeldOffset;
        if (Weight > 0.0f)
        {
            // Out of reach, the gloves stop short: the item comes to meet them while they reach out.
            const auto HandWorld = utils_transform::Get_EntityCurrentTransform(_HandNode);
            const auto& ReachSpec = Config.FPHands.Reach;
            const auto ReachOut = mars_fphands_reach::Ease(ReachSpec.GrabOutEasing, Ahead.Time / Math::Max(ReachSpec.GrabOutSeconds, 0.01f));
            const auto PickedWorld = FTransform(_Carry.StartWorld.GetRotation(),
                _Carry.StartWorld.GetLocation() + Get_GloveShortfall(HandWorld) * ReachOut, FVector::OneVector);
            const auto Picked = PickedWorld.GetRelativeTransform(HandWorld);
            Offset.SetLocation(Math::Lerp(_Carry.HeldOffset.GetLocation(), Picked.GetLocation(), float(Weight)));
            Offset.SetRotation(FQuat::Slerp(_Carry.HeldOffset.GetRotation(), Picked.GetRotation(), float(Weight)));
        }
        else
        { _Carry.IsActive = false; }

        auto Node = utils_scene_node::DoCastChecked(Presentation);
        utils_scene_node::Request_UpdateOffset(Node, FCk_Request_SceneNode_UpdateRelativeTransform(Offset));
    }

    // The entity an interactable belongs to (world item, lever root), via the context stamped on its targets.
    private FCk_Handle Get_InteractableOwner(FCk_Handle_Interactable InInteractable)
    {
        for (auto Target : InInteractable.Get_AllInteractTargets())
        {
            if (ck::IsValid(Target) && Target.Has_Fragment(FMars_Fragment_InteractionContext))
            { return Target.Get_Fragment(FMars_Fragment_InteractionContext).InteractableOwner; }
        }
        return FCk_Handle();
    }

    private FMars_FPHands_ReachTarget Resolve_ReachTarget(const FCk_Handle_Interactable& InInteractable, const FCk_Handle& InOwner)
    {
        const auto HandWorld = utils_transform::Get_EntityCurrentTransform(_HandNode);
        auto Target = mars_fphands_grips::Resolve(Config.FPHands, _Hold, InInteractable, InOwner, HandWorld, _Reach.PreferRightHand);
        if (Target.IsValid && Target.UsesRight != Target.UsesLeft)
        { _Reach.PreferRightHand = Target.UsesRight; }
        return Target;
    }

    // Use pressed on a target: reach for it with one glove or both. Instant targets get a grab gesture; timed ones
    // hold until released.
    UFUNCTION()
    private void OnBestTargetsChanged_FPHands(FCk_Handle_InteractionResolver InResolver, FGameplayTag InIntent,
                                              const TArray<FCk_Handle_InteractTarget>&in InPreviousTargets,
                                              const TArray<FCk_Handle_InteractTarget>&in InNewTargets,
                                              const TArray<FCk_Handle_InteractTarget>&in InRemovedTargets)
    {
        if (InIntent != GameplayTags::InteractionIntent_Mars_Use || ck::Is_NOT_Valid(_HandNode))
        { return; }

        for (auto Removed : InRemovedTargets)
        {
            if (Removed == _Reach.InteractTarget)
            { mars_fphands_reach::Release(_Reach, Config.FPHands.Reach); }
        }

        for (auto Target : InNewTargets)
        {
            if (ck::Is_NOT_Valid(Target) || Target.Has_Fragment(FMars_Fragment_InteractionContext) == false)
            { continue; }

            const auto& Context = Target.Get_Fragment(FMars_Fragment_InteractionContext);
            const auto ReachTarget = Resolve_ReachTarget(Context.Interactable, Context.InteractableOwner);
            if (ReachTarget.IsValid == false)
            { return; }

            const auto IsInstant = Target.Get_InteractionCompletionPolicy() == ECk_Interaction_CompletionPolicy::Instant;
            Stop_FPEmote();
            mars_fphands_reach::Start(_Reach, Target, ReachTarget, IsInstant);

            // A pickup: if it lands in the hands, its held visual starts where the item lay (see Tick_Carry).
            if (ck::IsValid(ReachTarget.ShapeMesh))
            {
                auto HeldItem = _PlayerEntity.As_HeldItem();
                HeldItem.Set_NextSpawnFrom(ReachTarget.AnchorWorld);
            }
            return;
        }
    }

    // Empty hands and two-handed holds centre the Hand node between the gloves; one-handed items move it to the right.
    UFUNCTION()
    private void OnHeldItemChanged(FCk_Handle_HeldItem InHeldItem, FCk_Handle_Item InPrev, FCk_Handle_Item InNew)
    {
        const auto PrevRest = mars_fphands::Get_HandRestOffset(Config.FPHands, _Hold, Config.HandOffset);
        _Hold = mars_fphands::Make_Hold(InNew);
        if (_Hold.IsHolding)
        { Stop_FPEmote(); }

        // Picked up with the gloves: the new held visual rides in them instead of appearing at the hold.
        _Carry = FMars_FPHands_Carry();
        if (_Reach.Phase == EMars_FPHands_ReachPhase::Grab && ck::IsValid(_Reach.Target.ShapeMesh)
            && ck::IsValid(InNew) && InNew.Has_Presentation())
        {
            _Carry.IsActive = true;
            _Carry.StartWorld = _Reach.Target.AnchorWorld;
            _Carry.HeldOffset = InNew.Get_Presentation().HeldOffset;
        }
        const auto NewRest = mars_fphands::Get_HandRestOffset(Config.FPHands, _Hold, Config.HandOffset);

        if (NewRest.Equals(PrevRest) || ck::Is_NOT_Valid(_HandSway))
        { return; }

        utils_sway::Request_SetRestOffset(_HandSway, FCk_Request_Sway_SetRestOffset(NewRest));
    }
}
