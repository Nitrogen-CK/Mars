// The authority's ledger writer (only a limb composed with authority carries the Publishing tag). Every k_PublishSeconds
// it reads each piece's pose in the root's frame and writes them when any piece moved more than k_MoveCm or
// k_MoveDegrees since the last write. Once nothing has moved for k_RestSeconds it writes once more with AtRest, drops
// the tag and writes nothing after.
class UMars_Processor_SeveredLimb_Publish : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_SeveredLimb);
        Query.Require(FMars_Tag_SeveredLimb_Publishing);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle, FMars_Fragment_SeveredLimb& InState)
    {
        InState.PublishClock += float32(InDeltaT.Get_Seconds());
        if (InState.PublishClock < constants_severed_limb::k_PublishSeconds)
        { return; }

        const auto Elapsed = InState.PublishClock;
        InState.PublishClock = 0.0f;

        auto Limb = InHandle.As_SeveredLimb();
        auto Ledger = FMars_Fragment_SeveredLimb_Net();
        Ledger.Pieces = Limb.Get_PiecePoses();

        if (utils_severed_limb::Get_HasMoved(InHandle.Get_Fragment(FMars_Fragment_SeveredLimb_Net).Pieces, Ledger.Pieces))
        {
            InState.QuietSeconds = 0.0f;
            utils_severed_limb::Publish(Limb, Ledger);
            return;
        }

        InState.QuietSeconds += Elapsed;
        if (InState.QuietSeconds < constants_severed_limb::k_RestSeconds)
        { return; }

        Ledger.AtRest = true;
        utils_severed_limb::Publish(Limb, Ledger);
        InHandle.Request_TryRemove(FMars_Tag_SeveredLimb_Publishing);
    }
}
