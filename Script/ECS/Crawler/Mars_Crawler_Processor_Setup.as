// Turns the crawler's gait leg-set changes and every Health it owns (the body's and each leg part's) into Brain facts,
// the only way anything outside the brain changes its world state: CanWalk from the enabled leg count, IsHurt (and the
// HurtCount the Flinch task watches) from any damage.
class UMars_Processor_Crawler_Setup : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _MarkedDirtyBy = FMars_Tag_Crawler_NeedsSetup;

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_Crawler);
        Query.Require(FMars_Tag_Crawler_NeedsSetup);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle)
    {
        auto Crawler = InHandle.As_Crawler();

        auto Gait = Crawler.Get_Gait();
        utils_procedural_gait::BindTo_OnLegSetChanged(Gait, FCk_Delegate_ProceduralGait_OnLegSetChanged(this, n"OnLegSetChanged"));

        auto BodyHealth = Crawler.Get_Monster().Get_BodyHealth();
        BodyHealth.BindTo_OnDamaged(FMars_Delegate_Health_OnDamaged(this, n"OnDamaged"));

        for (auto Part : Crawler.Get_LegParts())
        {
            auto PartHealth = Part.Get_Health();
            PartHealth.BindTo_OnDamaged(FMars_Delegate_Health_OnDamaged(this, n"OnDamaged"));
        }

        Crawler.Request_TryRemove(FMars_Tag_Crawler_NeedsSetup);
    }

    // The gait lives on the crawler root.
    UFUNCTION()
    private void OnLegSetChanged(FCk_Handle_ProceduralGait InGait, int32 InEnabledCount, int32 InTotalCount)
    {
        auto Crawler = InGait.As_Crawler();

        const auto CanWalk = InEnabledCount >= Crawler.Get_Spec().MinLegsToWalk;
        ck::Trace(f"[Crawler] [{Crawler.ToString()}] legs enabled [{InEnabledCount}] of [{InTotalCount}]: CanWalk [{CanWalk}]");

        auto Brain = Crawler.Get_Brain();
        Brain.Request_SetFact(FMars_Request_Brain_SetFact(utils_crawler::Get_CanWalkFact(), CanWalk));
    }

    // The body Health is on the crawler root; a leg's Health is on its leg entity, whose part names the monster (= root).
    UFUNCTION()
    private void OnDamaged(FCk_Handle_Health InHealth, FMars_DamageEvent InEvent, float32 InApplied, float32 InRemaining)
    {
        auto Crawler = InHealth.As_Crawler(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(Crawler))
        { Crawler = InHealth.As_BodyPart().Get_Monster().As_Crawler(ECk_SanityCheck::UnChecked); }

        // A severed leg is world-owned and can outlive the crawler that shed it.
        if (ck::Is_NOT_Valid(Crawler))
        { return; }

        auto& State = Crawler.Get_Fragment(FMars_Fragment_Crawler);
        ++State.HurtCount;

        auto Brain = Crawler.Get_Brain();
        Brain.Request_SetFact(FMars_Request_Brain_SetFact(utils_crawler::Get_IsHurtFact(), true));
    }
}
