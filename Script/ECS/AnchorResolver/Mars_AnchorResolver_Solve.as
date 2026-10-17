// The run solve: one seeded, pure choice of the party's entrance, the route anchors that close and the court that holds
// the quarry, scored for how differently it walks from the last runs. No world, no entities: tests call it directly,
// the game mode calls it once per run. Determinism is the contract - every draw comes from one FRandomStream in a fixed
// order, and every set is sorted by lowercase name before it is drawn from.

struct FMars_AnchorGraph
{
    // Node index = position here, sorted by lowercase name.
    UPROPERTY()
    TArray<FName> NodeIds;

    // Parallel to UMars_AnchorPlan_Def.Links (same link index); A and B are node indices.
    UPROPERTY()
    TArray<int32> LinkA;

    UPROPERTY()
    TArray<int32> LinkB;

    UPROPERTY()
    TArray<float32> LinkCost;

    UPROPERTY()
    TArray<FGameplayTag> LinkClosedBy;
}

struct FMars_AnchorGraph_Query
{
    UPROPERTY()
    FName From;

    UPROPERTY()
    TArray<FGameplayTag> Closed;

    FMars_AnchorGraph_Query() {}

    FMars_AnchorGraph_Query(FName InFrom, const TArray<FGameplayTag>& InClosed)
    {
        From = InFrom;
        Closed = InClosed;
    }
}

// One entry per node index.
struct FMars_AnchorGraph_Paths
{
    UPROPERTY()
    TArray<bool> Reached;

    UPROPERTY()
    TArray<float32> Dist;

    // k_NoIndex (-1) at the source and at unreached nodes.
    UPROPERTY()
    TArray<int32> PrevLink;

    UPROPERTY()
    TArray<int32> PrevNode;
}

struct FMars_AnchorClosureSet
{
    UPROPERTY()
    TArray<FGameplayTag> Closed;
}

struct FMars_AnchorConnectivity_Query
{
    UPROPERTY()
    FName From;

    UPROPERTY()
    TArray<FGameplayTag> Closed;

    UPROPERTY()
    TArray<FName> MustReach;

    FMars_AnchorConnectivity_Query() {}

    FMars_AnchorConnectivity_Query(FName InFrom, const TArray<FGameplayTag>& InClosed, const TArray<FName>& InMustReach)
    {
        From = InFrom;
        Closed = InClosed;
        MustReach = InMustReach;
    }
}

struct FMars_AnchorWalk_Query
{
    UPROPERTY()
    FName Entrance;

    UPROPERTY()
    FName Quarry;

    UPROPERTY()
    FName Hearth;

    UPROPERTY()
    TArray<FGameplayTag> Closed;

    FMars_AnchorWalk_Query() {}

    FMars_AnchorWalk_Query(FName InEntrance, FName InQuarry, FName InHearth, const TArray<FGameplayTag>& InClosed)
    {
        Entrance = InEntrance;
        Quarry = InQuarry;
        Hearth = InHearth;
        Closed = InClosed;
    }
}

// One finished run, kept as history (newest first).
struct FMars_AnchorRun_Record
{
    // Entrance anchor id.
    UPROPERTY()
    FGameplayTag Entrance;

    // Court anchor id.
    UPROPERTY()
    FGameplayTag Quarry;

    UPROPERTY()
    TArray<int32> WalkedLinks;
}

struct FMars_AnchorRun_Input
{
    UPROPERTY()
    int32 Seed = 0;

    // Newest first.
    UPROPERTY()
    TArray<FMars_AnchorRun_Record> History;
}

struct FMars_AnchorRun_RoleEntry
{
    UPROPERTY()
    FGameplayTag AnchorId;

    UPROPERTY()
    EMars_Anchor_Role Role = EMars_Anchor_Role::None;

    FMars_AnchorRun_RoleEntry() {}

    FMars_AnchorRun_RoleEntry(FGameplayTag InAnchorId, EMars_Anchor_Role InRole)
    {
        AnchorId = InAnchorId;
        Role = InRole;
    }
}

