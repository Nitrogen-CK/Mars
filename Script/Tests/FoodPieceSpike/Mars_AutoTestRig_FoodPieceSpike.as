// Test-only rig for rebuilding a cut food piece on a client from a recipe: the food definition plus the ordered list of
// planes the authority cut its lineage with, each with the side it kept, all in the definition mesh's local frame. The
// authority cuts real FoodPiece joints through the FoodPiece cut request and publishes every finished lineage as a
// replicated record (the recipe, the digest of the imported joint and of every kept half). The client imports the
// definition mesh itself, replays each recipe straight through RuntimeMesh's slice (the definition's cap, default
// tolerance, island policy and the framework's minimum rejecting limits), keeping every slice result in a memo of
// prefixes so a sibling never slices twice, and compares digests. A digest is the volume's bits, a CRC over the
// centroid's bits, one over the bounds' bits, the triangle and vertex counts and a CRC over the local vertex list's bits.

enum EMars_TESTONLY_FoodPieceSpike_Side
{
    Positive,
    Negative
}

enum EMars_TESTONLY_FoodPieceSpike_Keep
{
    Positive,
    Negative,
    Both
}

struct FMars_TESTONLY_FoodPieceSpike_Cut
{
    // Exactly as submitted to the slice.
    UPROPERTY()
    FCk_RuntimeMesh_PlaneLocal Plane;

    UPROPERTY()
    EMars_TESTONLY_FoodPieceSpike_Side Kept = EMars_TESTONLY_FoodPieceSpike_Side::Positive;
}

struct FMars_TESTONLY_FoodPieceSpike_Recipe
{
    UPROPERTY()
    TSoftObjectPtr<UMars_Food_Def> Definition;

    // The definition's object name, for a client whose soft pointer does not resolve.
    UPROPERTY()
    FName DefinitionName;

    UPROPERTY()
    TArray<FMars_TESTONLY_FoodPieceSpike_Cut> Cuts;
}

// Bitwise fingerprints travel as integers so the comparison never depends on how a double crosses the wire.
struct FMars_TESTONLY_FoodPieceSpike_Digest
{
    // The CRC of the plane this geometry was cut with, as the machine that made it read the plane (0 for a joint).
    UPROPERTY()
    int64 PlaneCrc = 0;

    UPROPERTY()
    int64 VolumeBits = 0;

    UPROPERTY()
    int64 CentroidCrc = 0;

    UPROPERTY()
    int64 BoundsCrc = 0;

    UPROPERTY()
    int32 TriangleCount = 0;

    UPROPERTY()
    int32 VertexCount = 0;

    UPROPERTY()
    int64 VertexCrc = 0;
}

struct FMars_TESTONLY_FoodPieceSpike_Record
{
    UPROPERTY()
    int32 Batch = 0;

    // The lineage's seeded chain; Leaf is unique among every record a test publishes.
    UPROPERTY()
    int32 Chain = 0;

    UPROPERTY()
    int32 Leaf = 0;

    UPROPERTY()
    FMars_TESTONLY_FoodPieceSpike_Recipe Recipe;

    UPROPERTY()
    FMars_TESTONLY_FoodPieceSpike_Digest Root;

    // One per cut of the recipe: the kept half's digest on the authority.
    UPROPERTY()
    TArray<FMars_TESTONLY_FoodPieceSpike_Digest> Steps;

    // The recipe's doubles as their raw 64-bit patterns, when a test sends them that way too.
    UPROPERTY()
    TArray<int64> PackedBits;
}

struct FMars_TESTONLY_FoodPieceSpike_Fragment_Record
{
    UPROPERTY()
    FMars_TESTONLY_FoodPieceSpike_Record Record;
}

// What the record script is spawned with; injection matches by property name.
struct FMars_TESTONLY_FoodPieceSpike_RecordSpawnParams
{
    UPROPERTY()
    FMars_TESTONLY_FoodPieceSpike_Record Record;
}

// A second carrier for planes: a replicated fragment on the subject.
struct FMars_TESTONLY_FoodPieceSpike_Fragment_Planes
{
    UPROPERTY()
    TArray<FCk_RuntimeMesh_PlaneLocal> Planes;

    UPROPERTY()
    TArray<int64> PackedBits;
}

// The authority's count of the records it published, per batch; Complete once it publishes no more.
struct FMars_TESTONLY_FoodPieceSpike_Fragment_Manifest
{
    UPROPERTY()
    TArray<int32> Batches;

    UPROPERTY()
    TArray<int32> Counts;

    UPROPERTY()
    bool Complete = false;
}

struct FMars_TESTONLY_FoodPieceSpike_Rng
{
    uint32 State = 1;
}

// One live piece of a lineage on the authority.
struct FMars_TESTONLY_FoodPieceSpike_Node
{
    FCk_Handle_FoodPiece Piece;
    int32 Batch = 0;
    int32 Chain = 0;
    FMars_TESTONLY_FoodPieceSpike_Rng Rng;
    FMars_TESTONLY_FoodPieceSpike_Recipe Recipe;
    FMars_TESTONLY_FoodPieceSpike_Digest Root;
    bool HasRoot = false;
    TArray<FMars_TESTONLY_FoodPieceSpike_Digest> Steps;
    // The last step's digest is taken on the next tick, outside the slice drain, so it never eats the drain's budget.
    bool StepDigestPending = false;
    int32 Attempts = 0;
    int32 Refusals = 0;
    bool Cutting = false;
    FCk_RuntimeMesh_PlaneLocal Pending;
    // Where a lineage cut at fixed steps along local X started.
    float64 OriginCm = 0.0;
}

struct FMars_TESTONLY_FoodPieceSpike_Memo
{
    FCk_Handle_RuntimeMesh Mesh;
    int64 PlaneCrc = 0;
    bool HasDigest = false;
    FMars_TESTONLY_FoodPieceSpike_Digest Digest;
}

struct FMars_TESTONLY_FoodPieceSpike_Flight
{
    FString Base;
    int32 Batch = 0;
    int64 PlaneCrc = 0;
}

struct FMars_TESTONLY_FoodPieceSpike_Replay
{
    FMars_TESTONLY_FoodPieceSpike_Record Record;
    bool Done = false;
    bool DefinitionMissing = false;
    TOptional<int32> RejectedAt;
    TOptional<ECk_RuntimeMesh_SliceOutcome> RejectedOutcome;
}

// Client frames of one batch, counted by the rig's own tick.
struct FMars_TESTONLY_FoodPieceSpike_BatchClock
{
    TOptional<int32> Arrival;
    TOptional<int32> RootReady;
    TOptional<int32> Done;
    int32 Slices = 0;
}

struct FMars_TESTONLY_FoodPieceSpike_StepTally
{
    int32 Records = 0;
    int32 Committed = 0;
    int32 Equal = 0;
    int32 Rejected = 0;
    int32 NotReplayed = 0;
}

struct FMars_TESTONLY_FoodPieceSpike_MismatchTally
{
    int32 VertexOnly = 0;
    int32 VolumeDiffers = 0;
    int32 TrianglesDiffer = 0;
    int32 PlaneDiffers = 0;
}

struct FMars_TESTONLY_FoodPieceSpike_RootTally
{
    int32 Compared = 0;
    int32 Equal = 0;
    int32 MissingDefinition = 0;
}

struct FMars_TESTONLY_FoodPieceSpike_Tally
{
    FMars_TESTONLY_FoodPieceSpike_StepTally Steps;
    FMars_TESTONLY_FoodPieceSpike_MismatchTally Mismatch;
    FMars_TESTONLY_FoodPieceSpike_RootTally Roots;
}

