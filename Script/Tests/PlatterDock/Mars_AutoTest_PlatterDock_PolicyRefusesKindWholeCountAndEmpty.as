// Each policy rule refuses on its own, and a count never does: five docks on one root (A Kind = Food.Meat, B WholeOnly, C no
// rule, D RequireEmpty true, E RequireEmpty false) judge three platters (the whole beef joint on a large platter; two bare
// boxes with no kind; empty) through the pure Get_Refusal, every combination: the two boxes pass every rule they do not
// break. Two real Docks prove the signals: the box platter onto A is refused KindRejected, the dock stays empty and the
// platter stays in the world; the same two-piece platter onto C docks. Isolated Z band: -58000.
class UMars_AutoTest_PlatterDock_PolicyRefusesKindWholeCountAndEmpty : UMars_AutoTestRig_PlatterDock
{
    default _TimeoutSeconds = 30.0f;

    private const FVector k_Origin = FVector(0.0, 0.0, -58000.0);

    // _Platters order.
    private const int32 k_Meat = 0;
    private const int32 k_Boxes = 1;
    private const int32 k_Empty = 2;

    private TArray<FCk_Handle_PlatterDock> _Docks;
    private TArray<FCk_Handle_FoodPiece> _Boxes;
    private FCk_Handle_FoodPiece _Joint;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Root = Build_StationRoot(InHandle, k_Origin);

        auto MustBeEmpty = Make_Policy(TOptional<FGameplayTag>(), false);
        MustBeEmpty.RequireEmpty = TOptional<bool>(true);

        auto MustHaveFood = Make_Policy(TOptional<FGameplayTag>(), false);
        MustHaveFood.RequireEmpty = TOptional<bool>(false);

        TArray<FMars_PlatterDock_Policy> Policies;
        Policies.Add(Make_Policy(TOptional<FGameplayTag>(GameplayTags::Food_Meat), false));
        Policies.Add(Make_Policy(TOptional<FGameplayTag>(), true));
        Policies.Add(Make_Policy(TOptional<FGameplayTag>(), false));
        Policies.Add(MustBeEmpty);
        Policies.Add(MustHaveFood);

        for (int32 Index = 0; Index < Policies.Num(); ++Index)
        {
            const auto MountLocal = FTransform(FRotator::ZeroRotator, FVector(0.0, 60.0 * Index, 70.0));
            _Docks.Add(Build_Dock(Root, Make_DockSpec(Policies[Index], MountLocal, f"dock {Index}")));
        }

        Spawn_Platter(InHandle, FMars_Platter_SpawnSpec(FTransform(FRotator::ZeroRotator, k_Origin + FVector(200.0, 0.0, 0.0)),
            mars_items::Platter_Large()));
        Spawn_FoodOnto(k_Meat, mars_items::Food_MeatSlab(), k_Origin + FVector(200.0, 0.0, 60.0));
        Spawn_Platter(InHandle, FMars_Platter_SpawnSpec(FTransform(FRotator::ZeroRotator, k_Origin + FVector(200.0, 100.0, 0.0))));
        Spawn_Platter(InHandle, FMars_Platter_SpawnSpec(FTransform(FRotator::ZeroRotator, k_Origin + FVector(200.0, 200.0, 0.0))));

        _Boxes.Add(Build_Box(FTransform(FRotator::ZeroRotator, k_Origin + FVector(300.0, 100.0, 0.0))));
        _Boxes.Add(Build_Box(FTransform(FRotator::ZeroRotator, k_Origin + FVector(300.0, 150.0, 0.0))));

        Add_Step_WaitUntil("the three platters are constructed and their holders hold their items", n"Check_PlattersConstructed");
        Add_Step_WaitUntil("the beef joint landed on its platter and both boxes are Ready", n"Check_MeatLandedBoxesReady");
        Add_Step("load both boxes onto the box platter", n"Step_LoadBoxes");
        Add_Step_WaitUntil("both boxes landed", n"Check_BoxesLanded");
        Add_Step("Get_Refusal over every dock and platter", n"Step_AssertTable");
        Add_Step("dock the box platter onto the meat dock", n"Step_DockBoxesOntoMeat");
        Add_Step_WaitUntil("the meat dock refused it", n"Check_Refused");
        Add_Step_WaitFrames("nothing else moves", 2);
        Add_Step("refused KindRejected: the dock is empty and the platter still lies in the world", n"Step_AssertRefused");
        Add_Step("dock the two-piece box platter onto the rule-less dock", n"Step_DockBoxesOntoNoRule");
        Add_Step_WaitUntil("the rule-less dock took it", n"Check_DockedOntoNoRule", 0, 5.0f);
        Add_Step("no count refused it", n"Step_AssertDocked");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_DockBoxesOntoNoRule(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Dock(_Docks[2], _PlatterItems[k_Boxes]);
    }

