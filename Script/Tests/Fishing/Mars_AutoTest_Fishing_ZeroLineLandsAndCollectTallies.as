// Holding the reel with no runs takes the line to zero: the fish lands (OnLanded once, with the table's item and where the
// bait was), flies from the water to the catch point over LandFlingSeconds (Get_FishWorld arrives at the catch node), and
// stays Landed until collected. Collect before the fling ends still works; two Collects in one drain tally one fish
// (OnCollected once) and leave the spot Idle; a Collect while Idle is ignored.
class UMars_AutoTest_Fishing_ZeroLineLandsAndCollectTallies : UMars_AutoTestRig_Fishing
{
    default _TimeoutSeconds = 20.0f;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        BuildFishing(InHandle, Make_SpecWithNodes(InHandle));

        Add_Step("engage", n"Step_Engage");
        Add_Step_WaitUntil("the spot is engaged", n"Check_Engaged");
        Add_Step("cast at full power", n"Step_CastFull");
        Add_Step_WaitUntil("a fish bites", n"Check_Bite");
        Add_Step("strike the hook", n"Step_Hook");
        Add_Step_WaitUntil("the fight is on", n"Check_Reeling");
        Add_Step("hold the reel", n"Step_Hold");
        Add_Step_WaitUntil("the fish lands", n"Check_Landed");
        Add_Step("the landing broadcast the catch", n"Step_AssertLanded");
        Add_Step_WaitUntil("the fling arrives", n"Check_FlingDone");
        Add_Step("the fish is at the catch point and not yet tallied", n"Step_AssertArrived");
        Add_Step("collect twice", n"Step_CollectTwice");
        Add_Step_WaitUntil("the spot is Idle", n"Check_Idle");
        Add_Step("the tally counts one fish", n"Step_AssertTallied");
        Add_Step("collect while Idle", n"Step_Collect");
        Add_Step_WaitSeconds("a beat", 0.15f);
        Add_Step("the idle collect was ignored", n"Step_AssertIdleCollectIgnored");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_AssertLanded(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Lands, 1, "one OnLanded");
        Assert_Equals_Int(_Snaps, 0, "no snap");
        Assert_True(_LastLandedCatch.Item.Get() == mars_items::Food_MeatSlab(), "the catch is the table's item");
        Assert_True(_LastLandedCatch.LandedAt.Equals(_LastLandingPoint, 0.001), "the fish left the water where the bait was");
        Assert_Equals_Float(_Fishing.Get_LineLengthCm(), 0.0f, 0.0f, "no line out");
        Assert_True(_Fishing.Get_FlingAlpha() < 1.0f, "the fling has started");
        Assert_Equals_Int(_Fishing.Get_Tally(), 0, "not tallied before the collect");
    }

    UFUNCTION()
    private void Step_AssertArrived(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Fishing.Get_FishWorld().Equals(k_Origin + k_CatchLocal, 0.01), f"the fish arrived at the catch point ({_Fishing.Get_FishWorld()})");
        Assert_True(_Fishing.Get_Phase() == EMars_Fishing_Phase::Landed, "still Landed");
        Assert_Equals_Int(_Collects, 0, "no OnCollected yet");
    }

    UFUNCTION()
    private void Step_CollectTwice(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Fishing.Request_Collect(FMars_Request_Fishing_Collect());
        _Fishing.Request_Collect(FMars_Request_Fishing_Collect());
    }

    UFUNCTION()
    private void Step_AssertTallied(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Fishing.Get_Tally(), 1, "two Collects in one drain tallied one fish");
        Assert_Equals_Int(_Collects, 1, "one OnCollected");
        Assert_True(_LastCollectedCatch.Item.Get() == mars_items::Food_MeatSlab(), "OnCollected carried the catch");
        Assert_True(_Fishing.Get_Catch().Item.IsNull(), "the catch left the spot");
        Assert_Equals_Float(_Fishing.Get_FlingAlpha(), 0.0f, 0.0f, "no fling while Idle");
    }

    UFUNCTION()
    private void Step_AssertIdleCollectIgnored(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Fishing.Get_Tally(), 1, "still one fish");
        Assert_Equals_Int(_Collects, 1, "still one OnCollected");
    }
}
