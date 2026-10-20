// The station path, end to end. A whole mushroom (a prep food with a battered variant) loaded onto a large raw platter and an
// empty tray dock on the real batter station; an operator takes it and one add-food press carries the mushroom into the
// bowl, where it wears its own display (no shell yet). The bowl is dipped until its coat completes and lifted; a take-out
// lands it on the tray. Its ledger is battered, and it wears its food's battered shell (the food's battered mesh, its dip
// slot written) in place of its hidden display. Isolated origin (192000, -76000, -30000).
class UMars_AutoTest_BatterStation_APlatterSourcedPrepFoodIsBatteredAndWearsItsShell : UMars_AutoTestRig_BatterStation
{
    private const FVector k_Origin = FVector(192000.0, -76000.0, -30000.0);

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Spawn_All(InHandle, k_Origin, mars_items::Food_Mushroom());

        Add_Steps_DockedAndTaken();
        Add_Step("one add-food press", n"Step_BeginTransfer");
        Add_Step_WaitUntil("the bowl admitted the mushroom", n"Check_Admitted", k_SlowPolls, 0);
        Add_Step("it wears its own display, no shell yet", n"Step_AssertBare");
        Add_Step("dip", n"Step_Dip");
        Add_Step_WaitUntil("the coat completes", n"Check_Coated", k_SlowPolls, 0);
        Add_Step("lift", n"Step_Lift");
        Add_Step_WaitUntil("it rose back to rest and the readout lists it", n"Check_Takeable", k_SlowPolls, 0);
        Add_Step("take out onto the tray", n"Step_TakeOut");
        Add_Step_WaitUntil("the mushroom landed on the tray", n"Check_OnTray", k_SlowPolls, 0);
        Add_Step_WaitUntil("it wears its battered shell in its display's place", n"Check_WearsShell", k_SlowPolls, 0);
        Add_Step("battered, on the tray, wearing its food's battered mesh", n"Step_AssertBattered");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_AssertBare(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Batter.Get_PieceHandle(Get_FirstId()) == _Food, "the bowl holds the mushroom from the raw platter");
        Assert_True(_Food.Get_IsWhole(), "the mushroom is whole");

        FCk_Handle Entity = _Food;
        Assert_True(Entity.Is_RuntimeMeshDisplay(), "it wears its own display");
        Assert_False(ck::IsValid(utils_food::TryGet_BatteredShell(_Food)), "no battered shell before the take-out");
        Assert_False(utils_batter::Get_IsBattered(_Food.Get_CookState()), "its ledger is not battered yet");
    }

    UFUNCTION()
    private void Step_AssertBattered(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(utils_batter::Get_IsBattered(_Food.Get_CookState()), "the ledger is battered");
        Assert_True(_Food.TryGet_Platter() == _Tray.As_Platter(), "the mushroom is on the tray");
        Assert_Equals_Int(_Batter.Get_PieceCount(), 0, "the bowl is empty");

        const auto Shell = utils_food::TryGet_BatteredShell(_Food);
        const auto Mesh = Cast<UStaticMeshComponent>(utils_unreal_component::Get_Component(Shell));
        Assert_True(ck::IsValid(Mesh), "the shell is a static mesh component");
        if (ck::Is_NOT_Valid(Mesh))
        { return; }

        const auto Expected = mars::Food_Mushroom_Mars.Visuals.Battered.Mesh.ToSoftObjectPath().ToString();
        const auto Shown = ck::IsValid(Mesh.GetStaticMesh()) ? Mesh.GetStaticMesh().GetPathName() : "none";
        Assert_True(Shown == Expected, f"the shell shows the food's battered mesh [{Expected}] (shows [{Shown}])");
    }
}
