// Two pieces added side by side (pan-local (-8, 0) and (+8, 0)) land on the cold pan as two identities with distinct
// entities and bodies. The first is then teleported in place onto its +X face; once the pan heats, each piece sears only
// its own down face: the first's +X rises and nothing else of it, the second's -Z rises and nothing else of it (its +X
// stays raw), so no face value is shared between pieces.
class UMars_AutoTest_Searing_TwoPiecesSearIndependently : UMars_AutoTestRig_Searing
{
    default _TimeoutSeconds = 10.0f;

    private const FVector k_FirstLocal = FVector(-8.0, 0.0, 8.0);
    private const FVector k_SecondLocal = FVector(8.0, 0.0, 8.0);
    // Long enough that half a second of heat leaves both faces partway.
    private const float32 k_SecondsPerFace = 1.0f;
    private const float32 k_SearSeconds = 0.5f;

    private FMars_CookingFeed_PieceId _FirstId;
    private FMars_CookingFeed_PieceId _SecondId;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Spec = Make_TestSpec();
        Spec.Cook.SecondsPerFace = k_SecondsPerFace;
        BuildStation(InHandle, Spec);

        Add_Step_WaitUntil("the pan body is in the simulation", n"Check_PanBodyAdded", 0, 3.0f);
        Add_Step("add two pieces side by side on the cold pan", n"Step_AddTwo");
        Add_Step_WaitUntil("both pieces landed on the pan", n"Check_BothOnPan", 0, 3.0f);
        Add_Step("two identities, two entities, two bodies; turn the first onto +X", n"Step_AssertDistinctAndTurnFirst");
        Add_Step_WaitFrames("the teleport is applied and written back", 4);
        Add_Step_WaitUntil("both pieces are on the pan again", n"Check_BothOnPan", 0, 2.0f);
        Add_Step("the first lies on +X, the second on -Z; heat the pan", n"Step_AssertFacesAndHeat");
        Add_Step_WaitSeconds("both pieces sear", k_SearSeconds);
        Add_Step("each piece seared only its own down face", n"Step_AssertIndependentSear");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_AddTwo(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _FirstId = AddPieceAt(k_FirstLocal);
        _SecondId = AddPieceAt(k_SecondLocal);
    }

    UFUNCTION()
    private void Check_BothOnPan(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Added.Num() == 2 && Get_IsOnPan(_FirstId) && Get_IsOnPan(_SecondId));
    }

    UFUNCTION()
    private void Step_AssertDistinctAndTurnFirst(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(Get_AdmissionCount(EMars_CookingFeed_Admission::Accepted), 2, "both admissions accepted");
        Assert_False(_FirstId.Get_IsSame(_SecondId), "two identities");
        Assert_True(_Searing.Get_PieceEntity(_FirstId) != _Searing.Get_PieceEntity(_SecondId), "two entities");
        Assert_True(_Searing.Get_PieceBody(_FirstId) != _Searing.Get_PieceBody(_SecondId), "two bodies");

        auto Body = _Searing.Get_PieceBody(_FirstId);
        Assert_True(utils_jolt_body::Get_IsBodyAdded(Body), "the first piece's body is in the simulation");

        const auto PanBaseWorld = _Searing.Get_PanBaseWorld();
        const auto Location = PanBaseWorld.TransformPosition(FVector(k_FirstLocal.X, k_FirstLocal.Y, utils_searing::k_PanSurfaceZ + _Spec.Steak.HalfSize + 1.0));
        const auto Rotation = (FQuat(PanBaseWorld.Rotator()) * FQuat(utils_searing::Make_FaceDownRotation(EMars_Searing_Face::PosX))).Rotator();
        utils_jolt_body::Request_Teleport(Body, FCk_Request_JoltBody_Teleport(Location, Rotation));
    }

    UFUNCTION()
    private void Step_AssertFacesAndHeat(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto FirstDown = _Searing.Get_DownFace(_FirstId);
        const auto SecondDown = _Searing.Get_DownFace(_SecondId);
        Assert_True(FirstDown == EMars_Searing_Face::PosX, f"the first piece lies on +X (got {FirstDown :n})");
        Assert_True(SecondDown == EMars_Searing_Face::NegZ, f"the second piece lies on -Z (got {SecondDown :n})");
        Assert_Equals_Int(_Seared.Num() + _ProgressSignals, 0, "nothing seared on the cold pan");

        Heat();
    }

    UFUNCTION()
    private void Step_AssertIndependentSear(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        for (int32 Index = 0; Index < utils_searing::k_FaceCount; ++Index)
        {
            const auto Face = EMars_Searing_Face(Index);
            const auto FirstSear = _Searing.Get_FaceSear(_FirstId, Face);
            const auto SecondSear = _Searing.Get_FaceSear(_SecondId, Face);
            ck::Trace(f"[Searing] two pieces: face {utils_searing::Get_FaceName(Face)} first {FirstSear :.3} second {SecondSear :.3}");

            if (Face == EMars_Searing_Face::PosX)
            { Assert_True(FirstSear > 0.1f && FirstSear < 1.0f, f"the first piece's +X rose (got {FirstSear})"); }
            else
            { Assert_Equals_Float(FirstSear, 0.0, 0.0001, f"the first piece's {utils_searing::Get_FaceName(Face)} is raw"); }

            if (Face == EMars_Searing_Face::NegZ)
            { Assert_True(SecondSear > 0.1f && SecondSear < 1.0f, f"the second piece's -Z rose (got {SecondSear})"); }
            else
            { Assert_Equals_Float(SecondSear, 0.0, 0.0001, f"the second piece's {utils_searing::Get_FaceName(Face)} is raw"); }
        }

        Assert_True(_Searing.Get_PieceStatus(_FirstId) == EMars_Searing_PieceStatus::Cooking, "the first piece is cooking");
        Assert_True(_Searing.Get_PieceStatus(_SecondId) == EMars_Searing_PieceStatus::Cooking, "the second piece is cooking");
        Assert_Equals_Int(_Searing.Get_Summary().Cooking, 2, "two pieces cooking");
        Assert_True(_Searing.Get_Sizzle() == EMars_Searing_Sizzle::Sizzling, "the pan sizzles");
    }
}

class AMars_AutoTest_Searing_TwoPiecesSearIndependently_Actor : AMars_AutoTestRunner_SearingPan
{
    default _TimeoutSeconds = 10.0f;
    default _TestEntityScriptClass = UMars_AutoTest_Searing_TwoPiecesSearIndependently;
}
