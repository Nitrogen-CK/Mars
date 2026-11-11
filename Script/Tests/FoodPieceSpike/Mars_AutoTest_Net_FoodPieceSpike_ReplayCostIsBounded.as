// What a client's replay costs, on the meat slab, in three batches the server publishes each in one frame, a second apart:
// - a chop: 8 joints cut once each, both halves kept (16 records, 8 slices on the client);
// - a balanced board: one joint halved through its bounds centre along its longest axis down to depth 5 (32 records);
// - a deep board: one joint cut 31 times, 1.1 cm slices off its -X end (32 records, recipes 1 to 31 cuts long).
// The client imports the definition when a batch arrives and replays with a memo of prefixes, so every cut is sliced once.
// Bounds: the slice drain resolves about one cut a frame, so cuts that do not depend on one another replay within two
// frames a cut, and a lineage cut in sequence within three (each cut waits for the one before it). Measured: 8 frames
// for the chop, 32 for the balanced board, 62 for the deep one. Frames are the rig's own tick;
// per-slice milliseconds are the gaps between two resolutions in one drain (FDateTime::UtcNow, millisecond resolution).
// World X 89000.
// Surface: Ck.FoodPieceSpike.Net.AS_FoodPieceSpike_ReplayCostIsBounded
class UCk_AutoTest_Net_FoodPieceSpike_ReplayCostIsBounded : UMars_AutoTestRig_FoodPieceSpike
{
    private const FVector k_Origin = FVector(89000.0, 0.0, 5000.0);
    private const int32 k_ChopBatch = 1;
    private const int32 k_BalancedBatch = 2;
    private const int32 k_DeepBatch = 3;
    private const int32 k_ChopJoints = 8;
    private const int32 k_BalancedDepth = 5;
    private const int32 k_DeepCuts = 31;
    private const float64 k_DeepStepCm = 1.1;
    // A refused deep cut moves on by this much.
    private const float64 k_DeepNudgeCm = 0.25;
    private const int32 k_FramesPerIndependentCut = 2;
    private const int32 k_FramesPerLineageCut = 3;
    private const float64 k_BatchGapSeconds = 1.0;

    private int32 _Batch = 0;
    private bool _Running = false;
    private bool _PlanDone = false;
    private float64 _NextBatchAt = 0.0;
    private TArray<FMars_TESTONLY_FoodPieceSpike_Record> _Buffered;

    protected void Server_Step() override
    {
        if (_PlanDone)
        { return; }

        if (_Running)
        {
            if (Get_HasNodes(_Batch))
            { return; }

            Flush(_Batch);
            _Running = false;
            _NextBatchAt = Get_ElapsedSeconds() + k_BatchGapSeconds;
            return;
        }

        if (_Batch >= k_DeepBatch)
        {
            _PlanDone = true;
            return;
        }

        if (Get_ElapsedSeconds() < _NextBatchAt)
        { return; }

        _Batch += 1;
        _Running = true;
        const auto Joints = _Batch == k_ChopBatch ? k_ChopJoints : 1;
        for (int32 Chain = 0; Chain < Joints; ++Chain)
        {
            auto Node = FMars_TESTONLY_FoodPieceSpike_Node();
            Node.Batch = _Batch;
            Node.Chain = Chain;
            Node.Rng = Make_Rng(89000 + 100 * _Batch + Chain);
            Add_Joint(mars::Food_MeatSlab_Mars, Node, k_Origin);
        }
    }

    protected bool Get_IsServerPlanDone() const override
    {
        return _PlanDone;
    }

    protected void Publish_Record(const FMars_TESTONLY_FoodPieceSpike_Record& InRecord) override
    {
        _Buffered.Add(InRecord);
    }

    // Every buffered record of InBatch is spawned in this one frame.
    private void Flush(int32 InBatch)
    {
        auto Index = 0;
        while (Index < _Buffered.Num())
        {
            if (_Buffered[Index].Batch != InBatch)
            {
                Index += 1;
                continue;
            }

            Spawn_Record(_Buffered[Index]);
            _Buffered.RemoveAt(Index);
        }

        Publish_Manifest(false);
    }

    protected TOptional<FCk_RuntimeMesh_PlaneLocal> Plan_Cut(FMars_TESTONLY_FoodPieceSpike_Node& InOutNode, const FCk_RuntimeMesh_Metrics& InMetrics) override
    {
        const auto Cuts = InOutNode.Recipe.Cuts.Num();
        const auto Min = InMetrics.Get_BoundsMinCm();
        const auto Max = InMetrics.Get_BoundsMaxCm();
        const auto Centre = (Min + Max) * 0.5;

        if (InOutNode.Batch == k_ChopBatch)
        {
            if (Cuts >= 1 || InOutNode.Attempts >= 4)
            { return TOptional<FCk_RuntimeMesh_PlaneLocal>(); }

            auto Normal = FVector::ZeroVector;
            while (Normal.Size() < 0.3)
            { Normal = FVector(Draw_Signed(InOutNode.Rng), Draw_Signed(InOutNode.Rng), Draw_Signed(InOutNode.Rng)); }

            return TOptional<FCk_RuntimeMesh_PlaneLocal>(Make_Plane(Centre, Normal.GetSafeNormal()));
        }

        if (InOutNode.Batch == k_BalancedBatch)
        {
            if (Cuts >= k_BalancedDepth || InOutNode.Attempts >= k_BalancedDepth + 4)
            { return TOptional<FCk_RuntimeMesh_PlaneLocal>(); }

            const auto Size = Max - Min;
            auto Normal = FVector::ForwardVector;
            if (Size.Y >= Size.X && Size.Y >= Size.Z)
            { Normal = FVector::RightVector; }
            else if (Size.Z >= Size.X && Size.Z >= Size.Y)
            { Normal = FVector::UpVector; }

            return TOptional<FCk_RuntimeMesh_PlaneLocal>(Make_Plane(Centre, Normal));
        }

        // The deep board: a slice (the negative side) ends its lineage; the remainder takes the next slice.
        const auto IsSlice = Cuts > 0 && InOutNode.Recipe.Cuts[Cuts - 1].Kept == EMars_TESTONLY_FoodPieceSpike_Side::Negative;
        if (IsSlice || Cuts >= k_DeepCuts || InOutNode.Attempts >= k_DeepCuts + 10)
        { return TOptional<FCk_RuntimeMesh_PlaneLocal>(); }

        if (Cuts == 0 && InOutNode.Attempts == 0)
        { InOutNode.OriginCm = Min.X; }

        auto Position = Centre;
        Position.X = InOutNode.OriginCm + k_DeepStepCm * float64(Cuts + 1) + k_DeepNudgeCm * float64(InOutNode.Refusals);
        return TOptional<FCk_RuntimeMesh_PlaneLocal>(Make_Plane(Position, FVector::ForwardVector));
    }

