UCLASS(NotPlaceable)
class UMars_TestLamp_EntityScript : UCk_EntityScript_WithActor_UE
{
    default _Replication = ECk_Replication::DoesNotReplicate;
}

class AMars_TestLamp : AActor
{
    default bReplicates = false;

    // Authored shape: editor visual + collision. In game it is hidden and an entity-hosted copy renders instead,
    // because CkUsf outlines only reach components hosted by the entity (utils_unreal_component).
    UPROPERTY(DefaultComponent, RootComponent)
    UStaticMeshComponent Mesh;
    default Mesh.SetCollisionProfileName(n"BlockAll");
    default Mesh.bHiddenInGame = true;

    UPROPERTY(DefaultComponent, Attach = Mesh)
    UPointLightComponent Light;
    default Light.RelativeLocation = FVector(0.0, 0.0, 120.0);
    default Light.SetIntensity(8000.0f);
    default Light.LightColor = FLinearColor(1.0, 0.67, 0.35);

    UPROPERTY(Category = "Interaction")
    FText PromptText = NSLOCTEXT("MarsInteraction", "ToggleLampPrompt", "Toggle lamp");

    UPROPERTY(Category = "Interaction")
    bool StartsOn = false;

    UFUNCTION(BlueprintOverride)
    void ConstructionScript()
    {
        if (ck::Is_NOT_Valid(Mesh.StaticMesh))
        { Mesh.SetStaticMesh(engine::load::Cube()); }

        Light.SetVisibility(StartsOn);
    }

    UFUNCTION(BlueprintOverride)
    void BeginPlay()
    {
        auto PendingEntity = utils_entity_script::Request_SpawnEntity(
            ck::TransientEntity(), UMars_TestLamp_EntityScript, UMars_TestLamp_EntityScript::Params(this));

        utils_pending_entity_script::Promise_OnConstructed(
            PendingEntity, FCk_Delegate_EntityScript_Constructed(this, n"OnEntityConstructed"));
    }

    void Toggle()
    {
        Light.SetVisibility(Light.IsVisible() == false);
    }

    UFUNCTION()
    private void OnEntityConstructed(FCk_Handle_EntityScript InEntityScriptHandle)
    {
        FCk_Handle Lamp = InEntityScriptHandle;
        utils_handle::Set_DebugName(Lamp, n"TestLamp");

        auto Probe = FMars_Interactable_ProbeInfo();
        Probe.ProbeSpec = FCk_Probe_Spec(GameplayTags::Probe_Mars_Interact);
        Probe.ProbeShape = utils_shapes::Make_Box(FCk_ShapeBox_Dimensions(GetActorScale3D() * 50.0));

        auto Prompt = FMars_InteractPrompt_Spec();
        Prompt.InputAction = mars::Mars_IA_Interact_Use;
        Prompt.PromptText = PromptText;

        auto TargetSpec = FCk_InteractTarget_Spec(GameplayTags::InteractionChannel_Mars_Use);
        TargetSpec.Set_CompletionPolicy(ECk_Interaction_CompletionPolicy::Instant);

        auto Target = FMars_Interactable_TargetEntry();
        Target.InteractTargetSpec = TargetSpec;
        Target.InteractPromptSpec = Prompt;
        Target.InteractionStateClass = UMars_SmState_TestLamp_Toggle;

        auto Spec = FMars_Interactable_Spec();
        Spec.ProbeInfo = Probe;
        Spec.Targets.Add(Target);

        auto LampTransform = Lamp.As_Transform();

        auto VisualParams = utils_unreal_component::Make_Params(
            UStaticMeshComponent, ECk_UnrealComponent_TickPolicy::DoNotTick, n"TestLampVisual");
        auto Visual = utils_unreal_component::Add(Lamp, VisualParams);
        utils_unreal_component::BindTo_OnAdded(Visual, FCk_Delegate_UnrealComponent_OnAdded(this, n"OnVisualAdded"));

        utils_interactable::Create(LampTransform, Spec);
    }

    UFUNCTION()
    private void OnVisualAdded(FCk_Handle_UnrealComponent InHandle)
    {
        auto Visual = Cast<UStaticMeshComponent>(utils_unreal_component::Get_Component(InHandle));
        if (ck::Is_NOT_Valid(Visual))
        { return; }

        Visual.SetStaticMesh(Mesh.StaticMesh);
        Visual.SetMaterial(0, Mesh.GetMaterial(0));
        Visual.SetCollisionEnabled(ECollisionEnabled::NoCollision);
    }
}

class UMars_SmState_TestLamp_Toggle : UCk_SmState_EntityScript
{
    UFUNCTION(BlueprintOverride)
    TArray<FGameplayTag> DoGet_StatesToOverride() const
    {
        return GameplayTag::MakeGameplayTagArrayFromTag(
            UCk_SmState_EntityScript::Get_StateTagForClass(UMars_SmState_InteractTarget_Enter));
    }

    UFUNCTION(BlueprintOverride)
    void DoDefineState(FCk_Handle_SmState_UnderConstruction& InHandle)
    {
        AddTask(InHandle, UMars_SmTask_TestLamp_Toggle);

        auto OnSuccess = AddTransition(InHandle, UMars_SmState_ExitAndTerminate);
        AddCondition(OnSuccess, UMars_SmCondition_AllTasksSucceeded);

        auto OnFailure = AddTransition(InHandle, UMars_SmState_ExitAndTerminate);
        AddCondition(OnFailure, UMars_SmCondition_AnyTaskFailed);
    }
}

class UMars_SmTask_TestLamp_Toggle : UCk_SmTask_EntityScript
{
    default _TaskMode = ECk_SmTaskMode::EnterExitOnly;

    UFUNCTION(BlueprintOverride)
    void DoEnterTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        const auto& Context = Get_OwningStateMachine().Get_Fragment(FMars_Fragment_InteractionContext);
        auto Lamp = Cast<AMars_TestLamp>(ck::ToActor(Context.InteractableOwner, ECk_SanityCheck::UnChecked));
        if (ck::Is_NOT_Valid(Lamp))
        {
            Mark_Result(ECk_SmTaskResult::Failed);
            return;
        }

        Lamp.Toggle();
        Mark_Result(ECk_SmTaskResult::Succeeded);
    }
}
