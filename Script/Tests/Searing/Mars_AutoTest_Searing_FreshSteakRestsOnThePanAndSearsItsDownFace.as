// A fresh steak spawns once, drops onto the level pan and rests flat on its -Z face, which sears on the hot pan while
// the pan sizzles; at 1 the face stops (no overcook), the sizzle goes quiet and no other face cooked.
class UMars_AutoTest_Searing_FreshSteakRestsOnThePanAndSearsItsDownFace : UMars_AutoTestRig_Searing
{
    default _TimeoutSeconds = 8.0f;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        BuildStation(InHandle, Make_TestSpec());

        Add_Step("heat the pan", n"Step_Heat");
        Add_Step_WaitUntil("a steak spawned", n"Check_Spawned1", 0, 1.0f);
        Add_Step_WaitUntil("the steak landed on the pan", n"Check_OnPan", 0, 3.0f);
        Add_Step("the steak rests flat on its -Z face and the pan sizzles", n"Step_AssertResting");
        Add_Step_WaitUntil("the face on the pan seared", n"Check_DownFaceSeared", 0, 2.0f);
        Add_Step("only -Z seared", n"Step_AssertOnlyDownFaceSeared");
        Add_Step_WaitFrames("the sizzle edge", 2);
        Add_Step("the sizzle went quiet", n"Step_AssertQuiet");
        Add_Step_WaitSeconds("a seared face would overcook in this window", 0.3f);
        Add_Step("the face stayed at 1", n"Step_AssertNoOvercook");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_AssertResting(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Log(f"[Mars_AutoTest_Searing_FreshSteakRestsOnThePanAndSearsItsDownFace] spawn to first landing {_FirstLandingTime - _FirstSpawnTime :.3} s");

        Assert_Equals_Int(_Spawned.Num(), 1, "OnSteakSpawned fired once");
        Assert_True(ck::IsValid(_Searing.Get_Steak()), "the steak entity is live");

        const auto Local = _Searing.Get_SteakPanLocal();
        Assert_Equals_Float(Local.Z, utils_searing::k_PanBaseHalfHeight + _Spec.Steak.HalfSize, 3.0,
            "the steak's centre rests HalfSize above the pan base top");

        const auto Down = _Searing.Get_DownFace();
        Assert_True(Down == EMars_Searing_Face::NegZ, f"the steak lies on its -Z face (got {Down :n})");

        Assert_True(_Sizzles.Num() > 0 && _Sizzles.Last() == EMars_Searing_Sizzle::Sizzling, "the pan sizzles under a raw face");
    }

    UFUNCTION()
    private void Step_AssertOnlyDownFaceSeared(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Seared.Num(), 1, "OnFaceSeared fired once");
        if (_Seared.Num() > 0)
        { Assert_True(_Seared[0] == EMars_Searing_Face::NegZ, f"the seared face is -Z (got {_Seared[0] :n})"); }

        Assert_True(_ProgressSignals > 0, "OnSearProgress reported the face's progress");

        for (int32 Index = 0; Index < utils_searing::k_FaceCount; ++Index)
        {
            const auto Face = EMars_Searing_Face(Index);
            const auto Expected = Face == EMars_Searing_Face::NegZ ? 1.0 : 0.0;
            Assert_Equals_Float(_Searing.Get_FaceSear(Face), Expected, 0.001, f"face {utils_searing::Get_FaceName(Face)} sear");
        }
    }

    UFUNCTION()
    private void Step_AssertQuiet(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Sizzles.Num() > 0 && _Sizzles.Last() == EMars_Searing_Sizzle::Quiet, "a seared face on the pan does not sizzle");
        Assert_True(_Searing.Get_IsOnPan(), "the steak is still on the pan");
    }

    UFUNCTION()
    private void Step_AssertNoOvercook(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Float(_Searing.Get_FaceSear(EMars_Searing_Face::NegZ), 1.0, 0.0001, "the seared face stays at 1");
        Assert_Equals_Int(_Seared.Num(), 1, "no second OnFaceSeared");
        Assert_Equals_Int(_Searing.Get_SearedFaceCount(), 1, "one face seared");
    }
}
