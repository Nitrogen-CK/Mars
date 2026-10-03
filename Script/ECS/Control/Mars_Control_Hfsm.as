class UMars_SmState_Control_Engage : UCk_SmState_EntityScript
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
        AddTask(InHandle, UMars_SmTask_Control_Engage);

        auto OnSuccess = AddTransition(InHandle, UMars_SmState_ExitAndTerminate);
        AddCondition(OnSuccess, UMars_SmCondition_AllTasksSucceeded);

        auto OnFailure = AddTransition(InHandle, UMars_SmState_ExitAndTerminate);
        AddCondition(OnFailure, UMars_SmCondition_AnyTaskFailed);
    }
}

class UMars_SmTask_Control_Engage : UCk_SmTask_EntityScript
{
    default _TaskMode = ECk_SmTaskMode::EnterExitOnly;

    UFUNCTION(BlueprintOverride)
    void DoEnterTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        // The state only runs as a control target's interaction (Make_InteractTarget), so its owner is the control.
        auto Context = Get_StateMachineContext();
        if (ck::EnsureIfNot(Context.Has_Fragment(FMars_Fragment_InteractionContext),
            f"[Control] Engage ran on [{Context.ToString()}], which carries no InteractionContext"))
        {
            Mark_Result(ECk_SmTaskResult::Failed);
            return;
        }

        auto Control = Context.Get_Fragment(FMars_Fragment_InteractionContext).InteractableOwner.As_Control();
        if (ck::Is_NOT_Valid(Control))
        {
            Mark_Result(ECk_SmTaskResult::Failed);
            return;
        }

        Control.Request_Engage();
        Mark_Result(ECk_SmTaskResult::Succeeded);
    }
}
