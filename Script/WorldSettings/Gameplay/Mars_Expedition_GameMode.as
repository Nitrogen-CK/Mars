// A run chooses one authored entrance for the whole party. Separate starts inside that foyer avoid stacked pawns.
// Explicitly assigned by the four expedition maps; it does not change the Sandbox or camp game modes.
class AMars_Expedition_GameMode : AMars_Gameplay_GameMode
{
    private FName _Entrance;
    private int32 _NextSlot = 0;
    private TArray<AController> _Controllers;
    private TArray<AActor> _AssignedStarts;

    UFUNCTION(BlueprintOverride)
    AActor ChoosePlayerStart(AController Player)
    {
        for (int32 Index = 0; Index < _Controllers.Num(); ++Index)
        {
            if (_Controllers[Index] == Player && IsValid(_AssignedStarts[Index]))
            { return _AssignedStarts[Index]; }
        }

        TArray<APlayerStart> Starts;
        GetAllActorsOfClass(Starts);
        TArray<FName> Entrances;
        for (auto Start : Starts)
        {
            if (IsValid(Start) && Start.PlayerStartTag != NAME_None)
            { Entrances.AddUnique(Start.PlayerStartTag); }
        }
        if (Entrances.IsEmpty())
        { return nullptr; }

        if (_Entrance == NAME_None)
        { _Entrance = Entrances[Math::RandRange(0, Entrances.Num() - 1)]; }

        TArray<AActor> Slots;
        for (auto Start : Starts)
        {
            if (IsValid(Start) && Start.PlayerStartTag == _Entrance)
            { Slots.Add(Start); }
        }
        if (Slots.IsEmpty())
        { return nullptr; }

        auto Chosen = Slots[_NextSlot % Slots.Num()];
        ++_NextSlot;
        _Controllers.Add(Player);
        _AssignedStarts.Add(Chosen);
        return Chosen;
    }
}
