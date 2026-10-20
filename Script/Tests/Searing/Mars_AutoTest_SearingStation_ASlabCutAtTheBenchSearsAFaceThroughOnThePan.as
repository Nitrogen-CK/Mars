// The bench-to-pan path a player takes, through both real stations. At the cutting station the meat slab is fed from the
// input platter, chopped once at the board's centre and swept onto the finished tray: two dressed halves. That tray is
// docked as the raw platter of a searing station beside it (its input dock takes meat, cut or whole); an operator takes
// the pan and one add-food press releases a half onto it. The pan admits the half itself (cut, beef, its food the slab's,
// wearing the display the bench dressed it with), with its own half extents; the operated pan is hot, the half rests on
// it and a face sears through, and that face's slot in the half's display (cook-state Custom Primitive Data 0..5) reaches
// the full crust, 1.0, as the old cube's did. Isolated origins: the bench at (56000, -30000, -30000), the pan 700 uu to
// its +Y.
class UMars_AutoTest_SearingStation_ASlabCutAtTheBenchSearsAFaceThroughOnThePan : UMars_AutoTestRig_CuttingStation
{
    default _TimeoutSeconds = 60.0f;

    private const FVector k_Origin = FVector(56000.0, -30000.0, -30000.0);
    private const FVector k_PanOffset = FVector(0.0, 700.0, 0.0);
    // A seared face's display slot is the crust, within the float's own rounding.
    private const float32 k_FullCrust = 0.999f;

    private UMars_AutoTestHelper_HeatStation _PanFixture;
    private FCk_Handle_Station _PanStation;
    private FCk_Handle_Searing _Searing;
    private FCk_Handle_CookingFeed _PanFeed;
    private FCk_Handle_PlatterDock _PanInputDock;
    private FCk_Handle_Operator _Cook;

    private FCk_Handle_FoodPiece _Half;
    private FMars_CookingFeed_PieceId _HalfId;
    private EMars_FoodPiece_Face _SearedFace = EMars_FoodPiece_Face::NegZ;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Spawn_Station(InHandle, k_Origin);
        Spawn_InputPlatter(InHandle, mars_items::Food_MeatSlab());
        Spawn_OutputPlatter(InHandle);

        _PanFixture = Cast<UMars_AutoTestHelper_HeatStation>(NewObject(this, UMars_AutoTestHelper_HeatStation));
        auto Pending = _PanFixture.Spawn_Searing(InHandle, k_Origin + k_PanOffset, FMars_CookingFeed_TimingSpec());
        utils_pending_entity_script::Promise_OnConstructed(Pending, FCk_Delegate_EntityScript_Constructed(this, n"OnPanConstructed"));
        auto CookEntity = utils_entity_lifetime::Request_CreateEntity(InHandle);
        _Cook = utils_operator::Add(CookEntity);

