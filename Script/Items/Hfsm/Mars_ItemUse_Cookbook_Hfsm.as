// The held-item resolver remains the only Primary entry point, so focused world prompts keep their existing priority.
class UMars_SmState_ItemUse_ToggleCookbook : UMars_SmState_InteractTarget_RunTask
{
    default TaskClass = UMars_SmTask_ItemUse_ToggleCookbook;
}

class UMars_SmTask_ItemUse_ToggleCookbook : UCk_SmTask_EntityScript
{
    default _TaskMode = ECk_SmTaskMode::EnterExitOnly;

    UFUNCTION(BlueprintOverride)
    void DoEnterTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        auto Context = Get_StateMachineContext();
        if (Context.Has_Fragment(FMars_Fragment_InteractionContext) == false)
        {
            Mark_Result(ECk_SmTaskResult::Failed);
            return;
        }

        auto Book = utils_cookbook::TryGet_HeldBook(Context.Get_Fragment(FMars_Fragment_InteractionContext).InteractableOwner);
        if (ck::Is_NOT_Valid(Book))
        {
            Mark_Result(ECk_SmTaskResult::Failed);
            return;
        }

        Book.Request_Toggle();
        Mark_Result(ECk_SmTaskResult::Succeeded);
    }
}
