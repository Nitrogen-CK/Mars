// Who an anchor turned out to be this run. Spawn and Route anchors are Open or Closed; Hunt anchors are Quarry or
// Other; the plan's cache anchors are Active (within the run's cache budget) or Dormant; an anchor the plan does not
// name resolves with None and draws from its table's Other rows.
enum EMars_Anchor_Role
{
    None,
    Open,
    Closed,
    Quarry,
    Other,
    Active,
    Dormant
}

struct FMars_AnchorPlan_Node
{
    UPROPERTY()
    FName Id;

    // Centimetres, world space. Informational: the debugger and the greybox builder use it; the solve uses link costs.
    UPROPERTY()
    FVector Location;

    FMars_AnchorPlan_Node() {}

    FMars_AnchorPlan_Node(FName InId, FVector InLocation)
    {
        Id = InId;
        Location = InLocation;
    }
}

struct FMars_AnchorPlan_Link
{
    UPROPERTY()
    FName A;

    UPROPERTY()
    FName B;

    // Walk cost in centimetres (a ladder's cost already includes its climb time as walking distance).
    UPROPERTY()
    float32 CostCm = 0.0f;

    // The anchor that removes this link when it resolves Closed; an invalid tag for a link nothing can close.
    UPROPERTY(meta = (Categories = "Anchor"))
    FGameplayTag ClosedBy;

    // For a closable link: the end (A or B) on whose side a one-sided lever gate puts its lever, so a chef who reaches
    // that side (through the crawl beside the gate) opens it for the pack. None: no one-sided row for this gate.
    UPROPERTY()
    FName LeverNode;

    FMars_AnchorPlan_Link() {}

    FMars_AnchorPlan_Link(FName InA, FName InB, float32 InCostCm, FGameplayTag InClosedBy)
    {
        A = InA;
        B = InB;
        CostCm = InCostCm;
        ClosedBy = InClosedBy;
    }
}

struct FMars_AnchorPlan_Entrance
{
    UPROPERTY(meta = (Categories = "Anchor"))
    FGameplayTag AnchorId;

    UPROPERTY()
    FName PlayerStartTag;

    UPROPERTY()
    FName Node;

    FMars_AnchorPlan_Entrance() {}

    FMars_AnchorPlan_Entrance(FGameplayTag InAnchorId, FName InPlayerStartTag, FName InNode)
    {
        AnchorId = InAnchorId;
        PlayerStartTag = InPlayerStartTag;
        Node = InNode;
    }
}

struct FMars_AnchorPlan_Court
{
    UPROPERTY(meta = (Categories = "Anchor"))
    FGameplayTag AnchorId;

    UPROPERTY()
    FName Node;

    FMars_AnchorPlan_Court() {}

    FMars_AnchorPlan_Court(FGameplayTag InAnchorId, FName InNode)
    {
        AnchorId = InAnchorId;
        Node = InNode;
    }
}

struct FMars_AnchorPlan_Group
{
    UPROPERTY()
    FName Name;

    UPROPERTY()
    int32 MaxClosed = 0;

    UPROPERTY(meta = (Categories = "Anchor"))
    TArray<FGameplayTag> AnchorIds;

    FMars_AnchorPlan_Group() {}

    FMars_AnchorPlan_Group(FName InName, int32 InMaxClosed)
    {
        Name = InName;
        MaxClosed = InMaxClosed;
    }
}

// One anchored map: its route graph and the anchors the solve decides. Emitted from Tools/LevelDesign/anchor_plans.
class UMars_AnchorPlan_Def : UDataAsset
{
    UPROPERTY()
    FName MapName;

    UPROPERTY()
    FName Hearth;

    UPROPERTY()
    float32 QuarryMinWalkCm = 9000.0f;

    UPROPERTY()
    int32 Candidates = 8;

    UPROPERTY()
    int32 HistoryDepth = 3;

    UPROPERTY()
    FString SourceRevision;

    UPROPERTY()
    TArray<FMars_AnchorPlan_Node> Nodes;

    UPROPERTY()
    TArray<FMars_AnchorPlan_Link> Links;

    UPROPERTY()
    TArray<FMars_AnchorPlan_Entrance> Entrances;

