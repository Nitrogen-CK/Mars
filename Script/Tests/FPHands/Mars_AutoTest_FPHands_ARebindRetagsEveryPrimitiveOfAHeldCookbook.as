// The hand mount's rebind retags a held cookbook: held on the unpossessed pawn's body every primitive of the book (its
// physical mesh and the skeletal reading presentation) is a world primitive; once the local player possesses the pawn and
// the mount moves under the gloves, every one is first-person (UMars_AutoTestRig_PlayerHandRebind). It must hold both: the
// static mesh and the skeletal book. Isolated origin (-198000, 214000, 8000).
class UMars_AutoTest_FPHands_ARebindRetagsEveryPrimitiveOfAHeldCookbook : UMars_AutoTestRig_PlayerHandRebind
{
    default _Origin = FVector(-198000.0, 214000.0, 8000.0);

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        _Definition = mars_items::Cookbook();
        _ItemKinds = FMars_AutoTest_PrimitiveKinds(1, 1);
        Run_Rebind(InHandle);
    }
}

class AMars_AutoTest_FPHands_ARebindRetagsEveryPrimitiveOfAHeldCookbook_Actor : AMars_AutoTestRunner_PlayerCombat
{
    default _TimeoutSeconds = 30.0f;
    default _TestEntityScriptClass = UMars_AutoTest_FPHands_ARebindRetagsEveryPrimitiveOfAHeldCookbook;
}
