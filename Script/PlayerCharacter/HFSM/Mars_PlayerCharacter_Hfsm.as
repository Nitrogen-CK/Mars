// Root (on the player entity, initial = Alive)
// |- Alive       ->Downed [IsDowned]
// |    tasks: ViewpointSync, InteractionFocus, InteractionResolverBinds, Use/PrimaryIntentToResolver,
// |           the five inventory links (Mars_PlayerCharacter_Hfsm_Inventory.as), AliveSubSm
// |    modes: ViewpointSync is the only Tick task (it samples the controller view every frame); every other task is
// |           EnterExitOnly and signal-driven - the intent tasks through UMars_SmTask_IntentEdges' matcher edges
// |    `- Alive sub-SM (initial = Locomotion)
// |         `- Locomotion   tasks: LocomotionSubSm
// |              `- Loco sub-SM (initial = Idle): Idle / Walk / Sprint / Crouch / Jump / Airborne
// `- Downed      ->Alive [IsNotDowned]
//
// A parent's transitions keep firing while any descendant is active, and leaving a parent tears
// down its subtree - so Alive->Downed interrupts any locomotion state.

class UMars_SmCondition_IsDowned : UMars_SmCondition_ByteAttribute
{
    default AttributeTag = GameplayTags::ByteAttribute_Mars_Player_Downed;
    default Comparison._Operator = ECk_ComparisonOperators::EqualTo;
    default Comparison._RHS = 1;
}

class UMars_SmCondition_IsNotDowned : UMars_SmCondition_IsDowned
{
    default _NegateResult = true;
}

class UMars_SmTask_AliveSubSm : UCk_SmTask_SubStateMachine
{
    default _InitialStateClass = UMars_SmState_Locomotion;
    default _CompletionBehavior = ECk_SmTask_SubSm_CompletionBehavior::KeepRunning;
}

class UMars_SmTask_LocomotionSubSm : UCk_SmTask_SubStateMachine
{
    default _InitialStateClass = UMars_SmState_Loco_Idle;
    default _CompletionBehavior = ECk_SmTask_SubSm_CompletionBehavior::KeepRunning;
}

class UMars_SmState_Alive : UCk_SmState_EntityScript
{
    UFUNCTION(BlueprintOverride)
    void DoDefineState(FCk_Handle_SmState_UnderConstruction& InHandle)
    {
        auto ToDowned = AddTransition(InHandle, UMars_SmState_Downed);
        AddCondition(ToDowned, UMars_SmCondition_IsDowned);

        AddTask(InHandle, UMars_SmTask_ViewpointSync);
        AddTask(InHandle, UMars_SmTask_InteractionFocus);
        AddTask(InHandle, UMars_SmTask_InteractionResolverBinds);
        AddTask(InHandle, UMars_SmTask_UseIntentToResolver);
        AddTask(InHandle, UMars_SmTask_PrimaryIntentToResolver);
        AddTask(InHandle, UMars_SmTask_HotbarIntents);
        AddTask(InHandle, UMars_SmTask_HotbarDrivesHeldItem);
        AddTask(InHandle, UMars_SmTask_HeldItemDrivesUse);
        AddTask(InHandle, UMars_SmTask_DropThrowIntent);
        AddTask(InHandle, UMars_SmTask_HeldItemHints);
        AddTask(InHandle, UMars_SmTask_AliveSubSm);
    }

    UFUNCTION(BlueprintOverride)
    void DoEnterState(FCk_Handle_SmState InHandle, ECk_Sm_NetContext InNetContext)
    {
        ck::Trace("Player SM: Alive", n"PlayerSM", 2.0f, FLinearColor(0.3f, 1.0f, 0.3f, 1.0f));
    }
}

class UMars_SmState_Downed : UCk_SmState_EntityScript
{
    UFUNCTION(BlueprintOverride)
    void DoDefineState(FCk_Handle_SmState_UnderConstruction& InHandle)
    {
        auto ToAlive = AddTransition(InHandle, UMars_SmState_Alive);
        AddCondition(ToAlive, UMars_SmCondition_IsNotDowned);
    }

    UFUNCTION(BlueprintOverride)
    void DoEnterState(FCk_Handle_SmState InHandle, ECk_Sm_NetContext InNetContext)
    {
        ck::Trace("Player SM: Downed", n"PlayerSM", 2.0f, FLinearColor(1.0f, 0.3f, 0.3f, 1.0f));
    }
}

class UMars_SmState_Locomotion : UCk_SmState_EntityScript
{
    UFUNCTION(BlueprintOverride)
    void DoDefineState(FCk_Handle_SmState_UnderConstruction& InHandle)
    {
        AddTask(InHandle, UMars_SmTask_LocomotionSubSm);
    }
}
