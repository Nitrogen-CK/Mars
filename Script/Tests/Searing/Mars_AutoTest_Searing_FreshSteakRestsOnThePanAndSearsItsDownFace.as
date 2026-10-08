// A fresh piece added over the level pan is admitted once, drops onto it and rests flat on its -Z face, which sears on the
// hot pan while the pan sizzles; at 1 the face stops (no overcook), the sizzle goes quiet and no other face cooked.
class UMars_AutoTest_Searing_FreshSteakRestsOnThePanAndSearsItsDownFace : UMars_AutoTestRig_Searing
{
    default _TimeoutSeconds = 8.0f;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        BuildStation(InHandle, Make_TestSpec());

        Add_Step("heat the pan", n"Step_Heat");
        Add_Steps_AddPieceAndLand();
        Add_Step("the piece rests flat on its -Z face and the pan sizzles", n"Step_AssertResting");
        Add_Step_WaitUntil("the face on the pan seared", n"Check_FirstDownFaceSeared", 0, 2.0f);
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
        Log(f"[Mars_AutoTest_Searing_FreshSteakRestsOnThePanAndSearsItsDownFace] add to first landing {_FirstLandingTime - _FirstAddedTime :.3} s");

        Assert_Equals_Int(Get_AdmissionCount(EMars_CookingFeed_Admission::Accepted), 1, "one admission, accepted");
        Assert_Equals_Int(_Added.Num(), 1, "OnPieceAdded fired once");
        const auto PieceId = Get_FirstId();
        Assert_True(ck::IsValid(_Searing.Get_PieceEntity(PieceId)), "the piece entity is live");
        Assert_True(_Searing.Get_PieceStatus(PieceId) == EMars_Searing_PieceStatus::Cooking, "the piece is cooking");

        const auto Local = _Searing.Get_PiecePanLocal(PieceId);
        ck::Trace(f"[Searing] resting piece at pan-local Z {Local.Z :.3} (HalfSize {_Spec.Steak.HalfSize})");
        Assert_Equals_Float(Local.Z, utils_searing::k_PanSurfaceZ + _Spec.Steak.HalfSize, 3.0,
            "the piece's centre rests HalfSize above the cooking surface");

        const auto Down = _Searing.Get_DownFace(PieceId);
        Assert_True(Down == EMars_Searing_Face::NegZ, f"the piece lies on its -Z face (got {Down :n})");

        Assert_True(_Sizzles.Num() > 0 && _Sizzles.Last() == EMars_Searing_Sizzle::Sizzling, "the pan sizzles under a raw face");
    }

    UFUNCTION()
    private void Step_AssertOnlyDownFaceSeared(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Seared.Num(), 1, "OnFaceSeared fired once");
        if (_Seared.Num() > 0)
        {
            Assert_True(_Seared[0] == EMars_Searing_Face::NegZ, f"the seared face is -Z (got {_Seared[0] :n})");
            Assert_True(_SearedIds[0].Get_IsSame(Get_FirstId()), "OnFaceSeared names the piece");
        }

        Assert_True(_ProgressSignals > 0, "OnSearProgress reported the face's progress");

        for (int32 Index = 0; Index < utils_searing::k_FaceCount; ++Index)
        {
            const auto Face = EMars_Searing_Face(Index);
            const auto Expected = Face == EMars_Searing_Face::NegZ ? 1.0 : 0.0;
            Assert_Equals_Float(_Searing.Get_FaceSear(Get_FirstId(), Face), Expected, 0.001, f"face {utils_searing::Get_FaceName(Face)} sear");
        }
    }

    UFUNCTION()
    private void Step_AssertQuiet(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Sizzles.Num() > 0 && _Sizzles.Last() == EMars_Searing_Sizzle::Quiet, "a seared face on the pan does not sizzle");
        Assert_True(Get_IsOnPan(Get_FirstId()), "the piece is still on the pan");
    }

    UFUNCTION()
    private void Step_AssertNoOvercook(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Float(_Searing.Get_FaceSear(Get_FirstId(), EMars_Searing_Face::NegZ), 1.0, 0.0001, "the seared face stays at 1");
        Assert_Equals_Int(_Seared.Num(), 1, "no second OnFaceSeared");
        Assert_Equals_Int(_Searing.Get_SearedFaceCount(Get_FirstId()), 1, "one face seared");
        Assert_Equals_Int(_Added.Num(), 1, "nothing else was added");
    }
}

class AMars_AutoTest_Searing_FreshSteakRestsOnThePanAndSearsItsDownFace_Actor : AMars_AutoTestRunner_SearingPan
{
    default _TimeoutSeconds = 8.0f;
    default _TestEntityScriptClass = UMars_AutoTest_Searing_FreshSteakRestsOnThePanAndSearsItsDownFace;
}