    protected EMars_TESTONLY_FoodPieceSpike_Keep Choose_Keep(FMars_TESTONLY_FoodPieceSpike_Node& InOutNode) override
    {
        return EMars_TESTONLY_FoodPieceSpike_Keep::Both;
    }

    protected void Report_Client() override
    {
        const auto Tally = Tally_Replays();
        const auto Chop = Get_Clock(k_ChopBatch);
        const auto Balanced = Get_Clock(k_BalancedBatch);
        const auto Deep = Get_Clock(k_DeepBatch);

        ck::Trace(f"[FoodPieceSpike] cost: {Describe_Tally(Tally)}");
        ck::Trace(f"[FoodPieceSpike] cost chop: {Describe_Clock(Chop)} records={Get_RecordCount(k_ChopBatch)}");
        ck::Trace(f"[FoodPieceSpike] cost balanced: {Describe_Clock(Balanced)} records={Get_RecordCount(k_BalancedBatch)}");
        ck::Trace(f"[FoodPieceSpike] cost deep: {Describe_Clock(Deep)} records={Get_RecordCount(k_DeepBatch)}");
        ck::Trace(f"[FoodPieceSpike] cost sliceMs mean={Get_MeanMs() :.2} p95={Get_P95Ms() :.2} (n={_SliceMs.Num()} same-drain gaps)");

        Assert_Equals_Int(Tally.Steps.Equal, Tally.Steps.Committed, f"every replayed cut matches the server ({Describe_Tally(Tally)})");
        Assert_Equals_Int(Get_RecordCount(k_ChopBatch), 2 * k_ChopJoints, "the chop published both halves of every joint");
        Assert_Equals_Int(Chop.Slices, k_ChopJoints, "the chop costs the client one slice per cut");
        Assert_Equals_Int(Balanced.Slices, 31, "the balanced board costs the client one slice per cut");
        Assert_Equals_Int(Deep.Slices, k_DeepCuts, "the deep board costs the client one slice per cut");
        const auto ChopBound = k_ChopJoints * k_FramesPerIndependentCut;
        const auto BalancedBound = Balanced.Slices * k_FramesPerIndependentCut;
        const auto DeepBound = k_DeepCuts * k_FramesPerLineageCut;
        Assert_True(Get_ReplayFrames(Chop) <= ChopBound, f"the chop's pieces are all replayed within {ChopBound} frames of the import ({Get_ReplayFrames(Chop)})");
        Assert_True(Get_ReplayFrames(Balanced) <= BalancedBound, f"the balanced board is replayed within {BalancedBound} frames of the import ({Get_ReplayFrames(Balanced)})");
        Assert_True(Get_ReplayFrames(Deep) <= DeepBound, f"the deep board is replayed within {DeepBound} frames of the import ({Get_ReplayFrames(Deep)})");
    }

    private int32 Get_RecordCount(int32 InBatch) const
    {
        auto Count = 0;
        for (const auto& Replay : _Replays)
        {
            if (Replay.Record.Batch == InBatch)
            { Count += 1; }
        }

        return Count;
    }

    // Frames from the import being Ready to the last piece replayed; 1000 when either is missing.
    private int32 Get_ReplayFrames(const FMars_TESTONLY_FoodPieceSpike_BatchClock& InClock) const
    {
        if (InClock.RootReady.IsSet() == false || InClock.Done.IsSet() == false)
        { return 1000; }

        return InClock.Done.GetValue() - InClock.RootReady.GetValue();
    }

    private FString Describe_Clock(const FMars_TESTONLY_FoodPieceSpike_BatchClock& InClock) const
    {
        auto Arrival = -1;
        auto RootReady = -1;
        auto Done = -1;
        if (InClock.Arrival.IsSet())
        { Arrival = InClock.Arrival.GetValue(); }

        if (InClock.RootReady.IsSet())
        { RootReady = InClock.RootReady.GetValue(); }

        if (InClock.Done.IsSet())
        { Done = InClock.Done.GetValue(); }

        return f"arrivalFrame={Arrival} importReadyFrame={RootReady} doneFrame={Done} importFrames={RootReady - Arrival} "
            + f"replayFrames={Done - RootReady} slices={InClock.Slices}";
    }
}