    UPROPERTY()
    TArray<FMars_AnchorPlan_Court> Courts;

    UPROPERTY()
    TArray<FMars_AnchorPlan_Group> Groups;

    // The cache anchors the run budgets: MaxActiveCaches of them resolve Active, the rest Dormant.
    UPROPERTY(meta = (Categories = "Anchor"))
    TArray<FGameplayTag> Caches;

    UPROPERTY()
    int32 MaxActiveCaches = 2;

    FMars_Validation Validate() const
    {
        TSet<FName> NodeIds;
        for (const auto& Node : Nodes)
        {
            if (Node.Id.IsNone() || NodeIds.Contains(Node.Id))
            { return FMars_Validation("node ids must be unique and set"); }

            NodeIds.Add(Node.Id);
        }

        if (NodeIds.Contains(Hearth) == false)
        { return FMars_Validation("the hearth is not a node"); }

        for (const auto& Link : Links)
        {
            if (NodeIds.Contains(Link.A) == false || NodeIds.Contains(Link.B) == false)
            { return FMars_Validation("a link names an unknown node"); }
        }

        for (const auto& Link : Links)
        {
            if (Link.CostCm <= 0.0f)
            { return FMars_Validation("a link cost must be positive"); }

            if (Link.LeverNode.IsNone() == false && (Link.ClosedBy.IsValid() == false || (Link.LeverNode != Link.A && Link.LeverNode != Link.B)))
            { return FMars_Validation("a lever node must be an end of a closable link"); }
        }

        TArray<FGameplayTag> CacheIds;
        for (const auto& Cache : Caches)
        {
            if (Cache.IsValid() == false || CacheIds.Contains(Cache))
            { return FMars_Validation("cache anchors must be set and unique"); }

            CacheIds.Add(Cache);
        }

        if (MaxActiveCaches < 0)
        { return FMars_Validation("the cache budget cannot be negative"); }

        TArray<FGameplayTag> Grouped;
        for (const auto& Group : Groups)
        {
            for (const auto& AnchorId : Group.AnchorIds)
            {
                if (AnchorId.IsValid() == false)
                { return FMars_Validation("a group names an unset anchor"); }

                if (Grouped.Contains(AnchorId))
                { return FMars_Validation("an anchor is in two groups"); }

                Grouped.Add(AnchorId);
            }
        }

        TArray<FGameplayTag> Closers;
        for (const auto& Link : Links)
        {
            if (Link.ClosedBy.IsValid() == false)
            { continue; }

            if (Grouped.Contains(Link.ClosedBy) == false)
            { return FMars_Validation("a closable link's anchor is in no group"); }

            Closers.AddUnique(Link.ClosedBy);
        }

        for (const auto& AnchorId : Grouped)
        {
            if (Closers.Contains(AnchorId) == false)
            { return FMars_Validation("a group anchor closes no link"); }
        }

        for (const auto& Group : Groups)
        {
            if (Group.MaxClosed < 0 || Group.MaxClosed > Group.AnchorIds.Num())
            { return FMars_Validation("a group cap is out of range"); }
        }

        if (Entrances.Num() < 1)
        { return FMars_Validation("entrances are missing or invalid"); }

        TArray<FGameplayTag> EntranceIds;
        for (const auto& Entrance : Entrances)
        {
            if (Entrance.AnchorId.IsValid() == false || EntranceIds.Contains(Entrance.AnchorId) || NodeIds.Contains(Entrance.Node) == false)
            { return FMars_Validation("entrances are missing or invalid"); }

            EntranceIds.Add(Entrance.AnchorId);
        }

        if (Courts.Num() < 1)
        { return FMars_Validation("courts are missing or invalid"); }

        for (const auto& Court : Courts)
        {
            if (Court.AnchorId.IsValid() == false || NodeIds.Contains(Court.Node) == false)
            { return FMars_Validation("courts are missing or invalid"); }
        }

        if (Candidates < 1 || HistoryDepth < 0 || QuarryMinWalkCm < 0.0f)
        { return FMars_Validation("solve settings are out of range"); }

        return FMars_Validation();
    }
}
