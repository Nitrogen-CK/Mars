// Three pieces released level a centimetre above the oil float there unattended (no basket, no scoop: the buoyancy is the
// oil's alone). After twice GoldenSeconds (1 s here) in the oil each piece is still in the Oil, its down face is Golden and
// its up face, above the line at the float (Oil.BuoyancyAccel 1500 holds about a third of the height dry), is still Pale:
// passive floating never finishes every face (the A10 equilibrium check). Every face reported Golden at most once.
class UMars_AutoTest_Fry_PiecesFloatInTheOilAndFryBelowTheLine : UMars_AutoTestRig_Fry
{
    default _TimeoutSeconds = 15.0f;

    private const float32 k_GoldenSeconds = 1.0f;
    // Clear of each other and of the parked scoop's footprint, inside the pot.
    private const FVector2D k_SpotA = FVector2D(-20.0, 0.0);
    private const FVector2D k_SpotB = FVector2D(0.0, -22.0);
    private const FVector2D k_SpotC = FVector2D(-5.0, 22.0);

    private TArray<FMars_CookingFeed_PieceId> _Ids;
    private float32 _AllInOilTime = 0.0f;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Spec = Make_TestSpec();
        Spec.Heat.GoldenSeconds = k_GoldenSeconds;
        // No face reaches Overdone in this test's time: every report is a Golden one.
        Spec.Heat.OverdoneSeconds = 100.0f;
        BuildStation(InHandle, Spec);

        Add_Step_WaitUntil("the scoop and basket bodies are in the simulation", n"Check_BodiesAdded", 0, 3.0f);
        Add_Step("release three pieces just above the oil", n"Step_Release");
        Add_Step_WaitUntil("all three float in the oil", n"Check_AllInOil", 0, 3.0f);
        Add_Step("start the clock", n"Step_StartClock");
        Add_Step_WaitUntil("twice GoldenSeconds in the oil", n"Check_TwiceGolden", 0, 4.0f);
        Add_Step("down faces golden, up faces pale, each reported once", n"Step_AssertFloatFried");
        Run_Steps(InHandle);
    }

    private FVector Get_ReleaseAt(FVector2D InSpot) const
    {
        return FVector(InSpot.X, InSpot.Y, float64(_Spec.Oil.SurfaceZ + _Spec.Piece.HalfSize + 1.0f));
    }

    UFUNCTION()
    private void Step_Release(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Ids.Add(AddPiece(Get_ReleaseAt(k_SpotA)));
        _Ids.Add(AddPiece(Get_ReleaseAt(k_SpotB)));
        _Ids.Add(AddPiece(Get_ReleaseAt(k_SpotC)));
    }

    UFUNCTION()
    private void Check_AllInOil(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto AllInOil = _Added.Num() == 3;
        for (const auto& PieceId : _Ids)
        {
            if (_Fry.Get_HasPiece(PieceId) == false || _Fry.Get_PieceWhereabouts(PieceId) != EMars_Fry_Whereabouts::Oil)
            { AllInOil = false; }
        }

        auto Res = OutResult;
        Res.Set(AllInOil);
    }

    UFUNCTION()
    private void Step_StartClock(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _AllInOilTime = Get_Now();
    }

    UFUNCTION()
    private void Check_TwiceGolden(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_Now() - _AllInOilTime >= 2.0f * k_GoldenSeconds);
    }

    UFUNCTION()
    private void Step_AssertFloatFried(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Log(f"[Mars_AutoTest_Fry_PiecesFloatInTheOilAndFryBelowTheLine] Oil.BuoyancyAccel {_Spec.Oil.BuoyancyAccel}, predicted dry share {1.0f - 980.0f / _Spec.Oil.BuoyancyAccel :.3}");

        for (const auto& PieceId : _Ids)
        {
            const auto PieceName = utils_cooking_feed::Get_PieceName(PieceId);
            Assert_True(_Fry.Get_PieceWhereabouts(PieceId) == EMars_Fry_Whereabouts::Oil,
                f"piece {PieceName} still floats in the Oil (got {_Fry.Get_PieceWhereabouts(PieceId) :n})");

            const auto Up = Get_UpFace(PieceId);
            const auto Down = Get_DownFace(PieceId);
            auto Heats = FString();
            for (int32 FaceIndex = 0; FaceIndex < utils_searing::k_FaceCount; ++FaceIndex)
            {
                const auto Face = EMars_Searing_Face(FaceIndex);
                Heats = f"{Heats} {utils_searing::Get_FaceName(Face)} {_Fry.Get_FaceHeat(PieceId, Face) :.2}";
            }

            Log(f"[Mars_AutoTest_Fry_PiecesFloatInTheOilAndFryBelowTheLine] piece {PieceName} at root {Get_PieceRootLocal(PieceId)}, up {utils_searing::Get_FaceName(Up)}, heats{Heats}, {_Fry.Get_PaleFaceCount(PieceId)} pale");

            Assert_True(_Fry.Get_PieceStage(PieceId, Down) == EMars_Fry_HeatStage::Golden,
                f"piece {PieceName}'s down face {utils_searing::Get_FaceName(Down)} is under the oil and Golden (heat {_Fry.Get_FaceHeat(PieceId, Down) :.3})");
            Assert_True(_Fry.Get_PieceStage(PieceId, Up) == EMars_Fry_HeatStage::Pale,
                f"piece {PieceName}'s up face {utils_searing::Get_FaceName(Up)} floats above the line and is still Pale (heat {_Fry.Get_FaceHeat(PieceId, Up) :.3})");
            Assert_True(_Fry.Get_PaleFaceCount(PieceId) >= 1, f"piece {PieceName} has at least one pale face");

            for (int32 FaceIndex = 0; FaceIndex < utils_searing::k_FaceCount; ++FaceIndex)
            {
                auto Reports = 0;
                for (int32 Signal = 0; Signal < _Stages.Num(); ++Signal)
                {
                    if (_StageIds[Signal].Get_IsSame(PieceId) && _StageFaces[Signal] == EMars_Searing_Face(FaceIndex))
                    { Reports += 1; }
                }

                Assert_True(Reports <= 1, f"piece {PieceName} face {utils_searing::Get_FaceName(EMars_Searing_Face(FaceIndex))} reported at most once (got {Reports})");
            }
        }

        for (const auto Stage : _Stages)
        { Assert_True(Stage == EMars_Fry_HeatStage::Golden, f"every report is Golden (got {Stage :n})"); }

        const auto Summary = _Fry.Get_Summary();
        Assert_Equals_Int(Summary.InOil, 3, "the summary has three in the oil");
        Assert_True(Summary.PaleFaces >= 3, f"at least one pale face per piece in the summary (got {Summary.PaleFaces})");
    }
}
