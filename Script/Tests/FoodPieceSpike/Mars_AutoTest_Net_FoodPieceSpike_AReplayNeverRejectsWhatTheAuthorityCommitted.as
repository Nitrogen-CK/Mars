// For every placed food, six lineages (one per local axis direction to start from) are cut by the server at the game's
// thickness limit: each plane leaves a sliver exactly the food's MinPortionThicknessCm plus 1e-6 cm thick, the sliver is
// dropped and the rest cut again on the next axis, up to 6 committed cuts. The client replays with the framework's
// minimum limits and rejects none of the cuts the server committed. World X 88000.
// Surface: Ck.FoodPieceSpike.Net.AS_FoodPieceSpike_AReplayNeverRejectsWhatTheAuthorityCommitted
class UCk_AutoTest_Net_FoodPieceSpike_AReplayNeverRejectsWhatTheAuthorityCommitted : UMars_AutoTestRig_FoodPieceSpike
{
    private const FVector k_Origin = FVector(88000.0, 0.0, 5000.0);
    private const int32 k_Axes = 6;
    private const int32 k_Depth = 6;
    private const float64 k_InsideCm = 0.000001;

    protected void Begin_Server() override
    {
        const auto Definitions = Get_PlacedDefinitions();

        for (int32 Food = 0; Food < Definitions.Num(); ++Food)
        {
            for (int32 Axis = 0; Axis < k_Axes; ++Axis)
            {
                auto Node = FMars_TESTONLY_FoodPieceSpike_Node();
                Node.Batch = 0;
                Node.Chain = Food * k_Axes + Axis;
                Add_Joint(Definitions[Food], Node, k_Origin);
            }
        }
    }

    // Axis n (0..5) is +X, -X, +Y, -Y, +Z, -Z. The plane's positive side is the sliver on that face.
    protected TOptional<FCk_RuntimeMesh_PlaneLocal> Plan_Cut(FMars_TESTONLY_FoodPieceSpike_Node& InOutNode, const FCk_RuntimeMesh_Metrics& InMetrics) override
    {
        if (InOutNode.Recipe.Cuts.Num() >= k_Depth || InOutNode.Attempts >= k_Depth)
        { return TOptional<FCk_RuntimeMesh_PlaneLocal>(); }

        UMars_Food_Def Definition = InOutNode.Recipe.Definition.Get();
        const auto Sliver = float64(Definition.Tuners.MinPortionThicknessCm) + k_InsideCm;
        const auto Axis = ((InOutNode.Chain % k_Axes) + InOutNode.Attempts) % k_Axes;
        const auto Dimension = Math::IntegerDivisionTrunc(Axis, 2);
        const auto Sign = Axis % 2 == 0 ? 1.0 : -1.0;

        const auto Min = InMetrics.Get_BoundsMinCm();
        const auto Max = InMetrics.Get_BoundsMaxCm();
        auto Position = (Min + Max) * 0.5;
        auto Normal = FVector::ZeroVector;
        if (Dimension == 0)
        {
            Position.X = Sign > 0.0 ? Max.X - Sliver : Min.X + Sliver;
            Normal.X = Sign;
        }
        else if (Dimension == 1)
        {
            Position.Y = Sign > 0.0 ? Max.Y - Sliver : Min.Y + Sliver;
            Normal.Y = Sign;
        }
        else
        {
            Position.Z = Sign > 0.0 ? Max.Z - Sliver : Min.Z + Sliver;
            Normal.Z = Sign;
        }

        return TOptional<FCk_RuntimeMesh_PlaneLocal>(Make_Plane(Position, Normal));
    }

    protected EMars_TESTONLY_FoodPieceSpike_Keep Choose_Keep(FMars_TESTONLY_FoodPieceSpike_Node& InOutNode) override
    {
        return EMars_TESTONLY_FoodPieceSpike_Keep::Negative;
    }

    protected void Report_Client() override
    {
        const auto Tally = Tally_Replays();
        ck::Trace(f"[FoodPieceSpike] at limits: {Describe_Tally(Tally)} | slices={_ClientSlices}");

        Assert_Equals_Int(Tally.Steps.Records, 9 * k_Axes, "every lineage published one record");
        Assert_True(Tally.Steps.Committed > 0, "the server committed cuts at the limit");
        Assert_Equals_Int(Tally.Steps.Rejected, 0, f"the client's replay rejected no cut the server committed ({Describe_Tally(Tally)})");
        Assert_Equals_Int(Tally.Steps.NotReplayed, 0, "every committed cut was replayed");
    }
}
