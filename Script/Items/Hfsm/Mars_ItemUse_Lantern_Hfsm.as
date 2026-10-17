// Lantern use states (Mars_ItemUse_Hfsm.as shape): each overrides UMars_SmState_InteractTarget_Enter on the held-item use
// interactable, whose owner is the player.

//--------------------------------------------------------------------------------------------------------------------------
// Toggle shutter
//--------------------------------------------------------------------------------------------------------------------------

class UMars_SmState_ItemUse_ToggleShutter : UMars_SmState_InteractTarget_RunTask
{
    default TaskClass = UMars_SmTask_ItemUse_ToggleShutter;
}

// Opens a shuttered held lantern and shutters an open one. A spent lantern's shutter still moves; it shows no flame.
class UMars_SmTask_ItemUse_ToggleShutter : UCk_SmTask_EntityScript
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

        auto Lantern = HeldItem.Get_CurrentItem().TryGet_Lantern();
        if (ck::EnsureIfNot(ck::IsValid(Lantern), f"[ItemUse] ToggleShutter ran while [{HeldItem.ToString()}] holds no lantern"))
        {
            Mark_Result(ECk_SmTaskResult::Failed);
            return;
        }

        const auto Next = Lantern.Get_Shutter() == EMars_Lantern_Shutter::Open
            ? EMars_Lantern_Shutter::Shuttered
            : EMars_Lantern_Shutter::Open;
        Lantern.Request_SetShutter(FMars_Request_Lantern_SetShutter(Next));
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

// Feeds the held tallow to the emptiest lantern in the user's hotbar and uses the tallow up. Every carried lantern full
// (or none carried): fails, and the tallow is kept.
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
        auto Lantern = ck::IsValid(Hotbar) ? utils_lantern::TryGet_RefuelTarget(Hotbar) : FCk_Handle_Lantern();
        if (ck::Is_NOT_Valid(Lantern))
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

        Lantern.Request_Refuel(FMars_Request_Lantern_Refuel(Tallow.Get_TallowMeasures()));

        auto Request = FCk_Request_Inventory_RemoveItem(Tallow);
        Request.Set_PostRemovePolicy(ECk_Inventory_PostRemovePolicy::DestroyItem);
        Inventory.Request_RemoveItem(Request, FCk_Delegate_Inventory_OnOperationResult_Remove());
        Mark_Result(ECk_SmTaskResult::Succeeded);
    }
}