// One published record. Its spawn data is the whole payload; every machine copies it into a local fragment.
class UMars_TESTONLY_FoodPieceSpike_Record_EntityScript : UCk_GenericEntityScript_UE
{
    // Stance A: the authority spawns it under the replicated spawn owner; its spawn data is what replicates.
    default _Replication = ECk_Replication::Replicates;

    UPROPERTY(ExposeOnSpawn)
    FMars_TESTONLY_FoodPieceSpike_Record Record;

    UFUNCTION(BlueprintOverride)
    ECk_EntityScript_ConstructionFlow DoConstruct(FCk_Handle& InHandle)
    {
        auto Fragment = FMars_TESTONLY_FoodPieceSpike_Fragment_Record();
        Fragment.Record = Record;
        InHandle.Add_Fragment(Fragment);
        utils_entity_tag::Add(InHandle, n"TAG_MarsFoodPieceSpikeRecord");
        return ECk_EntityScript_ConstructionFlow::Finished;
    }
}

UCLASS(Abstract)
class UMars_AutoTestRig_FoodPieceSpike : UCk_AutoTest_NetBase
{
    // The stub's own limit is 30 s; each world's body ends at 0.9 of this.
    default _TimeoutSeconds = 29.0f;

    protected const int32 k_SlowPolls = 100000;
    // RuntimeMesh's world-wide slice queue holds 16; a fuller queue refuses a cut on submission.
    protected const int32 k_MaxSlicesInFlight = 12;
    // The server's pause after its last publish, so the client has copied every record before the server's cleanup
    // destroys them.
    protected const float32 k_ServerHoldSeconds = 4.0f;
    // Past this share of the timeout a world reports what it has rather than dying on the deadline with no numbers.
    protected const float32 k_ReportShare = 0.8f;
    protected const int32 k_DigestsPerTick = 16;

    protected FCk_Handle _Runner;
    protected bool _IsServer = false;
    protected int32 _Frame = 0;
    private FCk_Handle_Timer _Tick;
    private float64 _StartSeconds = 0.0;
    private int32 _EnsuresAtStart = 0;
    private TArray<uint32> _CrcTable;
    private TArray<float64> _Pow2Up;
    private TArray<float64> _Pow2Down;

    // Server.
    private bool _ServerStarted = false;
    private bool _ServerFinished = false;
    protected TArray<FMars_TESTONLY_FoodPieceSpike_Node> _Nodes;
    protected int32 _ServerCommitted = 0;
    protected int32 _ServerLost = 0;
    protected int32 _NextLeaf = 0;
    private TMap<FString, int32> _ServerRefusals;
    private TArray<int32> _ManifestBatches;
    private bool _NextSpawnLogged = false;
    private TArray<int32> _ManifestCounts;

    // Client.
    private bool _ClientComplete = false;
    protected bool _ClientOutOfTime = false;
    protected TArray<FMars_TESTONLY_FoodPieceSpike_Replay> _Replays;
    private TSet<FString> _SeenRecords;
    protected TMap<FString, FMars_TESTONLY_FoodPieceSpike_Memo> _Memo;
    private TArray<FString> _PendingDigests;
    private TMap<FString, FCk_Handle_RuntimeMesh> _Imports;
    private TMap<FString, FMars_TESTONLY_FoodPieceSpike_Flight> _Flights;
    private TSet<FString> _FlightBases;
    protected TMap<FString, ECk_RuntimeMesh_SliceOutcome> _Rejected;
    protected TMap<int32, FMars_TESTONLY_FoodPieceSpike_BatchClock> _Clocks;
    protected int32 _ClientSlices = 0;
    // Resolutions of a record's definition through its soft pointer, per Advance call.
    protected int32 _SoftResolved = 0;
    protected int32 _SoftUnresolved = 0;
    private bool _SoftPathLogged = false;
    protected TArray<float64> _SliceMs;
    private TOptional<int32> _LastResolveFrame;
    private float64 _LastResolveSeconds = 0.0;

    //----------------------------------------------------------------------------------------------------------------------
    // What a test supplies
    //----------------------------------------------------------------------------------------------------------------------

    protected void Begin_Server() {}

    // Every server tick, before the lineages advance.
    protected void Server_Step() {}

    protected bool Get_IsServerPlanDone() const { return true; }

    // The next plane for InOutNode's piece (InMetrics are its local metrics); unset ends the lineage at this piece.
    protected TOptional<FCk_RuntimeMesh_PlaneLocal> Plan_Cut(FMars_TESTONLY_FoodPieceSpike_Node& InOutNode, const FCk_RuntimeMesh_Metrics& InMetrics)
    {
        return TOptional<FCk_RuntimeMesh_PlaneLocal>();
    }

    protected EMars_TESTONLY_FoodPieceSpike_Keep Choose_Keep(FMars_TESTONLY_FoodPieceSpike_Node& InOutNode)
    {
        return EMars_TESTONLY_FoodPieceSpike_Keep::Positive;
    }

    protected void Publish_Record(const FMars_TESTONLY_FoodPieceSpike_Record& InRecord)
    {
        Spawn_Record(InRecord);
    }

    protected bool Get_ShouldReplay() const { return true; }

    protected bool Get_IsClientExtraReady() { return true; }

    protected void Report_Client() {}

    //----------------------------------------------------------------------------------------------------------------------
    // Flow
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        _Runner = InHandle;
        Build_Tables();

        auto Subject = Get_SubjectEntity();
        if (ck::Is_NOT_Valid(Subject))
        { FinishFailure("subject entity not found"); return; }

        _IsServer = utils_net::Get_HasAuthority(Subject);
        _EnsuresAtStart = utils_ensure::Get_EnsureCount();
        _StartSeconds = System::GetGameTimeInSeconds();
        _Tick = utils_timer::Create_Tick(InHandle, FCk_Delegate_Timer(this, n"OnSpikeTick"));

        if (_IsServer == false)
        {
            WaitUntil(n"Is_ClientComplete", n"OnClientComplete", k_SlowPolls);
            return;
        }

        WaitUntil(n"Is_ReplicatedSpawnOwnerPublished", n"OnServerOwnerPublished", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ReplicatedSpawnOwnerPublished(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(utils_mars_net::Get_HasReplicatedSpawnOwner(Get_SubjectEntity()));
    }

    UFUNCTION()
    private void OnServerOwnerPublished(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Begin_Server();
        _ServerStarted = true;
        WaitUntil(n"Is_ServerFinished", n"OnServerFinished", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerFinished(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_ServerFinished);
    }

    UFUNCTION()
    private void OnServerFinished(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_ServerHoldSeconds, n"OnServerHeld");
    }

    UFUNCTION()
    private void OnServerHeld(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Stop_Tick();
        for (const auto& Node : _Nodes)
        { utils_entity_lifetime::Request_DestroyEntity(Node.Piece); }

        FString Refusals;
        for (auto Entry : _ServerRefusals)
        { Refusals += f"{Entry.Key}={Entry.Value} "; }

        auto Published = 0;
        for (const auto Count : _ManifestCounts)
        { Published += Count; }

        ck::Trace(f"[FoodPieceSpike] server {GetName()}: committed={_ServerCommitted} refusals=[{Refusals}] lostJoints={_ServerLost} "
            + f"records={Published} unfinishedLineages={_Nodes.Num()} frames={_Frame} newEnsures={Get_NewEnsures()}");
        Assert_True(_Nodes.Num() == 0, f"every lineage finished on the server ({_Nodes.Num()} did not)");
        Assert_Equals_Int(_ServerLost, 0, "every joint imported on the server");
        FinishSuccess();
    }

    UFUNCTION()
    private void Is_ClientComplete(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_ClientComplete || _ClientOutOfTime);
    }

