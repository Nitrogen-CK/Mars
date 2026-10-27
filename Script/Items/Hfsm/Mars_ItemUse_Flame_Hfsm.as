// Flame use states (Mars_ItemUse_Hfsm.as shape): each overrides UMars_SmState_InteractTarget_Enter on the held-item use
// interactable, whose owner is the player.

//--------------------------------------------------------------------------------------------------------------------------
// Toggle flame
//--------------------------------------------------------------------------------------------------------------------------

class UMars_SmState_ItemUse_ToggleFlame : UMars_SmState_InteractTarget_RunTask
{
    default TaskClass = UMars_SmTask_ItemUse_ToggleFlame;
}

// Snuffs a lit held flame and lights an unlit one that can light itself (a lantern's shutter, a torch's strike). One that
// cannot - spent, or needing another flame - fails and stays as it is.
class UMars_SmTask_ItemUse_ToggleFlame : UCk_SmTask_EntityScript
{
    default _TaskMode = ECk_SmTaskMode::EnterExitOnly;

    UFUNCTION(BlueprintOverride)
    void DoEnterTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        auto HeldItem = utils_held_item::Get_UserHeldItem(Get_StateMachineContext());
        if (ck::Is_NOT_Valid(HeldItem))
        {
            Mark_Result(ECk_SmTaskResult::Failed);
            return;
        }

        auto Flame = HeldItem.Get_CurrentItem().TryGet_Flame();
        if (ck::EnsureIfNot(ck::IsValid(Flame), f"[ItemUse] ToggleFlame ran while [{HeldItem.ToString()}] holds no flame"))
        {
            Mark_Result(ECk_SmTaskResult::Failed);
            return;
        }

        if (Flame.Get_Ignition() == EMars_Flame_Ignition::Lit)
        {
            Flame.Request_SetIgnition(FMars_Request_Flame_SetIgnition(EMars_Flame_Ignition::Snuffed));
            Mark_Result(ECk_SmTaskResult::Succeeded);
            return;
        }

        if (Flame.Get_CanSelfLight() == false)
        {
            Mark_Result(ECk_SmTaskResult::Failed);
            return;
        }

        Flame.Request_SetIgnition(FMars_Request_Flame_SetIgnition(EMars_Flame_Ignition::Lit));
        Mark_Result(ECk_SmTaskResult::Succeeded);
    }
}

//--------------------------------------------------------------------------------------------------------------------------
// Refuel
//--------------------------------------------------------------------------------------------------------------------------

class UMars_SmState_ItemUse_Refuel : UMars_SmState_InteractTarget_RunTask
{
    default TaskClass = UMars_SmTask_ItemUse_Refuel;
}

// Feeds the held tallow to the emptiest refuelable flame in the user's hotbar and uses the tallow up. None that can take
// it (every one full, unlimited or not refuelable, or none carried): fails, and the tallow is kept.
class UMars_SmTask_ItemUse_Refuel : UCk_SmTask_EntityScript
{
    default _TaskMode = ECk_SmTaskMode::EnterExitOnly;

    UFUNCTION(BlueprintOverride)
    void DoEnterTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        auto HeldItem = utils_held_item::Get_UserHeldItem(Get_StateMachineContext());
        if (ck::Is_NOT_Valid(HeldItem))
        {
            Mark_Result(ECk_SmTaskResult::Failed);
            return;
        }

        auto Tallow = HeldItem.Get_CurrentItem();
        if (ck::EnsureIfNot(ck::IsValid(Tallow) && Tallow.Has_Tallow(), f"[ItemUse] Refuel ran while [{HeldItem.ToString()}] holds no tallow"))
        {
            Mark_Result(ECk_SmTaskResult::Failed);
            return;
        }

        const auto Hotbar = HeldItem.H().As_Hotbar(ECk_SanityCheck::UnChecked);
        auto Flame = ck::IsValid(Hotbar) ? utils_flame::TryGet_RefuelTarget(Hotbar) : FCk_Handle_Flame();
        if (ck::Is_NOT_Valid(Flame) || Flame.Get_CanRefuel() == false)
        {
            Mark_Result(ECk_SmTaskResult::Failed);
            return;
        }

        auto Inventory = Tallow.Get_ParentInventory();
        if (ck::EnsureIfNot(ck::IsValid(Inventory), f"[ItemUse] Held tallow [{Tallow.ToString()}] is in no inventory"))
        {
            Mark_Result(ECk_SmTaskResult::Failed);
            return;
        }

        Flame.Request_Refuel(FMars_Request_Flame_Refuel(Tallow.Get_Tallow().Measures));

        auto Request = FCk_Request_Inventory_RemoveItem(Tallow);
        Request.Set_PostRemovePolicy(ECk_Inventory_PostRemovePolicy::DestroyItem);
        Inventory.Request_RemoveItem(Request, FCk_Delegate_Inventory_OnOperationResult_Remove());
        Mark_Result(ECk_SmTaskResult::Succeeded);
    }
}
