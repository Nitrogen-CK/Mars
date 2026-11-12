// What one dock of a station is built from: the kernel's spec, its prompt's words and its marker's name.
struct FMars_PlatterDock_Setup
{
    UPROPERTY()
    FMars_PlatterDock_Spec Spec;

    UPROPERTY()
    FMars_PlatterDock_PromptWords Words;

    UPROPERTY()
    FName MarkerName;
}

// A station's dock setups, kept on its root by utils_platter_dock::Request_Docks: local, the same on every machine.
struct FMars_Fragment_PlatterDock_Setups
{
    UPROPERTY()
    TArray<FMars_PlatterDock_Setup> Setups;
}

// The dock script's spawn params (its ExposeOnSpawn field): a client's placeholder is matched to the replicated dock by its
// role.
struct FMars_PlatterDock_SpawnParams
{
    UPROPERTY()
    EMars_PlatterDock_Role Role = EMars_PlatterDock_Role::Input;

    FMars_PlatterDock_SpawnParams() {}

    FMars_PlatterDock_SpawnParams(EMars_PlatterDock_Role InRole)
    {
        Role = InRole;
    }
}

// One dock of a station: a lifetime child of the station, attached under the station root at its mount, composing the
// whole dock on itself (utils_platter_dock::Add) from the setup its station keeps for Role. Requested only by
// utils_platter_dock::Request_Docks. A copy without authority can arrive before its station has stored its setups there:
// it then waits for them before it composes (Continue flow), and ends if the station ends first. It inherits its station's
// context.
class UMars_PlatterDock_EntityScript : UCk_GenericEntityScript_UE
{
    // Stance A: replicates with its station; the authority builds it and a client's request is the placeholder it resolves
    // to, so its inventory replicates through a driver of its own. Its transform is local: every machine attaches it under
    // its own copy of the station root.
    default _Replication = ECk_Replication::Replicates;

    UPROPERTY(ExposeOnSpawn)
    EMars_PlatterDock_Role Role = EMars_PlatterDock_Role::Input;

    private FCk_Handle _Self;
    private FCk_Handle_Timer _WaitTimer;

    UFUNCTION(BlueprintOverride)
    ECk_EntityScript_ConstructionFlow DoConstruct(FCk_Handle& InHandle)
    {
        _Self = InHandle;
        if (Get_IsMisplaced(InHandle))
        { return ECk_EntityScript_ConstructionFlow::Finished; }

        const auto Owner = utils_entity_lifetime::Get_LifetimeOwner(InHandle);
        if (ck::IsValid(Owner) && Owner.Has_Fragment(FMars_Fragment_PlatterDock_Setups))
        {
            Compose(InHandle);
            return ECk_EntityScript_ConstructionFlow::Finished;
        }

        _WaitTimer = utils_timer::Create_Tick(InHandle, FCk_Delegate_Timer(this, n"OnWaitForSetups"));
        return ECk_EntityScript_ConstructionFlow::Continue;
    }

    // A copy without authority: composes once its station has its setups; a station that ends first takes the dock with it.
    UFUNCTION()
    private void OnWaitForSetups(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Owner = utils_entity_lifetime::Get_LifetimeOwner(_Self);
        const auto HasSetups = ck::IsValid(Owner) && Owner.Has_Fragment(FMars_Fragment_PlatterDock_Setups);
        if (ck::IsValid(Owner) && HasSetups == false)
        { return; }

        utils_timer::UnbindFrom_OnUpdate(_WaitTimer, FCk_Delegate_Timer(this, n"OnWaitForSetups"));
        utils_entity_lifetime::Request_DestroyEntity(_WaitTimer.H());
        _WaitTimer = FCk_Handle_Timer();

        if (HasSetups == false)
        {
            utils_entity_lifetime::Request_DestroyEntity(_Self);
            return;
        }

        if (Compose(_Self))
        { DoFinishConstruction(); }
    }

    // False when the dock could not compose; it is then destroyed.
    private bool Compose(FCk_Handle& InHandle)
    {
        FCk_Handle Station = utils_entity_lifetime::Get_LifetimeOwner(InHandle);
        const auto MaybeSetup = utils_platter_dock::TryGet_Setup(Station, Role);
        if (ck::EnsureIfNot(MaybeSetup.IsSet(),
            f"[PlatterDock] Dock [{Role :n}] [{InHandle.ToString()}] has no setup on its station [{Station.ToString()}]. Destroyed."))
        {
            utils_entity_lifetime::Request_DestroyEntity(InHandle);
            return false;
        }

        const auto Setup = MaybeSetup.GetValue();
        auto Spec = Setup.Spec;
        Spec.Replication = _Replication;

        auto StationRoot = Station.As_Transform();
        const auto StationWorld = utils_transform::Get_EntityCurrentTransform(StationRoot);
        auto Root = utils_transform::Add(InHandle, Spec.MountLocal * StationWorld, ECk_Replication::DoesNotReplicate);
        utils_scene_node::Add(Root, StationRoot, Spec.MountLocal);
        utils_handle::Set_DebugName(InHandle, FName(f"Station.PlatterDock.{Role :n}"));
        utils_entity_tag::Add(InHandle, n"TAG_MarsPlatterDock");

        // A rejected spec already ensured in utils_platter_dock::Add.
        auto Dock = utils_platter_dock::Add(InHandle, Spec);
        if (ck::Is_NOT_Valid(Dock))
        {
            utils_entity_lifetime::Request_DestroyEntity(InHandle);
            return false;
        }

        utils_platter_dock::Add_Prompt(Dock, Setup.Words);
        Dock.Add_Marker(this, Setup.MarkerName);
        return true;
    }

