// The rat's single writer. Drain priority (DESIGN_TECH_SPEC section 13):
//   1. destruction guard: a Destroyed rat drops every request;
//   2. TakeHit (lethal only for a positive weapon hit by a chef: Causer an item with a Strike trait, Instigator a Hotbar root)
//      and Died (the monster's OnDied: Dying, then the loot's release or DeadHold);
//   3. ClaimResult (the inventory's answer: Accepted keeps the exact item and waits for its carry receipt; a refusal is a
//      benign Contended / Cancelled, the lease dropped, back to Observe) and ReleaseRefused (BlockedCleanup);
//   4. Stop;
//   5. NavResult (only for the route's own goal and phase);
//   6. Advance (the edge table: a loaded rat only flees), MoveTo (admitted only on a real provider route) and Claim (the
//      guarded transfer into the pocket - never a CargoSlot Take).
// Every write lands before any broadcast; the requests fragment is removed before anything else happens.
class UMars_Processor_PantryRat_HandleRequests : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _MarkedDirtyBy = FMars_Fragment_PantryRat_Requests;

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_PantryRat);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle,
                       FMars_Fragment_PantryRat_Requests& InRequests,
                       FMars_Fragment_PantryRat& InState)
    {
        auto Self = InHandle.As_PantryRat();

        TArray<FMars_Request_PantryRat_TakeHit> TakeHitRequests = InRequests.TakeHitRequests;
        TArray<FMars_Request_PantryRat_Died> DiedRequests = InRequests.DiedRequests;
        TArray<FMars_Request_PantryRat_ClaimResult> ClaimResultRequests = InRequests.ClaimResultRequests;
        TArray<FMars_Request_PantryRat_ReleaseRefused> ReleaseRefusedRequests = InRequests.ReleaseRefusedRequests;
        TArray<FMars_Request_PantryRat_Stop> StopRequests = InRequests.StopRequests;
        TArray<FMars_Request_PantryRat_NavResult> NavResultRequests = InRequests.NavResultRequests;
        TArray<FMars_Request_PantryRat_Advance> AdvanceRequests = InRequests.AdvanceRequests;
        TArray<FMars_Request_PantryRat_MoveTo> MoveToRequests = InRequests.MoveToRequests;
        TArray<FMars_Request_PantryRat_Claim> ClaimRequests = InRequests.ClaimRequests;

        // InRequests is invalid past this line; removing before broadcasting lets re-entrant requests survive.
        Self.Request_TryRemove(FMars_Fragment_PantryRat_Requests);

        if (Self.Get_Phase() == EMars_PantryRat_Phase::Destroyed)
        { return; }

        auto Changes = FMars_PantryRat_DrainEvents();
        Changes.PhaseBefore = Self.Get_Phase();

        for (const auto& Request : TakeHitRequests)
        { HandleTakeHit(Self, Request); }

        for (const auto& Request : DiedRequests)
        { HandleDied(Self, Changes); }

        for (const auto& Request : ClaimResultRequests)
        { HandleClaimResult(Self, Request, Changes); }

        for (const auto& Request : ReleaseRefusedRequests)
        { HandleReleaseRefused(Self, Request, Changes); }

        if (StopRequests.Num() > 0)
        { HandleStop(Self); }

        for (const auto& Request : NavResultRequests)
        { HandleNavResult(Self, Request); }

        for (const auto& Request : AdvanceRequests)
        { HandleAdvance(Self, Request, Changes); }

        if (MoveToRequests.Num() > 0)
        { HandleMoveTo(Self, MoveToRequests.Last()); }

        for (const auto& Request : ClaimRequests)
        { HandleClaim(Self, Request, Changes); }

        utils_pantry_rat::Broadcast(Self, Changes);
    }

    //----------------------------------------------------------------------------------------------------------------------
    // 2. Lethal
    //----------------------------------------------------------------------------------------------------------------------

    private void HandleTakeHit(FCk_Handle_PantryRat& InRat, const FMars_Request_PantryRat_TakeHit& InRequest)
    {
        auto& State = InRat.Get_Fragment(FMars_Fragment_PantryRat);
        if (State.Death.LethalPending || utils_pantry_rat::Get_IsDeadPhase(State.Phase))
        { return; }

        if (utils_pantry_rat::Get_IsWeaponHit(InRequest.Event) == false)
        { return; }

        State.Death.LethalPending = true;
        ++State.Death.Sequence;
        State.Death.HitImpulse = InRequest.Event.Hit.Impulse;

        // The Health drain applies SetInvulnerable before ApplyDamage and latches the depletion once, so the zone's own
        // forwarded hit and this one deplete it exactly once, whichever reaches the Health drain first.
        auto Health = InRat.Get_Monster().Get_BodyHealth();
        Health.Request_SetInvulnerable(FMars_Request_Health_SetInvulnerable(ECk_EnableDisable::Disable));
        auto Lethal = InRequest.Event;
        Lethal.Amount = Health.Get_Max();
        Health.Request_ApplyDamage(FMars_Request_Health_ApplyDamage(Lethal));

        utils_pantry_rat::Cancel_Lease(InRat, State);
        auto Navigator = InRat.Get_Navigator();
        Navigator.Request_Stop(FMars_Request_SurfaceNavigator_Stop());
        State.Route.Status = EMars_PantryRat_RouteStatus::Idle;
    }

    // Dying; a claim already handed to the inventory waits for its answer (a late success is released, never rolled back by
    // inventing an item); otherwise the loot's release starts now, or the corpse holds.
    private void HandleDied(FCk_Handle_PantryRat& InRat, FMars_PantryRat_DrainEvents& InOutChanges)
    {
        auto& State = InRat.Get_Fragment(FMars_Fragment_PantryRat);
        if (utils_pantry_rat::Get_IsDeadPhase(State.Phase))
        { return; }

        const auto WasClaiming = State.Phase == EMars_PantryRat_Phase::ClaimTransfer;
        State.Death.LethalPending = true;
        State.Death.DiedAt = State.Clock;
        State.Death.CorpseDeadline = State.Clock + InRat.Get_Tuning().DeathHoldSeconds;
        utils_pantry_rat::Cancel_Lease(InRat, State);
        utils_pantry_rat::Set_Phase(State, EMars_PantryRat_Phase::Dying);

        auto Raid = InRat.Get_Raid();
        if (ck::IsValid(Raid))
        { Raid.Request_RatDied(FMars_Request_PantryRaid_RatDied(InRat)); }

        if (WasClaiming)
        { return; }

        utils_pantry_rat::Begin_LootRelease(InRat, State);
    }

    //----------------------------------------------------------------------------------------------------------------------
    // 3. Inventory results
    //----------------------------------------------------------------------------------------------------------------------

    private void HandleClaimResult(FCk_Handle_PantryRat& InRat, const FMars_Request_PantryRat_ClaimResult& InRequest,
                                   FMars_PantryRat_DrainEvents& InOutChanges)
    {
        auto& State = InRat.Get_Fragment(FMars_Fragment_PantryRat);
        const auto Pocket = InRat.Get_Pocket();
        FCk_Handle PocketEntity = Pocket;
        const FCk_Handle Parent = InRequest.Item.Get_ParentInventory();
        const auto Landed = InRequest.Result == ECk_Inventory_OperationResult_Transfer::Success && InRequest.NewItemInTarget == InRequest.Item
            && Parent == PocketEntity;

        // A death that arrived while the transfer was in flight: a committed item is released, once.
        if (State.Phase == EMars_PantryRat_Phase::Dying)
        {
            if (Landed)
            {
                State.Loot = InRequest.Item;
                InOutChanges.Add_Claim(EMars_PantryRat_ClaimResult::Accepted, InRequest.Item);
                utils_pantry_rat::Begin_LootRelease(InRat, State);
            }
            else
            {
                InOutChanges.Add_Claim(utils_pantry_rat::Get_ClaimResult(InRequest.Result), InRequest.Item);
                utils_pantry_rat::Begin_LootRelease(InRat, State);
            }
            return;
        }

        if (State.Phase != EMars_PantryRat_Phase::ClaimTransfer)
        {
            ++State.StaleResults;
            Log(f"[PantryRat] [{InRat.ToString()}] ignored a claim answer [{InRequest.Result :n}] outside ClaimTransfer ([{State.Phase :n}])");
            return;
        }

        const auto Token = State.Target.IsSet() ? State.Target.GetValue().Token : 0;
        auto Raid = InRat.Get_Raid();
        if (ck::IsValid(Raid))
        { Raid.Request_ReleaseLease(FMars_Request_PantryRaid_ReleaseLease(InRat, Token)); }

        if (Landed == false)
        {
            const auto Result = InRequest.Result == ECk_Inventory_OperationResult_Transfer::Success
                ? EMars_PantryRat_ClaimResult::Failed : utils_pantry_rat::Get_ClaimResult(InRequest.Result);
            State.LastClaimResult = Result;
            State.Target.Reset();
            utils_pantry_rat::Set_Phase(State, EMars_PantryRat_Phase::Observe);
            utils_pantry_rat::Plan_Rhythm(InRat, State);
            InOutChanges.Add_Claim(Result, InRequest.Item);
            return;
        }

        State.Loot = InRequest.Item;
        State.LastClaimResult = EMars_PantryRat_ClaimResult::Accepted;
        State.CarryReceipt = false;
        utils_pantry_rat::Set_Phase(State, EMars_PantryRat_Phase::CarryMountPending);
        InOutChanges.Add_Claim(EMars_PantryRat_ClaimResult::Accepted, InRequest.Item);

        // A Persistent food mounts its own body on the mouth through the WorldItem reconcile (the receipt is its settled
        // Carried mount, Tick); a transient item gets one Visual world item on the mouth node (the receipt is its construction).
        if (InRequest.Item.Has_PersistentWorldItem() == false && InRequest.Item.Has_Presentation())
        {
            const UMars_ItemTrait_Presentation Presentation = InRequest.Item.Get_Presentation();
            FCk_Handle RatEntity = InRat;
            State.CarryVisual = utils_world_item::Request_SpawnVisual(RatEntity,
                FMars_WorldItem_VisualSpec(InRequest.Item, InRat.Get_MouthNode(), utils_pantry_rat::Get_CarryOffset(Presentation)));
        }
    }

    private void HandleReleaseRefused(FCk_Handle_PantryRat& InRat, const FMars_Request_PantryRat_ReleaseRefused& InRequest,
                                      FMars_PantryRat_DrainEvents& InOutChanges)
    {
        auto& State = InRat.Get_Fragment(FMars_Fragment_PantryRat);
        if (State.Phase != EMars_PantryRat_Phase::LootReleasePending || State.Death.ReleaseHolder != InRequest.WorldItem)
        {
            ++State.StaleResults;
            return;
        }

        utils_pantry_rat::Block_Cleanup(InRat, State, f"its loot's world item refused the release [{InRequest.Reason :n}]");
    }

    //----------------------------------------------------------------------------------------------------------------------
    // 4-5. Movement
    //----------------------------------------------------------------------------------------------------------------------

    private void HandleStop(FCk_Handle_PantryRat& InRat)
    {
        auto& State = InRat.Get_Fragment(FMars_Fragment_PantryRat);
        auto Navigator = InRat.Get_Navigator();
        Navigator.Request_Stop(FMars_Request_SurfaceNavigator_Stop());
        State.Route.Status = EMars_PantryRat_RouteStatus::Idle;
        ++State.Route.Epoch;
    }

    private void HandleNavResult(FCk_Handle_PantryRat& InRat, const FMars_Request_PantryRat_NavResult& InRequest)
    {
        auto& State = InRat.Get_Fragment(FMars_Fragment_PantryRat);
        if (State.Route.Status != EMars_PantryRat_RouteStatus::Moving || (InRequest.Goal - State.Route.Goal).Size() > 1.0)
        {
            ++State.StaleResults;
            return;
        }

        State.Route.Status = InRequest.Arrived ? EMars_PantryRat_RouteStatus::Arrived : EMars_PantryRat_RouteStatus::Failed;
    }

    //----------------------------------------------------------------------------------------------------------------------
    // 6. Control
    //----------------------------------------------------------------------------------------------------------------------

    private void HandleAdvance(FCk_Handle_PantryRat& InRat, const FMars_Request_PantryRat_Advance& InRequest, FMars_PantryRat_DrainEvents& InOutChanges)
    {
        auto& State = InRat.Get_Fragment(FMars_Fragment_PantryRat);
        const auto Allowed = State.Phase == InRequest.From && State.Death.LethalPending == false
            && utils_pantry_rat::Get_IsAllowedAdvance(State.Phase, InRequest.To, InRat.Get_IsLoaded());
        if (Allowed == false)
        {
            ++State.RejectedAdvances;
            if (InRat.Get_IsLoaded() && utils_pantry_rat::Get_IsHomeOrFadePhase(InRequest.To))
            { utils_pantry_rat::Note_LoadedVeto(InRat, State, f"an Advance {InRequest.From :n} -> {InRequest.To :n}"); }
            return;
        }

        // Inspect needs the lease it was granted; leaving the claim path drops the lease.
        if (InRequest.To == EMars_PantryRat_Phase::Inspect)
        {
            if (InRequest.Target.IsSet() == false)
            {
                ++State.RejectedAdvances;
                return;
            }

            State.Target = InRequest.Target;
        }
        else if (InRequest.To != EMars_PantryRat_Phase::ClaimTell)
        { utils_pantry_rat::Cancel_Lease(InRat, State); }

        // The new phase asks for its own moves: a move still in flight is stopped.
        if (State.Route.Status == EMars_PantryRat_RouteStatus::Moving)
        {
            auto Navigator = InRat.Get_Navigator();
            Navigator.Request_Stop(FMars_Request_SurfaceNavigator_Stop());
        }

        utils_pantry_rat::Set_Phase(State, InRequest.To);
        utils_pantry_rat::Plan_Rhythm(InRat, State);

        // The thief works the slot facing it: once per entry, after this drain's Stop (the navigator applies a Face only
        // when no move owns the steer).
        if (InRequest.To == EMars_PantryRat_Phase::Inspect || InRequest.To == EMars_PantryRat_Phase::ClaimTell)
        { utils_pantry_rat::Face_Target(InRat, State); }
    }

    // The rat's own provider admission: a raid / flee / home goal moves only on a Success route; a loaded rat's flee route
    // keeps LoadedPortalKeepOutCm from every den portal along every waypoint. A refused goal is a Failed route (no move).
    private void HandleMoveTo(FCk_Handle_PantryRat& InRat, const FMars_Request_PantryRat_MoveTo& InRequest)
    {
        auto& State = InRat.Get_Fragment(FMars_Fragment_PantryRat);
        if (State.Death.LethalPending || utils_pantry_rat::Get_IsDeadPhase(State.Phase))
        { return; }

        ++State.Route.Epoch;
        State.Route.Goal = InRequest.Goal;
        State.Route.Purpose = InRequest.Purpose;
        State.Route.IssuedIn = State.Phase;
        State.Route.PathMode = EMars_SurfaceNavigator_PathMode::Provider;

        const auto Start = InRat.Get_Location();
        auto Query = FCk_NavSurface_PathQuery(Start, InRequest.Goal);
        Query.Set_AgentRadiusUu(utils_pantry_rat::k_AgentRadius);
        const auto Result = utils_nav_surface::Try_FindPathSync(Query);
        if (Result.Get_Status() != ECk_NavSurface_QueryStatus::Success)
        {
            Log(f"[PantryRat] [{InRat.ToString()}] refused a {InRequest.Purpose :n} move to [{InRequest.Goal.ToString()}]: provider [{Result.Get_Status() :n}]");
            State.Route.Status = EMars_PantryRat_RouteStatus::Failed;
            return;
        }

        if (InRequest.Purpose == EMars_PantryRat_RoutePurpose::Flee && InRat.Get_IsLoaded())
        {
            const auto Portals = utils_pantry_rat::Get_PortalPoints(InRat.Get_Raid());
            const auto KeepOut = float64(InRat.Get_Tuning().Routing.LoadedPortalKeepOutCm);
            auto Clear = utils_pantry_rat::Get_PortalClearance(Portals, InRequest.Goal) >= KeepOut;
            for (const auto& Waypoint : Result.Get_Waypoints())
            { Clear = Clear && utils_pantry_rat::Get_PortalClearance(Portals, Waypoint) >= KeepOut; }

            if (Clear == false)
            {
                State.Route.Status = EMars_PantryRat_RouteStatus::Failed;
                return;
            }

            if (State.FleeGoals.Num() >= utils_pantry_rat::k_FleeGoalHistory)
            { State.FleeGoals.RemoveAt(0); }

            State.FleeGoals.Add(InRequest.Goal);
        }

        auto Navigator = InRat.Get_Navigator();
        Navigator.Request_SetSpeed(FMars_Request_SurfaceNavigator_SetSpeed(InRequest.Speed));
        Navigator.Request_MoveTo(FMars_Request_SurfaceNavigator_MoveTo(InRequest.Goal));
        State.Route.Status = EMars_PantryRat_RouteStatus::Moving;
    }

    // ClaimTell -> ClaimTransfer and the transfer of the leased item from the leased slot's inventory into the pocket, with
    // this processor's correlated callback. The drain re-checks only what it owns (phase, token, pocket, lethal); the guard,
    // the lease and the pack are the pocket policy's at the commit itself.
    private void HandleClaim(FCk_Handle_PantryRat& InRat, const FMars_Request_PantryRat_Claim& InRequest, FMars_PantryRat_DrainEvents& InOutChanges)
    {
        auto& State = InRat.Get_Fragment(FMars_Fragment_PantryRat);
        const auto Valid = State.Phase == EMars_PantryRat_Phase::ClaimTell && State.Death.LethalPending == false && State.Target.IsSet()
            && State.Target.GetValue().Token == InRequest.Token && InRat.Get_IsLoaded() == false;
        if (Valid == false)
        {
            ++State.StaleResults;
            return;
        }

        const auto Target = State.Target.GetValue();
        auto Source = Target.SourceInventory;
        if (ck::Is_NOT_Valid(Source) || ck::Is_NOT_Valid(Target.ExpectedItem))
        {
            utils_pantry_rat::Cancel_Lease(InRat, State);
            utils_pantry_rat::Set_Phase(State, EMars_PantryRat_Phase::Observe);
            utils_pantry_rat::Plan_Rhythm(InRat, State);
            return;
        }

        utils_pantry_rat::Set_Phase(State, EMars_PantryRat_Phase::ClaimTransfer);
        ++State.ClaimTransfersIssued;
        utils_pantry_rat::Face_Target(InRat, State);

        // A Persistent loot rides the mouth at its carry offset (the drag offset for a bulky one): the pocket's mount marker
        // is set for the item before it lands.
        if (Target.ExpectedItem.Has_Presentation())
        {
            FCk_Handle PocketEntity = InRat.Get_Pocket();
            PocketEntity.Get_Fragment(FMars_Fragment_MountedInventory).Offset =
                utils_pantry_rat::Get_CarryOffset(Target.ExpectedItem.Get_Presentation());
        }
        Source.Request_TransferItem_ToDataOnly(
            FCk_Request_Inventory_TransferItem_ToDataOnly(Target.ExpectedItem, InRat.Get_Pocket()),
            FCk_Delegate_Inventory_OnOperationResult_Transfer(this, n"OnClaimTransfer"));
    }

    // The target is the pocket; its lifetime owner is the rat. A rat gone since the claim has nothing to record.
    UFUNCTION()
    private void OnClaimTransfer(FCk_Handle_Inventory InSource,
                                 FCk_Handle_Item InItem,
                                 FCk_Handle_Inventory InTarget,
                                 int32 InCount,
                                 FCk_Handle_Item InNewItemInTarget,
                                 ECk_Inventory_OperationResult_Transfer InResult)
    {
        auto Rat = utils_entity_lifetime::Get_LifetimeOwner(InTarget).As_PantryRat(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(Rat))
        { return; }

        Rat.Request_ClaimResult(FMars_Request_PantryRat_ClaimResult(InItem, InNewItemInTarget, InResult));
    }

}

