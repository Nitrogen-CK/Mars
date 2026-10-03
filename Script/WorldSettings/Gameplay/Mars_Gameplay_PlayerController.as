class AMars_Gameplay_PlayerController : AMars_Master_PlayerController
{
    default CheatClass = UMars_Gameplay_CheatManager;

    UFUNCTION(BlueprintOverride)
    void BeginPlay()
    {
        Super::BeginPlay();

        if (IsLocalController() == false)
        { return; }

        Widget::SetInputMode_GameOnly(this);
        bShowMouseCursor = false;
    }

    protected void OnLocalPawnPossessed(APawn InPawn) override
    {
        TryActivateGameplayInputs(InPawn);
    }
}
