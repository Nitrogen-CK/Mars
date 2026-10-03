// The zone arbiter. Drains SetEnabled -> ReleaseHurtboxes -> Hit, each kind in arrival order.
//
// A hit on an enabled zone is scaled by the reaction row for its damage type (DefaultMultiplier, Impact None when no row
// names it), stamped with this zone, counted, broadcast as OnHit, then forwarded to the zone's Health as one
// ApplyDamage request. OnHit fires before the Health drain, so a listener (the BodyPart ledger) sees the hit even when
// the Health ignores it (invulnerable or already depleted).
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

        // Swap-and-pop - InRequests is dead past this line. Removing before broadcasting lets re-entrant requests survive.
        Self.Request_TryRemove(FMars_Fragment_HitZone_Requests);

        for (const auto& Request : SetEnabledRequests)
        { Self.Get_Fragment(FMars_Fragment_HitZone).IsEnabled = Request.Enabled; }

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
        Scaled.HitZone = FCk_Handle(InZone);

        ++State.HitCount;
        auto Health = State.Health;

        if (InZone.Has_Fragment(FMars_Fragment_HitZone_Signals))
        { InZone.Get_Fragment(FMars_Fragment_HitZone_Signals).OnHit.Broadcast(InZone, Scaled, Reaction); }

        if (ck::IsValid(Health))
        { Health.Request_ApplyDamage(FMars_Request_Health_ApplyDamage(Scaled)); }
    }
}
