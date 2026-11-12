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
// Only the authority cuts: a copy without authority drops every SetCookState and answers every Cut RefusedNoAuthority.
// A succeeded slice of a source that replicates commits in two stages (Commit_Replicated, then utils_foodpiece::Add_Born);
// any other commits on the slice's own entities at once (Commit).
class UMars_Processor_FoodPiece_HandleRequests : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _RunAfter.Add(n"/Script/Angelscript.Mars_Processor_FoodBoard_HandleRequests");
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

        // A piece's ledger and its cuts are the authority's: a copy without authority writes nothing.
        if (utils_net::Get_HasAuthority(InHandle) == false)
        {
            for (int32 Index = 0; Index < CutRequests.Num(); ++Index)
            { Broadcast_CutResolved(Drain.Piece, FMars_FoodPiece_CutResult(EMars_FoodPiece_CutOutcome::RefusedNoAuthority)); }

            return;
        }

        for (const auto& Request : SetCookStateRequests)
        { InState.CookState = Request.CookState; }

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
        WorldEntity.AddOrGet_Fragment(FMars_Fragment_FoodPiece_PendingCuts).Entries.Add(FMars_FoodPiece_CutInFlight(OperationID, Piece, InRequest.Plane));

        auto Geometry = Piece.Get_Geometry();
        utils_runtime_mesh::Request_Slice(Geometry, Slice, FCk_Delegate_RuntimeMesh_OnSliceResolved(this, n"OnSliceResolved"));
    }

    // The single resolution of every submitted slice, from RuntimeMesh's drain (or its submission, for a slice it could not
    // queue). A Succeeded slice commits; any other outcome hands the piece back Ready. A piece that is gone or being
    // destroyed has its halves destroyed and nothing is broadcast; a live piece no longer waiting on this operation is a
    // broken ledger: it ensures, with the same recovery.
    UFUNCTION()
    private void OnSliceResolved(FCk_RuntimeMesh_SliceResult InResult)
    {
        // A closing world cancels every queued slice; its pieces and the ledger go with it.
        FCk_Handle WorldEntity = _Handle;
        if (ck::Is_NOT_Valid(WorldEntity) || utils_entity_lifetime::Get_IsPendingDestroy(WorldEntity, ECk_EntityLifetime_DestructionPhase::BeginDestroy))
        { return; }

        const auto OperationID = InResult.Get_OperationID();
        const auto InFlight = Take_CutInFlight(WorldEntity, OperationID);
        auto Piece = InFlight.Piece;

        // An expected absence, not a defect: a board or a test tore the piece down while its slice was queued.
        if (Piece.Get_IsGone())
        {
            Destroy_Halves(InResult);
            return;
        }

        if (ck::EnsureIfNot(Get_IsAwaiting(Piece, OperationID),
            f"[FoodPiece] a live piece [{Piece.ToString()}] no longer waits on cut [{OperationID.ToString(EGuidFormats::Short)}]: only that cut's resolution clears it"))
        {
            Destroy_Halves(InResult);
            return;
        }

        if (InResult.Get_Outcome() == ECk_RuntimeMesh_SliceOutcome::Succeeded)
        {
            if (utils_foodpiece::Get_CutsIntoReplicatedPieces(Piece))
            { Commit_Replicated(Piece, InFlight.Plane, InResult); }
            else
            { Commit(Piece, InResult); }

            return;
        }

        auto& State = Piece.Get_Fragment(FMars_Fragment_FoodPiece);
        State.PendingCut.Reset();
        State.Status = EMars_FoodPiece_Status::Ready;

        const auto Outcome = utils_foodpiece::Get_CutOutcome(InResult.Get_Outcome());

        Broadcast_CutResolved(Piece, FMars_FoodPiece_CutResult(Outcome, InResult.Get_Outcome()));
    }

    // The cook state the halves inherit: the source's ledger, or the last SetCookState still queued on it. A slice resolves
    // a frame or more after it was submitted, so a write sent while the piece was Cutting may not have drained yet; the
    // source dies at the commit, so without this the write would be lost.
    private FMars_FoodPiece_CookState Get_CookStateAtCommit(const FCk_Handle_FoodPiece& InSource, const FMars_Fragment_FoodPiece& InState) const
    {
        if (InSource.Has_Fragment(FMars_Fragment_FoodPiece_Requests) == false)
        { return InState.CookState; }

        const auto& Pending = InSource.Get_Fragment(FMars_Fragment_FoodPiece_Requests).SetCookStateRequests;
        if (Pending.Num() == 0)
        { return InState.CookState; }

        return Pending.Last().CookState;
    }

    // Removes and returns the ledger's entry for InOperationID (an entry with no piece when there is none). Every result
    // answers a slice this processor entered, so a missing entry is a broken ledger.
    private FMars_FoodPiece_CutInFlight Take_CutInFlight(FCk_Handle& InWorld, const FGuid& InOperationID)
    {
        const auto HasLedger = InWorld.Has_Fragment(FMars_Fragment_FoodPiece_PendingCuts);
        if (ck::EnsureIfNot(HasLedger, f"[FoodPiece] cut [{InOperationID.ToString(EGuidFormats::Short)}] resolved with no PendingCuts ledger on [{InWorld.ToString()}]"))
        { return FMars_FoodPiece_CutInFlight(); }

        auto& Entries = InWorld.Get_Fragment(FMars_Fragment_FoodPiece_PendingCuts).Entries;
        for (int32 Index = 0; Index < Entries.Num(); ++Index)
        {
            if (Entries[Index].OperationID != InOperationID)
            { continue; }

            const auto Entry = Entries[Index];
            Entries.RemoveAt(Index);
            return Entry;
        }

        ck::EnsureIfNot(false, f"[FoodPiece] cut [{InOperationID.ToString(EGuidFormats::Short)}] resolved but is not in the PendingCuts ledger");
        return FMars_FoodPiece_CutInFlight();
    }

    // The live piece's pending cut is InOperationID: set at submission, cleared only by that cut's resolution.
    private bool Get_IsAwaiting(const FCk_Handle_FoodPiece& InPiece, const FGuid& InOperationID)
    {
        const auto PendingCut = InPiece.Get_Fragment(FMars_Fragment_FoodPiece).PendingCut;
        return PendingCut.IsSet() && PendingCut.GetValue() == InOperationID;
    }

    // Exactly once per succeeded slice: each half gets the source's current world transform and a FoodPiece of its own
    // (new Id, ParentId = the source, the source's lineage, cook state, definition, kind, tuners, cap and body surface, its
    // share of the mass), then OnCutResolved reports both and the source is destroyed.
    private void Commit(FCk_Handle_FoodPiece& InSource, const FCk_RuntimeMesh_SliceResult& InResult)
    {
        const auto State = InSource.Get_Fragment(FMars_Fragment_FoodPiece);
        FCk_Handle SourceEntity = InSource;
        const auto SourceWorld = utils_transform::Get_EntityCurrentTransform(SourceEntity.As_Transform());
        const auto Split = utils_foodpiece::Get_MassSplit(State.MassKg, InResult);

        auto HalfSpec = FMars_FoodPiece_Spec(FMars_FoodPiece_Data(), InSource.Get_Tuners(), InSource.Get_Cap(), InSource.Get_BodyTuners());
        HalfSpec.Data.Lineage = State.Lineage;
        HalfSpec.Data.ParentId = State.Id;
        HalfSpec.Data.CookState = Get_CookStateAtCommit(InSource, State);
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

        auto Result = FMars_FoodPiece_CutResult(EMars_FoodPiece_CutOutcome::Cut, InResult.Get_Outcome());
        Result.Positive = Positive;
        Result.Negative = Negative;
        Broadcast_CutResolved(InSource, Result);

        utils_entity_lifetime::Request_DestroyEntity(InSource);
    }

    // The first stage of a succeeded slice of a source that replicates: each half is spawned as a piece script
    // (utils_foodpiece::Request_SpawnCutPiece) with the slice's geometry for the authority to share, a spec as Commit builds
    // it plus a new Id and the source's recipe with this cut appended, and the cook state the source holds now. The source
    // stays Cutting with its PendingCommit until the second half composes and broadcasts the cut (utils_foodpiece::Add_Born).
    // A source with no recipe definition cannot be rebuilt on another machine, and a half that does not spawn fails the
    // commit: it ensured, what was spawned and sliced is destroyed, and the source is Ready again with Failed.
    private void Commit_Replicated(FCk_Handle_FoodPiece& InSource, const FCk_RuntimeMesh_PlaneLocal& InPlane, const FCk_RuntimeMesh_SliceResult& InResult)
    {
        const auto State = InSource.Get_Fragment(FMars_Fragment_FoodPiece);
        const auto Recipe = InSource.Get_Recipe();
        if (ck::EnsureIfNot(Recipe.Definition.IsValid(), f"[FoodPiece] [{InSource.ToString()}] replicates but has no recipe definition: its halves could not be rebuilt on another machine"))
        {
            Fail_Commit(InSource, InResult);
            return;
        }

        FCk_Handle SourceEntity = InSource;
        // The spawn runs in this processor's slice callback: scope the script world to the source's.
        const auto WorldContext = FAngelscriptGameThreadScopeWorldContext(utils_entity_lifetime::Get_WorldForEntity(SourceEntity));

        const auto Split = utils_foodpiece::Get_MassSplit(State.MassKg, InResult);
        auto HalfSpec = FMars_FoodPiece_Spec(FMars_FoodPiece_Data(), InSource.Get_Tuners(), InSource.Get_Cap(), InSource.Get_BodyTuners());
        HalfSpec.Data.Lineage = State.Lineage;
        HalfSpec.Data.ParentId = State.Id;
        HalfSpec.Data.CookState = Get_CookStateAtCommit(InSource, State);
        HalfSpec.Data.Definition = State.Definition;
        HalfSpec.Data.Kind = State.Kind;
        HalfSpec.Data.Recipe = Recipe;

        auto Birth = FMars_FoodPiece_Birth();
        Birth.World = utils_transform::Get_EntityCurrentTransform(SourceEntity.As_Transform());
        Birth.Source = InSource;

        Birth.Geometry = InResult.Get_Positive();
        Birth.Spec = Make_HalfSpec(HalfSpec, FMars_FoodPiece_RecipeCut(InPlane, EMars_FoodPiece_CutSide::Positive), Split.PositiveKg);
        auto Positive = utils_foodpiece::Request_SpawnCutPiece(SourceEntity, Birth);

        Birth.Geometry = InResult.Get_Negative();
        Birth.Spec = Make_HalfSpec(HalfSpec, FMars_FoodPiece_RecipeCut(InPlane, EMars_FoodPiece_CutSide::Negative), Split.NegativeKg);
        auto Negative = utils_foodpiece::Request_SpawnCutPiece(SourceEntity, Birth);

        // A spawn that returned invalid already ensured.
        if (ck::Is_NOT_Valid(Positive) || ck::Is_NOT_Valid(Negative))
        {
            if (ck::IsValid(Positive))
            { utils_entity_lifetime::Request_DestroyEntity(Positive); }

            if (ck::IsValid(Negative))
            { utils_entity_lifetime::Request_DestroyEntity(Negative); }

            Fail_Commit(InSource, InResult);
            return;
        }

        Positive.Get_Fragment(FMars_Fragment_FoodPiece_Birth).Birth.Sibling = Negative;
        Negative.Get_Fragment(FMars_Fragment_FoodPiece_Birth).Birth.Sibling = Positive;
        InSource.Add_Fragment(FMars_Fragment_FoodPiece_PendingCommit(Positive, Negative, InResult.Get_Outcome()));
    }

    // InSpec as one half: its share of the mass, a new Id and InCut appended to its recipe.
    private FMars_FoodPiece_Spec Make_HalfSpec(const FMars_FoodPiece_Spec& InSpec, const FMars_FoodPiece_RecipeCut& InCut, float InMassKg) const
    {
        auto Spec = InSpec;
        Spec.Data.MassKg = InMassKg;
        Spec.Data.Id = FGuid::NewGuid();
        Spec.Data.Recipe.Cuts.Add(InCut);
        return Spec;
    }

    // The slice's results are destroyed and the source is whole and Ready again; its cut reports Failed.
    private void Fail_Commit(FCk_Handle_FoodPiece& InSource, const FCk_RuntimeMesh_SliceResult& InResult)
    {
        Destroy_Halves(InResult);

        auto& SourceState = InSource.Get_Fragment(FMars_Fragment_FoodPiece);
        SourceState.PendingCut.Reset();
        SourceState.Status = EMars_FoodPiece_Status::Ready;
        Broadcast_CutResolved(InSource, FMars_FoodPiece_CutResult(EMars_FoodPiece_CutOutcome::Failed, InResult.Get_Outcome()));
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
