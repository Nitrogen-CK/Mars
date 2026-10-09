// One drain's refusals, broadcast once every request is applied.
struct FMars_FoodPiece_Drain
{
    FCk_Handle_FoodPiece Piece;
    TArray<EMars_FoodPiece_CutOutcome> Refusals;
}

// Drains SetCookState requests (the last wins), then Cut requests in order. A piece already cutting refuses RefusedBusy
// and one that is not Ready RefusedNotReady; otherwise the slice is submitted with portion limits derived from the piece's
// tuners, the piece is Cutting, and the operation is entered in the PendingCuts ledger on this processor's handle: the
// world's transient entity, which also owns the halves. Refusals broadcast after the drain. Every submitted slice resolves
// in OnSliceResolved, exactly once: RuntimeMesh answers a slice it cannot queue (its world-wide queue is full) on the
// submitting call stack, so that rejection resolves inside this drain and is not retried.
class UMars_Processor_FoodPiece_HandleRequests : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _MarkedDirtyBy = FMars_Fragment_FoodPiece_Requests;

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_FoodPiece);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle,
                       FMars_Fragment_FoodPiece_Requests& InRequests,
                       FMars_Fragment_FoodPiece& InState)
    {
        auto Drain = FMars_FoodPiece_Drain();
        Drain.Piece = InHandle.As_FoodPiece();

        TArray<FMars_Request_FoodPiece_SetCookState> SetCookStateRequests = InRequests.SetCookStateRequests;
        TArray<FMars_Request_FoodPiece_Cut> CutRequests = InRequests.CutRequests;

        // InRequests is invalid past this line; removing before broadcasting lets re-entrant requests survive.
        Drain.Piece.Request_TryRemove(FMars_Fragment_FoodPiece_Requests);

        for (const auto& Request : SetCookStateRequests)
        { InState.CookState = Request.CookState; }

        if (SetCookStateRequests.Num() > 0)
        { ck::Trace(f"[FoodPiece] [{Drain.Piece.ToString()}] cook state set"); }

        for (const auto& Request : CutRequests)
        { Apply_Cut(Drain, InState, Request); }

        for (const auto Refusal : Drain.Refusals)
        { Broadcast_CutResolved(Drain.Piece, FMars_FoodPiece_CutResult(Refusal)); }
    }

    private void Apply_Cut(FMars_FoodPiece_Drain& InDrain, FMars_Fragment_FoodPiece& InState, const FMars_Request_FoodPiece_Cut& InRequest)
    {
        if (InState.PendingCut.IsSet())
        {
            InDrain.Refusals.Add(EMars_FoodPiece_CutOutcome::RefusedBusy);
            return;
        }

        if (InState.Status != EMars_FoodPiece_Status::Ready)
        {
            InDrain.Refusals.Add(EMars_FoodPiece_CutOutcome::RefusedNotReady);
            return;
        }

        auto Piece = InDrain.Piece;
        FCk_Handle WorldEntity = _Handle;

        auto Limits = FCk_RuntimeMesh_CutLimits();
        Limits.Set_MinimumOutputVolumeCm3(Piece.Get_MinimumPortionVolumeCm3());
        Limits.Set_MinimumNormalExtentCm(Piece.Get_Tuners().MinPortionThicknessCm);

        const auto OperationID = FGuid::NewGuid();
        auto Slice = FCk_Request_RuntimeMesh_Slice();
        Slice.Set_OperationID(OperationID);
        Slice.Set_ResultOwner(WorldEntity);
        Slice.Set_Plane(InRequest.Plane);
        Slice.Set_Cap(Piece.Get_Cap());
        Slice.Set_Limits(Limits);

        // Entered before submitting: a slice RuntimeMesh cannot queue resolves on this call stack.
        InState.PendingCut = TOptional<FGuid>(OperationID);
        InState.Status = EMars_FoodPiece_Status::Cutting;
        WorldEntity.AddOrGet_Fragment(FMars_Fragment_FoodPiece_PendingCuts).Entries.Add(FMars_FoodPiece_CutInFlight(OperationID, Piece));

        ck::Trace(f"[FoodPiece] [{Piece.ToString()}] cut submitted as [{OperationID.ToString(EGuidFormats::Short)}]");

        auto Geometry = Piece.Get_Geometry();
        utils_runtime_mesh::Request_Slice(Geometry, Slice, FCk_Delegate_RuntimeMesh_OnSliceResolved(this, n"OnSliceResolved"));
    }

    // The single resolution of every submitted slice, from RuntimeMesh's drain (or its submission, for a slice it could not
    // queue). A Succeeded slice commits; any other outcome hands the piece back Ready. A piece that is gone, being
    // destroyed, or no longer waiting on this operation is stale: its halves are destroyed and nothing is broadcast.
    UFUNCTION()
    private void OnSliceResolved(FCk_RuntimeMesh_SliceResult InResult)
    {
        // A closing world cancels every queued slice; its pieces and the ledger go with it.
        FCk_Handle WorldEntity = _Handle;
        if (ck::Is_NOT_Valid(WorldEntity) || utils_entity_lifetime::Get_IsPendingDestroy(WorldEntity, ECk_EntityLifetime_DestructionPhase::BeginDestroy))
        { return; }

        const auto OperationID = InResult.Get_OperationID();
        auto Piece = Take_CutInFlight(WorldEntity, OperationID);
        if (Get_IsStale(Piece, OperationID))
        {
            ck::Trace(f"[FoodPiece] cut [{OperationID.ToString(EGuidFormats::Short)}] resolved {InResult.Get_Outcome() :n} for a piece that no longer waits on it: discarded");
            Destroy_Halves(InResult);
            return;
        }

        if (InResult.Get_Outcome() == ECk_RuntimeMesh_SliceOutcome::Succeeded)
        {
            Commit(Piece, InResult);
            return;
        }

        auto& State = Piece.Get_Fragment(FMars_Fragment_FoodPiece);
        State.PendingCut.Reset();
        State.Status = EMars_FoodPiece_Status::Ready;

        const auto Outcome = utils_foodpiece::Get_CutOutcome(InResult.Get_Outcome());
        ck::Trace(f"[FoodPiece] [{Piece.ToString()}] cut {Outcome :n} ({InResult.Get_Outcome() :n}): the piece is whole");

        Broadcast_CutResolved(Piece, FMars_FoodPiece_CutResult(Outcome, InResult.Get_Outcome()));
    }

    // Removes and returns the ledger's piece for InOperationID. Every result answers a slice this processor entered, so a
    // missing entry is a broken ledger.
    private FCk_Handle_FoodPiece Take_CutInFlight(FCk_Handle& InWorld, const FGuid& InOperationID)
    {
        const auto HasLedger = InWorld.Has_Fragment(FMars_Fragment_FoodPiece_PendingCuts);
        if (ck::EnsureIfNot(HasLedger, f"[FoodPiece] cut [{InOperationID.ToString(EGuidFormats::Short)}] resolved with no PendingCuts ledger on [{InWorld.ToString()}]"))
        { return FCk_Handle_FoodPiece(); }

        auto& Entries = InWorld.Get_Fragment(FMars_Fragment_FoodPiece_PendingCuts).Entries;
        for (int32 Index = 0; Index < Entries.Num(); ++Index)
        {
            if (Entries[Index].OperationID != InOperationID)
            { continue; }

            const auto Piece = Entries[Index].Piece;
            Entries.RemoveAt(Index);
            return Piece;
        }

        ck::EnsureIfNot(false, f"[FoodPiece] cut [{InOperationID.ToString(EGuidFormats::Short)}] resolved but is not in the PendingCuts ledger");
        return FCk_Handle_FoodPiece();
    }

    private bool Get_IsStale(const FCk_Handle_FoodPiece& InPiece, const FGuid& InOperationID)
    {
        if (ck::Is_NOT_Valid(InPiece) || utils_entity_lifetime::Get_IsPendingDestroy(InPiece, ECk_EntityLifetime_DestructionPhase::BeginDestroy))
        { return true; }

        const auto PendingCut = InPiece.Get_Fragment(FMars_Fragment_FoodPiece).PendingCut;
        return PendingCut.IsSet() == false || PendingCut.GetValue() != InOperationID;
    }

    // Exactly once per succeeded slice: each half gets the source's current world transform and a FoodPiece of its own
    // (new Id, ParentId = the source, the source's lineage, cook state, definition, kind, tuners and cap, its share of the
    // mass), then OnCutResolved reports both and the source is destroyed.
    private void Commit(FCk_Handle_FoodPiece& InSource, const FCk_RuntimeMesh_SliceResult& InResult)
    {
        const auto State = InSource.Get_Fragment(FMars_Fragment_FoodPiece);
        FCk_Handle SourceEntity = InSource;
        const auto SourceWorld = utils_transform::Get_EntityCurrentTransform(SourceEntity.As_Transform());
        const auto Split = utils_foodpiece::Get_MassSplit(State.MassKg, InResult);

        auto HalfSpec = FMars_FoodPiece_Spec(FMars_FoodPiece_Data(), InSource.Get_Tuners(), InSource.Get_Cap());
        HalfSpec.Data.Lineage = State.Lineage;
        HalfSpec.Data.ParentId = State.Id;
        HalfSpec.Data.CookState = State.CookState;
        HalfSpec.Data.Definition = State.Definition;
        HalfSpec.Data.Kind = State.Kind;

        HalfSpec.Data.MassKg = Split.PositiveKg;
        const auto Positive = Compose_Half(InResult.Get_Positive(), SourceWorld, HalfSpec);

        HalfSpec.Data.MassKg = Split.NegativeKg;
        const auto Negative = Compose_Half(InResult.Get_Negative(), SourceWorld, HalfSpec);

        const auto HalvesComposed = ck::IsValid(Positive) && ck::IsValid(Negative);
        if (ck::EnsureIfNot(HalvesComposed, f"[FoodPiece] [{InSource.ToString()}] could not compose the halves of its cut"))
        {
            Destroy_Halves(InResult);

            auto& SourceState = InSource.Get_Fragment(FMars_Fragment_FoodPiece);
            SourceState.PendingCut.Reset();
            SourceState.Status = EMars_FoodPiece_Status::Ready;
            Broadcast_CutResolved(InSource, FMars_FoodPiece_CutResult(EMars_FoodPiece_CutOutcome::Failed, InResult.Get_Outcome()));
            return;
        }

        ck::Trace(f"[FoodPiece] [{InSource.ToString()}] cut into [{Positive.ToString()}] {Split.PositiveKg :.4} kg and [{Negative.ToString()}] {Split.NegativeKg :.4} kg");

        auto Result = FMars_FoodPiece_CutResult(EMars_FoodPiece_CutOutcome::Cut, InResult.Get_Outcome());
        Result.Positive = Positive;
        Result.Negative = Negative;
        Broadcast_CutResolved(InSource, Result);

        utils_entity_lifetime::Request_DestroyEntity(InSource);
    }

    private FCk_Handle_FoodPiece Compose_Half(const FCk_Handle_RuntimeMesh& InGeometry, const FTransform& InWorld, const FMars_FoodPiece_Spec& InSpec)
    {
        FCk_Handle Entity = InGeometry;
        utils_transform::Add(Entity, InWorld, ECk_Replication::DoesNotReplicate);
        return utils_foodpiece::Add(Entity, InSpec);
    }

    private void Destroy_Halves(const FCk_RuntimeMesh_SliceResult& InResult)
    {
        if (ck::IsValid(InResult.Get_Positive()))
        { utils_entity_lifetime::Request_DestroyEntity(InResult.Get_Positive()); }

        if (ck::IsValid(InResult.Get_Negative()))
        { utils_entity_lifetime::Request_DestroyEntity(InResult.Get_Negative()); }
    }

    private void Broadcast_CutResolved(FCk_Handle_FoodPiece& InSource, const FMars_FoodPiece_CutResult& InResult)
    {
        if (InSource.Has_Fragment(FMars_Fragment_FoodPiece_Signals))
        { InSource.Get_Fragment(FMars_Fragment_FoodPiece_Signals).OnCutResolved.Broadcast(InSource, InResult); }
    }
}
