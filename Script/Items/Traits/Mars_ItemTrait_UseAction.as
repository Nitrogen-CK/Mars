// What "use" means while this item is held: the state class activates on the Primary channel through a
// no-probe Interactable on the player.
UCLASS(Meta = (DisplayName = "🖐️ Use Action"))
class UMars_ItemTrait_UseAction : UCk_ItemTrait
{
    // Overrides InteractTarget_Enter on the use interaction.
    UPROPERTY()
    TSoftClassPtr<UCk_SmState_EntityScript> UseStateClass;

    // Verb beside the Primary glyph in the action-hint legend ("eat", "swing").
    UPROPERTY()
    FText HintText;

    UPROPERTY()
    ECk_Interaction_CompletionPolicy CompletionPolicy = ECk_Interaction_CompletionPolicy::Instant;

    // Timed only.
    UPROPERTY()
    float32 HoldSeconds = 0.0f;

    // Destroys the item once the use completes (Ration: eat).
    UPROPERTY()
    bool ConsumeOnSuccess = false;
}

mixin bool Has_UseAction(const FCk_Handle_Item& Self)
{
    return Self.Has_ItemTrait(UMars_ItemTrait_UseAction);
}

mixin const UMars_ItemTrait_UseAction Get_UseAction(const FCk_Handle_Item& Self)
{
    return Self.Get_ItemTrait(UMars_ItemTrait_UseAction);
}
