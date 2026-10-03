//   Idle <---> Focused ---> Interacting ---> Focused
//   Disabled <--- (any)     Disabled ---> Idle

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
        AddCondition(ToDisabled, UMars_SmCondition_InteractableIsDisabled);

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
        AddCondition(ToDisabled, UMars_SmCondition_InteractableIsDisabled);

        auto ToIdle = AddTransition(InHandle, UMars_SmState_Interactable_Idle);
        AddCondition(ToIdle, UMars_SmCondition_InteractableIsNotFocused);

        auto ToInteracting = AddTransition(InHandle, UMars_SmState_Interactable_Interacting);
        AddCondition(ToInteracting, UMars_SmCondition_InteractedWith);

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
        AddCondition(ToDisabled, UMars_SmCondition_InteractableIsDisabled);

        AddTask(InHandle, UMars_SmTask_PerformInteractionSubSm);

        auto ToFocused = AddTransition(InHandle, UMars_SmState_Interactable_Focused);
        AddCondition(ToFocused, UCk_SmCondition_SubSmFinished);
    }
}

class UMars_SmState_Interactable_Disabled : UCk_SmState_EntityScript
{
    UFUNCTION(BlueprintOverride)
    void DoDefineState(FCk_Handle_SmState_UnderConstruction& InHandle)
    {
        auto ToIdle = AddTransition(InHandle, UMars_SmState_Interactable_Idle);
        AddCondition(ToIdle, UMars_SmCondition_InteractableIsEnabled);
    }
}
