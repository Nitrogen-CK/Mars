// See AMars_Master_GameState for the actor -> entity bridge contract.
UCLASS(NotPlaceable)
class UMars_Master_PlayerController_EntityScript : UCk_EntityScript_WithActor_UE
{
    UFUNCTION(BlueprintOverride)
    ECk_EntityScript_ConstructionFlow DoConstruct(FCk_Handle& InHandle)
    {
        auto Actor = Cast<AMars_Master_PlayerController>(DoGet_Actor());
        if (ck::EnsureIfNot(ck::IsValid(Actor), "[Mars_Master_PlayerController] the entity script's Actor is not a Master PlayerController"))
        { return ECk_EntityScript_ConstructionFlow::Finished; }

        Actor.Request_ComposeEntity(InHandle);
        return ECk_EntityScript_ConstructionFlow::Finished;
    }
}

class AMars_Master_PlayerController : ACk_PlayerController_UE
{
    UPROPERTY(DefaultComponent)
    UCk_EntityBridge_ActorComponent_UE EntityBridge;

    UPROPERTY(DefaultComponent)
    UMars_InputComponent InputComp;

    UPROPERTY(DefaultComponent)
    UMars_PauseMenuComponent PauseMenu;

    protected FCk_Handle ThisActorEntity;

    UFUNCTION(BlueprintOverride)
    void BeginPlay()
    {
        EntityBridge.Request_SpawnLinkedEntity(UMars_Master_PlayerController_EntityScript);

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

    // Called by the entity script while it constructs the entity.
    void Request_ComposeEntity(FCk_Handle InEntity)
    {
        ThisActorEntity = InEntity;
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
        // A same-world possession change closes pause before any profile is re-pointed.
        PauseMenu.ClosePause(EMars_PauseClose::Resume);

        // An unpossess: nothing to do until the next possession.
        if (ck::Is_NOT_Valid(NewPawn))
        {
            if (InputComp.GetProfileCount() > 0)
            { InputComp.RepointPawn(nullptr); }
            return;
        }

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
