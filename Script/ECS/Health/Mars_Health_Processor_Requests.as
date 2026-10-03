// The Health arbiter. Every request of the drain runs against ONE running value read from the attribute at the start,
// then the attribute is written once; each applied request broadcasts its own signal here (attribute signals coalesce
// same-frame mutations, so they never carry hit feedback).
//
// Depletion is latched the moment the running value reaches 0, BEFORE OnDepleted broadcasts: a handler that queues
// another hit sees a depleted Health, and later hits in the same drain are ignored, so two lethal hits in one frame
// deplete once and LastHit names the one that crossed zero.
//
// The state is re-fetched per request: a handler may compose Health on another entity mid-broadcast, which can move the
// fragment storage under a reference held across the broadcast.
class UMars_Processor_Health_HandleRequests : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _MarkedDirtyBy = FMars_Fragment_Health_Requests;

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_Health);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle,
                       FMars_Fragment_Health_Requests& InRequests,
                       FMars_Fragment_Health& InState)
    {
        auto Self = InHandle.As_Health();

        TArray<FMars_Request_Health_SetInvulnerable> SetInvulnerableRequests = InRequests.SetInvulnerableRequests;
        TArray<FMars_Request_Health_Heal> HealRequests = InRequests.HealRequests;
        TArray<FMars_Request_Health_ApplyDamage> ApplyDamageRequests = InRequests.ApplyDamageRequests;

        // InRequests is invalid past this line; removing before broadcasting lets re-entrant requests survive.
        Self.Request_TryRemove(FMars_Fragment_Health_Requests);

        const auto Attribute = InState.Attribute;
        auto Running = utils_float_attribute::Get_FinalValue(Attribute, ECk_MinMaxCurrent::Current);
        const auto Max = Self.Get_Max();
        auto Changed = false;

        for (const auto& Request : SetInvulnerableRequests)
        { Self.Get_Fragment(FMars_Fragment_Health).IsInvulnerable = Request.Invulnerability == ECk_EnableDisable::Enable; }

        for (const auto& Request : HealRequests)
        {
            if (Request.Amount <= 0.0f)
            { continue; }

            Self.Get_Fragment(FMars_Fragment_Health).IsDepleted = false;

            const auto Applied = Math::Min(Request.Amount, Max - Running);
            Running += Applied;
            Changed = true;

            if (Self.Has_Fragment(FMars_Fragment_Health_Signals))
            { Self.Get_Fragment(FMars_Fragment_Health_Signals).OnHealed.Broadcast(Self, Applied, Running); }
        }

        for (const auto& Request : ApplyDamageRequests)
        {
            auto& State = Self.Get_Fragment(FMars_Fragment_Health);
            if (State.IsInvulnerable || State.IsDepleted || Request.Event.Amount <= 0.0f)
            { continue; }

            const auto Applied = Math::Min(Request.Event.Amount, Running);
            Running -= Applied;
            Changed = true;
            State.LastHit = Request.Event;

            const auto Depleted = Running <= 0.0f;
            if (Depleted)
            { State.IsDepleted = true; }

            if (Self.Has_Fragment(FMars_Fragment_Health_Signals))
            { Self.Get_Fragment(FMars_Fragment_Health_Signals).OnDamaged.Broadcast(Self, Request.Event, Applied, Running); }

            if (Depleted == false)
            { continue; }

            ck::Trace(f"[Health] [{Self.ToString()}] depleted by [{Request.Event.Amount}] [{Request.Event.DamageType.ToString()}]");

            if (Self.Has_Fragment(FMars_Fragment_Health_Signals))
            { Self.Get_Fragment(FMars_Fragment_Health_Signals).OnDepleted.Broadcast(Self, Request.Event); }
        }

        if (Changed)
        { utils_float_attribute::Request_Override_Current(Attribute, Running); }
    }
}
