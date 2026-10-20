// A SetStateExpression whose left cell is past the atlas and a SetPlatePrimitive naming a material slot the primitive
// lacks each fire their request ensure and change nothing: the cells stay the style's, and the primitive never becomes the
// plate (its cell slots are never written). Isolated Z band: -76500.
class UMars_AutoTest_Eyes_RejectsBadStateExpressionAndPlateSlot : UMars_AutoTestRig_Eyes
{
    private FCk_Handle_UnrealComponent _Primitive;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto FaceNode = Make_FaceNode(InHandle, FVector(0.0, 0.0, -76500.0));

        auto Spec = FMars_Eyes_Spec();
        Spec.Style.LeftCell = 3;
        Spec.Style.RightCell = 3;
        _Eyes = utils_eyes::Add(FaceNode, Spec);
        _Primitive = Make_PlatePrimitive(FaceNode, n"EyesTest_RejectedPlate");

        Add_Step("the eyes have a presentation", n"Step_AssertPresentation");
        Add_Step_WaitUntil("the primitive's component exists", n"Check_PrimitiveExists");
        Add_Step("a state expression with cell 32, and the primitive's missing slot 5 as the plate", n"Step_RequestBad");
        Add_Step_WaitUntil("the requests were drained", n"Check_RequestsDrained");
        Add_Step("nothing changed", n"Step_AssertUnchanged");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Check_PrimitiveExists(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(ck::IsValid(Get_PrimitiveComponent(_Primitive)));
    }

    UFUNCTION()
    private void Step_RequestBad(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Bad = FMars_Eyes_ExpressionDef();
        Bad.LeftCell = constants_eyes::k_CellCount;
        Bad.RightCell = 13;
        _Eyes.Request_SetStateExpression(FMars_Request_Eyes_SetStateExpression(Bad));
        _Eyes.Request_SetPlatePrimitive(FMars_Request_Eyes_SetPlatePrimitive(Get_PrimitiveComponent(_Primitive), 5));
    }

    UFUNCTION()
    private void Check_RequestsDrained(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Eyes.Has_Fragment(FMars_Fragment_Eyes_Requests) == false);
    }

    UFUNCTION()
    private void Step_AssertUnchanged(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Eyes.Get_ResolvedLeftCell(), 3, "the left cell is still the style's after the rejected state expression");
        Assert_Equals_Int(_Eyes.Get_ResolvedRightCell(), 3, "the right cell is still the style's after the rejected state expression");
        Assert_True(Get_IsSlot(_Primitive, LeftCellSlot, 0.0f) && Get_IsSlot(_Primitive, RightCellSlot, 0.0f),
            f"the rejected plate was never written (cell slots [{Get_Slot(_Primitive, LeftCellSlot)}, {Get_Slot(_Primitive, RightCellSlot)}])");
    }
}

// Hand-authored so the deliberate rejected-request ensures are expected errors rather than failures.
class AMars_AutoTest_Eyes_RejectsBadStateExpressionAndPlateSlot_Actor : ACk_AutoTestRunner
{
    default _TestEntityScriptClass = UMars_AutoTest_Eyes_RejectsBadStateExpressionAndPlateSlot;

    UFUNCTION(BlueprintOverride)
    TArray<FString> Get_ExpectedLogErrors() const
    {
        TArray<FString> Out;
        Out.Add("rejected SetStateExpression: LeftCell [32] is outside [0, 31]");
        Out.Add("has no material slot [5] (it has [1])");
        return Out;
    }
}
