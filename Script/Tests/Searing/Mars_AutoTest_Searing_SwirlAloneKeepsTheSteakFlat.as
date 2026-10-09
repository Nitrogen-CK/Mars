// A hot pan swirling at the station's radius and rate, with no look, must keep the piece on the face it landed on: the
// swirl makes it glide on the oil, it must not tumble it. Faces never sear here (SecondsPerFace 100), so a face change is
// the only event; every second the piece's flips, radius and height are traced, so a red run measures the tumbling.
class UMars_AutoTest_Searing_SwirlAloneKeepsTheSteakFlat : UMars_AutoTestRig_Searing
{
    default _TimeoutSeconds = 25.0f;

    // The swirl radius under test (uu); the station's SwirlRadius (Mars_SearingStation_EntityScript.as).
    protected const float32 k_SwirlRadius = 4.0f;
    // The station's SwirlHz.
    private const float32 k_SwirlHz = 1.5f;
    private const int32 k_SwirlSeconds = 12;

    private int32 _SecondsTraced = 0;
    private float64 _MaxRadius = 0.0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Spec = Make_TestSpec();
        Spec.Cook.SecondsPerFace = 100.0f;
        auto PanSpec = FMars_Implement_Spec();
        PanSpec.Orbit = FMars_Implement_OrbitSpec(k_SwirlRadius, k_SwirlHz);
        BuildStation(InHandle, Spec, PanSpec);
        Build_Pieces(1);

        Add_Steps_AddPieceAndLand();
        Add_Step("heat the pan: the swirl runs", n"Step_Heat");
        for (auto Second = 0; Second < k_SwirlSeconds; ++Second)
        {
            Add_Step_WaitSeconds("let the pan swirl", 1.0f);
            Add_Step("trace the piece", n"Step_TraceSwirl");
        }

        Add_Step("the piece stayed on the pan, on its face", n"Step_AssertFlat");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_TraceSwirl(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _SecondsTraced += 1;
        const auto Local = _Searing.Get_PiecePanLocal(Get_FirstId());
        _MaxRadius = Math::Max(_MaxRadius, Local.Size2D());
        ck::Trace(f"[SearingSwirl] t={_SecondsTraced} s flips={_Searing.Get_Tally().Flips} r={Local.Size2D() :.2} "
            + f"z={Local.Z :.2} down={utils_searing::Get_FaceName(_Searing.Get_DownFace(Get_FirstId()))}");
    }

    UFUNCTION()
    private void Step_AssertFlat(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Tally = _Searing.Get_Tally();
        ck::Trace(f"[SearingSwirl] radius {k_SwirlRadius :.1}: flips {Tally.Flips} in {k_SwirlSeconds} s, max r {_MaxRadius :.2}, "
            + f"losses {Tally.Losses}");

        Assert_True(Get_IsOnPan(Get_FirstId()), f"the piece stayed on the pan (contact {_Searing.Get_PieceContact(Get_FirstId()) :n})");
        Assert_Equals_Int(Tally.Losses, 0, "no loss");
        Assert_Equals_Int(Tally.Flips, 0, f"the swirl alone must not flip the piece (flips {Tally.Flips} in {k_SwirlSeconds} s)");
    }
}

class AMars_AutoTest_Searing_SwirlAloneKeepsTheSteakFlat_Actor : AMars_AutoTestRunner_SearingPan
{
    default _TimeoutSeconds = 25.0f;
    default _TestEntityScriptClass = UMars_AutoTest_Searing_SwirlAloneKeepsTheSteakFlat;
}
