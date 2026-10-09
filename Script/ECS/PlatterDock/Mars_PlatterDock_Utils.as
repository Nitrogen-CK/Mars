// Stateless accept predicate for every dock inventory, bound from the CDO (the cargo slot's shape). Only the inventory's own
// guard: the dock's policy is evaluated by the request drain, since a CDO delegate has no dock to read.
UCLASS()
class UMars_PlatterDock_AcceptPolicy : UObject
{
    UFUNCTION()
    void OnCanAccept(FCk_Handle_Inventory InInventory, FCk_Handle_Item InItem, bool& OutCanAccept)
    { OutCanAccept = InItem.Has_Platter() && InItem.Has_PersistentWorldItem(); }
}

namespace utils_platter_dock
{
    // A scene-node child of the station root at MountLocal carrying the dock: a capacity-1 Inventory.Mars.Dock.<Role>
    // inventory (accept policy CDO), the node published as AttachPoint.Mars.Dock (the dock is the carrier a docked platter
    // mounts on) and a probe interactable with one Use target running UMars_SmState_PlatterDock_Interact. The scene-node
    // Create makes the dock a lifetime child of the station root, so it dies with the station.
    FCk_Handle_PlatterDock Create(FCk_Handle_Transform& InStationRoot, FMars_PlatterDock_Spec InSpec)
    {
        const auto Validation = InSpec.Validate();
        if (ck::EnsureIfNot(Validation.IsValid(), f"[PlatterDock] [{InStationRoot.ToString()}] rejected the spec: {Validation.Get_Error()}"))
        { return FCk_Handle_PlatterDock(); }

        auto Node = utils_scene_node::Create(InStationRoot, InSpec.MountLocal).As_Transform();

        TSubclassOf<UMars_PlatterDock_AcceptPolicy> PolicyClass = UMars_PlatterDock_AcceptPolicy;
        auto Policy = PolicyClass.GetDefaultObject();

        const auto InventoryTag = InSpec.Role == EMars_PlatterDock_Role::Input
            ? GameplayTags::Inventory_Mars_Dock_Input
            : GameplayTags::Inventory_Mars_Dock_Output;

        auto InventoryParams = utils_inventory_data_only::Make_Params_Bounded(InventoryTag, 1,
            FCk_Delegate_Inventory_CustomCanAcceptItem_Dynamic(Policy, n"OnCanAccept"),
            FCk_Delegate_Inventory_CustomCanStackItems_Dynamic());
        InventoryParams.Set_StackingPolicy(ECk_Inventory_StackingPolicy::NoStacking);
        InventoryParams.Set_PersistContents(ECk_EnableDisable::Disable);

        FCk_Handle DockEntity = Node;
        auto Inventory = utils_inventory_data_only::Add(DockEntity, InventoryParams, ECk_Replication::DoesNotReplicate);

        auto AttachPointsSpec = FMars_AttachPoints_Spec();
        AttachPointsSpec.Points.Add(FMars_AttachPoint_Entry(GameplayTags::AttachPoint_Mars_Dock, Node));
        utils_attach_points::Add(DockEntity, AttachPointsSpec);

        auto Params = FMars_Fragment_PlatterDock_Params();
        Params.Spec = InSpec;

        auto State = FMars_Fragment_PlatterDock();
        State.Inventory = Inventory;
        State.Interactable = DoCreate_Interactable(Node, InSpec.ProbeRadius);
        State.Node = Node;

        Node.Add_Fragment(FMars_Feature_PlatterDock());
        Node.Add_Fragment(Params);
        Node.Add_Fragment(State);
        return DockEntity.As_PlatterDock();
    }

    // The dock with InRole that Create made on InStation (a lifetime child of the station root); invalid when there is none.
    FCk_Handle_PlatterDock Find_OnStation(FCk_Handle InStation, EMars_PlatterDock_Role InRole)
    {
        for (auto Dependent : utils_entity_lifetime::Get_LifetimeDependents(InStation))
        {
            if (ck::IsValid(Dependent) && Dependent.Is_PlatterDock() && Dependent.As_PlatterDock().Get_Role() == InRole)
            { return Dependent.As_PlatterDock(); }
        }

        return FCk_Handle_PlatterDock();
    }

