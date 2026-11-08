// The pocket's drain-time acceptance: the TARGET inventory's custom accept delegate, which CkInventory runs inside the
// operation coordinator at the transfer's commit (a refusal rolls the item back into its source). Bound from the CDO, so it
// is stateless: it resolves the rat from the pocket's lifetime owner and reads the rat, its raid's lease and every chef's
// CURRENT location. CkInventory has already removed the item from its source when this runs (CkInventory_RequestHandlers.cpp
// DoTransfer: remove, then add with Validate), so the item has no parent inventory here: the source membership is the
// framework's own check (Failed_SourceNotInInventory) on the source the claim named, the lease's slot inventory.
UCLASS()
class UMars_PantryRat_PocketPolicy : UObject
{
    UFUNCTION()
    void OnCanAccept(FCk_Handle_Inventory InInventory, FCk_Handle_Item InItem, bool& OutCanAccept)
    { OutCanAccept = utils_pantry_rat::Get_CanCommitClaim(InInventory, InItem); }
}

namespace utils_pantry_rat
{
    // The root rides this far above the floor (SurfaceMotion Rays clearance); the assembly drops the mesh by it.
    const float32 k_Clearance = 18.0f;

    // The rat's navigator accepts an arrival this far (planar) short of its goal: a resident sent to its den's OutsideStand
    // stops anywhere within it (the raid's emergence scent test allows for it).
    const float32 k_ArrivalCm = 30.0f;

    // The provider route's wall clearance for a rat (the navigator's AgentRadius and every admission query). Kept at 25 for
    // R02 although its nose reaches 30.7 cm ahead of the root (half-width 15.5): a route that ends facing a wall can put the
    // nose up to ~6 cm into it; the routes, rings and the raid's readiness query are tuned on 25.
    const float32 k_AgentRadius = 25.0f;

    // The jaw socket's rest frame on the root: the R02 Carry_Mouth socket sits at (26.6, 0, 13.2) in the mesh
    // (PantryRat_R02_Manifest.json sockets.Carry_Mouth.component_cm, read back in Unreal to 0.0 cm), whose origin is the floor
    // under the root; its X is the item's forward, its Z the item's cap (forward-down). Its axes are R01's, so the rotation
    // stands (R01: (19.8, 0, 20.6)).
    const FTransform k_MouthRest = FTransform(FRotator(52.0, 0.0, 180.0), FVector(26.6, 0.0, 13.2 - 18.0));

    // A bulky item's pivot on the floor ahead of the jaw, held upright: the R02 Carry_Drag socket's rest X (26.9 cm ahead of
    // the mesh origin, which is the floor 18 cm under the root) at floor height (Phase 1: the dragged proxy's min z is 0).
    // R01: 24.546.
    const FTransform k_DragRest = FTransform(FRotator::ZeroRotator, FVector(26.9455, 0.0, -18.0));

    // An item wider than this either side of its hold is bulky: it is dragged, not carried in the mouth.
    const float32 k_BulkyHalfWidthCm = 10.0f;

    // A transient death drop is released this far ahead of the mouth.
    const float64 k_ReleaseAheadCm = 12.0;

    // A persistent death drop is launched forward at this speed.
    const float64 k_ReleaseSpeed = 80.0;

    // The flee goals a rat remembers (diagnostics and tests), newest last.
    const int32 k_FleeGoalHistory = 32;

    // The entity tag every rat root carries (a refused release finds its rat by it).
    const FName RatTag = n"TAG_MarsPantryRat";

    FGameplayTag Get_MonsterTag() { return utils_gameplay_tag::ResolveGameplayTag(n"Monster.Mars.PantryRat"); }

    FGameplayTag Get_MouthPoint() { return utils_gameplay_tag::ResolveGameplayTag(n"AttachPoint.Mars.RatMouth"); }

    FGameplayTag Get_PocketTag() { return utils_gameplay_tag::ResolveGameplayTag(n"Inventory.Mars.RatPocket"); }

