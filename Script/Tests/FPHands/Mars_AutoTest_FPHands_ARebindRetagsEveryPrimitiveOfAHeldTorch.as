// The hand mount's rebind retags a held torch: held on the unpossessed pawn's body every primitive of the torch (its
// shaft, its head, its flame's card and effect) is a world primitive; once the local player possesses the pawn and the
// mount moves under the gloves, every one is first-person (UMars_AutoTestRig_PlayerHandRebind). It must hold at least the
// shaft and the head (static meshes); a headless boot builds no flame card or effect. Isolated origin
// (-204000, 214000, 8000).
class UMars_AutoTest_FPHands_ARebindRetagsEveryPrimitiveOfAHeldTorch : UMars_AutoTestRig_PlayerHandRebind
{
    default _Origin = FVector(-204000.0, 214000.0, 8000.0);

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        _Definition = mars_items::Torch();
        _ItemKinds = FMars_AutoTest_PrimitiveKinds(2, 0);
        Run_Rebind(InHandle);
    }
}

class AMars_AutoTest_FPHands_ARebindRetagsEveryPrimitiveOfAHeldTorch_Actor : AMars_AutoTestRunner_PlayerCombat
{
    default _TimeoutSeconds = 30.0f;
    default _TestEntityScriptClass = UMars_AutoTest_FPHands_ARebindRetagsEveryPrimitiveOfAHeldTorch;
}
