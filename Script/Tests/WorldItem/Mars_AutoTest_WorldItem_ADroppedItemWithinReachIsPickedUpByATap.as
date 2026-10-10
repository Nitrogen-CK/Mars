// A dropped rock that lands within the gloves' reach is picked up again by one tap of Use. The gloved carrier drops the rock
// it holds (the held item's real drop) just in front of it, focuses it once it lies still and taps Use (released two frames
// after the press): the gloves reach it and the rock is in a bag slot within a second. Isolated origin
// (33400, -21000, -30000).
class UMars_AutoTest_WorldItem_ADroppedItemWithinReachIsPickedUpByATap : UMars_AutoTestRig_PickupByPress
{
    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        _LaunchKind = EMars_LaunchKind::Drop;
        Build_Rig(InHandle, FVector(33400.0, -21000.0, -30000.0));
        Add_Steps_LaunchAndTap();
        Run_Steps(InHandle);
    }
}