    FCk_SurfaceMotion_Spec Make_MotionSpec()
    {
        auto Contact = FCk_SurfaceMotion_Contact();
        Contact.Set_Clearance(k_Clearance);
        Contact.Set_ProbeReach(120.0f);
        Contact.Set_HeightSource(ECk_SurfaceMotion_HeightSource::Rays);
        Contact.Set_WallPolicy(ECk_SurfaceMotion_WallPolicy::Slide);
        // 0 = no stepping: SurfaceMotion rejects a step height at or under the clearance, and a face lower than the
        // clearance is lifted over by the down ray anyway.
        Contact.Set_MaxStepHeight(0.0f);

        auto Movement = FCk_SurfaceMotion_Movement();
        Movement.Set_MaxSpeed(340.0f);
        Movement.Set_SurfaceTurnRate(360.0f);

        auto Spec = FCk_SurfaceMotion_Spec();
        Spec.Set_Contact(Contact);
        Spec.Set_Movement(Movement);
        return Spec;
    }

    // Composes the rat on InRoot, Bat-style: SurfaceMotion (the only writer of the root while it lives) -> SurfaceNavigator ->
    // monster (Health born invulnerable so no contact but a weapon hit ever depletes it; body zone; team) -> the body hurtbox
    // -> the mouth node published as AttachPoint.Mars.RatMouth -> the pocket (capacity 1, the drain-time policy, its
    // Persistent loot riding the mouth) on a child entity the rat owns -> the rat's fragments -> LAST the state machine.
    // A rejected spec or sub-feature ensures and returns an invalid handle.
    FCk_Handle_PantryRat Add(FCk_Handle_Transform& InRoot, FMars_PantryRat_Spec InSpec)
    {
        FCk_Handle RootEntity = InRoot;
        const auto Validation = InSpec.Validate();
        if (ck::EnsureIfNot(Validation.IsValid(), f"[PantryRat] [{RootEntity.ToString()}] rejected the spec: {Validation.Get_Error()}"))
        { return FCk_Handle_PantryRat(); }

        auto Motion = utils_surface_motion::Add(InRoot, Make_MotionSpec());
        if (ck::EnsureIfNot(ck::IsValid(Motion), f"[PantryRat] [{RootEntity.ToString()}] the surface motion was rejected"))
        { return FCk_Handle_PantryRat(); }

        auto Navigator = utils_surface_navigator::Add(Motion, FMars_SurfaceNavigator_Spec(InSpec.Tuning.Speeds.Creep, k_ArrivalCm, 2.0f, 15.0f, k_AgentRadius));
        if (ck::Is_NOT_Valid(Navigator))
        { return FCk_Handle_PantryRat(); }

        const auto BodyHealth = FMars_Health_Spec(1.0f, 1.0f, ECk_EnableDisable::Enable);
        const auto BodyZone = utils_hit_zone::Make_FleshZoneSpec(GameplayTags::HitZone_Mars_Body, 1.0f);
        auto Monster = utils_monster::Add(RootEntity, FMars_Monster_Spec(Get_MonsterTag(), BodyHealth, BodyZone, 8.0f, ECk_Team_ID::Two));
        if (ck::Is_NOT_Valid(Monster))
        { return FCk_Handle_PantryRat(); }

        auto Zone = Monster.Get_BodyZone();
        utils_hit_zone::AddHurtbox_Box(Zone, InRoot, FMars_HitZone_Hurtbox(InSpec.HurtboxHalfExtents, FTransform::Identity));

        auto MouthNode = utils_scene_node::Create(InRoot, k_MouthRest).As_Transform();
        utils_handle::Set_DebugName(MouthNode.H(), n"PantryRat.Mouth");
        auto AttachPointsSpec = FMars_AttachPoints_Spec();
        AttachPointsSpec.Points.Add(FMars_AttachPoint_Entry(Get_MouthPoint(), MouthNode));
        utils_attach_points::Add(RootEntity, AttachPointsSpec);

        auto Pocket = Add_Pocket(RootEntity);

        auto Params = FMars_Fragment_PantryRat_Params();
        Params.Spec = InSpec;
        Params.Monster = Monster;
        Params.Navigator = Navigator;
        Params.Pocket = Pocket;
        Params.MouthNode = MouthNode;

        RootEntity.Add_Fragment(FMars_Feature_PantryRat());
        RootEntity.Add_Fragment(Params);
        RootEntity.Add_Fragment(FMars_Fragment_PantryRat());
        RootEntity.Add_Fragment(FMars_Tag_PantryRat_NeedsSetup());
        utils_entity_tag::Add(RootEntity, RatTag);

        // Last: Alive's condition reads the Dead attribute as the machine enters its initial state.
        utils_state_machine::Add(RootEntity, FCk_StateMachine_Spec(UMars_SmState_PantryRat_Alive));
        return RootEntity.As_PantryRat();
    }

