// The zone arbiter. A hit on an enabled zone is scaled by its reaction row, stamped with this zone, broadcast as OnHit,
// then forwarded to the zone's Health. OnHit fires before the Health drain, so a listener (the BodyPart ledger) sees the
// hit even when the Health ignores it (invulnerable or already depleted).
//
// The state is re-fetched per request: an OnHit handler may compose features on another entity mid-broadcast, which can
// move the fragment storage under a reference held across the broadcast.
class UMars_Processor_HitZone_HandleRequests : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _MarkedDirtyBy = FMars_Fragment_HitZone_Requests;

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_HitZone);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle,
                       FMars_Fragment_HitZone_Requests& InRequests,
                       FMars_Fragment_HitZone& InState)
    {
        auto Self = InHandle.As_HitZone();

        TArray<FMars_Request_HitZone_SetEnabled> SetEnabledRequests = InRequests.SetEnabledRequests;
        TArray<FMars_Request_HitZone_ReleaseHurtboxes> ReleaseHurtboxesRequests = InRequests.ReleaseHurtboxesRequests;
        TArray<FMars_Request_HitZone_Hit> HitRequests = InRequests.HitRequests;

        // InRequests is invalid past this line; removing before broadcasting lets re-entrant requests survive.
        Self.Request_TryRemove(FMars_Fragment_HitZone_Requests);

        for (const auto& Request : SetEnabledRequests)
        { Self.Get_Fragment(FMars_Fragment_HitZone).IsEnabled = Request.EnableDisable == ECk_EnableDisable::Enable; }

        if (ReleaseHurtboxesRequests.Num() > 0)
        { HandleReleaseHurtboxes(Self); }

        for (const auto& Request : HitRequests)
        { HandleHit(Self, Request); }
    }

    private void HandleReleaseHurtboxes(FCk_Handle_HitZone& InZone)
    {
        auto& State = InZone.Get_Fragment(FMars_Fragment_HitZone);
        TArray<FCk_Handle> Hurtboxes = State.Hurtboxes;
        State.Hurtboxes.Empty();

        for (auto Hurtbox : Hurtboxes)
        {
            if (ck::IsValid(Hurtbox))
            { utils_entity_lifetime::Request_DestroyEntity(Hurtbox); }
        }

        ck::Trace(f"[HitZone] [{InZone.ToString()}] released [{Hurtboxes.Num()}] hurtboxes");
    }

    private void HandleHit(FCk_Handle_HitZone& InZone, const FMars_Request_HitZone_Hit& InRequest)
    {
        auto& State = InZone.Get_Fragment(FMars_Fragment_HitZone);
        if (State.IsEnabled == false)
        { return; }

        const auto Reaction = InZone.Get_Reaction(InRequest.Event.DamageType);

        auto Scaled = InRequest.Event;
        Scaled.Amount *= Reaction.Multiplier;
        Scaled.HitZone = InZone;

        ++State.HitCount;
        auto Health = State.Health;

        if (InZone.Has_Fragment(FMars_Fragment_HitZone_Signals))
        { InZone.Get_Fragment(FMars_Fragment_HitZone_Signals).OnHit.Broadcast(InZone, Scaled, Reaction); }

        Health.Request_ApplyDamage(FMars_Request_Health_ApplyDamage(Scaled));
    }
}
