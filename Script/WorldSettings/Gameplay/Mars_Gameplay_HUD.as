class AMars_Gameplay_HUD : ACk_HUD_UE
{
    // Soft ref (path only) - ACk_HUD_UE async-loads it at BeginPlay. A hard `assets::load::*` default block-loads at
    // CDO/registration time, which the packaged client can't do safely -> null layout -> no UI.
    default _LayoutConfigAsset = assets::Gameplay_LayoutConfig_Mars_DA();

    protected UCk_UI_PrimaryGameLayout_UE ConstructedLayout;

    UFUNCTION(BlueprintOverride)
    void OnLayoutReady_Event(UCk_UI_PrimaryGameLayout_UE InLayout)
    {
        ConstructedLayout = InLayout;

        auto ControlledPawn = GetOwningPawn();

        if (ck::Is_NOT_Valid(ControlledPawn))
        {
            ck::Warning("[Mars_Gameplay_HUD] OnLayoutReady_Event: Owning pawn is not valid.");
            return;
        }

        utils_owning_actor::Promise_OnActorEcsReady(ControlledPawn, FCk_Delegate_OwningActor_OnEcsReady(this, n"OnPlayerEcsReady"));
    }

    UFUNCTION()
    private void OnPlayerEcsReady(AActor InActor, FCk_Handle InEntity)
    {
        // ValuesReplicated promises may complete after another possession.
        // Never let an older pawn overwrite the HUD context for the committed one.
        if (GetOwningPawn() != InActor)
        { return; }

        utils_context_receiver::TryInjectContextIntoObject(ConstructedLayout, InEntity);
    }
}
