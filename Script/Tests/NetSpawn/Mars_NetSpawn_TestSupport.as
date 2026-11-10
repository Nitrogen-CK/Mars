// Test support for the replicated-spawn tests: a script that never finishes its construction, and three
// marker-less processors that execute a spawn order in a chosen pass of the frame, so no test depends on which pass a
// timer continuation happens to land in. A marker-less processor is never pumped: it runs once per frame, in the main
// pass of its group, at the position its declared edge gives it.
// - forced M: before the framework's spawn processor, so the spawn executes in the script group's main pass;
// - forced B: after the framework's begin-play processor in the same group, so the spawn executes in the group's settle;
// - forced T: in FGroup_Replication, after the script group, so the spawn executes in the end-of-frame tail pump.
// A test stamps an order fragment on any entity (the subject, an anchor) from a continuation; the processor executes it
// and removes it.

namespace utils_net_spawn_test
{
    // The live measurement carrier on InAny's machine with InPayload, skipping entities being torn down.
    FCk_Handle Find_Spike(const FCk_Handle& InAny, int32 InPayload)
    {
        for (auto Candidate : utils_entity_tag::ForEach_Entity(InAny, constants_net_spike::k_Tag))
        {
            if (utils_entity_lifetime::Get_IsPendingDestroy(Candidate, ECk_EntityLifetime_DestructionPhase::BeginDestroy))
            { continue; }

            if (Candidate.Has_Fragment(FMars_Fragment_NetSpike_Local) == false)
            { continue; }

            if (Candidate.Get_Fragment(FMars_Fragment_NetSpike_Local).Payload == InPayload)
            { return Candidate; }
        }

        return FCk_Handle();
    }

    // How a test line spells the host's replication state of InEntity.
    FString Get_HostState(const FCk_Handle& InEntity)
    {
        if (ck::Is_NOT_Valid(InEntity))
        { return "absent"; }

        if (utils_entity_replication_driver::Has(InEntity) == false)
        { return "noDriver"; }

        return utils_entity_replication_driver::Get_IsReplicationComplete(InEntity) ? "complete" : "notComplete";
    }

    bool Get_IsComplete(const FCk_Handle& InEntity)
    {
        return ck::IsValid(InEntity) && utils_entity_replication_driver::Has(InEntity)
            && utils_entity_replication_driver::Get_IsReplicationComplete(InEntity);
    }
}

//--------------------------------------------------------------------------------------------------------------------------
// A script that never finishes its construction
//--------------------------------------------------------------------------------------------------------------------------

namespace constants_net_spawn_test
{
    const FName k_NeverFinishesTag = n"TAG_MarsTestNetSpawnNeverFinishes";
}

// Returns Continue from DoConstruct and never finishes its construction, so it is never replicated: the cause the
// host-side check names as "never finished its construction".
class UMars_TESTONLY_NetSpawn_NeverFinishes_EntityScript : UCk_GenericEntityScript_UE
{
    default _ShowInPlaceActors = false;
    // Stance A by declaration (spawned under the replicated spawn owner); it never replicates because it never finishes.
    default _Replication = ECk_Replication::Replicates;

    UFUNCTION(BlueprintOverride)
    ECk_EntityScript_ConstructionFlow DoConstruct(FCk_Handle& InHandle)
    {
        utils_entity_tag::Add(InHandle, constants_net_spawn_test::k_NeverFinishesTag);
        return ECk_EntityScript_ConstructionFlow::Continue;
    }
}

//--------------------------------------------------------------------------------------------------------------------------
// Forced-pass spawn orders
//--------------------------------------------------------------------------------------------------------------------------

enum EMars_TESTONLY_NetSpawn_OrderKind
{
    // A measurement carrier that requests one Replicates child in its own DoConstruct.
    LegacyParent,
    // A flagless measurement carrier, checked with utils_net_spawn::Expect_Replicated.
    PlainSpawn,
    // A UMars_Shortcut_EntityScript (gate and lever).
    Shortcut,
    // A World-mode rock through the world-item funnel, for nobody (the transient entity), so under the replicated spawn
    // owner; the funnel stamps the check itself. The order's Owner is not read.
    WorldItem
}