    UFUNCTION()
    private void OnClientComplete(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Stop_Tick();
        ck::Trace(f"[FoodPieceSpike] client {GetName()}: records={_Replays.Num()} slices={_ClientSlices} frames={_Frame} "
            + f"softPointerResolved={_SoftResolved} softPointerUnresolved={_SoftUnresolved} "
            + f"outOfTime={_ClientOutOfTime} newEnsures={Get_NewEnsures()}");
        Assert_False(_ClientOutOfTime, "the client received and replayed every record before its deadline");
        Report_Client();
        FinishSuccess();
    }

    UFUNCTION()
    private void OnSpikeTick(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        if (IsFinished())
        { return; }

        _Frame += 1;
        if (_IsServer)
        {
            Server_Tick();
            return;
        }

        Client_Tick();
    }

    private void Stop_Tick()
    {
        if (ck::Is_NOT_Valid(_Tick))
        { return; }

        utils_timer::UnbindFrom_OnUpdate(_Tick, FCk_Delegate_Timer(this, n"OnSpikeTick"));
        utils_entity_lifetime::Request_DestroyEntity(_Tick.H());
        _Tick = FCk_Handle_Timer();
    }

    protected float64 Get_ElapsedSeconds() const
    {
        return float64(System::GetGameTimeInSeconds()) - _StartSeconds;
    }

    protected int32 Get_NewEnsures() const
    {
        return utils_ensure::Get_EnsureCount() - _EnsuresAtStart;
    }

