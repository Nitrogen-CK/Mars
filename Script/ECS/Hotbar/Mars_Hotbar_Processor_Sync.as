// Once the hotbar is ready, every pass and on every machine: polls every slot's item against the last pass, and a change
// broadcasts OnSlotItemChanged. On the authority an arrival also applies the arrival rule (overflow always selects
// itself; a bag slot is auto-held while hands are empty; a backpack arrival never selects - the pack goes on the back),
// and then a parked selection applies once the overflow slot reads empty; a client receives both through the ledger.
// Items only ever arrive by stow, so the rule needs no provenance.
class UMars_Processor_Hotbar_Sync : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _RunAfter.Add(n"/Script/Angelscript.Mars_Processor_Hotbar_HandleRequests");
    default _RunAfter.Add(n"/Script/Angelscript.Mars_Processor_Hotbar_AdoptSlots");
    default _RunAfter.Add(n"/Script/Angelscript.Mars_Processor_HeldItem_HandleRequests");

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_Hotbar);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle, FMars_Fragment_Hotbar& InState)
    {
        auto Self = InHandle.As_Hotbar();
        if (Self.Get_IsReady() == false)
        { return; }

        auto& Local = InHandle.Get_Fragment(FMars_Fragment_Hotbar_Local);

        const auto HasAuthority = utils_net::Get_HasAuthority(InHandle);
        const auto OverflowIndex = Self.Get_OverflowIndex();
        const auto BackpackIndex = Self.Get_BackpackIndex();

        for (int32 Index = 0; Index < Local.Slots.Num(); ++Index)
        {
            const auto Now = Local.Slots[Index].Get_SoleItem();
            if (Now == Local.LastSeen[Index])
            { continue; }

            Local.LastSeen[Index] = Now;

            if (Self.Has_Fragment(FMars_Fragment_Hotbar_Signals))
            { Self.Get_Fragment(FMars_Fragment_Hotbar_Signals).OnSlotItemChanged.Broadcast(Self, Index, Now); }

            if (ck::Is_NOT_Valid(Now) || HasAuthority == false)
            { continue; }

            const auto IsBackpackSlot = BackpackIndex.IsSet() && BackpackIndex.GetValue() == Index;
            if (Index == OverflowIndex)
            { utils_hotbar::Apply_Selection(Self, InState, TOptional<int32>(OverflowIndex)); }
            else if (Get_AreHandsEmpty(InState, Local) && IsBackpackSlot == false)
            { utils_hotbar::Apply_Selection(Self, InState, TOptional<int32>(Index)); }
        }

        if (HasAuthority == false || InState.Park == EMars_Hotbar_Park::Nothing || ck::IsValid(Local.LastSeen[OverflowIndex]))
        { return; }

        const auto Parked = InState.ParkedIndex;
        InState.Park = EMars_Hotbar_Park::Nothing;
        InState.ParkedIndex.Reset();
        Self.H().Request_MarkReplicationDirty(FMars_Fragment_Hotbar);
        utils_hotbar::Apply_Selection(Self, InState, Parked);
    }

    // Nothing selected, or the selected slot holds nothing (it stays selected after its item was thrown, dropped or used).
    private bool Get_AreHandsEmpty(const FMars_Fragment_Hotbar& InState, const FMars_Fragment_Hotbar_Local& InLocal) const
    {
        if (InState.SelectedIndex.IsSet() == false)
        { return true; }

        return ck::Is_NOT_Valid(InLocal.Slots[InState.SelectedIndex.GetValue()].Get_SoleItem());
    }
}