struct FMars_AnchorRun_Result
{
    UPROPERTY()
    int32 Seed = 0;

    UPROPERTY()
    FGameplayTag Entrance;

    UPROPERTY()
    FName PlayerStartTag;

    UPROPERTY()
    FGameplayTag Quarry;

    // Sorted.
    UPROPERTY()
    TArray<FGameplayTag> Closed;

    // Sorted by AnchorId.
    UPROPERTY()
    TArray<FMars_AnchorRun_RoleEntry> Roles;

    // Sorted, unique.
    UPROPERTY()
    TArray<int32> WalkedLinks;

    UPROPERTY()
    float32 Divergence = 0.0f;

    UPROPERTY()
    int32 CandidatesRejected = 0;

    UPROPERTY()
    bool UsedFallback = false;

    // None when the plan does not name the anchor.
    EMars_Anchor_Role Get_Role(FGameplayTag InAnchorId) const
    {
        for (const auto& Entry : Roles)
        {
            if (Entry.AnchorId == InAnchorId)
            { return Entry.Role; }
        }
        return EMars_Anchor_Role::None;
    }

    FMars_AnchorRun_Record To_Record() const
    {
        auto Record = FMars_AnchorRun_Record();
        Record.Entrance = Entrance;
        Record.Quarry = Quarry;
        Record.WalkedLinks = WalkedLinks;
        return Record;
    }
}

struct FMars_AnchorRow_Query
{
    UPROPERTY()
    EMars_Anchor_Role Role = EMars_Anchor_Role::None;

    UPROPERTY()
    int32 RunSeed = 0;

    UPROPERTY()
    FGameplayTag AnchorId;

    UPROPERTY()
    TOptional<int32> PinnedRow;
}

struct FMars_AnchorRow_Pick
{
    UPROPERTY()
    TOptional<int32> RowIndex;

    UPROPERTY()
    bool Pinned = false;

    UPROPERTY()
    bool RoleMismatch = false;
}

namespace utils_anchor_resolver
{
    // A node or link index that is not there (AngelScript has no INDEX_NONE).
    const int32 k_NoIndex = -1;

    FString Get_SortKey(FName InId)
    { return InId.ToString().ToLower(); }

    // Anchor ids are tags; the key is the lowercase tag string, so the order never depends on the tag table.
    FString Get_SortKey(FGameplayTag InId)
    { return InId.ToString().ToLower(); }

    // Insertion sort by lowercase name: FName comparison would follow name-table indices, which differ per process.
    void Sort_Names(TArray<FName>& InOutNames)
    {
        for (int32 Index = 1; Index < InOutNames.Num(); ++Index)
        {
            const auto Moving = InOutNames[Index];
            const auto Key = Get_SortKey(Moving);
            auto Slot = Index - 1;
            while (Slot >= 0 && Get_SortKey(InOutNames[Slot]) > Key)
            {
                InOutNames[Slot + 1] = InOutNames[Slot];
                --Slot;
            }
            InOutNames[Slot + 1] = Moving;
        }
    }

    void Sort_Tags(TArray<FGameplayTag>& InOutIds)
    {
        for (int32 Index = 1; Index < InOutIds.Num(); ++Index)
        {
            const auto Moving = InOutIds[Index];
            const auto Key = Get_SortKey(Moving);
            auto Slot = Index - 1;
            while (Slot >= 0 && Get_SortKey(InOutIds[Slot]) > Key)
            {
                InOutIds[Slot + 1] = InOutIds[Slot];
                --Slot;
            }
            InOutIds[Slot + 1] = Moving;
        }
    }

    TArray<FMars_AnchorPlan_Entrance> Get_SortedEntrances(const UMars_AnchorPlan_Def InPlan)
    {
        auto Sorted = InPlan.Entrances;
        for (int32 Index = 1; Index < Sorted.Num(); ++Index)
        {
            const auto Moving = Sorted[Index];
            const auto Key = Get_SortKey(Moving.AnchorId);
            auto Slot = Index - 1;
            while (Slot >= 0 && Get_SortKey(Sorted[Slot].AnchorId) > Key)
            {
                Sorted[Slot + 1] = Sorted[Slot];
                --Slot;
            }
            Sorted[Slot + 1] = Moving;
        }
        return Sorted;
    }

