// Teleporting the steak onto the hot pan with each face down in turn (utils_searing::Make_FaceDownRotation) lands that
// face on the pan (Get_DownFace agrees) and sears it; the sixth seared face completes the steak once. Each teleport after
// the first (NegZ, the spawn's resting face) changes the resting face, so it counts a flip.
class UMars_AutoTest_Searing_TeleportingEachFaceDownCompletes : UMars_AutoTestRig_Searing
{
    default _TimeoutSeconds = 25.0f;

    private TArray<EMars_Searing_Face> _Order;
    private int32 _FaceIndex = -1;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Spec = Make_TestSpec();
        Spec.Cook.SecondsPerFace = 0.15f;
        BuildStation(InHandle, Spec);

        _Order.Add(EMars_Searing_Face::NegZ);
        _Order.Add(EMars_Searing_Face::PosZ);
        _Order.Add(EMars_Searing_Face::PosX);
        _Order.Add(EMars_Searing_Face::NegX);
        _Order.Add(EMars_Searing_Face::PosY);
        _Order.Add(EMars_Searing_Face::NegY);

        Add_Step("heat the pan", n"Step_Heat");
        Add_Step_WaitUntil("the steak landed on the pan", n"Check_OnPan", 0, 3.0f);
        for (int32 Index = 0; Index < _Order.Num(); ++Index)
        {
            Add_Step(f"teleport face {utils_searing::Get_FaceName(_Order[Index])} down onto the pan", n"Step_TeleportNextFace");
            Add_Step_WaitFrames("the teleport is applied and written back", 4);
            Add_Step_WaitUntil("the steak is on the pan", n"Check_OnPan", 0, 2.0f);
            Add_Step("the teleported face is the one on the pan", n"Step_AssertDownFace");
            Add_Step_WaitUntil("that face seared", n"Check_CurrentFaceSeared", 0, 2.0f);
        }
        Add_Step("six faces seared and the steak completed once", n"Step_AssertCompleted");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_TeleportNextFace(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _FaceIndex += 1;
        const auto Face = _Order[_FaceIndex];

        // On the pan implies the body exists in the simulation; a teleport before that does nothing.
        const auto Body = _Searing.Get_SteakBody();
        Assert_True(utils_jolt_body::Get_IsBodyAdded(Body), "the steak's body is in the simulation");

        const auto PanBaseWorld = _Searing.Get_PanBaseWorld();
        const auto Location = PanBaseWorld.TransformPosition(FVector(0.0, 0.0, utils_searing::k_PanSurfaceZ + _Spec.Steak.HalfSize + 1.0));
        const auto Rotation = (FQuat(PanBaseWorld.Rotator()) * FQuat(utils_searing::Make_FaceDownRotation(Face))).Rotator();
        utils_jolt_body::Request_Teleport(Body, FCk_Request_JoltBody_Teleport(Location, Rotation));
    }

    UFUNCTION()
    private void Step_AssertDownFace(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Expected = _Order[_FaceIndex];
        const auto Down = _Searing.Get_DownFace();
        Assert_True(Down == Expected,
            f"Make_FaceDownRotation({Expected :n}) = {utils_searing::Make_FaceDownRotation(Expected)} lands {Expected :n} on the pan (got {Down :n})");
    }

    UFUNCTION()
    private void Check_CurrentFaceSeared(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Searing.Get_FaceSear(_Order[_FaceIndex]) >= 1.0f);
    }

    UFUNCTION()
    private void Step_AssertCompleted(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Completed, 1, "OnCompleted fired once");
        const auto Phase = _Searing.Get_Phase();
        Assert_True(Phase == EMars_Searing_Phase::Done, f"the steak is done (got {Phase :n})");
        Assert_Equals_Int(_Searing.Get_SearedFaceCount(), 6, "six faces seared");
        Assert_Equals_Int(_Seared.Num(), 6, "OnFaceSeared fired once per face");

        const auto Flips = _Searing.Get_Tally().Flips;
        ck::Trace(f"[Searing] teleported each face down: flips {Flips}");
        Assert_True(Flips >= 5, f"each teleport onto another face counted a flip (got {Flips}, want >= 5)");
        Assert_True(_Sizzles.Num() > 0 && _Sizzles.Last() == EMars_Searing_Sizzle::Quiet, "a done steak does not sizzle");
    }
}

class AMars_AutoTest_Searing_TeleportingEachFaceDownCompletes_Actor : AMars_AutoTestRunner_SearingPan
{
    default _TimeoutSeconds = 25.0f;
    default _TestEntityScriptClass = UMars_AutoTest_Searing_TeleportingEachFaceDownCompletes;
}
