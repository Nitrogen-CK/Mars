// How the item leaves the hand: a tap of Drop launches it at DropSpeed, a held-then-released Drop at ThrowSpeed.
UCLASS(Meta = (DisplayName = "⚾💨 Throwable"))
class UMars_ItemTrait_Throwable : UCk_ItemTrait
{
    UPROPERTY()
    float32 ThrowSpeed = 900.0f;

    UPROPERTY()
    float32 DropSpeed = 150.0f;

    UPROPERTY()
    FVector AngularVelocityDeg = FVector(0, 180, 0);
}

mixin bool Has_Throwable(const FCk_Handle_Item& Self)
{
    return Self.Has_ItemTrait(UMars_ItemTrait_Throwable);
}

mixin const UMars_ItemTrait_Throwable Get_Throwable(const FCk_Handle_Item& Self)
{
    return Self.Get_ItemTrait(UMars_ItemTrait_Throwable);
}
