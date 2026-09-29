// Polls every slot's first item against the last pass: a change broadcasts OnSlotItemChanged, and an arrival applies
// the arrival rule (overflow always selects itself; a bag slot is auto-held while hands are empty). Items only ever
// arrive by stow, so the rule needs no provenance. Then a parked selection applies once the overflow slot reads empty.
class UMars_Processor_Hotbar_Sync : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_Hotbar);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle, FMars_Fragment_Hotbar& InState)
    {
        auto Self = InHandle.As_Hotbar();
        const auto OverflowIndex = Self.Get_OverflowIndex();

        for (int32 Index = 0; Index < InState.Slots.Num(); ++Index)
        {
            const auto Now = utils_hotbar::DoGet_FirstItem(InState.Slots[Index]);
            if (Now == InState.LastSeen[Index])
            { continue; }

            InState.LastSeen[Index] = Now;

            if (Self.Has_Fragment(FMars_Fragment_Hotbar_Signals))
            { Self.Get_Fragment(FMars_Fragment_Hotbar_Signals).OnSlotItemChanged.Broadcast(Self, Index, Now); }

            if (ck::Is_NOT_Valid(Now))
            { continue; }

            if (Index == OverflowIndex)
            { utils_hotbar::DoApplySelection(Self, InState, OverflowIndex); }
            else if (InState.SelectedIndex == -1)
            { utils_hotbar::DoApplySelection(Self, InState, Index); }
        }

        if (InState.PendingSelectedIndex == -2 || ck::IsValid(InState.LastSeen[OverflowIndex]))
        { return; }

        const auto ParkedIndex = InState.PendingSelectedIndex;
        InState.PendingSelectedIndex = -2;
        utils_hotbar::DoApplySelection(Self, InState, ParkedIndex);
    }
}
