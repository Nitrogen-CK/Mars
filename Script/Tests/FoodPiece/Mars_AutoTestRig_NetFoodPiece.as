// The FoodPiece net tests' shared steps, on the world-item net rig. The server lays a floor at the test's own X (Z 5000),
// spawns whole foods 5 cm above it under the replicated spawn owner, waits until they are Ready (and the first at rest),
// cuts them and records every OnCutResolved, tracking every half a cut reports. What the client compares against goes out
// in one test-only replicated report fragment on the subject. Each machine counts the ensures raised since it began and
// logs one [FoodPieceNetTest] line. Every test ends clean: the server destroys what lies at its X and holds
// (End_Server); the client waits until no piece script is left at its X and its replay memo holds no lineage and no
// geometry (End_Client).

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

    // The check numbers the server's halves recorded in their ledgers.
    UPROPERTY()
    float PositiveCheckVolumeCm3 = 0.0;

    UPROPERTY()
    int32 PositiveCheckTriangles = 0;

    UPROPERTY()
    float NegativeCheckVolumeCm3 = 0.0;

    UPROPERTY()
    int32 NegativeCheckTriangles = 0;

    // How many uncut pieces the server's test left.
    UPROPERTY()
    int32 LeafCount = 0;

    UPROPERTY()
    int32 Serial = 0;
}