    // The pocket: a capacity-1, non-stacking, non-persisted inventory. CkInventory composes it on a child entity of the rat
    // (its lifetime owner is the rat, which the policy and the world item's mount resolve), its Persistent loot riding
    // AttachPoint.Mars.RatMouth.
    FCk_Handle_Inventory_DataOnly Add_Pocket(FCk_Handle& InRat)
    {
        TSubclassOf<UMars_PantryRat_PocketPolicy> PolicyClass = UMars_PantryRat_PocketPolicy;
        auto Params = utils_inventory_data_only::Make_Params_Bounded(Get_PocketTag(), 1,
            FCk_Delegate_Inventory_CustomCanAcceptItem_Dynamic(PolicyClass.GetDefaultObject(), n"OnCanAccept"),
            FCk_Delegate_Inventory_CustomCanStackItems_Dynamic());
        Params.Set_StackingPolicy(ECk_Inventory_StackingPolicy::NoStacking);
        Params.Set_PersistContents(ECk_EnableDisable::Disable);

        auto Pocket = utils_inventory_data_only::Add(InRat, Params, ECk_Replication::DoesNotReplicate);
        utils_world_item::Add_MountedInventory(Pocket, FMars_Fragment_MountedInventory(EMars_WorldItem_MountRule::PointAtOffset,
            Get_MouthPoint(), FTransform::Identity));
        return Pocket;
    }

    // The drain-time predicate (UMars_PantryRat_PocketPolicy). Its own loot re-entering (a failed outgoing transfer's
    // rollback) is always accepted. Otherwise: the rat is alive and not hit, mid-claim with an empty pocket,
    // InItem is the item its lease names, the raid still holds that lease under the claim's token and before its expiry, the
    // pack is still grounded and settled, and no chef stands within GuardEnterCm of the pack RIGHT NOW (current transforms).
    bool Get_CanCommitClaim(const FCk_Handle_Inventory& InPocket, const FCk_Handle_Item& InItem)
    {
        auto Rat = utils_entity_lifetime::Get_LifetimeOwner(InPocket).As_PantryRat(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(Rat))
        { return false; }

        const auto& State = Rat.Get_Fragment(FMars_Fragment_PantryRat);

        // The rat's own loot coming back: CkInventory validates a failed transfer's rollback re-add against the SOURCE's
        // accept policy (CkInventory_RequestHandlers.cpp DoTransfer rollback), so a refused release out of the pocket must
        // be let back in, or the item would end in no inventory at all.
        if (ck::IsValid(State.Loot) && InItem == State.Loot)
        { return true; }

        if (State.Death.LethalPending || Get_IsDeadPhase(State.Phase) || State.Phase != EMars_PantryRat_Phase::ClaimTransfer)
        { return false; }

        if (Rat.Get_Pocket().Get_NumItems() != 0 || State.Target.IsSet() == false)
        { return false; }

        const auto Target = State.Target.GetValue();
        if (InItem != Target.ExpectedItem)
        { return false; }

        const auto Raid = Rat.Get_Raid();
        if (ck::Is_NOT_Valid(Raid))
        { return false; }

        const auto Lease = Raid.TryGet_LeaseOf(Rat);
        if (Lease.IsSet() == false || Lease.GetValue().Token != Target.Token || Lease.GetValue().ExpectedItem != InItem
            || Lease.GetValue().Expiry < Raid.Get_Clock())
        { return false; }

        auto Pack = Target.Pack;
        if (ck::Is_NOT_Valid(Pack) || Pack.Get_Mount() != EMars_WorldItem_Mount::World || Pack.Get_IsSettled() == false)
        { return false; }

        const auto Guard = Rat.Get_Tuning().Guard;
        const auto PackLocation = utils_transform::Get_EntityCurrentLocation(Pack.As_Transform());
        return utils_pantry_raid::Get_IsAnyChefWithin(utils_pantry_raid::Read_ChefsNow(Rat), PackLocation, Guard.GuardEnterCm, Guard.SameFloorCm) == false;
    }

    bool Get_IsDeadPhase(EMars_PantryRat_Phase InPhase)
    {
        return InPhase == EMars_PantryRat_Phase::Dying || InPhase == EMars_PantryRat_Phase::LootReleasePending
            || InPhase == EMars_PantryRat_Phase::DeadHold || InPhase == EMars_PantryRat_Phase::CorpseFade
            || InPhase == EMars_PantryRat_Phase::Destroyed || InPhase == EMars_PantryRat_Phase::BlockedCleanup;
    }

