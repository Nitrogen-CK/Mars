// Five pieces released in one drain, each where one whereabouts lives: A a little above the parked scoop lands in the bowl
// (Airborne -> Skimmer: one catch); B just above the oil floats there (Oil), its height sampled over a 0.5 s window (the
// float is a lightly damped bob, so one frame's height is the phase of the bob, not the float) against the predicted
// float; C below FloorZ is Lost at once; D over the drain basket lands in it (DrainBasket); E over the corridor (outside the
// pot, outside the basket) falls past the rim and is Lost (the corridor is no home). Teleported beside the bowl, A falls
// past the lip into the oil and never reads Skimmer: the catch needs the scoop's contact AND the bowl. C and E report Lost
// once and never leave it.
class UMars_AutoTest_Fry_WhereaboutsFollowTheGeometry : UMars_AutoTestRig_Fry
{
    default _TimeoutSeconds = 30.0f;

    // cm of fall from the release onto the disc (the piece's bottom above the disc's top).
    private const float32 k_DropHeight = 6.0f;
    // Station frame: over the oil on the operator's side, clear of the scoop.
    private const FVector2D k_OilXY = FVector2D(-30.0, 0.0);
    // Over the corridor: outside the pot (radius 45) and short of the basket's outer footprint (Y 62.8).
    private const FVector k_CorridorLocal = FVector(0.0, 52.0, 122.0);
    // cm/s^2: the world's gravity the float height is predicted from.
    private const float32 k_Gravity = 980.0f;
    // How long the oil piece floats before its height is sampled, the sampling window, and how far the window's mid-height
    // may sit from the predicted float.
    private const float32 k_FloatSettleSeconds = 2.0f;
    private const float32 k_FloatWindowSeconds = 0.5f;
    private const float32 k_FloatBand = 1.5f;
    // Seconds after the beside piece found a home in which a late Skimmer edge would still show.
    private const float32 k_BesideSettleSeconds = 0.5f;

    private FMars_CookingFeed_PieceId _A;
    private FMars_CookingFeed_PieceId _B;
    private FMars_CookingFeed_PieceId _C;
    private FMars_CookingFeed_PieceId _D;
    private FMars_CookingFeed_PieceId _E;
    private float32 _ReleaseTime = 0.0f;
    private float32 _WindowStart = -1.0f;
    private float64 _FloatMin = 1000000.0;
    private float64 _FloatMax = -1000000.0;
    private int32 _EdgesBeforeBeside = 0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Spec = Make_TestSpec();
        // Lost bodies linger past the end of the test, so "still Lost" is read off a piece that still exists.
        Spec.Zones.LingerSeconds = 20.0f;
        BuildStation(InHandle, Spec);

        Add_Step_WaitUntil("the scoop and basket bodies are in the simulation", n"Check_BodiesAdded", 0, 3.0f);
        Add_Step("release A over the scoop, B over the oil, C below the floor, D over the basket, E over the corridor", n"Step_Release");
        Add_Step_WaitUntil("every piece found its whereabouts", n"Check_AllHomed", 0, 4.0f);
        Add_Step("A caught, C and E lost, D in the basket", n"Step_AssertHomes");
        Add_Step_WaitUntil("the oil piece floated a while and its window was sampled", n"Check_FloatSampled", 0, 6.0f);
        Add_Step("B floats near the predicted line; teleport A beside the bowl", n"Step_AssertFloatThenBeside");
        Add_Step_WaitUntil("A came down beside the scoop", n"Check_BesideLanded", 0, 3.0f);
        Add_Step_WaitSeconds("a late catch would show", k_BesideSettleSeconds);
        Add_Step("A never read Skimmer beside the bowl; C and E stayed Lost", n"Step_AssertBeside");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_Release(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto HalfSize = float64(_Spec.Piece.HalfSize);
        const auto ScoopTop = _Fry.Get_ScoopRoot();
        _A = AddPiece(ScoopTop + FVector(0.0, 0.0, HalfSize + float64(k_DropHeight)));
        _B = AddPiece(FVector(k_OilXY.X, k_OilXY.Y, float64(_Spec.Oil.SurfaceZ) + HalfSize + 1.0));
        _C = AddPiece(FVector(0.0, 0.0, float64(_Spec.Zones.FloorZ) - 20.0));
        _D = AddPiece(k_BasketLocal + FVector(0.0, 0.0, HalfSize + 3.0));
        _E = AddPiece(k_CorridorLocal);
        _ReleaseTime = Get_Now();
        ck::Trace(f"[Fry] whereabouts: scoop top centre at root {ScoopTop}");
    }