enum EMars_TESTONLY_NetSpawn_OrderOwner
{
    // The entity carrying the order.
    Carrier,
    // The replicated spawn owner of the carrier's world.
    SpawnOwner
}

struct FMars_TESTONLY_NetSpawn_Order
{
    UPROPERTY()
    EMars_TESTONLY_NetSpawn_OrderKind Kind = EMars_TESTONLY_NetSpawn_OrderKind::LegacyParent;

    UPROPERTY()
    EMars_TESTONLY_NetSpawn_OrderOwner Owner = EMars_TESTONLY_NetSpawn_OrderOwner::SpawnOwner;

    UPROPERTY()
    int32 Payload = 0;

    UPROPERTY()
    FVector Location = FVector::ZeroVector;

    FMars_TESTONLY_NetSpawn_Order() {}

    FMars_TESTONLY_NetSpawn_Order(EMars_TESTONLY_NetSpawn_OrderKind InKind, EMars_TESTONLY_NetSpawn_OrderOwner InOwner, int32 InPayload)
    {
        Kind = InKind;
        Owner = InOwner;
        Payload = InPayload;
    }
}

struct FMars_TESTONLY_NetSpawn_OrdersAtMain
{
    UPROPERTY()
    TArray<FMars_TESTONLY_NetSpawn_Order> Orders;
}

struct FMars_TESTONLY_NetSpawn_OrdersAtSettle
{
    UPROPERTY()
    TArray<FMars_TESTONLY_NetSpawn_Order> Orders;
}

struct FMars_TESTONLY_NetSpawn_OrdersAtTail
{
    UPROPERTY()
    TArray<FMars_TESTONLY_NetSpawn_Order> Orders;
}

// A resolve the anchor drain must execute in the main pass: stamped on the anchor, issued by a processor ordered before
// the anchor drain.
struct FMars_TESTONLY_NetSpawn_ResolveAtMain
{
    UPROPERTY()
    FMars_Request_Anchor_Resolve Request;
}

namespace utils_net_spawn_test
{
    // The transient entity of InAny's world (what ck::TransientEntity() names), reached through InAny's lifetime chain: a
    // processor has no implicit world.
    FCk_Handle Get_TransientEntity(const FCk_Handle& InAny)
    {
        auto Entity = InAny;
        while (ck::IsValid(Entity) && utils_entity_lifetime::Get_IsTransientEntity(Entity) == false)
        { Entity = utils_entity_lifetime::Get_LifetimeOwner(Entity); }

        return Entity;
    }

    void Add_OrderAtMain(FCk_Handle& InCarrier, const FMars_TESTONLY_NetSpawn_Order& InOrder)
    { InCarrier.AddOrGet_Fragment(FMars_TESTONLY_NetSpawn_OrdersAtMain).Orders.Add(InOrder); }

    void Add_OrderAtSettle(FCk_Handle& InCarrier, const FMars_TESTONLY_NetSpawn_Order& InOrder)
    { InCarrier.AddOrGet_Fragment(FMars_TESTONLY_NetSpawn_OrdersAtSettle).Orders.Add(InOrder); }

    void Add_OrderAtTail(FCk_Handle& InCarrier, const FMars_TESTONLY_NetSpawn_Order& InOrder)
    { InCarrier.AddOrGet_Fragment(FMars_TESTONLY_NetSpawn_OrdersAtTail).Orders.Add(InOrder); }

