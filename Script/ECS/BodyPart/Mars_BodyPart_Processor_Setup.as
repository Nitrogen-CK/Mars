// Wires a new part to its own zone and Health: every hit the zone routes becomes a RecordHit (ledger + spill), and the
// Health's depletion becomes a Sever (the depletion policy). The part, its zone and its Health are one entity.
class UMars_Processor_BodyPart_Setup : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _MarkedDirtyBy = FMars_Tag_BodyPart_NeedsSetup;

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_BodyPart);
        Query.Require(FMars_Tag_BodyPart_NeedsSetup);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle)
    {
        auto Part = InHandle.As_BodyPart();

        auto Zone = Part.Get_Zone();
        Zone.BindTo_OnHit(FMars_Delegate_HitZone_OnHit(this, n"OnZoneHit"));

        auto Health = Part.Get_Health();
        Health.BindTo_OnDepleted(FMars_Delegate_Health_OnDepleted(this, n"OnHealthDepleted"));

        Part.Request_TryRemove(FMars_Tag_BodyPart_NeedsSetup);
    }

    UFUNCTION()
    private void OnZoneHit(FCk_Handle_HitZone InZone, FMars_DamageEvent InScaledEvent, FMars_HitZone_Reaction InReaction)
    {
        auto Part = InZone.As_BodyPart();
        Part.Request_RecordHit(FMars_Request_BodyPart_RecordHit(InScaledEvent, InReaction));
    }

    UFUNCTION()
    private void OnHealthDepleted(FCk_Handle_Health InHealth, FMars_DamageEvent InCause)
    {
        auto Part = InHealth.As_BodyPart();
        Part.Request_Sever(FMars_Request_BodyPart_Sever(InCause));
    }
}