// What the per-frame sampler saw of one food entity: the frame it appeared, the frame it was first a FoodPiece and its
// standing then, and the first frame it stood. -1 for what has not happened.
struct FMars_TESTONLY_NetFoodPieceSighting
{
    int32 AppearFrame = -1;
    int32 PieceFrame = -1;
    EMars_FoodPiece_Standing FirstStanding = EMars_FoodPiece_Standing::Current;
    int32 StoodFrame = -1;
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
    // The server's test entity: the owner of the floor and of every slice the test makes by hand.
    protected FCk_Handle _ServerTestEntity;
    // In order: every slice the server's test made by hand (Slice_ByHand).
    protected TArray<FCk_RuntimeMesh_SliceResult> _ByHandSlices;

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
        _ServerTestEntity = InTestEntity;
        Spawn_ServerFloor(InTestEntity, _FloorTop);
    }

    // The whole food Spawn_ServerSlab spawns.
    protected UCk_InventoryItem_Definition Get_RigFoodItem()
    {
        return mars_items::Food_MeatSlab();
    }

    // The rig's food (the meat slab unless a test names another) 5 cm above the floor, as _Rock.
    protected void Spawn_ServerSlab()
    {
        _Rock = Spawn_ServerFood(Get_RigFoodItem(), _FloorTop + FVector(0.0, 0.0, 5.0));
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

    // The entity of InEntities whose replay recipe has InCuts cuts, the last keeping InSide; invalid when none does.
    protected FCk_Handle Find_ByRecipe(TArray<FCk_Handle> InEntities, int32 InCuts, EMars_FoodPiece_CutSide InSide)
    {
        for (const auto& Entity : InEntities)
        {
            const auto Replay = utils_foodpiece::TryGet_Replay(Entity);
            const auto Kept = Get_LastKept(Entity);
            if (Replay.IsSet() && Replay.GetValue().Piece.Data.Recipe.Cuts.Num() == InCuts && Kept.IsSet() && Kept.GetValue() == InSide)
            { return Entity; }
        }

        return FCk_Handle();
    }

    protected bool Get_IsPlaneEqual(FCk_RuntimeMesh_PlaneLocal InA, FCk_RuntimeMesh_PlaneLocal InB)
    {
        return InA.Get_PositionCm() == InB.Get_PositionCm() && InA.Get_Normal() == InB.Get_Normal() && InA.Get_Tangent() == InB.Get_Tangent();
    }

    //----------------------------------------------------------------------------------------------------------------------
    // The replicated ledger
    //----------------------------------------------------------------------------------------------------------------------

    // The display slot of the oil coat, as utils_cookstate lays the slots out.
    protected const int32 k_OilCoatSlot = 7;

    // Every whole food near InNear on this machine that is a FoodPiece (from its composition, before it is a world item).
    protected TArray<FCk_Handle_FoodPiece> Get_FoodPiecesNear(FVector InNear)
    {
        TArray<FCk_Handle_FoodPiece> Foods;
        for (auto Candidate : utils_entity_tag::ForEach_Entity(Get_SubjectEntity(), n"TAG_MarsWorldItem"))
        {
            if (Get_IsLive(Candidate) && Candidate.Is_Transform() && Candidate.Is_FoodPiece() && Get_IsNear(Candidate, InNear))
            { Foods.Add(Candidate.As_FoodPiece()); }
        }

        return Foods;
    }

    // The first whole food near InNear that is a FoodPiece; invalid when none is.
    protected FCk_Handle_FoodPiece Find_FoodPieceNear(FVector InNear)
    {
        const auto Foods = Get_FoodPiecesNear(InNear);
        if (Foods.Num() == 0)
        { return FCk_Handle_FoodPiece(); }

        return Foods[0];
    }

    protected bool Get_IsCookStateEqual(FMars_FoodPiece_CookState InA, FMars_FoodPiece_CookState InB)
    {
        if (InA.Sear.Num() != InB.Sear.Num() || InA.Batter.Num() != InB.Batter.Num())
        { return false; }

        for (int32 Index = 0; Index < InA.Sear.Num(); ++Index)
        {
            if (InA.Sear[Index] != InB.Sear[Index])
            { return false; }
        }

        for (int32 Index = 0; Index < InA.Batter.Num(); ++Index)
        {
            if (InA.Batter[Index] != InB.Batter[Index])
            { return false; }
        }

        return InA.OilCoat == InB.OilCoat && InA.Crumb == InB.Crumb && InA.Battered == InB.Battered;
    }

    // A raw cook state with InPosZSear on +Z and InOilCoat.
    protected FMars_FoodPiece_CookState Make_CookState(float32 InPosZSear, float32 InOilCoat)
    {
        auto CookState = FMars_FoodPiece_CookState();
        CookState.Sear[int32(EMars_FoodPiece_Face::PosZ)] = InPosZSear;
        CookState.OilCoat = InOilCoat;
        return CookState;
    }

    // The oil coat InPiece's display shows; unset until it has a Ready display.
    protected TOptional<float32> Get_ShownOilCoat(FCk_Handle_FoodPiece InPiece)
    {
        FCk_Handle Entity = InPiece;
        if (ck::Is_NOT_Valid(Entity) || Entity.Is_RuntimeMeshDisplay() == false)
        { return TOptional<float32>(); }

        const auto Display = Entity.As_RuntimeMeshDisplay();
        if (utils_runtime_mesh_display::Get_SetupState(Display) != ECk_RuntimeMesh_SetupState::Ready)
        { return TOptional<float32>(); }

        return TOptional<float32>(utils_runtime_mesh_display::Get_CustomPrimitiveDataFloat(Display, k_OilCoatSlot));
    }

    protected float64 Get_Now()
    {
        return System::GetGameTimeInSeconds();
    }

    //----------------------------------------------------------------------------------------------------------------------
    // The replay
    //----------------------------------------------------------------------------------------------------------------------

    // This machine's replay memo as counts.
    protected FMars_FoodPiece_ReplayTally Get_Tally()
    {
        return utils_foodpiece::Get_ReplayTally(ck::TransientEntity());
    }

    protected FString Describe_Tally()
    {
        const auto Tally = Get_Tally();
        return f"slices={Tally.Slices} built={Tally.Built} failed={Tally.Failed} lineages={Tally.Lineages} geometries={Tally.Geometries}";
    }

    // Every piece script near InNear on this machine that is a Ready FoodPiece.
    protected TArray<FCk_Handle_FoodPiece> Get_ReadyPiecesNear(FVector InNear)
    {
        TArray<FCk_Handle_FoodPiece> Ready;
        for (auto Entity : Get_PieceEntitiesNear(InNear))
        {
            if (Entity.Is_FoodPiece() && Entity.As_FoodPiece().Get_Status() == EMars_FoodPiece_Status::Ready)
            { Ready.Add(Entity.As_FoodPiece()); }
        }

        return Ready;
    }

    protected int32 Get_ReadyPieceCountNear(FVector InNear)
    {
        return Get_ReadyPiecesNear(InNear).Num();
    }

    // The piece of InPieces with InId; invalid when none has it.
    protected FCk_Handle_FoodPiece Find_ById(TArray<FCk_Handle_FoodPiece> InPieces, FGuid InId)
    {
        for (const auto& Piece : InPieces)
        {
            if (Piece.Get_Id() == InId)
            { return Piece; }
        }

        return FCk_Handle_FoodPiece();
    }

    // InPieces that compared InResult against the authority's numbers.
    protected int32 Get_CheckCount(TArray<FCk_Handle_FoodPiece> InPieces, EMars_FoodPiece_CheckResult InResult)
    {
        auto Count = 0;
        for (const auto& Piece : InPieces)
        {
            if (Piece.Get_CheckResult() == InResult)
            { ++Count; }
        }

        return Count;
    }

    // None of InPieces is still Unchecked.
    protected bool Get_AreChecked(TArray<FCk_Handle_FoodPiece> InPieces)
    {
        return Get_CheckCount(InPieces, EMars_FoodPiece_CheckResult::Unchecked) == 0;
    }

    //----------------------------------------------------------------------------------------------------------------------
    // The slab (server)
    //----------------------------------------------------------------------------------------------------------------------

    // Lays the floor, waits for the replicated spawn owner, spawns the slab and calls On_ServerSlabStill once it is Ready
    // and at rest.
    protected void Begin_ServerSlab(FCk_Handle InTestEntity)
    {
        Begin_ServerFloor(InTestEntity);
        WaitUntil(n"Is_ReplicatedSpawnOwnerPublished", n"OnRigOwnerPublished", k_SlowPolls);
    }

    protected void On_ServerSlabStill() {}

    UFUNCTION()
    private void OnRigOwnerPublished(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Spawn_ServerSlab();
        WaitUntil(n"Is_RigSlabStill", n"OnRigSlabStill", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_RigSlabStill(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Tick_SlabReadyAndStill());
    }

    UFUNCTION()
    private void OnRigSlabStill(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        On_ServerSlabStill();
    }

    // The middle of InPiece's local bounds on InAxis (0 X, 1 Y), as a plane with that axis as its normal.
    protected FCk_RuntimeMesh_PlaneLocal Make_MiddlePlane(FCk_Handle_FoodPiece InPiece, int32 InAxis)
    {
        const auto Metrics = utils_runtime_mesh::Get_Metrics(InPiece.Get_Geometry());
        const auto Centre = (Metrics.Get_BoundsMinCm() + Metrics.Get_BoundsMaxCm()) * 0.5;
        if (InAxis == 0)
        { return Make_Plane(FVector(Centre.X, 0.0, 0.0), FVector::ForwardVector, FVector::RightVector); }

        return Make_Plane(FVector(0.0, Centre.Y, 0.0), FVector::RightVector, FVector::ForwardVector);
    }

    //----------------------------------------------------------------------------------------------------------------------
    // By hand (server)
    //----------------------------------------------------------------------------------------------------------------------

    // Slices InGeometry along InPlane with InCap and default limits, the results owned by the test entity and recorded in
    // _ByHandSlices.
    protected void Slice_ByHand(FCk_Handle_RuntimeMesh InGeometry, FCk_RuntimeMesh_PlaneLocal InPlane, FCk_RuntimeMesh_Cap InCap)
    {
        auto Slice = FCk_Request_RuntimeMesh_Slice();
        Slice.Set_OperationID(FGuid::NewGuid());
        Slice.Set_ResultOwner(_ServerTestEntity);
        Slice.Set_Plane(InPlane);
        Slice.Set_Cap(InCap);
        utils_runtime_mesh::Request_Slice(InGeometry, Slice, FCk_Delegate_RuntimeMesh_OnSliceResolved(this, n"OnRigByHandSliced"));
    }

    UFUNCTION()
    private void OnRigByHandSliced(FCk_RuntimeMesh_SliceResult InResult)
    {
        _ByHandSlices.Add(InResult);
    }

    // InPiece's spec as its halves inherit it: identity, lineage, mass, cook state, definition, kind, recipe, tuners, cap
    // and body surface.
    protected FMars_FoodPiece_Spec Make_SourceSpec(FCk_Handle_FoodPiece InPiece)
    {
        auto Spec = FMars_FoodPiece_Spec(FMars_FoodPiece_Data(InPiece.Get_MassKg()), InPiece.Get_Tuners(), InPiece.Get_Cap(), InPiece.Get_BodyTuners());
        Spec.Data.Id = InPiece.Get_Id();
        Spec.Data.ParentId = InPiece.Get_ParentId();
        Spec.Data.Lineage = InPiece.Get_Lineage();
        Spec.Data.CookState = InPiece.Get_CookState();
        Spec.Data.Definition = InPiece.Get_Definition();
        Spec.Data.Kind = InPiece.Get_Kind();
        Spec.Data.Recipe = InPiece.Get_Recipe();
        return Spec;
    }

    // The birth of the InCut.Kept side of InSlice, as a commit builds it from InSource: a new Id, InSource as parent, its
    // lineage, tuners, cap, body, definition and kind, its share of the mass and the recipe of InSource plus InCut. It
    // names no source piece, so nothing commits; its world transform is the slab's.
    protected FMars_FoodPiece_Birth Make_ByHandBirth(FMars_FoodPiece_Spec InSource, FCk_RuntimeMesh_SliceResult InSlice, FMars_FoodPiece_RecipeCut InCut)
    {
        const auto Split = utils_foodpiece::Get_MassSplit(InSource.Data.MassKg, InSlice);
        const auto IsPositive = InCut.Kept == EMars_FoodPiece_CutSide::Positive;

        auto Spec = InSource;
        Spec.Data.Id = FGuid::NewGuid();
        Spec.Data.ParentId = InSource.Data.Id;
        Spec.Data.MassKg = IsPositive ? Split.PositiveKg : Split.NegativeKg;
        Spec.Data.Recipe.Cuts.Add(InCut);

        auto Birth = FMars_FoodPiece_Birth();
        Birth.Geometry = IsPositive ? InSlice.Get_Positive() : InSlice.Get_Negative();
        Birth.Spec = Spec;
        Birth.World = utils_transform::Get_EntityCurrentTransform(_Rock.As_Transform());
        return Birth;
    }

    // The piece script of InBirth under the replicated spawn owner, tracked.
    protected FCk_Handle Spawn_ByHand(FMars_FoodPiece_Birth InBirth)
    {
        auto Entity = utils_foodpiece::Request_SpawnCutPiece(Get_SubjectEntity(), InBirth);
        Track_ForCleanup(Entity);
        return Entity;
    }

    //----------------------------------------------------------------------------------------------------------------------
    // The two halves by hand (server)
    //----------------------------------------------------------------------------------------------------------------------

    protected const float32 k_StepSeconds = 1.5f;

    // The rig's food as its halves inherit it, taken when the by-hand slice is asked.
    protected FMars_FoodPiece_Spec _WholeSpec;
    // The two halves of the by-hand slice, held until a step spawns them.
    protected FMars_FoodPiece_Birth _BirthP;
    protected FMars_FoodPiece_Birth _BirthN;
    protected FCk_Handle _SpawnedP;
    protected FCk_Handle _SpawnedN;

    // The plane the by-hand slice cuts the rig's food along.
    protected FCk_RuntimeMesh_PlaneLocal Get_ByHandPlane()
    {
        return Make_CentrePlane();
    }

    // Slices _Rock's geometry along Get_ByHandPlane and holds its two births; On_ServerHalvesHeld once they are.
    protected void Begin_ByHandHalves()
    {
        auto Food = _Rock.As_FoodPiece();
        _WholeSpec = Make_SourceSpec(Food);
        Slice_ByHand(Food.Get_Geometry(), Get_ByHandPlane(), Food.Get_Cap());
        WaitUntil(n"Is_RigHalvesSliced", n"OnRigHalvesSliced", k_SlowPolls);
    }

    protected void On_ServerHalvesHeld() {}

    UFUNCTION()
    private void Is_RigHalvesSliced(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_ByHandSlices.Num() >= 1);
    }

    UFUNCTION()
    private void OnRigHalvesSliced(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Slice = _ByHandSlices[0];
        Assert_True(Slice.Get_Outcome() == ECk_RuntimeMesh_SliceOutcome::Succeeded, f"the by-hand slice succeeded (got {Slice.Get_Outcome() :n})");
        if (Slice.Get_Outcome() != ECk_RuntimeMesh_SliceOutcome::Succeeded)
        {
            End_Server();
            return;
        }

        _BirthP = Make_ByHandBirth(_WholeSpec, Slice, FMars_FoodPiece_RecipeCut(Get_ByHandPlane(), EMars_FoodPiece_CutSide::Positive));
        _BirthN = Make_ByHandBirth(_WholeSpec, Slice, FMars_FoodPiece_RecipeCut(Get_ByHandPlane(), EMars_FoodPiece_CutSide::Negative));
        On_ServerHalvesHeld();
    }

    protected void Spawn_P()
    {
        _SpawnedP = Spawn_ByHand(_BirthP);
    }

    protected void Spawn_N()
    {
        _SpawnedN = Spawn_ByHand(_BirthN);
    }

    protected void Destroy_Whole()
    {
        if (ck::IsValid(_Rock))
        { utils_entity_lifetime::Request_DestroyEntity(_Rock); }
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Standing (either machine, sampled every frame)
    //----------------------------------------------------------------------------------------------------------------------

    // Frames in which two standing pieces stand of which one was cut from the other.
    protected int32 _Both = 0;
    // Frames, from the first frame a whole food stood, in which nothing near the test's X stands.
    protected int32 _Neither = 0;
    protected int32 _SampleFrame = 0;
    protected bool _WholeStood = false;
    // In parallel: every food entity seen near the test's X, and what the sampler saw of it.
    protected TArray<FCk_Handle> _Seen;
    protected TArray<FMars_TESTONLY_NetFoodPieceSighting> _Sightings;
    private FCk_Handle_Timer _SampleTimer;
    private bool _BothLogged = false;

    // Every live whole food and piece script near InNear on this machine, FoodPiece or not.
    protected TArray<FCk_Handle> Get_FoodEntitiesNear(FVector InNear)
    {
        auto Entities = Get_PieceEntitiesNear(InNear);
        for (auto Candidate : utils_entity_tag::ForEach_Entity(Get_SubjectEntity(), n"TAG_MarsWorldItem"))
        {
            if (Get_IsLive(Candidate) && Candidate.Is_Transform() && Get_IsNear(Candidate, InNear))
            { Entities.Add(Candidate); }
        }

        return Entities;
    }

    // A Ready FoodPiece whose standing is Current.
    protected bool Get_Stands(FCk_Handle InEntity)
    {
        return Get_IsLive(InEntity) && InEntity.Is_FoodPiece() && InEntity.As_FoodPiece().Get_Status() == EMars_FoodPiece_Status::Ready
            && InEntity.As_FoodPiece().Get_Standing() == EMars_FoodPiece_Standing::Current;
    }

    protected TArray<FCk_Handle_FoodPiece> Get_StandingNear(FVector InNear)
    {
        TArray<FCk_Handle_FoodPiece> Standing;
        for (auto Entity : Get_FoodEntitiesNear(InNear))
        {
            if (Get_Stands(Entity))
            { Standing.Add(Entity.As_FoodPiece()); }
        }

        return Standing;
    }

    // InEntity's standing; unset while it is not a FoodPiece.
    protected TOptional<EMars_FoodPiece_Standing> Get_StandingOf(FCk_Handle InEntity)
    {
        if (Get_IsLive(InEntity) == false || InEntity.Is_FoodPiece() == false)
        { return TOptional<EMars_FoodPiece_Standing>(); }

        return TOptional<EMars_FoodPiece_Standing>(InEntity.As_FoodPiece().Get_Standing());
    }

    protected bool Get_IsSuperseded(FCk_Handle InEntity)
    {
        const auto Standing = Get_StandingOf(InEntity);
        return Standing.IsSet() && Standing.GetValue() == EMars_FoodPiece_Standing::Superseded;
    }

    // InEntity's display is Ready and drawn.
    protected bool Get_IsShown(FCk_Handle InEntity)
    {
        if (Get_IsLive(InEntity) == false || InEntity.Is_RuntimeMeshDisplay() == false)
        { return false; }

        return utils_runtime_mesh_display::Get_Visibility(InEntity.As_RuntimeMeshDisplay()) == ECk_EnableDisable::Enable;
    }

    // Call on both machines once Begin_Rig ran: samples every frame until End_Sampling.
    protected void Begin_Sampling(FCk_Handle InTestEntity)
    {
        _SampleTimer = utils_timer::Create_Tick(InTestEntity, FCk_Delegate_Timer(this, n"OnRigSample"));
    }

    protected void End_Sampling()
    {
        if (ck::Is_NOT_Valid(_SampleTimer))
        { return; }

        utils_timer::UnbindFrom_OnUpdate(_SampleTimer, FCk_Delegate_Timer(this, n"OnRigSample"));
        utils_entity_lifetime::Request_DestroyEntity(_SampleTimer.H());
        _SampleTimer = FCk_Handle_Timer();
    }

    // Called every sampled frame after the counts, with every food entity near the test's X and those that stand.
    protected void On_Sample(TArray<FCk_Handle> InEntities, TArray<FCk_Handle_FoodPiece> InStanding) {}

    protected FString Describe_Standing()
    {
        return f"Both={_Both} Neither={_Neither} frames={_SampleFrame}";
    }

    // InEntity's sighting; a default one (every frame -1) when it was never seen.
    protected FMars_TESTONLY_NetFoodPieceSighting Get_Sighting(FCk_Handle InEntity)
    {
        for (int32 Index = 0; Index < _Seen.Num(); ++Index)
        {
            if (_Seen[Index] == InEntity)
            { return _Sightings[Index]; }
        }

        return FMars_TESTONLY_NetFoodPieceSighting();
    }

    // Frames from InEntity's first sighting to its first standing frame; unset while it has not stood.
    protected TOptional<int32> Get_StandDelay(FCk_Handle InEntity)
    {
        const auto Sighting = Get_Sighting(InEntity);
        if (Sighting.AppearFrame < 0 || Sighting.StoodFrame < 0)
        { return TOptional<int32>(); }

        return TOptional<int32>(Sighting.StoodFrame - Sighting.AppearFrame);
    }

    protected FString Describe_Recipe(FCk_Handle_FoodPiece InPiece)
    {
        auto Text = f"{InPiece.Get_Recipe().Cuts.Num()} cuts [";
        for (const auto& Cut : InPiece.Get_Recipe().Cuts)
        { Text += f"{Cut.Plane.Get_PositionCm().ToString()} {Cut.Kept :n}; "; }

        return Text + "]";
    }

    UFUNCTION()
    private void OnRigSample(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        ++_SampleFrame;
        const auto Entities = Get_FoodEntitiesNear(_FloorTop);
        TArray<FCk_Handle_FoodPiece> Standing;
        for (auto Entity : Entities)
        {
            auto Index = -1;
            for (int32 SeenIndex = 0; SeenIndex < _Seen.Num(); ++SeenIndex)
            {
                if (_Seen[SeenIndex] == Entity)
                { Index = SeenIndex; }
            }

            if (Index < 0)
            {
                auto Sighting = FMars_TESTONLY_NetFoodPieceSighting();
                Sighting.AppearFrame = _SampleFrame;
                _Seen.Add(Entity);
                _Sightings.Add(Sighting);
                Index = _Seen.Num() - 1;
            }

            if (Entity.Is_FoodPiece() && _Sightings[Index].PieceFrame < 0)
            {
                _Sightings[Index].PieceFrame = _SampleFrame;
                _Sightings[Index].FirstStanding = Entity.As_FoodPiece().Get_Standing();
            }

            if (Get_Stands(Entity) == false)
            { continue; }

            Standing.Add(Entity.As_FoodPiece());
            if (_Sightings[Index].StoodFrame < 0)
            { _Sightings[Index].StoodFrame = _SampleFrame; }

            if (Entity.As_FoodPiece().Get_IsWhole())
            { _WholeStood = true; }
        }

        auto IsBoth = false;
        for (int32 A = 0; A < Standing.Num(); ++A)
        {
            for (int32 B = 0; B < Standing.Num(); ++B)
            {
                if (A == B || utils_foodpiece::Get_IsCutFrom(Standing[A], Standing[B]) == false)
                { continue; }

                IsBoth = true;
                if (_BothLogged == false)
                {
                    _BothLogged = true;
                    const auto Machine = Get_MachineName();
                    const auto TestName = GetClass().GetName();
                    const auto Piece = Describe_Recipe(Standing[A]);
                    const auto Ancestor = Describe_Recipe(Standing[B]);
                    Log(f"[FoodPieceNetTest] {TestName} {Machine}: both stand at frame {_SampleFrame}: [{Standing[A].ToString()}] {Piece} was cut from [{Standing[B].ToString()}] {Ancestor}");
                }
            }
        }

        if (IsBoth)
        { ++_Both; }

        if (_WholeStood && Standing.Num() == 0)
        { ++_Neither; }

        On_Sample(Entities, Standing);
    }

    //----------------------------------------------------------------------------------------------------------------------
    // The clean ending
    //----------------------------------------------------------------------------------------------------------------------

    // The last step of the server: every piece script and world item at the test's X is destroyed, and the server holds
    // while that replicates.
    protected void End_Server()
    {
        for (auto Piece : Get_PieceEntitiesNear(_FloorTop))
        { utils_entity_lifetime::Request_DestroyEntity(Piece); }

        for (auto Candidate : utils_entity_tag::ForEach_Entity(Get_SubjectEntity(), n"TAG_MarsWorldItem"))
        {
            if (Get_IsLive(Candidate) && Candidate.Is_Transform() && Get_IsNear(Candidate, _FloorTop))
            { utils_entity_lifetime::Request_DestroyEntity(Candidate); }
        }

        WaitSeconds(k_ServerHoldSeconds, n"OnRigServerEnded");
    }

    UFUNCTION()
    private void OnRigServerEnded(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        FinishSuccess();
    }

    // The last step of the client: waits until no piece script is left at its X and its replay memo is empty.
    protected void End_Client()
    {
        WaitUntil(n"Is_RigClientClean", n"OnRigClientClean", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_RigClientClean(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto Tally = Get_Tally();
        auto Result = OutResult;
        Result.Set(Get_PieceEntitiesNear(_FloorTop).Num() == 0 && Tally.Lineages == 0 && Tally.Geometries == 0);
    }

    UFUNCTION()
    private void OnRigClientClean(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        FinishSuccess();
    }
}
