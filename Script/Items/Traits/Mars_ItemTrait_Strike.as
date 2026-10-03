// What a held melee item deals when its use swings it (UMars_SmState_ItemUse_Strike): after WindupSeconds, one sphere
// sweep of Radius from the player's viewpoint out to Reach, filtered on Probe.Mars.HitZone with a Blocking world policy
// (a wall stops the swing); the first hurtbox hit takes Damage of DamageType through the player's DamageDealer. The use
// completes RecoverySeconds after the sweep.
UCLASS(Meta = (DisplayName = "🗡️ Strike"))
class UMars_ItemTrait_Strike : UCk_ItemTrait
{
    UPROPERTY()
    float32 Damage = 20.0f;

    // DamageType.Mars.{Sever, Crush, Blunt}.
    UPROPERTY(meta = (Categories = "DamageType"))
    FGameplayTag DamageType;

    UPROPERTY()
    float32 Reach = 180.0f;

    UPROPERTY()
    float32 Radius = 25.0f;

    UPROPERTY()
    float32 WindupSeconds = 0.15f;

    UPROPERTY()
    float32 RecoverySeconds = 0.35f;
}

mixin bool Has_Strike(const FCk_Handle_Item& Self)
{
    return Self.Has_ItemTrait(UMars_ItemTrait_Strike);
}

mixin const UMars_ItemTrait_Strike Get_Strike(const FCk_Handle_Item& Self)
{
    return Self.Get_ItemTrait(UMars_ItemTrait_Strike);
}