    // Authority and game worlds only (an editor preview world has no net). Each guard ensures once and destroys the dock,
    // which leaves its station without that dock rather than holding one whose contents never reach the other machines.
    private bool Get_IsMisplaced(FCk_Handle& InHandle) const
    {
        const UWorld EntityWorld = utils_entity_lifetime::Get_WorldForEntity(InHandle);
        if (ck::Is_NOT_Valid(EntityWorld) || EntityWorld.IsGameWorld() == false || utils_net::Get_HasAuthority(InHandle) == false)
        { return false; }

        const auto Owner = utils_entity_lifetime::Get_LifetimeOwner(InHandle);
        const auto OwnerHasDriver = ck::IsValid(Owner) && utils_entity_replication_driver::Has(Owner);
        const auto Replicates = _Replication == ECk_Replication::Replicates;

        if (ck::EnsureIfNot(utils_platter_dock::TryGet_Setup(Owner, Role).IsSet(),
            f"[PlatterDock] Dock [{Role :n}] [{InHandle.ToString()}] is under [{Owner.ToString()}], which has no setup for it: "
            + "request docks through utils_platter_dock::Request_Docks. Destroyed."))
        {
            utils_entity_lifetime::Request_DestroyEntity(InHandle);
            return true;
        }

        if (ck::EnsureIfNot(Replicates == false || OwnerHasDriver,
            f"[PlatterDock] Dock [{Role :n}] [{InHandle.ToString()}] is the replicated dock class under [{Owner.ToString()}], "
            + "which has no replication driver: its inventory cannot create an item. Destroyed."))
        {
            utils_entity_lifetime::Request_DestroyEntity(InHandle);
            return true;
        }

        if (ck::EnsureIfNot(Replicates || OwnerHasDriver == false,
            f"[PlatterDock] Dock [{Role :n}] [{InHandle.ToString()}] is the local dock class under [{Owner.ToString()}], which "
            + "has a replication driver: its contents would never reach the other machines. Destroyed."))
        {
            utils_entity_lifetime::Request_DestroyEntity(InHandle);
            return true;
        }

        return false;
    }
}

// The dock for a station with no replication driver (a single-machine rig, a station under a driverless owner): the same
// dock, local on its one machine.
class UMars_PlatterDock_Local_EntityScript : UMars_PlatterDock_EntityScript
{
    // Stance D: a driverless station replicates nothing, so neither does its dock.
    default _Replication = ECk_Replication::DoesNotReplicate;
}

namespace utils_platter_dock
{
    // Stores InSetups on InStation, then requests one dock script per setup under it, on every machine: the replicated class
    // where the station replicates (the authority builds it and stamps the host-side check; a client's request is the
    // placeholder the replicated dock resolves to), else the local twin. Each dock composes on a later pass.
    void Request_Docks(FCk_Handle& InStation, const TArray<FMars_PlatterDock_Setup>& InSetups)
    {
        auto Setups = FMars_Fragment_PlatterDock_Setups();
        Setups.Setups = InSetups;
        InStation.Add_Fragment(Setups);

        const auto Replicates = utils_mars_net::Get_ReplicatesHere(InStation);
        const auto IsAuthority = utils_net::Get_HasAuthority(InStation);
        TSubclassOf<UMars_PlatterDock_EntityScript> DockClass = UMars_PlatterDock_EntityScript;
        if (Replicates == false)
        { DockClass = UMars_PlatterDock_Local_EntityScript; }

        for (const auto& Setup : InSetups)
        {
            auto Pending = utils_entity_script::Request_SpawnEntity(InStation, DockClass, FMars_PlatterDock_SpawnParams(Setup.Spec.Role));
            if (Replicates && IsAuthority)
            {
                auto Dock = Pending.Get_EntityUnderConstruction();
                utils_net_spawn::Expect_Replicated(Dock);
            }
        }
    }

    // Every dock InStation's setups name has composed (Find_OnStation finds its role); false while it has no setups.
    bool Get_AreDocksComposed(const FCk_Handle& InStation)
    {
        if (ck::Is_NOT_Valid(InStation) || InStation.Has_Fragment(FMars_Fragment_PlatterDock_Setups) == false)
        { return false; }

        for (const auto& Setup : InStation.Get_Fragment(FMars_Fragment_PlatterDock_Setups).Setups)
        {
            if (ck::Is_NOT_Valid(Find_OnStation(InStation, Setup.Spec.Role)))
            { return false; }
        }

        return true;
    }

    // InStation's setup for the dock with InRole; unset when it has none.
    TOptional<FMars_PlatterDock_Setup> TryGet_Setup(const FCk_Handle& InStation, EMars_PlatterDock_Role InRole)
    {
        if (ck::Is_NOT_Valid(InStation) || InStation.Has_Fragment(FMars_Fragment_PlatterDock_Setups) == false)
        { return TOptional<FMars_PlatterDock_Setup>(); }

        for (const auto& Setup : InStation.Get_Fragment(FMars_Fragment_PlatterDock_Setups).Setups)
        {
            if (Setup.Spec.Role == InRole)
            { return TOptional<FMars_PlatterDock_Setup>(Setup); }
        }

        return TOptional<FMars_PlatterDock_Setup>();
    }
}
