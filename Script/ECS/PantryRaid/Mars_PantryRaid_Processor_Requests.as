// The raid's request drain, in order: SpawnRat (once per operation id: an operation that already has a rat, or that the raid
// never asked for, is stale) -> RatDied (the den slot cools down, the lease drops) -> RatHome (an empty rat admitted home is
// retired) -> ReleaseLease (only with the lease's own token) -> GrantLease (one lease per pack). Rats are spawned on the
// raid entity, so the raid owns them; removing a den never destroys a rat.
class UMars_Processor_PantryRaid_HandleRequests : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _MarkedDirtyBy = FMars_Fragment_PantryRaid_Requests;

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_PantryRaid);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle,
                       FMars_Fragment_PantryRaid_Requests& InRequests,
                       FMars_Fragment_PantryRaid& InState)
    {
        auto Self = InHandle.As_PantryRaid();

        TArray<FMars_Request_PantryRaid_SpawnRat> SpawnRatRequests = InRequests.SpawnRatRequests;
        TArray<FMars_Request_PantryRaid_RatDied> RatDiedRequests = InRequests.RatDiedRequests;
        TArray<FMars_Request_PantryRaid_RatHome> RatHomeRequests = InRequests.RatHomeRequests;
        TArray<FMars_Request_PantryRaid_ReleaseLease> ReleaseLeaseRequests = InRequests.ReleaseLeaseRequests;
        TArray<FMars_Request_PantryRaid_GrantLease> GrantLeaseRequests = InRequests.GrantLeaseRequests;

        // InRequests is invalid past this line; removing before broadcasting lets re-entrant requests survive.
        Self.Request_TryRemove(FMars_Fragment_PantryRaid_Requests);

        TArray<FCk_Handle> Spawned;
        TArray<int32> SpawnedOperations;
        for (const auto& Request : SpawnRatRequests)
        {
            const auto Rat = HandleSpawnRat(Self, Request);
            if (ck::IsValid(Rat))
            {
                Spawned.Add(Rat);
                SpawnedOperations.Add(Request.OperationId);
            }
        }

        for (const auto& Request : RatDiedRequests)
        { HandleRatDied(Self, Request); }

        for (const auto& Request : RatHomeRequests)
        { HandleRatHome(Self, Request); }

        for (const auto& Request : ReleaseLeaseRequests)
        { HandleReleaseLease(Self, Request); }

        for (const auto& Request : GrantLeaseRequests)
        { HandleGrantLease(Self, Request); }

        if (Self.Has_Fragment(FMars_Fragment_PantryRaid_Signals) == false)
        { return; }

        for (int32 Index = 0; Index < Spawned.Num(); ++Index)
        { Self.Get_Fragment(FMars_Fragment_PantryRaid_Signals).OnRatSpawned.Broadcast(Self, Spawned[Index], SpawnedOperations[Index]); }
    }

    private FCk_Handle HandleSpawnRat(FCk_Handle_PantryRaid& InRaid, const FMars_Request_PantryRaid_SpawnRat& InRequest)
    {
        auto& State = InRaid.Get_Fragment(FMars_Fragment_PantryRaid);
        const auto PendingIndex = State.PendingOperations.FindIndex(InRequest.OperationId);

        auto AlreadySpawned = false;
        for (const auto& Record : State.Rats)
        { AlreadySpawned = AlreadySpawned || Record.OperationId == InRequest.OperationId; }

        if (PendingIndex < 0 || AlreadySpawned || ck::Is_NOT_Valid(InRequest.Den))
        {
            ++State.StaleSpawns;
            Log(f"[PantryRaid] [{InRaid.ToString()}] ignored a stale SpawnRat for operation [{InRequest.OperationId}]");
            return FCk_Handle();
        }

        State.PendingOperations.RemoveAt(PendingIndex);

        const auto Rat = utils_pantry_raid::Request_SpawnRatEntity(InRaid, InRequest);
        if (ck::Is_NOT_Valid(Rat))
        { return FCk_Handle(); }

        auto Record = FMars_PantryRaid_RatRecord();
        Record.Rat = Rat;
        Record.Den = InRequest.Den;
        Record.Slot = InRequest.Slot;
        Record.OperationId = InRequest.OperationId;
        InRaid.Get_Fragment(FMars_Fragment_PantryRaid).Rats.Add(Record);

        auto Den = InRequest.Den;
        Den.Request_MarkOutside(FMars_Request_RatDen_MarkOutside(InRequest.Slot, InRequest.OperationId));
        return Rat;
    }

    private void HandleRatDied(FCk_Handle_PantryRaid& InRaid, const FMars_Request_PantryRaid_RatDied& InRequest)
    {
        auto& State = InRaid.Get_Fragment(FMars_Fragment_PantryRaid);
        for (auto& Record : State.Rats)
        {
            if (Record.Rat != InRequest.Rat || Record.Dead)
            { continue; }

            Record.Dead = true;
            if (ck::IsValid(Record.Den))
            {
                auto Den = Record.Den;
                Den.Request_ResidentDied(FMars_Request_RatDen_ResidentDied(Record.Slot, Record.OperationId,
                    State.Clock + InRaid.Get_Spec().Population.DeadReplacementSeconds));
            }
        }

        Drop_LeaseOf(State, InRequest.Rat);
    }

    // Only an empty rat is ever admitted (the den checks the pocket); the raid retires the entity and its lease.
    private void HandleRatHome(FCk_Handle_PantryRaid& InRaid, const FMars_Request_PantryRaid_RatHome& InRequest)
    {
        auto& State = InRaid.Get_Fragment(FMars_Fragment_PantryRaid);
        for (int32 Index = State.Rats.Num() - 1; Index >= 0; --Index)
        {
            if (State.Rats[Index].Rat != InRequest.Rat)
            { continue; }

            const auto Rat = InRequest.Rat.As_PantryRat(ECk_SanityCheck::UnChecked);
            if (ck::IsValid(Rat) && Rat.Get_IsLoaded())
            {
                ++State.RefusedRetirements;
                if (State.RefusedRetirements == 1)
                { Log(f"[PantryRaid] [{InRaid.ToString()}] refused to retire loaded rat [{InRequest.Rat.ToString()}]: a loaded thief is never retired (later refusals are counted only)"); }
                return;
            }

            State.Rats.RemoveAt(Index);
            utils_entity_lifetime::Request_DestroyEntity(InRequest.Rat);
        }

        Drop_LeaseOf(State, InRequest.Rat);
    }

    private void HandleReleaseLease(FCk_Handle_PantryRaid& InRaid, const FMars_Request_PantryRaid_ReleaseLease& InRequest)
    {
        auto& State = InRaid.Get_Fragment(FMars_Fragment_PantryRaid);
        for (auto& Record : State.Packs)
        {
            if (Record.Lease.IsSet() && Record.Lease.GetValue().Rat == InRequest.Rat && Record.Lease.GetValue().Token == InRequest.Token)
            { Record.Lease.Reset(); }
        }
    }

    private void HandleGrantLease(FCk_Handle_PantryRaid& InRaid, const FMars_Request_PantryRaid_GrantLease& InRequest)
    {
        auto& State = InRaid.Get_Fragment(FMars_Fragment_PantryRaid);
        if (InRaid.TryGet_LeaseOf(InRequest.Rat).IsSet())
        { return; }

        const auto Spec = InRaid.Get_Spec();
        for (auto& Record : State.Packs)
        {
            if (Record.Pack != InRequest.Pack)
            { continue; }

            if (Record.Lease.IsSet() || Record.Guarded || Record.ScentArmed == false || Record.EligibleSlots.Contains(InRequest.Slot) == false)
            { return; }

            const auto Slot = Record.Pack.As_Backpack().Get_CargoSlot(InRequest.Slot);
            if (Slot.Get_Item() != InRequest.Item || ck::Is_NOT_Valid(InRequest.Item))
            { return; }

            auto Lease = FMars_PantryRaid_Lease();
            Lease.Rat = InRequest.Rat;
            Lease.Slot = InRequest.Slot;
            Lease.ExpectedItem = InRequest.Item;
            Lease.SourceInventory = Slot.Get_Inventory();
            Lease.Token = State.NextToken;
            Lease.Expiry = State.Clock + Spec.Theft.LeaseSeconds;
            ++State.NextToken;
            ++State.LeasesGranted;
            Log(f"[PantryRaid] [{InRaid.ToString()}] leased slot [{InRequest.Slot}] item [{InRequest.Item.ToString()}] to [{InRequest.Rat.ToString()}] token [{Lease.Token}]");
            Record.Lease = TOptional<FMars_PantryRaid_Lease>(Lease);
            return;
        }
    }

    private void Drop_LeaseOf(FMars_Fragment_PantryRaid& InOutState, const FCk_Handle& InRat)
    {
        for (auto& Record : InOutState.Packs)
        {
            if (Record.Lease.IsSet() && Record.Lease.GetValue().Rat == InRat)
            { Record.Lease.Reset(); }
        }
    }
}