    // The phases a loaded thief lives in: it has an item (or one is landing) and only ever flees.
    bool Get_IsLoadedPhase(EMars_PantryRat_Phase InPhase)
    {
        return InPhase == EMars_PantryRat_Phase::CarryMountPending || InPhase == EMars_PantryRat_Phase::FleeWithLoot
            || InPhase == EMars_PantryRat_Phase::FleePause || InPhase == EMars_PantryRat_Phase::FleeCornered;
    }

    // The edge table an Advance must pass. Kernel-only phases (ClaimTransfer, CarryMountPending, every death phase, the den
    // hide) are never entered by an Advance; a loaded rat (or one in a loaded phase) only moves between the flee phases -
    // FleeWithLoot has no edge to ReturnEmpty, DenEnter, DormantInDen or any fade; DenEnter is entered only from ReturnEmpty,
    // ClaimTell only from Inspect, Inspect only from a watching or approaching phase.
    bool Get_IsAllowedAdvance(EMars_PantryRat_Phase InFrom, EMars_PantryRat_Phase InTo, bool InLoaded)
    {
        if (InFrom == InTo || Get_IsDeadPhase(InFrom))
        { return false; }

        if (InTo == EMars_PantryRat_Phase::CorpseFade || Get_IsDeadPhase(InTo) || InTo == EMars_PantryRat_Phase::ClaimTransfer
            || InTo == EMars_PantryRat_Phase::CarryMountPending || InTo == EMars_PantryRat_Phase::DormantInDen
            || InTo == EMars_PantryRat_Phase::Peek || InTo == EMars_PantryRat_Phase::Emerge)
        { return false; }

        if (InLoaded || Get_IsLoadedPhase(InFrom))
        {
            return InTo == EMars_PantryRat_Phase::FleeWithLoot || InTo == EMars_PantryRat_Phase::FleePause
                || InTo == EMars_PantryRat_Phase::FleeCornered;
        }

        if (Get_IsLoadedPhase(InTo) || InFrom == EMars_PantryRat_Phase::ClaimTransfer)
        { return false; }

        if (InTo == EMars_PantryRat_Phase::DenEnter)
        { return InFrom == EMars_PantryRat_Phase::ReturnEmpty; }

        if (InTo == EMars_PantryRat_Phase::ClaimTell)
        { return InFrom == EMars_PantryRat_Phase::Inspect; }

        if (InTo == EMars_PantryRat_Phase::Inspect)
        {
            return InFrom == EMars_PantryRat_Phase::Observe || InFrom == EMars_PantryRat_Phase::BoundApproach
                || InFrom == EMars_PantryRat_Phase::WatchGuarded;
        }

        return true;
    }

    // The side the corpse topples to: the one the lethal blow's impulse pushes it toward (InRatRight . InImpulse > 0 ->
    // Right; no planar impulse -> Left), unless that side failed the assembly's floor clearance test and the other passed.
    // Both failing keeps the pushed side (there is no safe side to prefer).
    EMars_PantryRat_ToppleSide Get_ToppleSide(FVector InRatRight, FVector InImpulse, bool InLeftClear, bool InRightClear)
    {
        const auto Pushed = InRatRight.GetSafeNormal2D().DotProduct(InImpulse.GetSafeNormal2D()) > 0.0
            ? EMars_PantryRat_ToppleSide::Right : EMars_PantryRat_ToppleSide::Left;
        if (Pushed == EMars_PantryRat_ToppleSide::Right && InRightClear == false && InLeftClear)
        { return EMars_PantryRat_ToppleSide::Left; }

        if (Pushed == EMars_PantryRat_ToppleSide::Left && InLeftClear == false && InRightClear)
        { return EMars_PantryRat_ToppleSide::Right; }

        return Pushed;
    }

    // Every den portal of InRaid's dens (Entry and Exit), world: the loaded flee keep-out.
    TArray<FVector> Get_PortalPoints(const FCk_Handle_PantryRaid& InRaid)
    {
        auto Points = TArray<FVector>();
        if (ck::Is_NOT_Valid(InRaid))
        { return Points; }

        for (auto Den : InRaid.Get_Dens())
        {
            if (ck::Is_NOT_Valid(Den))
            { continue; }

            Points.Add(Den.Get_PortalWorld(EMars_RatDen_Portal::EntryPortal));
            Points.Add(Den.Get_PortalWorld(EMars_RatDen_Portal::ExitPortal));
        }

        return Points;
    }

