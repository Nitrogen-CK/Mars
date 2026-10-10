// A thrown rock is picked up again by one tap of Use. The gloved carrier throws the rock it holds (the held item's real
// throw) far onto the floor, focuses it once it lies still and taps Use (released two frames after the press, long before
// the gloves could get there): the rock is in a bag slot within a second. Isolated origin (31800, -21000, -30000).
class UMars_AutoTest_WorldItem_AThrownItemIsPickedUpByATap : UMars_AutoTestRig_PickupByPress
{
    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        _LaunchKind = EMars_LaunchKind::Throw;
        Build_Rig(InHandle, FVector(31800.0, -21000.0, -30000.0));
        Add_Steps_LaunchAndTap();
        Run_Steps(InHandle);
    }
}
