// The host's last runs per anchored map, so the next solve can walk differently. Pure data and a game-instance store;
// the slice keeps it for this process only (no save).

// Newest first, never longer than its depth.
struct FMars_AnchorRun_History
{
    UPROPERTY()
    TArray<FMars_AnchorRun_Record> Records;

    void Push(const FMars_AnchorRun_Record& InRecord, int32 InDepth)
    {
        Records.Insert(InRecord, 0);
        while (Records.Num() > Math::Max(InDepth, 0))
        { Records.RemoveAt(Records.Num() - 1); }
    }
}

class UMars_AnchorRunHistory_Subsystem : UScriptGameInstanceSubsystem
{
    private TMap<FName, FMars_AnchorRun_History> _ByMap;

    // Empty when the map has no runs yet.
    FMars_AnchorRun_History Get_History(FName InMapName) const
    {
        FMars_AnchorRun_History History;
        _ByMap.Find(InMapName, History);
        return History;
    }

    void Record(FName InMapName, const FMars_AnchorRun_Record& InRecord, int32 InDepth)
    {
        auto History = Get_History(InMapName);
        History.Push(InRecord, InDepth);
        _ByMap.Add(InMapName, History);
    }
}
