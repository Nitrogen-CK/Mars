// Input actions are asset literals, not runtime NewObject: UPlayerMappableKeySettings::Name is
// BlueprintReadOnly, so script can only write it inside an asset block. A runtime-built action
// can never be rebound.
//
// Input.Scope.Gameplay is declared in Config/DefaultGameplayTags.ini rather than a script tag
// asset - these literals resolve it before script tag assets register.

namespace mars
{
    asset Mars_IA_Move of UCk_Axis2d_InputAction
    {
    }

    asset Mars_IA_Look of UCk_Axis2d_InputAction
    {
    }

    asset Mars_IA_Jump of UCk_Boolean_InputAction
    {
        PlayerMappableKeySettings = NewObject(Mars_IA_Jump, UCk_PlayerMappableKeySettings_UE);
        PlayerMappableKeySettings.Name = n"IA_Jump";
        PlayerMappableKeySettings.DisplayName = NSLOCTEXT("MarsSettingsUI", "KeybindJump", "Jump");
        PlayerMappableKeySettings.DisplayCategory = NSLOCTEXT("MarsSettingsUI", "KeybindCategoryGameplay", "Gameplay");
        Cast<UCk_PlayerMappableKeySettings_UE>(PlayerMappableKeySettings).Set_ScopeTags(GameplayTag::MakeContainerFromTag(GameplayTags::ResolveGameplayTag(n"Input.Scope.Gameplay")));
    }

    asset Mars_IA_Sprint of UCk_Boolean_InputAction
    {
        PlayerMappableKeySettings = NewObject(Mars_IA_Sprint, UCk_PlayerMappableKeySettings_UE);
        PlayerMappableKeySettings.Name = n"IA_Sprint";
        PlayerMappableKeySettings.DisplayName = NSLOCTEXT("MarsSettingsUI", "KeybindSprint", "Sprint");
        PlayerMappableKeySettings.DisplayCategory = NSLOCTEXT("MarsSettingsUI", "KeybindCategoryGameplay", "Gameplay");
        Cast<UCk_PlayerMappableKeySettings_UE>(PlayerMappableKeySettings).Set_ScopeTags(GameplayTag::MakeContainerFromTag(GameplayTags::ResolveGameplayTag(n"Input.Scope.Gameplay")));
    }

    asset Mars_IA_Crouch of UCk_Boolean_InputAction
    {
        PlayerMappableKeySettings = NewObject(Mars_IA_Crouch, UCk_PlayerMappableKeySettings_UE);
        PlayerMappableKeySettings.Name = n"IA_Crouch";
        PlayerMappableKeySettings.DisplayName = NSLOCTEXT("MarsSettingsUI", "KeybindCrouch", "Crouch");
        PlayerMappableKeySettings.DisplayCategory = NSLOCTEXT("MarsSettingsUI", "KeybindCategoryGameplay", "Gameplay");
        Cast<UCk_PlayerMappableKeySettings_UE>(PlayerMappableKeySettings).Set_ScopeTags(GameplayTag::MakeContainerFromTag(GameplayTags::ResolveGameplayTag(n"Input.Scope.Gameplay")));
    }

    asset Mars_IA_Interact_Primary of UCk_Boolean_InputAction
    {
        PlayerMappableKeySettings = NewObject(Mars_IA_Interact_Primary, UCk_PlayerMappableKeySettings_UE);
        PlayerMappableKeySettings.Name = n"IA_Interact_Primary";
        PlayerMappableKeySettings.DisplayName = NSLOCTEXT("MarsSettingsUI", "KeybindPrimary", "Primary Action");
        PlayerMappableKeySettings.DisplayCategory = NSLOCTEXT("MarsSettingsUI", "KeybindCategoryGameplay", "Gameplay");
        Cast<UCk_PlayerMappableKeySettings_UE>(PlayerMappableKeySettings).Set_ScopeTags(GameplayTag::MakeContainerFromTag(GameplayTags::ResolveGameplayTag(n"Input.Scope.Gameplay")));
    }

    asset Mars_IA_Interact_Secondary of UCk_Boolean_InputAction
    {
        PlayerMappableKeySettings = NewObject(Mars_IA_Interact_Secondary, UCk_PlayerMappableKeySettings_UE);
        PlayerMappableKeySettings.Name = n"IA_Interact_Secondary";
        PlayerMappableKeySettings.DisplayName = NSLOCTEXT("MarsSettingsUI", "KeybindSecondary", "Secondary Action");
        PlayerMappableKeySettings.DisplayCategory = NSLOCTEXT("MarsSettingsUI", "KeybindCategoryGameplay", "Gameplay");
        Cast<UCk_PlayerMappableKeySettings_UE>(PlayerMappableKeySettings).Set_ScopeTags(GameplayTag::MakeContainerFromTag(GameplayTags::ResolveGameplayTag(n"Input.Scope.Gameplay")));
    }

    asset Mars_IA_Interact_Use of UCk_Boolean_InputAction
    {
        PlayerMappableKeySettings = NewObject(Mars_IA_Interact_Use, UCk_PlayerMappableKeySettings_UE);
        PlayerMappableKeySettings.Name = n"IA_Interact_Use";
        PlayerMappableKeySettings.DisplayName = NSLOCTEXT("MarsSettingsUI", "KeybindUse", "Interact");
        PlayerMappableKeySettings.DisplayCategory = NSLOCTEXT("MarsSettingsUI", "KeybindCategoryGameplay", "Gameplay");
        Cast<UCk_PlayerMappableKeySettings_UE>(PlayerMappableKeySettings).Set_ScopeTags(GameplayTag::MakeContainerFromTag(GameplayTags::ResolveGameplayTag(n"Input.Scope.Gameplay")));
    }

    // Dev tool - deliberately not player-mappable.
    asset Mars_IA_ToggleDebugger of UCk_Boolean_InputAction
    {
    }

    // CommonUI Back/Confirm (UMars_CommonUIInputData). Mapped per profile when menus exist.
    asset Mars_IA_UI_Back of UCk_Boolean_InputAction
    {
    }

    asset Mars_IA_UI_Confirm of UCk_Boolean_InputAction
    {
    }
}
