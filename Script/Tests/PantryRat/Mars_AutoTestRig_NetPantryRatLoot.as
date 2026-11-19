// One mount change a machine's copy of the row's food raised, with its frame.
struct FMars_NetRatTest_MountChange
{
    UPROPERTY()
    EMars_WorldItem_Mount To = EMars_WorldItem_Mount::World;

    UPROPERTY()
    int32 Frame = -1;
}

// One application of the rat's ledger on a copy as the loot rig reads it: its phase, its impulse and its frame.
struct FMars_NetRatTest_LootApplication
{
    UPROPERTY()
    EMars_PantryRat_Phase Phase = EMars_PantryRat_Phase::Emerge;

    UPROPERTY()
    FVector HitImpulse = FVector::ZeroVector;

    UPROPERTY()
    int32 Frame = -1;
}

// Which world items Count_WorldItemsOf counts: of Definition, in Mode, within Cm (planar) of Near.
struct FMars_NetRatTest_ItemQuery
{
    UPROPERTY()
    UCk_InventoryItem_Definition Definition;

    UPROPERTY()
    EMars_WorldItem_Mode Mode = EMars_WorldItem_Mode::World;

    UPROPERTY()
    FVector Near = FVector::ZeroVector;

    UPROPERTY()
    float64 Cm = 0.0;
}

enum EMars_NetRatTest_Hand
{
    // The hand stays where the row put it.
    Fixed,
    // Every sample moves the hand beside this machine's rat (k_HandFromRat off its root) while it lives.
    FollowsRat
}

enum EMars_NetRatTest_Born
{
    // The born rat lives through its BornThrough.
    Alive,
    // The born rat takes one lethal blow as it composes.
    Corpse
}

enum EMars_NetRatTest_Swing
{
    // The dealer's sweep alone: the copy's own zone drops what it sends.
    ContactOnly,
    // The sweep, then the claim of what it found (what the strike task does).
    Claimed
}

// The pantry rat loot net tests' shared steps, on top of the rat rig. The striker is a carrier on the subject on both
// machines (a hand node, a belt node, their attach points, a hotbar of one bag slot, HeldItem and HeldItemUse, a viewpoint
// on the hand node), a team and a dealer whose dealt hits each machine counts; armed is the server's cleaver in slot 0, selected. The subject
// carries no prey tag, so no raid reads it as a chef. The food court is the rat court plus a Mushroom, stowed into
// cargo slot 1 with the Monk's Rind in slot 2, so the first lease takes the Mushroom. Each machine samples what its
// rat carries (its carry visual against the mouth), its first dead frame and its corpse's fade, finds its food copy
// near the pack and records its mount changes, and on a client records every application of the rat's ledger with
// its impulse.
UCLASS(Abstract)
class UMars_AutoTestRig_NetPantryRatLoot : UMars_AutoTestRig_NetPantryRat
{
    default _TimeoutSeconds = 28.0f;

    protected const FVector k_HandFromRat = FVector(0.0, -100.0, 0.0);
    // The born rat's spot less 120 on Y, at its root's height.
    protected const FVector k_BornHandFromBase = FVector(-325.0, -120.0, 18.0);
    protected const FVector k_CourtHandFromBase = FVector(0.0, -500.0, 18.0);
    // A cleaver blow pushing +Y at the cleaver's impulse speed.
    protected const FVector k_BlowImpulse = FVector(0.0, 300.0, 0.0);
    protected const FVector k_FoodFromBase = FVector(150.0, -350.0, 5.0);
    protected const float64 k_FoodNearPackCm = 600.0;
    protected const float64 k_ImpulseTolerance = 0.01;

    // Each machine: the striker.
    protected FMars_TESTONLY_NetCarrier _Striker;
    protected FCk_Handle_DamageDealer _StrikerDealer;
    protected int32 _StrikerDealt = 0;
    protected int32 _StrikerDealtFrame = -1;
    protected EMars_NetRatTest_Hand _HandMode = EMars_NetRatTest_Hand::Fixed;

    // Each machine: its swing and its claim.
    protected int32 _LootSwingFrame = -1;
    protected FCk_ShapeCast_Result _LootSwingHit;
    protected bool _LootSwingHitRatZone = false;
    protected int32 _LootClaimFrame = -1;

    // Server: the food court's Mushroom.
    protected FCk_Handle _RowFoodEntity;
    protected FCk_Handle_Item _RowFoodItem;
    protected bool _TracksFood = false;

    // Each machine: its food copy and its mount changes.
    protected FCk_Handle_WorldItem _RowFood;
    protected int32 _RowFoodFoundFrame = -1;
    protected TArray<FMars_NetRatTest_MountChange> _FoodMounts;

    // Each machine: the samples.
    protected TOptional<float64> _CarryWorstCm;
    protected int32 _FirstDeadFrame = -1;
    protected float32 _FirstDeadAge = -1.0f;
    protected FVector _FirstDeadImpulse = FVector::ZeroVector;
    protected TOptional<EMars_PantryRat_ToppleSide> _FirstDeadSide;
    protected TOptional<float32> _LowestCorpseFade;
    protected bool _SawCorpseFadeBelowOne = false;
    protected TOptional<EMars_PantryRat_ToppleSide> _ScriptToppleSide;
    protected int32 _LedgerDeadHoldFrame = -1;
    protected FVector _LedgerImpulseSeen = FVector::ZeroVector;
    protected int32 _LootDiedFrame = -1;
    protected int32 _DealtWhenDied = -1;
    protected TArray<FMars_NetRatTest_LootApplication> _LootApplications;
    // The frames this machine first saw its pocket hold an item, its carry visual live, its food on its rat's mouth,
    // and, once its rat was dead, a World-mode world item of the row's loot definition (set by the row) within 300 of
    // it.
    protected int32 _PocketHeldFrame = -1;
    protected int32 _CarryVisualFrame = -1;
    protected int32 _FoodOnRatFrame = -1;
    protected int32 _LootDroppedFrame = -1;
    protected UCk_InventoryItem_Definition _RowLootDefinition;

