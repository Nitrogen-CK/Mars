// An item that is only ever carried in both hands: it stows into the hotbar's overflow slot and nowhere else, so selecting
// any other slot drops it. A tray of food, a bucket, a body.
UCLASS(Meta = (DisplayName = "🤲 Hands only"))
class UMars_ItemTrait_HandsOnly : UCk_ItemTrait
{
}

mixin bool Has_HandsOnly(const FCk_Handle_Item& Self)
{
    return Self.Has_ItemTrait(UMars_ItemTrait_HandsOnly);
}
