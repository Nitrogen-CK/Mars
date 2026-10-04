// Set_PlateComponent draws the look on a primitive's material slot (as the chef body's M_EyePlate slot does): the apply
// pass writes every group straight into that primitive's custom primitive data (slots 0/1 cells, 7 strength, 8/9 look,
// 10..12 colour), and a played expression rewrites the cell slots, keeping the previous cells for the crossfade. A
// CkUnrealComponent plate set afterwards takes over (a new style's colour reaches it and not the component), and a plate
// component that is destroyed under the eyes is skipped until the next one, which receives every group. The primitives
// are bare engine planes made through CkUnrealComponent so their data can be read back; no material is needed. Isolated
// Z band: -69000.
class UMars_AutoTest_Eyes_ApplyWritesComponentPlate : UCk_AutoTest_Base
{
    private FCk_Handle_Eyes _Eyes;
    private FCk_Handle_Transform _FaceNode;
    private FCk_Handle_UnrealComponent _Primitive;
    private FCk_Handle_UnrealComponent _Plate;
    private FCk_Handle_UnrealComponent _DoomedPrimitive;
    // Weak, as the eyes hold it: reads null once the component is destroyed.
    private TWeakObjectPtr<UPrimitiveComponent> _DoomedComponent;
    private FCk_Handle_UnrealComponent _LastPrimitive;

    private FLinearColor _StyleColor = FLinearColor(1.0f, 0.78f, 0.45f, 1.0f);
    private FLinearColor _NewStyleColor = FLinearColor(0.2f, 0.4f, 0.9f, 1.0f);

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto FaceEntity = utils_entity_lifetime::Request_CreateEntity(InHandle);
        _FaceNode = utils_transform::Add(FaceEntity, FTransform(FRotator::ZeroRotator, FVector(0.0, 0.0, -69000.0)),
            ECk_Replication::DoesNotReplicate);

        auto Spec = FMars_Eyes_Spec();
        Spec.Style.LeftCell = 3;
        Spec.Style.RightCell = 4;
        Spec.Style.EmissiveStrength = 6.0f;
        Spec.Style.Color = _StyleColor;
        Spec.BlinkEnabled = false;
        _Eyes = utils_eyes::Add(_FaceNode, Spec);

        _Primitive = MakePrimitive(_FaceNode, n"EyesTest_Primitive");

        Add_Step("the eyes have a presentation", n"Step_AssertComposed");
        Add_Step_WaitUntil("the primitive's component exists", n"Check_PrimitiveExists");
        Add_Step("set the primitive's slot 0 as the plate component", n"Step_SetPlateComponent");
        Add_Step_WaitUntil("the primitive holds left 3, right 4, strength 6", n"Check_StyleWritten");
        Add_Step("the blend, look and colour slots", n"Step_AssertLookAndColor");
        Add_Step("play Angry (16) until cleared", n"Step_PlayAngry");
        Add_Step_WaitUntil("the primitive's cell slots hold 16 and 16", n"Check_AngryWritten");
        Add_Step("the previous cells and the strength are in their slots", n"Step_AssertPrevAndStrength");
        Add_Step("set a CkUnrealComponent plate", n"Step_SetPlate");
        Add_Step_WaitUntil("the plate holds every group", n"Check_PlateWritten");
        Add_Step("set a style with another colour", n"Step_SetStyleColor");
        Add_Step_WaitUntil("the plate's colour slots hold the new colour", n"Check_NewColorOnPlate");
        Add_Step("the primitive kept the old colour", n"Step_AssertPrimitiveKeptColor");
        Add_Step("make a primitive to destroy", n"Step_MakeDoomedPrimitive");
        Add_Step_WaitUntil("its component exists", n"Check_DoomedPrimitiveExists");
        Add_Step("set it as the plate component, then remove it", n"Step_SetAndRemoveDoomed");
        Add_Step_WaitUntil("its component is destroyed", n"Check_DoomedPrimitiveGone");
        Add_Step("play Happy (9) with nothing to draw on", n"Step_PlayHappy");
        Add_Step_WaitFrames("the apply pass runs over the stale plate component", 5);
        Add_Step("make the last primitive", n"Step_MakeLastPrimitive");
        Add_Step_WaitUntil("its component exists", n"Check_LastPrimitiveExists");
        Add_Step("set it as the plate component", n"Step_SetLastPlateComponent");
        Add_Step_WaitUntil("the last primitive holds every group", n"Check_LastPrimitiveWritten");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_AssertComposed(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Valid(_Eyes, "utils_eyes::Add returns a valid handle");
        Assert_Valid(_Primitive, "the primitive's component handle");
        if (_Eyes.Get_HasPresentation() == false)
        { FinishFailure("the eyes have no presentation in this world - Get_CanExecuteCosmeticEvents was false"); }
    }

