// Wires a new mimic's body zone to the kernel: every hit the zone routes becomes a TakeHit (the flinch, the startle, the
// provoked target). The zone is on the mimic's root.
class UMars_Processor_PickleMimic_Setup : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _MarkedDirtyBy = FMars_Tag_PickleMimic_NeedsSetup;

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_PickleMimic);
        Query.Require(FMars_Tag_PickleMimic_NeedsSetup);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle)
    {
        auto Mimic = InHandle.As_PickleMimic();
        auto Zone = Mimic.Get_Monster().Get_BodyZone();
        Zone.BindTo_OnHit(FMars_Delegate_HitZone_OnHit(this, n"OnBodyHit"));

        Mimic.Request_TryRemove(FMars_Tag_PickleMimic_NeedsSetup);
    }

    UFUNCTION()
    private void OnBodyHit(FCk_Handle_HitZone InZone, FMars_DamageEvent InScaledEvent, FMars_HitZone_Reaction InReaction)
    {
        auto Mimic = InZone.As_PickleMimic(ECk_SanityCheck::UnChecked);
        if (ck::IsValid(Mimic))
        { Mimic.Request_TakeHit(FMars_Request_PickleMimic_TakeHit(InScaledEvent)); }
    }
}
