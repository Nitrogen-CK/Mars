// A piece at the foot of the bowl's wall (pan-local (22, 0, 8); the flat base ends at r 21.5 at the station's scale), where
// a held tilt parks it and a toss can land it, must glide, not tumble, while the pan swirls at the station's radius and
// rate with no look: after 12 s it is still on the pan, unlost and unflipped. Faces never sear here (SecondsPerFace 100),
// so a face change is the only event; every second the piece's flips, radius and height are traced.
class UMars_AutoTest_Searing_SwirlWithTheSteakAtTheWall : UMars_AutoTestRig_Searing
{
    default _TimeoutSeconds = 25.0f;

    // The station's SwirlRadius and SwirlHz (Mars_SearingStation_EntityScript.as).
    protected const float32 k_SwirlRadius = 4.0f;
    private const float32 k_SwirlHz = 1.5f;
    private const FVector k_WallFootLocal = FVector(22.0, 0.0, 8.0);
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

        Add_Steps_AddPieceAndLand();
        Add_Step("heat the pan: the swirl runs", n"Step_Heat");
        Add_Step_WaitSeconds("let the swirl ease in", 0.5f);
        Add_Step("teleport the piece to the foot of the wall", n"Step_TeleportToWall");
        for (auto Second = 0; Second < k_SwirlSeconds; ++Second)
        {
            Add_Step_WaitSeconds("let the pan swirl", 1.0f);
            Add_Step("trace the piece", n"Step_TraceSwirl");
        }

        Add_Step("the piece stayed on the pan, on its face", n"Step_AssertOnPan");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_TeleportToWall(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        // On the pan implies the body exists in the simulation; a teleport before that does nothing.
        auto Body = _Searing.Get_PieceBody(Get_FirstId());
        Assert_True(utils_jolt_body::Get_IsBodyAdded(Body), "the piece's body is in the simulation");

        const auto PanBaseWorld = _Searing.Get_PanBaseWorld();
        utils_jolt_body::Request_Teleport(Body,
            FCk_Request_JoltBody_Teleport(PanBaseWorld.TransformPosition(k_WallFootLocal), PanBaseWorld.Rotator()));
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
    private void Step_AssertOnPan(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Tally = _Searing.Get_Tally();
        ck::Trace(f"[SearingSwirl] piece at the wall, radius {k_SwirlRadius :.1}: flips {Tally.Flips} in {k_SwirlSeconds} s, "
            + f"max r {_MaxRadius :.2}, losses {Tally.Losses}");

        Assert_True(Get_IsOnPan(Get_FirstId()), f"the piece stayed on the pan (contact {_Searing.Get_PieceContact(Get_FirstId()) :n})");
        Assert_Equals_Int(Tally.Losses, 0, "no loss");
        Assert_Equals_Int(Tally.Flips, 0,
            f"the swirl must not flip a piece at the wall's foot (flips {Tally.Flips} in {k_SwirlSeconds} s)");
    }
}

class AMars_AutoTest_Searing_SwirlWithTheSteakAtTheWall_Actor : AMars_AutoTestRunner_SearingPan
{
    default _TimeoutSeconds = 25.0f;
    default _TestEntityScriptClass = UMars_AutoTest_Searing_SwirlWithTheSteakAtTheWall;
}
