// A piece sourced from a docked platter sears a face through on the hot pan. A meat box loaded onto the raw platter the
// kernel's way gets its body from the platter's drop (utils_foodpiece::Add_Body) and keeps it onto the pan: one add-food
// press releases it there. The operated pan is hot and nothing tilts it, so the box rests on it and its down face sears at
// one face per Cook.SecondsPerFace: a face is seared through within three faces' time of the admission.
class UMars_AutoTest_SearingStation_APlatterSourcedPieceSearsAFaceThrough : UMars_AutoTestRig_HeatStation
{
    private const FVector k_Origin = FVector(42000.0, -12000.0, -30000.0);
    private const FVector k_RawOffset = FVector(0.0, -300.0, 0.0);
    // A poll budget, not a ceiling: platters construct, drop and settle over seconds.
    private const int32 k_SlowPolls = 900;
    // One face's time on the hot pan sears a face through; the other two cover the box's drop from the release node and
    // its settle flat on the pan.
    private const float32 k_SearThroughFaces = 3.0f;

    private FCk_Handle _Raw;
    private FCk_Handle_FoodPiece _Box;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Spawn_Searing(InHandle, k_Origin, FMars_CookingFeed_TimingSpec());
        _Raw = Spawn_Platter(InHandle, k_RawOffset, nullptr);
        _Box = Build_Box(FTransform(FRotator::ZeroRotator, _Origin + k_RawOffset + FVector(0.0, 0.0, 60.0)), GameplayTags::Food_Meat_Beef);

        // The station spawns with the spawn params' Searing spec.
        const auto SecondsPerFace = UMars_SearingStation_EntityScript::Params().Searing.Cook.SecondsPerFace;

        Add_Step_WaitUntil("the station composed its Searing, feed and docks, and the pan body exists", n"Check_StationReady", k_SlowPolls, 0);
        Add_Step_WaitUntil("the raw platter is constructed and the box is Ready", n"Check_PlatterAndBoxReady", k_SlowPolls, 0);
        Add_Step("load the box onto the raw platter", n"Step_LoadBox");
        Add_Step_WaitUntil("the box landed on the raw platter", n"Check_BoxLanded", k_SlowPolls, 0);
        Add_Step("dock the raw platter", n"Step_Dock");
        Add_Step_WaitUntil("the raw platter is docked and arrived", n"Check_Docked", k_SlowPolls, 0);
        Add_Step("an operator takes the station", n"Step_Take");
        Add_Step_WaitUntil("the station is Operated and the feed draws from the raw platter", n"Check_OperatedAndSourced", 0, 0);
        Add_Step("one add-food press", n"Step_BeginTransfer");
        Add_Step_WaitUntil("the pan admitted the box", n"Check_Admitted", k_SlowPolls, 0);
        Add_Step("the hot pan holds the box", n"Step_AssertAdmitted");
        Add_Step_WaitUntil("a face of the box seared through within three faces' time", n"Check_FaceSearedThrough", 0, k_SearThroughFaces * SecondsPerFace);
        Add_Step("the box's seared face", n"Step_AssertSeared");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Check_PlatterAndBoxReady(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_IsPlatterReady(_Raw, 0) && _Box.Get_Status() == EMars_FoodPiece_Status::Ready);
    }

    UFUNCTION()
    private void Step_LoadBox(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Raw = _Raw.As_Platter();
        Raw.Request_Load(FMars_Request_Platter_Load(_Box));
    }

    UFUNCTION()
    private void Check_BoxLanded(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_IsPlatterReady(_Raw, 1));
    }

    UFUNCTION()
    private void Step_Dock(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        FCk_Handle BoxEntity = _Box;
        Assert_True(BoxEntity.Is_JoltBody(), "the platter's drop gave the box its body");
        Dock(_InputDock, _Raw);
    }

    UFUNCTION()
    private void Check_Docked(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_IsDocked(_InputDock, _Raw));
    }

    UFUNCTION()
    private void Check_OperatedAndSourced(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_IsOperated() && _Feed.Get_Source() == _Raw.As_Platter() && _Feed.Get_Available() == 1);
    }

    UFUNCTION()
    private void Check_Admitted(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_PieceIds().Num() == 1 && _Raw.As_Platter().Get_Occupancy() == 0);
    }

    UFUNCTION()
    private void Step_AssertAdmitted(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(Get_PieceHandle(Get_PieceIds()[0]) == _Box, "the pan holds the box from the raw platter");
        Assert_True(_Searing.Get_IsHot(), "the operator heated the pan");
    }

    UFUNCTION()
    private void Check_FaceSearedThrough(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto PieceIds = Get_PieceIds();
        auto Res = OutResult;
        Res.Set(PieceIds.Num() == 1 && _Searing.Get_SearedFaceCount(PieceIds[0]) >= 1);
    }

    UFUNCTION()
    private void Step_AssertSeared(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto PieceId = Get_PieceIds()[0];
        Assert_Equals_Int(_Searing.Get_SearedFaceCount(PieceId), 1, "one face is seared through");
        Assert_True(_Searing.Get_PieceStatus(PieceId) == EMars_Searing_PieceStatus::Cooking, "the box is still cooking its other faces");
    }
}

class AMars_AutoTest_SearingStation_APlatterSourcedPieceSearsAFaceThrough_Actor : AMars_AutoTestRunner_SearingPan
{
    default _TimeoutSeconds = 30.0f;
    default _TestEntityScriptClass = UMars_AutoTest_SearingStation_APlatterSourcedPieceSearsAFaceThrough;
}
