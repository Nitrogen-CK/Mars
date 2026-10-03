// Terminal state for sub-SMs: stops the owning SM so a parent waiting on UCk_SmCondition_SubSmFinished
// moves on. Route a work state here on both UMars_SmCondition_AllTasksSucceeded and _AnyTaskFailed.
class UMars_SmState_ExitAndTerminate : UCk_SmState_EntityScript
{
    UFUNCTION(BlueprintOverride)
    void DoDefineState(FCk_Handle_SmState_UnderConstruction& InHandle)
    {
        AddTask(InHandle, UMars_SmTask_TerminateOwningSm);
    }
}

class UMars_SmTask_TerminateOwningSm : UCk_SmTask_EntityScript
{
    default _TaskMode = ECk_SmTaskMode::EnterExitOnly;

    UFUNCTION(BlueprintOverride)
    void DoEnterTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        auto OwningSm = Get_OwningStateMachine();
        if (ck::EnsureIfNot(ck::IsValid(OwningSm), "[ExitAndTerminate] the task has no owning state machine to stop"))
        {
            Mark_Result(ECk_SmTaskResult::Failed);
            return;
        }

        utils_state_machine::Request_Stop(OwningSm);
        Mark_Result(ECk_SmTaskResult::Succeeded);
    }
}

class UMars_SmCondition_AllTasksSucceeded : UCk_SmCondition_TaskResults
{
    default _Check = ECk_SmCondition_TaskResultsCheck::AllSucceeded;
}

class UMars_SmCondition_AnyTaskFailed : UCk_SmCondition_TaskResults
{
    default _Check = ECk_SmCondition_TaskResultsCheck::AnyFailed;
}
