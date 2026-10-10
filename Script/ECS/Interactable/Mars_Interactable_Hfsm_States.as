//   Idle <---> Focused          Idle | Focused ---> Interacting ---> Focused
//   Disabled <--- (any)         Disabled ---> Idle
//
// Interacting runs the target's InteractionStateClass as a sub-SM: on a WhileLive target while its interaction is live
// (InteractionLive, until the sub-SM ends it or it ends from outside), on an AfterCompletion target once per Succeeded finish
// (InteractionCompleted). Only a claim that takes the interactable out of focus disables it (Get_IsFocusable).

// Placeholder the target's InteractionStateClass overrides; entering it un-overridden is a bug.
class UMars_SmState_InteractTarget_Enter : UCk_SmState_EntityScript
{
    UFUNCTION(BlueprintOverride)
    void DoEnterState(FCk_Handle_SmState InHandle, ECk_Sm_NetContext InNetContext)
    {
        ck::TriggerEnsure(f"UMars_SmState_InteractTarget_Enter was not overridden by the target's InteractionStateClass");
    }
}

class UMars_SmState_Interactable_Idle : UCk_SmState_EntityScript
{
    UFUNCTION(BlueprintOverride)
    void DoDefineState(FCk_Handle_SmState_UnderConstruction& InHandle)
    {
        auto ToDisabled = AddTransition(InHandle, UMars_SmState_Interactable_Disabled);
        AddCondition(ToDisabled, UMars_SmCondition_InteractableIsNotFocusable);

        auto ToInteractingWhileLive = AddTransition(InHandle, UMars_SmState_Interactable_Interacting);
        AddCondition(ToInteractingWhileLive, UMars_SmCondition_InteractionLive);

        auto ToInteractingAfterCompletion = AddTransition(InHandle, UMars_SmState_Interactable_Interacting);
        AddCondition(ToInteractingAfterCompletion, UMars_SmCondition_InteractionCompleted);

        auto ToFocused = AddTransition(InHandle, UMars_SmState_Interactable_Focused);
        AddCondition(ToFocused, UMars_SmCondition_InteractableIsFocused);
    }
}

class UMars_SmState_Interactable_Focused : UCk_SmState_EntityScript
{
    UFUNCTION(BlueprintOverride)
    void DoDefineState(FCk_Handle_SmState_UnderConstruction& InHandle)
    {
        auto ToDisabled = AddTransition(InHandle, UMars_SmState_Interactable_Disabled);
        AddCondition(ToDisabled, UMars_SmCondition_InteractableIsNotFocusable);

        auto ToInteractingWhileLive = AddTransition(InHandle, UMars_SmState_Interactable_Interacting);
        AddCondition(ToInteractingWhileLive, UMars_SmCondition_InteractionLive);

        auto ToInteractingAfterCompletion = AddTransition(InHandle, UMars_SmState_Interactable_Interacting);
        AddCondition(ToInteractingAfterCompletion, UMars_SmCondition_InteractionCompleted);

        auto ToIdle = AddTransition(InHandle, UMars_SmState_Interactable_Idle);
        AddCondition(ToIdle, UMars_SmCondition_InteractableIsNotFocused);

        AddTask(InHandle, UMars_SmTask_Interactable_ShowPrompt);
        AddTask(InHandle, UMars_SmTask_Interactable_HandsGate);
        AddTask(InHandle, UMars_SmTask_Interactable_Outline);
    }
}

class UMars_SmState_Interactable_Interacting : UCk_SmState_EntityScript
{
    UFUNCTION(BlueprintOverride)
    void DoDefineState(FCk_Handle_SmState_UnderConstruction& InHandle)
    {
        auto ToDisabled = AddTransition(InHandle, UMars_SmState_Interactable_Disabled);
        AddCondition(ToDisabled, UMars_SmCondition_InteractableIsNotFocusable);

        AddTask(InHandle, UMars_SmTask_PerformInteractionSubSm);

        auto ToFocused = AddTransition(InHandle, UMars_SmState_Interactable_Focused);
        AddCondition(ToFocused, UCk_SmCondition_SubSmFinished);

        auto ToFocusedOnEnd = AddTransition(InHandle, UMars_SmState_Interactable_Focused);
        AddCondition(ToFocusedOnEnd, UMars_SmCondition_InteractionEnded);
    }
}

class UMars_SmState_Interactable_Disabled : UCk_SmState_EntityScript
{
    UFUNCTION(BlueprintOverride)
    void DoDefineState(FCk_Handle_SmState_UnderConstruction& InHandle)
    {
        auto ToIdle = AddTransition(InHandle, UMars_SmState_Interactable_Idle);
        AddCondition(ToIdle, UMars_SmCondition_InteractableIsFocusable);
    }
}

//--------------------------------------------------------------------------------------------------------------------------
// The per-interaction sub-SM's terminal states
//--------------------------------------------------------------------------------------------------------------------------

// A work state's outcome: the sub-SM ends the interaction it runs for with it, and terminates only once that end has drained
// (InteractionGone), so Interacting is not entered again for an interaction already ended. An AfterCompletion target's
// interaction ended before the sub-SM ran: both terminate at once.
class UMars_SmState_InteractTarget_Succeeded : UCk_SmState_EntityScript
{
    UFUNCTION(BlueprintOverride)
    void DoDefineState(FCk_Handle_SmState_UnderConstruction& InHandle)
    {
        AddTask(InHandle, UMars_SmTask_EndInteraction_Succeeded);

        auto ToExit = AddTransition(InHandle, UMars_SmState_ExitAndTerminate);
        AddCondition(ToExit, UMars_SmCondition_InteractionGone);
    }
}

class UMars_SmState_InteractTarget_Failed : UCk_SmState_EntityScript
{
    UFUNCTION(BlueprintOverride)
    void DoDefineState(FCk_Handle_SmState_UnderConstruction& InHandle)
    {
        AddTask(InHandle, UMars_SmTask_EndInteraction_Failed);

        auto ToExit = AddTransition(InHandle, UMars_SmState_ExitAndTerminate);
        AddCondition(ToExit, UMars_SmCondition_InteractionGone);
    }
}
