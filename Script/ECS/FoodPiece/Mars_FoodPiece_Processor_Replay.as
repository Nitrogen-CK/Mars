// Every frame, for each entity whose replay waits (FMars_Tag_FoodPiece_AwaitsReplay), on a machine without the slice: walks
// the entity's recipe through the world's replay memo (FMars_Fragment_FoodPiece_ReplayMemo on this processor's handle, the
// world's transient entity). The lineage and the definition's import are found or added; an import still pending waits and
// one that failed resolves Failed (ImportFailed). From the root, each cut steps to the side it kept of a node already split
// along that same plane; a node split along another plane is a defect (Failed, PlaneMismatch, with an ensure), a node whose
// slice was refused resolves Failed (SliceRejected), a node in flight waits, and an uncut node is sliced (the spec's cap,
// default limits, results owned by the world entity), at most k_MaxReplayFlights at once, then waits. So every cut is
// sliced once on this machine however many pieces share it, and a missing ancestor costs one slice per missing cut. At the
// end of the recipe the node's geometry is shared onto the entity (Built). Each entity resolves once: the tag goes, the
// tally counts it, a failure logs one line, and OnReplayResolved is raised last. Nothing it builds is read by simulation.
class UMars_Processor_FoodPiece_Replay : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";

    // The operation being submitted while Request_Slice runs: RuntimeMesh answers a slice it cannot queue on that stack.
    private TOptional<FGuid> _Submitting;

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Fragment_FoodPiece_Replay);
        Query.Require(FMars_Tag_FoodPiece_AwaitsReplay);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle)
    {
        FCk_Handle WorldEntity = _Handle;
        const auto Spec = InHandle.Get_Fragment(FMars_Fragment_FoodPiece_Replay).Spec;
        const auto Recipe = Spec.Piece.Data.Recipe;
        const auto LineageId = Spec.Piece.Data.Lineage;

        const auto ImportIndex = FindOrAdd_Import(WorldEntity, Recipe.Definition, Spec.Mesh);
        const auto LineageIndex = FindOrAdd_Lineage(WorldEntity, LineageId, Recipe.Definition);

        const auto Import = WorldEntity.Get_Fragment(FMars_Fragment_FoodPiece_ReplayMemo).Imports[ImportIndex].Geometry;
        const auto ImportState = utils_runtime_mesh::Get_SetupState(Import);
        if (ImportState == ECk_RuntimeMesh_SetupState::Pending)
        { return; }

        if (ImportState != ECk_RuntimeMesh_SetupState::Ready)
        {
            Resolve(InHandle, Make_Failure(EMars_FoodPiece_ReplayFailure::ImportFailed, TOptional<ECk_RuntimeMesh_SliceOutcome>()));
            return;
        }

        auto NodeIndex = 0;
        for (const auto& Cut : Recipe.Cuts)
        {
            const auto Node = WorldEntity.Get_Fragment(FMars_Fragment_FoodPiece_ReplayMemo).Lineages[LineageIndex].Nodes[NodeIndex];
            if (Node.State == EMars_FoodPiece_ReplayNodeState::Rejected)
            {
                Resolve(InHandle, Make_Failure(EMars_FoodPiece_ReplayFailure::SliceRejected, TOptional<ECk_RuntimeMesh_SliceOutcome>(Node.Rejection)));
                return;
            }

            if (Node.State == EMars_FoodPiece_ReplayNodeState::InFlight)
            { return; }

            if (Node.State == EMars_FoodPiece_ReplayNodeState::Leaf)
            {
                auto Flight = FMars_FoodPiece_ReplayFlight();
                Flight.Lineage = LineageId;
                Flight.Node = NodeIndex;
                Submit(Flight, Cut.Plane, Spec.Piece.Cap);
                return;
            }

            if (ck::EnsureIfNot(utils_foodpiece::Get_IsSamePlane(Cut.Plane, Node.SplitPlane),
                f"[FoodPiece] [{InHandle.ToString()}]'s recipe cuts a piece of lineage [{LineageId.ToString(EGuidFormats::Short)}] along [{Cut.Plane.Get_PositionCm().ToString()} n {Cut.Plane.Get_Normal().ToString()}], which this machine split along [{Node.SplitPlane.Get_PositionCm().ToString()} n {Node.SplitPlane.Get_Normal().ToString()}]: a piece is cut once"))
            {
                Resolve(InHandle, Make_Failure(EMars_FoodPiece_ReplayFailure::PlaneMismatch, TOptional<ECk_RuntimeMesh_SliceOutcome>()));
                return;
            }

            NodeIndex = Cut.Kept == EMars_FoodPiece_CutSide::Positive ? Node.Positive : Node.Negative;
        }

        Build(InHandle, LineageIndex, NodeIndex);
    }

    // The recipe's geometry shared onto InEntity, which the node then records as its piece.
    private void Build(FCk_Handle& InEntity, int32 InLineageIndex, int32 InNodeIndex)
    {
        FCk_Handle WorldEntity = _Handle;
        const auto Geometry = WorldEntity.Get_Fragment(FMars_Fragment_FoodPiece_ReplayMemo).Lineages[InLineageIndex].Nodes[InNodeIndex].Geometry;

        // A rejected share already ensured (RuntimeMesh): the entity stays a non-piece.
        const auto Shared = utils_runtime_mesh::Add_SharedGeometry(InEntity, Geometry);
        if (ck::Is_NOT_Valid(Shared))
        {
            Resolve(InEntity, Make_Failure(EMars_FoodPiece_ReplayFailure::None, TOptional<ECk_RuntimeMesh_SliceOutcome>()));
            return;
        }

        WorldEntity.Get_Fragment(FMars_Fragment_FoodPiece_ReplayMemo).Lineages[InLineageIndex].Nodes[InNodeIndex].Piece = InEntity;

        auto Built = FMars_FoodPiece_ReplayResult();
        Built.State = EMars_FoodPiece_ReplayState::Built;
        Resolve(InEntity, Built);
    }

    private FMars_FoodPiece_ReplayResult Make_Failure(EMars_FoodPiece_ReplayFailure InFailure, TOptional<ECk_RuntimeMesh_SliceOutcome> InSliceOutcome) const
    {
        auto Result = FMars_FoodPiece_ReplayResult();
        Result.State = EMars_FoodPiece_ReplayState::Failed;
        Result.Failure = InFailure;
        Result.SliceOutcome = InSliceOutcome;
        return Result;
    }

    // Every write lands before the broadcast: a handler composes on the entity.
    private void Resolve(FCk_Handle& InEntity, const FMars_FoodPiece_ReplayResult& InResult)
    {
        auto& Replay = InEntity.Get_Fragment(FMars_Fragment_FoodPiece_Replay);
        Replay.State = InResult.State;
        Replay.Failure = InResult.Failure;
        Replay.SliceOutcome = InResult.SliceOutcome;
        const auto Recipe = Replay.Spec.Piece.Data.Recipe;
        InEntity.Request_TryRemove(FMars_Tag_FoodPiece_AwaitsReplay);

        FCk_Handle WorldEntity = _Handle;
        auto& Tally = WorldEntity.Get_Fragment(FMars_Fragment_FoodPiece_ReplayMemo).Tally;
        if (InResult.State == EMars_FoodPiece_ReplayState::Built)
        { Tally.Built += 1; }
        else
        {
            Tally.Failed += 1;
            auto Outcome = FString("-");
            if (InResult.SliceOutcome.IsSet())
            { Outcome = f"{InResult.SliceOutcome.GetValue() :n}"; }

            Warning(f"[FoodPiece] [{InEntity.ToString()}] replay failed: {InResult.Failure :n} (slice {Outcome}), definition [{Recipe.Definition.ToString()}], {Recipe.Cuts.Num()} cuts");
        }

        if (InEntity.Has_Fragment(FMars_Fragment_FoodPiece_ReplaySignals) == false)
        { return; }

        // Handlers compose and dress the piece: scope the script world to the entity's.
        const auto WorldContext = FAngelscriptGameThreadScopeWorldContext(utils_entity_lifetime::Get_WorldForEntity(InEntity));
        InEntity.Get_Fragment(FMars_Fragment_FoodPiece_ReplaySignals).OnReplayResolved.Broadcast(InEntity, InResult.State);
    }

    // The flight and the node's InFlight state are recorded, and the slice counted, before the call.
    private void Submit(FMars_FoodPiece_ReplayFlight InFlight, const FCk_RuntimeMesh_PlaneLocal& InPlane, const FCk_RuntimeMesh_Cap& InCap)
    {
        FCk_Handle WorldEntity = _Handle;
        auto& Memo = WorldEntity.Get_Fragment(FMars_Fragment_FoodPiece_ReplayMemo);
        if (Memo.Flights.Num() >= utils_foodpiece::k_MaxReplayFlights)
        { return; }

        const auto LineageIndex = Find_Lineage(Memo, InFlight.Lineage);
        auto& Node = Memo.Lineages[LineageIndex].Nodes[InFlight.Node];
        Node.State = EMars_FoodPiece_ReplayNodeState::InFlight;
        Node.SplitPlane = InPlane;
        const auto Geometry = Node.Geometry;

        auto Flight = InFlight;
        Flight.OperationID = FGuid::NewGuid();
        Memo.Flights.Add(Flight);
        Memo.Tally.Slices += 1;

        auto Slice = FCk_Request_RuntimeMesh_Slice();
        Slice.Set_OperationID(Flight.OperationID);
        Slice.Set_ResultOwner(WorldEntity);
        Slice.Set_Plane(InPlane);
        Slice.Set_Cap(InCap);

        _Submitting = TOptional<FGuid>(Flight.OperationID);
        utils_runtime_mesh::Request_Slice(Geometry, Slice, FCk_Delegate_RuntimeMesh_OnSliceResolved(this, n"OnReplaySliceResolved"));
        _Submitting.Reset();
    }

    // The single resolution of every replay slice. Succeeded: the node is Split into two uncut nodes holding the results.
    // A full queue or a source not Ready answered on the submitting stack: the node is uncut again and the slice uncounted, so
    // it is tried next frame. Any other outcome: the node is Rejected with it, and any result is destroyed.
    UFUNCTION()
    private void OnReplaySliceResolved(FCk_RuntimeMesh_SliceResult InResult)
    {
        // A closing world cancels every queued slice; the memo goes with it.
        FCk_Handle WorldEntity = _Handle;
        if (ck::Is_NOT_Valid(WorldEntity) || utils_entity_lifetime::Get_IsPendingDestroy(WorldEntity, ECk_EntityLifetime_DestructionPhase::BeginDestroy))
        { return; }

        const auto OperationID = InResult.Get_OperationID();
        const auto IsAnswered = WorldEntity.Has_Fragment(FMars_Fragment_FoodPiece_ReplayMemo);
        if (ck::EnsureIfNot(IsAnswered, f"[FoodPiece] replay slice [{OperationID.ToString(EGuidFormats::Short)}] resolved with no replay memo on [{WorldEntity.ToString()}]"))
        {
            Destroy_Results(InResult);
            return;
        }

        auto& Memo = WorldEntity.Get_Fragment(FMars_Fragment_FoodPiece_ReplayMemo);
        auto FlightIndex = -1;
        for (int32 Index = 0; Index < Memo.Flights.Num(); ++Index)
        {
            if (Memo.Flights[Index].OperationID == OperationID)
            { FlightIndex = Index; }
        }

        if (ck::EnsureIfNot(FlightIndex >= 0, f"[FoodPiece] replay slice [{OperationID.ToString(EGuidFormats::Short)}] resolved but is not in flight"))
        {
            Destroy_Results(InResult);
            return;
        }

        const auto Flight = Memo.Flights[FlightIndex];
        Memo.Flights.RemoveAt(FlightIndex);

        // A lineage is dropped only with no slice in flight.
        const auto LineageIndex = Find_Lineage(Memo, Flight.Lineage);
        if (ck::EnsureIfNot(LineageIndex >= 0, f"[FoodPiece] replay slice [{OperationID.ToString(EGuidFormats::Short)}] resolved for lineage [{Flight.Lineage.ToString(EGuidFormats::Short)}], which the memo no longer holds"))
        {
            Destroy_Results(InResult);
            return;
        }

        auto& Nodes = Memo.Lineages[LineageIndex].Nodes;
        const auto Outcome = InResult.Get_Outcome();
        if (Outcome == ECk_RuntimeMesh_SliceOutcome::Succeeded)
        {
            const auto PositiveIndex = Nodes.Num();
            auto Positive = FMars_FoodPiece_ReplayNode();
            Positive.Geometry = InResult.Get_Positive();
            Nodes.Add(Positive);

            auto Negative = FMars_FoodPiece_ReplayNode();
            Negative.Geometry = InResult.Get_Negative();
            Nodes.Add(Negative);

            Nodes[Flight.Node].State = EMars_FoodPiece_ReplayNodeState::Split;
            Nodes[Flight.Node].Positive = PositiveIndex;
            Nodes[Flight.Node].Negative = PositiveIndex + 1;
            return;
        }

        const auto IsRefusedOnSubmit = _Submitting.IsSet() && _Submitting.GetValue() == OperationID
            && (Outcome == ECk_RuntimeMesh_SliceOutcome::RejectedLimit || Outcome == ECk_RuntimeMesh_SliceOutcome::NotReady);
        if (IsRefusedOnSubmit)
        {
            Nodes[Flight.Node].State = EMars_FoodPiece_ReplayNodeState::Leaf;
            Memo.Tally.Slices -= 1;
        }
        else
        {
            Nodes[Flight.Node].State = EMars_FoodPiece_ReplayNodeState::Rejected;
            Nodes[Flight.Node].Rejection = Outcome;
        }

        Destroy_Results(InResult);
    }

    // The index of InDefinition's import, created on a local entity under InWorld when there is none.
    private int32 FindOrAdd_Import(FCk_Handle& InWorld, FGameplayTag InDefinition, TSoftObjectPtr<UStaticMesh> InMesh)
    {
        {
            const auto& Memo = InWorld.AddOrGet_Fragment(FMars_Fragment_FoodPiece_ReplayMemo);
            for (int32 Index = 0; Index < Memo.Imports.Num(); ++Index)
            {
                if (Memo.Imports[Index].Definition == InDefinition)
                { return Index; }
            }
        }

        auto Entity = utils_entity_lifetime::Request_CreateEntity(InWorld);
        utils_transform::Add(Entity, FTransform::Identity, ECk_Replication::DoesNotReplicate);

        auto Import = FMars_FoodPiece_ReplayImport();
        Import.Definition = InDefinition;
        Import.Geometry = utils_runtime_mesh::Add(Entity, FCk_RuntimeMesh_Spec(InMesh));

        auto& Imports = InWorld.Get_Fragment(FMars_Fragment_FoodPiece_ReplayMemo).Imports;
        Imports.Add(Import);
        return Imports.Num() - 1;
    }

    // The index of InLineage, whose orphan clock restarts; a new lineage's root is its definition's import. The first
    // lineage also creates the keeper.
    private int32 FindOrAdd_Lineage(FCk_Handle& InWorld, FGuid InLineage, FGameplayTag InDefinition)
    {
        {
            auto& Memo = InWorld.Get_Fragment(FMars_Fragment_FoodPiece_ReplayMemo);
            const auto Found = Find_Lineage(Memo, InLineage);
            if (Found >= 0)
            {
                Memo.Lineages[Found].OrphanSeconds = 0.0f;
                return Found;
            }
        }

        if (utils_foodpiece::Get_IsLiveEntity(InWorld.Get_Fragment(FMars_Fragment_FoodPiece_ReplayMemo).Keeper) == false)
        {
            auto Keeper = utils_entity_lifetime::Request_CreateEntity(InWorld);
            Keeper.Add_Fragment(FMars_Tag_FoodPiece_ReplayKeeper());
            InWorld.Get_Fragment(FMars_Fragment_FoodPiece_ReplayMemo).Keeper = Keeper;
        }

        auto& Memo = InWorld.Get_Fragment(FMars_Fragment_FoodPiece_ReplayMemo);
        auto Root = FMars_FoodPiece_ReplayNode();
        for (const auto& Import : Memo.Imports)
        {
            if (Import.Definition == InDefinition)
            { Root.Geometry = Import.Geometry; }
        }

        auto Lineage = FMars_FoodPiece_ReplayLineage();
        Lineage.Lineage = InLineage;
        Lineage.Definition = InDefinition;
        Lineage.Nodes.Add(Root);
        Memo.Lineages.Add(Lineage);
        return Memo.Lineages.Num() - 1;
    }

    private int32 Find_Lineage(const FMars_Fragment_FoodPiece_ReplayMemo& InMemo, FGuid InLineage) const
    {
        for (int32 Index = 0; Index < InMemo.Lineages.Num(); ++Index)
        {
            if (InMemo.Lineages[Index].Lineage == InLineage)
            { return Index; }
        }

        return -1;
    }

    private void Destroy_Results(const FCk_RuntimeMesh_SliceResult& InResult)
    {
        if (ck::IsValid(InResult.Get_Positive()))
        { utils_entity_lifetime::Request_DestroyEntity(InResult.Get_Positive()); }

        if (ck::IsValid(InResult.Get_Negative()))
        { utils_entity_lifetime::Request_DestroyEntity(InResult.Get_Negative()); }
    }
}