    protected float64 Get_WallSeconds() const
    {
        return (FDateTime::UtcNow() - FDateTime::MinValue()).GetTotalSeconds();
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Server
    //----------------------------------------------------------------------------------------------------------------------

    // A whole joint of InDefinition at InLocation, as the lineage InNode (batch, chain, seed) starts it.
    protected void Add_Joint(UMars_Food_Def InDefinition, FMars_TESTONLY_FoodPieceSpike_Node InNode, FVector InLocation)
    {
        auto Node = InNode;
        Node.Recipe.Definition = TSoftObjectPtr<UMars_Food_Def>(InDefinition);
        Node.Recipe.DefinitionName = InDefinition.GetName();
        Node.Piece = InDefinition.Build_Joint(_Runner, FTransform(FRotator::ZeroRotator, InLocation));
        if (ck::Is_NOT_Valid(Node.Piece))
        {
            _ServerLost += 1;
            return;
        }

        Node.Piece.BindTo_OnCutResolved(FMars_Delegate_FoodPiece_OnCutResolved(this, n"OnServerCutResolved"));
        _Nodes.Add(Node);
    }

    protected bool Get_HasNodes(int32 InBatch) const
    {
        for (const auto& Node : _Nodes)
        {
            if (Node.Batch == InBatch)
            { return true; }
        }

        return false;
    }

    private void Server_Tick()
    {
        if (_ServerStarted == false || _ServerFinished)
        { return; }

        if (Get_ElapsedSeconds() > _TimeoutSeconds * k_ReportShare)
        {
            Publish_Manifest(true);
            _ServerFinished = true;
            return;
        }

        Server_Step();

        auto InFlight = 0;
        for (const auto& Node : _Nodes)
        {
            if (Node.Cutting)
            { InFlight += 1; }
        }

        auto Index = 0;
        while (Index < _Nodes.Num())
        {
            auto& Node = _Nodes[Index];
            if (Node.Cutting)
            {
                Index += 1;
                continue;
            }

            if (Node.Piece.Get_IsGone() || Node.Piece.Get_Status() == EMars_FoodPiece_Status::Failed)
            {
                _ServerLost += 1;
                _Nodes.RemoveAt(Index);
                continue;
            }

            if (Node.Piece.Get_Status() != EMars_FoodPiece_Status::Ready)
            {
                Index += 1;
                continue;
            }

            const auto Geometry = Node.Piece.Get_Geometry();
            if (Node.HasRoot == false)
            {
                Node.Root = Make_Digest(Geometry, 0);
                Node.HasRoot = true;
            }

            if (Node.StepDigestPending)
            {
                const auto Last = Node.Steps.Num() - 1;
                Node.Steps[Last] = Make_Digest(Geometry, Node.Steps[Last].PlaneCrc);
                Node.StepDigestPending = false;
            }

            if (InFlight >= k_MaxSlicesInFlight)
            {
                Index += 1;
                continue;
            }

            const auto Plan = Plan_Cut(Node, utils_runtime_mesh::Get_Metrics(Geometry));
            if (Plan.IsSet() == false)
            {
                Finish_Node(Index);
                continue;
            }

            Node.Pending = Plan.GetValue();
            Node.Cutting = true;
            Node.Attempts += 1;
            InFlight += 1;
            Node.Piece.Request_Cut(FMars_Request_FoodPiece_Cut(Node.Pending));
            Index += 1;
        }

        if (_Nodes.Num() == 0 && Get_IsServerPlanDone())
        {
            Publish_Manifest(true);
            _ServerFinished = true;
        }
    }

    private void Finish_Node(int32 InIndex)
    {
        const auto Node = _Nodes[InIndex];
        _Nodes.RemoveAt(InIndex);

        auto Record = FMars_TESTONLY_FoodPieceSpike_Record();
        Record.Batch = Node.Batch;
        Record.Chain = Node.Chain;
        Record.Leaf = _NextLeaf;
        _NextLeaf += 1;
        Record.Recipe = Node.Recipe;
        Record.Root = Node.Root;
        Record.Steps = Node.Steps;
        Publish_Record(Record);

        utils_entity_lifetime::Request_DestroyEntity(Node.Piece);
    }

    UFUNCTION()
    private void OnServerCutResolved(FCk_Handle_FoodPiece InSource, FMars_FoodPiece_CutResult InResult)
    {
        for (int32 Index = 0; Index < _Nodes.Num(); ++Index)
        {
            if (_Nodes[Index].Piece != InSource || _Nodes[Index].Cutting == false)
            { continue; }

            auto Node = _Nodes[Index];
            Node.Cutting = false;
            if (InResult.Outcome != EMars_FoodPiece_CutOutcome::Cut)
            {
                Node.Refusals += 1;
                Count_Refusal(InResult);
                _Nodes[Index] = Node;
                return;
            }

            _ServerCommitted += 1;
            _Nodes.RemoveAt(Index);

            const auto Keep = Choose_Keep(Node);
            auto Positive = InResult.Positive;
            auto Negative = InResult.Negative;
            if (Keep == EMars_TESTONLY_FoodPieceSpike_Keep::Negative)
            { utils_entity_lifetime::Request_DestroyEntity(Positive); }
            else
            { Add_Child(Node, Positive, EMars_TESTONLY_FoodPieceSpike_Side::Positive); }

            if (Keep == EMars_TESTONLY_FoodPieceSpike_Keep::Positive)
            { utils_entity_lifetime::Request_DestroyEntity(Negative); }
            else
            { Add_Child(Node, Negative, EMars_TESTONLY_FoodPieceSpike_Side::Negative); }

            return;
        }
    }

    private void Count_Refusal(const FMars_FoodPiece_CutResult& InResult)
    {
        auto Key = f"{InResult.Outcome :n}";
        if (InResult.SliceOutcome.IsSet())
        { Key += f"/{InResult.SliceOutcome.GetValue() :n}"; }

        auto Count = 0;
        _ServerRefusals.Find(Key, Count);
        _ServerRefusals.Add(Key, Count + 1);
    }

    private void Add_Child(const FMars_TESTONLY_FoodPieceSpike_Node& InParent, FCk_Handle_FoodPiece InHalf, EMars_TESTONLY_FoodPieceSpike_Side InSide)
    {
        auto Child = InParent;
        Child.Piece = InHalf;

        auto Cut = FMars_TESTONLY_FoodPieceSpike_Cut();
        Cut.Plane = InParent.Pending;
        Cut.Kept = InSide;
        Child.Recipe.Cuts.Add(Cut);

        auto Placeholder = FMars_TESTONLY_FoodPieceSpike_Digest();
        Placeholder.PlaneCrc = Get_PlaneCrc(InParent.Pending);
        Child.Steps.Add(Placeholder);
        Child.StepDigestPending = true;

        // A sibling draws its own stream.
        if (InSide == EMars_TESTONLY_FoodPieceSpike_Side::Negative)
        {
            Child.Rng.State = Child.Rng.State ^ uint32(0x9E3779B9);
            if (Child.Rng.State == 0)
            { Child.Rng.State = 1; }

            Draw(Child.Rng);
        }

        Child.Piece.BindTo_OnCutResolved(FMars_Delegate_FoodPiece_OnCutResolved(this, n"OnServerCutResolved"));
        _Nodes.Add(Child);
    }

    protected void Spawn_Record(const FMars_TESTONLY_FoodPieceSpike_Record& InRecord)
    {
        if (_NextSpawnLogged == false)
        {
            _NextSpawnLogged = true;
            ck::Trace(f"[FoodPieceSpike] server: a record's definition soft pointer is [{InRecord.Recipe.Definition.ToSoftObjectPath().ToString()}]");
        }

        auto Owner = utils_mars_net::Get_ReplicatedSpawnOwner(Get_SubjectEntity());
        auto Params = FMars_TESTONLY_FoodPieceSpike_RecordSpawnParams();
        Params.Record = InRecord;
        auto Pending = utils_entity_script::Request_SpawnEntity(Owner, UMars_TESTONLY_FoodPieceSpike_Record_EntityScript, Params);
        auto Spawned = Pending.Get_EntityUnderConstruction();
        utils_net_spawn::Expect_Replicated(Spawned);
        Track_ForCleanup(Spawned);

        for (int32 Index = 0; Index < _ManifestBatches.Num(); ++Index)
        {
            if (_ManifestBatches[Index] == InRecord.Batch)
            {
                _ManifestCounts[Index] += 1;
                return;
            }
        }

        _ManifestBatches.Add(InRecord.Batch);
        _ManifestCounts.Add(1);
    }

    protected void Publish_Manifest(bool InComplete)
    {
        auto Subject = Get_SubjectEntity();
        if (Subject.Has_Fragment(FMars_TESTONLY_FoodPieceSpike_Fragment_Manifest) == false)
        {
            auto Manifest = FMars_TESTONLY_FoodPieceSpike_Fragment_Manifest();
            Manifest.Batches = _ManifestBatches;
            Manifest.Counts = _ManifestCounts;
            Manifest.Complete = InComplete;
            Subject.Add_Fragment(Manifest, ECk_Replication::Replicates);
            return;
        }

        auto& Manifest = Subject.Get_Fragment(FMars_TESTONLY_FoodPieceSpike_Fragment_Manifest);
        Manifest.Batches = _ManifestBatches;
        Manifest.Counts = _ManifestCounts;
        Manifest.Complete = InComplete;
        Subject.Request_MarkReplicationDirty(FMars_TESTONLY_FoodPieceSpike_Fragment_Manifest);
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Client
    //----------------------------------------------------------------------------------------------------------------------

    private void Client_Tick()
    {
        Collect_Records();
        if (Get_ShouldReplay())
        {
            for (int32 Index = 0; Index < _Replays.Num(); ++Index)
            {
                if (_Replays[Index].Done == false)
                { Advance(_Replays[Index]); }
            }
        }
        else
        {
            for (int32 Index = 0; Index < _Replays.Num(); ++Index)
            { _Replays[Index].Done = true; }
        }

        Take_PendingDigests();
        Update_Clocks();

        if (Get_ElapsedSeconds() > _TimeoutSeconds * k_ReportShare)
        { _ClientOutOfTime = true; }
    }

    private void Collect_Records()
    {
        for (auto Candidate : utils_entity_tag::ForEach_Entity(Get_SubjectEntity(), n"TAG_MarsFoodPieceSpikeRecord"))
        {
            if (Candidate.Has_Fragment(FMars_TESTONLY_FoodPieceSpike_Fragment_Record) == false)
            { continue; }

            const auto Record = Candidate.Get_Fragment(FMars_TESTONLY_FoodPieceSpike_Fragment_Record).Record;
            const auto Key = f"{Record.Batch}:{Record.Leaf}";
            if (_SeenRecords.Contains(Key))
            { continue; }

            _SeenRecords.Add(Key);
            auto Replay = FMars_TESTONLY_FoodPieceSpike_Replay();
            Replay.Record = Record;
            _Replays.Add(Replay);

            auto Clock = Get_Clock(Record.Batch);
            if (Clock.Arrival.IsSet() == false)
            {
                Clock.Arrival = TOptional<int32>(_Frame);
                _Clocks.Add(Record.Batch, Clock);
            }
        }
    }

    protected FMars_TESTONLY_FoodPieceSpike_BatchClock Get_Clock(int32 InBatch) const
    {
        auto Clock = FMars_TESTONLY_FoodPieceSpike_BatchClock();
        _Clocks.Find(InBatch, Clock);
        return Clock;
    }

    protected FString Get_RootKey(const FMars_TESTONLY_FoodPieceSpike_Record& InRecord) const
    {
        return f"{InRecord.Recipe.DefinitionName}#{InRecord.Batch}";
    }

    // The recipe's soft pointer, else the placed food of that name. Counts how often the soft pointer alone resolved.
    private UMars_Food_Def Resolve_Definition(const FMars_TESTONLY_FoodPieceSpike_Recipe& InRecipe)
    {
        UMars_Food_Def Soft = InRecipe.Definition.Get();
        if (ck::IsValid(Soft))
        {
            _SoftResolved += 1;
            return Soft;
        }

        _SoftUnresolved += 1;
        if (_SoftPathLogged == false)
        {
            _SoftPathLogged = true;
            ck::Trace(f"[FoodPieceSpike] client: the soft pointer [{InRecipe.Definition.ToSoftObjectPath().ToString()}] did not resolve; "
                + f"resolving [{InRecipe.DefinitionName}] by name");
        }

        for (auto Definition : Get_PlacedDefinitions())
        {
            if (Definition.GetName() == InRecipe.DefinitionName)
            { return Definition; }
        }

        return nullptr;
    }

    protected TArray<UMars_Food_Def> Get_PlacedDefinitions() const
    {
        TArray<UMars_Food_Def> Definitions;
        Definitions.Add(mars::Food_MeatSlab_Mars);
        Definitions.Add(mars::Food_MushroomSlice_Mars);
        Definitions.Add(mars::Food_Drumstick_Mars);
        Definitions.Add(mars::Food_Tentacle_Mars);
        Definitions.Add(mars::Food_Puffer_Mars);
        Definitions.Add(mars::Food_SpikedBerry_Mars);
        Definitions.Add(mars::Food_Mushroom_Mars);
        Definitions.Add(mars::Food_Pickle_Mars);
        Definitions.Add(mars::Food_Fish_Mars);
        return Definitions;
    }

    protected FString Get_ChildKey(const FString& InBase, EMars_TESTONLY_FoodPieceSpike_Side InSide) const
    {
        if (InSide == EMars_TESTONLY_FoodPieceSpike_Side::Positive)
        { return InBase + "P"; }

        return InBase + "N";
    }

    private void Advance(FMars_TESTONLY_FoodPieceSpike_Replay& InOutReplay)
    {
        UMars_Food_Def Definition = Resolve_Definition(InOutReplay.Record.Recipe);
        if (ck::Is_NOT_Valid(Definition))
        {
            InOutReplay.DefinitionMissing = true;
            InOutReplay.Done = true;
            return;
        }

        auto Key = Get_RootKey(InOutReplay.Record);
        if (_Rejected.Contains(Key))
        {
            InOutReplay.RejectedAt = TOptional<int32>(0);
            InOutReplay.RejectedOutcome = TOptional<ECk_RuntimeMesh_SliceOutcome>(ECk_RuntimeMesh_SliceOutcome::NotReady);
            InOutReplay.Done = true;
            return;
        }

        if (_Memo.Contains(Key) == false)
        {
            Ensure_Import(Definition, InOutReplay.Record.Batch, Key);
            return;
        }

        const auto& Cuts = InOutReplay.Record.Recipe.Cuts;
        for (int32 Step = 0; Step < Cuts.Num(); ++Step)
        {
            const auto PlaneCrc = Get_PlaneCrc(Cuts[Step].Plane);
            const auto Base = Key + "|" + Get_Hex(uint64(PlaneCrc));
            const auto Child = Get_ChildKey(Base, Cuts[Step].Kept);
            if (_Memo.Contains(Child))
            {
                Key = Child;
                continue;
            }

            auto Outcome = ECk_RuntimeMesh_SliceOutcome::InvalidRequest;
            if (_Rejected.Find(Base, Outcome))
            {
                InOutReplay.RejectedAt = TOptional<int32>(Step);
                InOutReplay.RejectedOutcome = TOptional<ECk_RuntimeMesh_SliceOutcome>(Outcome);
                InOutReplay.Done = true;
                return;
            }

            if (_FlightBases.Contains(Base) || _Flights.Num() >= k_MaxSlicesInFlight)
            { return; }

            auto Parent = FMars_TESTONLY_FoodPieceSpike_Memo();
            _Memo.Find(Key, Parent);

            auto Slice = FCk_Request_RuntimeMesh_Slice();
            Slice.Set_OperationID(FGuid::NewGuid());
            Slice.Set_ResultOwner(_Runner);
            Slice.Set_Plane(Cuts[Step].Plane);
            Slice.Set_Cap(Definition.Visuals.Cap);

            auto Flight = FMars_TESTONLY_FoodPieceSpike_Flight();
            Flight.Base = Base;
            Flight.Batch = InOutReplay.Record.Batch;
            Flight.PlaneCrc = PlaneCrc;
            Submit_Replay(Parent.Mesh, Slice, Flight);
            return;
        }

        InOutReplay.Done = true;
    }

    // Entered before submitting: a slice RuntimeMesh cannot queue resolves on this call stack.
    private void Submit_Replay(FCk_Handle_RuntimeMesh InSource, const FCk_Request_RuntimeMesh_Slice& InSlice, const FMars_TESTONLY_FoodPieceSpike_Flight& InFlight)
    {
        _Flights.Add(InSlice.Get_OperationID().ToString(), InFlight);
        _FlightBases.Add(InFlight.Base);
        _ClientSlices += 1;

        auto Clock = Get_Clock(InFlight.Batch);
        Clock.Slices += 1;
        _Clocks.Add(InFlight.Batch, Clock);

        utils_runtime_mesh::Request_Slice(InSource, InSlice, FCk_Delegate_RuntimeMesh_OnSliceResolved(this, n"OnReplayResolved"));
    }

    UFUNCTION()
    private void OnReplayResolved(FCk_RuntimeMesh_SliceResult InResult)
    {
        const auto Now = Get_WallSeconds();
        if (_LastResolveFrame.IsSet() && _LastResolveFrame.GetValue() == _Frame)
        { _SliceMs.Add((Now - _LastResolveSeconds) * 1000.0); }

        _LastResolveFrame = TOptional<int32>(_Frame);
        _LastResolveSeconds = Now;

        const auto OperationKey = InResult.Get_OperationID().ToString();
        auto Flight = FMars_TESTONLY_FoodPieceSpike_Flight();
        if (ck::EnsureIfNot(_Flights.Find(OperationKey, Flight), f"[FoodPieceSpike] a replay slice [{OperationKey}] resolved that this client never submitted"))
        { return; }

        _Flights.Remove(OperationKey);
        _FlightBases.Remove(Flight.Base);

        if (InResult.Get_Outcome() != ECk_RuntimeMesh_SliceOutcome::Succeeded)
        {
            _Rejected.Add(Flight.Base, InResult.Get_Outcome());
            if (ck::IsValid(InResult.Get_Positive()))
            { utils_entity_lifetime::Request_DestroyEntity(InResult.Get_Positive()); }

            if (ck::IsValid(InResult.Get_Negative()))
            { utils_entity_lifetime::Request_DestroyEntity(InResult.Get_Negative()); }

            return;
        }

        Add_Memo(Get_ChildKey(Flight.Base, EMars_TESTONLY_FoodPieceSpike_Side::Positive), InResult.Get_Positive(), Flight.PlaneCrc);
        Add_Memo(Get_ChildKey(Flight.Base, EMars_TESTONLY_FoodPieceSpike_Side::Negative), InResult.Get_Negative(), Flight.PlaneCrc);
    }

    // The digest is taken on a later tick, outside the slice drain.
    private void Add_Memo(const FString& InKey, FCk_Handle_RuntimeMesh InMesh, int64 InPlaneCrc)
    {
        auto Entry = FMars_TESTONLY_FoodPieceSpike_Memo();
        Entry.Mesh = InMesh;
        Entry.PlaneCrc = InPlaneCrc;
        _Memo.Add(InKey, Entry);
        _PendingDigests.Add(InKey);
    }

    private void Take_PendingDigests()
    {
        auto Taken = 0;
        while (_PendingDigests.Num() > 0 && Taken < k_DigestsPerTick)
        {
            const auto Key = _PendingDigests[_PendingDigests.Num() - 1];
            _PendingDigests.RemoveAt(_PendingDigests.Num() - 1);

            auto Entry = FMars_TESTONLY_FoodPieceSpike_Memo();
            _Memo.Find(Key, Entry);
            Entry.Digest = Make_Digest(Entry.Mesh, Entry.PlaneCrc);
            Entry.HasDigest = true;
            _Memo.Add(Key, Entry);
            Taken += 1;
        }
    }

    // The definition's mesh imported on this machine, as the game composes a joint (FCk_RuntimeMesh_Spec(Data.Mesh)).
    private void Ensure_Import(UMars_Food_Def InDefinition, int32 InBatch, const FString& InKey)
    {
        auto Import = FCk_Handle_RuntimeMesh();
        if (_Imports.Find(InKey, Import) == false)
        {
            auto Owner = _Runner;
            auto Entity = utils_entity_lifetime::Request_CreateEntity(Owner);
            utils_transform::Add(Entity, FTransform::Identity, ECk_Replication::DoesNotReplicate);
            Import = utils_runtime_mesh::Add(Entity, FCk_RuntimeMesh_Spec(InDefinition.Data.Mesh));
            _Imports.Add(InKey, Import);
            return;
        }

        const auto State = utils_runtime_mesh::Get_SetupState(Import);
        if (State == ECk_RuntimeMesh_SetupState::Pending)
        { return; }

        if (ck::EnsureIfNot(State == ECk_RuntimeMesh_SetupState::Ready,
            f"[FoodPieceSpike] the client could not import [{InDefinition.GetName()}]: {utils_runtime_mesh::Get_SetupFailure(Import) :n}"))
        {
            _Rejected.Add(InKey, ECk_RuntimeMesh_SliceOutcome::NotReady);
            return;
        }

        Add_Memo(InKey, Import, 0);

        auto Clock = Get_Clock(InBatch);
        Clock.RootReady = TOptional<int32>(_Frame);
        _Clocks.Add(InBatch, Clock);
    }

    private FMars_TESTONLY_FoodPieceSpike_Fragment_Manifest Get_Manifest()
    {
        auto Subject = Get_SubjectEntity();
        if (ck::Is_NOT_Valid(Subject) || Subject.Has_Fragment(FMars_TESTONLY_FoodPieceSpike_Fragment_Manifest) == false)
        { return FMars_TESTONLY_FoodPieceSpike_Fragment_Manifest(); }

        return Subject.Get_Fragment(FMars_TESTONLY_FoodPieceSpike_Fragment_Manifest);
    }

    private bool Get_IsBatchDone(int32 InBatch, int32 InCount) const
    {
        auto Seen = 0;
        for (const auto& Replay : _Replays)
        {
            if (Replay.Record.Batch != InBatch)
            { continue; }

            if (Replay.Done == false)
            { return false; }

            Seen += 1;
        }

        return Seen == InCount;
    }

    private void Update_Clocks()
    {
        const auto Manifest = Get_Manifest();
        auto Expected = 0;
        auto AllDone = true;
        for (int32 Index = 0; Index < Manifest.Batches.Num(); ++Index)
        {
            const auto Batch = Manifest.Batches[Index];
            Expected += Manifest.Counts[Index];
            if (Get_IsBatchDone(Batch, Manifest.Counts[Index]) == false)
            {
                AllDone = false;
                continue;
            }

            auto Clock = Get_Clock(Batch);
            // Done when every piece's geometry exists; the digests are bookkeeping and may follow later.
            if (Clock.Done.IsSet() == false)
            {
                Clock.Done = TOptional<int32>(_Frame);
                _Clocks.Add(Batch, Clock);
            }
        }

        _ClientComplete = Manifest.Complete && AllDone && _Replays.Num() == Expected && _PendingDigests.Num() == 0
            && Get_IsClientExtraReady();
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Comparison and reporting
    //----------------------------------------------------------------------------------------------------------------------

    protected FMars_TESTONLY_FoodPieceSpike_Tally Tally_Replays() const
    {
        auto Tally = FMars_TESTONLY_FoodPieceSpike_Tally();
        for (const auto& Replay : _Replays)
        {
            Tally.Steps.Records += 1;
            Tally.Steps.Committed += Replay.Record.Recipe.Cuts.Num();
            if (Replay.DefinitionMissing)
            {
                Tally.Roots.MissingDefinition += 1;
                Tally.Steps.NotReplayed += Replay.Record.Recipe.Cuts.Num();
                continue;
            }

            auto Key = Get_RootKey(Replay.Record);
            auto Entry = FMars_TESTONLY_FoodPieceSpike_Memo();
            if (_Memo.Find(Key, Entry) && Entry.HasDigest)
            {
                Tally.Roots.Compared += 1;
                if (Get_IsSameGeometry(Entry.Digest, Replay.Record.Root))
                { Tally.Roots.Equal += 1; }
            }

            const auto& Cuts = Replay.Record.Recipe.Cuts;
            for (int32 Step = 0; Step < Cuts.Num(); ++Step)
            {
                const auto Base = Key + "|" + Get_Hex(uint64(Get_PlaneCrc(Cuts[Step].Plane)));
                const auto Child = Get_ChildKey(Base, Cuts[Step].Kept);
                if (_Memo.Find(Child, Entry) == false || Entry.HasDigest == false)
                {
                    if (Replay.RejectedAt.IsSet() && Replay.RejectedAt.GetValue() == Step)
                    { Tally.Steps.Rejected += 1; }
                    else
                    { Tally.Steps.NotReplayed += 1; }

                    continue;
                }

                Key = Child;
                const auto& Server = Replay.Record.Steps[Step];
                if (Entry.Digest.PlaneCrc != Server.PlaneCrc)
                { Tally.Mismatch.PlaneDiffers += 1; }

                if (Get_IsSameGeometry(Entry.Digest, Server))
                {
                    Tally.Steps.Equal += 1;
                    continue;
                }

                if (Entry.Digest.VolumeBits != Server.VolumeBits)
                { Tally.Mismatch.VolumeDiffers += 1; }

                if (Entry.Digest.TriangleCount != Server.TriangleCount)
                { Tally.Mismatch.TrianglesDiffer += 1; }

                if (Entry.Digest.VolumeBits == Server.VolumeBits && Entry.Digest.TriangleCount == Server.TriangleCount)
                { Tally.Mismatch.VertexOnly += 1; }
            }
        }

        return Tally;
    }

    protected bool Get_IsSameGeometry(const FMars_TESTONLY_FoodPieceSpike_Digest& InA, const FMars_TESTONLY_FoodPieceSpike_Digest& InB) const
    {
        return InA.VolumeBits == InB.VolumeBits && InA.CentroidCrc == InB.CentroidCrc && InA.BoundsCrc == InB.BoundsCrc
            && InA.TriangleCount == InB.TriangleCount && InA.VertexCount == InB.VertexCount && InA.VertexCrc == InB.VertexCrc;
    }

    protected FString Describe_Tally(const FMars_TESTONLY_FoodPieceSpike_Tally& InTally) const
    {
        return f"records={InTally.Steps.Records} committed={InTally.Steps.Committed} equal={InTally.Steps.Equal} "
            + f"rejected={InTally.Steps.Rejected} notReplayed={InTally.Steps.NotReplayed} | vertexOnly={InTally.Mismatch.VertexOnly} "
            + f"volumeDiffers={InTally.Mismatch.VolumeDiffers} trianglesDiffer={InTally.Mismatch.TrianglesDiffer} "
            + f"planeDiffers={InTally.Mismatch.PlaneDiffers} | roots {InTally.Roots.Equal}/{InTally.Roots.Compared} equal, "
            + f"missingDefinition={InTally.Roots.MissingDefinition}";
    }

    protected FString Describe_Digest(const FMars_TESTONLY_FoodPieceSpike_Digest& InDigest) const
    {
        return f"vol={Get_Hex(uint64(InDigest.VolumeBits))} cen={Get_Hex(uint64(InDigest.CentroidCrc))} box={Get_Hex(uint64(InDigest.BoundsCrc))} "
            + f"tri={InDigest.TriangleCount} vtx={InDigest.VertexCount}/{Get_Hex(uint64(InDigest.VertexCrc))}";
    }

    // One line per committed cut, lineages in chain order, so two runs or two machines compare with a plain diff.
    protected void Write_DigestFile(const FString& InName)
    {
        auto MaxChain = 0;
        for (const auto& Replay : _Replays)
        { MaxChain = Math::Max(MaxChain, Replay.Record.Chain); }

        FString Content;
        for (int32 Chain = 0; Chain <= MaxChain; ++Chain)
        {
            for (const auto& Replay : _Replays)
            {
                if (Replay.Record.Chain != Chain || Replay.DefinitionMissing)
                { continue; }

                auto Key = Get_RootKey(Replay.Record);
                const auto& Cuts = Replay.Record.Recipe.Cuts;
                for (int32 Step = 0; Step < Cuts.Num(); ++Step)
                {
                    const auto Base = Key + "|" + Get_Hex(uint64(Get_PlaneCrc(Cuts[Step].Plane)));
                    Key = Get_ChildKey(Base, Cuts[Step].Kept);
                    auto Entry = FMars_TESTONLY_FoodPieceSpike_Memo();
                    FString Client = "none";
                    if (_Memo.Find(Key, Entry) && Entry.HasDigest)
                    { Client = Describe_Digest(Entry.Digest); }

                    FString Kept = "N";
                    if (Cuts[Step].Kept == EMars_TESTONLY_FoodPieceSpike_Side::Positive)
                    { Kept = "P"; }
                    Content += f"chain={Chain} step={Step} kept={Kept} plane={Get_Hex(uint64(Replay.Record.Steps[Step].PlaneCrc))} "
                        + f"server[{Describe_Digest(Replay.Record.Steps[Step])}] client[{Client}]\n";
                }
            }
        }

        const auto Path = FPaths::ProjectSavedDir() + "FoodPieceSpike/digests_" + InName + ".txt";
        const auto Saved = FFileHelper::SaveStringToFile(Content, Path);
        ck::Trace(f"[FoodPieceSpike] digest file {Path} saved={Saved}");
    }

    protected float64 Get_MeanMs() const
    {
        if (_SliceMs.Num() == 0)
        { return 0.0; }

        auto Sum = 0.0;
        for (const auto Value : _SliceMs)
        { Sum += Value; }

        return Sum / float64(_SliceMs.Num());
    }

    protected float64 Get_P95Ms() const
    {
        if (_SliceMs.Num() == 0)
        { return 0.0; }

        auto Values = _SliceMs;
        Values.Sort();
        const auto Index = Math::Min(Values.Num() - 1, int32(Math::FloorToDouble(0.95 * float64(Values.Num()))));
        return Values[Index];
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Geometry, planes and the deterministic generator
    //----------------------------------------------------------------------------------------------------------------------

    protected FMars_TESTONLY_FoodPieceSpike_Digest Make_Digest(const FCk_Handle_RuntimeMesh& InMesh, int64 InPlaneCrc) const
    {
        const auto Metrics = utils_runtime_mesh::Get_Metrics(InMesh);
        auto Digest = FMars_TESTONLY_FoodPieceSpike_Digest();
        Digest.PlaneCrc = InPlaneCrc;
        Digest.VolumeBits = int64(Get_Bits(Metrics.Get_VolumeCm3()));
        Digest.CentroidCrc = Finish_Crc(Crc_AddVector(Get_CrcStart(), Metrics.Get_CentroidCm()));
        Digest.BoundsCrc = Finish_Crc(Crc_AddVector(Crc_AddVector(Get_CrcStart(), Metrics.Get_BoundsMinCm()), Metrics.Get_BoundsMaxCm()));
        Digest.TriangleCount = Metrics.Get_TriangleCount();

        const auto Vertices = utils_runtime_mesh::Copy_LocalVerticesCm(InMesh);
        auto Crc = Get_CrcStart();
        for (const auto& Vertex : Vertices)
        { Crc = Crc_AddVector(Crc, Vertex); }

        Digest.VertexCount = Vertices.Num();
        Digest.VertexCrc = Finish_Crc(Crc);
        return Digest;
    }

    protected int64 Get_PlaneCrc(const FCk_RuntimeMesh_PlaneLocal& InPlane) const
    {
        auto Crc = Crc_AddVector(Get_CrcStart(), InPlane.Get_PositionCm());
        Crc = Crc_AddVector(Crc, InPlane.Get_Normal());
        Crc = Crc_AddVector(Crc, InPlane.Get_Tangent());
        return Finish_Crc(Crc);
    }

    protected int64 Get_PlanesCrc(const TArray<FCk_RuntimeMesh_PlaneLocal>& InPlanes) const
    {
        auto Crc = Get_CrcStart();
        for (const auto& Plane : InPlanes)
        {
            Crc = Crc_AddVector(Crc, Plane.Get_PositionCm());
            Crc = Crc_AddVector(Crc, Plane.Get_Normal());
            Crc = Crc_AddVector(Crc, Plane.Get_Tangent());
        }

        return Finish_Crc(Crc);
    }

    protected int64 Get_WordsCrc(const TArray<int64>& InWords) const
    {
        auto Crc = Get_CrcStart();
        for (const auto Word : InWords)
        { Crc = Crc_AddWord(Crc, uint64(Word)); }

        return Finish_Crc(Crc);
    }

    protected void Append_PlaneBits(TArray<int64>& OutWords, const FCk_RuntimeMesh_PlaneLocal& InPlane) const
    {
        Append_VectorBits(OutWords, InPlane.Get_PositionCm());
        Append_VectorBits(OutWords, InPlane.Get_Normal());
        Append_VectorBits(OutWords, InPlane.Get_Tangent());
    }

    private void Append_VectorBits(TArray<int64>& OutWords, const FVector& InVector) const
    {
        OutWords.Add(int64(Get_Bits(InVector.X)));
        OutWords.Add(int64(Get_Bits(InVector.Y)));
        OutWords.Add(int64(Get_Bits(InVector.Z)));
    }

    // A plane through InPosition along InNormal; the tangent only orients the cap's UVs.
    protected FCk_RuntimeMesh_PlaneLocal Make_Plane(const FVector& InPosition, const FVector& InNormal) const
    {
        auto Tangent = InNormal.CrossProduct(FVector::UpVector);
        if (Tangent.Size() < 0.1)
        { Tangent = InNormal.CrossProduct(FVector::ForwardVector); }

        auto Plane = FCk_RuntimeMesh_PlaneLocal();
        Plane.Set_PositionCm(InPosition);
        Plane.Set_Normal(InNormal);
        Plane.Set_Tangent(Tangent.GetSafeNormal());
        return Plane;
    }

    protected FMars_TESTONLY_FoodPieceSpike_Rng Make_Rng(int32 InSeed) const
    {
        auto Rng = FMars_TESTONLY_FoodPieceSpike_Rng();
        Rng.State = uint32(InSeed) * uint32(2654435761) + uint32(12345);
        if (Rng.State == 0)
        { Rng.State = 1; }

        for (int32 Warm = 0; Warm < 4; ++Warm)
        { Draw(Rng); }

        return Rng;
    }

    // xorshift32: [0, 1) in steps of 2^-24.
    protected float64 Draw(FMars_TESTONLY_FoodPieceSpike_Rng& InOutRng) const
    {
        auto X = InOutRng.State;
        X = X ^ (X << 13);
        X = X ^ (X >> 17);
        X = X ^ (X << 5);
        InOutRng.State = X;
        return float64(X >> 8) / 16777216.0;
    }

    // [-1, 1).
    protected float64 Draw_Signed(FMars_TESTONLY_FoodPieceSpike_Rng& InOutRng) const
    {
        return Draw(InOutRng) * 2.0 - 1.0;
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Bits and CRC-32
    //----------------------------------------------------------------------------------------------------------------------

    private void Build_Tables()
    {
        _CrcTable.Empty();
        for (uint32 Value = 0; Value < 256; ++Value)
        {
            auto Crc = Value;
            for (int32 Bit = 0; Bit < 8; ++Bit)
            {
                if ((Crc & uint32(1)) != 0)
                { Crc = uint32(0xEDB88320) ^ (Crc >> 1); }
                else
                { Crc = Crc >> 1; }
            }

            _CrcTable.Add(Crc);
        }

        // Doubling and halving are exact, so every entry is an exact power of two.
        _Pow2Up.Empty();
        _Pow2Down.Empty();
        auto Up = 1.0;
        auto Down = 1.0;
        for (int32 Power = 0; Power <= 1023; ++Power)
        {
            _Pow2Up.Add(Up);
            _Pow2Down.Add(Down);
            Up *= 2.0;
            Down *= 0.5;
        }
    }

    protected uint32 Get_CrcStart() const
    {
        return uint32(0xFFFFFFFF);
    }

    protected int64 Finish_Crc(uint32 InCrc) const
    {
        return int64(InCrc ^ uint32(0xFFFFFFFF));
    }

    protected uint32 Crc_AddVector(uint32 InCrc, const FVector& InVector) const
    {
        auto Crc = Crc_AddWord(InCrc, Get_Bits(InVector.X));
        Crc = Crc_AddWord(Crc, Get_Bits(InVector.Y));
        return Crc_AddWord(Crc, Get_Bits(InVector.Z));
    }

    // Little-endian, as the double sits in memory.
    protected uint32 Crc_AddWord(uint32 InCrc, uint64 InWord) const
    {
        auto Crc = InCrc;
        for (uint32 Byte = 0; Byte < 8; ++Byte)
        {
            const auto Value = uint32((InWord >> (Byte * 8)) & uint64(255));
            Crc = _CrcTable[int32((Crc ^ Value) & uint32(255))] ^ (Crc >> 8);
        }

        return Crc;
    }

    // The IEEE-754 bit pattern of InValue, rebuilt by exact arithmetic (scaling by powers of two never rounds). Minus zero
    // reads as zero: telling them apart would need a division by zero, which the script engine traps.
    protected uint64 Get_Bits(float64 InValue) const
    {
        if (InValue != InValue)
        { return uint64(0x7FF8) << 48; }

        auto Sign = uint64(0);
        auto Magnitude = InValue;
        if (InValue < 0.0)
        {
            Sign = uint64(1) << 63;
            Magnitude = -InValue;
        }

        if (Magnitude == 0.0)
        { return Sign; }

        if (Magnitude > 1.7976931348623157e308)
        { return Sign | (uint64(2047) << 52); }

        // Subnormal: the mantissa is the value in units of 2^-1074.
        if (Magnitude < _Pow2Down[1022])
        { return Sign | uint64(Magnitude * _Pow2Up[1000] * _Pow2Up[74]); }

        auto Exponent = int32(Math::FloorToDouble(Math::Log2(Magnitude)));
        auto Mantissa = Scale_ByPowerOfTwo(Magnitude, 52 - Exponent);
        while (Mantissa >= _Pow2Up[53])
        {
            Mantissa *= 0.5;
            Exponent += 1;
        }

        while (Mantissa < _Pow2Up[52])
        {
            Mantissa *= 2.0;
            Exponent -= 1;
        }

        return Sign | (uint64(Exponent + 1023) << 52) | (uint64(Mantissa) - (uint64(1) << 52));
    }

    private float64 Scale_ByPowerOfTwo(float64 InValue, int32 InPower) const
    {
        auto Value = InValue;
        auto Power = InPower;
        while (Power > 1000)
        {
            Value *= _Pow2Up[1000];
            Power -= 1000;
        }

        while (Power < -1000)
        {
            Value *= _Pow2Down[1000];
            Power += 1000;
        }

        return Power >= 0 ? Value * _Pow2Up[Power] : Value * _Pow2Down[-Power];
    }

    protected FString Get_Hex(uint64 InValue) const
    {
        const FString Digits = "0123456789abcdef";
        FString Out;
        for (int32 Nibble = 0; Nibble < 16; ++Nibble)
        {
            const auto Shift = uint32(60 - 4 * Nibble);
            Out += Digits.Mid(int32((InValue >> Shift) & uint64(15)), 1);
        }

        return Out;
    }
}

// The recipe-replay tests for one placed food: 50 seeded lineages of up to 6 committed cuts, each through the real
// FoodPiece cut, one kept half per cut. The client replays every record and compares the kept halves' digests.
UCLASS(Abstract)
class UMars_AutoTestRig_FoodPieceSpike_Replay : UMars_AutoTestRig_FoodPieceSpike
{
    protected const int32 k_Chains = 50;
    protected const int32 k_Depth = 6;
    protected const int32 k_MaxAttempts = 12;
    // The share of the bounds a plane's point may stray from the centre.
    protected const float64 k_PointSpread = 0.5;

    protected UMars_Food_Def Get_Definition() const
    {
        return nullptr;
    }

    // Seeds and the test's own world X.
    protected int32 Get_DefinitionIndex() const
    {
        return 0;
    }

    protected void Begin_Server() override
    {
        const auto Origin = FVector(79000.0 + 1000.0 * float64(Get_DefinitionIndex()), 0.0, 5000.0);
        for (int32 Chain = 0; Chain < k_Chains; ++Chain)
        {
            auto Node = FMars_TESTONLY_FoodPieceSpike_Node();
            Node.Batch = 0;
            Node.Chain = Chain;
            Node.Rng = Make_Rng(1000 * (Get_DefinitionIndex() + 1) + Chain);
            Add_Joint(Get_Definition(), Node, Origin);
        }
    }

    protected TOptional<FCk_RuntimeMesh_PlaneLocal> Plan_Cut(FMars_TESTONLY_FoodPieceSpike_Node& InOutNode, const FCk_RuntimeMesh_Metrics& InMetrics) override
    {
        if (InOutNode.Recipe.Cuts.Num() >= k_Depth || InOutNode.Attempts >= k_MaxAttempts)
        { return TOptional<FCk_RuntimeMesh_PlaneLocal>(); }

        auto Normal = FVector::ZeroVector;
        while (Normal.Size() < 0.3)
        { Normal = FVector(Draw_Signed(InOutNode.Rng), Draw_Signed(InOutNode.Rng), Draw_Signed(InOutNode.Rng)); }

        const auto Min = InMetrics.Get_BoundsMinCm();
        const auto Max = InMetrics.Get_BoundsMaxCm();
        const auto Centre = (Min + Max) * 0.5;
        const auto Half = (Max - Min) * 0.5;
        const auto Offset = FVector(Draw_Signed(InOutNode.Rng) * Half.X, Draw_Signed(InOutNode.Rng) * Half.Y, Draw_Signed(InOutNode.Rng) * Half.Z);
        return TOptional<FCk_RuntimeMesh_PlaneLocal>(Make_Plane(Centre + Offset * k_PointSpread, Normal.GetSafeNormal()));
    }

    protected EMars_TESTONLY_FoodPieceSpike_Keep Choose_Keep(FMars_TESTONLY_FoodPieceSpike_Node& InOutNode) override
    {
        return Draw(InOutNode.Rng) < 0.5 ? EMars_TESTONLY_FoodPieceSpike_Keep::Positive : EMars_TESTONLY_FoodPieceSpike_Keep::Negative;
    }

    protected void Report_Client() override
    {
        const auto FoodName = Get_Definition().GetName().ToString();
        const auto Tally = Tally_Replays();
        Write_DigestFile(FoodName);
        ck::Trace(f"[FoodPieceSpike] replay {FoodName}: {Describe_Tally(Tally)} | slices={_ClientSlices} "
            + f"sliceMs mean={Get_MeanMs() :.2} p95={Get_P95Ms() :.2} (n={_SliceMs.Num()})");

        Assert_Equals_Int(Tally.Steps.Records, k_Chains, "every lineage published one record");
        Assert_Equals_Int(Tally.Roots.MissingDefinition, 0, "every record's definition resolved on the client");
        Assert_Equals_Int(Tally.Roots.Equal, Tally.Roots.Compared, "the client's import of the definition matches the server's joint bit for bit");
        Assert_Equals_Int(Tally.Steps.Rejected, 0, "the client's replay rejected no cut the server committed");
        Assert_Equals_Int(Tally.Mismatch.PlaneDiffers, 0, "every recipe plane arrived bit for bit");
        Assert_Equals_Int(Tally.Steps.Equal, Tally.Steps.Committed, f"every committed cut replays to the same digest ({Describe_Tally(Tally)})");
    }
}
