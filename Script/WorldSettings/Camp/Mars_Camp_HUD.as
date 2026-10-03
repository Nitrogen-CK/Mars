// Camp HUD: the camp layout. When the local player possesses a chef, the gameplay HUD widget is pushed on the Game layer
// with the chef's entity as context and the Menu layer is cleared. Soft ref: ACk_HUD_UE async-loads the layout at
// BeginPlay.
class AMars_Camp_HUD : AMars_Master_HUD
{
    default _LayoutConfigAsset = assets::Camp_LayoutConfig_Mars_DA();

    // Set once the push succeeds; a later chef's entity is injected into the same widget.
    private UCommonActivatableWidget _GameplayHud;

    protected void OnChefEntityReady(FCk_Handle InEntity) override
    {
        if (ck::Is_NOT_Valid(_GameplayHud))
        {
            auto PC = GetOwningPlayerController();
            utils_u_i_layout::ClearLayer(PC, GameplayTags::ResolveGameplayTag(n"UI.Layer.Menu"));

            auto HudClass = System::LoadClassAsset_Blocking(assets::Gameplay_HUD_Mars_WBP_Class());
            _GameplayHud = utils_u_i_layout::PushWidgetToLayer(PC, GameplayTags::ResolveGameplayTag(n"UI.Layer.Game"), HudClass);
            if (ck::EnsureIfNot(ck::IsValid(_GameplayHud), "[Mars_Camp_HUD] failed to push the gameplay HUD widget"))
            { return; }
        }

        utils_context_receiver::TryInjectContextIntoObject(_GameplayHud, InEntity);
    }
}
