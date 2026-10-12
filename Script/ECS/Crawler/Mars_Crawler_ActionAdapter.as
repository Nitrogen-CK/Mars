// The crawler owns damage, cooldown and cancellation policy. This adapter only plays the jab's compiled clip as one scoped
// action with explicit receipt delivery (the resolver needs every accepted interval), cancels it, and releases it after
// the copied terminal stream has been acknowledged.
namespace utils_crawler
{
    bool Get_IsAttackActionLost(const FCk_Handle_Crawler& InSelf)
    {
        const auto& Attack = InSelf.Get_Fragment(FMars_Fragment_Crawler_Attack);
        FCk_Handle Scope = Attack.ActionScope;
        FCk_Handle Action = Attack.Action;
        return Attack.ActionIdentity.Get_Value() != 0 &&
            (ck::Is_NOT_Valid(Action) || ck::Is_NOT_Valid(Scope) ||
                utils_entity_lifetime::Get_IsPendingDestroy(Action, ECk_EntityLifetime_DestructionPhase::BeginDestroy) ||
                utils_entity_lifetime::Get_IsPendingDestroy(Scope, ECk_EntityLifetime_DestructionPhase::BeginDestroy));
    }

    // The clip action's tuning: the player's, with no entry blend (the windup starts at admission, from the identity
    // offset) and CancelSeconds as the dedicated return a cancel eases back through.
    FCk_ProceduralAction_Tuning Make_AttackTuning(const FMars_Crawler_Combat& InCombat)
    {
        auto Tuning = Make_AttackPlayerSpec(InCombat).Get_Tuning();
        auto Transition = Tuning.Get_Transition();
        const auto CancelReturn = FCk_Time(float64(InCombat.Timing.CancelSeconds));
        Transition.Set_EntryBlend(FCk_Time(0.0));
        Transition.Set_DedicatedReturn(CancelReturn);
        if (Transition.Get_ReturnTimeout().Get_Seconds() < CancelReturn.Get_Seconds())
        { Transition.Set_ReturnTimeout(CancelReturn); }
        Tuning.Set_Transition(Transition);
        return Tuning;
    }

    bool Create_AttackAction(FCk_Handle_Crawler& InSelf)
    {
        const auto Player = InSelf.Get_ActionPlayer();
        const auto Combat = InSelf.Get_Spec().Combat;
        auto Clip = Combat.AttackClip.Get();
        if (ck::Is_NOT_Valid(Player) || ck::Is_NOT_Valid(Clip))
        { return false; }

        FCk_Handle Owner = InSelf;
        auto Scope = utils_entity_lifetime::Request_CreateEntity(Owner);
        auto PlaySpec = FCk_ProceduralAction_LoadedPlaySpec(Clip);
        PlaySpec.Set_Tuning(Make_AttackTuning(Combat));
        const auto Action = utils_procedural_action::Create_FromLoadedClip(Scope, Player, PlaySpec);
        if (ck::Is_NOT_Valid(Action))
        {
            utils_entity_lifetime::Request_DestroyEntity(Scope);
            return false;
        }

        auto& Attack = InSelf.Get_Fragment(FMars_Fragment_Crawler_Attack);
        Attack.ActionScope = Scope;
        Attack.Action = Action;
        Attack.ActionIdentity = Action.Get_Identity();
        Attack.ReceiptCursor = 0;
        Attack.CancelRequested = false;
        Attack.TerminalSeen = false;
        Attack.TerminalConsumeIssued = false;
        Attack.TerminalConsumeSucceeded = false;
        return true;
    }

    // Once per attack; the action's own return owns neutralization from wherever the body is.
    void Cancel_AttackAction(FCk_Handle_Crawler& InSelf)
    {
        auto& Attack = InSelf.Get_Fragment(FMars_Fragment_Crawler_Attack);
        if (Attack.CancelRequested || Get_IsAttackActionLost(InSelf) || ck::Is_NOT_Valid(Attack.Action) ||
            Attack.Action.Get_State() == ECk_ProceduralAction_State::Finished)
        { return; }

        Attack.CancelRequested = true;
        Attack.Action.Request_Cancel(FCk_Request_ProceduralAction_Cancel());
    }

    bool Release_TerminalAttackAction(FCk_Handle_Crawler& InSelf)
    {
        auto& Attack = InSelf.Get_Fragment(FMars_Fragment_Crawler_Attack);
        if (Attack.TerminalSeen == false || Attack.TerminalConsumeSucceeded == false ||
            (ck::IsValid(Attack.Action) && Attack.Action.Get_State() != ECk_ProceduralAction_State::Finished))
        { return false; }

        if (ck::IsValid(Attack.Action) && Get_IsAttackActionLost(InSelf) == false)
        { Attack.Action.Request_Release(FCk_Request_ProceduralAction_Release()); }
        if (ck::IsValid(Attack.ActionScope) &&
            utils_entity_lifetime::Get_IsPendingDestroy(Attack.ActionScope,
                ECk_EntityLifetime_DestructionPhase::BeginDestroy) == false)
        { utils_entity_lifetime::Request_DestroyEntity(Attack.ActionScope); }
        Attack.Action = FCk_Handle_ProceduralAction();
        Attack.ActionScope = FCk_Handle();
        Attack.ActionIdentity = FCk_ProceduralAction_Identity();
        return true;
    }
}