    // The planar distance from InPoint to the nearest of InPortals (a large number when there are none).
    float64 Get_PortalClearance(const TArray<FVector>& InPortals, FVector InPoint)
    {
        auto Nearest = 1.0e9;
        for (const auto& Portal : InPortals)
        { Nearest = Math::Min(Nearest, utils_pantry_raid::Get_PlanarDistance(Portal, InPoint)); }

        return Nearest;
    }
}

namespace utils_pantry_raid
{
    // The raid's tuning a rat copies into its spec.
    FMars_PantryRat_Tuning Make_RatTuning(const FMars_PantryRaid_Spec& InSpec)
    {
        auto Tuning = FMars_PantryRat_Tuning();
        Tuning.Guard = InSpec.Guard;
        Tuning.Scent = InSpec.Scent;
        Tuning.Routing = InSpec.Routing;
        Tuning.Theft = InSpec.Theft;
        Tuning.Speeds = InSpec.Speeds;
        Tuning.Hop = InSpec.Hop;
        Tuning.Rhythm = InSpec.Rhythm;
        return Tuning;
    }
}

//--------------------------------------------------------------------------------------------------------------------------
// Getters
//--------------------------------------------------------------------------------------------------------------------------

mixin FMars_PantryRat_Spec Get_Spec(const FCk_Handle_PantryRat& Self)
{
    return Self.Get_Fragment(FMars_Fragment_PantryRat_Params).Spec;
}

mixin FMars_PantryRat_Tuning Get_Tuning(const FCk_Handle_PantryRat& Self)
{
    return Self.Get_Fragment(FMars_Fragment_PantryRat_Params).Spec.Tuning;
}

mixin FMars_PantryRat_Links Get_Links(const FCk_Handle_PantryRat& Self)
{
    return Self.Get_Fragment(FMars_Fragment_PantryRat_Params).Spec.Links;
}

// Invalid once the raid is gone.
mixin FCk_Handle_PantryRaid Get_Raid(const FCk_Handle_PantryRat& Self)
{
    return Self.Get_Fragment(FMars_Fragment_PantryRat_Params).Spec.Links.Raid.As_PantryRaid(ECk_SanityCheck::UnChecked);
}

// Invalid once the den is gone (a removed den never takes its rat along).
mixin FCk_Handle_RatDen Get_Den(const FCk_Handle_PantryRat& Self)
{
    return Self.Get_Fragment(FMars_Fragment_PantryRat_Params).Spec.Links.Den.As_RatDen(ECk_SanityCheck::UnChecked);
}

mixin FCk_Handle_Monster Get_Monster(const FCk_Handle_PantryRat& Self)
{
    return Self.Get_Fragment(FMars_Fragment_PantryRat_Params).Monster;
}

mixin FCk_Handle_SurfaceNavigator Get_Navigator(const FCk_Handle_PantryRat& Self)
{
    return Self.Get_Fragment(FMars_Fragment_PantryRat_Params).Navigator;
}

mixin FCk_Handle_Inventory_DataOnly Get_Pocket(const FCk_Handle_PantryRat& Self)
{
    return Self.Get_Fragment(FMars_Fragment_PantryRat_Params).Pocket;
}

mixin FCk_Handle_Transform Get_MouthNode(const FCk_Handle_PantryRat& Self)
{
    return Self.Get_Fragment(FMars_Fragment_PantryRat_Params).MouthNode;
}

mixin EMars_PantryRat_Phase Get_Phase(const FCk_Handle_PantryRat& Self)
{
    return Self.Get_Fragment(FMars_Fragment_PantryRat).Phase;
}

// Seconds in the current phase (the rat's clock).
mixin float32 Get_PhaseAge(const FCk_Handle_PantryRat& Self)
{
    const auto& State = Self.Get_Fragment(FMars_Fragment_PantryRat);
    return State.Clock - State.PhaseStartedAt;
}

mixin float32 Get_Clock(const FCk_Handle_PantryRat& Self)
{
    return Self.Get_Fragment(FMars_Fragment_PantryRat).Clock;
}

