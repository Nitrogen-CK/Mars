// The station rig: stations on transform-only roots (no probe, no grip nodes) and operator child entities. The handlers
// record a station's reserves and releases.
UCLASS(Abstract)
class UMars_AutoTestRig_Station : UCk_AutoTest_Base
{
    protected TArray<FCk_Handle> _Reserved;
    protected TArray<FCk_Handle> _Released;
    protected TArray<EMars_Station_ReleaseReason> _ReleaseReasons;

    // Each station on its own child entity: composing two on one entity would alias them.
    protected FCk_Handle_Station AddStation(FCk_Handle InHandle, FMars_Station_Spec InSpec)
    {
        auto StationEntity = utils_entity_lifetime::Request_CreateEntity(InHandle);
        auto Root = utils_transform::Add(StationEntity, FTransform::Identity, ECk_Replication::DoesNotReplicate);
        return utils_station::Add(Root, InSpec, FMars_Station_Setup());
    }

    protected FCk_Handle_Operator AddOperator(FCk_Handle InHandle)
    {
        auto OperatorEntity = utils_entity_lifetime::Request_CreateEntity(InHandle);
        return utils_operator::Add(OperatorEntity);
    }

    UFUNCTION()
    protected void OnReserved(FCk_Handle_Station InStation, FCk_Handle InOperator)
    {
        _Reserved.Add(InOperator);
    }

    UFUNCTION()
    protected void OnReleased(FCk_Handle_Station InStation, FCk_Handle InOperator, EMars_Station_ReleaseReason InReason)
    {
        _Released.Add(InOperator);
        _ReleaseReasons.Add(InReason);
    }

    UFUNCTION()
    protected void Check_Reserved(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Reserved.Num() > 0);
    }

    UFUNCTION()
    protected void Check_Released(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Released.Num() > 0);
    }
}
