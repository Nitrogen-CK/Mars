// The part arbiter, on the machine with authority over the part only: a machine without it drops RecordHit and Sever and
// learns the part's state from UMars_Processor_BodyPart_Mirror. RecordHit runs before Sever, so the lethal hit is in the
// condition ledger before the part severs. A changed condition and every sever are published to the ledger on the
// monster's entity (utils_body_part::Publish); the break and the detach are the base's, shared with the mirror.
class UMars_Processor_BodyPart_HandleRequests : UMars_Processor_BodyPart_Base
{
    default _Group = n"FGroup_Gameplay_Script";
    default _RunAfter.Add(n"/Script/Angelscript.Mars_Processor_Health_HandleRequests");
    default _MarkedDirtyBy = FMars_Fragment_BodyPart_Requests;

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_BodyPart);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle,
                       FMars_Fragment_BodyPart_Requests& InRequests,
                       FMars_Fragment_BodyPart& InState)
    {
        auto Self = InHandle.As_BodyPart();

        TArray<FMars_Request_BodyPart_RecordHit> RecordHitRequests = InRequests.RecordHitRequests;
        TArray<FMars_Request_BodyPart_Sever> SeverRequests = InRequests.SeverRequests;

        // InRequests is invalid past this line; removing before broadcasting lets re-entrant requests survive.
        Self.Request_TryRemove(FMars_Fragment_BodyPart_Requests);

        if (utils_net::Get_HasAuthority(InHandle) == false)
        { return; }

        for (const auto& Request : RecordHitRequests)
        { HandleRecordHit(Self, Request); }

        for (const auto& Request : SeverRequests)
        { HandleSever(Self, Request); }
    }

    //----------------------------------------------------------------------------------------------------------------------
    // RecordHit
    //----------------------------------------------------------------------------------------------------------------------

    // The ledger is data, not code paths: a Damages reaction moves Pristine -> Damaged; a Ruins reaction accumulates its
    // scaled amount and ruins the part at RuinThreshold x Health.Max; a None reaction leaves the condition. Then
    // SpillToBody x Amount lands on the monster's body Health as its own hit.
    private void HandleRecordHit(FCk_Handle_BodyPart& InPart, const FMars_Request_BodyPart_RecordHit& InRequest)
    {
        const auto Severance = InPart.Get_Spec().Severance;

        auto& State = InPart.Get_Fragment(FMars_Fragment_BodyPart);
        const auto Old = State.Condition;
        auto New = Old;

        if (InRequest.Reaction.Impact == EMars_HitZone_ConditionImpact::Damages)
        {
            if (New == EMars_BodyPart_Condition::Pristine)
            { New = EMars_BodyPart_Condition::Damaged; }
        }
        else if (InRequest.Reaction.Impact == EMars_HitZone_ConditionImpact::Ruins)
        {
            State.RuinDamageTaken += InRequest.Event.Amount;

            if (State.RuinDamageTaken >= Severance.RuinThreshold * State.Health.Get_Max())
            { New = EMars_BodyPart_Condition::Ruined; }
            else if (New == EMars_BodyPart_Condition::Pristine)
            { New = EMars_BodyPart_Condition::Damaged; }
        }

        State.Condition = New;
        auto Monster = InPart.Get_Monster();

        if (New != Old)
        {
            utils_body_part::Publish(InPart);

            if (InPart.Has_Fragment(FMars_Fragment_BodyPart_Signals))
            { InPart.Get_Fragment(FMars_Fragment_BodyPart_Signals).OnConditionChanged.Broadcast(InPart, Old, New); }
        }

        // A severed limb is world-owned and can outlive its monster.
        if (Severance.SpillToBody <= 0.0f || ck::Is_NOT_Valid(Monster))
        { return; }

        auto Spilled = InRequest.Event;
        Spilled.Amount = InRequest.Event.Amount * Severance.SpillToBody;

        auto BodyHealth = Monster.Get_BodyHealth();
        BodyHealth.Request_ApplyDamage(FMars_Request_Health_ApplyDamage(Spilled));
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Sever
    //----------------------------------------------------------------------------------------------------------------------

    private void HandleSever(FCk_Handle_BodyPart& InPart, const FMars_Request_BodyPart_Sever& InRequest)
    {
        if (InPart.Get_State() != EMars_BodyPart_State::Attached)
        { return; }

        const auto Policy = InPart.Get_Spec().Severance.OnDepleted;
        if (Policy == EMars_BodyPart_DepletionPolicy::None)
        { return; }

        if (Policy == EMars_BodyPart_DepletionPolicy::Break)
        { DoBreak(InPart, InRequest.Cause); }
        else
        { DoDetach(InPart, InRequest.Cause); }

        utils_body_part::Publish(InPart);
    }
}
