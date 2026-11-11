// Nothing in range ends the path out of range. A bare carrier holds a rock with no geometry anywhere near and aims: the
// path ends OutOfRange, has points, and was flown for the Spec's whole MaxFlightSeconds (within 0.06 s).
// Isolated origin (260000, -40000, -30000).
class UMars_AutoTest_ThrowPreview_NothingInRangeEndsOutOfRange : UMars_AutoTestRig_ThrowPreview
{
    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        _Origin = FVector(260000.0, -40000.0, -30000.0);
        Add_CarrierBody(InHandle, _Origin);
        Add_PreviewParts(2);
        _Holders.Add(MakeSeededHolder(InHandle, mars_items::Rock()));

        Add_Step_WaitUntil("the holder holds its rock", n"Check_HoldersSeeded");
        Add_Step("stow the rock into the hands", n"Step_StowFirst");
        Add_Step_WaitUntil("the hands hold it", n"Check_Holding");
        Add_Step("aim", n"Step_Aim");
        Add_Step_WaitUntil("the path has an end", n"Check_PathHasAnEnd", k_SlowPolls);
        Add_Step("the path ran out of range over the whole MaxFlightSeconds", n"Step_AssertOutOfRange");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Check_PathHasAnEnd(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Preview.Get_IsAiming() && _Preview.Get_Path().End != EMars_ThrowPreview_End::None);
    }

    UFUNCTION()
    private void Step_AssertOutOfRange(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Path = _Preview.Get_Path();
        const auto MaxSeconds = FMars_ThrowPreview_Spec().MaxFlightSeconds;
        Log(f"[ThrowPreview] out of range: {Path.Points.Num()} points, flight {Path.FlightSeconds} s of {MaxSeconds} s");

        Assert_True(Path.End == EMars_ThrowPreview_End::OutOfRange, f"the path ends out of range (End {Path.End :n})");
        Assert_True(Math::Abs(Path.FlightSeconds - MaxSeconds) <= 0.06f,
            f"the flight ran for MaxFlightSeconds {MaxSeconds} s (got {Path.FlightSeconds} s)");
        Assert_True(Path.Points.Num() >= 2, f"the path has at least two points (got {Path.Points.Num()})");
    }
}