// The rat holds (or is landing) an item: its pocket is not empty, or its loot is recorded.
mixin bool Get_IsLoaded(const FCk_Handle_PantryRat& Self)
{
    return ck::IsValid(Self.Get_Fragment(FMars_Fragment_PantryRat).Loot) || Self.Get_Pocket().Get_NumItems() > 0;
}

mixin FCk_Handle_Item Get_Loot(const FCk_Handle_PantryRat& Self)
{
    return Self.Get_Fragment(FMars_Fragment_PantryRat).Loot;
}

mixin FCk_Handle Get_CarryVisual(const FCk_Handle_PantryRat& Self)
{
    return Self.Get_Fragment(FMars_Fragment_PantryRat).CarryVisual;
}

mixin bool Get_HasCarryReceipt(const FCk_Handle_PantryRat& Self)
{
    return Self.Get_Fragment(FMars_Fragment_PantryRat).CarryReceipt;
}

mixin TOptional<FMars_PantryRat_Target> Get_Target(const FCk_Handle_PantryRat& Self)
{
    return Self.Get_Fragment(FMars_Fragment_PantryRat).Target;
}

mixin FMars_PantryRat_Threat Get_Threat(const FCk_Handle_PantryRat& Self)
{
    return Self.Get_Fragment(FMars_Fragment_PantryRat).Threat;
}

mixin FMars_PantryRat_Route Get_Route(const FCk_Handle_PantryRat& Self)
{
    return Self.Get_Fragment(FMars_Fragment_PantryRat).Route;
}

// The route answered for a move issued in the current phase (an older phase's answer never counts).
mixin bool Get_IsRouteIn(const FCk_Handle_PantryRat& Self, EMars_PantryRat_RouteStatus InStatus)
{
    const auto& State = Self.Get_Fragment(FMars_Fragment_PantryRat);
    return State.Route.Status == InStatus && State.Route.IssuedIn == State.Phase;
}

mixin FMars_PantryRat_Rhythm Get_Rhythm(const FCk_Handle_PantryRat& Self)
{
    return Self.Get_Fragment(FMars_Fragment_PantryRat).Rhythm;
}

mixin FMars_PantryRat_Death Get_Death(const FCk_Handle_PantryRat& Self)
{
    return Self.Get_Fragment(FMars_Fragment_PantryRat).Death;
}

mixin bool Get_IsDead(const FCk_Handle_PantryRat& Self)
{
    return utils_pantry_rat::Get_IsDeadPhase(Self.Get_Phase());
}

mixin TOptional<float32> Get_NoTargetSince(const FCk_Handle_PantryRat& Self)
{
    return Self.Get_Fragment(FMars_Fragment_PantryRat).NoTargetSince;
}

mixin EMars_PantryRat_ClaimResult Get_LastClaimResult(const FCk_Handle_PantryRat& Self)
{
    return Self.Get_Fragment(FMars_Fragment_PantryRat).LastClaimResult;
}

mixin int32 Get_ClaimTransfersIssued(const FCk_Handle_PantryRat& Self)
{
    return Self.Get_Fragment(FMars_Fragment_PantryRat).ClaimTransfersIssued;
}

mixin int32 Get_RejectedAdvances(const FCk_Handle_PantryRat& Self)
{
    return Self.Get_Fragment(FMars_Fragment_PantryRat).RejectedAdvances;
}

mixin int32 Get_StaleResults(const FCk_Handle_PantryRat& Self)
{
    return Self.Get_Fragment(FMars_Fragment_PantryRat).StaleResults;
}

mixin TArray<FVector> Get_FleeGoals(const FCk_Handle_PantryRat& Self)
{
    return Self.Get_Fragment(FMars_Fragment_PantryRat).FleeGoals;
}

mixin int32 Get_PhaseChanges(const FCk_Handle_PantryRat& Self)
{
    return Self.Get_Fragment(FMars_Fragment_PantryRat).PhaseChanges;
}

mixin float32 Get_FadeAlpha(const FCk_Handle_PantryRat& Self)
{
    return Self.Get_Fragment(FMars_Fragment_PantryRat).FadeAlpha;
}

// The empty return faded out: every rat primitive is hidden until the entity is retired.
mixin bool Get_IsHidden(const FCk_Handle_PantryRat& Self)
{
    return Self.Get_Fragment(FMars_Fragment_PantryRat).Hidden;
}

