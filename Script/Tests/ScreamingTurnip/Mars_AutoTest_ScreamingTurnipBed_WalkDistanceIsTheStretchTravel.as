// The bed's walk distance is its stretch tuner: spawned with a non-default Pull (travel 74 cm), the bed's Control walks
// WalkCm == Pull.Stretch.TravelCm with Pull.Spring's stiffness, damping and threshold; and a pull walked out by half that
// travel settles at alpha 0.5 (within 0.05), so the tuner alone sets the distance.
class UMars_AutoTest_ScreamingTurnipBed_WalkDistanceIsTheStretchTravel : UMars_AutoTestRig_ScreamingTurnip
{
    default _Origin = FVector(430000.0, 39000.0, -30000.0);

    private const float32 k_TravelCm = 74.0f;
    private const float32 k_HeldAlpha = 0.5f;
    private const float32 k_AlphaTolerance = 0.05f;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        _Carrier = InHandle;
        _BedPull.Stretch.TravelCm = k_TravelCm;
        Build_Floor(InHandle);
        Spawn_Bed(InHandle);

        Add_Step_WaitUntil("the bed is constructed", n"Check_BedReady");
        Add_Step("the Control walks the tuner's travel with the tuner's spring", n"Step_AssertControlTuning");
        Add_Step("start a pull with free hands", n"Step_Pull");
        Add_Step_WaitUntil("the puller grips the stalks", n"Check_PullGripped", k_SlowPolls);
        Add_Step("walk back half the tuner's travel", n"Step_WalkHalfway");
        Add_Step_WaitSeconds("the spring settles", 1.0f);
        Add_Step("half the travel reads alpha 0.5; let go", n"Step_AssertHalfAndLetGo");
        Add_Step_WaitUntil("the pull finishes", n"Check_PullFinished", k_SlowPolls);
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_AssertControlTuning(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto& Manipulation = _BedControl.Get_Fragment(FMars_Fragment_Control_Params).Manipulation;
        Assert_True(_BedControl.Get_PullSource() == EMars_Control_PullSource::Walk, "the bed's Control is a Walk control");
        Assert_Equals_Float(Manipulation.WalkCm, k_TravelCm, 0.0001f, "WalkCm is Pull.Stretch.TravelCm");
        Assert_Equals_Float(Manipulation.Stiffness, _BedPull.Spring.Stiffness, 0.0001f, "the stiffness is Pull.Spring's");
        Assert_Equals_Float(Manipulation.Damping, _BedPull.Spring.Damping, 0.0001f, "the damping is Pull.Spring's");
        Assert_Equals_Float(Manipulation.EngageAlpha, _BedPull.Spring.EngageAlpha, 0.0001f, "the threshold is Pull.Spring's");
    }

    UFUNCTION()
    private void Step_WalkHalfway(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Walk_Puller(Get_WalkCmFor(k_HeldAlpha));
    }

    UFUNCTION()
    private void Step_AssertHalfAndLetGo(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Float(Get_PullAlpha(), k_HeldAlpha, k_AlphaTolerance, f"{Get_WalkCmFor(k_HeldAlpha) :.1} cm walked of a {k_TravelCm} cm travel reads half");
        Assert_Equals_Int(_PullResults.Num(), 0, "the pull is still live");
        Cancel_Pull();
    }
}
