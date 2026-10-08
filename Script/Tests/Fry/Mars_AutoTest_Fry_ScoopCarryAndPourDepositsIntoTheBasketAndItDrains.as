// The whole fryer loop on one piece: released at its float height, it floats over the dipped scoop; Carry lifts it out of the oil (Oil -> Skimmer: one
// retrieval); the carried scoop is eased (as a hand moves it, and within the reach: first to a point both in the pot disc
// and in the corridor, then along the corridor) out of the pot and over the basket, the piece still on it; a Dip there pours (pitch target PourPitchDegrees, toward the operator; lift target the carry) and the piece slides off into
// the basket (Skimmer -> DrainBasket, directly or via Airborne; nothing lost); resting on the basket floor it drains and is
// Drained after Receiver.DrainSeconds, OnPieceDrained once.
class UMars_AutoTest_Fry_ScoopCarryAndPourDepositsIntoTheBasketAndItDrains : UMars_AutoTestRig_Fry
{
    default _TimeoutSeconds = 40.0f;

    private const float32 k_DrainSeconds = 0.5f;
    // cm/s^2: the world's gravity the float height is predicted from.
    private const float32 k_Gravity = 980.0f;
    private const float32 k_CalmTimeoutSeconds = 8.0f;
    private const float32 k_CalmSpeed = 4.0f;
    private const float32 k_LipClearanceCm = 1.0f;
    // A carried piece is moved the way a hand moves it: the target eases (smoothstep) leg by leg, not in one jump the slide
    // spring would turn into a shove that throws the piece off the scoop. The first leg ends where the pot disc and the
    // corridor overlap (the straight line from the park to the basket would cut the disc's corner, outside the reach).
    private const FVector2D k_CorridorEntry = FVector2D(15.0, 20.0);
    private const float32 k_EntrySeconds = 1.5f;
    private const float32 k_CarrySeconds = 3.5f;
    private const float32 k_CarrySettleSeconds = 0.3f;
    private const float32 k_CarryTolerance = 1.0f;

    private FMars_CookingFeed_PieceId _Piece;
    private int32 _EdgesBeforeLift = 0;
    private int32 _EdgesBeforePour = 0;
    private float32 _PourTime = 0.0f;
    // The eased carry: from, to, the target issued so far (looks drain a frame later, so the issued target is tracked here
    // rather than read back) and when it started.
    private FVector2D _CarryFrom = FVector2D::ZeroVector;
    private FVector2D _CarryTo = FVector2D::ZeroVector;
    private FVector2D _CarryIssued = FVector2D::ZeroVector;
    private float32 _CarryStart = 0.0f;
    private float32 _CarryLegSeconds = 1.0f;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Spec = Make_TestSpec();
        Spec.Receiver.DrainSeconds = k_DrainSeconds;
        BuildStation(InHandle, Spec);

        Add_Step_WaitUntil("the scoop and basket bodies are in the simulation", n"Check_BodiesAdded", 0, 3.0f);
        Add_Step("drive the skimmer", n"Step_Drive");
        Add_Step("dip it at its park", n"Step_Dip");
        Add_Step_WaitUntil("the scoop reached the dip", n"Check_Dipped", 0, 3.0f);
        Add_Step("release a piece over the dipped bowl", n"Step_ReleaseOverScoop");
        Add_Step_WaitUntil("the piece floats calmly over the dipped lip", n"Check_FloatCalm", 0, k_CalmTimeoutSeconds);
        Add_Step("lift: carry", n"Step_Lift");
        Add_Step_WaitUntil("the scoop carried the piece out of the oil", n"Check_Retrieved", 0, 4.0f);
        Add_Step("Oil -> Skimmer, one retrieval; ease the scoop to the corridor's entry", n"Step_AssertRetrievedThenCarry");
        Add_Step_WaitUntil("the scoop is at the corridor's entry", n"Check_CarryDone", 0, k_EntrySeconds + 2.0f);
        Add_Step("ease the scoop along the corridor over the basket", n"Step_CarryOverBasket");
        Add_Step_WaitUntil("the scoop is over the basket", n"Check_CarryDone", 0, k_CarrySeconds + 2.0f);
        Add_Step_WaitSeconds("the carried piece settles", k_CarrySettleSeconds);
        Add_Step("still on the skimmer over the basket; ask for a dip", n"Step_AskDipOverBasket");
        Add_Step_WaitUntil("the skim answered", n"Check_SkimNotCarry", 0, 0.5f);
        Add_Step("the dip became a pour", n"Step_AssertPour");
        Add_Step_WaitUntil("the poured piece is in the basket", n"Check_InBasket", 0, 3.0f);
        Add_Step_WaitUntil("the piece drained", n"Check_FirstDrained", 0, 3.0f);
        Add_Step("Skimmer -> DrainBasket, drained once, nothing lost", n"Step_AssertDrained");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_ReleaseOverScoop(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        // At its float height: released higher it would plunge on entry, touch the dipped disc and bob off it again (a
        // retrieval of its own) before the lift.
        const auto ScoopRoot = _Fry.Get_ScoopRoot();
        const auto HalfSize = _Spec.Piece.HalfSize;
        const auto FloatZ = _Spec.Oil.SurfaceZ + HalfSize - 2.0f * HalfSize * k_Gravity / _Spec.Oil.BuoyancyAccel;
        _Piece = AddPiece(FVector(ScoopRoot.X, ScoopRoot.Y, float64(FloatZ)));
    }