// A refused release of a rat's loot, bound from the CDO when the release is issued: the rat is found by its tag and the
// world item it is waiting on.
UCLASS()
class UMars_PantryRat_ReleaseListener : UObject
{
    UFUNCTION()
    void OnLootReleaseRefused(FCk_Handle_WorldItem InWorldItem, EMars_WorldItem_ReleaseRefusal InReason)
    {
        FCk_Handle WorldItemEntity = InWorldItem;
        for (auto Candidate : utils_entity_tag::ForEach_Entity(WorldItemEntity, utils_pantry_rat::RatTag))
        {
            auto Rat = Candidate.As_PantryRat(ECk_SanityCheck::UnChecked);
            if (ck::IsValid(Rat) && Rat.Get_Death().ReleaseHolder == WorldItemEntity)
            { Rat.Request_ReleaseRefused(FMars_Request_PantryRat_ReleaseRefused(WorldItemEntity, InReason)); }
        }
    }
}

// What one drain changed, broadcast after every write (utils_pantry_rat::Broadcast).
struct FMars_PantryRat_DrainEvents
{
    EMars_PantryRat_Phase PhaseBefore = EMars_PantryRat_Phase::Emerge;
    TArray<EMars_PantryRat_ClaimResult> ClaimResults;
    TArray<FCk_Handle_Item> ClaimItems;
}