namespace utils_pantry_raid
{
    // The resident's rat, spawned on the raid entity (the raid owns it) at the den's ExitPortal facing out of the den, with
    // the raid's tuning copied into its spec.
    FCk_Handle Request_SpawnRatEntity(FCk_Handle_PantryRaid& InRaid, const FMars_Request_PantryRaid_SpawnRat& InRequest)
    {
        const auto Den = InRequest.Den;
        auto Spec = FMars_PantryRat_Spec();
        Spec.Links.Raid = InRaid;
        Spec.Links.Den = Den;
        Spec.Links.ResidentSlot = InRequest.Slot;
        Spec.Links.OperationId = InRequest.OperationId;
        Spec.Tuning = Make_RatTuning(InRaid.Get_Spec());

        auto SpawnParams = UMars_PantryRat_EntityScript::Params();
        SpawnParams.SpawnTransform = FTransform(Den.Get_OutwardWorld().Rotation(), Den.Get_PortalWorld(EMars_RatDen_Portal::ExitPortal));
        SpawnParams.Spec = Spec;

        FCk_Handle Owner = InRaid;
        auto Pending = utils_entity_script::Request_SpawnEntity(Owner, UMars_PantryRat_EntityScript, SpawnParams);
        return Pending.Get_EntityUnderConstruction();
    }
}
