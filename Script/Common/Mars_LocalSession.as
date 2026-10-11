namespace utils_local_session
{
    // The one network fence of the combat layer: a world this machine alone plays in. Never a client, never a dedicated
    // server. A listen server that later accepts a join keeps its already-composed combat local: nothing in it replicates.
    bool Get_IsLocalCombatWorld(UWorld InWorld)
    {
        if (ck::Is_NOT_Valid(InWorld))
        { return false; }

        const auto Mode = InWorld.GetNetMode();
        return Mode == ENetMode::NM_Standalone || Mode == ENetMode::NM_ListenServer;
    }
}
