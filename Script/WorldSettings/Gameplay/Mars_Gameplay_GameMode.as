// In-dungeon gameplay mode, picked by the Sandbox_Mars_ map prefix (DefaultEngine.ini GameModeMapPrefixes). The
// project-wide GlobalDefaultGameMode is left alone so plugin test levels keep theirs.
class AMars_Gameplay_GameMode : AMars_Master_GameMode
{
    default GameStateClass = AMars_Gameplay_GameState;
    default PlayerControllerClass = AMars_Gameplay_PlayerController;
    default PlayerStateClass = AMars_Gameplay_PlayerState;
    default DefaultPawnClass = AMars_PlayerCharacter;
    default HUDClass = AMars_Gameplay_HUD;
}

class AMars_Gameplay_GameState : AMars_Master_GameState
{
}

class AMars_Gameplay_PlayerState : AMars_Master_PlayerState
{
}
