// Who an anchor turned out to be this run. Spawn and Route anchors are Open or Closed; Hunt anchors are Quarry or
// Other; an anchor the plan does not name resolves with None.
enum EMars_Anchor_Role
{
    None,
    Open,
    Closed,
    Quarry,
    Other
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

    // The anchor that removes this link when it resolves Closed; NAME_None for a link nothing can close.
    UPROPERTY()
    FName ClosedBy;

    FMars_AnchorPlan_Link() {}

    FMars_AnchorPlan_Link(FName InA, FName InB, float32 InCostCm, FName InClosedBy)
    {
        A = InA;
        B = InB;
        CostCm = InCostCm;
        ClosedBy = InClosedBy;
    }
}

struct FMars_AnchorPlan_Entrance
{
    UPROPERTY()
    FName AnchorId;

    UPROPERTY()
    FName PlayerStartTag;

    UPROPERTY()
    FName Node;

    FMars_AnchorPlan_Entrance() {}

    FMars_AnchorPlan_Entrance(FName InAnchorId, FName InPlayerStartTag, FName InNode)
    {
        AnchorId = InAnchorId;
        PlayerStartTag = InPlayerStartTag;
        Node = InNode;
    }
}

struct FMars_AnchorPlan_Court
{
    UPROPERTY()
    FName AnchorId;

    UPROPERTY()
    FName Node;

    FMars_AnchorPlan_Court() {}

    FMars_AnchorPlan_Court(FName InAnchorId, FName InNode)
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

    UPROPERTY()
    TArray<FName> AnchorIds;

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
        }

        TSet<FName> Grouped;
        for (const auto& Group : Groups)
        {
            for (const auto& AnchorId : Group.AnchorIds)
            {
                if (Grouped.Contains(AnchorId))
                { return FMars_Validation("an anchor is in two groups"); }

                Grouped.Add(AnchorId);
            }
        }

        TSet<FName> Closers;
        for (const auto& Link : Links)
        {
            if (Link.ClosedBy.IsNone())
            { continue; }

            if (Grouped.Contains(Link.ClosedBy) == false)
            { return FMars_Validation("a closable link's anchor is in no group"); }

            Closers.Add(Link.ClosedBy);
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

        TSet<FName> EntranceIds;
        for (const auto& Entrance : Entrances)
        {
            if (EntranceIds.Contains(Entrance.AnchorId) || NodeIds.Contains(Entrance.Node) == false)
            { return FMars_Validation("entrances are missing or invalid"); }

            EntranceIds.Add(Entrance.AnchorId);
        }

        if (Courts.Num() < 1)
        { return FMars_Validation("courts are missing or invalid"); }

        for (const auto& Court : Courts)
        {
            if (NodeIds.Contains(Court.Node) == false)
            { return FMars_Validation("courts are missing or invalid"); }
        }

        if (Candidates < 1 || HistoryDepth < 0 || QuarryMinWalkCm < 0.0f)
        { return FMars_Validation("solve settings are out of range"); }

        return FMars_Validation();
    }
}