    void Sort_Roles(TArray<FMars_AnchorRun_RoleEntry>& InOutRoles)
    {
        for (int32 Index = 1; Index < InOutRoles.Num(); ++Index)
        {
            const auto Moving = InOutRoles[Index];
            const auto Key = Get_SortKey(Moving.AnchorId);
            auto Slot = Index - 1;
            while (Slot >= 0 && Get_SortKey(InOutRoles[Slot].AnchorId) > Key)
            {
                InOutRoles[Slot + 1] = InOutRoles[Slot];
                --Slot;
            }
            InOutRoles[Slot + 1] = Moving;
        }
    }

    int32 Get_NodeIndex(const FMars_AnchorGraph& InGraph, FName InId)
    {
        for (int32 Index = 0; Index < InGraph.NodeIds.Num(); ++Index)
        {
            if (InGraph.NodeIds[Index] == InId)
            { return Index; }
        }
        return k_NoIndex;
    }

    FMars_AnchorGraph Make_Graph(const UMars_AnchorPlan_Def InPlan)
    {
        auto Graph = FMars_AnchorGraph();
        for (const auto& Node : InPlan.Nodes)
        { Graph.NodeIds.Add(Node.Id); }

        Sort_Names(Graph.NodeIds);

        for (const auto& Link : InPlan.Links)
        {
            Graph.LinkA.Add(Get_NodeIndex(Graph, Link.A));
            Graph.LinkB.Add(Get_NodeIndex(Graph, Link.B));
            Graph.LinkCost.Add(Link.CostCm);
            Graph.LinkClosedBy.Add(Link.ClosedBy);
        }
        return Graph;
    }

    // Dijkstra without a heap (the plans have under 64 nodes): the unvisited reached node with the smallest distance goes
    // next, ties to the lower node index; links relax in ascending index; a distance only ever strictly improves.
    FMars_AnchorGraph_Paths Get_ShortestPaths(const FMars_AnchorGraph& InGraph, const FMars_AnchorGraph_Query& InQuery)
    {
        auto Paths = FMars_AnchorGraph_Paths();
        const auto NodeCount = InGraph.NodeIds.Num();
        auto Visited = TArray<bool>();
        for (int32 Index = 0; Index < NodeCount; ++Index)
        {
            Paths.Reached.Add(false);
            Paths.Dist.Add(0.0f);
            Paths.PrevLink.Add(k_NoIndex);
            Paths.PrevNode.Add(k_NoIndex);
            Visited.Add(false);
        }

        const auto Source = Get_NodeIndex(InGraph, InQuery.From);
        if (Source == k_NoIndex)
        { return Paths; }

        Paths.Reached[Source] = true;
        while (true)
        {
            auto Current = k_NoIndex;
            for (int32 Index = 0; Index < NodeCount; ++Index)
            {
                if (Visited[Index] || Paths.Reached[Index] == false)
                { continue; }

                if (Current == k_NoIndex || Paths.Dist[Index] < Paths.Dist[Current])
                { Current = Index; }
            }

            if (Current == k_NoIndex)
            { break; }

            Visited[Current] = true;
            for (int32 Link = 0; Link < InGraph.LinkA.Num(); ++Link)
            {
                const auto ClosedBy = InGraph.LinkClosedBy[Link];
                if (ClosedBy.IsValid() && InQuery.Closed.Contains(ClosedBy))
                { continue; }

                auto Other = k_NoIndex;
                if (InGraph.LinkA[Link] == Current)
                { Other = InGraph.LinkB[Link]; }
                else if (InGraph.LinkB[Link] == Current)
                { Other = InGraph.LinkA[Link]; }

                if (Other == k_NoIndex || Visited[Other])
                { continue; }

                const auto Candidate = Paths.Dist[Current] + InGraph.LinkCost[Link];
                if (Paths.Reached[Other] == false || Candidate < Paths.Dist[Other])
                {
                    Paths.Reached[Other] = true;
                    Paths.Dist[Other] = Candidate;
                    Paths.PrevLink[Other] = Link;
                    Paths.PrevNode[Other] = Current;
                }
            }
        }
        return Paths;
    }

