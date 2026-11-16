// How the item leaves the hand: a tap of Drop launches it at DropSpeed, a held-then-released Drop throws it. A throw
// charges while Drop stays held, from MinThrowPower of ThrowSpeed to all of it over ChargeSeconds.
UCLASS(Meta = (DisplayName = "⚾💨 Throwable"))
class UMars_ItemTrait_Throwable : UCk_ItemTrait
{
    // A fully charged throw's speed.
    UPROPERTY()
    float32 ThrowSpeed = 900.0f;

    // An uncharged throw's share of ThrowSpeed, 0..1.
    UPROPERTY()
    float32 MinThrowPower = 0.35f;

    // How long a throw takes to charge from MinThrowPower to the full ThrowSpeed once it arms.
    UPROPERTY()
    float32 ChargeSeconds = 1.0f;

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
