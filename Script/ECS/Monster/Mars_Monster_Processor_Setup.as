// Wires a new monster's body Health to its death: depletion requests Die (latched by the request drain).
class UMars_Processor_Monster_Setup : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _MarkedDirtyBy = FMars_Tag_Monster_NeedsSetup;

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_Monster);
        Query.Require(FMars_Tag_Monster_NeedsSetup);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle)
    {
        auto Monster = InHandle.As_Monster();

        auto BodyHealth = Monster.Get_BodyHealth();
        if (ck::IsValid(BodyHealth))
        { BodyHealth.BindTo_OnDepleted(FMars_Delegate_Health_OnDepleted(this, n"OnBodyHealthDepleted")); }

        Monster.Request_TryRemove(FMars_Tag_Monster_NeedsSetup);
    }

    UFUNCTION()
    private void OnBodyHealthDepleted(FCk_Handle_Health InHealth, FMars_DamageEvent InCause)
    {
        auto Monster = FCk_Handle(InHealth).As_Monster(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(Monster))
        { return; }

        Monster.Request_Die(FMars_Request_Monster_Die(InCause));
    }
}