    UFUNCTION()
    private void Check_FloatCalm(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        if (_Added.Num() == 0 || _Fry.Get_HasPiece(_Piece) == false)
        {
            Res.Set(false);
            return;
        }

        const auto Bottom = Get_PieceRootLocal(_Piece).Z - float64(_Spec.Piece.HalfSize);
        const auto LipTop = _Fry.Get_ScoopRoot().Z + float64(_Spec.Scoop.LipHeight + k_LipClearanceCm);
        Res.Set(_Fry.Get_PieceWhereabouts(_Piece) == EMars_Fry_Whereabouts::Oil && Get_PieceSpeed(_Piece) < float64(k_CalmSpeed) && Bottom > LipTop);
    }

    UFUNCTION()
    private void Step_Lift(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _EdgesBeforeLift = _WhereaboutsTo.Num();
        Carry();
    }

    UFUNCTION()
    private void Check_Retrieved(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Fry.Get_PieceWhereabouts(_Piece) == EMars_Fry_Whereabouts::Skimmer && Get_IsLiftAt(_Spec.Scoop.CarryLift));
    }

    UFUNCTION()
    private void Step_AssertRetrievedThenCarry(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        TArray<EMars_Fry_Whereabouts> Path;
        const auto Edges = Get_Path(_Piece, _EdgesBeforeLift, Path);
        Log(f"[Mars_AutoTest_Fry_ScoopCarryAndPourDepositsIntoTheBasketAndItDrains] lift: edges{Edges}, piece at root {Get_PieceRootLocal(_Piece)}, scoop top {_Fry.Get_ScoopRoot()}");

        Assert_True(Path.Num() >= 2 && Path[0] == EMars_Fry_Whereabouts::Oil && Path.Last() == EMars_Fry_Whereabouts::Skimmer,
            f"the piece went Oil -> Skimmer (edges{Edges})");
        Assert_Equals_Int(_Fry.Get_Tally().Retrievals, 1, "one retrieval");
        Assert_True(_Fry.Get_IsScoopClearOfRim(), "the carried scoop is clear of the rim");

        Start_Carry(k_CorridorEntry, k_EntrySeconds);
    }

    UFUNCTION()
    private void Step_CarryOverBasket(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Fry.Get_PieceWhereabouts(_Piece) == EMars_Fry_Whereabouts::Skimmer,
            f"at the corridor's entry the piece is still on the skimmer (got {_Fry.Get_PieceWhereabouts(_Piece) :n})");
        Start_Carry(_Spec.Reach.BasketCentre, k_CarrySeconds);
    }

    private void Start_Carry(FVector2D InTo, float32 InSeconds)
    {
        _CarryFrom = _Fry.Get_SkimmerTarget();
        _CarryIssued = _CarryFrom;
        _CarryTo = InTo;
        _CarryLegSeconds = InSeconds;
        _CarryStart = Get_Now();
    }

    // Eases the target along the carry (one look per check for the step since the last one) until it is there and the
    // scoop has followed it.
    UFUNCTION()
    private void Check_CarryDone(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto Alpha = Math::Clamp((Get_Now() - _CarryStart) / _CarryLegSeconds, 0.0f, 1.0f);
        const auto Eased = float64(Alpha * Alpha * (3.0f - 2.0f * Alpha));
        const auto Wanted = _CarryFrom + (_CarryTo - _CarryFrom) * Eased;
        const auto Step = Wanted - _CarryIssued;
        if (Step.Size() > 0.0001)
        {
            SlideSkimmerBy(Step);
            _CarryIssued = Wanted;
        }

        const auto ScoopRoot = _Fry.Get_ScoopRoot();
        auto Res = OutResult;
        Res.Set(Alpha >= 1.0f
            && (_Fry.Get_SkimmerTarget() - _CarryTo).Size() <= float64(k_CarryTolerance)
            && (FVector2D(ScoopRoot.X, ScoopRoot.Y) - _CarryTo).Size() <= float64(k_CarryTolerance));
    }

    UFUNCTION()
    private void Step_AskDipOverBasket(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Whereabouts = _Fry.Get_PieceWhereabouts(_Piece);
        Log(f"[Mars_AutoTest_Fry_ScoopCarryAndPourDepositsIntoTheBasketAndItDrains] pour: scoop top at root {_Fry.Get_ScoopRoot()}, piece at root {Get_PieceRootLocal(_Piece)} ({Whereabouts :n})");
        Assert_True(Whereabouts == EMars_Fry_Whereabouts::Skimmer, f"carried over the basket, the piece is still on the skimmer (got {Whereabouts :n})");
        Assert_True(_Fry.Get_IsScoopOverBasket(), "the whole bowl is over the basket interior");

        _EdgesBeforePour = _WhereaboutsTo.Num();
        _PourTime = Get_Now();
        Dip();
    }

    UFUNCTION()
    private void Check_SkimNotCarry(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Fry.Get_Skim() != EMars_Fry_Skim::Carry);
    }

    UFUNCTION()
    private void Step_AssertPour(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Fry.Get_Skim() == EMars_Fry_Skim::Pour, f"a dip over the basket pours (got {_Fry.Get_Skim() :n})");
        Assert_Equals_Float(_Skimmer.Get_TargetTilt().Pitch, float64(_Spec.Scoop.PourPitchDegrees), 0.001, "the scoop's pitch target is the pour's");
        Assert_Equals_Float(_Skimmer.Get_TargetLift(), _Spec.Scoop.CarryLift, 0.0001, "the pour holds the lift at the carry");
        Assert_True(_SkimChanges.Num() > 0 && _SkimChanges.Last() == EMars_Fry_Skim::Pour, "OnSkimChanged reported the Pour");
    }

    UFUNCTION()
    private void Check_InBasket(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Fry.Get_PieceWhereabouts(_Piece) == EMars_Fry_Whereabouts::DrainBasket);
    }

    UFUNCTION()
    private void Step_AssertDrained(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        TArray<EMars_Fry_Whereabouts> Path;
        const auto Edges = Get_Path(_Piece, _EdgesBeforePour, Path);
        Log(f"[Mars_AutoTest_Fry_ScoopCarryAndPourDepositsIntoTheBasketAndItDrains] pour: edges{Edges} within {Get_Now() - _PourTime :.3} s, piece at root {Get_PieceRootLocal(_Piece)}, scoop tilt {_Skimmer.Get_Tilt()}");

        const auto Direct = Path.Num() == 2 && Path[0] == EMars_Fry_Whereabouts::Skimmer && Path[1] == EMars_Fry_Whereabouts::DrainBasket;
        const auto ViaAir = Path.Num() == 3 && Path[0] == EMars_Fry_Whereabouts::Skimmer
            && Path[1] == EMars_Fry_Whereabouts::Airborne && Path[2] == EMars_Fry_Whereabouts::DrainBasket;
        Assert_True(Direct || ViaAir, f"the piece went Skimmer -> DrainBasket or Skimmer -> Airborne -> DrainBasket (edges{Edges})");

        Assert_True(_Fry.Get_PieceDrain(_Piece) == EMars_Fry_Drain::Drained, "the piece is Drained");
        Assert_Equals_Float(_Fry.Get_PieceDrainProgress(_Piece), 1.0, 0.0001, "its drain progress is full");
        Assert_Equals_Int(Count_Ids(_DrainedIds, _Piece), 1, "OnPieceDrained fired once");

        const auto Summary = _Fry.Get_Summary();
        Assert_Equals_Int(Summary.InBasket, 1, "one piece in the basket");
        Assert_Equals_Int(Summary.Drained, 1, "one drained");
        Assert_Equals_Int(Summary.Lost, 0, "nothing lost");
        Assert_Equals_Int(_Fry.Get_Tally().Ejections, 0, "a deposit is not an ejection");
    }
}