mixin void Add_Claim(FMars_PantryRat_DrainEvents& Self, EMars_PantryRat_ClaimResult InResult, FCk_Handle_Item InItem)
{
    Self.ClaimResults.Add(InResult);
    Self.ClaimItems.Add(InItem);
}

namespace utils_pantry_rat
{
    // A weapon hit: a positive amount, the causer an item with a Strike trait, the instigator a chef root (a Hotbar). A
    // monster's own dealer (Causer = the dealer) or a cosmetic contact never qualifies.
    bool Get_IsWeaponHit(const FMars_DamageEvent& InEvent)
    {
        if (InEvent.Amount <= 0.0f || InEvent.Source.Causer.Is_Item() == false)
        { return false; }

        if (InEvent.Source.Causer.As_Item().Has_Strike() == false)
        { return false; }

        return ck::IsValid(InEvent.Source.Instigator.As_Hotbar(ECk_SanityCheck::UnChecked));
    }

    EMars_PantryRat_ClaimResult Get_ClaimResult(ECk_Inventory_OperationResult_Transfer InResult)
    {
        if (InResult == ECk_Inventory_OperationResult_Transfer::Success)
        { return EMars_PantryRat_ClaimResult::Accepted; }

        if (InResult == ECk_Inventory_OperationResult_Transfer::Failed_RejectedByCustomAcceptanceLogic)
        { return EMars_PantryRat_ClaimResult::Contended; }

        if (InResult == ECk_Inventory_OperationResult_Transfer::Failed_SourceNotInInventory
            || InResult == ECk_Inventory_OperationResult_Transfer::Failed_OperationCancelled)
        { return EMars_PantryRat_ClaimResult::Cancelled; }

        return EMars_PantryRat_ClaimResult::Failed;
    }

