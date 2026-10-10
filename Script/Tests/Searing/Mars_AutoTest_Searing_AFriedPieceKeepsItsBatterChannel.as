// Sear and batter are separate channels of a piece's cook state: the pan never reads a fried face as seared, and never
// clamps the batter. A piece fried overdone all round (batter 2 on every face, no sear) is released onto the cold pan: it
// lands Cooking, not Ready, with every face's sear 0. Taken out by name, it comes back with its batter still 2 on every
// face and its sears the pan's (all 0 on a cold pan).
class UMars_AutoTest_Searing_AFriedPieceKeepsItsBatterChannel : UMars_AutoTestRig_Searing
{
    default _TimeoutSeconds = 10.0f;

    private const float32 k_Overdone = 2.0f;
    private const float32 k_Tolerance = 0.0001f;

    private FCk_Handle_FoodPiece _Piece;
    private FMars_CookingFeed_PieceId _PieceId;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        BuildStation(InHandle, Make_TestSpec());
        Build_Pieces(1);

        Add_Step_WaitUntil("the pan body is in the simulation", n"Check_PanBodyAdded", k_SlowPolls, 0);
        Add_Step_WaitUntil("the rig's pieces are ready", n"Check_PiecesReady", k_SlowPolls, 0);
        Add_Step("fry the piece overdone all round", n"Step_FryAllRound");
        Add_Step_WaitUntil("the cook state is on the ledger", n"Check_Fried", 0, 0);
        Add_Step("release it over the cold pan", n"Step_Release");
        Add_Step_WaitUntil("the piece landed on the pan", n"Check_FirstOnPan", k_SlowPolls, 0);
        Add_Step("it is not Ready and nothing is seared", n"Step_AssertNotSeared");
        Add_Step("take it out by name", n"Step_TakeOut");
        Add_Step_WaitUntil("the pan handed it back", n"Check_TakenOut", 0, 0);
        Add_Step_WaitFrames("the cook state drains", 2);
        Add_Step("its batter is still overdone, its sears the pan's", n"Step_AssertChannels");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_FryAllRound(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Piece = _Pieces[0];
        auto CookState = _Piece.Get_CookState();
        for (int32 Index = 0; Index < CookState.Batter.Num(); ++Index)
        { CookState.Batter[Index] = k_Overdone; }

        _Piece.Request_SetCookState(FMars_Request_FoodPiece_SetCookState(CookState));
    }

    UFUNCTION()
    private void Check_Fried(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Piece.Get_CookState().Batter[0] == k_Overdone);
    }

    UFUNCTION()
    private void Step_Release(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _PieceId = AddPiece();
    }

    UFUNCTION()
    private void Step_AssertNotSeared(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Searing.Get_PieceHandle(_PieceId) == _Piece, "the pan holds the fried piece");
        Assert_True(_Searing.Get_PieceStatus(_PieceId) == EMars_Searing_PieceStatus::Cooking, "a fried piece is not Ready on the pan");
        for (int32 Index = 0; Index < utils_searing::k_FaceCount; ++Index)
        {
            const auto Face = EMars_Searing_Face(Index);
            Assert_Equals_Float(_Searing.Get_FaceSear(_PieceId, Face), 0.0f, k_Tolerance, f"face {utils_searing::Get_FaceName(Face)} arrived unseared");
        }
    }

    UFUNCTION()
    private void Step_TakeOut(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Searing.Request_TakeOut(FMars_Request_Searing_TakeOut(TOptional<FCk_Handle_FoodPiece>(_Piece), TOptional<int32>()));
    }

    UFUNCTION()
    private void Check_TakenOut(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Searing.Get_HasPiece(_PieceId) == false);
    }

    UFUNCTION()
    private void Step_AssertChannels(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto CookState = _Piece.Get_CookState();
        for (int32 Index = 0; Index < utils_searing::k_FaceCount; ++Index)
        {
            const auto Face = EMars_Searing_Face(Index);
            Assert_Equals_Float(CookState.Batter[Index], k_Overdone, k_Tolerance, f"face {utils_searing::Get_FaceName(Face)} keeps its batter");
            Assert_Equals_Float(CookState.Sear[Index], 0.0f, k_Tolerance, f"face {utils_searing::Get_FaceName(Face)}'s sear is the cold pan's");
        }
    }
}

class AMars_AutoTest_Searing_AFriedPieceKeepsItsBatterChannel_Actor : AMars_AutoTestRunner_SearingPan
{
    default _TimeoutSeconds = 10.0f;
    default _TestEntityScriptClass = UMars_AutoTest_Searing_AFriedPieceKeepsItsBatterChannel;
}
