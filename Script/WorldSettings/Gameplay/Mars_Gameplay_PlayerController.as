class AMars_Gameplay_PlayerController : AMars_Master_PlayerController
{
    default CheatClass = UMars_Gameplay_CheatManager;

    UPROPERTY(DefaultComponent)
    UMars_InputComponent InputComp;

    UFUNCTION(BlueprintOverride)
    void BeginPlay()
    {
        Super::BeginPlay();

        if (IsLocalController() == false)
        { return; }

        OnPossessedPawnChanged.AddUFunction(this, n"HandlePossessedPawnChanged");
        ActivateGameplayInputs();

        Widget::SetInputMode_GameOnly(this);
        bShowMouseCursor = false;
    }

    UFUNCTION()
    UMars_InputComponent Get_InputStack() const
    {
        return InputComp;
    }

    // Idempotent: pushes the gameplay profile the first time a pawn is controlled; any later
    // possession re-points the existing stack (re-pushing would stack a duplicate IMC).
    private void ActivateGameplayInputs()
    {
        TryActivateGameplayInputs(InputComp, ControlledPawn);
    }

    UFUNCTION()
    private void HandlePossessedPawnChanged(APawn OldPawn, APawn NewPawn)
    {
        if (ck::Is_NOT_Valid(NewPawn))
        { return; }

        ActivateGameplayInputs();
    }
}
