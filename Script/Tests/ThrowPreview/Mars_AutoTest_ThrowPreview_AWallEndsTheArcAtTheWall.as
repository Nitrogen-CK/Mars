// A wall ends the arc at the wall. A bare carrier holds a rock with a Static slab standing 200 cm ahead of the hand and
// aims: the path meets the wall (End Surface, the landing names the wall), its landing normal faces back along the throw
// (+X), and the flight is short (under 0.5 s). Isolated origin (256000, -40000, -30000).
class UMars_AutoTest_ThrowPreview_AWallEndsTheArcAtTheWall : UMars_AutoTestRig_ThrowPreview
{
    private const float64 k_WallAhead = 200.0;

    private FCk_Handle _Wall;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        _Origin = FVector(256000.0, -40000.0, -30000.0);
        Add_CarrierBody(InHandle, _Origin);
        Add_PreviewParts(2);
        _Holders.Add(MakeSeededHolder(InHandle, mars_items::Rock()));

        Add_Step_WaitUntil("the holder holds its rock", n"Check_HoldersSeeded");
        Add_Step("stow the rock into the hands", n"Step_StowFirst");
        Add_Step_WaitUntil("the hands hold it", n"Check_Holding");
        Add_Step("a wall 200 cm ahead of the hand", n"Step_BuildWall");
        Add_Step("aim", n"Step_Aim");
        Add_Step_WaitUntil("the path meets a surface", n"Check_PathMeetsASurface", k_SlowPolls);
        Add_Step("the path ends on the wall's near face, soon", n"Step_AssertWall");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_BuildWall(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Hand = Get_HandLocation();
        _Wall = Spawn_StaticSlab(InHandle, FVector(Hand.X + k_WallAhead + 10.0, Hand.Y, Hand.Z), FVector(10.0, 300.0, 300.0));
    }

    UFUNCTION()
    private void Step_AssertWall(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Path = _Preview.Get_Path();
        Log(f"[ThrowPreview] wall: landing {Path.Landing.Location}, normal {Path.Landing.Normal}, flight {Path.FlightSeconds} s");

        Assert_True(Path.End == EMars_ThrowPreview_End::Surface, f"the path ends on a surface (End {Path.End :n})");
        Assert_True(Path.Landing.Entity == _Wall, "the landing names the wall");

        const auto ThrowDirection = FVector(1.0, 0.0, 0.0);
        const auto Facing = Path.Landing.Normal.DotProduct(ThrowDirection);
        Assert_True(Facing < -0.9, f"the landing normal faces back along the throw (normal . +X = {Facing})");
        Assert_True(Path.FlightSeconds < 0.5f, f"the flight to a wall 200 cm away is short (got {Path.FlightSeconds} s)");
    }
}
