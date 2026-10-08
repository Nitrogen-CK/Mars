// A piece floats over the dipped scoop (its bottom above the dipped lip). A flick - Carry, and 0.12 s later Dip again (a
// tap of Interact_Primary) - kicks the disc up through the piece's float and drops it back: the scoop's lift rises at
// least 5 above the dip (it reaches the piece), and within 1.5 s of the flick the piece is never lost: it lands back in the
// oil or on the scoop. Whether it turned over (its down face changed) is traced, not asserted: it is a tuning question.
class UMars_AutoTest_Fry_ARollFlickTumblesWithoutRoutineEjection : UMars_AutoTestRig_Fry
{
    default _TimeoutSeconds = 20.0f;

    private const float32 k_TapSeconds = 0.12f;
    private const float32 k_WatchSeconds = 1.5f;
    private const float32 k_MinKick = 5.0f;
    // How long the piece may take to float calmly over the dipped scoop after its release.
    private const float32 k_CalmTimeoutSeconds = 8.0f;
    private const float32 k_CalmSpeed = 4.0f;
    private const float32 k_LipClearanceCm = 1.0f;

    private FMars_CookingFeed_PieceId _Piece;
    private EMars_Searing_Face _DownBefore = EMars_Searing_Face::NegZ;
    private int32 _EdgesBeforeFlick = 0;
    private float32 _FlickTime = 0.0f;
    private float32 _PeakLift = -1000.0f;
    private float32 _MaxPieceSpeed = 0.0f;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        BuildStation(InHandle, Make_TestSpec());

        Add_Step_WaitUntil("the scoop and basket bodies are in the simulation", n"Check_BodiesAdded", 0, 3.0f);
        Add_Step("drive the skimmer", n"Step_Drive");
        Add_Step("dip it at its park", n"Step_Dip");
        Add_Step_WaitUntil("the scoop reached the dip", n"Check_Dipped", 0, 3.0f);
        Add_Step("release a piece over the dipped bowl", n"Step_ReleaseOverScoop");
        Add_Step_WaitUntil("the piece floats calmly over the dipped lip", n"Check_FloatCalm", 0, k_CalmTimeoutSeconds);
        Add_Step("record its down face; carry (the flick's rise)", n"Step_FlickUp");
        Add_Step_WaitUntil("the tap's length passed", n"Check_TapElapsed", 0, 1.0f);
        Add_Step("dip again (the flick's fall)", n"Step_FlickDown");
        Add_Step_WaitUntil("1.5 s after the flick", n"Check_Watched", 0, k_WatchSeconds + 1.0f);
        Add_Step("the scoop reached the piece; nothing was lost; the tumble traced", n"Step_AssertNoLoss");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_ReleaseOverScoop(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto ScoopRoot = _Fry.Get_ScoopRoot();
        _Piece = AddPiece(FVector(ScoopRoot.X, ScoopRoot.Y - 2.0, float64(_Spec.Oil.SurfaceZ + _Spec.Piece.HalfSize + 1.0f)));
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
    private void Step_FlickUp(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _DownBefore = Get_DownFace(_Piece);
        _EdgesBeforeFlick = _WhereaboutsTo.Num();
        _FlickTime = Get_Now();
        Carry();
    }

    UFUNCTION()
    private void Check_TapElapsed(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        Sample();
        auto Res = OutResult;
        Res.Set(Get_Now() - _FlickTime >= k_TapSeconds);
    }

    UFUNCTION()
    private void Step_FlickDown(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Sample();
        Dip();
    }

    private void Sample()
    {
        _PeakLift = Math::Max(_PeakLift, _Skimmer.Get_Lift());
        if (_Fry.Get_HasPiece(_Piece))
        { _MaxPieceSpeed = Math::Max(_MaxPieceSpeed, float32(Get_PieceSpeed(_Piece))); }
    }

    UFUNCTION()
    private void Check_Watched(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        Sample();
        auto Res = OutResult;
        Res.Set(Get_Now() - _FlickTime >= k_WatchSeconds);
    }

    UFUNCTION()
    private void Step_AssertNoLoss(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        TArray<EMars_Fry_Whereabouts> Path;
        const auto Edges = Get_Path(_Piece, _EdgesBeforeFlick, Path);
        const auto DownAfter = Get_DownFace(_Piece);
        const auto Kick = _PeakLift - _Spec.Scoop.DipLift;
        FString Turned = "same face";
        if (DownAfter != _DownBefore)
        { Turned = "turned over"; }

        Log(f"[Mars_AutoTest_Fry_ARollFlickTumblesWithoutRoutineEjection] kick {Kick :.2} above the dip, fastest piece {_MaxPieceSpeed :.1} cm/s, edges{Edges}, down face {utils_searing::Get_FaceName(_DownBefore)} -> {utils_searing::Get_FaceName(DownAfter)} ({Turned}), ends {_Fry.Get_PieceWhereabouts(_Piece) :n}");

        Assert_True(Kick >= k_MinKick, f"the flick lifted the scoop at least {k_MinKick} above the dip (got {Kick :.2})");
        Assert_Equals_Int(_Fry.Get_Tally().Lost, 0, "no piece was lost");
        Assert_Equals_Int(_LostIds.Num(), 0, "OnPieceLost never fired");

        const auto Whereabouts = _Fry.Get_PieceWhereabouts(_Piece);
        Assert_True(Whereabouts != EMars_Fry_Whereabouts::Lost, f"the piece is still in play (got {Whereabouts :n})");
    }
}