    TOptional<float32> Get_Distance(const FMars_AnchorGraph& InGraph, const FMars_AnchorGraph_Paths& InPaths, FName InTo)
    {
        const auto Index = Get_NodeIndex(InGraph, InTo);
        if (Index == k_NoIndex || InPaths.Reached[Index] == false)
        { return TOptional<float32>(); }

        return TOptional<float32>(InPaths.Dist[Index]);
    }

    TArray<int32> Get_PathLinks(const FMars_AnchorGraph& InGraph, const FMars_AnchorGraph_Paths& InPaths, FName InTo)
    {
        auto Links = TArray<int32>();
        auto Index = Get_NodeIndex(InGraph, InTo);
        if (Index == k_NoIndex || InPaths.Reached[Index] == false)
        { return Links; }

        while (InPaths.PrevLink[Index] != k_NoIndex)
        {
            Links.Add(InPaths.PrevLink[Index]);
            Index = InPaths.PrevNode[Index];
        }
        return Links;
    }

    bool Get_KeepsConnected(const FMars_AnchorGraph& InGraph, const FMars_AnchorConnectivity_Query& InQuery)
    {
        const auto Paths = Get_ShortestPaths(InGraph, FMars_AnchorGraph_Query(InQuery.From, InQuery.Closed));
        for (const auto& Target : InQuery.MustReach)
        {
            if (Get_Distance(InGraph, Paths, Target).IsSet() == false)
            { return false; }
        }
        return true;
    }

    // Every combination of InSize ids, in lexicographic index order.
    void Append_Combinations(const TArray<FGameplayTag>& InIds, int32 InSize, TArray<FMars_AnchorClosureSet>& OutSets)
    {
        if (InSize == 0)
        {
            OutSets.Add(FMars_AnchorClosureSet());
            return;
        }

        if (InSize > InIds.Num())
        { return; }

        auto Picks = TArray<int32>();
        for (int32 Index = 0; Index < InSize; ++Index)
        { Picks.Add(Index); }

        while (true)
        {
            auto Set = FMars_AnchorClosureSet();
            for (const auto Pick : Picks)
            { Set.Closed.Add(InIds[Pick]); }
            OutSets.Add(Set);

            auto Slot = InSize - 1;
            while (Slot >= 0 && Picks[Slot] == InIds.Num() - InSize + Slot)
            { --Slot; }

            if (Slot < 0)
            { return; }

            Picks[Slot] = Picks[Slot] + 1;
            for (int32 Next = Slot + 1; Next < InSize; ++Next)
            { Picks[Next] = Picks[Next - 1] + 1; }
        }
    }

    TArray<FMars_AnchorClosureSet> Get_LegalClosureSets(const UMars_AnchorPlan_Def InPlan)
    {
        auto Sets = TArray<FMars_AnchorClosureSet>();
        Sets.Add(FMars_AnchorClosureSet());
        for (const auto& Group : InPlan.Groups)
        {
            auto Ids = Group.AnchorIds;
            Sort_Tags(Ids);

            auto GroupSets = TArray<FMars_AnchorClosureSet>();
            for (int32 Size = 0; Size <= Group.MaxClosed; ++Size)
            { Append_Combinations(Ids, Size, GroupSets); }

            auto Product = TArray<FMars_AnchorClosureSet>();
            for (const auto& Existing : Sets)
            {
                for (const auto& Addition : GroupSets)
                {
                    auto Combined = Existing;
                    Combined.Closed.Append(Addition.Closed);
                    Sort_Tags(Combined.Closed);
                    Product.Add(Combined);
                }
            }
            Sets = Product;
        }
        return Sets;
    }

