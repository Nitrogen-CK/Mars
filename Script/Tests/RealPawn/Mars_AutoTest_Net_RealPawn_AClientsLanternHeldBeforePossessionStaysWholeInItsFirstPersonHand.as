// The server picks a lantern up for the production pawn and lights it while nobody possesses the pawn, waits a second,
// then hands the pawn to the client's controller. The client watches the lantern from the floor on and records the
// order its mount and its pawn's first-person flip came in (either may come first on a client); then, as when the
// lantern is raised after possession (UMars_AutoTestRig_NetRealPawnLitLantern): no scene node under the held lantern
// deeper than 8, the light half the flame over the flame node within 0.1 cm before and after a 90 degree turn and gone
// with the hand, the flame node the flame height over the root within 0.5 cm, the lantern lit, no ensure.
// Surface: Ck.RealPawn.Net.AS_RealPawn_AClientsLanternHeldBeforePossessionStaysWholeInItsFirstPersonHand
class UCk_AutoTest_Net_RealPawn_AClientsLanternHeldBeforePossessionStaysWholeInItsFirstPersonHand : UMars_AutoTestRig_NetRealPawnLitLantern
{
    private const FVector k_Base = FVector(944000.0, 0.0, 5000.0);

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        _PossessFirst = false;
        _Row = "AClientsLanternHeldBeforePossessionStaysWholeInItsFirstPersonHand";
        Run_LitLantern(InHandle, k_Base);
    }

    protected void Assert_Order() override
    {
        Assert_True(_Watch.MountFrame >= 0 && _Watch.FlipFrame >= 0 && (_Watch.ParentAtMount == "body" || _Watch.ParentAtMount == "firstPerson"),
            f"the client saw the lantern's mount commit on its pawn (hand mount under [{_Watch.ParentAtMount}] at mount frame {_Watch.MountFrame}, flip frame {_Watch.FlipFrame})");
    }
}
