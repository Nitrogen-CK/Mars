// A piece teleported into the basket's volume above its walls and flung across it at 700 cm/s (rising a little, so it clears
// the far wall) passes through the basket interior without ever resting on its floor: its whereabouts may read DrainBasket
// on the way through, but its drain never starts (Draining needs the floor's support), OnPieceDrained never fires, and it
// falls on beyond the basket and is lost.
class UMars_AutoTest_Fry_AnAirborneCrossingOfTheBasketDoesNotDrain : UMars_AutoTestRig_Fry
{
    default _TimeoutSeconds = 12.0f;

    // Basket frame: near the -X wall, inside the basket's volume (its interior reaches the piece's height above the wall
    // tops) with the piece's bottom k_CrossBottomAboveWalls above the wall tops; flung toward +X.
    private const float64 k_CrossStartX = -16.0;
    private const float64 k_CrossBottomAboveWalls = 4.0;
    private const FVector k_CrossVelocity = FVector(700.0, 0.0, 60.0);
    private const float32 k_WatchSeconds = 1.5f;

    private FMars_CookingFeed_PieceId _Piece;
    private int32 _EdgesBeforeCross = 0;
    private float32 _CrossTime = 0.0f;
    private bool _SawDraining = false;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        BuildStation(InHandle, Make_TestSpec());
        Build_Pieces(1);

        Add_Step_WaitUntil("the scoop and basket bodies are in the simulation", n"Check_BodiesAdded", 0, 3.0f);
        Add_Step_WaitUntil("the rig's pieces are ready", n"Check_PiecesReady", 0, 3.0f);
        Add_Step("release a piece over the oil", n"Step_Release");
        Add_Step_WaitUntil("its body is in the simulation", n"Check_Added1", 0, 2.0f);
        Add_Step("fling it across the basket", n"Step_Fling");
        Add_Step_WaitUntil("it crossed and fell away", n"Check_Watched", 0, k_WatchSeconds + 1.0f);
        Add_Step("it never drained", n"Step_AssertNeverDrained");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_Release(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Piece = AddPiece(FVector(-30.0, 0.0, float64(_Spec.Oil.SurfaceZ) + Get_BoxHalfExtents().Z + 1.0));
    }

    UFUNCTION()
    private void Step_Fling(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _EdgesBeforeCross = _WhereaboutsTo.Num();
        _CrossTime = Get_Now();
        const auto Start = FVector(k_CrossStartX, 0.0, float64(_Spec.Basket.WallHeight) + k_CrossBottomAboveWalls + _Fry.Get_PieceHalfExtents(_Piece).Z);
        Teleport(_Piece, k_BasketLocal + Start, k_CrossVelocity);
    }

    UFUNCTION()
    private void Check_Watched(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        if (_Fry.Get_HasPiece(_Piece) && _Fry.Get_PieceDrain(_Piece) != EMars_Fry_Drain::NotDraining)
        { _SawDraining = true; }

        auto Res = OutResult;
        Res.Set(Get_Now() - _CrossTime >= k_WatchSeconds);
    }

    UFUNCTION()
    private void Step_AssertNeverDrained(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        TArray<EMars_Fry_Whereabouts> Path;
        const auto Edges = Get_Path(_Piece, _EdgesBeforeCross, Path);
        Log(f"[Mars_AutoTest_Fry_AnAirborneCrossingOfTheBasketDoesNotDrain] crossing: edges{Edges}");
        Assert_True(Path.Contains(EMars_Fry_Whereabouts::DrainBasket), f"the crossing did pass through the basket's volume (edges{Edges})");

        Assert_False(_SawDraining, "the piece never started draining");
        Assert_Equals_Int(Count_Ids(_DrainedIds, _Piece), 0, "OnPieceDrained never fired");
        Assert_True(Path.Num() > 0 && Path.Last() == EMars_Fry_Whereabouts::Lost, f"it flew on past the basket and was lost (edges{Edges})");
    }
}