mixin int32 Get_LoadedVetoes(const FCk_Handle_PantryRat& Self)
{
    return Self.Get_Fragment(FMars_Fragment_PantryRat).LoadedVetoes;
}

mixin FVector Get_Location(const FCk_Handle_PantryRat& Self)
{
    return utils_transform::Get_EntityCurrentLocation(Self.As_Transform());
}

mixin int32 Get_FacesIssued(const FCk_Handle_PantryRat& Self)
{
    return Self.Get_Fragment(FMars_Fragment_PantryRat).FacesIssued;
}

// The raid's best target for this rat from where it stands (its lease's slot once it holds one); unset without a raid or
// a target. The one lookup the control layer and the drain's facing share.
mixin TOptional<FMars_PantryRaid_TargetView> TryGet_TargetView(const FCk_Handle_PantryRat& Self)
{
    const auto Raid = Self.Get_Raid();
    if (ck::Is_NOT_Valid(Raid))
    { return TOptional<FMars_PantryRaid_TargetView>(); }

    auto Query = FMars_PantryRaid_TargetQuery();
    Query.Rat = Self;
    Query.RatLocation = Self.Get_Location();
    Query.Seed = Self.Get_Links().OperationId;
    return Raid.TryGet_Target(Query);
}

//--------------------------------------------------------------------------------------------------------------------------
// Requests
//--------------------------------------------------------------------------------------------------------------------------

mixin void Request_Advance(FCk_Handle_PantryRat& Self, const FMars_Request_PantryRat_Advance& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_PantryRat_Requests);
    Requests.AdvanceRequests.Add(InRequest);
}

mixin void Request_MoveTo(FCk_Handle_PantryRat& Self, const FMars_Request_PantryRat_MoveTo& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_PantryRat_Requests);
    Requests.MoveToRequests.Add(InRequest);
}

mixin void Request_Stop(FCk_Handle_PantryRat& Self, const FMars_Request_PantryRat_Stop& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_PantryRat_Requests);
    Requests.MoveToRequests.Empty();
    Requests.StopRequests.Add(InRequest);
}

mixin void Request_Claim(FCk_Handle_PantryRat& Self, const FMars_Request_PantryRat_Claim& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_PantryRat_Requests);
    Requests.ClaimRequests.Add(InRequest);
}

mixin void Request_ClaimResult(FCk_Handle_PantryRat& Self, const FMars_Request_PantryRat_ClaimResult& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_PantryRat_Requests);
    Requests.ClaimResultRequests.Add(InRequest);
}

mixin void Request_TakeHit(FCk_Handle_PantryRat& Self, const FMars_Request_PantryRat_TakeHit& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_PantryRat_Requests);
    Requests.TakeHitRequests.Add(InRequest);
}

mixin void Request_Died(FCk_Handle_PantryRat& Self, const FMars_Request_PantryRat_Died& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_PantryRat_Requests);
    Requests.DiedRequests.Add(InRequest);
}

mixin void Request_NavResult(FCk_Handle_PantryRat& Self, const FMars_Request_PantryRat_NavResult& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_PantryRat_Requests);
    Requests.NavResultRequests.Add(InRequest);
}

mixin void Request_ReleaseRefused(FCk_Handle_PantryRat& Self, const FMars_Request_PantryRat_ReleaseRefused& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_PantryRat_Requests);
    Requests.ReleaseRefusedRequests.Add(InRequest);
}

//--------------------------------------------------------------------------------------------------------------------------
// Signal Binding
//--------------------------------------------------------------------------------------------------------------------------

mixin void BindTo_OnPhaseChanged(FCk_Handle_PantryRat& Self, FMars_Delegate_PantryRat_OnPhaseChanged InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_PantryRat_Signals);
    Fragment.OnPhaseChanged.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnPhaseChanged(FCk_Handle_PantryRat& Self, FMars_Delegate_PantryRat_OnPhaseChanged InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_PantryRat_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_PantryRat_Signals).OnPhaseChanged.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void BindTo_OnClaimResolved(FCk_Handle_PantryRat& Self, FMars_Delegate_PantryRat_OnClaimResolved InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_PantryRat_Signals);
    Fragment.OnClaimResolved.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnClaimResolved(FCk_Handle_PantryRat& Self, FMars_Delegate_PantryRat_OnClaimResolved InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_PantryRat_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_PantryRat_Signals).OnClaimResolved.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}
