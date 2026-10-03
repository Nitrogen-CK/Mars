// Offers the ladder to climbers: a player entering either zone becomes that zone's candidate on its Climber, leaving
// withdraws it. Entities already inside a zone when this runs are offered too. The entered entity is the player's probe
// node, resolved to the player entity through its owning actor.
class UMars_Processor_Ladder_Setup : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _MarkedDirtyBy = FMars_Tag_Ladder_NeedsSetup;

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_Ladder);
        Query.Require(FMars_Tag_Ladder_NeedsSetup);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle)
    {
        auto Ladder = InHandle.As_Ladder();

        auto FrontZone = Ladder.Get_FrontZone();
        SetupZone(FrontZone);

        auto TopZone = Ladder.Get_TopZone();
        SetupZone(TopZone);

        Ladder.Request_TryRemove(FMars_Tag_Ladder_NeedsSetup);
    }

    // Add composes both zones.
    private void SetupZone(FCk_Handle_Trigger& InZone)
    {
        InZone.BindTo_OnEntityEntered(FMars_Delegate_Trigger_OnEntityEntered(this, n"OnZoneEntityEntered"));
        InZone.BindTo_OnEntityExited(FMars_Delegate_Trigger_OnEntityExited(this, n"OnZoneEntityExited"));

        for (auto Entity : InZone.Get_EntitiesInside())
        { Offer(InZone, Entity); }
    }

    UFUNCTION()
    private void OnZoneEntityEntered(FCk_Handle_Trigger InTrigger, FCk_Handle InEntity)
    {
        Offer(InTrigger, InEntity);
    }

    UFUNCTION()
    private void OnZoneEntityExited(FCk_Handle_Trigger InTrigger, FCk_Handle InEntity)
    {
        Withdraw(InTrigger, InEntity);
    }

    private void Offer(const FCk_Handle_Trigger& InTrigger, FCk_Handle InEntity)
    {
        const auto Link = InTrigger.Get_Fragment(FMars_Fragment_Ladder_TriggerLink);
        auto Climber = Resolve_Climber(InEntity);
        if (ck::Is_NOT_Valid(Link.Ladder) || ck::Is_NOT_Valid(Climber))
        { return; }

        Climber.Request_AddCandidate(FMars_Request_Climber_AddCandidate(Link.Ladder, Link.Zone));
    }

    private void Withdraw(const FCk_Handle_Trigger& InTrigger, FCk_Handle InEntity)
    {
        const auto Link = InTrigger.Get_Fragment(FMars_Fragment_Ladder_TriggerLink);
        auto Climber = Resolve_Climber(InEntity);
        if (ck::Is_NOT_Valid(Link.Ladder) || ck::Is_NOT_Valid(Climber))
        { return; }

        Climber.Request_RemoveCandidate(FMars_Request_Climber_RemoveCandidate(Link.Ladder, Link.Zone));
    }

    // Invalid for anything but a climber: an entity that is not a player, or one being destroyed (it still reports its
    // exit, with a dead handle; its climber goes with it). A ladder being destroyed leaves a dead Link.Ladder the same way.
    private FCk_Handle_Climber Resolve_Climber(FCk_Handle InEntity) const
    {
        if (ck::Is_NOT_Valid(InEntity))
        { return FCk_Handle_Climber(); }

        auto Actor = utils_owning_actor::TryGet_EntityOwningActor_Recursive(InEntity);
        if (ck::Is_NOT_Valid(Actor))
        { return FCk_Handle_Climber(); }

        return Actor.TryGet_ActorEntityHandle().As_Climber(ECk_SanityCheck::UnChecked);
    }
}
