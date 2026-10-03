// Every player's pawn while the camp is in Lobby. Intentionally no movement component and no input bindings, so
// viewport focus leakage cannot move anything; the view is a station camera, not this pawn.
class AMars_Camp_ViewerPawn : APawn
{
    UPROPERTY(DefaultComponent, RootComponent)
    USceneComponent SceneRoot;
}