        Add_Step_WaitUntil("the empty tray is constructed", n"Check_OutputPlatterReady", k_SlowPolls, 0);
        Add_Steps_FeedTheJoint();
        Add_Step("dock the tray at the bench", n"Step_DockOutput");
        Add_Step_WaitUntil("the tray is docked at the bench", n"Check_OutputDocked", k_SlowPolls, 0);
        Add_Step("chop at the board's centre", n"Step_Chop");
        Add_Step_WaitUntil("the cut committed and both halves are shown", n"Check_TwoShown", k_SlowPolls, 0);
        Add_Step("sweep the halves onto the tray", n"Step_Sweep");
        Add_Step_WaitUntil("both halves landed on the tray", n"Check_TwoOnTray", k_SlowPolls, 0);
        Add_Step_WaitUntil("the searing station composed its Searing, feed and docks, and its pan body exists", n"Check_PanReady", k_SlowPolls, 0);
        Add_Step("dock the tray of halves as the pan's raw platter", n"Step_DockAtThePan");
        Add_Step_WaitUntil("the tray is docked at the pan", n"Check_DockedAtThePan", k_SlowPolls, 0);
        Add_Step("a cook takes the pan", n"Step_TakeThePan");
        Add_Step_WaitUntil("the pan is Operated and its feed draws the two halves", n"Check_PanOperatedAndSourced", k_SlowPolls, 0);
        Add_Step("one add-food press", n"Step_PressAddFoodAtThePan");
        Add_Step_WaitUntil("the pan admitted a half", n"Check_Admitted", k_SlowPolls, 0);
        Add_Step("the pan holds the dressed half with its own extents", n"Step_AssertAdmitted");
        Add_Step_WaitUntil("a face of the half seared through", n"Check_FaceSearedThrough", k_SlowPolls, 0);
        Add_Step("note the seared face", n"Step_NoteSearedFace");
        Add_Step_WaitUntil("the half's display shows that face's full crust", n"Check_DisplayShowsTheCrust", k_SlowPolls, 0);
        Add_Step("the seared face reads 1.0 on the half's display", n"Step_AssertDisplay");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void OnPanConstructed(FCk_Handle_EntityScript InEntityScriptHandle)
    {
        // Outside the test's own lifetime subtree: the runner's cascade would leave the station alive into later tests.
        Track_ForCleanup(InEntityScriptHandle);
        _PanStation = InEntityScriptHandle.As_Station();
        _Searing = InEntityScriptHandle.As_Searing();
        _PanFeed = InEntityScriptHandle.As_CookingFeed();
        _PanInputDock = utils_platter_dock::Find_OnStation(InEntityScriptHandle, EMars_PlatterDock_Role::Input);
    }

    UFUNCTION()
    private void Step_Chop(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Chop();
    }

    // A chop that issued nothing settles at once so the assertions report it.
    UFUNCTION()
    private void Check_TwoShown(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set((_Issues.Num() > 0 && _Issues[0].Issued == 0) || (_PieceCuts >= 1 && _Board.Get_HeldCount() == 2 && Get_AllHeldShown()));
    }

