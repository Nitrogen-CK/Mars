// The server sends 31 seeded planes (279 doubles of full-width mantissas) to the client twice: as the spawn data of a
// replicated record script, and as a replicated fragment on the subject; each carrier also holds the same doubles as raw
// 64-bit patterns. The client regenerates the planes from the seed and the CRC over the received doubles' bits equals its
// own in both carriers. World X 78000 (nothing is placed).
// Surface: Ck.FoodPieceSpike.Net.AS_FoodPieceSpike_PlanesSurviveTheWireBitForBit
class UCk_AutoTest_Net_FoodPieceSpike_PlanesSurviveTheWireBitForBit : UMars_AutoTestRig_FoodPieceSpike
{
    private const int32 k_Seed = 78031;
    private const int32 k_PlaneCount = 31;
    // An irrational-looking span, so positions use every mantissa bit.
    private const float64 k_SpanCm = 37.0 / 3.0;

    protected void Begin_Server() override
    {
        const auto Planes = Make_Planes();

        auto Record = FMars_TESTONLY_FoodPieceSpike_Record();
        Record.Recipe.Definition = TSoftObjectPtr<UMars_Food_Def>(mars::Food_MeatSlab_Mars);
        Record.Recipe.DefinitionName = mars::Food_MeatSlab_Mars.GetName();
        for (int32 Index = 0; Index < Planes.Num(); ++Index)
        {
            auto Cut = FMars_TESTONLY_FoodPieceSpike_Cut();
            Cut.Plane = Planes[Index];
            Cut.Kept = Index % 2 == 0 ? EMars_TESTONLY_FoodPieceSpike_Side::Positive : EMars_TESTONLY_FoodPieceSpike_Side::Negative;
            Record.Recipe.Cuts.Add(Cut);
            Append_PlaneBits(Record.PackedBits, Planes[Index]);
        }

        Spawn_Record(Record);

        auto Fragment = FMars_TESTONLY_FoodPieceSpike_Fragment_Planes();
        Fragment.Planes = Planes;
        Fragment.PackedBits = Record.PackedBits;
        auto Subject = Get_SubjectEntity();
        Subject.Add_Fragment(Fragment, ECk_Replication::Replicates);
    }

    protected bool Get_ShouldReplay() const override
    {
        return false;
    }

    protected bool Get_IsClientExtraReady() override
    {
        auto Subject = Get_SubjectEntity();
        return ck::IsValid(Subject) && Subject.Has_Fragment(FMars_TESTONLY_FoodPieceSpike_Fragment_Planes);
    }

    protected void Report_Client() override
    {
        const auto Expected = Make_Planes();
        TArray<int64> ExpectedBits;
        for (const auto& Plane : Expected)
        { Append_PlaneBits(ExpectedBits, Plane); }

        const auto ExpectedCrc = Get_PlanesCrc(Expected);
        const auto ExpectedBitsCrc = Get_WordsCrc(ExpectedBits);

        Assert_Equals_Int(_Replays.Num(), 1, "the record script arrived");
        if (_Replays.Num() != 1)
        { return; }

        const auto& Record = _Replays[0].Record;
        TArray<FCk_RuntimeMesh_PlaneLocal> SpawnPlanes;
        for (const auto& Cut : Record.Recipe.Cuts)
        { SpawnPlanes.Add(Cut.Plane); }

        auto Subject = Get_SubjectEntity();
        const auto Fragment = Subject.Get_Fragment(FMars_TESTONLY_FoodPieceSpike_Fragment_Planes);

        const auto SpawnCrc = Get_PlanesCrc(SpawnPlanes);
        const auto FragmentCrc = Get_PlanesCrc(Fragment.Planes);
        const auto SpawnBitsCrc = Get_WordsCrc(Record.PackedBits);
        const auto FragmentBitsCrc = Get_WordsCrc(Fragment.PackedBits);

        ck::Trace(f"[FoodPieceSpike] wire: expected planes={Expected.Num()} doubles={ExpectedBits.Num()} crc={Get_Hex(uint64(ExpectedCrc))} | "
            + f"spawn data planes={SpawnPlanes.Num()} crc={Get_Hex(uint64(SpawnCrc))} packed={Record.PackedBits.Num()} crc={Get_Hex(uint64(SpawnBitsCrc))} | "
            + f"fragment planes={Fragment.Planes.Num()} crc={Get_Hex(uint64(FragmentCrc))} packed={Fragment.PackedBits.Num()} crc={Get_Hex(uint64(FragmentBitsCrc))} "
            + f"(expected packed crc={Get_Hex(uint64(ExpectedBitsCrc))})");

        Assert_Equals_Int(SpawnPlanes.Num(), k_PlaneCount, "the spawn data carried every plane");
        Assert_Equals_Int(Fragment.Planes.Num(), k_PlaneCount, "the fragment carried every plane");
        Assert_True(SpawnCrc == ExpectedCrc, "the spawn data's doubles arrived bit for bit");
        Assert_True(FragmentCrc == ExpectedCrc, "the fragment's doubles arrived bit for bit");
        Assert_True(SpawnBitsCrc == ExpectedBitsCrc, "the spawn data's packed 64-bit patterns arrived exactly");
        Assert_True(FragmentBitsCrc == ExpectedBitsCrc, "the fragment's packed 64-bit patterns arrived exactly");
    }

    // Both machines build the same planes from the seed: positions, unit normals and unit tangents whose doubles use
    // their whole mantissa.
    private TArray<FCk_RuntimeMesh_PlaneLocal> Make_Planes() const
    {
        auto Rng = Make_Rng(k_Seed);
        TArray<FCk_RuntimeMesh_PlaneLocal> Planes;
        for (int32 Index = 0; Index < k_PlaneCount; ++Index)
        {
            const auto Position = FVector(Draw_Wide(Rng), Draw_Wide(Rng), Draw_Wide(Rng)) * k_SpanCm;
            auto Normal = FVector::ZeroVector;
            while (Normal.Size() < 0.3)
            { Normal = FVector(Draw_Wide(Rng), Draw_Wide(Rng), Draw_Wide(Rng)); }

            Planes.Add(Make_Plane(Position, Normal.GetSafeNormal()));
        }

        return Planes;
    }

    // [-1, 1) with 48 random bits.
    private float64 Draw_Wide(FMars_TESTONLY_FoodPieceSpike_Rng& InOutRng) const
    {
        const auto High = Draw(InOutRng);
        const auto Low = Draw(InOutRng);
        return (High + Low / 16777216.0) * 2.0 - 1.0;
    }
}
