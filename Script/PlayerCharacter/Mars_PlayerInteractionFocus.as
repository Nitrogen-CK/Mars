// The interactable the player is looking at, written by UMars_SmTask_InteractionFocus whenever focus changes. For
// presentation (the first-person gloves lean toward it); gameplay still goes through the interaction resolver.
struct FMars_Fragment_PlayerInteractionFocus
{
    UPROPERTY()
    FCk_Handle_Interactable Focused;
}

namespace mars_interaction_focus
{
    void Set(FCk_Handle& InPlayer, const FCk_Handle_Interactable& InFocused)
    {
        auto& Fragment = InPlayer.AddOrGet_Fragment(FMars_Fragment_PlayerInteractionFocus);
        Fragment.Focused = InFocused;
    }

    // Invalid when nothing is focused.
    FCk_Handle_Interactable Get(const FCk_Handle& InPlayer)
    {
        if (InPlayer.Has_Fragment(FMars_Fragment_PlayerInteractionFocus) == false)
        { return FCk_Handle_Interactable(); }

        return InPlayer.Get_Fragment(FMars_Fragment_PlayerInteractionFocus).Focused;
    }
}