    private FVector _HandFromBase = FVector::ZeroVector;
    private bool _LootRatHooked = false;
    private FMars_PantryRaid_Spec _FoodCourtSpec;
    private FName _FoodCourtContinuation;
    private FName _ArmedContinuation;

    //------------------------------------------------------------------------------------------------------------------
    // Both machines: the row and the striker
    //------------------------------------------------------------------------------------------------------------------

    protected void Begin_LootRow(FVector InBase, FVector InHandFromBase)
    {
        Begin_PantryRow(InBase);
        _HandFromBase = InHandFromBase;
        Compose_Striker(InBase + InHandFromBase);
    }

    // The net world-item rig's carrier composed inline (one bag slot, no backpack slot), a team and a dealer.
    private void Compose_Striker(FVector InHandLocation)
    {
        auto Subject = Get_SubjectEntity();
        auto Carrier = FMars_TESTONLY_NetCarrier();

        auto HandEntity = utils_entity_lifetime::Request_CreateEntity(Subject);
        Carrier.Hand = utils_transform::Add(HandEntity, FTransform(FRotator::ZeroRotator, InHandLocation), ECk_Replication::DoesNotReplicate);

        auto BeltEntity = utils_entity_lifetime::Request_CreateEntity(Subject);
        Carrier.Belt = utils_transform::Add(BeltEntity, FTransform(FRotator::ZeroRotator, InHandLocation + FVector(0.0, 40.0, -60.0)),
            ECk_Replication::DoesNotReplicate);

        auto Points = FMars_AttachPoints_Spec();
        Points.Points.Add(FMars_AttachPoint_Entry(GameplayTags::AttachPoint_Mars_Hand, Carrier.Hand));
        Points.Points.Add(FMars_AttachPoint_Entry(GameplayTags::AttachPoint_Mars_Belt, Carrier.Belt));
        utils_attach_points::Add(Subject, Points);

        auto HotbarSpec = FMars_Hotbar_Spec();
        HotbarSpec.BagSlotCount = 1;
        HotbarSpec.BackpackSlot = ECk_EnableDisable::Disable;
        Carrier.Hotbar = utils_hotbar::Add(Subject, HotbarSpec);
        Carrier.HeldItem = utils_held_item::Add(Subject);
        Carrier.Use = utils_held_item_use::Add(Subject);
        _Striker = Carrier;

        // The view is the hand node, where the rows sweep from (the authority judges a strike's reach from the view).
        auto Viewpoint = FMars_Fragment_PlayerViewpoint();
        Viewpoint.Viewpoint = Carrier.Hand;
        Subject.Add_Fragment(FMars_Feature_PlayerViewpoint());
        Subject.Add_Fragment(Viewpoint);

        utils_team::Add(Subject, ECk_Team_ID::One, ECk_Replication::DoesNotReplicate);
        _StrikerDealer = utils_damage_dealer::Add(Subject, FMars_DamageDealer_Spec());
        _StrikerDealer.BindTo_OnDamageDealt(FMars_Delegate_DamageDealer_OnDamageDealt(this, n"OnStrikerDealt"));
    }

    protected FVector Get_StrikerHandLocation()
    {
        return utils_transform::Get_EntityCurrentLocation(_Striker.Hand);
    }

