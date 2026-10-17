// Expedition placement preset: uses the existing spider rig and attack catalogue, with bounds relative to this spawn.
// Unlike the Sandbox demonstration it does not listen to a Room5 channel or roam toward Room5's coordinates.
class UMars_Expedition_Crawler_EntityScript : UMars_Crawler_EntityScript
{
    UFUNCTION(BlueprintOverride)
    ECk_EntityScript_ConstructionFlow DoConstruct(FCk_Handle& InHandle)
    {
        Spec.LegCount = 6;
        Spec.Layout = EMars_Crawler_Layout::Spider;
        Spec.MinLegsToWalk = 3;
        const auto Centre = SpawnTransform.GetLocation();
        Spec.RoamBounds = FBox(Centre - FVector(900.0, 700.0, 80.0), Centre + FVector(900.0, 700.0, 200.0));
        Spec.Combat.Enabled = true;
        Spec.Combat.StartAggressive = ECk_EnableDisable::Enable;
        // Court-wide threat: default six-metre home radius left the authored approach and protein table safe.
        Spec.Combat.Targeting.AcquireRadius = 1100.0f;
        Spec.Combat.Targeting.LoseRadius = 1400.0f;
        Spec.Combat.Targeting.HomeRadius = 1000.0f;
        Spec.Combat.Loadout = utils_crawler::Get_AttackReferenceLoadout(EMars_Crawler_AttackPreset::Spider6, false);
        Color = FLinearColor(0.35f, 0.55f, 0.2f, 1.0f);

        Look.Body = Get_Piece("Body");
        Look.Foot = Get_Piece("Foot");
        Look.Fang = Get_Piece("Fang");
        Look.FangRoot = FVector(87.4, 16.39, -28.95);
        Look.Legs.Empty();
        auto Pairs = TArray<FString>();
        Pairs.Add("Front");
        Pairs.Add("Mid");
        Pairs.Add("Back");
        Pairs.Add("Back");
        Pairs.Add("Mid");
        Pairs.Add("Front");
        for (const auto& Pair : Pairs)
        { Look.Legs.Add(FMars_Crawler_LegLook(Get_Piece(f"LegUpper{Pair}"), Get_Piece(f"LegLower{Pair}"))); }
        return Super::DoConstruct(InHandle);
    }

    private TSoftObjectPtr<UStaticMesh> Get_Piece(FString InPart) const
    {
        const FString PieceName = f"Crawler_{InPart}_Mars_SM";
        return TSoftObjectPtr<UStaticMesh>(FSoftObjectPath(f"/Game/Mars/Gameplay/Monsters/Crawler/Meshes/{PieceName}.{PieceName}"));
    }
}
