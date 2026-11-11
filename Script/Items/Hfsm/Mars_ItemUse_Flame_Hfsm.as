// Flame use states (Mars_ItemUse_Hfsm.as shape): each overrides UMars_SmState_InteractTarget_Enter on the held-item use
// interactable, whose owner is the player.

//--------------------------------------------------------------------------------------------------------------------------
// Toggle flame
//--------------------------------------------------------------------------------------------------------------------------

class UMars_SmState_ItemUse_ToggleFlame : UMars_SmState_InteractTarget_RunTask
{
    default TaskClass = UMars_SmTask_ItemUse_ToggleFlame;
}

// Snuffs a lit held flame and lights an unlit one that can light itself (a lantern's shutter, a torch's strike), through
// utils_flame::Request_ActFor (the authority checks it again). One that cannot - spent, or needing another flame - fails
// and stays as it is.
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

        if (Flame.Get_Ignition() == EMars_Flame_Ignition::Snuffed && Flame.Get_CanSelfLight() == false)
        {
            Mark_Result(ECk_SmTaskResult::Failed);
            return;
        }

        utils_flame::Request_ActFor(Flame, HeldItem.H(), EMars_Flame_Verb::Toggle);
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

// Feeds the held tallow to the emptiest refuelable flame in the user's hotbar through utils_flame::Request_ActFor: the
// authority checks it again, refuels the flame and uses the tallow up. None that can take it (every one full, unlimited
// or not refuelable, or none carried): fails, and the tallow is kept.
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

        utils_flame::Request_ActFor(Flame, HeldItem.H(), EMars_Flame_Verb::Refuel);
        Mark_Result(ECk_SmTaskResult::Succeeded);
    }
}
