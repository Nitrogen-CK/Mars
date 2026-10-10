// Batter and sear are separate channels of a piece's cook state. A piece whose +Z face was fried golden before (batter 1)
// and whose -Z face was seared on a pan (sear 1) arrives in the fryer with +Z golden (heat 1, stage Golden, never reported
// again) and every other face pale, -Z included: a pan's sear is not batter. It floats in the oil a while (its faces under
// the line heat), is moved into the basket and drains there; an unnamed TakeOut then hands it back: OnPieceTakenOut names
// it, it leaves play and lives on, its body reads Kinematic, and its own cook state carries each face's heat as its batter
// while its -Z sear is still 1 (the fryer never wrote the sear); its look's fry is the batter's mean.
class UMars_AutoTest_Fry_AdoptedPieceKeepsItsBatterAndItsSearApart : UMars_AutoTestRig_Fry
{
    default _TimeoutSeconds = 20.0f;

    private const float32 k_DrainSeconds = 0.5f;
    private const float32 k_GoldenSeconds = 1.0f;
    // How long the piece fries before it is moved into the basket.
    private const float32 k_FrySeconds = 0.5f;

    private FCk_Handle_FoodPiece _Food;
    private FMars_CookingFeed_PieceId _Piece;
    private FCk_Handle_JoltBody _Body;
    private float32 _InOilTime = 0.0f;
    private TArray<float32> _HeatsAtTakeOut;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Spec = Make_TestSpec();
        Spec.Receiver.DrainSeconds = k_DrainSeconds;
        Spec.Heat.GoldenSeconds = k_GoldenSeconds;
        // Nothing reaches Overdone in this test's time.
        Spec.Heat.OverdoneSeconds = 100.0f;
        BuildStation(InHandle, Spec);
        Build_Pieces(1);

        Add_Step_WaitUntil("the scoop and basket bodies are in the simulation", n"Check_BodiesAdded", 0, 0);
        Add_Step_WaitUntil("the rig's pieces are ready", n"Check_PiecesReady", 0, 0);
        Add_Step("fry the piece's +Z face golden and sear its -Z, as two stations would", n"Step_SeedChannels");
        Add_Step_WaitFrames("the cook state drains", 2);
        Add_Step("release it just above the oil", n"Step_Release");
        Add_Step_WaitUntil("its body is in the simulation", n"Check_Added1", 0, 0);
        Add_Step("the fried face arrived golden, the rest pale", n"Step_AssertSeeded");
        Add_Step_WaitUntil("the piece is in the oil", n"Check_InOil", k_SlowPolls, 0);
        Add_Step("start the clock", n"Step_StartClock");
        Add_Step_WaitUntil("it fried a while", n"Check_Fried", k_SlowPolls, 0);
        Add_Step("move it into the basket", n"Step_MoveToBasket");
        Add_Step_WaitUntil("the piece drained", n"Check_FirstDrained", k_SlowPolls, 0);
        Add_Step("take out every drained piece", n"Step_TakeOut");
        Add_Step_WaitUntil("the take-out was answered and the body reads Kinematic", n"Check_TakenOut", 0, 0);
        Add_Step_WaitFrames("the cook state drains", 2);
        Add_Step("the piece came back with its heat as its batter and its sear untouched", n"Step_AssertTakenOut");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_SeedChannels(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Food = _Pieces[0];
        auto CookState = _Food.Get_CookState();
        CookState.Batter[int32(EMars_Searing_Face::PosZ)] = 1.0f;
        CookState.Sear[int32(EMars_Searing_Face::NegZ)] = 1.0f;
        _Food.Request_SetCookState(FMars_Request_FoodPiece_SetCookState(CookState));
    }

    UFUNCTION()
    private void Step_Release(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Float(_Food.Get_CookState().Batter[int32(EMars_Searing_Face::PosZ)], 1.0, 0.0001, "the piece's +Z is fried before it is released");
        Assert_Equals_Float(_Food.Get_CookState().Sear[int32(EMars_Searing_Face::NegZ)], 1.0, 0.0001, "the piece's -Z is seared before it is released");
        _Piece = AddPiece(FVector(-30.0, 0.0, float64(_Spec.Oil.SurfaceZ) + Get_BoxHalfExtents().Z + 1.0));
    }