    UFUNCTION()
    private void Check_AllHomed(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Added.Num() == 5
            && _Fry.Get_PieceWhereabouts(_A) == EMars_Fry_Whereabouts::Skimmer
            && _Fry.Get_PieceWhereabouts(_B) == EMars_Fry_Whereabouts::Oil
            && _Fry.Get_PieceWhereabouts(_C) == EMars_Fry_Whereabouts::Lost
            && _Fry.Get_PieceWhereabouts(_D) == EMars_Fry_Whereabouts::DrainBasket
            && _Fry.Get_PieceWhereabouts(_E) == EMars_Fry_Whereabouts::Lost);
    }

    UFUNCTION()
    private void Step_AssertHomes(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        TArray<EMars_Fry_Whereabouts> Path;
        const auto EdgesA = Get_Path(_A, 0, Path);
        Log(f"[Mars_AutoTest_Fry_WhereaboutsFollowTheGeometry] A edges{EdgesA}, at root {Get_PieceRootLocal(_A)}");
        Assert_True(Path.Num() == 2 && Path[0] == EMars_Fry_Whereabouts::Airborne && Path[1] == EMars_Fry_Whereabouts::Skimmer,
            f"A went Airborne -> Skimmer (edges{EdgesA})");
        Assert_Equals_Float(Get_PieceRootLocal(_A).Z, _Fry.Get_ScoopRoot().Z + float64(_Spec.Piece.HalfSize), 1.0, "A rests on the disc");

        const auto EdgesD = Get_Path(_D, 0, Path);
        Assert_True(Path.Num() == 2 && Path[1] == EMars_Fry_Whereabouts::DrainBasket, f"D went straight into the DrainBasket (edges{EdgesD})");

        const auto EdgesC = Get_Path(_C, 0, Path);
        Assert_True(Path.Num() == 2 && Path[1] == EMars_Fry_Whereabouts::Lost, f"C below the floor is Lost (edges{EdgesC})");

        const auto EdgesE = Get_Path(_E, 0, Path);
        Log(f"[Mars_AutoTest_Fry_WhereaboutsFollowTheGeometry] E (over the corridor) edges{EdgesE}");
        Assert_True(Path.Num() == 2 && Path[0] == EMars_Fry_Whereabouts::Airborne && Path[1] == EMars_Fry_Whereabouts::Lost,
            f"E over the corridor fell straight from Airborne to Lost (edges{EdgesE})");

        const auto Tally = _Fry.Get_Tally();
        Assert_Equals_Int(Tally.Catches, 1, "a hop that landed on the scoop is a catch");
        Assert_Equals_Int(Tally.Retrievals, 0, "no retrieval");
        Assert_Equals_Int(Tally.Lost, 2, "two lost pieces in the tally");
        Assert_Equals_Int(Tally.Ejections, 0, "nothing left the basket");
        Assert_Equals_Int(_LostIds.Num(), 2, "OnPieceLost fired twice");

        const auto Summary = _Fry.Get_Summary();
        Assert_Equals_Int(Summary.Admitted, 5, "the summary admits five");
        Assert_True(Summary.OnSkimmer == 1 && Summary.InOil == 1 && Summary.InBasket == 1 && Summary.Lost == 2,
            f"the summary has one on the scoop, one in the oil, one in the basket and two lost (got {Summary.OnSkimmer}, {Summary.InOil}, {Summary.InBasket}, {Summary.Lost})");
    }

    // Samples B's height every check once it has floated k_FloatSettleSeconds, for k_FloatWindowSeconds.
    UFUNCTION()
    private void Check_FloatSampled(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto Now = Get_Now();
        if (Now - _ReleaseTime < k_FloatSettleSeconds)
        {
            auto Waiting = OutResult;
            Waiting.Set(false);
            return;
        }

        if (_WindowStart < 0.0f)
        { _WindowStart = Now; }

        const auto Z = Get_PieceRootLocal(_B).Z;
        _FloatMin = Math::Min(_FloatMin, Z);
        _FloatMax = Math::Max(_FloatMax, Z);

        auto Res = OutResult;
        Res.Set(Now - _WindowStart >= k_FloatWindowSeconds);
    }

    UFUNCTION()
    private void Step_AssertFloatThenBeside(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto HalfSize = _Spec.Piece.HalfSize;
        const auto FloatZ = float64(_Spec.Oil.SurfaceZ + HalfSize - 2.0f * HalfSize * k_Gravity / _Spec.Oil.BuoyancyAccel);
        const auto MidZ = (_FloatMin + _FloatMax) * 0.5;
        Log(f"[Mars_AutoTest_Fry_WhereaboutsFollowTheGeometry] oil piece over {k_FloatWindowSeconds} s: Z {_FloatMin :.2} .. {_FloatMax :.2} (mid {MidZ :.2}), predicted float Z {FloatZ :.2}");

        Assert_True(_Fry.Get_PieceWhereabouts(_B) == EMars_Fry_Whereabouts::Oil, f"B is in the Oil (got {_Fry.Get_PieceWhereabouts(_B) :n})");
        Assert_Equals_Float(MidZ, FloatZ, float64(k_FloatBand), "B's float, mid-window, sits at the predicted height");

        _EdgesBeforeBeside = _WhereaboutsTo.Num();
        const auto Beside = _Fry.Get_ScoopRoot()
            + FVector(0.0, float64(_Spec.Scoop.BowlRadius + 2.0f * HalfSize), float64(HalfSize + k_DropHeight));
        ck::Trace(f"[Fry] piece A beside the bowl: to root {Beside}");
        Teleport(_A, Beside, FVector::ZeroVector);
    }

    UFUNCTION()
    private void Check_BesideLanded(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto Whereabouts = _Fry.Get_PieceWhereabouts(_A);
        auto Res = OutResult;
        Res.Set(_WhereaboutsTo.Num() > _EdgesBeforeBeside
            && Whereabouts != EMars_Fry_Whereabouts::Airborne
            && Whereabouts != EMars_Fry_Whereabouts::Skimmer);
    }

    UFUNCTION()
    private void Step_AssertBeside(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        TArray<EMars_Fry_Whereabouts> Path;
        const auto Edges = Get_Path(_A, _EdgesBeforeBeside, Path);
        Log(f"[Mars_AutoTest_Fry_WhereaboutsFollowTheGeometry] beside the bowl: A edges{Edges}, ends {_Fry.Get_PieceWhereabouts(_A) :n} at root {Get_PieceRootLocal(_A)}");

        for (int32 Index = 1; Index < Path.Num(); ++Index)
        { Assert_True(Path[Index] != EMars_Fry_Whereabouts::Skimmer, f"A beside the bowl never read Skimmer (edges{Edges})"); }

        Assert_True(_Fry.Get_PieceWhereabouts(_A) == EMars_Fry_Whereabouts::Oil, f"A fell into the Oil (got {_Fry.Get_PieceWhereabouts(_A) :n})");
        Assert_Equals_Int(_Fry.Get_Tally().Catches, 1, "still one catch");

        Assert_True(_Fry.Get_PieceWhereabouts(_C) == EMars_Fry_Whereabouts::Lost, "C is still Lost");
        Assert_True(_Fry.Get_PieceWhereabouts(_E) == EMars_Fry_Whereabouts::Lost, "E is still Lost");
        Assert_Equals_Int(Count_Ids(_LostIds, _C), 1, "C reported Lost once");
        Assert_Equals_Int(Count_Ids(_LostIds, _E), 1, "E reported Lost once");
    }
}