    UFUNCTION()
    private void Check_DockedOntoNoRule(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_DockedCount(_Docks[2]) == 1 || Get_Refusals(_Docks[2]).Num() > 0);
    }

    UFUNCTION()
    private void Step_AssertDocked(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(Get_Refusals(_Docks[2]).Num(), 0, "the rule-less dock refused nothing");
        Assert_True(_Docks[2].Get_Platter() == _Platters[k_Boxes], "the rule-less dock holds the two-piece platter");
        Assert_Equals_Int(_Platters[k_Boxes].Get_Occupancy(), 2, "with both its pieces");
    }

    UFUNCTION()
    private void Check_MeatLandedBoxesReady(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto MeatLanded = _Platters[k_Meat].Get_HeldCount() == 1;
        if (MeatLanded && ck::Is_NOT_Valid(_Joint))
        {
            const auto Held = _Platters[k_Meat].Get_Held();
            _Joint = Held[0];
            Track_ForCleanup(_Joint);
        }

        auto BoxesReady = true;
        for (const auto& Box : _Boxes)
        { BoxesReady = BoxesReady && Box.Get_Status() == EMars_FoodPiece_Status::Ready; }

        auto Res = OutResult;
        Res.Set(MeatLanded && BoxesReady);
    }

    UFUNCTION()
    private void Step_LoadBoxes(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Platter = _Platters[k_Boxes];
        for (const auto& Box : _Boxes)
        { Platter.Request_Load(FMars_Request_Platter_Load(Box)); }
    }

    UFUNCTION()
    private void Check_BoxesLanded(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Platters[k_Boxes].Get_HeldCount() == 2);
    }

    UFUNCTION()
    private void Step_AssertTable(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto None = TOptional<EMars_PlatterDock_Refusal>();
        const auto KindRejected = TOptional<EMars_PlatterDock_Refusal>(EMars_PlatterDock_Refusal::KindRejected);
        const auto MustBeEmpty = TOptional<EMars_PlatterDock_Refusal>(EMars_PlatterDock_Refusal::MustBeEmpty);
        const auto MustHaveFood = TOptional<EMars_PlatterDock_Refusal>(EMars_PlatterDock_Refusal::MustHaveFood);

        Assert_True(_Joint.Get_Kind().HasTag(GameplayTags::Food_Meat_Beef), "the meat platter carries the beef joint");
        Assert_True(_Platters[k_Boxes].Get_Kinds().IsEmpty(), "the boxes carry no kind");

        // Rows: the platters; columns: docks A..E.
        AssertCell(k_Meat, 0, None);
        AssertCell(k_Meat, 1, None);
        AssertCell(k_Meat, 2, None);
        AssertCell(k_Meat, 3, MustBeEmpty);
        AssertCell(k_Meat, 4, None);

        AssertCell(k_Boxes, 0, KindRejected);
        AssertCell(k_Boxes, 1, None);
        AssertCell(k_Boxes, 2, None);
        AssertCell(k_Boxes, 3, MustBeEmpty);
        AssertCell(k_Boxes, 4, None);

        AssertCell(k_Empty, 0, None);
        AssertCell(k_Empty, 1, None);
        AssertCell(k_Empty, 2, None);
        AssertCell(k_Empty, 3, None);
        AssertCell(k_Empty, 4, MustHaveFood);
    }

    private void AssertCell(int32 InPlatter, int32 InDock, TOptional<EMars_PlatterDock_Refusal> InExpected)
    {
        const auto Actual = utils_platter_dock::Get_Refusal(_Docks[InDock].Get_Spec().Policy, _Platters[InPlatter]);
        const auto Matches = Actual.IsSet() == InExpected.IsSet() && (Actual.IsSet() == false || Actual.GetValue() == InExpected.GetValue());
        Assert_True(Matches, f"platter {InPlatter} on dock {InDock}: got [{Describe(Actual)}], expected [{Describe(InExpected)}]");
    }

    private FString Describe(TOptional<EMars_PlatterDock_Refusal> InRefusal) const
    {
        if (InRefusal.IsSet() == false)
        { return "none"; }

        return f"{InRefusal.GetValue() :n}";
    }

    UFUNCTION()
    private void Step_DockBoxesOntoMeat(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Dock(_Docks[0], _PlatterItems[k_Boxes]);
    }

    UFUNCTION()
    private void Check_Refused(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_Refusals(_Docks[0]).Num() > 0);
    }

    UFUNCTION()
    private void Step_AssertRefused(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Refusals = Get_Refusals(_Docks[0]);
        Assert_Equals_Int(Refusals.Num(), 1, "the meat dock refused once");
        Assert_True(Refusals[0].Item == _PlatterItems[k_Boxes], "the refusal names the box platter's item");
        Assert_True(Refusals[0].Refusal == EMars_PlatterDock_Refusal::KindRejected, f"refused KindRejected (got [{Refusals[0].Refusal :n}])");

        Assert_False(_Docks[0].Get_IsOccupied(), "the meat dock is empty");
        Assert_Equals_Int(Get_DockedCount(_Docks[0]), 0, "the meat dock docked nothing");
        Assert_True(_WorldItems[k_Boxes].Get_Mount() == EMars_WorldItem_Mount::World, "the box platter is still in the world");
        Assert_True(_WorldItems[k_Boxes].Get_TargetMount() == EMars_WorldItem_Mount::World, "the box platter is not on its way anywhere");
        Assert_True(_WorldItems[k_Boxes].Get_HeldItem() == _PlatterItems[k_Boxes], "the box platter's holder still holds its item");
    }
}