    // Where the loot rides the mouth node: a bulky item (presentation half-width over 10 cm) at the Carry_Drag socket's rest
    // frame (upright, its pivot on the floor ahead of the jaw) instead; no item type is excluded.
    FTransform Get_CarryOffset(const UMars_ItemTrait_Presentation InPresentation)
    {
        const auto HalfWidth = InPresentation.Grip.HalfWidth.IsSet() ? InPresentation.Grip.HalfWidth.GetValue() : 0.0f;
        if (HalfWidth > k_BulkyHalfWidthCm)
        { return k_DragRest.GetRelativeTransform(k_MouthRest); }

        return FTransform::Identity;
    }

    // A route answer belongs to the phase instance that asked for it: every phase change starts with no route, so a
    // re-entered phase never reads the last visit's Arrived / Failed.
    void Set_Phase(FMars_Fragment_PantryRat& InOutState, EMars_PantryRat_Phase InPhase)
    {
        if (InOutState.Phase == InPhase)
        { return; }

        InOutState.StepFrom.Add(InOutState.Phase);
        InOutState.StepTo.Add(InPhase);
        InOutState.Phase = InPhase;
        InOutState.PhaseStartedAt = InOutState.Clock;
        InOutState.Route.Status = EMars_PantryRat_RouteStatus::Idle;
        ++InOutState.Route.Epoch;
        ++InOutState.PhaseChanges;
    }

