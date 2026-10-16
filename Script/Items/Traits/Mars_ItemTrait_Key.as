// A key: opens a lock whose AcceptedKey is KeyId (utils_key_lock). Which colour it is drawn in is its Presentation's.
UCLASS(Meta = (DisplayName = "🔑 Key"))
class UMars_ItemTrait_Key : UCk_ItemTrait
{
    UPROPERTY(meta = (Categories = "Key.Mars"))
    FGameplayTag KeyId;
}

mixin bool Has_Key(const FCk_Handle_Item& Self)
{
    return Self.Has_ItemTrait(UMars_ItemTrait_Key);
}

// Invalid for an item that is no key.
mixin FGameplayTag Get_KeyId(const FCk_Handle_Item& Self)
{
    if (Self.Has_Key() == false)
    { return FGameplayTag(); }

    const UMars_ItemTrait_Key Key = Self.Get_ItemTrait(UMars_ItemTrait_Key);
    return Key.KeyId;
}
