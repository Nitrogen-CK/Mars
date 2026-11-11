// What pressing a flame's ignite row does: pass fire between the flame and the initiator's held flame.
class UMars_SmState_Flame_Ignite : UMars_SmState_InteractTarget_RunTask
{
    default TaskClass = UMars_SmTask_Flame_Ignite;
}

// Re-evaluates Get_ActionFor for the initiator: Light lights this flame from the held one, TakeLight lights the held one
// from this one, each asked of the flame through utils_flame::Request_ActFor (the authority checks it again). Any other
// action fails: the prompt processor disables the row for it, but can lag the initiator's hands by a frame.
class UMars_SmTask_Flame_Ignite : UCk_SmTask_EntityScript
{
    default _TaskMode = ECk_SmTaskMode::EnterExitOnly;

    UFUNCTION(BlueprintOverride)
    void DoEnterTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        FCk_Handle SubSm = Get_OwningStateMachine();
        if (ck::EnsureIfNot(ck::IsValid(SubSm) && SubSm.Has_Fragment(FMars_Fragment_InteractionContext),
            "[Flame] the ignite task ran without an interaction context"))
        {
            Mark_Result(ECk_SmTaskResult::Failed);
            return;
        }

        const auto& Context = SubSm.Get_Fragment(FMars_Fragment_InteractionContext);
        FCk_Handle Owner = Context.InteractableOwner;
        FCk_Handle Initiator = Context.Initiator;

        auto Flame = Owner.As_Flame(ECk_SanityCheck::UnChecked);
        if (ck::EnsureIfNot(ck::IsValid(Flame), f"[Flame] Interaction owner [{Owner.ToString()}] is no flame")
            || ck::EnsureIfNot(ck::IsValid(Initiator), f"[Flame] [{Flame.ToString()}] ignite has no initiator"))
        {
            Mark_Result(ECk_SmTaskResult::Failed);
            return;
        }

        const auto Action = Flame.Get_ActionFor(Initiator);
        if (Action == EMars_Flame_Action::Light)
        {
            utils_flame::Request_ActFor(Flame, Initiator, EMars_Flame_Verb::Light);
            Mark_Result(ECk_SmTaskResult::Succeeded);
            return;
        }

        if (Action == EMars_Flame_Action::TakeLight)
        {
            utils_flame::Request_ActFor(Flame, Initiator, EMars_Flame_Verb::TakeLight);
            Mark_Result(ECk_SmTaskResult::Succeeded);
            return;
        }

        Mark_Result(ECk_SmTaskResult::Failed);
    }
}