    // A Face toward the target slot's mount point (the pack's root when the raid shows no target; the leased pack's when
    // even that is gone), planar, from the rat's root. Nothing is sent from closer than 1 cm.
    void Face_Target(FCk_Handle_PantryRat& InRat, FMars_Fragment_PantryRat& InOutState)
    {
        const auto Here = InRat.Get_Location();
        const auto View = InRat.TryGet_TargetView();
        auto Point = TOptional<FVector>();
        if (View.IsSet())
        { Point = TOptional<FVector>(View.GetValue().SlotLocation.IsZero() ? View.GetValue().PackLocation : View.GetValue().SlotLocation); }
        else if (InOutState.Target.IsSet() && ck::IsValid(InOutState.Target.GetValue().Pack))
        { Point = TOptional<FVector>(utils_transform::Get_EntityCurrentLocation(InOutState.Target.GetValue().Pack.As_Transform())); }

        if (Point.IsSet() == false)
        { return; }

        auto Direction = Point.GetValue() - Here;
        Direction.Z = 0.0;
        if (Direction.Size() < 1.0)
        { return; }

        auto Navigator = InRat.Get_Navigator();
        Navigator.Request_Face(FMars_Request_SurfaceNavigator_Face(Direction));
        ++InOutState.FacesIssued;
        Log(f"[PantryRat] [{InRat.ToString()}] faces [{Point.GetValue().ToString()}] from [{Here.ToString()}] in [{InOutState.Phase :n}] "
            + f"(heading [{Direction.GetSafeNormal().ToString()}])");
    }

