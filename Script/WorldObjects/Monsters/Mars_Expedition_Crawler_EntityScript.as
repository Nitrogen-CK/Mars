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
        Spec.Combat.Loadout = utils_crawler::Get_AttackReferenceLoadout(EMars_Crawler_AttackPreset::Spider6, EMars_AttackReference_Kind::Parity);
        Color = FLinearColor(0.35f, 0.55f, 0.2f, 1.0f);
        Look = Make_SpiderLook();
        return Super::DoConstruct(InHandle);
    }
}
