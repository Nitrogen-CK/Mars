// A plain workbench station: a TableDepth x TableWidth x TableHeight table centred on the origin (depth along local X,
// width along local Y), the operator standing StandGap uu in front of its -X edge facing +X, and the right glove flat on
// the table top near that edge. Place it with +X pointing away from where the player walks up.
class UMars_WorkbenchStation_EntityScript : UMars_Station_EntityScript
{
    default _ShowInPlaceActors = true;

    private const float64 TableWidth = 120.0;
    private const float64 TableDepth = 60.0;
    private const float64 TableHeight = constants_station::k_CounterHeight;
    private const float64 StandGap = 70.0;
    // From the table's near (-X) edge toward its middle.
    private const float64 GripInset = 15.0;
    // The grip node above the table top.
    private const float64 GripLift = 2.0;

    private FCk_Handle_Transform _TableTopNode;

    protected void Configure_Spec(FMars_Station_Spec& InOutSpec) override
    {
        InOutSpec.StandLocal = FTransform(FRotator::ZeroRotator, FVector(-(TableDepth * 0.5 + StandGap), 0.0, 0.0));

        auto Grips = TArray<FMars_Station_Grip>();
        Grips.Add(FMars_Station_Grip(EMars_Hand::Right, GameplayTags::Station_Node_Surface, NAME_None,
            EMars_HandGripPose::Open, TOptional<float32>(), EMars_FPHands_GripFrame::Aimed, EMars_FPHands_GripRoll::Fixed));
        InOutSpec.Grips = Grips;
    }

    protected TOptional<FMars_Interactable_ProbeInfo> Make_Probe() const override
    {
        auto Probe = FMars_Interactable_ProbeInfo();
        Probe.ProbeSpec = FCk_Probe_Spec(GameplayTags::Probe_Mars_Interact);
        Probe.ProbeShape = utils_shapes::Make_Box(
            FCk_ShapeBox_Dimensions(FVector(TableDepth * 0.5 + 5.0, TableWidth * 0.5 + 5.0, TableHeight * 0.5 + 5.0)));
        Probe.ProbeOffset = FTransform(FRotator::ZeroRotator, FVector(0.0, 0.0, TableHeight * 0.5));
        return TOptional<FMars_Interactable_ProbeInfo>(Probe);
    }

    // Engine cube is 100 uu with its pivot at the centre.
    protected void AddVisuals(FCk_Handle_Transform& InRoot) override
    {
        InRoot.Add_MeshPart(this, FMars_MeshPart(
            FTransform(FRotator::ZeroRotator, FVector(0.0, 0.0, TableHeight * 0.5), FVector(TableDepth, TableWidth, TableHeight) * 0.01),
            engine::load::Cube(), assets::load::ProtoGrid_Platform_Mars_MI(), collision::profile::BlockAll, n"Workbench_Table"));

        _TableTopNode = utils_scene_node::Create(InRoot,
            FTransform(FRotator::ZeroRotator, FVector(-TableDepth * 0.5 + GripInset, 0.0, TableHeight + GripLift))).As_Transform();
    }

    protected void Register_GripNodes(TArray<FMars_Station_GripNode>& OutNodes) override
    {
        OutNodes.Add(FMars_Station_GripNode(GameplayTags::Station_Node_Surface, _TableTopNode));
    }
}
