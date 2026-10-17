// The resolver driver: one per world (the game mode's subsystem spawns it on anchored maps; tests spawn their own). It
// never scans once - a continuous tag query reconciles the full anchor population every pass, so an anchor that
// composes late still resolves, and the per-anchor draw makes the order irrelevant.
UCLASS(NotPlaceable)
class UMars_AnchorResolver_EntityScript : UCk_GenericEntityScript_UE
{
    default _Replication = ECk_Replication::DoesNotReplicate;

    UPROPERTY(ExposeOnSpawn)
    FMars_AnchorResolver_Spec Resolver;

    private FCk_Handle_AnchorResolver _Resolver;
    private FCk_Handle_EntityTagQuery _AnchorQuery;
    private TSet<FCk_Handle> _Requested;

    UFUNCTION(BlueprintOverride)
    ECk_EntityScript_ConstructionFlow DoConstruct(FCk_Handle& InHandle)
    {
        _Resolver = utils_anchor_resolver::Add(InHandle, Resolver);

        _AnchorQuery = utils_entity_tag_query::Add(InHandle);
        utils_entity_tag_query::Request_AddRequirement(_AnchorQuery,
            FCk_Request_EntityTagQuery_AddRequirement(
                utils_entity_tag_query::Make_Requirement_All(n"TAG_MarsAnchor")));
        utils_entity_tag_query::BindTo_OnContinuousUpdate(_AnchorQuery,
            ECk_Signal_BindingPolicy::FireIfPayloadInFlight,
            ECk_Signal_PostFireBehavior::DoNothing,
            FCk_Delegate_EntityTagQuery_OnContinuousUpdate(this, n"OnAnchorsChanged"));

        return ECk_EntityScript_ConstructionFlow::Finished;
    }

    // Reconcile from _Handles (the full population), not the deltas, as the mechanism driver does. Every tagged entity
    // carries the feature (utils_anchor::Add stamps the tag last), so the cast is checked.
    UFUNCTION()
    private void OnAnchorsChanged(FCk_Handle_EntityTagQuery InQuery, bool InIsSatisfied,
                                  const TArray<FCk_EntityTagQuery_Result>&in InResults)
    {
        if (ck::Is_NOT_Valid(_Resolver) || InResults.Num() == 0)
        { return; }

        for (auto Entity : InResults[0]._Handles)
        {
            if (ck::Is_NOT_Valid(Entity) || _Requested.Contains(Entity))
            { continue; }

            _Requested.Add(Entity);
            _Resolver.Request_ResolveAnchor(FMars_Request_AnchorResolver_ResolveAnchor(Entity.As_Anchor()));
        }
    }
}
