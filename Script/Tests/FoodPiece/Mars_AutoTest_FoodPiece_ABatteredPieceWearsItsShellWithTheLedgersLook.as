// A battered whole piece wears its food's battered shell in its display's place, and the shell shows the ledger's look. A
// whole mushroom joint (a batterable food: batter is for whole ingredients), Ready and undressed, is given a battered cook state (its -X fried 1.5 in batter,
// an oil coat of 0.4, Battered 1); then its food dresses it (UMars_Food_Def::Add_Display). Once the display is Ready and
// the shell is set up: the display is hidden, the shell is its food's battered mesh, and the shell's 14 cook-state slots
// (the batter master reads the fry at 10 and the oil coat at 7; the dip rides 13) are the kernel's mapping of that ledger
// (utils_cookstate::Make_DisplayParams), as are the hidden display's, within 0.0001. Isolated origin
// (185000, -64000, -30000).
class UMars_AutoTest_FoodPiece_ABatteredPieceWearsItsShellWithTheLedgersLook : UMars_AutoTestRig_FoodPiece
{
    private const FVector k_Origin = FVector(185000.0, -64000.0, -30000.0);
    // The cook state's slots: 0..13, the oil coat at 7, the fry at 10, the dip at 13.
    private const int32 k_SlotCount = 14;
    private const int32 k_BatteredSlot = 13;
    private const float32 k_Tolerance = 0.0001f;
    private const int32 k_SlowPolls = 900;

    private FCk_Handle_FoodPiece _Slice;
    private FMars_CookState _Expected;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        _Slice = mars::Food_Mushroom_Mars.Build_Joint(ck::TransientEntity(), FTransform(FRotator::ZeroRotator, k_Origin));
        Track_ForCleanup(_Slice);

        Add_Step_WaitUntil("the slice is Ready", n"Check_SliceReady", k_SlowPolls, 0);
        Add_Step("batter the slice", n"Step_Batter");
        Add_Step_WaitUntil("the dip is on the ledger", n"Check_Battered", 0, 0);
        Add_Step("its food dresses it", n"Step_Dress");
        Add_Step_WaitUntil("the display is hidden and the shell wrote its cook state", n"Check_ShellWritten", k_SlowPolls, 0);
        Add_Step("the shell shows the ledger's look in the display's place", n"Step_AssertShell");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Check_SliceReady(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(ck::IsValid(_Slice) && _Slice.Get_Status() == EMars_FoodPiece_Status::Ready);
    }

    UFUNCTION()
    private void Step_Batter(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(utils_batter::Get_IsBatterable(_Slice), "the whole slice of a batterable food is batterable");

        auto CookState = FMars_FoodPiece_CookState();
        CookState.Batter[int32(EMars_FoodPiece_Face::NegX)] = 1.5f;
        CookState.OilCoat = 0.4f;
        CookState.Battered = 1.0f;
        _Slice.Request_SetCookState(FMars_Request_FoodPiece_SetCookState(CookState));
        _Expected = utils_cookstate::Make_DisplayParams(CookState);
    }

    UFUNCTION()
    private void Check_Battered(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Slice.Get_CookState().Battered > 0.5f);
    }

    UFUNCTION()
    private void Step_Dress(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const UMars_Food_Def Def = _Slice.Get_Definition().Get();
        Assert_True(ck::IsValid(Def), "the slice has its food's definition");
        if (ck::IsValid(Def))
        { Def.Add_Display(_Slice); }
    }

    UFUNCTION()
    private void Check_ShellWritten(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        FCk_Handle Entity = _Slice;
        auto Res = OutResult;
        if (Entity.Is_RuntimeMeshDisplay() == false)
        {
            Res.Set(false);
            return;
        }

        const auto Display = Entity.As_RuntimeMeshDisplay();
        const auto IsHidden = utils_runtime_mesh_display::Get_SetupState(Display) == ECk_RuntimeMesh_SetupState::Ready
            && Display.Get_Visibility() == ECk_EnableDisable::Disable;

        const auto Shell = utils_food::TryGet_BatteredShell(_Slice);
        const auto ShellWritten = ck::IsValid(Shell) && ck::IsValid(utils_unreal_component::Get_Component(Shell))
            && utils_unreal_component::Get_CustomPrimitiveDataFloat(Shell, k_BatteredSlot) > 0.5f;

        Res.Set(IsHidden && ShellWritten);
    }

    UFUNCTION()
    private void Step_AssertShell(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        FCk_Handle Entity = _Slice;
        const auto Display = Entity.As_RuntimeMeshDisplay();
        const auto Shell = utils_food::TryGet_BatteredShell(_Slice);

        const auto Mesh = Cast<UStaticMeshComponent>(utils_unreal_component::Get_Component(Shell));
        Assert_True(ck::IsValid(Mesh), "the shell is a static mesh component");
        if (ck::IsValid(Mesh))
        {
            const auto Expected = mars::Food_Mushroom_Mars.Visuals.Battered.Mesh.ToSoftObjectPath().ToString();
            const auto Shown = ck::IsValid(Mesh.GetStaticMesh()) ? Mesh.GetStaticMesh().GetPathName() : "none";
            Assert_True(Shown == Expected, f"the shell shows the food's battered mesh [{Expected}] (shows [{Shown}])");
        }

        // The slots as utils_cookstate lays them out: six face sears, penetration, oil coat, glaze, shape, fry, wet, crumb,
        // the dip.
        auto Expected = _Expected.FaceSear;
        Expected.Add(_Expected.Penetration);
        Expected.Add(_Expected.OilCoat);
        Expected.Add(_Expected.Glaze);
        Expected.Add(_Expected.Shape);
        Expected.Add(_Expected.Fry);
        Expected.Add(_Expected.Wet);
        Expected.Add(_Expected.Crumb);
        Expected.Add(_Expected.Battered);

        for (int32 Slot = 0; Slot < k_SlotCount; ++Slot)
        {
            const auto Shown = utils_unreal_component::Get_CustomPrimitiveDataFloat(Shell, Slot);
            Assert_Equals_Float(Shown, Expected[Slot], k_Tolerance, f"shell slot {Slot} [{Shown}] is the ledger's look [{Expected[Slot]}]");

            const auto Hidden = utils_runtime_mesh_display::Get_CustomPrimitiveDataFloat(Display, Slot);
            Assert_Equals_Float(Hidden, Expected[Slot], k_Tolerance, f"hidden display slot {Slot} [{Hidden}] is the ledger's look [{Expected[Slot]}]");
        }

        Assert_Equals_Float(_Expected.Battered, 1.0f, k_Tolerance, "the look is battered");
        Assert_Equals_Float(_Expected.OilCoat, 0.4f, k_Tolerance, "the look carries the oil coat");
        Assert_True(_Expected.Fry > 0.0f, "the look carries the batter's fry");
    }
}
