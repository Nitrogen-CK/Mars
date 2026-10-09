// The FoodPiece rig. Pieces are built under the world's transient entity, where the kernel puts their halves, tracked for
// cleanup and recorded: every OnReady, OnFailed and OnCutResolved, and a Cut's halves are tracked and recorded as they
// arrive. The box fixture is a CPU-readable 1000 cm3 cube; tests place their planes from its metrics.
UCLASS(Abstract)
class UMars_AutoTestRig_FoodPiece : UCk_AutoTest_Base
{
    default _TimeoutSeconds = 15.0f;

    // In arrival order.
    protected TArray<FCk_Handle_FoodPiece> _Readied;
    protected TArray<ECk_RuntimeMesh_SetupFailure> _Failures;

    // In parallel: one entry per OnCutResolved.
    protected TArray<FCk_Handle_FoodPiece> _CutSources;
    protected TArray<FMars_FoodPiece_CutResult> _Cuts;

    protected TSoftObjectPtr<UStaticMesh> Get_BoxMesh() const
    {
        return TSoftObjectPtr<UStaticMesh>(FSoftObjectPath("/CkTests/CkRuntimeMesh/Cooked/SM_Import_CPU.SM_Import_CPU"));
    }

    // InMassKg with portion minimums no box cut in these tests comes near.
    protected FMars_FoodPiece_Spec Make_Spec(float InMassKg) const
    {
        auto Spec = FMars_FoodPiece_Spec();
        Spec.Data.MassKg = InMassKg;
        Spec.Tuners = FMars_FoodPiece_Tuners(0.0001, 0.05);
        return Spec;
    }

    // Transform, RuntimeMesh(InMesh) and FoodPiece(InSpec) on a new entity under the world's transient entity.
    protected FCk_Handle_FoodPiece Build_Piece(TSoftObjectPtr<UStaticMesh> InMesh, FTransform InWorld, FMars_FoodPiece_Spec InSpec)
    {
        auto Entity = utils_entity_lifetime::Request_CreateEntity(ck::TransientEntity());
        Track_ForCleanup(Entity);
        utils_transform::Add(Entity, InWorld, ECk_Replication::DoesNotReplicate);
        utils_runtime_mesh::Add(Entity, FCk_RuntimeMesh_Spec(InMesh));
        auto Piece = utils_foodpiece::Add(Entity, InSpec);
        Record(Piece);
        return Piece;
    }

    protected void Cut(FCk_Handle_FoodPiece InPiece, FVector InPositionCm, FVector InNormal)
    {
        auto Piece = InPiece;
        Piece.Request_Cut(FMars_Request_FoodPiece_Cut(Make_Plane(InPositionCm, InNormal)));
    }

    protected FCk_RuntimeMesh_PlaneLocal Make_Plane(FVector InPositionCm, FVector InNormal) const
    {
        auto Plane = FCk_RuntimeMesh_PlaneLocal();
        Plane.Set_PositionCm(InPositionCm);
        Plane.Set_Normal(InNormal);
        if (Math::Abs(InNormal.Z) < 0.9)
        { Plane.Set_Tangent(FVector::UpVector); }
        else
        { Plane.Set_Tangent(FVector::ForwardVector); }

        return Plane;
    }

    protected FCk_RuntimeMesh_Metrics Get_Metrics(FCk_Handle_FoodPiece InPiece) const
    {
        return utils_runtime_mesh::Get_Metrics(InPiece.Get_Geometry());
    }

    protected FVector Get_BoundsCenter(FCk_Handle_FoodPiece InPiece) const
    {
        const auto Metrics = Get_Metrics(InPiece);
        return (Metrics.Get_BoundsMinCm() + Metrics.Get_BoundsMaxCm()) * 0.5;
    }

    protected FTransform Get_World(FCk_Handle_FoodPiece InPiece) const
    {
        FCk_Handle Entity = InPiece;
        return utils_transform::Get_EntityCurrentTransform(Entity.As_Transform());
    }

    protected bool Get_HasReadied(FCk_Handle_FoodPiece InPiece) const
    {
        for (const auto& Readied : _Readied)
        {
            if (Readied == InPiece)
            { return true; }
        }

        return false;
    }

    protected int32 Get_CutCount(EMars_FoodPiece_CutOutcome InOutcome) const
    {
        auto Count = 0;
        for (const auto& Result : _Cuts)
        {
            if (Result.Outcome == InOutcome)
            { ++Count; }
        }

        return Count;
    }

    // The first OnCutResolved with InOutcome; a default result when there is none.
    protected FMars_FoodPiece_CutResult Get_FirstCut(EMars_FoodPiece_CutOutcome InOutcome) const
    {
        for (const auto& Result : _Cuts)
        {
            if (Result.Outcome == InOutcome)
            { return Result; }
        }

        return FMars_FoodPiece_CutResult();
    }

    // Every live piece under the world's transient entity in InLineage.
    protected TArray<FCk_Handle_FoodPiece> Get_LineagePieces(FGuid InLineage) const
    {
        TArray<FCk_Handle_FoodPiece> Pieces;
        for (auto Dependent : utils_entity_lifetime::Get_LifetimeDependents(ck::TransientEntity()))
        {
            if (ck::Is_NOT_Valid(Dependent) || utils_entity_lifetime::Get_IsPendingDestroy(Dependent, ECk_EntityLifetime_DestructionPhase::BeginDestroy)
                || Dependent.Is_FoodPiece() == false)
            { continue; }

            const auto Piece = Dependent.As_FoodPiece();
            if (Piece.Get_Lineage() == InLineage)
            { Pieces.Add(Piece); }
        }

        return Pieces;
    }

    private void Record(FCk_Handle_FoodPiece InPiece)
    {
        auto Piece = InPiece;
        Piece.BindTo_OnReady(FMars_Delegate_FoodPiece_OnReady(this, n"OnPieceReady"));
        Piece.BindTo_OnFailed(FMars_Delegate_FoodPiece_OnFailed(this, n"OnPieceFailed"));
        Piece.BindTo_OnCutResolved(FMars_Delegate_FoodPiece_OnCutResolved(this, n"OnPieceCutResolved"));
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Handlers
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void OnPieceReady(FCk_Handle_FoodPiece InPiece)
    {
        _Readied.Add(InPiece);
    }

    UFUNCTION()
    private void OnPieceFailed(FCk_Handle_FoodPiece InPiece, ECk_RuntimeMesh_SetupFailure InReason)
    {
        _Failures.Add(InReason);
    }

    UFUNCTION()
    private void OnPieceCutResolved(FCk_Handle_FoodPiece InSource, FMars_FoodPiece_CutResult InResult)
    {
        _CutSources.Add(InSource);
        _Cuts.Add(InResult);

        if (InResult.Outcome != EMars_FoodPiece_CutOutcome::Cut)
        { return; }

        Track_ForCleanup(InResult.Positive);
        Track_ForCleanup(InResult.Negative);
        Record(InResult.Positive);
        Record(InResult.Negative);
    }
}
