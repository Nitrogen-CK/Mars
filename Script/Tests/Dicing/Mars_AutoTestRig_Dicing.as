// The dicing rig: a Dicing station on a transform-only root, its lateral node carrying a cleaver node 25 uu up that a
// Mover drops to the board in 0.05 s. The handlers record the station's signals; the steps aim the hand and wait on chops.
UCLASS(Abstract)
class UMars_AutoTestRig_Dicing : UCk_AutoTest_Base
{
    protected FCk_Handle_Dicing _Dicing;
    // The spec the station was built from, nodes included.
    protected FMars_Dicing_Spec _Spec;

    protected int32 _ChopsIssued = 0;
    // One entry per OnChopResolved: whether the chop was aligned.
    protected TArray<bool> _Resolved;
    protected TArray<EMars_Dicing_State> _States;
    protected TArray<float32> _BandMoves;

    protected void BuildStation(FCk_Handle InHandle, FMars_Dicing_Spec InSpec)
    {
        _Spec = InSpec;

        auto StationEntity = utils_entity_lifetime::Request_CreateEntity(InHandle);
        auto Root = utils_transform::Add(StationEntity, FTransform::Identity, ECk_Replication::DoesNotReplicate);
        auto LateralNode = utils_scene_node::Create(Root, FTransform::Identity);
        auto LateralTransform = LateralNode.As_Transform();
        auto CleaverNode = utils_scene_node::Create(LateralTransform, FTransform(FRotator::ZeroRotator, FVector(0.0, 0.0, 25.0)));

        auto MoverSpec = FMars_Mover_Spec();
        MoverSpec.StartLocation = FVector(0.0, 0.0, 25.0);
        MoverSpec.EndLocation = FVector::ZeroVector;
        MoverSpec.Duration = 0.05f;
        auto Mover = utils_mover::Add(CleaverNode, MoverSpec);

        _Spec.Nodes = FMars_Dicing_Nodes(LateralNode, Mover);
        _Dicing = utils_dicing::Add(StationEntity, _Spec);
    }

    protected void AimAtBand()
    {
        _Dicing.Request_Nudge(FMars_Request_Dicing_Nudge((_Dicing.Get_BandCenter() - _Dicing.Get_HandLateral()) / _Spec.LateralPerDegree));
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Handlers
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    protected void OnChopResolved(FCk_Handle_Dicing InDicing, EMars_Dicing_ChopResult InResult)
    {
        _Resolved.Add(InResult == EMars_Dicing_ChopResult::Aligned);
    }

    UFUNCTION()
    protected void OnStateChanged(FCk_Handle_Dicing InDicing, EMars_Dicing_State InState)
    {
        _States.Add(InState);
    }

    UFUNCTION()
    protected void OnBandMoved(FCk_Handle_Dicing InDicing, float32 InCenter)
    {
        _BandMoves.Add(InCenter);
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Steps
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    protected void Step_AimAtBand(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        AimAtBand();
    }

    UFUNCTION()
    protected void Check_HandOnBand(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Math::Abs(_Dicing.Get_HandLateral() - _Dicing.Get_BandCenter()) < 0.01f);
    }

    // Every issued chop resolved and the cleaver is back up.
    UFUNCTION()
    protected void Check_ChopDone(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Resolved.Num() == _ChopsIssued && _Dicing.Get_IsChopping() == false);
    }

    // A chop resolved and the cleaver is back up.
    UFUNCTION()
    protected void Check_FirstChopDone(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Resolved.Num() > 0 && _Dicing.Get_IsChopping() == false);
    }
}
