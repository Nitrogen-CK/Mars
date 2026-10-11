// The roster contract end to end on the kernel: the drumstick's definition (a prep food) validates, and a FoodPiece built
// from it (its prep mesh, mass, tuners, cap and body; its definition and kind) imports Ready as one closed solid under the
// prep budget (at most 660 triangles, about 765 cm3). A cut across its long X axis at its centroid succeeds: the halves'
// volumes add back to the joint's within RuntimeMesh's own tolerance, their masses add back exactly, and both halves keep
// the definition, the kind and the definition's cap slot. Isolated origin (-62000, 141000, -30000).
class UMars_AutoTest_FoodPiece_APrepFoodImportsReadyAndCuts : UMars_AutoTestRig_FoodPiece
{
    private const FVector k_Origin = FVector(-62000.0, 141000.0, -30000.0);
    private const int32 k_MaxPrepTriangles = 660;
    private const float k_ExpectedVolumeCm3 = 765.0;
    private const int32 k_SlowPolls = 900;

    private UMars_Food_Def _Food;
    private FCk_Handle_FoodPiece _Joint;
    private float _JointVolumeCm3 = 0.0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        _Food = mars::Food_Drumstick_Mars;
        const auto Validation = _Food.Validate();
        Assert_True(Validation.IsValid(), f"the drumstick validates: {Validation.Get_Error()}");

        auto Spec = Make_FoodSpec(_Food.Data.MassKg, _Food);
        Spec.Tuners = _Food.Tuners;
        Spec.Cap = _Food.Visuals.Cap;
        Spec.Body = _Food.Body;
        _Joint = Build_Piece(_Food.Data.Mesh, FTransform(FRotator::ZeroRotator, k_Origin), Spec);

        Add_Step_WaitUntil("the drumstick is Ready", n"Check_JointReady", k_SlowPolls, 0);
        Add_Step("cut the drumstick across X at its centroid", n"Step_Cut");
        Add_Step_WaitUntil("the cut resolved", n"Check_CutResolved", k_SlowPolls, 0);
        Add_Step("the halves conserve volume and mass and keep the food", n"Step_AssertHalves");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Check_JointReady(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_HasReadied(_Joint) || _Failures.Num() > 0);
    }

    UFUNCTION()
    private void Step_Cut(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Failures.Num(), 0, "the drumstick imported");
        Assert_True(_Joint.Get_Status() == EMars_FoodPiece_Status::Ready, "the drumstick is Ready");
        if (_Joint.Get_Status() != EMars_FoodPiece_Status::Ready)
        { return; }

        const auto Metrics = Get_Metrics(_Joint);
        _JointVolumeCm3 = _Joint.Get_VolumeCm3();
        ck::Trace(f"[FoodPiece test] drumstick prep: {Metrics.Get_TriangleCount()} triangles, {_JointVolumeCm3} cm3");
        Assert_True(Metrics.Get_TriangleCount() > 0 && Metrics.Get_TriangleCount() <= k_MaxPrepTriangles,
            f"the prep solid is within its triangle budget ({Metrics.Get_TriangleCount()} <= {k_MaxPrepTriangles})");
        Assert_Equals_Float(_JointVolumeCm3, k_ExpectedVolumeCm3, 0.05 * k_ExpectedVolumeCm3, "the prep solid's volume");

        Cut(_Joint, Metrics.Get_CentroidCm(), FVector::ForwardVector);
    }

    UFUNCTION()
    private void Check_CutResolved(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Cuts.Num() > 0 || _JointVolumeCm3 <= 0.0);
    }

    UFUNCTION()
    private void Step_AssertHalves(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Cuts.Num() > 0, "the cut resolved");
        if (_Cuts.Num() == 0)
        { return; }

        const auto Result = _Cuts[0];
        Assert_True(Result.Outcome == EMars_FoodPiece_CutOutcome::Cut, f"the drumstick was cut (got {Result.Outcome :n})");
        if (Result.Outcome != EMars_FoodPiece_CutOutcome::Cut)
        { return; }

        const auto PositiveCm3 = Result.Positive.Get_VolumeCm3();
        const auto NegativeCm3 = Result.Negative.Get_VolumeCm3();
        const auto MassKg = _Food.Data.MassKg;
        ck::Trace(f"[FoodPiece test] drumstick {_JointVolumeCm3} cm3 cut into {PositiveCm3} + {NegativeCm3} cm3");

        Assert_True(PositiveCm3 > 0.0 && NegativeCm3 > 0.0, "both halves have volume");
        Assert_Equals_Float(PositiveCm3 + NegativeCm3, _JointVolumeCm3, Math::Max(0.01, 0.0001 * _JointVolumeCm3), "the halves' volumes add back to the joint's");
        Assert_True(Math::Abs(Result.Positive.Get_MassKg() + Result.Negative.Get_MassKg() - MassKg) <= 0.000000001, "the halves' masses add back to the joint's");

        Assert_Half(Result.Positive, "the positive half");
        Assert_Half(Result.Negative, "the negative half");
    }

    private void Assert_Half(const FCk_Handle_FoodPiece& InHalf, const FString& InName)
    {
        Assert_True(ck::IsValid(InHalf), f"{InName} is live");
        if (ck::Is_NOT_Valid(InHalf))
        { return; }

        Assert_True(InHalf.Get_Definition().Get() == _Food, f"{InName} keeps the drumstick's definition");
        Assert_True(InHalf.Get_Kind().HasTag(GameplayTags::Food_Meat), f"{InName} is meat");
        Assert_Equals_Int(InHalf.Get_Cap().Get_MaterialID(), _Food.Visuals.Cap.Get_MaterialID(), f"{InName} caps on the definition's slot");
    }
}