    // Drops the rat's lease (by its token) and its target.
    void Cancel_Lease(FCk_Handle_PantryRat& InRat, FMars_Fragment_PantryRat& InOutState)
    {
        if (InOutState.Target.IsSet() == false)
        { return; }

        auto Raid = InRat.Get_Raid();
        if (ck::IsValid(Raid))
        { Raid.Request_ReleaseLease(FMars_Request_PantryRaid_ReleaseLease(InRat, InOutState.Target.GetValue().Token)); }

        InOutState.Target.Reset();
    }

    // The rhythm a phase starts with: bursts for BoundApproach (empty 1..3) and FleeWithLoot (loaded 2..3), a pause deadline
    // for Observe (0.6..1.5 s) and FleePause (0.35..0.65 s); deterministic per rat (operation id) and entry.
    void Plan_Rhythm(const FCk_Handle_PantryRat& InRat, FMars_Fragment_PantryRat& InOutState)
    {
        const auto Rhythm = InRat.Get_Tuning().Rhythm;
        const auto Seed = InRat.Get_Links().OperationId;
        ++InOutState.Rhythm.Entries;
        const auto Salt = InOutState.Rhythm.Entries;

        if (InOutState.Phase == EMars_PantryRat_Phase::BoundApproach)
        { InOutState.Rhythm.BurstsPlanned = utils_pantry_raid::Get_RangeInt(Seed, Salt, Rhythm.EmptyBoundsMin, Rhythm.EmptyBoundsMax); }
        else if (InOutState.Phase == EMars_PantryRat_Phase::FleeWithLoot)
        { InOutState.Rhythm.BurstsPlanned = utils_pantry_raid::Get_RangeInt(Seed, Salt, Rhythm.LoadedBoundsMin, Rhythm.LoadedBoundsMax); }
        else if (InOutState.Phase == EMars_PantryRat_Phase::Observe)
        { InOutState.Rhythm.PauseDeadline = InOutState.Clock + utils_pantry_raid::Get_RangeFloat(Seed, Salt, Rhythm.ObserveMinSeconds, Rhythm.ObserveMaxSeconds); }
        else if (InOutState.Phase == EMars_PantryRat_Phase::FleePause)
        { InOutState.Rhythm.PauseDeadline = InOutState.Clock + utils_pantry_raid::Get_RangeFloat(Seed, Salt, Rhythm.FleePauseMinSeconds, Rhythm.FleePauseMaxSeconds); }
    }

