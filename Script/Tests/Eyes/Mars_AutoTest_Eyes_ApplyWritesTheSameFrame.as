// The plate reflects this frame's resolve: Apply runs after Resolve (and after Blink and Look), so the first time the
// resolved cells show a played expression, the plate primitive's cell slots already hold it. Before the ordering edges
// Apply ran first by name and pushed the previous frame's cells. Isolated Z band: -75500.
class UMars_AutoTest_Eyes_ApplyWritesTheSameFrame : UMars_AutoTestRig_Eyes
{
    private FCk_Handle_UnrealComponent _Primitive;
    private TOptional<float32> _PlateLeftWhenResolved;
    private TOptional<float32> _PlateRightWhenResolved;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto FaceNode = Make_FaceNode(InHandle, FVector(0.0, 0.0, -75500.0));

        auto Spec = FMars_Eyes_Spec();
        Spec.Style.LeftCell = 3;
        Spec.Style.RightCell = 4;
        _Eyes = utils_eyes::Add(FaceNode, Spec);
        _Primitive = Make_PlatePrimitive(FaceNode, n"EyesTest_SameFramePrimitive");

        Add_Step("the eyes have a presentation", n"Step_AssertPresentation");
        Add_Step_WaitUntil("the primitive's component exists", n"Check_PrimitiveExists");
        Add_Step("draw on the primitive", n"Step_SetPlatePrimitive");
        Add_Step_WaitUntil("the primitive holds the style's cells 3 and 4", n"Check_StyleOnPlate");
        Add_Step("play an expression of cells 16 and 17", n"Step_PlayExpression");
        Add_Step_WaitUntil("the resolved cells show the expression", n"Check_ResolvedAndSampled");
        Add_Step("the plate held the expression the frame it resolved", n"Step_AssertSameFrame");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Check_PrimitiveExists(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(ck::IsValid(Get_PrimitiveComponent(_Primitive)));
    }

    UFUNCTION()
    private void Step_SetPlatePrimitive(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Eyes.Request_SetPlatePrimitive(FMars_Request_Eyes_SetPlatePrimitive(Get_PrimitiveComponent(_Primitive), 0));
    }

    UFUNCTION()
    private void Check_StyleOnPlate(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_IsSlot(_Primitive, LeftCellSlot, 3.0f) && Get_IsSlot(_Primitive, RightCellSlot, 4.0f));
    }

    UFUNCTION()
    private void Step_PlayExpression(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Expression = FMars_Eyes_ExpressionDef();
        Expression.LeftCell = 16;
        Expression.RightCell = 17;
        Expression.AllowBlink = false;
        _Eyes.Request_PlayExpression(FMars_Request_Eyes_PlayExpression(Expression));
    }

    // Samples the plate in the first poll that sees the resolve.
    UFUNCTION()
    private void Check_ResolvedAndSampled(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        const auto IsResolved = _Eyes.Get_ResolvedLeftCell() == 16 && _Eyes.Get_ResolvedRightCell() == 17;
        if (IsResolved && _PlateLeftWhenResolved.IsSet() == false)
        {
            _PlateLeftWhenResolved = TOptional<float32>(Get_Slot(_Primitive, LeftCellSlot));
            _PlateRightWhenResolved = TOptional<float32>(Get_Slot(_Primitive, RightCellSlot));
        }

        Res.Set(IsResolved);
    }

    UFUNCTION()
    private void Step_AssertSameFrame(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_PlateLeftWhenResolved.IsSet() && _PlateRightWhenResolved.IsSet(), "the plate was sampled when the cells resolved");
        if (_PlateLeftWhenResolved.IsSet() == false)
        { return; }

        Assert_Equals_Float(_PlateLeftWhenResolved.GetValue(), 16.0, 0.001, "the plate's left cell slot held 16 the frame the cell resolved");
        Assert_Equals_Float(_PlateRightWhenResolved.GetValue(), 17.0, 0.001, "the plate's right cell slot held 17 the frame the cell resolved");
    }
}
