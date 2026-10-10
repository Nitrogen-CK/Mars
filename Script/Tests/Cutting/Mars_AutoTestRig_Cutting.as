// The cutting rig: a Cutting station on a transform-only root and its lateral node; nothing draws a cleaver (the chop is the
// kernel's own clock). The handlers record the chops' starts and landings; the steps wait on chops.
UCLASS(Abstract)
class UMars_AutoTestRig_Cutting : UCk_AutoTest_Base
{
    protected FCk_Handle_Cutting _Cutting;
    // The spec the station was built from, nodes included.
    protected FMars_Cutting_Spec _Spec;

    protected int32 _ChopsIssued = 0;
    protected int32 _ChopsStarted = 0;
    protected int32 _ChopsLanded = 0;

    protected void BuildStation(FCk_Handle InHandle, FMars_Cutting_Spec InSpec)
    {
        _Spec = InSpec;

        auto StationEntity = utils_entity_lifetime::Request_CreateEntity(InHandle);
        auto Root = utils_transform::Add(StationEntity, FTransform::Identity, ECk_Replication::DoesNotReplicate);
        auto LateralNode = utils_scene_node::Create(Root, FTransform::Identity);

        _Spec.Nodes = FMars_Cutting_Nodes(LateralNode);
        _Cutting = utils_cutting::Add(StationEntity, _Spec);
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Handlers
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    protected void OnChopStarted(FCk_Handle_Cutting InCutting)
    {
        ++_ChopsStarted;
    }

    UFUNCTION()
    protected void OnChopLanded(FCk_Handle_Cutting InCutting)
    {
        ++_ChopsLanded;
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Steps
    //----------------------------------------------------------------------------------------------------------------------

    // A chop landed and the cleaver is back up.
    UFUNCTION()
    protected void Check_FirstChopDone(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_ChopsLanded > 0 && _Cutting.Get_IsChopping() == false);
    }
}
