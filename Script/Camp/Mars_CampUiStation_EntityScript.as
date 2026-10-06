struct FMars_Fragment_CampUiStation
{
    EMars_CampStation Station = EMars_CampStation::Contracts;
}

class UMars_CampUiStation_EntityScript : UCk_GenericEntityScript_UE
{
    default _Replication = ECk_Replication::DoesNotReplicate;

    UPROPERTY(ExposeOnSpawn)
    FTransform SpawnTransform = FTransform::Identity;

    UPROPERTY(ExposeOnSpawn)
    EMars_CampStation Station = EMars_CampStation::Contracts;

    UPROPERTY(ExposeOnSpawn)
    FVector ProbeDimensions = FVector(15.0, 65.0, 70.0);

    UFUNCTION(BlueprintOverride)
    ECk_EntityScript_ConstructionFlow DoConstruct(FCk_Handle& InHandle)
    {
        if (ck::EnsureIfNot(Station == EMars_CampStation::Contracts || Station == EMars_CampStation::Departure,
            "[CampUiStation] only Contracts and Departure are supported"))
        { return ECk_EntityScript_ConstructionFlow::Finished; }
        if (ck::EnsureIfNot(ProbeDimensions.X > 0.0 && ProbeDimensions.Y > 0.0 && ProbeDimensions.Z > 0.0,
            "[CampUiStation] probe dimensions must be positive"))
        { return ECk_EntityScript_ConstructionFlow::Finished; }

        auto Root = utils_transform::Add(InHandle, SpawnTransform, ECk_Replication::DoesNotReplicate);
        if (ck::EnsureIfNot(ck::IsValid(Root), "[CampUiStation] could not compose its transform"))
        { return ECk_EntityScript_ConstructionFlow::Finished; }

        auto Metadata = FMars_Fragment_CampUiStation();
        Metadata.Station = Station;
        InHandle.Add_Fragment(Metadata);

        auto Probe = FMars_Interactable_ProbeInfo();
        Probe.ProbeSpec = FCk_Probe_Spec(GameplayTags::Probe_Mars_Interact);
        Probe.ProbeShape = utils_shapes::Make_Box(FCk_ShapeBox_Dimensions(ProbeDimensions));
        Probe.ProbeOffset = FTransform::Identity;

        auto Prompt = FMars_InteractPrompt_Spec();
        Prompt.InputAction = mars::Mars_IA_Interact_Use;
        Prompt.PromptText = Station == EMars_CampStation::Contracts
            ? NSLOCTEXT("MarsCamp", "OpenContracts", "Open contracts")
            : NSLOCTEXT("MarsCamp", "OpenDeparture", "Open departure");

        auto TargetSpec = FCk_InteractTarget_Spec(GameplayTags::InteractionChannel_Mars_Use);
        TargetSpec.Set_CompletionPolicy(ECk_Interaction_CompletionPolicy::Instant);

        auto Target = FMars_Interactable_TargetEntry();
        Target.InteractTargetSpec = TargetSpec;
        Target.InteractPromptSpec = Prompt;
        Target.InteractionStateClass = UMars_SmState_CampUiStation_Open;

        auto Spec = FMars_Interactable_Spec();
        Spec.ProbeInfo = Probe;
        Spec.Targets.Add(Target);
        utils_interactable::Create(Root, Spec);
        return ECk_EntityScript_ConstructionFlow::Finished;
    }
}

class UMars_SmState_CampUiStation_Open : UCk_SmState_EntityScript
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
        AddTask(InHandle, UMars_SmTask_CampUiStation_Open);

        auto OnSuccess = AddTransition(InHandle, UMars_SmState_ExitAndTerminate);
        AddCondition(OnSuccess, UMars_SmCondition_AllTasksSucceeded);

        auto OnFailure = AddTransition(InHandle, UMars_SmState_ExitAndTerminate);
        AddCondition(OnFailure, UMars_SmCondition_AnyTaskFailed);
    }
}

class UMars_SmTask_CampUiStation_Open : UCk_SmTask_EntityScript
{
    default _TaskMode = ECk_SmTaskMode::EnterExitOnly;

    UFUNCTION(BlueprintOverride)
    void DoEnterTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        auto SubSm = Get_OwningStateMachine();
        if (ck::EnsureIfNot(ck::IsValid(SubSm) && SubSm.Has_Fragment(FMars_Fragment_InteractionContext),
            "[CampUiStation] interaction sub-state has no context"))
        {
            Mark_Result(ECk_SmTaskResult::Failed);
            return;
        }

        const auto& Context = SubSm.Get_Fragment(FMars_Fragment_InteractionContext);
        const auto HasOwner = ck::IsValid(Context.InteractableOwner)
            && Context.InteractableOwner.Has_Fragment(FMars_Fragment_CampUiStation);
        if (ck::EnsureIfNot(HasOwner, "[CampUiStation] interaction owner has no station metadata"))
        {
            Mark_Result(ECk_SmTaskResult::Failed);
            return;
        }

        auto Pawn = Cast<APawn>(ck::ToActor(Context.Initiator, ECk_SanityCheck::UnChecked));
        auto PC = ck::IsValid(Pawn) ? Cast<AMars_Camp_PlayerController>(Pawn.GetController()) : nullptr;
        if (ck::EnsureIfNot(ck::IsValid(PC) && PC.IsLocalController(),
            "[CampUiStation] interaction initiator is not a local camp player"))
        {
            Mark_Result(ECk_SmTaskResult::Failed);
            return;
        }

        PC.OpenCampStation(Context.InteractableOwner.Get_Fragment(FMars_Fragment_CampUiStation).Station);
        Mark_Result(ECk_SmTaskResult::Succeeded);
    }
}
