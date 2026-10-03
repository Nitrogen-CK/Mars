// The dealer arbiter. Each DealDamage resolves its hit entity to a zone, rejects a disabled zone and (unless friendly fire
// is allowed) a Friendly one, then forwards the hit scaled by DamageScale. The attitude walks both ownership chains for a
// team, so the dealer hitting its own zone is Friendly and a side with no team is Neutral.
//
// The zone, never a context root, is the hit's identity: a creature's limbs are distinct zones under one root.
// Hit feedback (cues, debug draws) belongs at this pass, not on attribute signals (they coalesce same-frame hits).
class UMars_Processor_DamageDealer_HandleRequests : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _MarkedDirtyBy = FMars_Fragment_DamageDealer_Requests;

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_DamageDealer);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle,
                       FMars_Fragment_DamageDealer_Requests& InRequests,
                       FMars_Fragment_DamageDealer& InState)
    {
        auto Self = InHandle.As_DamageDealer();

        TArray<FMars_Request_DamageDealer_DealDamage> DealDamageRequests = InRequests.DealDamageRequests;

        // InRequests is invalid past this line; removing before broadcasting lets re-entrant requests survive.
        Self.Request_TryRemove(FMars_Fragment_DamageDealer_Requests);

        for (const auto& Request : DealDamageRequests)
        { HandleDealDamage(Self, Request); }
    }

    private void HandleDealDamage(FCk_Handle_DamageDealer& InDealer, const FMars_Request_DamageDealer_DealDamage& InRequest)
    {
        auto Zone = utils_hit_zone::TryGet_Zone(InRequest.HitEntity);
        if (ck::Is_NOT_Valid(Zone))
        {
            Reject(InDealer, InRequest.HitEntity, EMars_DamageDealer_RejectReason::NoHitZone);
            return;
        }

        if (Zone.Get_IsEnabled() == false)
        {
            Reject(InDealer, InRequest.HitEntity, EMars_DamageDealer_RejectReason::ZoneDisabled);
            return;
        }

        const auto Spec = InDealer.Get_Spec();
        if (Spec.FriendlyFire == EMars_DamageDealer_FriendlyFire::Reject &&
            utils_relationship::Get_AttitudeTowards(InDealer, Zone) == ECk_RelationshipAttitude::Friendly)
        {
            Reject(InDealer, InRequest.HitEntity, EMars_DamageDealer_RejectReason::Friendly);
            return;
        }

        auto Event = InRequest.Event;
        Event.Amount *= Spec.DamageScale;
        Zone.Request_Hit(FMars_Request_HitZone_Hit(Event));

        auto& State = InDealer.Get_Fragment(FMars_Fragment_DamageDealer);
        ++State.HitsDealt;
        State.LastDealt = Event;

        ck::Trace(f"[DamageDealer] [{InDealer.ToString()}] dealt [{Event.Amount}] [{Event.DamageType.ToString()}] to [{Zone.ToString()}]");

        if (InDealer.Has_Fragment(FMars_Fragment_DamageDealer_Signals))
        { InDealer.Get_Fragment(FMars_Fragment_DamageDealer_Signals).OnDamageDealt.Broadcast(InDealer, Zone, Event); }
    }

    private void Reject(FCk_Handle_DamageDealer& InDealer, FCk_Handle InHitEntity, EMars_DamageDealer_RejectReason InReason)
    {
        auto& State = InDealer.Get_Fragment(FMars_Fragment_DamageDealer);
        ++State.HitsRejected;

        ck::Trace(f"[DamageDealer] [{InDealer.ToString()}] rejected [{InHitEntity.ToString()}] ({InReason :n})");

        if (InDealer.Has_Fragment(FMars_Fragment_DamageDealer_Signals))
        { InDealer.Get_Fragment(FMars_Fragment_DamageDealer_Signals).OnDamageRejected.Broadcast(InDealer, InHitEntity, InReason); }
    }
}
