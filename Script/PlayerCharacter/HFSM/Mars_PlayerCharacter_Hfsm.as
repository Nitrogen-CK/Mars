// The player's state machine. Alive keeps only what outlives both of its modes - the hotbar -> held-item link and the
// gloves' sub-SM (Script/ECS/FPHands/Mars_FPHands_Hfsm.as); every interaction task lives on the mode that uses it:
// Locomotion is free roam, Operating is the station mode. A parent's transitions keep firing while any descendant is
// active, and leaving a parent tears down its subtree - so Alive->Downed interrupts any locomotion or operating state,
// and Locomotion->Operating tears down every free-roam task (focus cleared, intents closed, manipulation ended, hints
// unregistered) before the station's enter.
//
// The SM is owning-client authoritative (Mars_PlayerCharacter::TryStartPlayerSm): the owner's transitions replicate, so
// every copy (the server's, the other clients') enters the owner's states and runs their tasks' enter and exit; only the
// owner ticks tasks and evaluates conditions. A task whose enter or exit touches the owner's local world (camera, UI,
// gloves, stations, the interaction resolver) or drives the movement component's stance gates on
// utils_player_sm::Get_IsOwningCopy.

namespace utils_player_sm
{
    // Standalone (also every DoesNotReplicate test SM), the owning client, or the listen host for its own pawn. Probes the
    // context (the pawn's entity): a sub-SM handle has no owning pawn.
    bool Get_IsOwningCopy(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        if (InNetContext == ECk_Sm_NetContext::Standalone)
        { return true; }

        return utils_net::Get_IsEntityLocallyControlled_ByPlayer(ck::Ctx(InHandle))
            == ECk_Utils_Net_IsLocallyControlled_Result::IsLocallyControlled;
    }
}

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

        AddTask(InHandle, UMars_SmTask_MovementSpeedSync);
        AddTask(InHandle, UMars_SmTask_HotbarDrivesHeldItem);
        AddTask(InHandle, UMars_SmTask_AliveSubSm);
        AddTask(InHandle, UMars_SmTask_HandsSubSm);
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

// The free-roam interaction mode: every task that turns input or the view trace into an interaction, an item use, an emote
// or a ladder mount. Operating replaces it wholesale, so none of them can fire while a station holds the player.
class UMars_SmState_Locomotion : UCk_SmState_EntityScript
{
    UFUNCTION(BlueprintOverride)
    void DoDefineState(FCk_Handle_SmState_UnderConstruction& InHandle)
    {
        auto ToOperating = AddTransition(InHandle, UMars_SmState_Operating);
        AddCondition(ToOperating, UMars_SmCondition_IsOperating);

        AddTask(InHandle, UMars_SmTask_InteractionFocus);
        AddTask(InHandle, UMars_SmTask_InteractionResolverBinds);
        AddTask(InHandle, UMars_SmTask_UseIntentToResolver);
        AddTask(InHandle, UMars_SmTask_PrimaryIntentToResolver);
        AddTask(InHandle, UMars_SmTask_ManipulateControl);
        AddTask(InHandle, UMars_SmTask_HotbarIntents);
        AddTask(InHandle, UMars_SmTask_EmoteIntents);
        AddTask(InHandle, UMars_SmTask_EmoteWheelIntent);
        AddTask(InHandle, UMars_SmTask_HeldItemDrivesUse);
        AddTask(InHandle, UMars_SmTask_DropThrowIntent);
        AddTask(InHandle, UMars_SmTask_HeldItemHints);
        AddTask(InHandle, UMars_SmTask_ClimberMountIntent);
        AddTask(InHandle, UMars_SmTask_LocomotionSubSm);
    }

    // Leaving Locomotion while climbing (Downed, or a station's Operating) leaves the ladder: the Climber's drain runs next
    // frame and restores walking, so a Downed player falls out of Flying and an operator's glide follows.
    UFUNCTION(BlueprintOverride)
    void DoExitState(FCk_Handle_SmState InHandle, ECk_Sm_NetContext InNetContext)
    {
        auto Climber = ck::Ctx(InHandle).As_Climber();
        if (Climber.Get_IsClimbing() == false)
        { return; }

        Climber.Request_Dismount(FMars_Request_Climber_Dismount(EMars_Climber_Dismount::Lost));
    }
}
