// A second tap after a spent hold picks up again. The empty-handed gloved carrier taps Use on a loose rock: it is picked
// up (that pickup spends the first hold). It throws the rock (the held item's real throw), and once the rock lies still
// taps Use again, a fresh press: the rock is in a bag slot within a second. One pickup per hold must never make every
// later press dead. Isolated origin (36600, -21000, -30000).
class UMars_AutoTest_WorldItem_ASecondTapAfterASpentHoldPicksUpAgain : UMars_AutoTestRig_PickupByPress
{
    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Build_Rig(InHandle, FVector(36600.0, -21000.0, -30000.0));
        Add_Steps_TapTwice();
        Run_Steps(InHandle);
    }
}
