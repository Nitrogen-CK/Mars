// One-shot per feed. Every feed takes the answers a receiving kernel on its own entity gives on the station's OnAdmission
// and forwards each as it is (Request_ResolveAdmission): the feed honours one only for the piece it awaits, and puts a
// rejected piece back itself. A feed with an input dock (a station's) draws from the platter that has arrived on that dock:
// set here when one already has, again on every OnArrived, and cleared on every OnUndocked (an unsourced feed cancels a
// transfer in flight). A platter still travelling onto the dock is no source yet. The bindings live as long as the feed: the
// dock is its lifetime child.
class UMars_Processor_CookingFeed_Setup : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _MarkedDirtyBy = FMars_Tag_CookingFeed_NeedsSetup;

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_CookingFeed);
        Query.Require(FMars_Tag_CookingFeed_NeedsSetup);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle)
    {
        auto Feed = InHandle.As_CookingFeed();
        utils_cooking_feed::BindTo_OnAdmission(InHandle, FMars_Delegate_StationAdmission_OnAdmission(this, n"OnAdmission"));

        auto InputDock = Feed.Get_InputDock();
        if (ck::IsValid(InputDock))
        {
            InputDock.BindTo_OnArrived(FMars_Delegate_PlatterDock_OnArrived(this, n"OnInputArrived"));
            InputDock.BindTo_OnUndocked(FMars_Delegate_PlatterDock_OnUndocked(this, n"OnInputUndocked"));

            if (InputDock.Get_HasArrived())
            { Feed.Request_SetSource(FMars_Request_CookingFeed_SetSource(InputDock.Get_Platter())); }
        }

        Feed.Request_TryRemove(FMars_Tag_CookingFeed_NeedsSetup);
    }

    UFUNCTION()
    private void OnAdmission(FCk_Handle InStation, FMars_CookingFeed_PieceId InPieceId, EMars_CookingFeed_Admission InAdmission, FString InReason)
    {
        auto Feed = InStation.As_CookingFeed(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(Feed))
        { return; }

        Feed.Request_ResolveAdmission(FMars_Request_CookingFeed_ResolveAdmission(InPieceId, InAdmission, InReason));
    }

    UFUNCTION()
    private void OnInputArrived(FCk_Handle_PlatterDock InDock, FCk_Handle_Platter InPlatter)
    {
        auto Feed = Get_FeedOf(InDock);
        if (ck::IsValid(Feed))
        { Feed.Request_SetSource(FMars_Request_CookingFeed_SetSource(InPlatter)); }
    }

    UFUNCTION()
    private void OnInputUndocked(FCk_Handle_PlatterDock InDock, FCk_Handle_Platter InPlatter)
    {
        auto Feed = Get_FeedOf(InDock);
        if (ck::IsValid(Feed))
        { Feed.Request_SetSource(FMars_Request_CookingFeed_SetSource(FCk_Handle_Platter())); }
    }

    // The feed InDock is the input dock of: its lifetime owner (utils_cooking_feed::Add checked it); invalid once the feed
    // is going.
    private FCk_Handle_CookingFeed Get_FeedOf(const FCk_Handle_PlatterDock& InDock) const
    {
        auto Feed = utils_entity_lifetime::Get_LifetimeOwner(InDock).As_CookingFeed(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(Feed) || Feed.Get_InputDock() != InDock)
        { return FCk_Handle_CookingFeed(); }

        return Feed;
    }
}
