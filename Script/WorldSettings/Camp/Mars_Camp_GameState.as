// Owns the camp session. The session lives on this actor's entity so every machine has one place to read the phase.
class AMars_Camp_GameState : AMars_Master_GameState
{
    private FCk_Handle_CampSession _CampSession;

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
