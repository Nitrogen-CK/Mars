// A readopted piece is announced again, so the placing script dresses it again. A piece lands on the pan (OnPieceAdded
// once, with its admission); a TakeOut naming it, with no tray, hands it back (off the books, no holder, Kinematic). The
// kernel is then asked to readopt it under its own id: it is on the pan's books again, the station its holder, its body
// Dynamic, the take-out no longer counted, and OnPieceAdded fires a second time for that id with the piece's entity. No
// second admission answer: nobody awaits one.
class UMars_AutoTest_Searing_AReadoptedPieceIsAnnouncedAgain : UMars_AutoTestRig_Searing
{
    default _TimeoutSeconds = 20.0f;

    private FMars_CookingFeed_PieceId _PieceId;
    private FCk_Handle_FoodPiece _Piece;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        BuildStation(InHandle, Make_TestSpec());
        Build_Pieces(1);

        Add_Steps_AddPieceAndLand();
        Add_Step("take the piece out by name, with no tray", n"Step_TakeOut");
        Add_Step_WaitUntil("the pan handed it back", n"Check_HandedBack", 0, 0);
        Add_Step("it is off the books; readopt it", n"Step_AssertHandedBackAndReadopt");
        Add_Step_WaitUntil("it is on the pan's books again, its body Dynamic", n"Check_Readopted", k_SlowPolls, 0);
        Add_Step("OnPieceAdded announced it again", n"Step_AssertAnnouncedAgain");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_TakeOut(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _PieceId = Get_FirstId();
        _Piece = _Searing.Get_PieceHandle(_PieceId);
        Assert_Equals_Int(_AddedIds.Num(), 1, "the admission announced the piece once");
        _Searing.Request_TakeOut(FMars_Request_Searing_TakeOut(TOptional<FCk_Handle_FoodPiece>(_Piece), TOptional<int32>()));
    }

    UFUNCTION()
    private void Check_HandedBack(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_TakenOut.Num() >= 1 && _Searing.Get_HasPiece(_PieceId) == false);
    }

    UFUNCTION()
    private void Step_AssertHandedBackAndReadopt(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_TakenOut.Num() == 1 && _TakenOut[0] == _Piece, "the take-out handed the named piece back");
        Assert_False(ck::IsValid(_Piece.TryGet_Holder()), "the handed-back piece has no holder");
        Assert_Equals_Int(_Searing.Get_Summary().TakenOut, 1, "the summary counts it taken out");

        _Searing.Request_Readopt(FMars_Request_Searing_Readopt(_PieceId, _Piece));
    }

    UFUNCTION()
    private void Check_Readopted(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        if (_Searing.Get_HasPiece(_PieceId) == false)
        {
            Res.Set(false);
            return;
        }

        Res.Set(utils_jolt_body::Get_MotionType(_Searing.Get_PieceBody(_PieceId)) == ECk_MotionType::Dynamic);
    }

    UFUNCTION()
    private void Step_AssertAnnouncedAgain(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_AddedIds.Num(), 2, "OnPieceAdded fired twice: the admission and the readopt");
        if (_AddedIds.Num() == 2)
        {
            Assert_True(_AddedIds[1].Get_IsSame(_PieceId), "the second OnPieceAdded names the readopted id");
            FCk_Handle Entity = _Piece;
            Assert_True(_Added[1] == Entity, "the second OnPieceAdded carries the piece's entity");
        }

        Assert_Equals_Int(_Admissions.Num(), 1, "the readopt sends no admission answer");
        Assert_True(_Piece.TryGet_Holder() == _StationEntity, "the station is its holder again");
        Assert_True(_Searing.Get_PieceHandle(_PieceId) == _Piece, "the books hold the piece under its own id");
        Assert_Equals_Int(_Searing.Get_Summary().TakenOut, 0, "the take-out it undid no longer counts");
    }
}

class AMars_AutoTest_Searing_AReadoptedPieceIsAnnouncedAgain_Actor : AMars_AutoTestRunner_SearingPan
{
    default _TimeoutSeconds = 20.0f;
    default _TestEntityScriptClass = UMars_AutoTest_Searing_AReadoptedPieceIsAnnouncedAgain;
}