    //------------------------------------------------------------------------------------------------------------------
    // Armed
    //------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    protected void Is_LootServerReady(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(utils_mars_net::Get_HasReplicatedSpawnOwner(Get_SubjectEntity()) && ck::IsValid(_Striker.Hotbar)
            && _Striker.Hotbar.Get_IsReady());
    }

    // Server: a cleaver into slot 0, selected. The hotbar must be ready.
    protected void Arm_Server()
    {
        auto Slot = _Striker.Hotbar.Get_Slot(0);
        auto Request = FCk_Request_Inventory_AddItemByDefinition(mars_items::Cleaver(), 1);
        Request.Set_Policy(ECk_Inventory_AddPolicy::ForceNewItem);
        Slot.Request_AddItemByDefinition(Request, FCk_Delegate_Inventory_OnOperationResult_AddByDefinition());
        _Striker.Hotbar.Request_SetSelection(FMars_Request_Hotbar_SetSelection(TOptional<int32>(0)));
    }

    // Server: once the spawn owner and the hotbar are ready, armed; then InContinuation.
    protected void Begin_ServerArmed(FName InContinuation)
    {
        _ArmedContinuation = InContinuation;
        WaitUntil(n"Is_LootServerReady", n"OnLootServerReady", k_SlowPolls);
    }

    UFUNCTION()
    private void OnLootServerReady(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Arm_Server();
        WaitUntil(n"Is_StrikerArmed", _ArmedContinuation, k_SlowPolls);
    }

    UFUNCTION()
    protected void Is_StrikerArmed(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        Sample_Row();
        auto Result = OutResult;
        Result.Set(Get_IsStrikerArmed());
    }

    // This machine's hotbar is ready and its HeldItem holds a cleaver.
    protected bool Get_IsStrikerArmed()
    {
        if (ck::Is_NOT_Valid(_Striker.Hotbar) || _Striker.Hotbar.Get_IsReady() == false)
        { return false; }

        const auto Item = _Striker.HeldItem.Get_CurrentItem();
        return ck::IsValid(Item) && Item.Get_Definition() == mars_items::Cleaver();
    }

    //------------------------------------------------------------------------------------------------------------------
    // Server: the food court
    //------------------------------------------------------------------------------------------------------------------

    // The rat court plus a Mushroom, through its waits in order (the owner, the floor, the build, the pack, the Rind
    // and the Mushroom ready, the Mushroom into slot 1 and the Rind into slot 2, both held and the Mushroom settled on
    // its slot), until the first rat is out and found; then InContinuation.
    protected void Begin_ServerFoodCourt(FMars_PantryRaid_Spec InSpec, FName InContinuation)
    {
        _FoodCourtSpec = InSpec;
        _FoodCourtContinuation = InContinuation;
        _TracksFood = true;
        WaitUntil(n"Is_RowSpawnOwnerPublished", n"OnFoodCourtOwnerPublished", k_SlowPolls);
    }

    UFUNCTION()
    private void OnFoodCourtOwnerPublished(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Spawn_ServerCourt(_FoodCourtSpec);
        auto Owner = utils_mars_net::Get_ReplicatedSpawnOwner(Get_SubjectEntity());
        auto FoodSpec = FMars_WorldItem_WorldSpec(utils_held_item::Make_DefinitionSoft(mars_items::Food_Mushroom()),
            FTransform(FRotator::ZeroRotator, _Base + k_FoodFromBase));
        _RowFoodEntity = utils_world_item::Request_SpawnWorld(Owner, FoodSpec);
        Track_ForCleanup(_RowFoodEntity);
        WaitUntil(n"Is_RowFloorJoined", n"OnFoodCourtFloorJoined", k_SlowPolls);
    }

    UFUNCTION()
    private void OnFoodCourtFloorJoined(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Request_ServerFieldBuild();
        WaitUntil(n"Is_FoodCourtReady", n"OnFoodCourtReady", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_FoodCourtReady(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Ready = false;
        if (ck::IsValid(_RowFoodEntity) && _RowFoodEntity.Is_WorldItem())
        {
            const auto Food = _RowFoodEntity.As_WorldItem();
            Ready = ck::IsValid(Food.Get_HeldItem()) && Food.Get_IsSettled();
        }

        auto Result = OutResult;
        Result.Set(Ready && Get_IsRowPackAndRindReady());
    }

    // The raid's court's pack and Rind, as its rig reads them (the raid and the den found first).
    private bool Get_IsRowPackAndRindReady()
    {
        if ((Get_IsRowRaidFound() && Get_IsRowDenFound()) == false)
        { return false; }

        if (ck::Is_NOT_Valid(_RowPackEntity) || ck::Is_NOT_Valid(_RowCheeseEntity))
        { return false; }

        const auto PackReady = _RowPackEntity.Is_Backpack() && _RowPackEntity.Is_WorldItem()
            && ck::IsValid(_RowPackEntity.As_WorldItem().Get_HeldItem()) && _RowPackEntity.As_Backpack().Get_IsReady();
        const auto CheeseReady = _RowCheeseEntity.Is_WorldItem() && ck::IsValid(_RowCheeseEntity.As_WorldItem().Get_HeldItem())
            && _RowCheeseEntity.As_WorldItem().Get_IsSettled();
        if ((PackReady && CheeseReady) == false)
        { return false; }

        _RowCheeseItem = _RowCheeseEntity.As_WorldItem().Get_HeldItem();
        if (_PackReadyFrame < 0)
        { _PackReadyFrame = int32(utils_time::Get_FrameCounter()); }

        return true;
    }

    UFUNCTION()
    private void OnFoodCourtReady(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _RowFoodItem = _RowFoodEntity.As_WorldItem().Get_HeldItem();
        auto Pack = _RowPackEntity.As_Backpack();
        auto FoodSlot = Pack.Get_CargoSlot(1);
        auto RindSlot = Pack.Get_CargoSlot(2);
        FoodSlot.Request_Stow(FMars_Request_CargoSlot_Stow(_RowFoodItem));
        RindSlot.Request_Stow(FMars_Request_CargoSlot_Stow(_RowCheeseItem));
        WaitUntil(n"Is_FoodCourtStowed", n"OnFoodCourtStowed", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_FoodCourtStowed(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Stowed = false;
        if (ck::IsValid(_RowPackEntity) && _RowPackEntity.Is_Backpack() && _RowPackEntity.Is_WorldItem()
            && ck::IsValid(_RowFoodEntity) && _RowFoodEntity.Is_WorldItem())
        {
            auto Pack = _RowPackEntity.As_Backpack();
            FCk_Handle FoodSlotEntity = Pack.Get_CargoSlot(1);
            const auto Food = _RowFoodEntity.As_WorldItem();
            const auto PackItem = _RowPackEntity.As_WorldItem();
            Stowed = Pack.Get_CargoSlot(1).Get_Item() == _RowFoodItem && Pack.Get_CargoSlot(2).Get_Item() == _RowCheeseItem
                && Food.Get_Mount() == EMars_WorldItem_Mount::Carried && Food.Get_Carrier() == FoodSlotEntity && Food.Get_IsSettled()
                && PackItem.Get_Mount() == EMars_WorldItem_Mount::World && PackItem.Get_IsSettled();
        }

        if (Stowed && _StowedFrame < 0)
        { _StowedFrame = int32(utils_time::Get_FrameCounter()); }

        auto Result = OutResult;
        Result.Set(Stowed);
    }

    UFUNCTION()
    private void OnFoodCourtStowed(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitUntil(n"Is_RowRatOutAndFound", _FoodCourtContinuation, k_SlowPolls);
    }

    //------------------------------------------------------------------------------------------------------------------
    // Server: the born corpse
    //------------------------------------------------------------------------------------------------------------------

    // A born rat's tuning: it watches for a minute before it would turn home.
    protected FMars_PantryRat_Tuning Make_BornTuning()
    {
        auto Tuning = utils_pantry_raid::Make_RatTuning(Make_RowSpec());
        Tuning.Scent.NoTargetReturnSeconds = 60.0f;
        return Tuning;
    }

    // The born rat under the server's raid with InBornThrough, its body built headless and one lethal cleaver blow at
    // its spot pushing it +Y when InWithBlow (the held cleaver as causer; the server must be armed).
    protected void Spawn_ServerBornLootRat(TArray<EMars_PantryRat_Phase> InBornThrough, EMars_NetRatTest_Born InBorn)
    {
        auto Spec = FMars_PantryRat_Spec();
        Spec.Links.Raid = _RowRaid;
        Spec.Links.Den = _RowDen;
        Spec.Links.ResidentSlot = 0;
        Spec.Links.OperationId = k_BornOperationId;
        Spec.Tuning = Make_BornTuning();

        const auto Spot = _DenSpot + k_BornFromDen;
        auto Params = FMars_NetPantryRat_Born_SpawnParams();
        Params.SpawnTransform = FTransform(FRotator::ZeroRotator, Spot);
        Params.Spec = Spec;
        Params.BornThrough = InBornThrough;
        if (InBorn == EMars_NetRatTest_Born::Corpse)
        {
            const auto Item = _Striker.HeldItem.Get_CurrentItem();
            const UMars_ItemTrait_Strike Strike = Item.Get_Strike();
            auto Hit = utils_damage_dealer::Make_Event(_StrikerDealer, Strike.Damage, Strike.DamageType);
            Hit.Source.Causer = Item;
            Hit.Hit.Location = Spot;
            Hit.Hit.Impulse = k_BlowImpulse;
            Params.BuildBodyHeadless = true;
            Params.BornHits.Add(Hit);
        }

        FCk_Handle Owner = _RowRaid;
        Track_ForCleanup(utils_entity_script::Request_SpawnEntity(Owner, UMars_NetPantryRat_Born_EntityScript, Params).Get_EntityUnderConstruction());
        _BornSpawnFrame = int32(utils_time::Get_FrameCounter());
    }

    //------------------------------------------------------------------------------------------------------------------
    // Each machine: sweeping, swinging and claiming at its rat
    //------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    protected void Is_RowRatSweepable(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        Sample_Row();
        auto Result = OutResult;
        Result.Set(Get_IsRowRatSweepable());
    }

    // This machine has found its rat, is armed, and its rat reads Observe and is sweepable.
    UFUNCTION()
    protected void Is_RowRatReadyToStrike(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        Get_IsRowRaidFound();
        Get_IsRowDenFound();
        const auto Found = Get_IsRowRatFound();
        Sample_Row();
        const auto Ready = Found && Get_IsRowRatGone() == false && _RowRat.Get_Phase() == EMars_PantryRat_Phase::Observe
            && Get_IsRowRatSweepable();
        auto Result = OutResult;
        Result.Set(Ready);
    }

    // This machine has found its rat and is armed.
    UFUNCTION()
    protected void Is_RowRatFoundAndArmed(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        Get_IsRowRaidFound();
        Get_IsRowDenFound();
        const auto Found = Get_IsRowRatFound();
        Sample_Row();
        auto Result = OutResult;
        Result.Set(Found && Get_IsStrikerArmed());
    }

    // Armed, a silent sweep from this machine's hand along +Y, as far as the held item reaches, reports a hurtbox of
    // this machine's rat's body zone.
    protected bool Get_IsRowRatSweepable()
    {
        if (Get_IsRowRatGone() || Get_IsStrikerArmed() == false)
        { return false; }

        const UMars_ItemTrait_Strike Strike = _Striker.HeldItem.Get_CurrentItem().Get_Strike();
        const auto Start = Get_StrikerHandLocation();
        auto Settings = FCk_ShapeCast_Settings(
            Start,
            Start + FVector::RightVector * Strike.Reach,
            utils_shapes::Make_Sphere(FCk_ShapeSphere_Dimensions(Strike.Radius)),
            GameplayTag::MakeContainerFromTag(GameplayTags::Probe_Mars_HitZone));
        Settings.Set_OverlapNotifyPolicy(ECk_ProbeResponse_Policy::Silent);
        auto Subject = Get_SubjectEntity();
        const auto Hit = utils_probe_trace::Request_SingleShapeTrace(Subject, Settings);
        return utils_hit_zone::TryGet_Zone(Hit.Get_HitEntity()) == _RowRat.Get_Monster().Get_BodyZone();
    }

    // The strike task's calls from this machine's hand along +Y: the dealer's sweep with the task's template (the
    // held item as causer, +Y at the trait's speed), then, Claimed, the claim of what it found.
    protected void Swing_AtRowRat(EMars_NetRatTest_Swing InSwing)
    {
        auto Subject = Get_SubjectEntity();
        const auto Item = _Striker.HeldItem.Get_CurrentItem();
        const UMars_ItemTrait_Strike Strike = Item.Get_Strike();
        const auto Start = Get_StrikerHandLocation();
        const auto Direction = FVector::RightVector;

        auto Template = utils_damage_dealer::Make_Event(_StrikerDealer, Strike.Damage, Strike.DamageType);
        Template.Source.Causer = Item;
        Template.Hit.Impulse = Direction * Strike.ImpulseSpeed;

        _LootSwingFrame = int32(utils_time::Get_FrameCounter());
        _LootSwingHit = _StrikerDealer.Request_StrikeSweep(FMars_DamageDealer_Sweep(Start, Start + Direction * Strike.Reach, Strike.Radius), Template);
        _LootSwingHitRatZone = _LootSwingHit.Get_HitKind() == ECk_ProbeTrace_HitKind::Probe && Get_IsRowRatGone() == false
            && utils_hit_zone::TryGet_Zone(_LootSwingHit.Get_HitEntity()) == _RowRat.Get_Monster().Get_BodyZone();
        if (InSwing == EMars_NetRatTest_Swing::Claimed)
        { utils_held_item_use::Fire_StrikeCueFor(Subject, FMars_HeldItemUse_Swing(Item, _LootSwingHit, Template.Hit.Impulse)); }
    }

    // A claim straight through the cue: this machine's rat's body zone, InItem, where this machine's rat root stands,
    // normal -Y, impulse +Y.
    protected void Claim_RowRat(UCk_InventoryItem_Definition InItem)
    {
        const auto Address = _RowRat.Get_Monster().Get_BodyZone().Get_Address();
        auto Claim = FMars_HeldItemUse_Strike();
        Claim.ZoneRoot = Address.Root;
        Claim.ZoneIndex = Address.Index;
        Claim.Item = utils_held_item::Make_DefinitionSoft(InItem);
        Claim.Location = _RowRat.Get_Location();
        Claim.Normal = FVector(0.0, -1.0, 0.0);
        Claim.Impulse = FVector(0.0, 1.0, 0.0);
        _LootClaimFrame = int32(utils_time::Get_FrameCounter());
        utils_cue_generic::Request_ExecuteCue(Get_SubjectEntity(), GameplayTags::Cue_Mars_HeldItemUse_Strike, Claim,
            ECk_Cue_ReliabilityPolicy::Reliable, ECk_Cue_MulticastPolicy::ServerOnly);
    }

    //------------------------------------------------------------------------------------------------------------------
    // Each machine: its food and its world items
    //------------------------------------------------------------------------------------------------------------------

    // The World-mode world item of the Mushroom's definition nearest the pack's spot within k_FoodNearPackCm; once
    // found, its mount changes are recorded.
    protected bool Get_IsRowFoodFound()
    {
        if (_RowFoodFoundFrame >= 0)
        { return true; }

        auto Found = FCk_Handle_WorldItem();
        auto Nearest = k_FoodNearPackCm;
        for (auto Candidate : utils_entity_tag::ForEach_Entity(Get_SubjectEntity(), n"TAG_MarsWorldItem"))
        {
            if (Get_IsRowEnding(Candidate) || Candidate.Is_WorldItem() == false)
            { continue; }

            auto WorldItem = Candidate.As_WorldItem();
            if (WorldItem.Get_Mode() != EMars_WorldItem_Mode::World || WorldItem.Get_Definition() != mars_items::Food_Mushroom())
            { continue; }

            const auto Distance = Get_PlanarDistance(Get_RowRootLocation(Candidate), _PackSpot);
            if (Distance >= Nearest)
            { continue; }

            Found = WorldItem;
            Nearest = Distance;
        }

        if (ck::Is_NOT_Valid(Found))
        { return false; }

        _RowFood = Found;
        _RowFoodFoundFrame = int32(utils_time::Get_FrameCounter());
        _RowFood.BindTo_OnMountChanged(FMars_Delegate_WorldItem_OnMountChanged(this, n"OnRowFoodMountChanged"));
        return true;
    }

    protected bool Get_IsRowFoodGone()
    {
        return _RowFoodFoundFrame < 0 || Get_IsRowEnding(_RowFood);
    }

    // The row's food rides this machine's rat on its mouth point.
    protected bool Get_IsRowFoodOnRat()
    {
        if (Get_IsRowFoodGone() || Get_IsRowRatGone())
        { return false; }

        FCk_Handle RatEntity = _RowRat;
        return _RowFood.Get_Mount() == EMars_WorldItem_Mount::Carried && _RowFood.Get_Carrier() == RatEntity
            && _RowFood.Get_MountPoint() == utils_pantry_rat::Get_MouthPoint();
    }

    protected int32 Count_WorldItemsOf(FMars_NetRatTest_ItemQuery InQuery)
    {
        auto Count = 0;
        for (auto Candidate : utils_entity_tag::ForEach_Entity(Get_SubjectEntity(), n"TAG_MarsWorldItem"))
        {
            if (Get_IsWorldItemOf(Candidate, InQuery))
            { Count += 1; }
        }

        return Count;
    }

    // The first of this machine's world items InQuery counts; invalid without one.
    protected FCk_Handle_WorldItem Find_WorldItemOf(FMars_NetRatTest_ItemQuery InQuery)
    {
        for (auto Candidate : utils_entity_tag::ForEach_Entity(Get_SubjectEntity(), n"TAG_MarsWorldItem"))
        {
            if (Get_IsWorldItemOf(Candidate, InQuery))
            { return Candidate.As_WorldItem(); }
        }

        return FCk_Handle_WorldItem();
    }

    private bool Get_IsWorldItemOf(FCk_Handle InCandidate, const FMars_NetRatTest_ItemQuery& InQuery)
    {
        if (Get_IsRowEnding(InCandidate) || InCandidate.Is_WorldItem() == false)
        { return false; }

        const auto WorldItem = InCandidate.As_WorldItem();
        if (WorldItem.Get_Definition() != InQuery.Definition || WorldItem.Get_Mode() != InQuery.Mode)
        { return false; }

        return Get_PlanarDistance(Get_RowRootLocation(InCandidate), InQuery.Near) <= InQuery.Cm;
    }

    protected FMars_NetRatTest_ItemQuery Make_ItemQuery(UCk_InventoryItem_Definition InDefinition, EMars_WorldItem_Mode InMode,
        FVector InNear)
    {
        auto Query = FMars_NetRatTest_ItemQuery();
        Query.Definition = InDefinition;
        Query.Mode = InMode;
        Query.Near = InNear;
        Query.Cm = k_LeftoverNearCm;
        return Query;
    }

    //------------------------------------------------------------------------------------------------------------------
    // Each machine: its rat's pocket, carry and death
    //------------------------------------------------------------------------------------------------------------------

    protected int32 Get_RowPocketCount()
    {
        if (Get_IsRowRatGone() || ck::Is_NOT_Valid(_RowRat.Get_Pocket()))
        { return -1; }

        return _RowRat.Get_Pocket().Get_NumItems();
    }

    // The pocket's sole item; invalid while empty or without a pocket.
    protected FCk_Handle_Item Get_RowPocketItem()
    {
        if (Get_RowPocketCount() <= 0)
        { return FCk_Handle_Item(); }

        return _RowRat.Get_Pocket().Get_SoleItem();
    }

    protected bool Get_IsRowPocketHolding(UCk_InventoryItem_Definition InDefinition)
    {
        const auto Item = Get_RowPocketItem();
        return Get_RowPocketCount() == 1 && ck::IsValid(Item) && Item.Get_Definition() == InDefinition;
    }

    // This machine's rat's carry visual is a live world item of InMode and InDefinition.
    protected bool Get_IsRowCarryVisual(EMars_WorldItem_Mode InMode, UCk_InventoryItem_Definition InDefinition)
    {
        if (Get_IsRowRatGone())
        { return false; }

        const auto Visual = _RowRat.Get_CarryVisual();
        if (Get_IsRowEnding(Visual) || Visual.Is_WorldItem() == false)
        { return false; }

        const auto WorldItem = Visual.As_WorldItem();
        return WorldItem.Get_Mode() == InMode && WorldItem.Get_Definition() == InDefinition;
    }

    protected bool Get_IsRowCarryVisualGone()
    {
        return Get_IsRowRatGone() || Get_IsRowEnding(_RowRat.Get_CarryVisual());
    }

    // The frame of the first change this machine recorded into InPhase; -1 without one.
    protected int32 Get_RatRecordedFrame(EMars_PantryRat_Phase InPhase) const
    {
        for (const auto& Change : _RatChanges)
        {
            if (Change.To == InPhase)
            { return Change.Frame; }
        }

        return -1;
    }

    protected bool Get_IsImpulseNear(FVector InImpulse, FVector InExpected)
    {
        return InImpulse.Equals(InExpected, k_ImpulseTolerance);
    }

    // The side Get_ToppleSide picks for this machine's rat with InImpulse and both sides clear.
    protected EMars_PantryRat_ToppleSide Get_RowRatPushedSide(FVector InImpulse)
    {
        const auto Right = utils_transform::Get_EntityCurrentTransform(_RowRat.As_Transform()).GetRotation().GetRightVector();
        return utils_pantry_rat::Get_ToppleSide(Right, InImpulse, true, true);
    }

    //------------------------------------------------------------------------------------------------------------------
    // Each machine: the samples
    //------------------------------------------------------------------------------------------------------------------

    protected void Sample_Row() override
    {
        Super::Sample_Row();

        if (_TracksFood || Get_IsServer() == false)
        { Get_IsRowFoodFound(); }

        if (_RatFoundFrame < 0 || Get_IsRowRatGone())
        { return; }

        Hook_LootRat();

        if (_HandMode == EMars_NetRatTest_Hand::FollowsRat)
        { utils_transform::Request_SetLocation(_Striker.Hand, FCk_Request_Transform_SetLocation(_RowRat.Get_Location() + k_HandFromRat)); }

        Sample_Carry();
        Sample_Death();
        Sample_Frames();

        const auto Script = Get_RowRatScript();
        if (ck::IsValid(Script) && Script.Get_ToppleSide().IsSet())
        { _ScriptToppleSide = Script.Get_ToppleSide(); }

        if (Get_HasRowRatLedger())
        {
            const auto Ledger = Get_RowRatLedger();
            if (Ledger.Phase == EMars_PantryRat_Phase::DeadHold && _LedgerDeadHoldFrame < 0)
            { _LedgerDeadHoldFrame = int32(utils_time::Get_FrameCounter()); }

            if (Ledger.HitImpulse.IsNearlyZero() == false)
            { _LedgerImpulseSeen = Ledger.HitImpulse; }
        }
    }

    // Once, the first sample after the rat is found: its monster's death with its frame, and on a client every
    // application of its ledger with its impulse.
    private void Hook_LootRat()
    {
        if (_LootRatHooked)
        { return; }

        _LootRatHooked = true;
        auto Monster = _RowRat.Get_Monster();
        Monster.BindTo_OnDied(FMars_Delegate_Monster_OnDied(this, n"OnLootRatDied"));
        if (Get_IsServer())
        { return; }

        FCk_Handle Entity = _RowRat;
        Entity.BindTo_OnRepNotify(FMars_Fragment_PantryRat_Net, FCk_DynamicFragment_OnRepNotify(this, n"OnLootLedgerNotify"));
    }

    // While loaded with a world-item carry visual: the highest distance between that visual's root and where the carry
    // offset puts it on the mouth node.
    private void Sample_Carry()
    {
        const auto Visual = _RowRat.Get_CarryVisual();
        const auto Loot = _RowRat.Get_Loot();
        if (_RowRat.Get_IsLoaded() == false || Get_IsRowEnding(Visual) || Visual.Is_WorldItem() == false || ck::Is_NOT_Valid(Loot)
            || Loot.Has_Presentation() == false)
        { return; }

        const UMars_ItemTrait_Presentation Presentation = Loot.Get_Presentation();
        const auto Mouth = utils_transform::Get_EntityCurrentTransform(_RowRat.Get_MouthNode());
        const auto Expected = (utils_pantry_rat::Get_CarryOffset(Presentation) * Mouth).GetLocation();
        const auto Distance = (Get_RowRootLocation(Visual) - Expected).Size();
        _CarryWorstCm = _CarryWorstCm.IsSet() ? Math::Max(_CarryWorstCm.GetValue(), Distance) : Distance;
    }

    private void Sample_Frames()
    {
        const auto Frame = int32(utils_time::Get_FrameCounter());
        if (_PocketHeldFrame < 0 && ck::IsValid(Get_RowPocketItem()))
        { _PocketHeldFrame = Frame; }

        if (_CarryVisualFrame < 0 && Get_IsRowCarryVisualGone() == false && ck::IsValid(_RowRat.Get_CarryVisual()))
        { _CarryVisualFrame = Frame; }

        if (_FoodOnRatFrame < 0 && Get_IsRowFoodOnRat())
        { _FoodOnRatFrame = Frame; }

        if (_LootDroppedFrame < 0 && _RowRat.Get_IsDead() && ck::IsValid(_RowLootDefinition))
        {
            auto Query = Make_ItemQuery(_RowLootDefinition, EMars_WorldItem_Mode::World, _RowRat.Get_Location());
            Query.Cm = 300.0;
            if (Count_WorldItemsOf(Query) > 0)
            { _LootDroppedFrame = Frame; }
        }
    }

    // The first dead frame (its age on the rat's clock, its impulse, the side it pushes to) and the corpse's fade.
    private void Sample_Death()
    {
        const auto Phase = _RowRat.Get_Phase();
        if (utils_pantry_rat::Get_IsDeadPhase(Phase) && _FirstDeadFrame < 0)
        {
            const auto Death = _RowRat.Get_Death();
            _FirstDeadFrame = int32(utils_time::Get_FrameCounter());
            _FirstDeadAge = _RowRat.Get_Clock() - Death.DiedAt;
            _FirstDeadImpulse = Death.HitImpulse;
            _FirstDeadSide = Get_RowRatPushedSide(Death.HitImpulse);
        }

        if (Phase == EMars_PantryRat_Phase::CorpseFade)
        {
            const auto Fade = _RowRat.Get_FadeAlpha();
            _LowestCorpseFade = _LowestCorpseFade.IsSet() ? Math::Min(_LowestCorpseFade.GetValue(), Fade) : Fade;
            if (Fade < 1.0f)
            { _SawCorpseFadeBelowOne = true; }
        }
    }

    //------------------------------------------------------------------------------------------------------------------
    // The row's log line
    //------------------------------------------------------------------------------------------------------------------

    protected FString Describe_Loot()
    {
        FString Mounts;
        for (const auto& Change : _FoodMounts)
        { Mounts += f"{Change.To :n}@{Change.Frame},"; }

        FString Applications;
        for (const auto& Application : _LootApplications)
        { Applications += f"{Application.Phase :n}[{Application.HitImpulse.ToString()}]@{Application.Frame},"; }

        const auto Carry = _CarryWorstCm.IsSet() ? f"{_CarryWorstCm.GetValue()}" : "unset";
        const auto LowFade = _LowestCorpseFade.IsSet() ? f"{_LowestCorpseFade.GetValue()}" : "unset";
        const auto ScriptSide = _ScriptToppleSide.IsSet() ? f"{_ScriptToppleSide.GetValue() :n}" : "unset";
        const auto DeadSide = _FirstDeadSide.IsSet() ? f"{_FirstDeadSide.GetValue() :n}" : "unset";
        auto Text = f"loot=[carryWorst {Carry} firstDead@{_FirstDeadFrame} age {_FirstDeadAge} impulse [{_FirstDeadImpulse.ToString()}] "
            + f"side {DeadSide} corpseFade {LowFade}/{_SawCorpseFadeBelowOne} scriptSide {ScriptSide} ledgerDeadHold@{_LedgerDeadHoldFrame} "
            + f"ledgerImpulseSeen [{_LedgerImpulseSeen.ToString()}] died@{_LootDiedFrame} dealtWhenDied {_DealtWhenDied} "
            + f"applications [{Applications}] dealt {_StrikerDealt}@{_StrikerDealtFrame} swing@{_LootSwingFrame} "
            + f"swingHitRat {_LootSwingHitRatZone} claim@{_LootClaimFrame} hand {_HandMode :n} pocketHeld@{_PocketHeldFrame} "
            + f"carryVisual@{_CarryVisualFrame} foodOnRat@{_FoodOnRatFrame} lootDropped@{_LootDroppedFrame}";

        if (Get_IsRowRatGone() == false)
        {
            const auto PocketItem = Get_RowPocketItem();
            const auto PocketDef = ck::IsValid(PocketItem) ? PocketItem.Get_Definition().GetName().ToString() : "none";
            const auto Loot = _RowRat.Get_Loot();
            const auto LootDef = ck::IsValid(Loot) ? Loot.Get_Definition().GetName().ToString() : "none";
            const auto Visual = _RowRat.Get_CarryVisual();
            auto VisualText = "none";
            if (Get_IsRowEnding(Visual) == false && Visual.Is_WorldItem())
            {
                const auto VisualItem = Visual.As_WorldItem();
                VisualText = f"{VisualItem.Get_Mode() :n}/{VisualItem.Get_Definition().GetName()}";
            }
            else if (ck::IsValid(Visual))
            { VisualText = "ending"; }

            const auto Death = _RowRat.Get_Death();
            Text += f" pocket {Get_RowPocketCount()}/{PocketDef} lootItem {LootDef} visual {VisualText} "
                + f"ledgerImpulse [{Get_RowRatLedger().HitImpulse.ToString()}] stateImpulse [{Death.HitImpulse.ToString()}] "
                + f"pushed {Get_RowRatPushedSide(Death.HitImpulse) :n} deathSeq {Death.Sequence} release {Death.ReleaseOperationId}/{Death.ReleaseReceipt} "
                + f"diedAt {Death.DiedAt} clock {_RowRat.Get_Clock()}";
        }

        if (Get_IsRowFoodGone() == false)
        {
            FCk_Handle RatEntity = _RowRat;
            const auto Carrier = _RowFood.Get_Carrier();
            auto CarrierText = ck::IsValid(Carrier) ? "other" : "none";
            if (ck::IsValid(Carrier) && Get_IsRowRatGone() == false && Carrier == RatEntity)
            { CarrierText = "rat"; }

            const auto Pickup = _RowFood.Get_Pickup();
            const auto PickupText = ck::IsValid(Pickup) ? f"{Pickup.Get_EnableDisable() :n}" : "none";
            Text += f" food=[found@{_RowFoodFoundFrame} mount {_RowFood.Get_Mount() :n} carrier {CarrierText} point {_RowFood.Get_MountPoint().ToString()} "
                + f"settled {_RowFood.Get_IsSettled()} pickup {PickupText} mounts [{Mounts}]]";
        }
        else
        { Text += f" food=[none mounts [{Mounts}]]"; }

        if (Get_IsServer() && ck::IsValid(_Striker.Use))
        {
            const auto Tally = _Striker.Use.Get_StrikeTally();
            const auto Refusal = Tally.LastRefusal.IsSet() ? f"{Tally.LastRefusal.GetValue() :n}" : FString("none");
            Text += f" tally {Tally.Applied}/{Tally.Refused}/{Refusal}";
        }

        if (Get_IsServer() && ck::IsValid(_RowDen) && Get_IsRowEnding(_RowDen) == false && _RowDen.Get_ResidentCount() > 0)
        { Text += f" denSlot0 {_RowDen.Get_SlotState(0) :n}"; }

        return Text + "]";
    }

    protected void Finish_LootRow(FString InRow, FString InExtra)
    {
        Finish_RatRow(InRow, f"{Describe_Loot()} {InExtra}");
    }

    protected void Hold_LootServerRow(FString InRow, FString InExtra)
    {
        Hold_RatServerRow(InRow, f"{Describe_Loot()} {InExtra}");
    }

    //------------------------------------------------------------------------------------------------------------------
    // Signals
    //------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void OnStrikerDealt(FCk_Handle_DamageDealer InDealer, FCk_Handle_HitZone InZone, FMars_DamageEvent InEvent)
    {
        _StrikerDealt += 1;
        if (_StrikerDealtFrame < 0)
        { _StrikerDealtFrame = int32(utils_time::Get_FrameCounter()); }
    }

    UFUNCTION()
    private void OnLootRatDied(FCk_Handle_Monster InMonster, FMars_DamageEvent InCause)
    {
        if (_LootDiedFrame >= 0)
        { return; }

        _LootDiedFrame = int32(utils_time::Get_FrameCounter());
        _DealtWhenDied = _StrikerDealt;
    }

    UFUNCTION()
    private void OnRowFoodMountChanged(FCk_Handle_WorldItem InWorldItem, EMars_WorldItem_Mount InPrev, EMars_WorldItem_Mount InNew)
    {
        auto Change = FMars_NetRatTest_MountChange();
        Change.To = InNew;
        Change.Frame = int32(utils_time::Get_FrameCounter());
        _FoodMounts.Add(Change);
    }

    // An expected absence: a notify can land on a copy already ending.
    UFUNCTION()
    private void OnLootLedgerNotify(FCk_Handle InHandle, FCk_DynamicFragment_RepNotifyInfo InInfo)
    {
        if (Get_HasRowRatLedger() == false)
        { return; }

        const auto Ledger = Get_RowRatLedger();
        auto Application = FMars_NetRatTest_LootApplication();
        Application.Phase = Ledger.Phase;
        Application.HitImpulse = Ledger.HitImpulse;
        Application.Frame = int32(utils_time::Get_FrameCounter());
        _LootApplications.Add(Application);
    }
}
