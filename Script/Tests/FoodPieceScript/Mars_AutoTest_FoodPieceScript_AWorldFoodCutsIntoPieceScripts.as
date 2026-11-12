// A meat slab spawned through the world-item funnel replicates, so its cut makes piece scripts: both halves are Ready, have
// a replication driver and a display, and carry a one-cut recipe naming the slab's definition id. A bare joint of the same
// food, built under the world's transient entity, is cut the same way on the slice's own entities: its halves have no
// replication driver and are the transient entity's lifetime dependents. Isolated origin (-150000, 30000, -30000).
class UMars_AutoTest_FoodPieceScript_AWorldFoodCutsIntoPieceScripts : UMars_AutoTestRig_FoodPiece
{
    private const FVector k_Origin = FVector(-150000.0, 30000.0, -30000.0);
    private const FVector k_BareOffset = FVector(400.0, 0.0, 0.0);
    private const int32 k_SlowPolls = 900;

    private UMars_AutoTestHelper_CookingFixture _Fixture;
    private FCk_Handle _WorldFood;
    private FCk_Handle_FoodPiece _BareJoint;
    private TArray<FCk_Handle_FoodPiece> _ResultSources;
    private TArray<FMars_FoodPiece_CutResult> _Results;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        _Fixture = Cast<UMars_AutoTestHelper_CookingFixture>(NewObject(this, UMars_AutoTestHelper_CookingFixture));
        _Fixture.Spawn_Floor(InHandle, k_Origin, 100.0);

        _BareJoint = mars::Food_MeatSlab_Mars.Build_Joint(ck::TransientEntity(), FTransform(FRotator::ZeroRotator, k_Origin + k_BareOffset));
        Track_ForCleanup(_BareJoint);

        Add_Step_WaitUntil("the replicated spawn owner is published", n"Check_SpawnOwner", k_SlowPolls, 0);
        Add_Step("spawn the world slab through the funnel", n"Step_SpawnWorldFood");
        Add_Step_WaitUntil("the world slab and the bare joint are Ready", n"Check_BothReady", k_SlowPolls, 0);
        Add_Step("cut both through their centre", n"Step_Cut");
        Add_Step_WaitUntil("both cuts resolved", n"Check_BothResolved", k_SlowPolls, 0);
        Add_Step_WaitFrames("the halves are dressed", 1);
        Add_Step("the world slab's halves are piece scripts; the bare joint's are local", n"Step_Assert");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Check_SpawnOwner(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(utils_mars_net::Get_HasReplicatedSpawnOwner(InHandle));
    }

    UFUNCTION()
    private void Step_SpawnWorldFood(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto SpawnParams = UMars_FoodItem_EntityScript::Params();
        SpawnParams.SpawnTransform = FTransform(FRotator::ZeroRotator, k_Origin + FVector(0.0, 0.0, 5.0));
        SpawnParams.Definition = utils_held_item::Make_DefinitionSoft(mars_items::Food_MeatSlab());
        SpawnParams.Mode = EMars_WorldItem_Mode::World;
        _WorldFood = utils_world_item::Request_SpawnWorldEntity(ck::TransientEntity(), UMars_FoodItem_EntityScript, SpawnParams).Get_EntityUnderConstruction();
        Track_ForCleanup(_WorldFood);
    }

    UFUNCTION()
    private void Check_BothReady(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto WorldReady = ck::IsValid(_WorldFood) && _WorldFood.Is_WorldItem() && _WorldFood.Is_FoodPiece()
            && _WorldFood.As_FoodPiece().Get_Status() == EMars_FoodPiece_Status::Ready;
        const auto BareReady = ck::IsValid(_BareJoint) && _BareJoint.Get_Status() == EMars_FoodPiece_Status::Ready;

        auto Res = OutResult;
        Res.Set(WorldReady && BareReady);
    }

    UFUNCTION()
    private void Step_Cut(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto WorldPiece = _WorldFood.As_FoodPiece();
        WorldPiece.BindTo_OnCutResolved(FMars_Delegate_FoodPiece_OnCutResolved(this, n"OnTestCutResolved"));
        _BareJoint.BindTo_OnCutResolved(FMars_Delegate_FoodPiece_OnCutResolved(this, n"OnTestCutResolved"));
        Cut(WorldPiece, FVector::ZeroVector, FVector::ForwardVector);
        Cut(_BareJoint, FVector::ZeroVector, FVector::ForwardVector);
    }

    UFUNCTION()
    private void OnTestCutResolved(FCk_Handle_FoodPiece InSource, FMars_FoodPiece_CutResult InResult)
    {
        _ResultSources.Add(InSource);
        _Results.Add(InResult);
        if (InResult.Outcome != EMars_FoodPiece_CutOutcome::Cut)
        { return; }

        Track_ForCleanup(InResult.Positive);
        Track_ForCleanup(InResult.Negative);
    }

    UFUNCTION()
    private void Check_BothResolved(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Results.Num() >= 2);
    }

    UFUNCTION()
    private void Step_Assert(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Results.Num(), 2, "two cuts resolved");
        for (int32 Index = 0; Index < _Results.Num(); ++Index)
        {
            const auto Result = _Results[Index];
            Assert_True(Result.Outcome == EMars_FoodPiece_CutOutcome::Cut, f"cut {Index} resolved Cut (got {Result.Outcome :n})");
            if (Result.Outcome != EMars_FoodPiece_CutOutcome::Cut)
            { continue; }

            const auto IsWorld = _ResultSources[Index] != _BareJoint;
            Assert_Halves(Result, IsWorld);
        }
    }

    private void Assert_Halves(FMars_FoodPiece_CutResult InResult, bool InIsWorld)
    {
        TArray<FCk_Handle_FoodPiece> Halves;
        Halves.Add(InResult.Positive);
        Halves.Add(InResult.Negative);
        for (const auto& Half : Halves)
        {
            FCk_Handle Entity = Half;
            Assert_True(ck::IsValid(Entity) && Half.Get_Status() == EMars_FoodPiece_Status::Ready, "the half is a Ready piece");
            if (ck::Is_NOT_Valid(Entity))
            { continue; }

            if (InIsWorld)
            {
                Assert_True(utils_entity_replication_driver::Has(Entity), "a world slab's half has a replication driver");
                Assert_True(Entity.Is_RuntimeMeshDisplay(), "a world slab's half wears a display");
                const auto Recipe = Half.Get_Recipe();
                Assert_True(Recipe.Definition == GameplayTags::FoodDef_Mars_MeatSlab, f"a world slab's half's recipe names the slab ({Recipe.Definition.ToString()})");
                Assert_Equals_Int(Recipe.Cuts.Num(), 1, "a world slab's half carries a one-cut recipe");
            }
            else
            {
                Assert_False(utils_entity_replication_driver::Has(Entity), "a bare joint's half has no replication driver");
                Assert_True(utils_entity_lifetime::Get_LifetimeOwner(Entity) == ck::TransientEntity(), "a bare joint's half is the transient entity's dependent");
            }
        }
    }
}
