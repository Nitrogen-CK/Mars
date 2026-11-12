// A piece script born of a cut its source is not committing ends itself. The test slices a funnel slab's geometry itself
// and spawns both results as piece scripts naming the slab as their source, which has no pending commit: neither becomes
// a live FoodPiece, both are gone three frames later, the slab is still Ready and whole and its OnCutResolved never fires.
// A second slice's two results spawned naming no source both become Ready pieces. Isolated origin (-151000, 30000, -30000).
class UMars_AutoTest_FoodPieceScript_APieceWhoseCommitIsGoneEndsItself : UMars_AutoTestRig_FoodPiece
{
    private const FVector k_Origin = FVector(-151000.0, 30000.0, -30000.0);
    private const int32 k_SlowPolls = 900;

    private UMars_AutoTestHelper_CookingFixture _Fixture;
    private FCk_Handle _WorldFood;
    private FCk_Handle_FoodPiece _Slab;
    private int32 _SlabResolutions = 0;
    // The two results of each slice the test made, in order.
    private TArray<FCk_RuntimeMesh_SliceResult> _Slices;
    private TArray<FCk_Handle> _Orphans;
    private TArray<FCk_Handle> _Free;
    private int32 _OrphanLivePieceFrames = 0;
    private int32 _OrphanWatchFrames = 0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        _Fixture = Cast<UMars_AutoTestHelper_CookingFixture>(NewObject(this, UMars_AutoTestHelper_CookingFixture));
        _Fixture.Spawn_Floor(InHandle, k_Origin, 100.0);

        Add_Step_WaitUntil("the replicated spawn owner is published", n"Check_SpawnOwner", k_SlowPolls, 0);
        Add_Step("spawn the world slab through the funnel", n"Step_SpawnWorldFood");
        Add_Step_WaitUntil("the world slab is Ready", n"Check_SlabReady", k_SlowPolls, 0);
        Add_Step("slice the slab's geometry", n"Step_Slice");
        Add_Step_WaitUntil("the slice resolved", n"Check_OneSlice", k_SlowPolls, 0);
        Add_Step("spawn both results naming the slab as their source", n"Step_SpawnOrphans");
        Add_Step_WaitUntil("three frames passed, watching the orphans", n"Check_OrphansWatched", k_SlowPolls, 0);
        Add_Step("the orphans ended themselves; the slab is untouched", n"Step_AssertOrphans");
        Add_Step("slice the slab's geometry again", n"Step_Slice");
        Add_Step_WaitUntil("the second slice resolved", n"Check_TwoSlices", k_SlowPolls, 0);
        Add_Step("spawn both results naming no source", n"Step_SpawnFree");
        Add_Step_WaitFrames("the free pieces construct", 3);
        Add_Step("both free pieces are Ready", n"Step_AssertFree");
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
    private void Check_SlabReady(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto IsReady = ck::IsValid(_WorldFood) && _WorldFood.Is_WorldItem() && _WorldFood.Is_FoodPiece()
            && _WorldFood.As_FoodPiece().Get_Status() == EMars_FoodPiece_Status::Ready;
        if (IsReady && ck::Is_NOT_Valid(_Slab))
        {
            _Slab = _WorldFood.As_FoodPiece();
            _Slab.BindTo_OnCutResolved(FMars_Delegate_FoodPiece_OnCutResolved(this, n"OnSlabCutResolved"));
        }

        auto Res = OutResult;
        Res.Set(IsReady);
    }

    UFUNCTION()
    private void OnSlabCutResolved(FCk_Handle_FoodPiece InSource, FMars_FoodPiece_CutResult InResult)
    {
        ++_SlabResolutions;
    }

    UFUNCTION()
    private void Step_Slice(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Slice = FCk_Request_RuntimeMesh_Slice();
        Slice.Set_OperationID(FGuid::NewGuid());
        Slice.Set_ResultOwner(InHandle);
        Slice.Set_Plane(Make_Plane(FVector::ZeroVector, FVector::ForwardVector));
        Slice.Set_Cap(_Slab.Get_Cap());
        utils_runtime_mesh::Request_Slice(_Slab.Get_Geometry(), Slice, FCk_Delegate_RuntimeMesh_OnSliceResolved(this, n"OnTestSliceResolved"));
    }

    UFUNCTION()
    private void OnTestSliceResolved(FCk_RuntimeMesh_SliceResult InResult)
    {
        _Slices.Add(InResult);
        if (ck::IsValid(InResult.Get_Positive()))
        { Track_ForCleanup(InResult.Get_Positive()); }

        if (ck::IsValid(InResult.Get_Negative()))
        { Track_ForCleanup(InResult.Get_Negative()); }
    }