    UFUNCTION()
    private void Check_PrimitiveExists(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(ck::IsValid(Get_PrimitiveComponent(_Primitive)));
    }

    UFUNCTION()
    private void Step_SetPlateComponent(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Eyes.Set_PlateComponent(Get_PrimitiveComponent(_Primitive), 0);
    }

    UFUNCTION()
    private void Check_StyleWritten(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_IsSlot(_Primitive, 0, 3.0f) && Get_IsSlot(_Primitive, 1, 4.0f) && Get_IsSlot(_Primitive, 7, 6.0f));
    }

    UFUNCTION()
    private void Step_AssertLookAndColor(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(Get_IsSlot(_Primitive, 4, 1.0f), f"slot 4 holds the settled blend 1 (got [{Get_Slot(_Primitive, 4)}])");
        Assert_True(Get_IsSlot(_Primitive, 8, 0.0f), f"slot 8 holds LookX 0 (got [{Get_Slot(_Primitive, 8)}])");
        Assert_True(Get_IsSlot(_Primitive, 9, 0.0f), f"slot 9 holds LookY 0 (got [{Get_Slot(_Primitive, 9)}])");
        Assert_True(Get_IsColor(_Primitive, _StyleColor),
            f"slots 10..12 hold the style's colour (got [{Get_ColorText(_Primitive)}])");
    }

    UFUNCTION()
    private void Step_PlayAngry(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Angry = FMars_Eyes_ExpressionDef();
        Angry.LeftCell = 16;
        Angry.RightCell = 16;
        Angry.AllowBlink = false;
        _Eyes.Request_PlayExpression(FMars_Request_Eyes_PlayExpression(Angry));
    }

    UFUNCTION()
    private void Check_AngryWritten(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_IsSlot(_Primitive, 0, 16.0f) && Get_IsSlot(_Primitive, 1, 16.0f));
    }

    UFUNCTION()
    private void Step_AssertPrevAndStrength(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(Get_IsSlot(_Primitive, 2, 3.0f), f"slot 2 holds the previous left cell 3 (got [{Get_Slot(_Primitive, 2)}])");
        Assert_True(Get_IsSlot(_Primitive, 3, 4.0f), f"slot 3 holds the previous right cell 4 (got [{Get_Slot(_Primitive, 3)}])");
        Assert_True(Get_IsSlot(_Primitive, 7, 6.0f), f"slot 7 still holds the strength 6 (got [{Get_Slot(_Primitive, 7)}])");
    }

    UFUNCTION()
    private void Step_SetPlate(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Plate = MakePrimitive(_FaceNode, n"EyesTest_Plate");
        Assert_Valid(_Plate, "the plate component handle");
        _Eyes.Set_Plate(_Plate);
    }

    UFUNCTION()
    private void Check_PlateWritten(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_IsSlot(_Plate, 0, 16.0f) && Get_IsSlot(_Plate, 1, 16.0f) && Get_IsSlot(_Plate, 7, 6.0f)
            && Get_IsColor(_Plate, _StyleColor));
    }

    UFUNCTION()
    private void Step_SetStyleColor(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto NewStyle = _Eyes.Get_Style();
        NewStyle.Color = _NewStyleColor;
        _Eyes.Request_SetStyle(FMars_Request_Eyes_SetStyle(NewStyle));
    }

    UFUNCTION()
    private void Check_NewColorOnPlate(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_IsColor(_Plate, _NewStyleColor));
    }

    UFUNCTION()
    private void Step_AssertPrimitiveKeptColor(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(Get_IsColor(_Primitive, _StyleColor),
            f"the replaced plate component keeps the old colour (got [{Get_ColorText(_Primitive)}])");
    }

    UFUNCTION()
    private void Step_MakeDoomedPrimitive(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _DoomedPrimitive = MakePrimitive(_FaceNode, n"EyesTest_DoomedPrimitive");
        Assert_Valid(_DoomedPrimitive, "the doomed primitive's component handle");
    }

    UFUNCTION()
    private void Check_DoomedPrimitiveExists(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(ck::IsValid(Get_PrimitiveComponent(_DoomedPrimitive)));
    }

    UFUNCTION()
    private void Step_SetAndRemoveDoomed(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _DoomedComponent = Get_PrimitiveComponent(_DoomedPrimitive);
        _Eyes.Set_PlateComponent(_DoomedComponent.Get(), 0);
        utils_unreal_component::Request_Remove(_DoomedPrimitive);
    }

    UFUNCTION()
    private void Check_DoomedPrimitiveGone(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(ck::Is_NOT_Valid(_DoomedComponent.Get()));
    }

    UFUNCTION()
    private void Step_PlayHappy(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Happy = FMars_Eyes_ExpressionDef();
        Happy.LeftCell = 9;
        Happy.RightCell = 9;
        Happy.AllowBlink = false;
        _Eyes.Request_PlayExpression(FMars_Request_Eyes_PlayExpression(Happy));
    }

    UFUNCTION()
    private void Step_MakeLastPrimitive(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Eyes.Get_ResolvedLeftCell(), 9, "Happy resolved while there was nothing to draw on");
        _LastPrimitive = MakePrimitive(_FaceNode, n"EyesTest_LastPrimitive");
        Assert_Valid(_LastPrimitive, "the last primitive's component handle");
    }

    UFUNCTION()
    private void Check_LastPrimitiveExists(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(ck::IsValid(Get_PrimitiveComponent(_LastPrimitive)));
    }

    UFUNCTION()
    private void Step_SetLastPlateComponent(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Eyes.Set_PlateComponent(Get_PrimitiveComponent(_LastPrimitive), 0);
    }

    // Look stays (0, 0) here, which an unwritten primitive also reads; the other groups carry non-zero values.
    UFUNCTION()
    private void Check_LastPrimitiveWritten(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_IsSlot(_LastPrimitive, 0, 9.0f) && Get_IsSlot(_LastPrimitive, 1, 9.0f)
            && Get_IsSlot(_LastPrimitive, 2, 16.0f) && Get_IsSlot(_LastPrimitive, 3, 16.0f)
            && Get_IsSlot(_LastPrimitive, 7, 6.0f)
            && Get_IsSlot(_LastPrimitive, 8, 0.0f) && Get_IsSlot(_LastPrimitive, 9, 0.0f)
            && Get_IsColor(_LastPrimitive, _NewStyleColor));
    }

    // Null while the component is not created yet or after it was removed.
    private UPrimitiveComponent Get_PrimitiveComponent(const FCk_Handle_UnrealComponent& InPrimitive) const
    {
        if (ck::Is_NOT_Valid(InPrimitive))
        { return nullptr; }

        return Cast<UPrimitiveComponent>(utils_unreal_component::Get_Component(InPrimitive));
    }

    private float32 Get_Slot(const FCk_Handle_UnrealComponent& InPrimitive, int32 InIndex) const
    {
        return utils_unreal_component::Get_CustomPrimitiveDataFloat(InPrimitive, InIndex);
    }

    private bool Get_IsSlot(const FCk_Handle_UnrealComponent& InPrimitive, int32 InIndex, float32 InExpected) const
    {
        return Math::Abs(Get_Slot(InPrimitive, InIndex) - InExpected) < 0.001f;
    }

    private bool Get_IsColor(const FCk_Handle_UnrealComponent& InPrimitive, const FLinearColor& InColor) const
    {
        return Get_IsSlot(InPrimitive, 10, InColor.R) && Get_IsSlot(InPrimitive, 11, InColor.G)
            && Get_IsSlot(InPrimitive, 12, InColor.B);
    }

    private FString Get_ColorText(const FCk_Handle_UnrealComponent& InPrimitive) const
    {
        return f"{Get_Slot(InPrimitive, 10)}, {Get_Slot(InPrimitive, 11)}, {Get_Slot(InPrimitive, 12)}";
    }

    // An engine plane under the face node, without collision so nothing bakes it into the static world.
    private FCk_Handle_UnrealComponent MakePrimitive(FCk_Handle_Transform& InFaceNode, FName InDebugName)
    {
        auto Node = utils_scene_node::Create(InFaceNode, FTransform::Identity);

        auto Archetype = NewObject(this, UStaticMeshComponent);
        // Movable: the component is registered first and then receives the entity transform, which a Static component
        // refuses once the world has begun play.
        Archetype.SetMobility(EComponentMobility::Movable);
        Archetype.SetStaticMesh(Cast<UStaticMesh>(LoadObject(this, "/Engine/BasicShapes/Plane.Plane")));
        Archetype.SetCollisionProfileName(n"NoCollision");

        auto ComponentParams = utils_unreal_component::Make_Params_FromArchetype(
            Archetype, ECk_UnrealComponent_TickPolicy::DoNotTick, InDebugName);
        return utils_unreal_component::Add(FCk_Handle(Node), ComponentParams);
    }
}