    UFUNCTION()
    private void Step_AssertSeeded(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Fry.Get_PieceHandle(_Piece) == _Food, "the fryer holds the piece itself");
        Assert_Equals_Float(_Fry.Get_FaceHeat(_Piece, EMars_Searing_Face::PosZ), 1.0, 0.0001, "the fried +Z arrived with heat 1");
        Assert_True(_Fry.Get_PieceStage(_Piece, EMars_Searing_Face::PosZ) == EMars_Fry_HeatStage::Golden, "the fried +Z is Golden");
        Assert_True(_Fry.Get_FaceHeat(_Piece, EMars_Searing_Face::NegZ) < 0.1f, "the seared -Z arrived pale: a sear is not batter");
        for (int32 Index = 0; Index < utils_searing::k_FaceCount; ++Index)
        {
            const auto Face = EMars_Searing_Face(Index);
            if (Face != EMars_Searing_Face::PosZ)
            { Assert_True(_Fry.Get_FaceHeat(_Piece, Face) < 0.1f, f"face {utils_searing::Get_FaceName(Face)} arrived pale"); }
        }

        Assert_Equals_Int(_Fry.Get_PaleFaceCount(_Piece), 5, "five faces are pale");
    }

    UFUNCTION()
    private void Check_InOil(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Fry.Get_PieceWhereabouts(_Piece) == EMars_Fry_Whereabouts::Oil);
    }

    UFUNCTION()
    private void Step_StartClock(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _InOilTime = Get_Now();
    }

    UFUNCTION()
    private void Check_Fried(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_Now() - _InOilTime >= k_FrySeconds);
    }

    UFUNCTION()
    private void Step_MoveToBasket(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Teleport(_Piece, k_BasketLocal + FVector(0.0, 0.0, Get_BoxHalfExtents().Z + 3.0), FVector::ZeroVector);
    }

    UFUNCTION()
    private void Step_TakeOut(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Fry.Get_PieceDrain(_Piece) == EMars_Fry_Drain::Drained, "the piece is Drained");
        Assert_Equals_Int(_Fry.Get_TakeableCount(), 1, "one piece is takeable");

        // The basket never heats: these are the heats the take-out writes.
        _HeatsAtTakeOut.Empty();
        for (int32 Index = 0; Index < utils_searing::k_FaceCount; ++Index)
        { _HeatsAtTakeOut.Add(_Fry.Get_FaceHeat(_Piece, EMars_Searing_Face(Index))); }

        _Body = _Fry.Get_PieceBody(_Piece);
        _Fry.Request_TakeOut(FMars_Request_Fry_TakeOut());
    }

    UFUNCTION()
    private void Check_TakenOut(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_TakenOut.Num() >= 1 && utils_jolt_body::Get_MotionType(_Body) == ECk_MotionType::Kinematic);
    }

    UFUNCTION()
    private void Step_AssertTakenOut(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_TakenOut.Num(), 1, "OnPieceTakenOut fired once");
        if (_TakenOut.Num() > 0)
        {
            Assert_True(_TakenOutIds[0].Get_IsSame(_Piece), "OnPieceTakenOut names the piece's Id");
            Assert_True(_TakenOut[0] == _Food, "OnPieceTakenOut hands back the piece");
        }

        Assert_False(_Fry.Get_HasPiece(_Piece), "the piece left play");
        Assert_True(ck::IsValid(_Food), "the piece lives on");

        const auto CookState = _Food.Get_CookState();
        Assert_Equals_Int(CookState.Batter.Num(), utils_searing::k_FaceCount, "six batter heats");
        auto HeatSum = 0.0f;
        for (int32 Index = 0; Index < _HeatsAtTakeOut.Num(); ++Index)
        {
            const auto Face = EMars_Searing_Face(Index);
            Assert_Equals_Float(CookState.Batter[Index], _HeatsAtTakeOut[Index], 0.0001,
                f"face {utils_searing::Get_FaceName(Face)}'s batter is its heat");
            HeatSum += _HeatsAtTakeOut[Index];
        }

        const auto Look = utils_cookstate::Make_DisplayParams(CookState);
        Log(f"[Mars_AutoTest_Fry_AdoptedPieceKeepsItsBatterAndItsSearApart] heat sum at the take-out {HeatSum :.3}, fry {Look.Fry :.3}");
        Assert_True(HeatSum > 1.1f, f"the oil heated faces beyond the seeded one (heat sum {HeatSum})");
        Assert_Equals_Float(CookState.Batter[int32(EMars_Searing_Face::PosZ)], 1.0, 0.05, "the fried +Z is still golden");
        Assert_Equals_Float(CookState.Sear[int32(EMars_Searing_Face::NegZ)], 1.0, 0.0001, "the seared -Z keeps its sear");
        Assert_Equals_Float(Look.Fry, HeatSum / float32(utils_searing::k_FaceCount), 0.0001, "its look's fry is the faces' mean heat");

        Assert_Equals_Int(_Fry.Get_Summary().TakenOut, 1, "the summary counts one taken out");
        Assert_Equals_Int(_Fry.Get_TakeableCount(), 0, "nothing is takeable");
    }
}
