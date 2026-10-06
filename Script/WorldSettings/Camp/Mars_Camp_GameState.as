struct FMars_CampPartyState
{
    UPROPERTY()
    FName ServiceId;

    UPROPERTY()
    bool IsDeparting = false;

    UPROPERTY()
    int32 Revision = 0;
}

enum EMars_PartyDeparture
{
    Staying,
    Departing
}

event void FMars_CampPartyStateChanged();

// CampSession owns server pawn phase. Party state is an atomic replicated view for local UI and late joins.
class AMars_Camp_GameState : AMars_Master_GameState
{
    UPROPERTY(EditDefaultsOnly, Category = "Camp")
    UMars_ServiceCatalog ServiceCatalog = mars::Mars_ServiceCatalog_Default;

    private FCk_Handle_CampSession _CampSession;

    UPROPERTY(ReplicatedUsing = OnRep_PartyState)
    private FMars_CampPartyState _PartyState;

    FMars_CampPartyStateChanged OnPartyStateChanged;

    FMars_CampPartyState Get_PartyState() const
    { return _PartyState; }

    // Only the authoritative GameMode calls this after validating the requesting controller and service id.
    void Apply_PartyState(FName InServiceId, EMars_PartyDeparture InDeparture)
    {
        if (ck::EnsureIfNot(HasAuthority(), "[Mars_Camp_GameState] Apply_PartyState called without authority"))
        { return; }
        const bool IsDeparting = InDeparture == EMars_PartyDeparture::Departing;
        if (_PartyState.ServiceId == InServiceId && _PartyState.IsDeparting == IsDeparting)
        { return; }

        _PartyState.ServiceId = InServiceId;
        _PartyState.IsDeparting = IsDeparting;
        ++_PartyState.Revision;
        ForceNetUpdate();
        OnPartyStateChanged.Broadcast();
    }

    UFUNCTION()
    private void OnRep_PartyState()
    { OnPartyStateChanged.Broadcast(); }

    UFUNCTION(BlueprintOverride)
    void EcsConstructionScript(FCk_Handle InEntity)
    {
        auto Entity = InEntity;
        _CampSession = utils_camp_session::Add(Entity, FMars_CampSession_Spec());
    }

    // Valid once Promise_OnEcsComposed has fired (EcsConstructionScript composes it) - see AMars_Master_GameState.
    UFUNCTION()
    FCk_Handle_CampSession Get_CampSession() const
    { return _CampSession; }
}