    UFUNCTION()
    private void Check_OneSlice(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Slices.Num() >= 1);
    }

    UFUNCTION()
    private void Check_TwoSlices(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Slices.Num() >= 2);
    }

    // The birth of one of a slice's results: a half of the slab of its share of the mass, cut along the centre plane.
    private FMars_FoodPiece_Birth Make_Birth(const FCk_RuntimeMesh_SliceResult& InSlice, EMars_FoodPiece_CutSide InSide, FCk_Handle_FoodPiece InSource)
    {
        const auto Split = utils_foodpiece::Get_MassSplit(_Slab.Get_MassKg(), InSlice);
        const auto IsPositive = InSide == EMars_FoodPiece_CutSide::Positive;

        auto Spec = FMars_FoodPiece_Spec(FMars_FoodPiece_Data(), _Slab.Get_Tuners(), _Slab.Get_Cap(), _Slab.Get_BodyTuners());
        Spec.Data.Id = FGuid::NewGuid();
        Spec.Data.ParentId = _Slab.Get_Id();
        Spec.Data.Lineage = _Slab.Get_Lineage();
        Spec.Data.MassKg = IsPositive ? Split.PositiveKg : Split.NegativeKg;
        Spec.Data.Definition = _Slab.Get_Definition();
        Spec.Data.Kind = _Slab.Get_Kind();
        Spec.Data.Recipe = _Slab.Get_Recipe();
        Spec.Data.Recipe.Cuts.Add(FMars_FoodPiece_RecipeCut(Make_Plane(FVector::ZeroVector, FVector::ForwardVector), InSide));

        auto Birth = FMars_FoodPiece_Birth();
        Birth.Geometry = IsPositive ? InSlice.Get_Positive() : InSlice.Get_Negative();
        Birth.Spec = Spec;
        Birth.World = Get_World(_Slab);
        Birth.Source = InSource;
        return Birth;
    }

    // Both results of InSlice as piece scripts, each naming the other as its sibling.
    private TArray<FCk_Handle> Spawn_Pair(FCk_Handle InHandle, const FCk_RuntimeMesh_SliceResult& InSlice, FCk_Handle_FoodPiece InSource)
    {
        auto Positive = utils_foodpiece::Request_SpawnCutPiece(InHandle, Make_Birth(InSlice, EMars_FoodPiece_CutSide::Positive, InSource));
        auto Negative = utils_foodpiece::Request_SpawnCutPiece(InHandle, Make_Birth(InSlice, EMars_FoodPiece_CutSide::Negative, InSource));
        Track_ForCleanup(Positive);
        Track_ForCleanup(Negative);

        TArray<FCk_Handle> Pair;
        Pair.Add(Positive);
        Pair.Add(Negative);
        if (ck::Is_NOT_Valid(Positive) || ck::Is_NOT_Valid(Negative))
        {
            Assert_True(false, "both results spawned as piece scripts");
            return Pair;
        }

        Positive.Get_Fragment(FMars_Fragment_FoodPiece_Birth).Birth.Sibling = Negative;
        Negative.Get_Fragment(FMars_Fragment_FoodPiece_Birth).Birth.Sibling = Positive;
        return Pair;
    }

    UFUNCTION()
    private void Step_SpawnOrphans(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Slices[0].Get_Outcome() == ECk_RuntimeMesh_SliceOutcome::Succeeded, f"the slice succeeded (got {_Slices[0].Get_Outcome() :n})");
        _Orphans = Spawn_Pair(InHandle, _Slices[0], _Slab);
        _OrphanLivePieceFrames = 0;
    }

    UFUNCTION()
    private void Check_OrphansWatched(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        for (const auto& Orphan : _Orphans)
        {
            const auto IsLivePiece = ck::IsValid(Orphan) && Orphan.Is_FoodPiece()
                && utils_entity_lifetime::Get_IsPendingDestroy(Orphan, ECk_EntityLifetime_DestructionPhase::BeginDestroy) == false;
            _OrphanLivePieceFrames += IsLivePiece ? 1 : 0;
        }

        ++_OrphanWatchFrames;
        auto Res = OutResult;
        Res.Set(_OrphanWatchFrames >= 3);
    }

    UFUNCTION()
    private void Step_AssertOrphans(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_OrphanLivePieceFrames, 0, "neither orphan was ever seen a live FoodPiece");
        for (const auto& Orphan : _Orphans)
        { Assert_True(ck::Is_NOT_Valid(Orphan), f"the orphan [{Orphan.ToString()}] is gone three frames later"); }

        Assert_True(ck::IsValid(_Slab) && _Slab.Get_Status() == EMars_FoodPiece_Status::Ready, "the slab is still Ready");
        Assert_True(_Slab.Get_IsWhole() && _Slab.Get_IsCutting() == false, "the slab is still whole and not cutting");
        Assert_Equals_Int(_SlabResolutions, 0, "the slab's OnCutResolved never fired");
    }

    UFUNCTION()
    private void Step_SpawnFree(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Slices[1].Get_Outcome() == ECk_RuntimeMesh_SliceOutcome::Succeeded, f"the second slice succeeded (got {_Slices[1].Get_Outcome() :n})");
        _Free = Spawn_Pair(InHandle, _Slices[1], FCk_Handle_FoodPiece());
    }

    UFUNCTION()
    private void Step_AssertFree(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        for (const auto& Free : _Free)
        {
            const auto IsReady = ck::IsValid(Free) && Free.Is_FoodPiece() && Free.As_FoodPiece().Get_Status() == EMars_FoodPiece_Status::Ready;
            Assert_True(IsReady, f"the free piece [{Free.ToString()}] is a Ready FoodPiece");
        }

        Assert_Equals_Int(_SlabResolutions, 0, "the slab's OnCutResolved never fired");
    }
}
