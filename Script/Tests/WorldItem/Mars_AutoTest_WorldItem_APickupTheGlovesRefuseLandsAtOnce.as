// A pickup the gloves refuse lands at once. The gloved carrier holds a rock (a two-handed hold: its gloves can take no
// grab) and taps Use on a second rock lying in front of it: the gloves refuse the reach (OnReachRefused names the rock's
// target) and the rock is in the other bag slot within 0.3 s of the tap, sooner than the grip-wait's half-second bound.
// Isolated origin (35000, -21000, -30000).
class UMars_AutoTest_WorldItem_APickupTheGlovesRefuseLandsAtOnce : UMars_AutoTestRig_PickupByPress
{
    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Build_Rig(InHandle, FVector(35000.0, -21000.0, -30000.0));
        Add_Steps_TapWhileHolding();
        Run_Steps(InHandle);
    }
}