    float32 Get_Divergence(const TArray<int32>& InA, const TArray<int32>& InB)
    {
        auto Union = TSet<int32>();
        auto Shared = 0;
        for (const auto Link : InA)
        { Union.Add(Link); }

        for (const auto Link : InB)
        {
            if (InA.Contains(Link))
            { ++Shared; }
            Union.Add(Link);
        }

        if (Union.Num() == 0)
        { return 0.0f; }

        return 1.0f - float32(Shared) / float32(Union.Num());
    }

    // FNV-1a 32-bit over an already-lowercased string: stable across processes, unlike a name-table or tag-table index.
    uint32 Get_StableHash_Lower(const FString& InText)
    {
        const auto Text = InText;
        auto Hash = uint32(2166136261);
        for (int32 Index = 0; Index < Text.Len(); ++Index)
        {
            Hash = Hash ^ uint32(uint16(Text[Index]));
            Hash = Hash * uint32(16777619);
        }
        return Hash;
    }

    // The anchor's hash is over its lowercase tag string ("anchor.mars.warrens.r1").
    uint32 Get_StableHash(FGameplayTag InId)
    { return Get_StableHash_Lower(Get_SortKey(InId)); }

    int32 Get_AnchorSeed(int32 InRunSeed, FGameplayTag InAnchorId)
    { return int32(Get_StableHash(InAnchorId) ^ (uint32(InRunSeed) * uint32(2654435761))); }

    // The run stream's seed: the run seed mixed with a fixed key, so the first draws of consecutive seeds differ.
    int32 Get_RunSeed(int32 InRunSeed)
    { return int32(Get_StableHash_Lower("run") ^ (uint32(InRunSeed) * uint32(2654435761))); }

    // Mean divergence against the newest InDepth records; 1.0 with no history.
    float32 Get_Score(const TArray<int32>& InWalk, const FMars_AnchorRun_Input& InInput, int32 InDepth)
    {
        const auto Count = Math::Min(InDepth, InInput.History.Num());
        if (Count <= 0)
        { return 1.0f; }

        auto Sum = 0.0f;
        for (int32 Index = 0; Index < Count; ++Index)
        { Sum += Get_Divergence(InWalk, InInput.History[Index].WalkedLinks); }

        return Sum / float32(Count);
    }

    // Entrance -> quarry and quarry -> hearth under the same closures, as one sorted set of link indices.
    TArray<int32> Get_Walk(const FMars_AnchorGraph& InGraph, const FMars_AnchorWalk_Query& InQuery)
    {
        const auto Inbound = Get_ShortestPaths(InGraph, FMars_AnchorGraph_Query(InQuery.Entrance, InQuery.Closed));
        const auto Outbound = Get_ShortestPaths(InGraph, FMars_AnchorGraph_Query(InQuery.Quarry, InQuery.Closed));

        auto Walk = Get_PathLinks(InGraph, Inbound, InQuery.Quarry);
        for (const auto Link : Get_PathLinks(InGraph, Outbound, InQuery.Hearth))
        {
            if (Walk.Contains(Link) == false)
            { Walk.Add(Link); }
        }
        Walk.Sort();
        return Walk;
    }

