// The FoodPiece net tests' shared steps, on the world-item net rig. The server lays a floor at the test's own X (Z 5000),
// spawns whole foods 5 cm above it under the replicated spawn owner, waits until they are Ready (and the first at rest),
// cuts them and records every OnCutResolved, tracking every half a cut reports. What the client compares against goes out
// in one test-only replicated report fragment on the subject. Each machine counts the ensures raised since it began and
// logs one [FoodPieceNetTest] line.

// Written by the server only, through Get_Fragment + Request_MarkReplicationDirty (test-only: a feature's processors are
// the only writers in game code).
struct FMars_Fragment_TESTONLY_NetFoodPieceReport
{
    UPROPERTY()
    FGuid SourceId;

    UPROPERTY()
    FGuid Lineage;

    UPROPERTY()
    FGuid PositiveId;

    UPROPERTY()
    FGuid NegativeId;

    UPROPERTY()
    float PositiveMassKg = 0.0;

    UPROPERTY()
    float NegativeMassKg = 0.0;

    // The parent a test expects of its deepest piece.
    UPROPERTY()
    FGuid DeepParentId;

    UPROPERTY()
    FVector PositiveLocation = FVector::ZeroVector;

    UPROPERTY()
    FVector NegativeLocation = FVector::ZeroVector;

    UPROPERTY()
    float64 PositiveYaw = 0.0;

    UPROPERTY()
    int32 Serial = 0;
}

UCLASS(Abstract)
class UMars_AutoTestRig_NetFoodPiece : UMars_AutoTestRig_NetWorldItem
{
    default _TimeoutSeconds = 25.0f;

    protected const float64 k_FloorZ = 5000.0;
    // A piece or a world item within this of the test's X (in XY) is the test's.
    protected const float64 k_NearCm = 400.0;

    protected FVector _FloorTop;
    private int32 _EnsuresAtStart = 0;

    // In parallel: one entry per OnCutResolved of a piece this machine cut.
    protected TArray<FCk_Handle_FoodPiece> _CutSources;
    protected TArray<FMars_FoodPiece_CutResult> _Cuts;

    // Call first, on both machines.
    protected void Begin_Rig(float64 InX)
    {
        _FloorTop = FVector(InX, 0.0, k_FloorZ);
        _EnsuresAtStart = utils_ensure::Get_EnsureCount();
        Add_PieceReport();
    }

    protected bool Get_IsServer()
    {
        return utils_net::Get_HasAuthority(Get_SubjectEntity());
    }

    protected FString Get_MachineName()
    {
        return Get_IsServer() ? "server" : "client";
    }

    protected int32 Get_EnsureDelta()
    {
        return utils_ensure::Get_EnsureCount() - _EnsuresAtStart;
    }

