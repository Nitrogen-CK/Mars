// The crawler owns the phase clock and damage policy. This adapter only translates its body offsets to one scoped
// public manual action and releases that action after the copied terminal stream has been acknowledged.
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

    bool Create_AttackAction(FCk_Handle_Crawler& InSelf)
    {
        const auto Player = InSelf.Get_ActionPlayer();
        if (ck::Is_NOT_Valid(Player))
        { return false; }

        FCk_Handle Owner = InSelf;
        auto Scope = utils_entity_lifetime::Request_CreateEntity(Owner);
        auto Control = FCk_ProceduralAction_ControlSpec(TArray<FName>());
        Control.Set_BodyChannel(ECk_EnableDisable::Enable);
        Control.Set_InputTimeout(FCk_Time(InSelf.Get_Spec().Combat.Timing.PoseTimeoutSeconds + 1.0f));
        const auto Action = utils_procedural_action::Create_Manual(Scope, Player, Control);
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
        Attack.EndRequested = false;
        Attack.TerminalSeen = false;
        Attack.TerminalConsumeIssued = false;
        Attack.TerminalConsumeSucceeded = false;
        return true;
    }

    int64 Submit_AttackOffset(FCk_Handle_Crawler& InSelf, const FTransform& InOffset)
    {
        auto& Attack = InSelf.Get_Fragment(FMars_Fragment_Crawler_Attack);
        if (Get_IsAttackActionLost(InSelf) || ck::Is_NOT_Valid(Attack.Action) ||
            Attack.Action.Get_State() != ECk_ProceduralAction_State::Ready ||
            Attack.EndRequested)
        { return 0; }

        auto Batch = FCk_ProceduralAction_PoseBatch();
        Batch.Set_BodyChannel(ECk_EnableDisable::Enable);
        Batch.Set_BodyOffset(InOffset);
        const auto SampleId = Attack.NextSampleId + 1;
        auto Request = FCk_Request_ProceduralAction_SubmitPoseBatch(Batch);
        Request.Set_CorrelationToken(SampleId);
        const auto Enqueued = utils_procedural_action::Request_SubmitPoseBatch(Attack.Action, Request);
        if (ck::Is_NOT_Valid(Enqueued))
        { return 0; }

        Attack.NextSampleId = SampleId;
        Attack.RequestedActionOffset = InOffset;
        return SampleId;
    }

    void End_AttackAction(FCk_Handle_Crawler& InSelf)
    {
        auto& Attack = InSelf.Get_Fragment(FMars_Fragment_Crawler_Attack);
        if (Attack.EndRequested || Get_IsAttackActionLost(InSelf) || ck::Is_NOT_Valid(Attack.Action))
        { return; }

        Attack.EndRequested = true;
        Attack.Action.Request_End(FCk_Request_ProceduralAction_End());
    }

    void Cancel_AttackAction(FCk_Handle_Crawler& InSelf)
    {
        auto& Attack = InSelf.Get_Fragment(FMars_Fragment_Crawler_Attack);
        if (Attack.EndRequested || Get_IsAttackActionLost(InSelf) || ck::Is_NOT_Valid(Attack.Action))
        { return; }

        Attack.EndRequested = true;
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