    // Dying -> LootReleasePending with the release issued (once per death), or DeadHold when the pocket is empty. A
    // Persistent food not yet mounted on the mouth waits (the Tick issues the release once its carry mount settles).
    void Begin_LootRelease(FCk_Handle_PantryRat& InRat, FMars_Fragment_PantryRat& InOutState)
    {
        if (ck::Is_NOT_Valid(InOutState.Loot))
        {
            Enter_DeadHold(InRat, InOutState);
            return;
        }

        Set_Phase(InOutState, EMars_PantryRat_Phase::LootReleasePending);
        Try_IssueRelease(InRat, InOutState);
    }

    // The one release of the loot: Persistent -> its own world item's Release (receipt: World, the item in its holder);
    // Transient -> a World-mode world item adopting the original item from the pocket (receipt: the item in that holder).
    // An item that already left the pocket without a receipt blocks the cleanup.
    void Try_IssueRelease(FCk_Handle_PantryRat& InRat, FMars_Fragment_PantryRat& InOutState)
    {
        if (InOutState.Death.ReleaseOperationId > 0)
        { return; }

        auto Loot = InOutState.Loot;
        const auto Pocket = InRat.Get_Pocket();
        FCk_Handle PocketEntity = Pocket;
        const FCk_Handle Parent = Loot.Get_ParentInventory();

        if (Loot.Has_PersistentWorldItem())
        {
            auto WorldItem = Loot.Get_PersistentWorldItem();
            FCk_Handle WorldItemEntity = WorldItem;
            // Not yet on the mouth: the Tick retries once the carry mount settles.
            if (Parent == PocketEntity && (WorldItem.Get_TargetMount() != EMars_WorldItem_Mount::Carried || WorldItem.Get_IsSettled() == false))
            { return; }

            ++InOutState.Death.ReleaseOperationId;
            InOutState.Death.ReleaseHolder = WorldItemEntity;
            TSubclassOf<UMars_PantryRat_ReleaseListener> ListenerClass = UMars_PantryRat_ReleaseListener;
            WorldItem.BindTo_OnReleaseRefused(FMars_Delegate_WorldItem_OnReleaseRefused(ListenerClass.GetDefaultObject(), n"OnLootReleaseRefused"));

            const auto Forward = utils_transform::Get_EntityCurrentRotation(InRat.As_Transform()).GetForwardVector();
            WorldItem.Request_Release(FMars_Request_WorldItem_Release(Forward * k_ReleaseSpeed, FVector::ZeroVector));
            return;
        }

        if (Parent != PocketEntity)
        {
            Block_Cleanup(InRat, InOutState, f"its transient loot [{Loot.ToString()}] left the pocket without a release receipt");
            return;
        }

        ++InOutState.Death.ReleaseOperationId;
        const auto Mouth = utils_transform::Get_EntityCurrentTransform(InRat.Get_MouthNode());
        const auto Forward = utils_transform::Get_EntityCurrentRotation(InRat.As_Transform()).GetForwardVector();

        auto SpawnParams = UMars_WorldItem_EntityScript::Params();
        SpawnParams.SpawnTransform = FTransform(utils_transform::Get_EntityCurrentRotation(InRat.As_Transform()),
            Mouth.GetLocation() + Forward * k_ReleaseAheadCm);
        SpawnParams.Definition = utils_held_item::Make_DefinitionSoft(Loot.Get_Definition());
        SpawnParams.Mode = EMars_WorldItem_Mode::World;
        SpawnParams.SourceItem = Loot;
        SpawnParams.SourceInventory = Pocket;

        // Under the world's transient entity: the dropped item outlives the corpse.
        auto Owner = ck::TransientEntity();
        auto Pending = utils_entity_script::Request_SpawnEntity(Owner, utils_world_item::Get_WorldItemScriptClass(Loot), SpawnParams);
        InOutState.Death.ReleaseHolder = Pending.Get_EntityUnderConstruction();

        if (ck::IsValid(InOutState.CarryVisual))
        { utils_entity_lifetime::Request_DestroyEntity(InOutState.CarryVisual); }

        InOutState.CarryVisual = FCk_Handle();
    }

