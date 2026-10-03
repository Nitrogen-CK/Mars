class AMars_Gameplay_HUD : AMars_Master_HUD
{
    // Soft ref (path only) - ACk_HUD_UE async-loads it at BeginPlay. A hard `assets::load::*` default block-loads at
    // CDO/registration time, which the packaged client can't do safely -> null layout -> no UI.
    default _LayoutConfigAsset = assets::Gameplay_LayoutConfig_Mars_DA();
}
