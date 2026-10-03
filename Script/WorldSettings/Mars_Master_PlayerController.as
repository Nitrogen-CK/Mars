// See AMars_Master_GameState for the actor -> entity bridge contract.
class AMars_Master_PlayerController : ACk_PlayerController_UE
{
    UPROPERTY(DefaultComponent)
    UMars_InputComponent InputComp;

    protected FCk_Handle ThisActorEntity;

    UFUNCTION(BlueprintOverride)
    void BeginPlay()
    {
        auto PendingEntity = utils_entity_script::Request_SpawnEntity(
            ck::TransientEntity(), UCk_EntityScript_WithActor_UE, FCk_EntityScript_WithActor_SpawnParams(this));

        utils_pending_entity_script::Promise_OnConstructed(
            PendingEntity, FCk_Delegate_EntityScript_Constructed(this, n"OnEntityConstructed"));

        if (IsLocalController() == false)
        { return; }

        OnPossessedPawnChanged.AddUFunction(this, n"HandlePossessedPawnChanged");

        // PIE possesses the local pawn before BeginPlay, standalone after it: replay the first case here, the handler
        // covers the second.
        if (ck::IsValid(ControlledPawn))
        { OnLocalPawnPossessed(ControlledPawn); }
    }

    UFUNCTION()
    UMars_InputComponent Get_InputStack() const
    {
        return InputComp;
    }

    UFUNCTION()
    private void OnEntityConstructed(FCk_Handle_EntityScript InEntityScriptHandle)
    {
        ThisActorEntity = InEntityScriptHandle;
        utils_handle::Set_DebugName(ThisActorEntity, n"PlayerController");
        EcsConstructionScript(ThisActorEntity);
    }

    UFUNCTION(BlueprintEvent)
    protected void EcsConstructionScript(FCk_Handle InEntity)
    {
    }

    // The local controller possessed InPawn (never null).
    protected void OnLocalPawnPossessed(APawn InPawn)
    {
    }

    UFUNCTION()
    private void HandlePossessedPawnChanged(APawn OldPawn, APawn NewPawn)
    {
        // An unpossess: nothing to do until the next possession.
        if (ck::Is_NOT_Valid(NewPawn))
        { return; }

        OnLocalPawnPossessed(NewPawn);
    }

    // Idempotent: pushes the gameplay profile the first time a chef pawn is controlled; any later possession re-points
    // the existing stack (re-pushing would stack a duplicate IMC). Shared by every mode that possesses an
    // AMars_PlayerCharacter.
    protected void TryActivateGameplayInputs(APawn InPawn)
    {
        if (ck::Is_NOT_Valid(InPawn))
        { return; }

        if (InputComp.GetProfileCount() > 0)
        {
            InputComp.RepointPawn(InPawn);
            return;
        }

        PushInputComponent(InputComp);
        InputComp.PushProfile(UMars_InputProfile_Gameplay, InPawn);

        InputComp.BindAction(mars::Mars_IA_ToggleDebugger, ETriggerEvent::Started,
            FEnhancedInputActionHandlerDynamicSignature(this, n"OnToggleDebuggerInput"));
    }

    UFUNCTION()
    protected void OnToggleDebuggerInput(FInputActionValue ActionValue, float32 ElapsedTime,
        float32 TriggeredTime, const UInputAction SourceAction)
    {
        utils_mars_debugger::Toggle();
    }
}