    void Execute(FCk_Handle& InCarrier, const TArray<FMars_TESTONLY_NetSpawn_Order>& InOrders)
    {
        for (const auto& Order : InOrders)
        {
            auto Owner = InCarrier;
            if (Order.Owner == EMars_TESTONLY_NetSpawn_OrderOwner::SpawnOwner)
            { Owner = utils_mars_net::Get_ReplicatedSpawnOwner(InCarrier); }

            if (ck::EnsureIfNot(ck::IsValid(Owner), f"[NetSpawnTest] order {Order.Payload} has no owner on [{InCarrier.ToString()}]"))
            { continue; }

            switch (Order.Kind)
            {
                case EMars_TESTONLY_NetSpawn_OrderKind::LegacyParent:
                {
                    auto Params = FMars_NetSpike_SpawnParams(Order.Location, Order.Payload);
                    Params.ChildInConstruct = true;
                    utils_entity_script::Request_SpawnEntity(Owner, UMars_NetSpike_EntityScript, Params);
                    break;
                }
                case EMars_TESTONLY_NetSpawn_OrderKind::PlainSpawn:
                {
                    auto Params = FMars_NetSpike_SpawnParams(Order.Location, Order.Payload);
                    auto Entity = utils_entity_script::Request_SpawnEntity(Owner, UMars_NetSpike_EntityScript, Params).Get_EntityUnderConstruction();
                    utils_net_spawn::Expect_Replicated(Entity);
                    break;
                }
                case EMars_TESTONLY_NetSpawn_OrderKind::Shortcut:
                {
                    auto Params = UMars_Shortcut_EntityScript::Params();
                    Params.SpawnTransform = FTransform(FRotator::ZeroRotator, Order.Location);
                    Params.Channel = GameplayTags::ResolveGameplayTag(n"Mechanism.Channel.Anchor.Test.A");
                    auto Entity = utils_entity_script::Request_SpawnEntity(Owner, UMars_Shortcut_EntityScript, Params).Get_EntityUnderConstruction();
                    utils_net_spawn::Expect_Replicated(Entity);
                    break;
                }
                case EMars_TESTONLY_NetSpawn_OrderKind::WorldItem:
                {
                    auto Nobody = Get_TransientEntity(InCarrier);
                    auto Spec = FMars_WorldItem_WorldSpec(utils_held_item::Make_DefinitionSoft(mars_items::Rock()), FTransform(FRotator::ZeroRotator, Order.Location));
                    utils_world_item::Request_SpawnWorld(Nobody, Spec);
                    break;
                }
            }
        }
    }
}

class UMars_TESTONLY_Processor_NetSpawn_ForceAtMain : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _RunBefore.Add(n"FProcessor_EntityScript_SpawnEntity_HandleRequests");

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle, FMars_TESTONLY_NetSpawn_OrdersAtMain& InOrders)
    {
        const auto Orders = InOrders.Orders;
        // InOrders is invalid past this line.
        InHandle.Request_TryRemove(FMars_TESTONLY_NetSpawn_OrdersAtMain);
        utils_net_spawn_test::Execute(InHandle, Orders);
    }
}

class UMars_TESTONLY_Processor_NetSpawn_ForceAtSettle : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _RunAfter.Add(n"FProcessor_EntityScript_BeginPlay");

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle, FMars_TESTONLY_NetSpawn_OrdersAtSettle& InOrders)
    {
        const auto Orders = InOrders.Orders;
        // InOrders is invalid past this line.
        InHandle.Request_TryRemove(FMars_TESTONLY_NetSpawn_OrdersAtSettle);
        utils_net_spawn_test::Execute(InHandle, Orders);
    }
}

class UMars_TESTONLY_Processor_NetSpawn_ForceAtTail : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Replication";

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle, FMars_TESTONLY_NetSpawn_OrdersAtTail& InOrders)
    {
        const auto Orders = InOrders.Orders;
        // InOrders is invalid past this line.
        InHandle.Request_TryRemove(FMars_TESTONLY_NetSpawn_OrdersAtTail);
        utils_net_spawn_test::Execute(InHandle, Orders);
    }
}

class UMars_TESTONLY_Processor_NetSpawn_ResolveAtMain : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _RunBefore.Add(n"/Script/Angelscript.Mars_Processor_Anchor_HandleRequests");

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle, FMars_TESTONLY_NetSpawn_ResolveAtMain& InResolve)
    {
        const auto Request = InResolve.Request;
        // InResolve is invalid past this line.
        InHandle.Request_TryRemove(FMars_TESTONLY_NetSpawn_ResolveAtMain);
        auto Anchor = InHandle.As_Anchor();
        Anchor.Request_Resolve(Request);
    }
}
