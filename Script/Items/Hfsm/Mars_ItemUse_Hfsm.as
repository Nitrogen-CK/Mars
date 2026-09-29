// Held-item use states. Each overrides UMars_SmState_InteractTarget_Enter on the held-item use interactable, so it runs
// once the Primary.UsableItem interaction completes (after the hold, for a Timed UseAction). The interactable owner is
// the player.

//--------------------------------------------------------------------------------------------------------------------------
// Consume
//--------------------------------------------------------------------------------------------------------------------------

class UMars_SmState_ItemUse_Consume : UCk_SmState_EntityScript
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
        AddTask(InHandle, UMars_SmTask_ItemUse_Consume);

        auto OnSuccess = AddTransition(InHandle, UMars_SmState_ExitAndTerminate);
        AddCondition(OnSuccess, UMars_SmCondition_AllTasksSucceeded);

        auto OnFailure = AddTransition(InHandle, UMars_SmState_ExitAndTerminate);
        AddCondition(OnFailure, UMars_SmCondition_AnyTaskFailed);
    }
}

// Destroys the held item when its UseAction says the use consumes it. The slot stays selected with empty hands.
class UMars_SmTask_ItemUse_Consume : UCk_SmTask_EntityScript
{
    default _TaskMode = ECk_SmTaskMode::EnterExitOnly;

    UFUNCTION(BlueprintOverride)
    void DoEnterTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        auto HeldItem = utils_item_use::Get_UserHeldItem(Get_StateMachineContext());
        if (ck::Is_NOT_Valid(HeldItem))
        {
            Mark_Result(ECk_SmTaskResult::Failed);
            return;
        }

        auto Item = HeldItem.Get_CurrentItem();
        if (ck::Is_NOT_Valid(Item) || Item.Has_UseAction() == false)
        {
            Mark_Result(ECk_SmTaskResult::Failed);
            return;
        }

        const UMars_ItemTrait_UseAction UseAction = Item.Get_UseAction();
        if (UseAction.ConsumeOnSuccess)
        {
            auto Inventory = Item.Get_ParentInventory();
            auto Request = FCk_Request_Inventory_RemoveItem(Item);
            Request.Set_PostRemovePolicy(ECk_Inventory_PostRemovePolicy::DestroyItem);
            Inventory.Request_RemoveItem(Request, FCk_Delegate_Inventory_OnOperationResult_Remove());
        }

        Mark_Result(ECk_SmTaskResult::Succeeded);
    }
}

//--------------------------------------------------------------------------------------------------------------------------
// Throw
//--------------------------------------------------------------------------------------------------------------------------

// For items that want the Primary button to throw. The same launch Drop-hold-release reaches.
class UMars_SmState_ItemUse_Throw : UCk_SmState_EntityScript
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
        AddTask(InHandle, UMars_SmTask_ItemUse_Throw);

        auto OnSuccess = AddTransition(InHandle, UMars_SmState_ExitAndTerminate);
        AddCondition(OnSuccess, UMars_SmCondition_AllTasksSucceeded);

        auto OnFailure = AddTransition(InHandle, UMars_SmState_ExitAndTerminate);
        AddCondition(OnFailure, UMars_SmCondition_AnyTaskFailed);
    }
}

class UMars_SmTask_ItemUse_Throw : UCk_SmTask_EntityScript
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

        auto Player = Context.Get_Fragment(FMars_Fragment_InteractionContext).InteractableOwner;
        auto Use = Player.As_HeldItemUse(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(Use))
        {
            Mark_Result(ECk_SmTaskResult::Failed);
            return;
        }

        Use.Request_Throw();
        Mark_Result(ECk_SmTaskResult::Succeeded);
    }
}

//--------------------------------------------------------------------------------------------------------------------------

namespace utils_item_use
{
    // The context is the InteractTarget; its InteractionContext names the player as the interactable owner.
    FCk_Handle_HeldItem Get_UserHeldItem(FCk_Handle InContext)
    {
        if (InContext.Has_Fragment(FMars_Fragment_InteractionContext) == false)
        { return FCk_Handle_HeldItem(); }

        auto Player = InContext.Get_Fragment(FMars_Fragment_InteractionContext).InteractableOwner;
        return Player.As_HeldItem(ECk_SanityCheck::UnChecked);
    }
}
