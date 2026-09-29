class AMars_PlayerCharacter : ACk_Character_UE
{
    default bUseControllerRotationYaw = true;
    default bUseControllerRotationPitch = false;
    default bUseControllerRotationRoll = false;

    default CharacterMovement.bOrientRotationToMovement = false;
    default CharacterMovement.NavAgentProps.bCanCrouch = true;
    default CharacterMovement.bCanWalkOffLedgesWhenCrouching = true;

    default Mesh.SetVisibility(false, true);

    UPROPERTY(DefaultComponent)
    UCameraComponent FirstPersonCamera;
    default FirstPersonCamera.bUsePawnControlRotation = true;

    UPROPERTY(ExposeOnSpawn)
    UMars_PlayerCharacter_Config Config = mars::Mars_PlayerCharacter_Config;

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
        utils_player_viewpoint::Add(Player, FirstPersonCamera.GetWorldTransform(), Config.Viewpoint);
        utils_interaction_resolver::Add(Player, Config.InteractionResolver, ECk_Replication::DoesNotReplicate);
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
        auto Hand = utils_scene_node::CreateAndAttachToUnrealComponent(PlayerTransform, FirstPersonCamera, Config.HandOffset);
        utils_handle::Set_DebugName(FCk_Handle(Hand), n"Player.Hand");

        auto HotbarSpec = FMars_Hotbar_Spec();
        HotbarSpec.BagSlotCount = Config.BagSlotCount;
        utils_hotbar::Add(Player, HotbarSpec);
        utils_held_item::Add(Player, FMars_HeldItem_Spec(Hand.As_Transform()));
        utils_held_item_use::Add(Player);

        utils_state_machine::Add(Player, FCk_StateMachine_Spec(UMars_SmState_Alive));
    }
}
