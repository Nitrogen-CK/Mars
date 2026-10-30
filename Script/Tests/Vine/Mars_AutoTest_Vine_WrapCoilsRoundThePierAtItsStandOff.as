// An ivy Wrap of 2 turns over 300 cm round a 60 x 60 cm pier: every stem point lies at the stand-off from a pier face
// (the stem radius 0.6 - 1.2 cm plus 0.5 cm, with 2 cm of slack below for corners the resampling cuts and 4 above), and
// the stem sweeps 2 x 360 degrees (+-10 %) round the pier axis.
class UMars_AutoTest_Vine_WrapCoilsRoundThePierAtItsStandOff : UMars_AutoTestRig_Vine
{
    default _Slot = 8;
    private AMars_Vine _Vine;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Add_Step("a pier on a floor", n"Step_Room");
        Add_Step_WaitFrames("let the slab bodies register", 2);
        Add_Step("an ivy wrapped round it", n"Step_Vine");
        Add_Step("the coil hugs the pier for two turns", n"Step_Assert");
        Add_Step("cleanup", n"Step_Cleanup");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_Room(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto O = Get_Origin();
        SpawnSlab(O, FVector(0.6, 0.6, 6.0));
        SpawnFloor(O, O.Z - 300.0, FVector(800.0, 800.0, 50.0));
    }

    UFUNCTION()
    private void Step_Vine(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Spawn = Make_Spawn(Make_Profile(EMars_VinePreset::Ivy), EMars_VineLayout::Wrap, EMars_VineEnd::Air);
        Spawn.Location = Get_Origin() - FVector(0.0, 0.0, 250.0);
        Spawn.Shape.Turns = 2.0f;
        Spawn.Shape.HeightCm = 300.0f;
        Spawn.Shape.StrandCount = 1;
        _Vine = SpawnVine(Spawn);
    }

    // Signed distance from (x, y) to the 60 x 60 square centred on the pier axis.
    private float Get_SquareDistance(float InX, float InY)
    {
        const auto DX = Math::Abs(InX) - 30.0;
        const auto DY = Math::Abs(InY) - 30.0;
        if (DX <= 0.0 && DY <= 0.0)
        { return Math::Max(DX, DY); }
        return Math::Sqrt(Math::Square(Math::Max(DX, 0.0)) + Math::Square(Math::Max(DY, 0.0)));
    }

    UFUNCTION()
    private void Step_Assert(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        if (ck::Is_NOT_Valid(_Vine))
        { return; }

        const auto O = Get_Origin();
        const auto Stems = Get_WorldPaths(_Vine, EMars_VinePathKind::Stem);
        Assert_Equals_Int(Stems.Num(), 1, f"one stem ({_Vine.Status})");
        if (Stems.Num() != 1)
        { return; }

        float Worst = 0.0;
        float Swept = 0.0;
        float Previous = 0.0;
        for (int32 Index = 0; Index < Stems[0].Points.Num(); ++Index)
        {
            const auto P = Stems[0].Points[Index] - O;
            const auto D = Get_SquareDistance(P.X, P.Y);
            if (D < -2.0 + 0.6 || D > 1.7 + 4.0)
            { Worst = Math::Max(Worst, Math::Abs(D)); }
            const auto Angle = Math::Atan2(P.Y, P.X);
            if (Index > 0)
            {
                auto Delta = Angle - Previous;
                while (Delta > PI)
                { Delta -= 2.0 * PI; }
                while (Delta < -PI)
                { Delta += 2.0 * PI; }
                Swept += Delta;
            }
            Previous = Angle;
        }
        Assert_True(Worst == 0.0, f"every point hugs a pier face (worst {Worst :.2} cm off)");
        const auto Degrees = Math::Abs(Swept) * 180.0 / PI;
        Assert_True(Math::Abs(Degrees - 720.0) <= 72.0, f"the coil sweeps two turns ({Degrees :.0} degrees)");
    }
}
