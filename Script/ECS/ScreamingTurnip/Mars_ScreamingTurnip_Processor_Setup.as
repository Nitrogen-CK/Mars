// One-shot per ScreamingTurnip: binds its world item's body's Added and Persisted contacts, where a supporting contact
// (utils_screaming_turnip::Get_IsSupportingContact) stamps the settle scratch's LastSupportAt with the kernel's clock. The
// handler finds the kernel on the body's own entity. A world item with no body binds nothing (the Tick reports it).
class UMars_Processor_ScreamingTurnip_Setup : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _MarkedDirtyBy = FMars_Tag_ScreamingTurnip_NeedsSetup;

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_ScreamingTurnip);
        Query.Require(FMars_Tag_ScreamingTurnip_NeedsSetup);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle, FMars_Fragment_ScreamingTurnip_Params& InParams)
    {
        auto Self = InHandle.As_ScreamingTurnip();
        Self.Request_TryRemove(FMars_Tag_ScreamingTurnip_NeedsSetup);

        auto Body = InParams.WorldItem.Get_Body();
        if (ck::Is_NOT_Valid(Body))
        { return; }

        utils_jolt_body::BindTo_OnJoltBodyContactAdded(Body, FCk_Delegate_JoltBody_OnContact(this, n"OnContact"));
        utils_jolt_body::BindTo_OnJoltBodyContactPersisted(Body, FCk_Delegate_JoltBody_OnContact(this, n"OnContact"));
    }

    UFUNCTION()
    private void OnContact(FCk_Handle_JoltBody InBody, FCk_JoltBody_Payload_OnContact InPayload)
    {
        // The entity is being torn down.
        auto Turnip = InBody.As_ScreamingTurnip(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(Turnip))
        { return; }

        if (utils_screaming_turnip::Get_IsSupportingContact(InPayload) == false)
        { return; }

        const auto Clock = Turnip.Get_Fragment(FMars_Fragment_ScreamingTurnip).Clock;
        Turnip.Get_Fragment(FMars_Fragment_ScreamingTurnip_Settle).LastSupportAt = TOptional<float32>(Clock);
    }
}
