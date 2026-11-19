// A late join (Mars_AutoTestRig_NetRealPawnLateJoin): the host picks up a rock, a transient item, out of the client's
// sight; when its pawn comes to the base the client's new copy of it presents the rock by a Visual-mode world item of its
// own at HeldOffset on the body's hand mount, drawn as a world primitive, with no proxy beside it. Nothing about the hold
// was sent for the late copy: it reads the replicated hotbar.
// Surface: Ck.RealPawn.Net.AS_RealPawn_ALateClientSeesTheHostsHeldRockInItsBodyHand
class UCk_AutoTest_Net_RealPawn_ALateClientSeesTheHostsHeldRockInItsBodyHand : UMars_AutoTestRig_NetRealPawnLateJoin
{
    private const FVector k_Base = FVector(932000.0, 0.0, 5000.0);

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Begin_LateJoin(InHandle, k_Base);
    }

    protected UCk_InventoryItem_Definition Get_Definition() override
    {
        return mars_items::Rock();
    }

    protected FString Get_Row() override
    {
        return "ALateClientSeesTheHostsHeldRockInItsBodyHand";
    }

    protected void DoAssert_ClientPresentation() override
    {
        Assert_True(Get_IsPresentationVisual(), "the late copy presents the rock by a Visual-mode world item of its own");
        Assert_PresentationIsWorldPrimitive();
    }
}