    FMars_AnchorRun_Result Solve(const UMars_AnchorPlan_Def InPlan, const FMars_AnchorRun_Input& InInput)
    {
        auto Result = FMars_AnchorRun_Result();
        Result.Seed = InInput.Seed;
        // Mixed first: FRandomStream is a linear congruential generator, so raw consecutive seeds (?seed=1, 2, 3...) give
        // nearly the same first draws and would all pick the same entrance.
        auto Stream = FRandomStream(Get_RunSeed(InInput.Seed));
        const auto HasHistory = InInput.History.Num() > 0;

        // 1. The entrance, drawn first: it depends on the seed and the last run only.
        auto Eligible = Get_SortedEntrances(InPlan);
        if (Eligible.Num() >= 3 && HasHistory)
        {
            for (int32 Index = Eligible.Num() - 1; Index >= 0; --Index)
            {
                if (Eligible[Index].AnchorId == InInput.History[0].Entrance)
                { Eligible.RemoveAt(Index); }
            }
        }
        const auto Entrance = Eligible[Stream.RandRange(0, Eligible.Num() - 1)];

        // 2. The graph and what every candidate must keep reachable.
        const auto Graph = Make_Graph(InPlan);
        auto MustReach = TArray<FName>();
        MustReach.Add(InPlan.Hearth);
        for (const auto& Court : InPlan.Courts)
        { MustReach.Add(Court.Node); }

        const auto ExcludeLastQuarry = InPlan.Courts.Num() >= 2 && HasHistory;
        auto HasBest = false;
        auto BestScore = 0.0f;
        auto BestClosed = TArray<FGameplayTag>();
        auto BestQuarry = FMars_AnchorPlan_Court();
        auto BestWalk = TArray<int32>();

        // 3. Candidates: closures, hard rules, quarry court, divergence score.
        for (int32 Candidate = 0; Candidate < InPlan.Candidates; ++Candidate)
        {
            auto Closed = TArray<FGameplayTag>();
            for (const auto& Group : InPlan.Groups)
            {
                auto Ids = Group.AnchorIds;
                Sort_Tags(Ids);
                const auto Count = Stream.RandRange(0, Group.MaxClosed);
                for (int32 Index = 0; Index < Count; ++Index)
                {
                    const auto Swap = Stream.RandRange(Index, Ids.Num() - 1);
                    const auto Held = Ids[Index];
                    Ids[Index] = Ids[Swap];
                    Ids[Swap] = Held;
                }
                for (int32 Index = 0; Index < Count; ++Index)
                { Closed.Add(Ids[Index]); }
            }
            Sort_Tags(Closed);

            const auto Paths = Get_ShortestPaths(Graph, FMars_AnchorGraph_Query(Entrance.Node, Closed));
            auto KeepsConnected = true;
            for (const auto& Target : MustReach)
            {
                if (Get_Distance(Graph, Paths, Target).IsSet() == false)
                { KeepsConnected = false; }
            }

            if (KeepsConnected == false)
            {
                ++Result.CandidatesRejected;
                continue;
            }

            auto Courts = TArray<FMars_AnchorPlan_Court>();
            for (const auto& Court : InPlan.Courts)
            {
                if (ExcludeLastQuarry && Court.AnchorId == InInput.History[0].Quarry)
                { continue; }

                if (Get_Distance(Graph, Paths, Court.Node).Get(0.0f) >= InPlan.QuarryMinWalkCm)
                { Courts.Add(Court); }
            }

            if (Courts.Num() == 0)
            {
                ++Result.CandidatesRejected;
                continue;
            }

            const auto Quarry = Courts[Stream.RandRange(0, Courts.Num() - 1)];
            const auto Walk = Get_Walk(Graph, FMars_AnchorWalk_Query(Entrance.Node, Quarry.Node, InPlan.Hearth, Closed));
            const auto Score = Get_Score(Walk, InInput, InPlan.HistoryDepth);
            if (HasBest == false || Score > BestScore)
            {
                HasBest = true;
                BestScore = Score;
                BestClosed = Closed;
                BestQuarry = Quarry;
                BestWalk = Walk;
            }
        }

        // 4. Fallback: an open map and the farthest court.
        if (HasBest == false)
        {
            const auto Open = Get_ShortestPaths(Graph, FMars_AnchorGraph_Query(Entrance.Node, TArray<FGameplayTag>()));
            auto HasFarthest = false;
            auto Farthest = 0.0f;
            for (const auto& Court : InPlan.Courts)
            {
                if (ExcludeLastQuarry && Court.AnchorId == InInput.History[0].Quarry)
                { continue; }

                const auto Distance = Get_Distance(Graph, Open, Court.Node);
                if (Distance.IsSet() && (HasFarthest == false || Distance.GetValue() > Farthest))
                {
                    HasFarthest = true;
                    Farthest = Distance.GetValue();
                    BestQuarry = Court;
                }
            }

            if (HasFarthest == false)
            { BestQuarry = InPlan.Courts[0]; }

            BestClosed.Reset();
            BestWalk = Get_Walk(Graph, FMars_AnchorWalk_Query(Entrance.Node, BestQuarry.Node, InPlan.Hearth, BestClosed));
            BestScore = Get_Score(BestWalk, InInput, InPlan.HistoryDepth);
            Result.UsedFallback = true;
            LogDisplay(f"Anchor solve fell back to an open map (seed {InInput.Seed})");
        }

        // 5. The result and every planned anchor's role.
        Result.Entrance = Entrance.AnchorId;
        Result.PlayerStartTag = Entrance.PlayerStartTag;
        Result.Quarry = BestQuarry.AnchorId;
        Result.Closed = BestClosed;
        Result.WalkedLinks = BestWalk;
        Result.Divergence = BestScore;

        for (const auto& Each : InPlan.Entrances)
        {
            const auto Role = Each.AnchorId == Entrance.AnchorId ? EMars_Anchor_Role::Open : EMars_Anchor_Role::Closed;
            Result.Roles.Add(FMars_AnchorRun_RoleEntry(Each.AnchorId, Role));
        }

        for (const auto& Group : InPlan.Groups)
        {
            for (const auto& AnchorId : Group.AnchorIds)
            {
                const auto Role = BestClosed.Contains(AnchorId) ? EMars_Anchor_Role::Closed : EMars_Anchor_Role::Open;
                Result.Roles.Add(FMars_AnchorRun_RoleEntry(AnchorId, Role));
            }
        }

        for (const auto& Court : InPlan.Courts)
        {
            const auto Role = Court.AnchorId == BestQuarry.AnchorId ? EMars_Anchor_Role::Quarry : EMars_Anchor_Role::Other;
            Result.Roles.Add(FMars_AnchorRun_RoleEntry(Court.AnchorId, Role));
        }

        Sort_Roles(Result.Roles);
        return Result;
    }

