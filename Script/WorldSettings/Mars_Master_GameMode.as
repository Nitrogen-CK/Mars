// Base game mode shared by every Mars mode. Leaves override the class slots; this layer holds what all of them agree on.
UCLASS(Abstract)
class AMars_Master_GameMode : ACk_GameMode_UE
{
    default GameStateClass = AMars_Master_GameState;
    default PlayerControllerClass = AMars_Master_PlayerController;
    default PlayerStateClass = AMars_Master_PlayerState;
    default bUseSeamlessTravel = true;
}
