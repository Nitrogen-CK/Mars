// A late join (Mars_AutoTestRig_NetRealPawnLateJoin): the host picks up a torch, a persistent item, out of the client's
// sight; when its pawn comes to the base the client's new copy of it holds the torch's own replicated body at HeldOffset on
// the body's hand mount, every primitive of it (the torch's mesh, its flame's card and effect) drawn as a world primitive,
// with no proxy beside it.
// Surface: Ck.RealPawn.Net.AS_RealPawn_ALateClientSeesTheHostsHeldTorchInItsBodyHand
class UCk_AutoTest_Net_RealPawn_ALateClientSeesTheHostsHeldTorchInItsBodyHand : UMars_AutoTestRig_NetRealPawnLateJoin
{
    private const FVector k_Base = FVector(934000.0, 0.0, 5000.0);

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Begin_LateJoin(InHandle, k_Base);
    }

    protected UCk_InventoryItem_Definition Get_Definition() override
    {
        return mars_items::Torch();
    }

    protected FString Get_Row() override
    {
        return "ALateClientSeesTheHostsHeldTorchInItsBodyHand";
    }

    protected void DoAssert_ClientPresentation() override
    {
        Assert_False(Get_IsPresentationVisual(), "the late copy holds the torch's own body, not a visual of its own");
        Assert_PresentationIsWorldPrimitive();
    }
}
