// See AMars_Master_GameState for the actor -> entity bridge contract.
class AMars_Master_PlayerController : ACk_PlayerController_UE
{
    protected FCk_Handle ThisActorEntity;

    UFUNCTION(BlueprintOverride)
    void BeginPlay()
    {
        auto PendingEntity = utils_entity_script::Request_SpawnEntity(
            ck::TransientEntity(), UCk_EntityScript_WithActor_UE, FCk_EntityScript_WithActor_SpawnParams(this));

        utils_pending_entity_script::Promise_OnConstructed(
            PendingEntity, FCk_Delegate_EntityScript_Constructed(this, n"OnEntityConstructed"));
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

    // Idempotent: pushes the gameplay profile the first time a chef pawn is controlled; any later possession
    // re-points the existing stack (re-pushing would stack a duplicate IMC). Shared by every mode that possesses
    // an AMars_PlayerCharacter (gameplay, camp; kitchen later).
    protected void TryActivateGameplayInputs(UMars_InputComponent InInputComp, APawn InPawn)
    {
        if (ck::Is_NOT_Valid(InPawn))
        { return; }

        if (InInputComp.GetProfileCount() > 0)
        {
            InInputComp.RepointPawn(InPawn);
            return;
        }

        PushInputComponent(InInputComp);
        InInputComp.PushProfile(UMars_InputProfile_Gameplay, this, InPawn);

        InInputComp.BindAction(mars::Mars_IA_ToggleDebugger, ETriggerEvent::Started,
            FEnhancedInputActionHandlerDynamicSignature(this, n"OnToggleDebuggerInput"));
    }

    UFUNCTION()
    protected void OnToggleDebuggerInput(FInputActionValue ActionValue, float32 ElapsedTime,
        float32 TriggeredTime, const UInputAction SourceAction)
    {
        utils_mars_debugger::Toggle();
    }
}
