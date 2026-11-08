// Wires a new rat to its kernel, once: every hit its body zone routes becomes a TakeHit (the drain decides whether it is a
// lethal weapon hit), the monster's OnDied becomes Died, and the navigator's OnArrived / OnFailed become NavResults (the
// drain counts only the route's own goal). The zone, the monster and the navigator are all on the rat's root.
class UMars_Processor_PantryRat_Setup : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _MarkedDirtyBy = FMars_Tag_PantryRat_NeedsSetup;

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_PantryRat);
        Query.Require(FMars_Tag_PantryRat_NeedsSetup);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle)
    {
        auto Rat = InHandle.As_PantryRat();
        Rat.Request_TryRemove(FMars_Tag_PantryRat_NeedsSetup);

        auto Monster = Rat.Get_Monster();
        auto Zone = Monster.Get_BodyZone();
        Zone.BindTo_OnHit(FMars_Delegate_HitZone_OnHit(this, n"OnBodyHit"));
        Monster.BindTo_OnDied(FMars_Delegate_Monster_OnDied(this, n"OnDied"));

        auto Navigator = Rat.Get_Navigator();
        Navigator.BindTo_OnArrived(FMars_Delegate_SurfaceNavigator_OnArrived(this, n"OnArrived"));
        Navigator.BindTo_OnFailed(FMars_Delegate_SurfaceNavigator_OnFailed(this, n"OnFailed"));
    }

    UFUNCTION()
    private void OnBodyHit(FCk_Handle_HitZone InZone, FMars_DamageEvent InScaledEvent, FMars_HitZone_Reaction InReaction)
    {
        auto Rat = InZone.As_PantryRat(ECk_SanityCheck::UnChecked);
        if (ck::IsValid(Rat))
        { Rat.Request_TakeHit(FMars_Request_PantryRat_TakeHit(InScaledEvent)); }
    }

    UFUNCTION()
    private void OnDied(FCk_Handle_Monster InMonster, FMars_DamageEvent InCause)
    {
        auto Rat = InMonster.As_PantryRat(ECk_SanityCheck::UnChecked);
        if (ck::IsValid(Rat))
        { Rat.Request_Died(FMars_Request_PantryRat_Died(InCause)); }
    }

    UFUNCTION()
    private void OnArrived(FCk_Handle_SurfaceNavigator InNavigator, FVector InGoal)
    {
        auto Rat = InNavigator.As_PantryRat(ECk_SanityCheck::UnChecked);
        if (ck::IsValid(Rat))
        { Rat.Request_NavResult(FMars_Request_PantryRat_NavResult(InGoal, true)); }
    }

    UFUNCTION()
    private void OnFailed(FCk_Handle_SurfaceNavigator InNavigator, FVector InGoal, EMars_SurfaceNavigator_FailReason InReason)
    {
        auto Rat = InNavigator.As_PantryRat(ECk_SanityCheck::UnChecked);
        if (ck::IsValid(Rat))
        { Rat.Request_NavResult(FMars_Request_PantryRat_NavResult(InGoal, false)); }
    }
}
