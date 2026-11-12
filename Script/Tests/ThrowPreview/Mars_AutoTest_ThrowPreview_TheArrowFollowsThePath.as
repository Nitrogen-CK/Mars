// The arrow follows the path. A bare carrier holds a rock and the throw preview's assembly
// (UMars_ThrowPreview_EntityScript) is spawned with the carrier's preview:
//   - aimed with nothing in range (OutOfRange): within a few frames the ribbon is drawn - at least two points, its length
//     the path's less the 25 cm hand clearance (within 5 cm);
//   - SetAim(Idle): two frames later it draws nothing;
//   - a floor slab 400 cm under the hand, aimed again (Surface): the ribbon as before, except that its last point is the
//     landing on the floor rather than the swept sphere's centre, so its length is measured to the landing;
//   - SetAim(Idle): two frames later it draws nothing.
// The OutOfRange half runs on the same carrier before its floor exists. Under -nullrhi the assembly loads no look (the
// ribbon draws on the engine's default material). Isolated origin (268000, -40000, -30000).
class UMars_AutoTest_ThrowPreview_TheArrowFollowsThePath : UMars_AutoTestRig_ThrowPreview
{
    private const float64 k_HandAboveFloor = 400.0;
    private const float64 k_HandClearance = 25.0;
    private const float64 k_LengthToleranceCm = 5.0;
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
        Add_Step_WaitUntil("within a few frames the ribbon is drawn", n"Check_Drawn", k_FewFrames, 1.0f);
        Add_Step("the ribbon is the path less the hand clearance", n"Step_AssertOutOfRange");
        Add_Step("stop aiming", n"Step_Idle");
        Add_Step_WaitFrames("two frames", 2);
        Add_Step("it draws nothing", n"Step_AssertNothingDrawn");
        Add_Step("a floor slab 400 cm under the hand", n"Step_BuildFloor");
        Add_Step("aim at the floor", n"Step_Aim");
        Add_Step_WaitUntil("the path meets a surface", n"Check_PathMeetsASurface", k_SlowPolls);
        Add_Step_WaitUntil("within a few frames the ribbon is drawn", n"Check_Drawn", k_FewFrames, 1.0f);
        Add_Step("the ribbon runs from the hand clearance to the landing", n"Step_AssertSurface");
        Add_Step("stop aiming", n"Step_Idle");
        Add_Step_WaitFrames("two frames", 2);
        Add_Step("it draws nothing", n"Step_AssertNothingDrawn");
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
        Res.Set(ck::IsValid(_Assembly) && ck::IsValid(_Assembly.Get_Arc()));
    }

    UFUNCTION()
    private void Check_PathOutOfRange(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Preview.Get_IsAiming() && _Preview.Get_Path().End == EMars_ThrowPreview_End::OutOfRange);
    }

    UFUNCTION()
    private void Check_Drawn(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Preview.Get_Path().End != EMars_ThrowPreview_End::None
            && utils_pmg_polyline::Get_NumDrawnPoints(_Assembly.Get_Arc()) >= 2);
    }

    UFUNCTION()
    private void Step_AssertOutOfRange(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Path = _Preview.Get_Path();
        Assert_Drawn(Get_PolylineLength(Path.Points) - k_HandClearance, Path);
    }

    UFUNCTION()
    private void Step_AssertSurface(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        // The ribbon's last point is moved from the swept sphere's centre down onto the landing.
        auto Points = _Preview.Get_Path().Points;
        const auto Path = _Preview.Get_Path();
        Points[Points.Num() - 1] = Path.Landing.Location;
        Assert_Drawn(Get_PolylineLength(Points) - k_HandClearance, Path);
    }

    // The ribbon draws at least two points and is InExpected long.
    private void Assert_Drawn(float64 InExpected, const FMars_ThrowPreview_Path& InPath)
    {
        const auto Drawn = float64(utils_pmg_polyline::Get_DrawnLength(_Assembly.Get_Arc()));
        const auto NumDrawn = utils_pmg_polyline::Get_NumDrawnPoints(_Assembly.Get_Arc());
        Log(f"[ThrowPreview] ribbon ({InPath.End :n}): {NumDrawn} points, drawn length {Drawn} cm against {InExpected} cm");

        Assert_True(NumDrawn >= 2, f"the ribbon draws at least two points (got {NumDrawn})");
        Assert_True(Math::Abs(Drawn - InExpected) <= k_LengthToleranceCm,
            f"the ribbon is {InExpected} cm long, within {k_LengthToleranceCm} cm (got {Drawn} cm)");
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
        Assert_Equals_Int(utils_pmg_polyline::Get_NumDrawnPoints(_Assembly.Get_Arc()), 0, "idle: the ribbon draws nothing");
    }

    UFUNCTION()
    private void Step_BuildFloor(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Hand = Get_HandLocation();
        const auto Top = Hand.Z - k_HandAboveFloor;
        Spawn_StaticSlab(InHandle, FVector(Hand.X + 600.0, Hand.Y, Top - 10.0), FVector(700.0, 300.0, 10.0));
    }
}
