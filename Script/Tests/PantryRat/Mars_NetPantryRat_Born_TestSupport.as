// The born rat's spawn params, by the script's ExposeOnSpawn names.
struct FMars_NetPantryRat_Born_SpawnParams
{
    UPROPERTY()
    FTransform SpawnTransform = FTransform::Identity;

    UPROPERTY()
    FMars_PantryRat_Spec Spec;

    UPROPERTY()
    bool WithVisuals = true;

    UPROPERTY()
    bool BuildBodyHeadless = false;

    UPROPERTY()
    TArray<EMars_PantryRat_Phase> BornThrough;
}

// The real rat script; with authority over a composed rat it also asks its kernel, from its construct, to advance
// through BornThrough in order. The requests are the rat's own: its drain applies them in the spawn frame and publishes
// the ledger, so a copy is born into the last of them.
class UMars_NetPantryRat_Born_EntityScript : UMars_PantryRat_EntityScript
{
    UPROPERTY(ExposeOnSpawn)
    TArray<EMars_PantryRat_Phase> BornThrough;

    UFUNCTION(BlueprintOverride)
    ECk_EntityScript_ConstructionFlow DoConstruct(FCk_Handle& InHandle)
    {
        const auto Flow = Super::DoConstruct(InHandle);
        if (utils_net::Get_HasAuthority(InHandle) == false || InHandle.Is_PantryRat() == false)
        { return Flow; }

        auto Rat = InHandle.As_PantryRat();
        auto From = Rat.Get_Phase();
        for (const auto To : BornThrough)
        {
            Rat.Request_Advance(FMars_Request_PantryRat_Advance(From, To));
            From = To;
        }

        return Flow;
    }
}
