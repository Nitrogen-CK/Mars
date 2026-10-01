// Camp HUD: the camp layout (menu layer starting widget arrives in Phase 3). When the local player possesses a chef,
// the gameplay HUD widget is pushed on the Game layer with the chef's entity as context and the Menu layer is cleared
// (design D6). Soft ref: ACk_HUD_UE async-loads the layout at BeginPlay.
class AMars_Camp_HUD : ACk_HUD_UE
{
    default _LayoutConfigAsset = assets::Camp_LayoutConfig_Mars_DA();

    protected UCk_UI_PrimaryGameLayout_UE ConstructedLayout;
    private bool _GameplayHudRequested = false;

    UFUNCTION(BlueprintOverride)
    void OnLayoutReady_Event(UCk_UI_PrimaryGameLayout_UE InLayout)
    {
        ConstructedLayout = InLayout;

        auto PC = GetOwningPlayerController();
        if (ck::Is_NOT_Valid(PC))
        { return; }

        PC.OnPossessedPawnChanged.AddUFunction(this, n"HandlePossessedPawnChanged");
        TryShowGameplayHud(GetOwningPawn());
    }

    UFUNCTION()
    private void HandlePossessedPawnChanged(APawn OldPawn, APawn NewPawn)
    { TryShowGameplayHud(NewPawn); }

    private void TryShowGameplayHud(APawn InPawn)
    {
        if (_GameplayHudRequested || ck::Is_NOT_Valid(ConstructedLayout))
        { return; }

        auto Chef = Cast<AMars_PlayerCharacter>(InPawn);
        if (ck::Is_NOT_Valid(Chef))
        { return; }

        _GameplayHudRequested = true;
        utils_owning_actor::Promise_OnActorEcsReady(Chef, FCk_Delegate_OwningActor_OnEcsReady(this, n"OnChefEcsReady"));
    }

    UFUNCTION()
    private void OnChefEcsReady(AActor InActor, FCk_Handle InEntity)
    {
        if (GetOwningPawn() != InActor)
        { return; }

        auto PC = GetOwningPlayerController();
        utils_u_i_layout::ClearLayer(PC, GameplayTags::ResolveGameplayTag(n"UI.Layer.Menu"));

        auto HudClass = System::LoadClassAsset_Blocking(assets::Gameplay_HUD_Mars_WBP_Class());
        auto Widget = utils_u_i_layout::PushWidgetToLayer(PC, GameplayTags::ResolveGameplayTag(n"UI.Layer.Game"), HudClass);
        if (ck::EnsureIfNot(ck::IsValid(Widget), "[Mars_Camp_HUD] failed to push the gameplay HUD widget"))
        { return; }

        utils_context_receiver::TryInjectContextIntoObject(Widget, InEntity);
        utils_context_receiver::TryInjectContextIntoObject(ConstructedLayout, InEntity);
    }
}
