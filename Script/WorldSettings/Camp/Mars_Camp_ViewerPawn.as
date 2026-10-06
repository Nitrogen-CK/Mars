// Every player's pawn while the camp is in Lobby. Intentionally no movement component and no input bindings, so
// viewport focus leakage cannot move anything. Its camera carries local menu transitions.
class AMars_Camp_ViewerPawn : APawn
{
    UPROPERTY(DefaultComponent, RootComponent)
    USceneComponent SceneRoot;

    UPROPERTY(DefaultComponent, Attach = SceneRoot)
    UCameraComponent MenuCamera;
    default MenuCamera.FieldOfView = 65.0f;
    default MenuCamera.AspectRatio = 1.7777778f;
    default MenuCamera.bConstrainAspectRatio = true;
}