    // The platter riding InItem's Persistent world item; invalid when InItem is not a platter's item.
    FCk_Handle_Platter TryGet_PlatterOf(const FCk_Handle_Item& InItem)
    {
        if (ck::Is_NOT_Valid(InItem) || InItem.Has_PersistentWorldItem() == false)
        { return FCk_Handle_Platter(); }

        FCk_Handle WorldItemEntity = InItem.Get_PersistentWorldItem();
        if (ck::Is_NOT_Valid(WorldItemEntity))
        { return FCk_Handle_Platter(); }

        return WorldItemEntity.As_Platter(ECk_SanityCheck::UnChecked);
    }

    // What InPolicy says to InPlatter as it is now; unset = it may dock. Pure: no transfer, no dock. Checked in order
    // MustBeEmpty / MustHaveFood, TooMany, NotWhole, KindRejected (Occupied is the dock's, not the policy's).
    TOptional<EMars_PlatterDock_Refusal> Get_Refusal(const FMars_PlatterDock_Policy& InPolicy, const FCk_Handle_Platter& InPlatter)
    {
        if (InPolicy.RequireEmpty.IsSet())
        {
            const auto HeldCount = InPlatter.Get_HeldCount();
            if (InPolicy.RequireEmpty.GetValue() && HeldCount > 0)
            { return TOptional<EMars_PlatterDock_Refusal>(EMars_PlatterDock_Refusal::MustBeEmpty); }

            if (InPolicy.RequireEmpty.GetValue() == false && HeldCount == 0)
            { return TOptional<EMars_PlatterDock_Refusal>(EMars_PlatterDock_Refusal::MustHaveFood); }
        }

        if (InPolicy.MaxPieces.IsSet() && InPlatter.Get_Occupancy() > InPolicy.MaxPieces.GetValue())
        { return TOptional<EMars_PlatterDock_Refusal>(EMars_PlatterDock_Refusal::TooMany); }

        if (InPolicy.WholeOnly && InPlatter.Get_IsWhole() == false)
        { return TOptional<EMars_PlatterDock_Refusal>(EMars_PlatterDock_Refusal::NotWhole); }

        if (InPolicy.Kind.IsEmpty() == false)
        {
            for (const auto& Piece : InPlatter.Get_Held())
            {
                if (InPolicy.Kind.Matches(Piece.Get_Kind()) == false)
                { return TOptional<EMars_PlatterDock_Refusal>(EMars_PlatterDock_Refusal::KindRejected); }
            }
        }

        return TOptional<EMars_PlatterDock_Refusal>();
    }

    // The dock's Name for Place / Take; InRefusal is the policy's reason for Blocked_Policy (the Kind refusal reads the
    // dock's KindRejectedText); the other Blocked_ texts are fixed.
    FText Get_PromptText(EMars_PlatterDock_Action InAction, const FMars_PlatterDock_Spec& InSpec, TOptional<EMars_PlatterDock_Refusal> InRefusal)
    {
        const auto Name = InSpec.Name.ToString();

        if (InAction == EMars_PlatterDock_Action::Place)
        { return FText::FromString(f"Place on {Name}"); }

        if (InAction == EMars_PlatterDock_Action::Take)
        { return FText::FromString(f"Take {Name}"); }

        if (InAction == EMars_PlatterDock_Action::Blocked_NothingHeld)
        { return FText::FromString("Nothing to place"); }

        if (InAction == EMars_PlatterDock_Action::Blocked_NotAPlatter)
        { return FText::FromString("Not a platter"); }

        if (InAction == EMars_PlatterDock_Action::Blocked_HandsFull)
        { return utils_interactable::Get_HandsFullText(); }

        return Get_RefusalText(InSpec, InRefusal);
    }

    // The Blocked_Policy reason.
    FText Get_RefusalText(const FMars_PlatterDock_Spec& InSpec, TOptional<EMars_PlatterDock_Refusal> InRefusal)
    {
        if (InRefusal == EMars_PlatterDock_Refusal::KindRejected)
        { return InSpec.KindRejectedText.IsEmpty() ? FText::FromString("Not this food") : InSpec.KindRejectedText; }

        if (InRefusal == EMars_PlatterDock_Refusal::NotWhole)
        { return FText::FromString("Whole pieces only"); }

        if (InRefusal == EMars_PlatterDock_Refusal::TooMany)
        { return FText::FromString("Too many pieces"); }

        if (InRefusal == EMars_PlatterDock_Refusal::MustBeEmpty)
        { return FText::FromString("Must be empty"); }

        if (InRefusal == EMars_PlatterDock_Refusal::MustHaveFood)
        { return FText::FromString("Needs food"); }

        return FText::FromString("Can't place that");
    }

