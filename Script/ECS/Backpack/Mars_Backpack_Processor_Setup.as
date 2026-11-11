// Once per pack, on every machine: requests one UMars_CargoSlot_EntityScript per slot of the layout under the pack. The
// authority builds each and stamps the host-side check; a client's request is the placeholder the replicated slot resolves
// to. A pack is a World-mode world item, which always lives under an owner with a replication driver, so the slot class is
// always the replicated one.
class UMars_Processor_Backpack_SpawnSlots : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _MarkedDirtyBy = FMars_Tag_Backpack_NeedsSlots;

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_Backpack);
        Query.Require(FMars_Tag_Backpack_NeedsSlots);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle, FMars_Fragment_Backpack_SlotSpecs& InSpecs)
    {
        auto Backpack = InHandle.As_Backpack();
        const auto SlotCount = InSpecs.Slots.Num();
        Backpack.Request_TryRemove(FMars_Tag_Backpack_NeedsSlots);

        const auto IsAuthority = utils_net::Get_HasAuthority(InHandle);
        for (int32 Index = 0; Index < SlotCount; ++Index)
        {
            auto Pending = utils_entity_script::Request_SpawnEntity(InHandle, UMars_CargoSlot_EntityScript,
                FMars_CargoSlot_SpawnParams(Index));

            if (IsAuthority)
            {
                auto Slot = Pending.Get_EntityUnderConstruction();
                utils_net_spawn::Expect_Replicated(Slot);
            }
        }
    }
}

// Every frame until the pack is ready, on every machine: finds the pack's composed cargo slots among its lifetime
// dependents and records each at its index; the pack is ready once every index is filled. A slot whose index is out of
// range or taken ensures and is destroyed. Never pumped: a slot still in flight is looked for again next frame.
class UMars_Processor_Backpack_AdoptSlots : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _RunAfter.Add(n"/Script/Angelscript.Mars_Processor_Backpack_SpawnSlots");

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_Backpack);
        Query.Require(FMars_Fragment_Backpack_AwaitingSlots);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle, FMars_Fragment_Backpack& InState)
    {
        auto Backpack = InHandle.As_Backpack();

        for (auto Dependent : utils_entity_lifetime::Get_LifetimeDependents(InHandle))
        {
            auto Slot = Dependent.As_CargoSlot(ECk_SanityCheck::UnChecked);
            if (ck::Is_NOT_Valid(Slot))
            { continue; }

            if (utils_entity_lifetime::Get_IsPendingDestroy(Dependent, ECk_EntityLifetime_DestructionPhase::BeginDestroy))
            { continue; }

            const auto Index = Slot.Get_Index();
            if (InState.CargoSlots.IsValidIndex(Index) && InState.CargoSlots[Index] == Slot)
            { continue; }

            const auto Fits = InState.CargoSlots.IsValidIndex(Index) && ck::Is_NOT_Valid(InState.CargoSlots[Index]);
            if (ck::EnsureIfNot(Fits,
                f"[Backpack] [{Backpack.ToString()}] found cargo slot [{Dependent.ToString()}] (index {Index}) that does not fit "
                + f"its layout of {InState.CargoSlots.Num()} slots: out of range or taken. Destroyed."))
            {
                utils_entity_lifetime::Request_DestroyEntity(Dependent);
                continue;
            }

            InState.CargoSlots[Index] = Slot;
        }

        for (const auto& Slot : InState.CargoSlots)
        {
            if (ck::Is_NOT_Valid(Slot))
            { return; }
        }

        Backpack.Request_TryRemove(FMars_Fragment_Backpack_AwaitingSlots);
    }
}
