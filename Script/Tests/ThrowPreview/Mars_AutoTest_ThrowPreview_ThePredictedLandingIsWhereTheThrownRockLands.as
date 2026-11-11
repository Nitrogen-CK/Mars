// The predicted landing is where the thrown rock really lands. A bare carrier holds a rock 400 cm above a 1400 cm Static
// floor slab and aims; once the path meets the floor its landing is kept and the rock is thrown with the held item's real
// throw. The rock's first Jolt contact is within 30 cm of the predicted landing, the landing is at least 600 cm from the
// hand horizontally, on the slab's upward face, and every frame of the real flight keeps the rock's bounds centre within
// 12 cm of the predicted path. The measured numbers are logged. Isolated origin (244000, -40000, -30000).
class UMars_AutoTest_ThrowPreview_ThePredictedLandingIsWhereTheThrownRockLands : UMars_AutoTestRig_ThrowPreview
{
    private const float64 k_HandAboveFloor = 400.0;
    private const float64 k_MaxLandingErrorCm = 30.0;
    private const float64 k_MaxFlightErrorCm = 12.0;
    private const float64 k_MinThrowDistanceCm = 600.0;

    private FCk_Handle _Floor;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        _Origin = FVector(244000.0, -40000.0, -30000.0);
        Add_CarrierBody(InHandle, _Origin);
        Add_PreviewParts(2);
        _Holders.Add(MakeSeededHolder(InHandle, mars_items::Rock()));

        Add_Step_WaitUntil("the holder holds its rock", n"Check_HoldersSeeded");
        Add_Step("stow the rock into the hands", n"Step_StowFirst");
        Add_Step_WaitUntil("the hands hold it", n"Check_Holding");
        Add_Step("a 1400 cm floor slab 400 cm under the hand", n"Step_BuildFloor");
        Add_Step("aim", n"Step_Aim");
        Add_Step_WaitUntil("the path meets a surface", n"Check_PathMeetsASurface", k_SlowPolls);
        Add_Step("keep the landing: on the floor's top, far enough out; throw", n"Step_AssertLandingAndThrow");
        Add_Step_WaitUntil("the thrown rock touches something", n"Check_FlightLanded", k_SlowPolls);
        Add_Step("it landed where predicted and flew along the path", n"Step_AssertFlight");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_BuildFloor(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Hand = Get_HandLocation();
        const auto Top = Hand.Z - k_HandAboveFloor;
        _Floor = Spawn_StaticSlab(InHandle, FVector(Hand.X + 600.0, Hand.Y, Top - 10.0), FVector(700.0, 300.0, 10.0));
    }

    UFUNCTION()
    private void Step_AssertLandingAndThrow(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Keep_PredictedPath();
        const auto Landing = _Predicted.Landing;
        Assert_True(Landing.Entity == _Floor, "the landing names the floor slab");
        Assert_True(Landing.Normal.Z > 0.99, f"the landing is on the slab's upward face (normal {Landing.Normal})");

        const auto Distance = (Landing.Location - _HandAtPrediction).Size2D();
        Assert_True(Distance >= k_MinThrowDistanceCm,
            f"the landing is at least {k_MinThrowDistanceCm} cm from the hand horizontally (got {Distance} cm)");
        Assert_True(_Predicted.Points.Num() >= 2, f"the path has points (got {_Predicted.Points.Num()})");

        _Use.Request_Throw(FMars_Request_HeldItemUse_Throw());
    }

    UFUNCTION()
    private void Step_AssertFlight(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Log_Flight("rock");

        Assert_True(_LandingErrorCm >= 0.0, "the first contact carries a contact point");
        Assert_True(_LandingErrorCm <= k_MaxLandingErrorCm,
            f"the rock's first contact is within {k_MaxLandingErrorCm} cm of the predicted landing (got {_LandingErrorCm} cm at {_ContactPoint})");
        Assert_True(_FlightSamples > 10, f"the flight was sampled every frame (got {_FlightSamples} samples)");
        Assert_True(_MaxFlightErrorCm <= k_MaxFlightErrorCm,
            f"every sampled bounds centre is within {k_MaxFlightErrorCm} cm of the predicted path (worst {_MaxFlightErrorCm} cm)");
    }
}