    protected void Log_Result(FString InText)
    {
        const auto Machine = Get_MachineName();
        const auto Ensures = Get_EnsureDelta();
        const auto TestName = GetClass().GetName();
        Log(f"[FoodPieceNetTest] {TestName} {Machine}: {InText} ensures={Ensures}");
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Server
    //----------------------------------------------------------------------------------------------------------------------

    // InItem's whole food under the replicated spawn owner, at InLocation, tracked. The entity under construction.
    protected FCk_Handle Spawn_ServerFood(UCk_InventoryItem_Definition InItem, FVector InLocation)
    {
        auto SpawnParams = UMars_FoodItem_EntityScript::Params();
        SpawnParams.SpawnTransform = FTransform(FRotator::ZeroRotator, InLocation);
        SpawnParams.Definition = utils_held_item::Make_DefinitionSoft(InItem);
        SpawnParams.Mode = EMars_WorldItem_Mode::World;

        auto Owner = utils_mars_net::Get_ReplicatedSpawnOwner(Get_SubjectEntity());
        auto Food = utils_world_item::Request_SpawnWorldEntity(Owner, UMars_FoodItem_EntityScript, SpawnParams).Get_EntityUnderConstruction();
        Track_ForCleanup(Food);
        return Food;
    }

    // Before the spawn owner is published: the floor the foods lie on.
    protected void Begin_ServerFloor(FCk_Handle InTestEntity)
    {
        Spawn_ServerFloor(InTestEntity, _FloorTop);
    }

    // The meat slab 5 cm above the floor, as _Rock.
    protected void Spawn_ServerSlab()
    {
        _Rock = Spawn_ServerFood(mars_items::Food_MeatSlab(), _FloorTop + FVector(0.0, 0.0, 5.0));
    }

    protected bool Get_IsCookStateZero(FMars_FoodPiece_CookState InCookState)
    {
        for (const auto Sear : InCookState.Sear)
        {
            if (Sear != 0.0f)
            { return false; }
        }

        for (const auto Batter : InCookState.Batter)
        {
            if (Batter != 0.0f)
            { return false; }
        }

        return InCookState.OilCoat == 0.0f && InCookState.Crumb == 0.0f && InCookState.Battered == 0.0f;
    }

    // InEntity is a constructed food item whose piece is Ready.
    protected bool Get_IsFoodReady(FCk_Handle InEntity)
    {
        return ck::IsValid(InEntity) && InEntity.Has_Fragment(FMars_Feature_WorldItem) && InEntity.Is_FoodPiece()
            && InEntity.As_FoodPiece().Get_Status() == EMars_FoodPiece_Status::Ready;
    }

    // Call once per frame from a predicate: _Rock is Ready and at rest.
    protected bool Tick_SlabReadyAndStill()
    {
        const auto Still = Tick_RockStill();
        return Still && Get_IsFoodReady(_Rock);
    }

    protected FCk_RuntimeMesh_PlaneLocal Make_Plane(FVector InPositionCm, FVector InNormal, FVector InTangent)
    {
        auto Plane = FCk_RuntimeMesh_PlaneLocal();
        Plane.Set_PositionCm(InPositionCm);
        Plane.Set_Normal(InNormal);
        Plane.Set_Tangent(InTangent);
        return Plane;
    }

    // The cut every test opens with: through the origin, normal +X, tangent +Y.
    protected FCk_RuntimeMesh_PlaneLocal Make_CentrePlane()
    {
        return Make_Plane(FVector::ZeroVector, FVector::ForwardVector, FVector::RightVector);
    }

    // Records InPiece's OnCutResolved and asks for the cut.
    protected void Cut(FCk_Handle_FoodPiece InPiece, FCk_RuntimeMesh_PlaneLocal InPlane)
    {
        auto Piece = InPiece;
        Piece.BindTo_OnCutResolved(FMars_Delegate_FoodPiece_OnCutResolved(this, n"OnRigCutResolved"));
        Piece.Request_Cut(FMars_Request_FoodPiece_Cut(InPlane));
    }

    // Called inside the OnCutResolved broadcast, after it is recorded.
    protected void On_CutResolved(FCk_Handle_FoodPiece InSource, FMars_FoodPiece_CutResult InResult) {}

    protected int32 Get_CutCount(EMars_FoodPiece_CutOutcome InOutcome)
    {
        auto Count = 0;
        for (const auto& Result : _Cuts)
        {
            if (Result.Outcome == InOutcome)
            { ++Count; }
        }

        return Count;
    }

    protected FMars_Fragment_TESTONLY_NetFoodPieceReport Make_CutReport(FCk_Handle_FoodPiece InSource, FMars_FoodPiece_CutResult InResult)
    {
        auto Report = Get_PieceReport();
        // The source may already be gone: its halves name it.
        Report.SourceId = InResult.Positive.Get_ParentId();
        Report.Lineage = InResult.Positive.Get_Lineage();
        Report.PositiveId = InResult.Positive.Get_Id();
        Report.NegativeId = InResult.Negative.Get_Id();
        Report.PositiveMassKg = InResult.Positive.Get_MassKg();
        Report.NegativeMassKg = InResult.Negative.Get_MassKg();
        return Report;
    }

    UFUNCTION()
    private void OnRigCutResolved(FCk_Handle_FoodPiece InSource, FMars_FoodPiece_CutResult InResult)
    {
        _CutSources.Add(InSource);
        _Cuts.Add(InResult);
        if (InResult.Outcome == EMars_FoodPiece_CutOutcome::Cut)
        {
            Track_ForCleanup(InResult.Positive);
            Track_ForCleanup(InResult.Negative);
        }

        On_CutResolved(InSource, InResult);
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Report
    //----------------------------------------------------------------------------------------------------------------------

    protected void Add_PieceReport()
    {
        auto Subject = Get_SubjectEntity();
        if (Subject.Has_Fragment(FMars_Fragment_TESTONLY_NetFoodPieceReport) == false)
        { Subject.Add_Fragment(FMars_Fragment_TESTONLY_NetFoodPieceReport(), ECk_Replication::Replicates); }
    }

    protected FMars_Fragment_TESTONLY_NetFoodPieceReport Get_PieceReport()
    {
        return Get_SubjectEntity().Get_Fragment(FMars_Fragment_TESTONLY_NetFoodPieceReport);
    }

    // InReport with the next serial, published.
    protected void Publish_PieceReport(FMars_Fragment_TESTONLY_NetFoodPieceReport InReport)
    {
        auto Subject = Get_SubjectEntity();
        auto& Report = Subject.Get_Fragment(FMars_Fragment_TESTONLY_NetFoodPieceReport);
        const auto Serial = Report.Serial;
        Report = InReport;
        Report.Serial = Serial + 1;
        Subject.Request_MarkReplicationDirty(FMars_Fragment_TESTONLY_NetFoodPieceReport);
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Either machine
    //----------------------------------------------------------------------------------------------------------------------

    protected bool Get_IsNear(FCk_Handle InEntity, FVector InNear)
    {
        const auto Location = Get_RootLocation(InEntity);
        return FVector2D(Location.X - InNear.X, Location.Y - InNear.Y).Size() < k_NearCm;
    }

    protected bool Get_IsLive(FCk_Handle InEntity)
    {
        return ck::IsValid(InEntity) && utils_entity_lifetime::Get_IsPendingDestroy(InEntity, ECk_EntityLifetime_DestructionPhase::BeginDestroy) == false;
    }

    // Every live piece script near InNear on this machine.
    protected TArray<FCk_Handle> Get_PieceEntitiesNear(FVector InNear)
    {
        TArray<FCk_Handle> Pieces;
        for (auto Candidate : utils_entity_tag::ForEach_Entity(Get_SubjectEntity(), n"TAG_MarsFoodPiece"))
        {
            if (Get_IsLive(Candidate) && Candidate.Is_Transform() && Get_IsNear(Candidate, InNear))
            { Pieces.Add(Candidate); }
        }

        return Pieces;
    }

    protected int32 Get_WorldItemCountNear(FVector InNear)
    {
        auto Count = 0;
        for (auto Candidate : utils_entity_tag::ForEach_Entity(Get_SubjectEntity(), n"TAG_MarsWorldItem"))
        {
            if (Get_IsLive(Candidate) && Candidate.Is_Transform() && Get_IsNear(Candidate, InNear))
            { ++Count; }
        }

        return Count;
    }

    // The side InEntity's replay spec says its last cut kept; unset without a replay spec or a cut.
    protected TOptional<EMars_FoodPiece_CutSide> Get_LastKept(FCk_Handle InEntity)
    {
        const auto Replay = utils_foodpiece::TryGet_Replay(InEntity);
        if (Replay.IsSet() == false || Replay.GetValue().Piece.Data.Recipe.Cuts.Num() == 0)
        { return TOptional<EMars_FoodPiece_CutSide>(); }

        return TOptional<EMars_FoodPiece_CutSide>(Replay.GetValue().Piece.Data.Recipe.Cuts.Last().Kept);
    }

    // The entity of InEntities whose last cut kept InSide; invalid when none does.
    protected FCk_Handle Find_ByKept(TArray<FCk_Handle> InEntities, EMars_FoodPiece_CutSide InSide)
    {
        for (const auto& Entity : InEntities)
        {
            const auto Kept = Get_LastKept(Entity);
            if (Kept.IsSet() && Kept.GetValue() == InSide)
            { return Entity; }
        }

        return FCk_Handle();
    }

    protected bool Get_IsPlaneEqual(FCk_RuntimeMesh_PlaneLocal InA, FCk_RuntimeMesh_PlaneLocal InB)
    {
        return InA.Get_PositionCm() == InB.Get_PositionCm() && InA.Get_Normal() == InB.Get_Normal() && InA.Get_Tangent() == InB.Get_Tangent();
    }
}
