// A piece's display starts as cooked as its ledger says, whoever dresses it (a cut half, a piece re-dressed at a station).
// A mushroom slice joint, Ready and undressed, is given a cook state (its +Z seared 0.6, its -X fried 1.5 in batter, an oil
// coat of 0.4); then its food dresses it (UMars_Food_Def::Add_Display). Once the display is Ready its 13 cook-state slots
// are the kernel's mapping of that ledger (utils_cookstate::Make_DisplayParams), within 0.0001. Isolated origin
// (185000, -70000, -30000).
class UMars_AutoTest_FoodPiece_ADisplayStartsFromTheLedgersCookState : UMars_AutoTestRig_FoodPiece
{
    private const FVector k_Origin = FVector(185000.0, -70000.0, -30000.0);
    // The cook state's display slots: 0..12, the oil coat at 7.
    private const int32 k_SlotCount = 13;
    private const int32 k_OilCoatSlot = 7;
    private const float32 k_Tolerance = 0.0001f;
    private const int32 k_SlowPolls = 900;

    private FCk_Handle_FoodPiece _Slice;
    private FMars_CookState _Expected;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        _Slice = mars::Food_MushroomSlice_Mars.Build_Joint(ck::TransientEntity(), FTransform(FRotator::ZeroRotator, k_Origin));
        Track_ForCleanup(_Slice);

        Add_Step_WaitUntil("the slice is Ready", n"Check_SliceReady", k_SlowPolls, 0);
        Add_Step("give the slice a cook state", n"Step_SetCookState");
        Add_Step_WaitUntil("the cook state is on the ledger", n"Check_CookStateSet", 0, 0);
        Add_Step("its food dresses it", n"Step_Dress");
        Add_Step_WaitUntil("the display is Ready and wrote its cook state", n"Check_DisplayWritten", k_SlowPolls, 0);
        Add_Step("every slot is the ledger's look", n"Step_AssertSlots");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Check_SliceReady(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(ck::IsValid(_Slice) && _Slice.Get_Status() == EMars_FoodPiece_Status::Ready);
    }

    UFUNCTION()
    private void Step_SetCookState(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        FCk_Handle Entity = _Slice;
        Assert_False(Entity.Is_RuntimeMeshDisplay(), "the slice is not dressed yet");

        auto CookState = FMars_FoodPiece_CookState();
        CookState.Sear[int32(EMars_FoodPiece_Face::PosZ)] = 0.6f;
        CookState.Batter[int32(EMars_FoodPiece_Face::NegX)] = 1.5f;
        CookState.OilCoat = 0.4f;
        _Slice.Request_SetCookState(FMars_Request_FoodPiece_SetCookState(CookState));
        _Expected = utils_cookstate::Make_DisplayParams(CookState);
    }

    UFUNCTION()
    private void Check_CookStateSet(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Slice.Get_CookState().OilCoat > 0.0f);
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
    private void Check_DisplayWritten(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        FCk_Handle Entity = _Slice;
        auto Res = OutResult;
        if (Entity.Is_RuntimeMeshDisplay() == false)
        {
            Res.Set(false);
            return;
        }

        const auto Display = Entity.As_RuntimeMeshDisplay();
        const auto IsReady = utils_runtime_mesh_display::Get_SetupState(Display) == ECk_RuntimeMesh_SetupState::Ready;
        Res.Set(IsReady && utils_runtime_mesh_display::Get_CustomPrimitiveDataFloat(Display, k_OilCoatSlot) > 0.0f);
    }

    UFUNCTION()
    private void Step_AssertSlots(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        FCk_Handle Entity = _Slice;
        const auto Display = Entity.As_RuntimeMeshDisplay();

        // The slots as utils_cookstate lays them out: six face sears, penetration, oil coat, glaze, shape, fry, wet, crumb.
        auto Expected = _Expected.FaceSear;
        Expected.Add(_Expected.Penetration);
        Expected.Add(_Expected.OilCoat);
        Expected.Add(_Expected.Glaze);
        Expected.Add(_Expected.Shape);
        Expected.Add(_Expected.Fry);
        Expected.Add(_Expected.Wet);
        Expected.Add(_Expected.Crumb);

        for (int32 Slot = 0; Slot < k_SlotCount; ++Slot)
        {
            const auto Shown = utils_runtime_mesh_display::Get_CustomPrimitiveDataFloat(Display, Slot);
            Assert_Equals_Float(Shown, Expected[Slot], k_Tolerance, f"display slot {Slot} [{Shown}] is the ledger's look [{Expected[Slot]}]");
        }

        Assert_Equals_Float(_Expected.FaceSear[int32(EMars_FoodPiece_Face::NegX)], 1.5f, k_Tolerance, "the fried -X shows its batter");
        Assert_Equals_Float(_Expected.FaceSear[int32(EMars_FoodPiece_Face::PosZ)], 0.6f, k_Tolerance, "the seared +Z shows its sear");
    }
}
