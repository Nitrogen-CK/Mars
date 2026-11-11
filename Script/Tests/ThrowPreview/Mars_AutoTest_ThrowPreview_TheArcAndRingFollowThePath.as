// The arc and the ring follow the path. A bare carrier holds a rock and the throw preview's assembly
// (UMars_ThrowPreview_EntityScript) is spawned with the carrier's preview:
//   - aimed with nothing in range (OutOfRange): within a few frames the arc is drawn - at least two points, its length the
//     path's less the 25 cm hand clearance (within 5 cm) - and the ring draws nothing;
//   - SetAim(Idle): two frames later both draw nothing;
//   - a floor slab 400 cm under the hand, aimed again (Surface): the arc as before, and the ring 33 points long, its length
//     within 2 % of 2 * PI * Max(14, CastRadius * 1.6);
//   - SetAim(Idle): two frames later both draw nothing.
// The OutOfRange half runs on the same carrier before its floor exists. Under -nullrhi the assembly loads no look (the
// polylines draw on the engine's default material). Isolated origin (268000, -40000, -30000).
class UMars_AutoTest_ThrowPreview_TheArcAndRingFollowThePath : UMars_AutoTestRig_ThrowPreview
{
    private const float64 k_HandAboveFloor = 400.0;
    private const float64 k_HandClearance = 25.0;
    private const float64 k_ArcLengthToleranceCm = 5.0;
    private const float64 k_RingLengthTolerance = 0.02;
    private const int32 k_RingPoints = 33;
    private const int32 k_FewFrames = 30;

    private UMars_ThrowPreview_EntityScript _Assembly;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        _Origin = FVector(268000.0, -40000.0, -30000.0);
        Add_CarrierBody(InHandle, _Origin);
        Add_PreviewParts(2);
        _Holders.Add(MakeSeededHolder(InHandle, mars_items::Rock()));

        auto Params = UMars_ThrowPreview_EntityScript::Params();
        Params.Preview = _Preview;
        auto Pending = utils_entity_script::Request_SpawnEntity(InHandle, UMars_ThrowPreview_EntityScript, Params);
        utils_pending_entity_script::Promise_OnConstructed(Pending, FCk_Delegate_EntityScript_Constructed(this, n"OnAssemblyConstructed"));

        Add_Step_WaitUntil("the assembly is constructed", n"Check_AssemblyConstructed");
        Add_Step_WaitUntil("the holder holds its rock", n"Check_HoldersSeeded");
        Add_Step("stow the rock into the hands", n"Step_StowFirst");
        Add_Step_WaitUntil("the hands hold it", n"Check_Holding");
        Add_Step("aim with nothing in range", n"Step_Aim");
        Add_Step_WaitUntil("the path runs out of range", n"Check_PathOutOfRange", k_SlowPolls);
        Add_Step_WaitUntil("within a few frames the arc is drawn", n"Check_OutOfRangeDrawn", k_FewFrames, 1.0f);
        Add_Step("the arc is the path less the hand clearance; no ring", n"Step_AssertOutOfRange");
        Add_Step("stop aiming", n"Step_Idle");
        Add_Step_WaitFrames("two frames", 2);
        Add_Step("both draw nothing", n"Step_AssertNothingDrawn");
        Add_Step("a floor slab 400 cm under the hand", n"Step_BuildFloor");
        Add_Step("aim at the floor", n"Step_Aim");
        Add_Step_WaitUntil("the path meets a surface", n"Check_PathMeetsASurface", k_SlowPolls);
        Add_Step_WaitUntil("within a few frames the arc and the ring are drawn", n"Check_SurfaceDrawn", k_FewFrames, 1.0f);
        Add_Step("the arc is the path less the hand clearance; the ring circles the landing", n"Step_AssertSurface");
        Add_Step("stop aiming", n"Step_Idle");
        Add_Step_WaitFrames("two frames", 2);
        Add_Step("both draw nothing", n"Step_AssertNothingDrawn");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void OnAssemblyConstructed(FCk_Handle_EntityScript InEntityScriptHandle)
    {
        FCk_Handle Entity = InEntityScriptHandle;
        _Assembly = Cast<UMars_ThrowPreview_EntityScript>(utils_entity_script::TryGet_EntityScript(Entity));
    }

