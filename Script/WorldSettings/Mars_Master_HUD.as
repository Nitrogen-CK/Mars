// Base HUD for every Mars mode. The HUD's context is the possessed chef's entity: it is injected into the layout once the
// chef's entity is ready, and again on every later possession.
UCLASS(Abstract)
class AMars_Master_HUD : ACk_HUD_UE
{
    protected UCk_UI_PrimaryGameLayout_UE ConstructedLayout;

    UFUNCTION(BlueprintOverride)
    void OnLayoutReady_Event(UCk_UI_PrimaryGameLayout_UE InLayout)
    {
        ConstructedLayout = InLayout;

        auto PC = GetOwningPlayerController();
        if (ck::EnsureIfNot(ck::IsValid(PC), "[Mars_Master_HUD] the layout is ready but the HUD has no owning PlayerController"))
        { return; }

        PC.OnPossessedPawnChanged.AddUFunction(this, n"HandlePossessedPawnChanged");
        TryAwaitChefEntity(GetOwningPawn());
    }

    // Runs before the layout receives InEntity; a mode adds its own widgets here.
    protected void OnChefEntityReady(FCk_Handle InEntity)
    {
    }

    UFUNCTION()
    private void HandlePossessedPawnChanged(APawn OldPawn, APawn NewPawn)
    {
        TryAwaitChefEntity(NewPawn);
    }

    // Only a chef carries the HUD's context. Any other pawn (the camp viewer, or none while unpossessed) waits for the
    // next possession.
    private void TryAwaitChefEntity(APawn InPawn)
    {
        auto Chef = Cast<AMars_PlayerCharacter>(InPawn);
        if (ck::Is_NOT_Valid(Chef))
        { return; }

        utils_owning_actor::Promise_OnActorEcsReady(Chef, FCk_Delegate_OwningActor_OnEcsReady(this, n"OnChefEcsReady"));
    }

    UFUNCTION()
    private void OnChefEcsReady(AActor InActor, FCk_Handle InEntity)
    {
        // ValuesReplicated promises may complete after another possession: never let an older pawn overwrite the context
        // of the committed one.
        if (GetOwningPawn() != InActor)
        { return; }

        OnChefEntityReady(InEntity);
        utils_context_receiver::TryInjectContextIntoObject(ConstructedLayout, InEntity);
    }
}
