// The oil the basket leaves on a piece is ledger state the fryer writes as it hands the piece back: its sheen at the next
// station. A raw piece released over the basket drains there; an unnamed TakeOut hands it back, and its own cook state
// carries the oil coat of the fryer's spec (Receiver.DrainedOilCoat), within 0.0001, where it had none.
class UMars_AutoTest_Fry_TakeOutWritesOilCoat : UMars_AutoTestRig_Fry
{
    default _TimeoutSeconds = 20.0f;

    private const float32 k_Tolerance = 0.0001f;

    private FCk_Handle_FoodPiece _Food;
    private FMars_CookingFeed_PieceId _Piece;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        BuildStation(InHandle, Make_TestSpec());
        Build_Pieces(1);

        Add_Step_WaitUntil("the scoop and basket bodies are in the simulation", n"Check_BodiesAdded", 0, 0);
        Add_Step_WaitUntil("the rig's pieces are ready", n"Check_PiecesReady", 0, 0);
        Add_Step("release the piece over the basket", n"Step_Release");
        Add_Step_WaitUntil("the piece drained", n"Check_FirstDrained", k_SlowPolls, 0);
        Add_Step("take out every drained piece", n"Step_TakeOut");
        Add_Step_WaitUntil("the take-out was answered", n"Check_TakenOut", 0, 0);
        Add_Step_WaitFrames("the cook state drains", 2);
        Add_Step("the piece's cook state carries the drained oil coat", n"Step_AssertOilCoat");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_Release(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Food = _Pieces[0];
        Assert_Equals_Float(_Food.Get_CookState().OilCoat, 0.0f, k_Tolerance, "the raw piece carries no oil coat");
        _Piece = AddPiece(k_BasketLocal + FVector(0.0, 0.0, Get_BoxHalfExtents().Z + 3.0));
    }

    UFUNCTION()
    private void Step_TakeOut(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Fry.Request_TakeOut(FMars_Request_Fry_TakeOut());
    }

    UFUNCTION()
    private void Check_TakenOut(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_TakenOut.Num() >= 1);
    }

    UFUNCTION()
    private void Step_AssertOilCoat(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_TakenOut.Num() == 1 && _TakenOut[0] == _Food, "the fryer handed the piece back");
        Assert_Equals_Float(_Food.Get_CookState().OilCoat, _Spec.Receiver.DrainedOilCoat, k_Tolerance,
            f"the piece's oil coat is the fryer's drained coat [{_Spec.Receiver.DrainedOilCoat}]");
    }
}