    // The probe carries Probe.Mars.Interact (the player's interaction trace only sees probes under that tag) and is
    // Kinematic: it follows the station. The prompt text is a placeholder until UMars_Processor_PlatterDock_Prompt writes
    // the focuser's action.
    FCk_Handle_Interactable DoCreate_Interactable(FCk_Handle_Transform& InNode, float32 InProbeRadius)
    {
        auto Probe = FMars_Interactable_ProbeInfo();
        Probe.ProbeSpec = FCk_Probe_Spec(GameplayTags::Probe_Mars_Interact);
        Probe.ProbeSpec.Set_MotionType(ECk_MotionType::Kinematic);
        Probe.ProbeShape = utils_shapes::Make_Sphere(FCk_ShapeSphere_Dimensions(InProbeRadius));
        Probe.ProbeOffset = FTransform::Identity;

        auto TargetSpec = FCk_InteractTarget_Spec(GameplayTags::InteractionChannel_Mars_Use);
        TargetSpec.Set_CompletionPolicy(ECk_Interaction_CompletionPolicy::Instant);

        auto Prompt = FMars_InteractPrompt_Spec();
        Prompt.InputAction = mars::Mars_IA_Interact_Use;
        Prompt.PromptText = FText::FromString("Dock");

        auto Target = FMars_Interactable_TargetEntry();
        Target.InteractTargetSpec = TargetSpec;
        Target.InteractPromptSpec = Prompt;
        Target.InteractionStateClass = UMars_SmState_PlatterDock_Interact;

        auto Spec = FMars_Interactable_Spec();
        Spec.ProbeInfo = Probe;
        Spec.Targets.Add(Target);
        Spec.FocusPriority = constants_platter_dock::k_FocusPriority;

        return utils_interactable::Create(InNode, Spec);
    }
}

//--------------------------------------------------------------------------------------------------------------------------
// Getters
//--------------------------------------------------------------------------------------------------------------------------

mixin FMars_PlatterDock_Spec Get_Spec(const FCk_Handle_PlatterDock& Self)
{
    return Self.Get_Fragment(FMars_Fragment_PlatterDock_Params).Spec;
}

mixin EMars_PlatterDock_Role Get_Role(const FCk_Handle_PlatterDock& Self)
{
    return Self.Get_Fragment(FMars_Fragment_PlatterDock_Params).Spec.Role;
}

// The node a docked platter's root is attached to (the dock entity itself).
mixin FCk_Handle_Transform Get_Node(const FCk_Handle_PlatterDock& Self)
{
    return Self.Get_Fragment(FMars_Fragment_PlatterDock).Node;
}

mixin FCk_Handle_Inventory_DataOnly Get_Inventory(const FCk_Handle_PlatterDock& Self)
{
    return Self.Get_Fragment(FMars_Fragment_PlatterDock).Inventory;
}

mixin FCk_Handle_Interactable Get_Interactable(const FCk_Handle_PlatterDock& Self)
{
    return Self.Get_Fragment(FMars_Fragment_PlatterDock).Interactable;
}

// Invalid while the dock is empty.
mixin FCk_Handle_Item Get_Item(const FCk_Handle_PlatterDock& Self)
{
    const auto Inventory = Self.Get_Inventory();
    return Inventory.Get_SoleItem();
}

mixin bool Get_IsOccupied(const FCk_Handle_PlatterDock& Self)
{
    return ck::IsValid(Self.Get_Item());
}

// The docked platter's world item; invalid while the dock is empty (as of the last sync pass).
mixin FCk_Handle_WorldItem Get_WorldItem(const FCk_Handle_PlatterDock& Self)
{
    return Self.Get_Fragment(FMars_Fragment_PlatterDock).WorldItem;
}

// The docked platter; invalid while the dock is empty (as of the last sync pass).
mixin FCk_Handle_Platter Get_Platter(const FCk_Handle_PlatterDock& Self)
{
    return Self.Get_Fragment(FMars_Fragment_PlatterDock).Platter;
}

