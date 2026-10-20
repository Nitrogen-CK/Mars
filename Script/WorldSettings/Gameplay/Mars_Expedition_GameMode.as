// A run chooses one authored entrance for the whole party. Separate starts inside that foyer avoid stacked pawns.
// Explicitly assigned by the four expedition maps; it does not change the Sandbox or camp game modes.
class AMars_Expedition_GameMode : AMars_Gameplay_GameMode
{
    private FName _Entrance;
    private int32 _NextSlot = 0;
    private TMap<AController, AActor> _AssignedStarts;

    // The PlayerStartTag the whole party starts from. Here a random entrance among the tagged starts, chosen once.
    FName Choose_Entrance(const TArray<APlayerStart>& InStarts)
    {
        if (_Entrance != NAME_None)
        { return _Entrance; }

        TArray<FName> Entrances;
        for (auto Start : InStarts)
        {
            if (IsValid(Start) && Start.PlayerStartTag != NAME_None)
            { Entrances.AddUnique(Start.PlayerStartTag); }
        }

        if (ck::EnsureIfNot(Entrances.Num() > 0, "[ExpeditionGameMode] no PlayerStart carries a PlayerStartTag"))
        { return NAME_None; }

        _Entrance = Entrances[Math::RandRange(0, Entrances.Num() - 1)];
        return _Entrance;
    }

    // Each player keeps the start first assigned to it; new players take the entrance's starts in turn.
    UFUNCTION(BlueprintOverride)
    AActor ChoosePlayerStart(AController Player)
    {
        AActor Assigned;
        if (_AssignedStarts.Find(Player, Assigned) && IsValid(Assigned))
        { return Assigned; }

        TArray<APlayerStart> Starts;
        GetAllActorsOfClass(Starts);
        const auto Entrance = Choose_Entrance(Starts);
        if (Entrance == NAME_None)
        { return nullptr; }

        TArray<AActor> Slots;
        for (auto Start : Starts)
        {
            if (IsValid(Start) && Start.PlayerStartTag == Entrance)
            { Slots.Add(Start); }
        }

        if (ck::EnsureIfNot(Slots.Num() > 0, f"[ExpeditionGameMode] no PlayerStart tagged {Entrance.ToString()}"))
        { return nullptr; }

        auto Chosen = Slots[_NextSlot % Slots.Num()];
        ++_NextSlot;
        _AssignedStarts.Add(Player, Chosen);
        return Chosen;
    }
}
