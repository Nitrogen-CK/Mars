// The resolver driver: one per world (the game mode's subsystem spawns it on anchored maps; tests spawn their own). It
// never scans once - a continuous tag query reconciles the full anchor population every pass, so an anchor that
// composes late still resolves, and the per-anchor draw makes the order irrelevant.
// A Replicated row spawns under the world's replicated spawn owner, which is published a few frames after begin play.
// The query reports changes only, so anchors seen before then wait here and resolve once the owner is there.
UCLASS(NotPlaceable)
class UMars_AnchorResolver_EntityScript : UCk_GenericEntityScript_UE
{
    // Stance C: spawned only in an anchored world, which is the authority; never on a client.
    default _Replication = ECk_Replication::DoesNotReplicate;

    UPROPERTY(ExposeOnSpawn)
    FMars_AnchorResolver_Spec Resolver;

    private FCk_Handle_AnchorResolver _Resolver;
    private FCk_Handle_EntityTagQuery _AnchorQuery;
    private TSet<FCk_Handle> _Requested;
    // Seen before the replicated spawn owner was published, in the order seen.
    private TArray<FCk_Handle> _Waiting;
    private FCk_Handle_Timer _WaitTimer;

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

        // A client world never resolves a Replicated row, so nothing waits there.
        const auto MustWait = utils_mars_net::Get_IsClientWorld(_Resolver) == false
            && utils_mars_net::Get_HasReplicatedSpawnOwner(_Resolver) == false;

        for (auto Entity : InResults[0]._Handles)
        {
            if (ck::Is_NOT_Valid(Entity) || _Requested.Contains(Entity))
            { continue; }

            _Requested.Add(Entity);
            if (MustWait)
            {
                _Waiting.Add(Entity);
                continue;
            }

            _Resolver.Request_ResolveAnchor(FMars_Request_AnchorResolver_ResolveAnchor(Entity.As_Anchor()));
        }

        if (_Waiting.Num() > 0 && ck::Is_NOT_Valid(_WaitTimer))
        {
            FCk_Handle Self = _Resolver;
            _WaitTimer = utils_timer::Create_Tick(Self, FCk_Delegate_Timer(this, n"OnWaitForSpawnOwner"));
        }
    }

    UFUNCTION()
    private void OnWaitForSpawnOwner(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        if (ck::Is_NOT_Valid(_Resolver) || utils_mars_net::Get_HasReplicatedSpawnOwner(_Resolver) == false)
        { return; }

        for (auto Entity : _Waiting)
        {
            if (ck::IsValid(Entity))
            { _Resolver.Request_ResolveAnchor(FMars_Request_AnchorResolver_ResolveAnchor(Entity.As_Anchor())); }
        }

        _Waiting.Empty();
        utils_timer::UnbindFrom_OnUpdate(_WaitTimer, FCk_Delegate_Timer(this, n"OnWaitForSpawnOwner"));
        utils_entity_lifetime::Request_DestroyEntity(_WaitTimer.H());
        _WaitTimer = FCk_Handle_Timer();
    }
}
