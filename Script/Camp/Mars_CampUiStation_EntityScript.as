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

        utils_camp_ui_station::Create(Root, Station, ProbeDimensions);
        return ECk_EntityScript_ConstructionFlow::Finished;
    }
}

namespace utils_camp_ui_station
{
    // Compose on the visible object so its existing focus task outlines that object's render tree.
    FCk_Handle_Interactable Create(FCk_Handle_Transform& InOwner, EMars_CampStation InStation,
        FVector InHalfExtents, FTransform InOffset = FTransform::Identity)
    {
        auto Metadata = FMars_Fragment_CampUiStation();
        Metadata.Station = InStation;
        InOwner.Add_Fragment(Metadata);

        auto Probe = FMars_Interactable_ProbeInfo();
        Probe.ProbeSpec = FCk_Probe_Spec(GameplayTags::Probe_Mars_Interact);
        Probe.ProbeShape = utils_shapes::Make_Box(FCk_ShapeBox_Dimensions(InHalfExtents));
        Probe.ProbeOffset = InOffset;

        auto Prompt = FMars_InteractPrompt_Spec();
        Prompt.InputAction = mars::Mars_IA_Interact_Use;
        Prompt.PromptText = InStation == EMars_CampStation::Contracts
            ? NSLOCTEXT("MarsCamp", "OpenSteward", "Speak to the Steward")
            : NSLOCTEXT("MarsCamp", "OpenDeparture", "Open departure");

        // WhileLive: the open state reads who interacts from the live interaction, and ends it once the UI opened.
        auto TargetSpec = FCk_InteractTarget_Spec(GameplayTags::InteractionChannel_Mars_Use);

        auto Target = FMars_Interactable_TargetEntry();
        Target.InteractTargetSpec = TargetSpec;
        Target.InteractPromptSpec = Prompt;
        Target.InteractionStateClass = UMars_SmState_CampUiStation_Open;
        Target.Work = EMars_Interactable_Work::WhileLive;
        // Opening a screen is no hands gesture: no lean at the Steward or the board, no grab as it opens.
        Target.ReachKind = EMars_FPHands_ReachKind::None;

        auto Spec = FMars_Interactable_Spec();
        Spec.ProbeInfo = Probe;
        Spec.Targets.Add(Target);
        return utils_interactable::Create(InOwner, Spec);
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

        auto OnSuccess = AddTransition(InHandle, UMars_SmState_InteractTarget_Succeeded);
        AddCondition(OnSuccess, UMars_SmCondition_AllTasksSucceeded);

        auto OnFailure = AddTransition(InHandle, UMars_SmState_InteractTarget_Failed);
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
