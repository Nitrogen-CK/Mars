// The carried skimmer slid into the corridor (out of the pot, short of the basket) and a Dip asked there: the skim stays
// Carry, no skim edge is broadcast, the lift target stays at the carry and the roll target level (a dip there would drop the
// disc into the counter; a pour would empty the scoop onto it).
class UMars_AutoTest_Fry_APourInTheCorridorIsIgnored : UMars_AutoTestRig_Fry
{
    default _TimeoutSeconds = 10.0f;

    private const FVector2D k_CorridorXY = FVector2D(0.0, 52.0);

    private int32 _SkimEdgesBeforeDip = 0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        BuildStation(InHandle, Make_TestSpec());

        Add_Step("drive the skimmer", n"Step_Drive");
        Add_Step("slide the carried scoop into the corridor", n"Step_SlideToCorridor");
        Add_Step_WaitUntil("the scoop is in the corridor", n"Check_SlideSettled", 0, 3.0f);
        Add_Step("neither in the pot nor over the basket; ask for a dip", n"Step_AskDip");
        Add_Step_WaitFrames("the dip drains", 3);
        Add_Step("the dip was ignored", n"Step_AssertIgnored");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_SlideToCorridor(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        SlideSkimmerTo(k_CorridorXY);
    }

    UFUNCTION()
    private void Step_AskDip(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto ScoopRoot = _Fry.Get_ScoopRoot();
        Log(f"[Mars_AutoTest_Fry_APourInTheCorridorIsIgnored] scoop at root {ScoopRoot}, target {_Fry.Get_SkimmerTarget()}");
        Assert_Equals_Float(_Fry.Get_SkimmerTarget().Y, k_CorridorXY.Y, 0.01, "the corridor point is inside the reach (no clamp)");
        Assert_False(_Fry.Get_IsScoopInPot(), "the scoop is out of the pot");
        Assert_False(_Fry.Get_IsScoopOverBasket(), "the scoop is not over the basket");

        _SkimEdgesBeforeDip = _SkimChanges.Num();
        Dip();
    }

    UFUNCTION()
    private void Step_AssertIgnored(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Fry.Get_Skim() == EMars_Fry_Skim::Carry, f"the skim stays Carry (got {_Fry.Get_Skim() :n})");
        Assert_Equals_Int(_SkimChanges.Num(), _SkimEdgesBeforeDip, "no skim edge");
        Assert_Equals_Float(_Skimmer.Get_TargetLift(), _Spec.Scoop.CarryLift, 0.0001, "the lift target stays at the carry");
        Assert_Equals_Float(_Skimmer.Get_TargetTilt().Roll, 0.0, 0.001, "the roll target stays level");
    }
}