    // The corpse holds from its death (CorpseDeadline was set as it died); CorpseFade waits for the deadline AND the receipt.
    void Enter_DeadHold(FCk_Handle_PantryRat& InRat, FMars_Fragment_PantryRat& InOutState)
    {
        Set_Phase(InOutState, EMars_PantryRat_Phase::DeadHold);
    }

    // The phases that take a rat home, hide it or fade it: a loaded rat is refused every one of them.
    bool Get_IsHomeOrFadePhase(EMars_PantryRat_Phase InPhase)
    {
        return InPhase == EMars_PantryRat_Phase::ReturnEmpty || InPhase == EMars_PantryRat_Phase::DenEnter
            || InPhase == EMars_PantryRat_Phase::DormantInDen || InPhase == EMars_PantryRat_Phase::CorpseFade
            || InPhase == EMars_PantryRat_Phase::Destroyed;
    }

    // A loaded rat refused a return, a fade or a retirement: counted every time, logged the first time (one line per rat).
    void Note_LoadedVeto(const FCk_Handle_PantryRat& InRat, FMars_Fragment_PantryRat& InOutState, FString InWhat)
    {
        ++InOutState.LoadedVetoes;
        if (InOutState.LoadedVetoes == 1)
        {
            Log(f"[PantryRat] [{InRat.ToString()}] op [{InRat.Get_Links().OperationId}] refused {InWhat}: loaded with "
                + f"[{InOutState.Loot.ToString()}] (a loaded thief never returns, fades or despawns; later refusals are counted only)");
        }
    }

    // The corpse stays visible and owns its pocket; a diagnostic names why. Never destroys the owner.
    void Block_Cleanup(FCk_Handle_PantryRat& InRat, FMars_Fragment_PantryRat& InOutState, FString InReason)
    {
        Set_Phase(InOutState, EMars_PantryRat_Phase::BlockedCleanup);
        InOutState.Death.BlockedReason = InReason;
        Warning(f"[PantryRat] [{InRat.ToString()}] blocked its corpse cleanup: {InReason}");
    }

    // One Display line per phase change (the headless lanes' only view of a rat's behaviour).
    void Log_Phase(const FCk_Handle_PantryRat& InRat, EMars_PantryRat_Phase InPrevious, EMars_PantryRat_Phase InNew)
    {
        const auto& State = InRat.Get_Fragment(FMars_Fragment_PantryRat);
        Log(f"[PantryRat] [{InRat.ToString()}] op [{InRat.Get_Links().OperationId}] {InPrevious :n} -> {InNew :n} at "
            + f"[{InRat.Get_Location().ToString()}] clock [{InRat.Get_Clock()}] loot [{State.Loot.ToString()}] fade [{State.FadeAlpha}]");
    }

    // Logs and broadcasts every phase step the pass took (one line and one OnPhaseChanged per step), then clears them.
    void Emit_PhaseSteps(FCk_Handle_PantryRat& InRat)
    {
        auto& State = InRat.Get_Fragment(FMars_Fragment_PantryRat);
        TArray<EMars_PantryRat_Phase> From = State.StepFrom;
        TArray<EMars_PantryRat_Phase> To = State.StepTo;
        State.StepFrom.Empty();
        State.StepTo.Empty();

        for (int32 Index = 0; Index < From.Num(); ++Index)
        { Log_Phase(InRat, From[Index], To[Index]); }

        if (InRat.Has_Fragment(FMars_Fragment_PantryRat_Signals) == false)
        { return; }

        for (int32 Index = 0; Index < From.Num(); ++Index)
        { InRat.Get_Fragment(FMars_Fragment_PantryRat_Signals).OnPhaseChanged.Broadcast(InRat, From[Index], To[Index]); }
    }

    void Broadcast(FCk_Handle_PantryRat& InRat, const FMars_PantryRat_DrainEvents& InChanges)
    {
        Emit_PhaseSteps(InRat);

        if (InRat.Has_Fragment(FMars_Fragment_PantryRat_Signals) == false)
        { return; }

        for (int32 Index = 0; Index < InChanges.ClaimResults.Num(); ++Index)
        { InRat.Get_Fragment(FMars_Fragment_PantryRat_Signals).OnClaimResolved.Broadcast(InRat, InChanges.ClaimResults[Index], InChanges.ClaimItems[Index]); }
    }
}