    UFUNCTION()
    private void Check_TwoOnTray(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_OutputPlatter.Get_HeldCount() == 2);
    }

    UFUNCTION()
    private void Check_PanReady(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_PanFixture.Get_IsStationReady(_PanStation));
    }

    UFUNCTION()
    private void Step_DockAtThePan(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_PieceCuts, 1, "the bench cut the slab once");
        for (const auto& Half : _OutputPlatter.Get_Held())
        { Assert_False(Half.Get_IsWhole(), f"[{Half.ToString()}] on the tray is a cut half"); }

        const auto Refusal = utils_platter_dock::Get_Refusal(_PanInputDock.Get_Spec(), _OutputPlatter);
        Assert_False(Refusal.IsSet(), "the pan's raw platter dock takes a tray of cut meat");
        // Straight from the bench's finished-tray dock (its item lives in that dock's inventory now).
        _PanInputDock.Request_Dock(FMars_Request_PlatterDock_Dock(_OutputDock.Get_Item()));
    }

    UFUNCTION()
    private void Check_DockedAtThePan(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto Tray = _PanInputDock.Get_Platter();
        auto Res = OutResult;
        Res.Set(ck::IsValid(Tray) && Get_HasArrived(Tray) && _PanInputDock.Get_HasArrived() && Tray.Get_HeldCount() == 2);
    }

    UFUNCTION()
    private void Step_TakeThePan(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _PanStation.Request_Reserve(FMars_Request_Station_Reserve(_Cook));
    }

    UFUNCTION()
    private void Check_PanOperatedAndSourced(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_PanFixture.Get_IsOperated(_PanStation, EMars_AutoTest_HeatStation::Searing)
            && _PanFeed.Get_Source() == _PanInputDock.Get_Platter() && _PanFeed.Get_Available() == 2 && _PanFeed.Get_IsSettling() == false);
    }

    UFUNCTION()
    private void Step_PressAddFoodAtThePan(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _PanFeed.Request_BeginTransfer(FMars_Request_CookingFeed_BeginTransfer());
    }

    UFUNCTION()
    private void Check_Admitted(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Searing.Get_PieceIds().Num() == 1);
    }

    UFUNCTION()
    private void Step_AssertAdmitted(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _HalfId = _Searing.Get_PieceIds()[0];
        _Half = _Searing.Get_PieceHandle(_HalfId);
        Assert_True(ck::IsValid(_Half), "the pan holds a food piece");
        if (ck::Is_NOT_Valid(_Half))
        { return; }

        Assert_False(_Half.Get_IsWhole(), "the pan holds a cut half");
        Assert_True(_Half.Get_Kind().HasTag(GameplayTags::Food_Meat_Beef), "the half is the slab's beef");
        Assert_True(_Half.Get_Definition().Get() == mars::Food_MeatSlab_Mars, "the half's food is the slab's");
        Assert_True(Get_IsShown(_Half), "the half wears the display the bench dressed it with");
        Assert_True(_Searing.Get_IsHot(), "the cook heated the pan");

        const auto HalfExtents = _Searing.Get_PieceHalfExtents(_HalfId);
        const auto Expected = utils_foodpiece::Get_BoundsHalfExtents(utils_runtime_mesh::Get_Metrics(_Half.Get_Geometry()));
        ck::Trace(f"[SearingStation] bench half admitted with half extents {HalfExtents}");
        Assert_True((HalfExtents - Expected).Size() < 0.01, f"the pan reads the half's own extents {HalfExtents} (its bounds {Expected})");
        Assert_True(HalfExtents.X < 12.0 || HalfExtents.Y < 12.0, f"one axis is about half the slab's 36.6 cm long axis ({HalfExtents})");
    }

    UFUNCTION()
    private void Check_FaceSearedThrough(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Searing.Get_HasPiece(_HalfId) == false || _Searing.Get_SearedFaceCount(_HalfId) >= 1);
    }

    UFUNCTION()
    private void Step_NoteSearedFace(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Searing.Get_HasPiece(_HalfId), "the pan still holds the half");
        Assert_True(_Searing.Get_PieceStatus(_HalfId) != EMars_Searing_PieceStatus::Lost, "the half was not lost");
        for (int32 Index = 0; Index < utils_searing::k_FaceCount; ++Index)
        {
            if (_Searing.Get_FaceSear(_HalfId, EMars_FoodPiece_Face(Index)) >= 1.0f)
            {
                _SearedFace = EMars_FoodPiece_Face(Index);
                break;
            }
        }

        ck::Trace(f"[SearingStation] bench half seared {utils_foodpiece::Get_FaceName(_SearedFace)} through");
    }

    UFUNCTION()
    private void Check_DisplayShowsTheCrust(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_DisplaySlot(int32(_SearedFace)) >= k_FullCrust);
    }

    UFUNCTION()
    private void Step_AssertDisplay(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Float(Get_DisplaySlot(int32(_SearedFace)), 1.0, 0.001,
            f"the half's display slot {int32(_SearedFace)} ({utils_foodpiece::Get_FaceName(_SearedFace)}) shows the full crust");
        Assert_Equals_Int(_Searing.Get_SearedFaceCount(_HalfId), 1, "one face is seared through");
        Assert_True(_Searing.Get_PieceStatus(_HalfId) == EMars_Searing_PieceStatus::Cooking, "the half is still cooking its other faces");
    }

    // 0 until the half's display is Ready.
    private float32 Get_DisplaySlot(int32 InIndex) const
    {
        FCk_Handle Entity = _Half;
        if (Entity.Is_RuntimeMeshDisplay() == false)
        { return 0.0f; }

        return utils_runtime_mesh_display::Get_CustomPrimitiveDataFloat(Entity.As_RuntimeMeshDisplay(), InIndex);
    }
}

class AMars_AutoTest_SearingStation_ASlabCutAtTheBenchSearsAFaceThroughOnThePan_Actor : AMars_AutoTestRunner_SearingPan
{
    default _TimeoutSeconds = 60.0f;
    default _TestEntityScriptClass = UMars_AutoTest_SearingStation_ASlabCutAtTheBenchSearsAFaceThroughOnThePan;
}