// What interacting would do for InFocuser, first matching row wins:
//   any dock,  no HeldItem + Hotbar on the focuser           -> Blocked_NothingHeld
//   occupied,  the focuser's overflow slot is free            -> Take
//   occupied,  the overflow slot is taken                     -> Blocked_HandsFull
//   empty,     hands empty                                    -> Blocked_NothingHeld
//   empty,     holds an item that is not a platter            -> Blocked_NotAPlatter
//   empty,     holds a platter the policy refuses             -> Blocked_Policy (TryGet_Refusal says why)
//   empty,     holds a platter                                -> Place
// "Hands empty" = the focuser's HeldItem has no current item.
mixin EMars_PlatterDock_Action Get_ActionFor(const FCk_Handle_PlatterDock& Self, FCk_Handle InFocuser)
{
    const auto HeldItem = InFocuser.As_HeldItem(ECk_SanityCheck::UnChecked);
    const auto Hotbar = InFocuser.As_Hotbar(ECk_SanityCheck::UnChecked);
    if (ck::Is_NOT_Valid(HeldItem) || ck::Is_NOT_Valid(Hotbar))
    { return EMars_PlatterDock_Action::Blocked_NothingHeld; }

    if (Self.Get_IsOccupied())
    { return Hotbar.Get_IsOverflowOccupied() ? EMars_PlatterDock_Action::Blocked_HandsFull : EMars_PlatterDock_Action::Take; }

    const auto Held = HeldItem.Get_CurrentItem();
    if (ck::Is_NOT_Valid(Held))
    { return EMars_PlatterDock_Action::Blocked_NothingHeld; }

    const auto Platter = utils_platter_dock::TryGet_PlatterOf(Held);
    if (ck::Is_NOT_Valid(Platter))
    { return EMars_PlatterDock_Action::Blocked_NotAPlatter; }

    const auto Refusal = utils_platter_dock::Get_Refusal(Self.Get_Spec().Policy, Platter);
    return Refusal.IsSet() ? EMars_PlatterDock_Action::Blocked_Policy : EMars_PlatterDock_Action::Place;
}

// The policy's refusal of the platter InFocuser holds; unset when it holds no platter or the policy lets it dock.
mixin TOptional<EMars_PlatterDock_Refusal> TryGet_Refusal(const FCk_Handle_PlatterDock& Self, FCk_Handle InFocuser)
{
    const auto HeldItem = InFocuser.As_HeldItem(ECk_SanityCheck::UnChecked);
    if (ck::Is_NOT_Valid(HeldItem))
    { return TOptional<EMars_PlatterDock_Refusal>(); }

    const auto Platter = utils_platter_dock::TryGet_PlatterOf(HeldItem.Get_CurrentItem());
    if (ck::Is_NOT_Valid(Platter))
    { return TOptional<EMars_PlatterDock_Refusal>(); }

    return utils_platter_dock::Get_Refusal(Self.Get_Spec().Policy, Platter);
}

//--------------------------------------------------------------------------------------------------------------------------
// Requests
//--------------------------------------------------------------------------------------------------------------------------

mixin void Request_Dock(FCk_Handle_PlatterDock& Self, const FMars_Request_PlatterDock_Dock& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_PlatterDock_Requests);
    Requests.DockRequests.Add(InRequest);
}

mixin void Request_Undock(FCk_Handle_PlatterDock& Self, const FMars_Request_PlatterDock_Undock& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_PlatterDock_Requests);
    Requests.UndockRequests.Add(InRequest);
}

//--------------------------------------------------------------------------------------------------------------------------
// Signal Binding
//--------------------------------------------------------------------------------------------------------------------------

mixin void BindTo_OnDocked(FCk_Handle_PlatterDock& Self, FMars_Delegate_PlatterDock_OnDocked InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_PlatterDock_Signals);
    Fragment.OnDocked.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnDocked(FCk_Handle_PlatterDock& Self, FMars_Delegate_PlatterDock_OnDocked InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_PlatterDock_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_PlatterDock_Signals).OnDocked.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void BindTo_OnUndocked(FCk_Handle_PlatterDock& Self, FMars_Delegate_PlatterDock_OnUndocked InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_PlatterDock_Signals);
    Fragment.OnUndocked.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnUndocked(FCk_Handle_PlatterDock& Self, FMars_Delegate_PlatterDock_OnUndocked InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_PlatterDock_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_PlatterDock_Signals).OnUndocked.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void BindTo_OnDockRefused(FCk_Handle_PlatterDock& Self, FMars_Delegate_PlatterDock_OnDockRefused InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_PlatterDock_Signals);
    Fragment.OnDockRefused.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnDockRefused(FCk_Handle_PlatterDock& Self, FMars_Delegate_PlatterDock_OnDockRefused InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_PlatterDock_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_PlatterDock_Signals).OnDockRefused.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}
