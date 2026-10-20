// One-shot per Resting entity: binds the body's Added and Persisted contacts, where a contact with one of the targets refreshes
// that target's contact age. The handler finds the Resting on the body's own entity.
class UMars_Processor_Resting_Setup : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _MarkedDirtyBy = FMars_Tag_Resting_NeedsSetup;

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_Resting);
        Query.Require(FMars_Tag_Resting_NeedsSetup);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle, FMars_Fragment_Resting& InState)
    {
        auto Self = InHandle.As_Resting();

        auto Body = InState.Body;
        utils_jolt_body::BindTo_OnJoltBodyContactAdded(Body, FCk_Delegate_JoltBody_OnContact(this, n"OnContact"));
        utils_jolt_body::BindTo_OnJoltBodyContactPersisted(Body, FCk_Delegate_JoltBody_OnContact(this, n"OnContact"));

        Self.Request_TryRemove(FMars_Tag_Resting_NeedsSetup);
    }

    UFUNCTION()
    private void OnContact(FCk_Handle_JoltBody InBody, FCk_JoltBody_Payload_OnContact InPayload)
    {
        // The entity is being torn down.
        auto Resting = InBody.As_Resting(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(Resting))
        { return; }

        // Fetched once: this runs on every Added and Persisted contact.
        auto& State = Resting.Get_Fragment(FMars_Fragment_Resting);
        const auto Index = utils_resting::TryFind_TargetIndex(State.Targets, InPayload.Get_OtherEntity());
        if (Index.IsSet() == false)
        { return; }

        State.ContactAges[Index.GetValue()].Seconds = TOptional<float32>(0.0f);
    }
}
