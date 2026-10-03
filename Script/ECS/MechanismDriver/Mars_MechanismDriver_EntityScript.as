UCLASS(NotPlaceable)
class UMars_MechanismDriver_EntityScript : UCk_GenericEntityScript_UE
{
    default _Replication = ECk_Replication::DoesNotReplicate;

    private FCk_Handle_MechanismDriver _Driver;
    private FCk_Handle_EntityTagQuery _SourceQuery;
    private FCk_Handle_EntityTagQuery _SinkQuery;

    UFUNCTION(BlueprintOverride)
    ECk_EntityScript_ConstructionFlow DoConstruct(FCk_Handle& InHandle)
    {
        _Driver = utils_mechanism_driver::Add(InHandle);

        _SourceQuery = utils_entity_tag_query::Add(InHandle);
        utils_entity_tag_query::Request_AddRequirement(_SourceQuery,
            FCk_Request_EntityTagQuery_AddRequirement(
                utils_entity_tag_query::Make_Requirement_All(n"TAG_MarsMechanismSource")));
        utils_entity_tag_query::BindTo_OnContinuousUpdate(_SourceQuery,
            ECk_Signal_BindingPolicy::FireIfPayloadInFlight,
            ECk_Signal_PostFireBehavior::DoNothing,
            FCk_Delegate_EntityTagQuery_OnContinuousUpdate(this, n"OnSourcesChanged"));

        _SinkQuery = utils_entity_tag_query::Add(InHandle);
        utils_entity_tag_query::Request_AddRequirement(_SinkQuery,
            FCk_Request_EntityTagQuery_AddRequirement(
                utils_entity_tag_query::Make_Requirement_All(n"TAG_MarsMechanismSink")));
        utils_entity_tag_query::BindTo_OnContinuousUpdate(_SinkQuery,
            ECk_Signal_BindingPolicy::FireIfPayloadInFlight,
            ECk_Signal_PostFireBehavior::DoNothing,
            FCk_Delegate_EntityTagQuery_OnContinuousUpdate(this, n"OnSinksChanged"));

        return ECk_EntityScript_ConstructionFlow::Finished;
    }

    // Reconcile from _Handles (the full population), not the deltas: the bind-time FireIfPayloadInFlight pass carries
    // pre-existing matches in _Handles but may not surface them in _Added. Every tagged entity carries the feature
    // (its Add adds the tag), so the casts are checked.
    UFUNCTION()
    private void OnSourcesChanged(FCk_Handle_EntityTagQuery InQuery, bool InIsSatisfied,
                                  const TArray<FCk_EntityTagQuery_Result>&in InResults)
    {
        if (ck::Is_NOT_Valid(_Driver) || InResults.Num() == 0)
        { return; }

        TSet<FCk_Handle_MechanismSource> Incoming;
        for (auto Entity : InResults[0]._Handles)
        {
            if (ck::Is_NOT_Valid(Entity))
            { continue; }

            Incoming.Add(Entity.As_MechanismSource());
        }

        TSet<FCk_Handle_MechanismSource> Current = _Driver.Get_Sources();
        for (auto Tracked : Current)
        {
            if (Incoming.Contains(Tracked) == false)
            { _Driver.Request_UntrackSource(FMars_Request_MechanismDriver_UntrackSource(Tracked)); }
        }
        for (auto Found : Incoming)
        {
            if (Current.Contains(Found) == false)
            { _Driver.Request_TrackSource(FMars_Request_MechanismDriver_TrackSource(Found)); }
        }
    }

    UFUNCTION()
    private void OnSinksChanged(FCk_Handle_EntityTagQuery InQuery, bool InIsSatisfied,
                                const TArray<FCk_EntityTagQuery_Result>&in InResults)
    {
        if (ck::Is_NOT_Valid(_Driver) || InResults.Num() == 0)
        { return; }

        TSet<FCk_Handle_MechanismSink> Incoming;
        for (auto Entity : InResults[0]._Handles)
        {
            if (ck::Is_NOT_Valid(Entity))
            { continue; }

            Incoming.Add(Entity.As_MechanismSink());
        }

        TSet<FCk_Handle_MechanismSink> Current = _Driver.Get_Sinks();
        for (auto Tracked : Current)
        {
            if (Incoming.Contains(Tracked) == false)
            { _Driver.Request_UntrackSink(FMars_Request_MechanismDriver_UntrackSink(Tracked)); }
        }
        for (auto Found : Incoming)
        {
            if (Current.Contains(Found) == false)
            { _Driver.Request_TrackSink(FMars_Request_MechanismDriver_TrackSink(Found)); }
        }
    }
}
