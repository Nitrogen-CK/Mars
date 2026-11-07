// The eye swarm's roster: one per world where cosmetics run (UMars_EyeSwarmRoster_Subsystem spawns it; tests spawn their
// own). Every frame it gathers every player character in the world, local and remote, then every entity put on the roster
// with utils_eye_swarm::Add_Watched, takes each one's head and writes the first four into EyeSwarm_Mars_MPC (Player0..3),
// parking the unused slots at the sentinel; the MarsEyeball / MarsEyelid shaders aim every eye from those. Visual only,
// like Mars_StillWater's player-position write: nothing simulates on it, so it is no kernel - no fragment, no request, no
// processor - and it never runs on a dedicated server. A missing collection (before the editor script creates it) only
// skips the write; Get_LastWritten still updates, since script cannot read an MPC back.
UCLASS(NotPlaceable)
class UMars_EyeSwarmRoster_EntityScript : UCk_GenericEntityScript_UE
{
    default _Replication = ECk_Replication::DoesNotReplicate;

    private UMaterialParameterCollection _Mpc;
    private FCk_Handle_Timer _Tick;
    private FCk_Handle _Self;
    private TArray<FVector> _LastWritten;

    UFUNCTION(BlueprintOverride)
    ECk_EntityScript_ConstructionFlow DoConstruct(FCk_Handle& InHandle)
    {
        _Self = InHandle;
        utils_entity_tag::Add(InHandle, utils_eye_swarm::Get_RosterTag());
        _LastWritten = utils_eye_swarm::Pack_PlayerSlots(TArray<FVector>());
        return ECk_EntityScript_ConstructionFlow::Finished;
    }

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (utils_net::Get_CanExecuteCosmeticEvents(InHandle) == false)
        { return; }

        _Mpc = utils_eye_swarm::Load_Mpc();
        _Tick = utils_timer::Create_Tick(InHandle, FCk_Delegate_Timer(this, n"OnTick"));
    }

    UFUNCTION(BlueprintOverride)
    void DoEndPlay(FCk_Handle InHandle)
    {
        if (ck::IsValid(_Tick))
        {
            _Tick.UnbindFrom_OnUpdate(FCk_Delegate_Timer(this, n"OnTick"));
            utils_entity_lifetime::Request_DestroyEntity(_Tick.H());
        }

        _Tick = FCk_Handle_Timer();
    }

    // Player0..Player3 as last packed: the heads in roster order, then the sentinel (utils_eye_swarm::Get_AbsentHead).
    TArray<FVector> Get_LastWritten() const
    {
        return _LastWritten;
    }

    // Whether the collection loaded, i.e. whether Get_LastWritten also reached the shaders.
    bool Get_HasMpc() const
    {
        return ck::IsValid(_Mpc);
    }

    UFUNCTION()
    private void OnTick(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _LastWritten = utils_eye_swarm::Pack_PlayerSlots(Gather_Heads());
        utils_eye_swarm::Write_PlayerSlots(_Mpc, _LastWritten);
    }

    // Player characters first (in world actor order), then watched entities.
    private TArray<FVector> Gather_Heads() const
    {
        auto Heads = TArray<FVector>();

        TArray<AMars_PlayerCharacter> Players;
        GetAllActorsOfClass(Players);
        for (auto Player : Players)
        {
            if (ck::IsValid(Player))
            { Heads.Add(utils_eye_swarm::Get_PlayerHead(Player)); }
        }

        for (auto Watched : utils_entity_tag::ForEach_Entity(_Self, utils_eye_swarm::Get_WatchedTag()))
        {
            if (ck::IsValid(Watched) && utils_transform::Has(Watched))
            { Heads.Add(utils_transform::Get_EntityCurrentLocation(Watched.As_Transform())); }
        }

        return Heads;
    }
}
