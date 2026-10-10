// Polls every slot's item against the last pass: a change broadcasts OnSlotItemChanged, and an arrival applies the
// arrival rule (overflow always selects itself; a bag slot is auto-held while hands are empty; a backpack arrival never
// selects - the pack goes on the back). Items only ever arrive by stow, so the rule needs no provenance. Then a parked
// selection applies once the overflow slot reads empty.
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
        const auto BackpackIndex = Self.Get_BackpackIndex();

        for (int32 Index = 0; Index < InState.Slots.Num(); ++Index)
        {
            const auto Now = InState.Slots[Index].Get_SoleItem();
            if (Now == InState.LastSeen[Index])
            { continue; }

            InState.LastSeen[Index] = Now;

            if (Self.Has_Fragment(FMars_Fragment_Hotbar_Signals))
            { Self.Get_Fragment(FMars_Fragment_Hotbar_Signals).OnSlotItemChanged.Broadcast(Self, Index, Now); }

            if (ck::Is_NOT_Valid(Now))
            { continue; }

            const auto IsBackpackSlot = BackpackIndex.IsSet() && BackpackIndex.GetValue() == Index;
            if (Index == OverflowIndex)
            { utils_hotbar::Apply_Selection(Self, InState, TOptional<int32>(OverflowIndex)); }
            else if (Get_AreHandsEmpty(InState) && IsBackpackSlot == false)
            { utils_hotbar::Apply_Selection(Self, InState, TOptional<int32>(Index)); }
        }

        if (InState.ParkedSelection.IsSet() == false || ck::IsValid(InState.LastSeen[OverflowIndex]))
        { return; }

        const auto Parked = InState.ParkedSelection.GetValue().Index;
        InState.ParkedSelection.Reset();
        utils_hotbar::Apply_Selection(Self, InState, Parked);
    }

    // Nothing selected, or the selected slot holds nothing (it stays selected after its item was thrown, dropped or used).
    private bool Get_AreHandsEmpty(const FMars_Fragment_Hotbar& InState) const
    {
        if (InState.SelectedIndex.IsSet() == false)
        { return true; }

        return ck::Is_NOT_Valid(InState.Slots[InState.SelectedIndex.GetValue()].Get_SoleItem());
    }
}