    // One anchor's row: a pin in range wins (and is marked); otherwise a weighted draw over the rows whose Role matches
    // the solved role (None, an unplanned anchor, draws from the Other rows), from a stream seeded by the run seed and
    // the anchor id alone, so the order anchors appear in never changes a draw.
    FMars_AnchorRow_Pick Pick_Row(const UMars_AnchorTable_Def InTable, const FMars_AnchorRow_Query& InQuery)
    {
        auto Pick = FMars_AnchorRow_Pick();
        if (InQuery.PinnedRow.IsSet() && InQuery.PinnedRow.GetValue() >= 0 && InQuery.PinnedRow.GetValue() < InTable.Rows.Num())
        {
            const auto Pinned = InQuery.PinnedRow.GetValue();
            Pick.RowIndex = TOptional<int32>(Pinned);
            Pick.Pinned = true;
            Pick.RoleMismatch = InTable.Rows[Pinned].Role != InQuery.Role;
            return Pick;
        }

        const auto Wanted = InQuery.Role == EMars_Anchor_Role::None ? EMars_Anchor_Role::Other : InQuery.Role;
        auto Eligible = TArray<int32>();
        auto Weights = TArray<float64>();
        for (int32 Index = 0; Index < InTable.Rows.Num(); ++Index)
        {
            if (InTable.Rows[Index].Role != Wanted)
            { continue; }

            Eligible.Add(Index);
            Weights.Add(float64(InTable.Rows[Index].Weight));
        }

        if (Eligible.Num() == 0)
        { return Pick; }

        auto Stream = FRandomStream(Get_AnchorSeed(InQuery.RunSeed, InQuery.AnchorId));
        const auto Drawn = utils_probability::Get_RandomIndexByWeight_Stream(Weights, Stream)._Index;
        if (Drawn >= 0 && Drawn < Eligible.Num())
        { Pick.RowIndex = TOptional<int32>(Eligible[Drawn]); }

        return Pick;
    }

    // The run seed from a travel URL's options ("?seed=7"); unset when the URL names none. An explicit seed is a repro
    // request, so the game mode then solves with an empty history.
    TOptional<int32> Get_SeedFromOptions(const FString& InOptions)
    {
        if (Gameplay::HasOption(InOptions, "seed") == false)
        { return TOptional<int32>(); }

        return TOptional<int32>(Gameplay::GetIntOption(InOptions, "seed", 0));
    }
}
