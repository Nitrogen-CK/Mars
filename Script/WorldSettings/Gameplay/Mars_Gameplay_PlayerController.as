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
        if (ck::Is_NOT_Valid(ControlledPawn))
        { return; }

        if (InputComp.GetProfileCount() > 0)
        {
            InputComp.RepointPawn(ControlledPawn);
            return;
        }

        PushInputComponent(InputComp);
        InputComp.PushProfile(UMars_InputProfile_Gameplay, this, ControlledPawn);

        InputComp.BindAction(mars::Mars_IA_ToggleDebugger, ETriggerEvent::Started,
            FEnhancedInputActionHandlerDynamicSignature(this, n"OnToggleDebuggerInput"));
    }

    UFUNCTION()
    private void OnToggleDebuggerInput(FInputActionValue ActionValue, float32 ElapsedTime,
        float32 TriggeredTime, const UInputAction SourceAction)
    {
        utils_mars_debugger::Toggle();
    }

    UFUNCTION()
    private void HandlePossessedPawnChanged(APawn OldPawn, APawn NewPawn)
    {
        if (ck::Is_NOT_Valid(NewPawn))
        { return; }

        ActivateGameplayInputs();
    }
}
