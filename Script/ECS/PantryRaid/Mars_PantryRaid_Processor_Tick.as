// The raid's per-frame pass, in this order: the clock (a zero, negative or non-finite delta does not advance; a hitch
// advances at most k_MaxStep); every chef's current location (TAG_MarsCombatTarget roots with a Hotbar, anywhere: every
// player is observed, not only the local one); den discovery inside the bounds (every DiscoverySeconds, binding each new
// den's signals); the rat roster pruned of entities that are gone; readiness, stamped FMars_Tag_PantryRaid_Ready LAST; the
// pack records (grounded, settled, cheese, eligible slots within reach, guard hysteresis, lease validity); then, once
// ready, at most one emergence per frame. Everything another feature owns changes only through its requests.
class UMars_Processor_PantryRaid_Tick : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";

    private const float32 k_MaxStep = 0.25f;
    private const float32 k_DiscoverySeconds = 0.5f;
    private const float32 k_PendingAnswerSeconds = 2.0f;
    // F4-4: a pack's reachability is re-asked this often, or as soon as it moves this far.
    private const float32 k_ReachRecheckSeconds = 1.0f;
    private const float64 k_ReachMoveCm = 5.0;

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_PantryRaid);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle,
                       FMars_Fragment_PantryRaid_Params& InParams,
                       FMars_Fragment_PantryRaid& InState)
    {
        const auto Delta = float32(InDeltaT.Get_Seconds());
        if (Math::IsFinite(Delta) == false || Delta <= 0.0f)
        { return; }

        auto Self = InHandle.As_PantryRaid();
        const auto Spec = InParams.Spec;
        InState.Clock += Math::Min(Delta, k_MaxStep);

        InState.Chefs = utils_pantry_raid::Read_ChefsNow(Self);

        if (InState.Clock >= InState.NextDiscoveryAt)
        {
            InState.NextDiscoveryAt = InState.Clock + k_DiscoverySeconds;
            Discover_Dens(Self, InState);
        }

        Prune_Rats(InState);

        if (InState.Ready == false && Get_IsReadyNow(Self, InParams, InState))
        {
            InState.Ready = true;
            Log(f"[PantryRaid] [{Self.ToString()}] ready: {InState.Dens.Num()} den(s), clock [{InState.Clock}]");
            Self.Add_Fragment(FMars_Tag_PantryRaid_Ready());
            if (Self.Has_Fragment(FMars_Fragment_PantryRaid_Signals))
            { Self.Get_Fragment(FMars_Fragment_PantryRaid_Signals).OnReady.Broadcast(Self); }
        }

        Refresh_Packs(Self, Spec, InState);

        if (InState.Ready)
        { Decide_Emergence(Self, Spec, InState); }
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Discovery
    //----------------------------------------------------------------------------------------------------------------------

    // Dens inside the bounds, in discovery order; a den gone or moved out is dropped (its rats stay: the raid owns them).
    private void Discover_Dens(FCk_Handle_PantryRaid& InSelf, FMars_Fragment_PantryRaid& InOutState)
    {
        auto Kept = TArray<FCk_Handle_RatDen>();
        for (auto Den : InOutState.Dens)
        {
            FCk_Handle DenEntity = Den;
            if (ck::IsValid(Den) && utils_world_item::Get_IsEnding(DenEntity) == false
                && InSelf.Get_IsInsideBounds(utils_transform::Get_EntityCurrentLocation(Den.As_Transform())))
            { Kept.Add(Den); }
        }

        for (auto Candidate : utils_entity_tag::ForEach_Entity(InSelf, utils_rat_den::DenTag))
        {
            auto Den = Candidate.As_RatDen(ECk_SanityCheck::UnChecked);
            if (ck::Is_NOT_Valid(Den) || Kept.Contains(Den) || utils_world_item::Get_IsEnding(Candidate))
            { continue; }

            if (InSelf.Get_IsInsideBounds(utils_transform::Get_EntityCurrentLocation(Den.As_Transform())) == false)
            { continue; }

            Den.BindTo_OnEmergeReady(FMars_Delegate_RatDen_OnEmergeReady(this, n"OnDenEmergeReady"));
            Den.BindTo_OnResidentReturned(FMars_Delegate_RatDen_OnResidentReturned(this, n"OnDenResidentReturned"));
            Kept.Add(Den);
        }

        InOutState.Dens = Kept;
    }

    private void Prune_Rats(FMars_Fragment_PantryRaid& InOutState)
    {
        for (int32 Index = InOutState.Rats.Num() - 1; Index >= 0; --Index)
        {
            const auto Rat = InOutState.Rats[Index].Rat;
            if (ck::Is_NOT_Valid(Rat) || utils_entity_lifetime::Get_IsPendingDestroy(Rat, ECk_EntityLifetime_DestructionPhase::BeginDestroy))
            { InOutState.Rats.RemoveAt(Index); }
        }
    }

    // A den granted an emergence: the raid that asked for it spawns the rat (its request drain owns the roster).
    UFUNCTION()
    private void OnDenEmergeReady(FCk_Handle_RatDen InDen, int32 InSlot, int32 InOperationId)
    {
        for (auto Candidate : utils_entity_tag::ForEach_Entity(InDen, utils_pantry_raid::RaidTag))
        {
            auto Raid = Candidate.As_PantryRaid(ECk_SanityCheck::UnChecked);
            if (ck::IsValid(Raid) && Raid.Get_Fragment(FMars_Fragment_PantryRaid).PendingOperations.Contains(InOperationId))
            { Raid.Request_SpawnRat(FMars_Request_PantryRaid_SpawnRat(InDen, InSlot, InOperationId)); }
        }
    }

    UFUNCTION()
    private void OnDenResidentReturned(FCk_Handle_RatDen InDen, int32 InSlot, FCk_Handle InRat)
    {
        for (auto Candidate : utils_entity_tag::ForEach_Entity(InDen, utils_pantry_raid::RaidTag))
        {
            auto Raid = Candidate.As_PantryRaid(ECk_SanityCheck::UnChecked);
            if (ck::IsValid(Raid) && Raid.Get_HasRat(InRat))
            { Raid.Request_RatHome(FMars_Request_PantryRaid_RatHome(InRat)); }
        }
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Readiness
    //----------------------------------------------------------------------------------------------------------------------

    // The field the raid was given is built and current, at least one den is discovered, and the provider answers a real
    // route from a den's OutsideStand into the bounds' centre. No sleeps: every frame until it holds.
    private bool Get_IsReadyNow(const FCk_Handle_PantryRaid& InSelf, const FMars_Fragment_PantryRaid_Params& InParams,
                                const FMars_Fragment_PantryRaid& InState) const
    {
        const auto Volume = InParams.NavVolume;
        if (ck::Is_NOT_Valid(Volume) || utils_ground_nav_volume::Get_IsBuilt(Volume) == false
            || utils_ground_nav_volume::Get_IsBuildCurrent(Volume) == false)
        { return false; }

        if (InState.Dens.Num() == 0)
        { return false; }

        const auto Bounds = InSelf.Get_BoundsWorld();
        for (auto Den : InState.Dens)
        {
            const auto Start = Den.Get_PortalWorld(EMars_RatDen_Portal::OutsideStand);
            auto Goal = (Bounds.Min + Bounds.Max) * 0.5;
            Goal.Z = Start.Z;

            auto Query = FCk_NavSurface_PathQuery(Start, Goal);
            Query.Set_AgentRadiusUu(utils_pantry_rat::k_AgentRadius);
            if (utils_nav_surface::Try_FindPathSync(Query).Get_Status() == ECk_NavSurface_QueryStatus::Success)
            { return true; }
        }

        return false;
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Packs
    //----------------------------------------------------------------------------------------------------------------------

    private void Refresh_Packs(FCk_Handle_PantryRaid& InSelf, const FMars_PantryRaid_Spec& InSpec, FMars_Fragment_PantryRaid& InOutState)
    {
        auto Kept = TArray<FMars_PantryRaid_PackRecord>();
        for (const auto& Record : InOutState.Packs)
        {
            FCk_Handle PackEntity = Record.Pack;
            if (ck::IsValid(Record.Pack) && utils_world_item::Get_IsEnding(PackEntity) == false
                && InSelf.Get_IsInsideBounds(utils_transform::Get_EntityCurrentLocation(Record.Pack.As_Transform())))
            { Kept.Add(Record); }
            else
            { ++InOutState.Epoch; }
        }

        for (auto Candidate : utils_entity_tag::ForEach_Entity(InSelf, n"TAG_MarsWorldItem"))
        {
            if (Candidate.Is_Backpack() == false || Candidate.Is_WorldItem() == false || utils_world_item::Get_IsEnding(Candidate))
            { continue; }

            const auto Pack = Candidate.As_WorldItem();
            if (InSelf.Get_IsInsideBounds(utils_transform::Get_EntityCurrentLocation(Pack.As_Transform())) == false)
            { continue; }

            auto Known = false;
            for (const auto& Record : Kept)
            { Known = Known || Record.Pack == Pack; }

            if (Known == false)
            {
                auto Record = FMars_PantryRaid_PackRecord();
                Record.Pack = Pack;
                Kept.Add(Record);
            }
        }

        for (auto& Record : Kept)
        { Refresh_Pack(InSpec, InOutState, Record); }

        InOutState.Packs = Kept;
    }

    private void Refresh_Pack(const FMars_PantryRaid_Spec& InSpec, FMars_Fragment_PantryRaid& InOutState, FMars_PantryRaid_PackRecord& InOutRecord)
    {
        auto Pack = InOutRecord.Pack;
        const auto Backpack = Pack.As_Backpack();
        const auto PackLocation = utils_transform::Get_EntityCurrentLocation(Pack.As_Transform());
        const auto Grounded = Pack.Get_Mount() == EMars_WorldItem_Mount::World && Pack.Get_TargetMount() == EMars_WorldItem_Mount::World
            && Pack.Get_IsSettled();

        auto HasCheese = false;
        auto Eligible = TArray<int32>();
        for (int32 Index = 0; Index < Backpack.Get_CargoSlotCount(); ++Index)
        {
            const auto Slot = Backpack.Get_CargoSlot(Index);
            const auto Item = Slot.Get_Item();
            if (ck::Is_NOT_Valid(Item))
            { continue; }

            HasCheese = HasCheese || Item.Has_StinkyCheese();
            if (utils_pantry_raid::Get_IsStealable(Item) && utils_pantry_raid::Get_SlotHeight(Slot, Pack) <= float64(InSpec.Theft.MaxReachCm))
            { Eligible.Add(Index); }
        }

        if (Grounded == false)
        { Eligible.Empty(); }

        const auto WasArmed = InOutRecord.ScentArmed;
        const auto EligibleBefore = InOutRecord.EligibleSlots.Num();
        if (Grounded && HasCheese)
        {
            if (InOutRecord.ArmingSince.IsSet() == false)
            { InOutRecord.ArmingSince = TOptional<float32>(InOutState.Clock); }

            InOutRecord.ScentArmed = InOutState.Clock - InOutRecord.ArmingSince.GetValue() >= InSpec.Scent.GroundArmSeconds;
        }
        else
        {
            InOutRecord.ArmingSince.Reset();
            InOutRecord.ScentArmed = false;
        }

        InOutRecord.HasCheese = HasCheese;
        InOutRecord.EligibleSlots = Eligible;
        if (WasArmed != InOutRecord.ScentArmed || EligibleBefore != Eligible.Num())
        { ++InOutState.Epoch; }

        Refresh_Guard(InSpec.Guard, InOutState, PackLocation, InOutRecord);
        Refresh_Lease(Grounded, InOutState, InOutRecord);
    }

    // Guarded on any chef within GuardEnterCm on the pack's floor; cleared only after every chef has stayed beyond
    // GuardExitCm for ClearDwellSeconds (a chef between the two holds the guard and restarts the dwell).
    private void Refresh_Guard(const FMars_PantryRaid_Guard& InGuard, const FMars_Fragment_PantryRaid& InState, FVector InPackLocation,
                               FMars_PantryRaid_PackRecord& InOutRecord)
    {
        const auto Nearest = utils_pantry_raid::Get_NearestChef(InState.Chefs, InPackLocation, InGuard.SameFloorCm);
        const auto HasNearest = ck::IsValid(Nearest.Root);
        const auto Distance = HasNearest ? utils_pantry_raid::Get_PlanarDistance(Nearest.Location, InPackLocation) : 0.0;

        if (HasNearest && Distance < float64(InGuard.GuardEnterCm))
        {
            if (InOutRecord.Guarded == false)
            { ++InOutRecord.GuardFlips; }

            InOutRecord.Guarded = true;
            InOutRecord.GuardChef = Nearest.Root;
            InOutRecord.ClearSince.Reset();
            return;
        }

        if (InOutRecord.Guarded == false)
        { return; }

        if (HasNearest && Distance <= float64(InGuard.GuardExitCm))
        {
            InOutRecord.GuardChef = Nearest.Root;
            InOutRecord.ClearSince.Reset();
            return;
        }

        if (InOutRecord.ClearSince.IsSet() == false)
        { InOutRecord.ClearSince = TOptional<float32>(InState.Clock); }

        if (InState.Clock - InOutRecord.ClearSince.GetValue() < InGuard.ClearDwellSeconds)
        { return; }

        InOutRecord.Guarded = false;
        InOutRecord.GuardChef = FCk_Handle();
        InOutRecord.ClearSince.Reset();
        ++InOutRecord.GuardFlips;
    }

    // A lease lapses at its expiry, when the pack is lifted, guarded, or its slot no longer holds the leased item, or when
    // its rat is gone. The rat finds its lease missing and aborts.
    private void Refresh_Lease(bool InGrounded, const FMars_Fragment_PantryRaid& InState, FMars_PantryRaid_PackRecord& InOutRecord)
    {
        if (InOutRecord.Lease.IsSet() == false)
        { return; }

        const auto Lease = InOutRecord.Lease.GetValue();
        const auto Slot = InOutRecord.Pack.As_Backpack().Get_CargoSlot(Lease.Slot);
        const auto Lapsed = InState.Clock > Lease.Expiry || InGrounded == false || InOutRecord.Guarded
            || Slot.Get_Item() != Lease.ExpectedItem || ck::Is_NOT_Valid(Lease.Rat) || utils_world_item::Get_IsEnding(Lease.Rat);
        if (Lapsed)
        { InOutRecord.Lease.Reset(); }
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Emergence
    //----------------------------------------------------------------------------------------------------------------------

    // At most one per frame: an armed pack with an eligible slot exists, the live + dead rats stay under MaxActiveRats, the
    // spacing since the last emergence has passed, and a den has an available resident whose OutsideStand is clear of
    // every chef (AvoidEnterCm) and from which the provider reaches one of an armed pack's eligible work points (F4-4: an
    // unreachable pack stays a target but spawns nothing; logged once per pack until it moves). The den answers
    // OnEmergeReady; the raid then spawns the rat (SpawnRat).
    private void Decide_Emergence(FCk_Handle_PantryRaid& InSelf, const FMars_PantryRaid_Spec& InSpec, FMars_Fragment_PantryRaid& InOutState)
    {
        auto AnyTarget = false;
        for (const auto& Record : InOutState.Packs)
        { AnyTarget = AnyTarget || (Record.ScentArmed && Record.EligibleSlots.Num() > 0); }

        // A den that never answered (its slot was taken the same frame) frees the raid after k_PendingAnswerSeconds.
        if (InOutState.PendingOperations.Num() > 0 && InOutState.LastEmergeAt.IsSet()
            && InOutState.Clock - InOutState.LastEmergeAt.GetValue() > k_PendingAnswerSeconds)
        {
            Log(f"[PantryRaid] [{InSelf.ToString()}] dropped {InOutState.PendingOperations.Num()} unanswered emergence(s)");
            InOutState.PendingOperations.Empty();
        }

        if (AnyTarget == false || InOutState.PendingOperations.Num() > 0)
        { return; }

        if (InOutState.Rats.Num() >= InSpec.Population.MaxActiveRats)
        { return; }

        if (InOutState.LastEmergeAt.IsSet() && InOutState.Clock - InOutState.LastEmergeAt.GetValue() < InSpec.Population.EmergeSpacingSeconds)
        { return; }

        for (auto Den : InOutState.Dens)
        {
            if (Den.Get_AvailableSlot(InOutState.Clock).IsSet() == false)
            { continue; }

            const auto Stand = Den.Get_PortalWorld(EMars_RatDen_Portal::OutsideStand);
            if (utils_pantry_raid::Get_IsAnyChefWithin(InOutState.Chefs, Stand, InSpec.Guard.AvoidEnterCm, InSpec.Guard.SameFloorCm))
            { continue; }

            if (Get_HasReachableTarget(InSelf, InSpec, Den, InOutState) == false)
            { continue; }

            const auto OperationId = InOutState.NextOperationId;
            ++InOutState.EmergencesRequested;
            ++InOutState.NextOperationId;
            InOutState.PendingOperations.Add(OperationId);
            InOutState.LastEmergeAt = TOptional<float32>(InOutState.Clock);
            auto Emerging = Den;
            Emerging.Request_Emerge(FMars_Request_RatDen_Emerge(OperationId, InOutState.Clock));
            return;
        }
    }

    // Whether a rat emerging from InDen has a target: an armed pack with an eligible slot that (F7-1) a rat at the den's
    // OutsideStand smells by the rat's own scent test (utils_pantry_raid::Get_IsWithinScent, with the arrival slack: the
    // resident may stop k_ArrivalCm short of the stand) and (F4-4) whose eligible work point the provider reaches from the
    // stand (the rat's own approach goal, utils_pantry_raid::Get_WorkPoint). Reach answers are cached per pack (re-asked on a
    // move, a different den or every k_ReachRecheckSeconds). A pack failing either test is logged once until it moves.
    private bool Get_HasReachableTarget(const FCk_Handle_PantryRaid& InSelf, const FMars_PantryRaid_Spec& InSpec,
                                        const FCk_Handle_RatDen& InDen, FMars_Fragment_PantryRaid& InOutState) const
    {
        const auto Stand = InDen.Get_PortalWorld(EMars_RatDen_Portal::OutsideStand);
        auto Any = false;
        for (int32 Index = 0; Index < InOutState.Packs.Num(); ++Index)
        {
            auto& Record = InOutState.Packs[Index];
            if (Record.ScentArmed == false || Record.EligibleSlots.Num() == 0 || ck::Is_NOT_Valid(Record.Pack))
            { continue; }

            const auto PackLocation = utils_transform::Get_EntityCurrentLocation(Record.Pack.As_Transform());
            const auto Moved = Record.ReachCheckedAt.IsSet() == false
                || (Record.ReachCheckedAt.GetValue() - PackLocation).Size() > k_ReachMoveCm;
            if (Moved)
            {
                Record.UnreachableLogged = false;
                Record.OutOfScentLogged = false;
            }

            if (utils_pantry_raid::Get_IsWithinScent(InSpec.Scent, utils_pantry_raid::Get_PlanarDistance(PackLocation, Stand),
                    float64(utils_pantry_rat::k_ArrivalCm)) == false)
            {
                if (Moved)
                {
                    Record.ReachCheckedAt = TOptional<FVector>(PackLocation);
                    Record.ReachDen = FCk_Handle_RatDen();
                }

                if (Record.OutOfScentLogged == false)
                {
                    Record.OutOfScentLogged = true;
                    ++InOutState.OutOfScentTargetLogs;
                    Log(f"[PantryRaid] [{InSelf.ToString()}] armed pack [{Record.Pack.ToString()}] at [{PackLocation.ToString()}] is "
                        + f"[{utils_pantry_raid::Get_PlanarDistance(PackLocation, Stand)}] cm from den [{InDen.ToString()}]'s OutsideStand: "
                        + f"beyond the scent range [{InSpec.Scent.ScentRangeCm}] less the arrival slack [{utils_pantry_rat::k_ArrivalCm}]; "
                        + f"no emergence for it until it moves (clock [{InOutState.Clock}])");
                }

                continue;
            }

            if (Moved || Record.ReachDen != InDen || InOutState.Clock - Record.ReachCheckedClock >= k_ReachRecheckSeconds)
            {
                Record.Reachable = Get_IsWorkPointReachable(InSpec, Stand, Record, PackLocation);
                Record.ReachCheckedAt = TOptional<FVector>(PackLocation);
                Record.ReachDen = InDen;
                Record.ReachCheckedClock = InOutState.Clock;
            }

            if (Record.Reachable)
            {
                Any = true;
                continue;
            }

            if (Record.UnreachableLogged == false)
            {
                Record.UnreachableLogged = true;
                ++InOutState.UnreachableTargetLogs;
                Log(f"[PantryRaid] [{InSelf.ToString()}] armed pack [{Record.Pack.ToString()}] at [{PackLocation.ToString()}] has no "
                    + f"provider route from den [{InDen.ToString()}]'s OutsideStand to any eligible work point: no emergence for it "
                    + f"until it moves (clock [{InOutState.Clock}])");
            }
        }

        return Any;
    }

    private bool Get_IsWorkPointReachable(const FMars_PantryRaid_Spec& InSpec, FVector InStand,
                                          const FMars_PantryRaid_PackRecord& InRecord, FVector InPackLocation) const
    {
        const auto Backpack = InRecord.Pack.As_Backpack();
        for (const auto SlotIndex : InRecord.EligibleSlots)
        {
            FCk_Handle SlotEntity = Backpack.Get_CargoSlot(SlotIndex);
            const auto SlotLocation = utils_transform::Get_EntityCurrentLocation(SlotEntity.As_Transform());
            const auto WorkPoint = utils_pantry_raid::Get_WorkPoint(SlotLocation, InPackLocation, InSpec.Theft.WorkStandoffCm, InStand.Z);
            auto Query = FCk_NavSurface_PathQuery(InStand, WorkPoint);
            Query.Set_AgentRadiusUu(utils_pantry_rat::k_AgentRadius);
            if (utils_nav_surface::Try_FindPathSync(Query).Get_Status() == ECk_NavSurface_QueryStatus::Success)
            { return true; }
        }

        return false;
    }
}