    UFUNCTION()
    private void Check_AssemblyConstructed(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(ck::IsValid(_Assembly) && ck::IsValid(_Assembly.Get_Arc()) && ck::IsValid(_Assembly.Get_Ring()));
    }

    UFUNCTION()
    private void Check_PathOutOfRange(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Preview.Get_IsAiming() && _Preview.Get_Path().End == EMars_ThrowPreview_End::OutOfRange);
    }

    UFUNCTION()
    private void Check_OutOfRangeDrawn(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Preview.Get_Path().End == EMars_ThrowPreview_End::OutOfRange
            && utils_pmg_polyline::Get_NumDrawnPoints(_Assembly.Get_Arc()) >= 2);
    }

    UFUNCTION()
    private void Check_SurfaceDrawn(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Preview.Get_Path().End == EMars_ThrowPreview_End::Surface
            && utils_pmg_polyline::Get_NumDrawnPoints(_Assembly.Get_Arc()) >= 2
            && utils_pmg_polyline::Get_NumDrawnPoints(_Assembly.Get_Ring()) == k_RingPoints);
    }

    UFUNCTION()
    private void Step_AssertOutOfRange(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Arc();
        Assert_Equals_Int(utils_pmg_polyline::Get_NumDrawnPoints(_Assembly.Get_Ring()), 0, "out of range: the ring draws nothing");
    }

    UFUNCTION()
    private void Step_AssertSurface(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Arc();

        const auto Path = _Preview.Get_Path();
        const auto Radius = Math::Max(14.0, float64(Path.CastRadius) * 1.6);
        const auto Expected = 2.0 * PI * Radius;
        const auto Drawn = float64(utils_pmg_polyline::Get_DrawnLength(_Assembly.Get_Ring()));
        Log(f"[ThrowPreview] ring: {utils_pmg_polyline::Get_NumDrawnPoints(_Assembly.Get_Ring())} points, drawn length {Drawn} cm against 2 PI R {Expected} cm (R {Radius} cm)");

        Assert_Equals_Int(utils_pmg_polyline::Get_NumDrawnPoints(_Assembly.Get_Ring()), k_RingPoints, "the ring draws 33 points");
        Assert_True(Math::Abs(Drawn - Expected) <= Expected * k_RingLengthTolerance,
            f"the ring's length is within 2 % of 2 PI x {Radius} = {Expected} cm (got {Drawn} cm)");
    }

    // The arc draws at least two points and is the path's length less the hand clearance.
    private void Assert_Arc()
    {
        const auto Path = _Preview.Get_Path();
        const auto Expected = Get_PolylineLength(Path.Points) - k_HandClearance;
        const auto Drawn = float64(utils_pmg_polyline::Get_DrawnLength(_Assembly.Get_Arc()));
        const auto NumDrawn = utils_pmg_polyline::Get_NumDrawnPoints(_Assembly.Get_Arc());
        Log(f"[ThrowPreview] arc ({Path.End :n}): {NumDrawn} points, drawn length {Drawn} cm against path less clearance {Expected} cm");

        Assert_True(NumDrawn >= 2, f"the arc draws at least two points (got {NumDrawn})");
        Assert_True(Math::Abs(Drawn - Expected) <= k_ArcLengthToleranceCm,
            f"the arc is the path less {k_HandClearance} cm, within {k_ArcLengthToleranceCm} cm: {Expected} cm (got {Drawn} cm)");
    }

    UFUNCTION()
    private void Step_Idle(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Preview.Request_SetAim(FMars_Request_ThrowPreview_SetAim(EMars_ThrowPreview_Aim::Idle));
    }

    UFUNCTION()
    private void Step_AssertNothingDrawn(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_False(_Preview.Get_IsAiming(), "not aiming");
        Assert_Equals_Int(utils_pmg_polyline::Get_NumDrawnPoints(_Assembly.Get_Arc()), 0, "idle: the arc draws nothing");
        Assert_Equals_Int(utils_pmg_polyline::Get_NumDrawnPoints(_Assembly.Get_Ring()), 0, "idle: the ring draws nothing");
    }

    UFUNCTION()
    private void Step_BuildFloor(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Hand = Get_HandLocation();
        const auto Top = Hand.Z - k_HandAboveFloor;
        Spawn_StaticSlab(InHandle, FVector(Hand.X + 600.0, Hand.Y, Top - 10.0), FVector(700.0, 300.0, 10.0));
    }
}
