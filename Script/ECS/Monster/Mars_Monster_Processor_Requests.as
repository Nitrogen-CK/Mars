// The monster arbiter. Die is latched: only the first one records the cause and raises the Dead attribute. Teardown
// (shedding legs, the corpse timer) belongs to the Dead HFSM state, not to this drain.
class UMars_Processor_Monster_HandleRequests : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _MarkedDirtyBy = FMars_Fragment_Monster_Requests;

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_Monster);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle,
                       FMars_Fragment_Monster_Requests& InRequests,
                       FMars_Fragment_Monster& InState)
    {
        auto Self = InHandle.As_Monster();

        TArray<FMars_Request_Monster_RegisterPart> RegisterPartRequests = InRequests.RegisterPartRequests;
        TArray<FMars_Request_Monster_Die> DieRequests = InRequests.DieRequests;

        // InRequests is invalid past this line; removing before broadcasting lets re-entrant requests survive.
        Self.Request_TryRemove(FMars_Fragment_Monster_Requests);

        for (const auto& Request : RegisterPartRequests)
        { HandleRegisterPart(Self, Request); }

        for (const auto& Request : DieRequests)
        { HandleDie(Self, Request); }
    }

    private void HandleRegisterPart(FCk_Handle_Monster& InMonster, const FMars_Request_Monster_RegisterPart& InRequest)
    {
        auto Part = InRequest.Part;
        if (ck::EnsureIfNot(ck::IsValid(Part), f"[Monster] [{InMonster.ToString()}] was asked to register an invalid part"))
        { return; }

        auto& State = InMonster.Get_Fragment(FMars_Fragment_Monster);
        for (auto Registered : State.Parts)
        {
            if (Registered == Part)
            { return; }
        }

        State.Parts.Add(Part);
    }

    private void HandleDie(FCk_Handle_Monster& InMonster, const FMars_Request_Monster_Die& InRequest)
    {
        auto& State = InMonster.Get_Fragment(FMars_Fragment_Monster);
        if (State.DeathCause.IsSet())
        { return; }

        State.DeathCause = InRequest.Cause;
        utils_byte_attribute::Request_Override(State.Dead, 1, ECk_MinMaxCurrent::Current);

        if (InMonster.Has_Fragment(FMars_Fragment_Monster_Signals))
        { InMonster.Get_Fragment(FMars_Fragment_Monster_Signals).OnDied.Broadcast(InMonster, InRequest.Cause); }
    }
}