// Every frame, on the keeper entity the Replay processor creates with the first lineage: each lineage with no slice in
// flight, no node in flight and no node whose piece is alive ages; past k_MemoGraceSeconds it is dropped and every geometry
// it rebuilt (all but the root, the import) is destroyed. While any of those holds, its age is 0. With no lineage left,
// every import and the keeper are destroyed and the memo is empty.
class UMars_Processor_FoodPiece_ReplayKeeper : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _RunAfter.Add(n"/Script/Angelscript.Mars_Processor_FoodPiece_Replay");

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Tag_FoodPiece_ReplayKeeper);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle)
    {
        FCk_Handle WorldEntity = _Handle;
        const auto HasMemo = WorldEntity.Has_Fragment(FMars_Fragment_FoodPiece_ReplayMemo);
        if (ck::EnsureIfNot(HasMemo && WorldEntity.Get_Fragment(FMars_Fragment_FoodPiece_ReplayMemo).Keeper == InHandle,
            f"[FoodPiece] replay keeper [{InHandle.ToString()}] is not the keeper of [{WorldEntity.ToString()}]'s replay memo"))
        {
            utils_entity_lifetime::Request_DestroyEntity(InHandle);
            return;
        }

        const auto DeltaSeconds = float32(InDeltaT.Get_Seconds());
        TArray<FCk_Handle> Dropped;
        {
            auto& Memo = WorldEntity.Get_Fragment(FMars_Fragment_FoodPiece_ReplayMemo);
            for (int32 Index = Memo.Lineages.Num() - 1; Index >= 0; --Index)
            {
                if (Get_IsInUse(Memo, Memo.Lineages[Index]))
                {
                    Memo.Lineages[Index].OrphanSeconds = 0.0f;
                    continue;
                }

                Memo.Lineages[Index].OrphanSeconds += DeltaSeconds;
                if (Memo.Lineages[Index].OrphanSeconds <= utils_foodpiece::k_MemoGraceSeconds)
                { continue; }

                const auto& Nodes = Memo.Lineages[Index].Nodes;
                for (int32 NodeIndex = 1; NodeIndex < Nodes.Num(); ++NodeIndex)
                {
                    FCk_Handle Geometry = Nodes[NodeIndex].Geometry;
                    Dropped.Add(Geometry);
                }

                Memo.Lineages.RemoveAt(Index);
            }

            if (Memo.Lineages.Num() == 0)
            {
                for (const auto& Import : Memo.Imports)
                {
                    FCk_Handle Geometry = Import.Geometry;
                    Dropped.Add(Geometry);
                }

                Memo = FMars_Fragment_FoodPiece_ReplayMemo();
                Dropped.Add(InHandle);
            }
        }

        for (auto Entity : Dropped)
        {
            if (ck::IsValid(Entity))
            { utils_entity_lifetime::Request_DestroyEntity(Entity); }
        }
    }

    private bool Get_IsInUse(const FMars_Fragment_FoodPiece_ReplayMemo& InMemo, const FMars_FoodPiece_ReplayLineage& InLineage) const
    {
        for (const auto& Flight : InMemo.Flights)
        {
            if (Flight.Lineage == InLineage.Lineage)
            { return true; }
        }

        for (const auto& Node : InLineage.Nodes)
        {
            if (Node.State == EMars_FoodPiece_ReplayNodeState::InFlight || utils_foodpiece::Get_IsLiveEntity(Node.Piece))
            { return true; }
        }

        return false;
    }
}
