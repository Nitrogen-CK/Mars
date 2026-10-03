// Pushes a severed limb's debris once Jolt has added each body: an impulse requested before Get_IsBodyAdded is dropped.
// A body that died before it was added is dropped with its impulse; the fragment goes once nothing is pending.
class UMars_Processor_BodyPart_Debris : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_BodyPart);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle, FMars_Fragment_BodyPart_PendingDebris& InPending)
    {
        for (int32 Index = InPending.Bodies.Num() - 1; Index >= 0; --Index)
        {
            auto DebrisBody = InPending.Bodies[Index];
            if (ck::IsValid(DebrisBody) && utils_jolt_body::Get_IsBodyAdded(DebrisBody) == false)
            { continue; }

            if (ck::IsValid(DebrisBody))
            { utils_jolt_body::Request_AddImpulse(DebrisBody, FCk_Request_JoltBody_AddImpulse(InPending.Impulses[Index])); }

            InPending.Bodies.RemoveAt(Index);
            InPending.Impulses.RemoveAt(Index);
        }

        if (InPending.Bodies.Num() == 0)
        { InHandle.Request_TryRemove(FMars_Fragment_BodyPart_PendingDebris); }
    }
}
