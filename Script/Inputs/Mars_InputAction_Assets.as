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

    asset Mars_IA_Slot1 of UCk_Boolean_InputAction
    {
        PlayerMappableKeySettings = NewObject(Mars_IA_Slot1, UCk_PlayerMappableKeySettings_UE);
        PlayerMappableKeySettings.Name = n"IA_Slot1";
        PlayerMappableKeySettings.DisplayName = NSLOCTEXT("MarsSettingsUI", "KeybindSlot1", "Slot 1");
        PlayerMappableKeySettings.DisplayCategory = NSLOCTEXT("MarsSettingsUI", "KeybindCategoryGameplay", "Gameplay");
        Cast<UCk_PlayerMappableKeySettings_UE>(PlayerMappableKeySettings).Set_ScopeTags(GameplayTag::MakeContainerFromTag(GameplayTags::ResolveGameplayTag(n"Input.Scope.Gameplay")));
    }

    asset Mars_IA_Slot2 of UCk_Boolean_InputAction
    {
        PlayerMappableKeySettings = NewObject(Mars_IA_Slot2, UCk_PlayerMappableKeySettings_UE);
        PlayerMappableKeySettings.Name = n"IA_Slot2";
        PlayerMappableKeySettings.DisplayName = NSLOCTEXT("MarsSettingsUI", "KeybindSlot2", "Slot 2");
        PlayerMappableKeySettings.DisplayCategory = NSLOCTEXT("MarsSettingsUI", "KeybindCategoryGameplay", "Gameplay");
        Cast<UCk_PlayerMappableKeySettings_UE>(PlayerMappableKeySettings).Set_ScopeTags(GameplayTag::MakeContainerFromTag(GameplayTags::ResolveGameplayTag(n"Input.Scope.Gameplay")));
    }

    asset Mars_IA_Slot3 of UCk_Boolean_InputAction
    {
        PlayerMappableKeySettings = NewObject(Mars_IA_Slot3, UCk_PlayerMappableKeySettings_UE);
        PlayerMappableKeySettings.Name = n"IA_Slot3";
        PlayerMappableKeySettings.DisplayName = NSLOCTEXT("MarsSettingsUI", "KeybindSlot3", "Slot 3");
        PlayerMappableKeySettings.DisplayCategory = NSLOCTEXT("MarsSettingsUI", "KeybindCategoryGameplay", "Gameplay");
        Cast<UCk_PlayerMappableKeySettings_UE>(PlayerMappableKeySettings).Set_ScopeTags(GameplayTag::MakeContainerFromTag(GameplayTags::ResolveGameplayTag(n"Input.Scope.Gameplay")));
    }

    asset Mars_IA_Slot4 of UCk_Boolean_InputAction
    {
        PlayerMappableKeySettings = NewObject(Mars_IA_Slot4, UCk_PlayerMappableKeySettings_UE);
        PlayerMappableKeySettings.Name = n"IA_Slot4";
        PlayerMappableKeySettings.DisplayName = NSLOCTEXT("MarsSettingsUI", "KeybindSlot4", "Slot 4");
        PlayerMappableKeySettings.DisplayCategory = NSLOCTEXT("MarsSettingsUI", "KeybindCategoryGameplay", "Gameplay");
        Cast<UCk_PlayerMappableKeySettings_UE>(PlayerMappableKeySettings).Set_ScopeTags(GameplayTag::MakeContainerFromTag(GameplayTags::ResolveGameplayTag(n"Input.Scope.Gameplay")));
    }

    asset Mars_IA_Drop of UCk_Boolean_InputAction
    {
        PlayerMappableKeySettings = NewObject(Mars_IA_Drop, UCk_PlayerMappableKeySettings_UE);
        PlayerMappableKeySettings.Name = n"IA_Drop";
        PlayerMappableKeySettings.DisplayName = NSLOCTEXT("MarsSettingsUI", "KeybindDrop", "Drop / Throw");
        PlayerMappableKeySettings.DisplayCategory = NSLOCTEXT("MarsSettingsUI", "KeybindCategoryGameplay", "Gameplay");
        Cast<UCk_PlayerMappableKeySettings_UE>(PlayerMappableKeySettings).Set_ScopeTags(GameplayTag::MakeContainerFromTag(GameplayTags::ResolveGameplayTag(n"Input.Scope.Gameplay")));
    }

    // Leaves a station (and later: backs out of other gameplay modes).
    asset Mars_IA_Back of UCk_Boolean_InputAction
    {
        PlayerMappableKeySettings = NewObject(Mars_IA_Back, UCk_PlayerMappableKeySettings_UE);
        PlayerMappableKeySettings.Name = n"IA_Back";
        PlayerMappableKeySettings.DisplayName = NSLOCTEXT("MarsSettingsUI", "KeybindBack", "Back / Leave");
        PlayerMappableKeySettings.DisplayCategory = NSLOCTEXT("MarsSettingsUI", "KeybindCategoryGameplay", "Gameplay");
        Cast<UCk_PlayerMappableKeySettings_UE>(PlayerMappableKeySettings).Set_ScopeTags(GameplayTag::MakeContainerFromTag(GameplayTags::ResolveGameplayTag(n"Input.Scope.Gameplay")));
    }

    // Held: the wheel stays open while the key is down; the release chooses.
    asset Mars_IA_EmoteWheel of UCk_Boolean_InputAction
    {
        PlayerMappableKeySettings = NewObject(Mars_IA_EmoteWheel, UCk_PlayerMappableKeySettings_UE);
        PlayerMappableKeySettings.Name = n"IA_EmoteWheel";
        PlayerMappableKeySettings.DisplayName = NSLOCTEXT("MarsSettingsUI", "KeybindEmoteWheel", "Emote Wheel (hold)");
        PlayerMappableKeySettings.DisplayCategory = NSLOCTEXT("MarsSettingsUI", "KeybindCategoryEmotes", "Emotes");
        Cast<UCk_PlayerMappableKeySettings_UE>(PlayerMappableKeySettings).Set_ScopeTags(GameplayTag::MakeContainerFromTag(GameplayTags::ResolveGameplayTag(n"Input.Scope.Gameplay")));
    }

    asset Mars_IA_Emote_Wave of UCk_Boolean_InputAction
    {
        PlayerMappableKeySettings = NewObject(Mars_IA_Emote_Wave, UCk_PlayerMappableKeySettings_UE);
        PlayerMappableKeySettings.Name = n"IA_Emote_Wave";
        PlayerMappableKeySettings.DisplayName = NSLOCTEXT("MarsSettingsUI", "KeybindEmoteWave", "Emote: Wave");
        PlayerMappableKeySettings.DisplayCategory = NSLOCTEXT("MarsSettingsUI", "KeybindCategoryEmotes", "Emotes");
        Cast<UCk_PlayerMappableKeySettings_UE>(PlayerMappableKeySettings).Set_ScopeTags(GameplayTag::MakeContainerFromTag(GameplayTags::ResolveGameplayTag(n"Input.Scope.Gameplay")));
    }

    asset Mars_IA_Emote_ThumbsUp of UCk_Boolean_InputAction
    {
        PlayerMappableKeySettings = NewObject(Mars_IA_Emote_ThumbsUp, UCk_PlayerMappableKeySettings_UE);
        PlayerMappableKeySettings.Name = n"IA_Emote_ThumbsUp";
        PlayerMappableKeySettings.DisplayName = NSLOCTEXT("MarsSettingsUI", "KeybindEmoteThumbsUp", "Emote: Thumbs Up");
        PlayerMappableKeySettings.DisplayCategory = NSLOCTEXT("MarsSettingsUI", "KeybindCategoryEmotes", "Emotes");
        Cast<UCk_PlayerMappableKeySettings_UE>(PlayerMappableKeySettings).Set_ScopeTags(GameplayTag::MakeContainerFromTag(GameplayTags::ResolveGameplayTag(n"Input.Scope.Gameplay")));
    }

    asset Mars_IA_Emote_Point of UCk_Boolean_InputAction
    {
        PlayerMappableKeySettings = NewObject(Mars_IA_Emote_Point, UCk_PlayerMappableKeySettings_UE);
        PlayerMappableKeySettings.Name = n"IA_Emote_Point";
        PlayerMappableKeySettings.DisplayName = NSLOCTEXT("MarsSettingsUI", "KeybindEmotePoint", "Emote: Point");
        PlayerMappableKeySettings.DisplayCategory = NSLOCTEXT("MarsSettingsUI", "KeybindCategoryEmotes", "Emotes");
        Cast<UCk_PlayerMappableKeySettings_UE>(PlayerMappableKeySettings).Set_ScopeTags(GameplayTag::MakeContainerFromTag(GameplayTags::ResolveGameplayTag(n"Input.Scope.Gameplay")));
    }

    asset Mars_IA_Emote_Clap of UCk_Boolean_InputAction
    {
        PlayerMappableKeySettings = NewObject(Mars_IA_Emote_Clap, UCk_PlayerMappableKeySettings_UE);
        PlayerMappableKeySettings.Name = n"IA_Emote_Clap";
        PlayerMappableKeySettings.DisplayName = NSLOCTEXT("MarsSettingsUI", "KeybindEmoteClap", "Emote: Clap");
        PlayerMappableKeySettings.DisplayCategory = NSLOCTEXT("MarsSettingsUI", "KeybindCategoryEmotes", "Emotes");
        Cast<UCk_PlayerMappableKeySettings_UE>(PlayerMappableKeySettings).Set_ScopeTags(GameplayTag::MakeContainerFromTag(GameplayTags::ResolveGameplayTag(n"Input.Scope.Gameplay")));
    }

    asset Mars_IA_Emote_FlipOff of UCk_Boolean_InputAction
    {
        PlayerMappableKeySettings = NewObject(Mars_IA_Emote_FlipOff, UCk_PlayerMappableKeySettings_UE);
        PlayerMappableKeySettings.Name = n"IA_Emote_FlipOff";
        PlayerMappableKeySettings.DisplayName = NSLOCTEXT("MarsSettingsUI", "KeybindEmoteFlipOff", "Emote: Middle Finger");
        PlayerMappableKeySettings.DisplayCategory = NSLOCTEXT("MarsSettingsUI", "KeybindCategoryEmotes", "Emotes");
        Cast<UCk_PlayerMappableKeySettings_UE>(PlayerMappableKeySettings).Set_ScopeTags(GameplayTag::MakeContainerFromTag(GameplayTags::ResolveGameplayTag(n"Input.Scope.Gameplay")));
    }

    // An axis like Move/Look: a wheel tick is pressed and released inside one frame, which a polled
    // level row can miss. Not player-mappable.
    asset Mars_IA_CycleSlot of UCk_Axis1d_InputAction
    {
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
