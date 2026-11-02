// Wires a new Root Maw's body zone to the kernel: every hit the zone routes becomes a TakeHit (the flinch, the startle, the
// provoked target). The zone is on the Maw's root.
class UMars_Processor_RootMaw_Setup : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _MarkedDirtyBy = FMars_Tag_RootMaw_NeedsSetup;

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_RootMaw);
        Query.Require(FMars_Tag_RootMaw_NeedsSetup);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle)
    {
        auto Maw = InHandle.As_RootMaw();
        auto Zone = Maw.Get_Monster().Get_BodyZone();
        Zone.BindTo_OnHit(FMars_Delegate_HitZone_OnHit(this, n"OnBodyHit"));

        Maw.Request_TryRemove(FMars_Tag_RootMaw_NeedsSetup);
    }

    UFUNCTION()
    private void OnBodyHit(FCk_Handle_HitZone InZone, FMars_DamageEvent InScaledEvent, FMars_HitZone_Reaction InReaction)
    {
        auto Maw = InZone.As_RootMaw(ECk_SanityCheck::UnChecked);
        if (ck::IsValid(Maw))
        { Maw.Request_TakeHit(FMars_Request_RootMaw_TakeHit(InScaledEvent)); }
    }
}
