// The cutting station builds its board's pile node on the board's top, and the board poses what the feed hands it there.
// The pile node lies in the station frame at X 0, Y 0, on the counter plus the cutting board mesh's own height (its bounds'
// top: the board's pivot is its underside), within 0.05 cm; fed the meat slab from a docked input platter, the board holds
// the joint at its pose on the pile node: the node's location (within 0.5 cm) yawed by the food's layout (within 0.5
// degree). Isolated origin (183000, -70000, -30000).
class UMars_AutoTest_CuttingStation_APlacedPieceSitsOnThePileNode : UMars_AutoTestRig_CuttingStation
{
    private const FVector k_Origin = FVector(183000.0, -70000.0, -30000.0);
    private const float64 k_NodeToleranceCm = 0.05;
    private const float64 k_PoseToleranceCm = 0.5;
    private const float64 k_YawToleranceDegrees = 0.5;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Spawn_Station(InHandle, k_Origin);
        Spawn_InputPlatter(InHandle, mars_items::Food_MeatSlab());

        Add_Steps_FeedTheJoint();
        Add_Step("the pile node is on the board's top and the joint lies on it", n"Step_AssertOnThePileNode");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_AssertOnThePileNode(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto StationWorld = Get_StationWorld();
        const auto PileLocal = StationWorld.InverseTransformPosition(_Board.Get_PileNodeWorld().GetLocation());

        const UStaticMesh BoardMesh = assets::load::CuttingBoard_Mars_SM();
        Assert_True(ck::IsValid(BoardMesh), "the cutting board mesh loads");
        if (ck::Is_NOT_Valid(BoardMesh))
        { return; }

        const auto BoardTop = constants_station::k_CounterHeight + BoardMesh.GetBoundingBox().Max.Z;
        Assert_True(PileLocal.Equals(FVector(0.0, 0.0, BoardTop), k_NodeToleranceCm),
            f"the pile node sits on the board's top in the station frame ({PileLocal} vs Z {BoardTop})");

        Assert_Equals_Int(_Board.Get_HeldCount(), 1, "the board holds the joint");
        if (_Board.Get_HeldCount() != 1)
        { return; }

        const auto Joint = _Board.Get_Held()[0];
        const auto JointWorld = Get_World(Joint);
        const auto Expected = _Board.Get_PoseOnPile(Joint);
        Assert_True(JointWorld.GetLocation().Equals(Expected.GetLocation(), k_PoseToleranceCm),
            f"the joint lies at its pose on the pile node ({JointWorld.GetLocation()} vs {Expected.GetLocation()})");

        const UMars_Food_Def Def = Joint.Get_Definition().Get();
        Assert_True(ck::IsValid(Def), "the joint has its food's definition");
        if (ck::Is_NOT_Valid(Def))
        { return; }

        const auto Yaw = JointWorld.Rotator().Yaw - StationWorld.Rotator().Yaw;
        const auto YawError = Math::Abs(Math::UnwindDegrees(Yaw - Def.Layout.YawDegrees));
        Assert_True(YawError <= k_YawToleranceDegrees, f"the joint is yawed by its layout ({Yaw} vs {Def.Layout.YawDegrees} deg)");
    }
}
