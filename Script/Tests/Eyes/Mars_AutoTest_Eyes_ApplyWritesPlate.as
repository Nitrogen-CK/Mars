// Once a plate is set, the apply pass writes every group into its custom primitive data (slots 0/1 cells, 7 strength,
// 8/9 look, 10..12 colour); a played expression rewrites the cell slots, keeping the previous cells for the crossfade;
// a new style's colour rewrites the colour slots; and a second plate set later receives every group. The plates are
// bare engine planes; no material is needed to read the data back. Isolated Z band: -68000.
class UMars_AutoTest_Eyes_ApplyWritesPlate : UCk_AutoTest_Base
{
    private FCk_Handle_Eyes _Eyes;
    private FCk_Handle_Transform _FaceNode;
    private FCk_Handle_UnrealComponent _Plate;
    private FCk_Handle_UnrealComponent _SecondPlate;

    private FLinearColor _StyleColor = FLinearColor(1.0f, 0.78f, 0.45f, 1.0f);
    private FLinearColor _NewStyleColor = FLinearColor(0.2f, 0.4f, 0.9f, 1.0f);

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto FaceEntity = utils_entity_lifetime::Request_CreateEntity(InHandle);
        _FaceNode = utils_transform::Add(FaceEntity, FTransform(FRotator::ZeroRotator, FVector(0.0, 0.0, -68000.0)),
            ECk_Replication::DoesNotReplicate);

        auto Spec = FMars_Eyes_Spec();
        Spec.Style.LeftCell = 3;
        Spec.Style.RightCell = 4;
        Spec.Style.EmissiveStrength = 6.0f;
        Spec.Style.Color = _StyleColor;
        Spec.BlinkEnabled = false;
        _Eyes = utils_eyes::Add(_FaceNode, Spec);

        _Plate = MakePlate(_FaceNode, n"EyesTest_Plate");
        _Eyes.Set_Plate(_Plate);

        Add_Step("the eyes have a presentation and a plate", n"Step_AssertComposed");
        Add_Step_WaitUntil("the plate holds left 3, right 4, strength 6", n"Check_StyleWritten");
        Add_Step("the look slots hold no offset and the colour slots the style's colour", n"Step_AssertLookAndColor");
        Add_Step("play Angry (16) until cleared", n"Step_PlayAngry");
        Add_Step_WaitUntil("the plate's cell slots hold 16 and 16", n"Check_AngryWritten");
        Add_Step("the previous cells and the strength are in their slots", n"Step_AssertPrevAndStrength");
        Add_Step("set a style with another colour", n"Step_SetStyleColor");
        Add_Step_WaitUntil("the plate's colour slots hold the new colour", n"Check_NewColorWritten");
        Add_Step("set a second plate", n"Step_SetSecondPlate");
        Add_Step_WaitUntil("the second plate holds every group", n"Check_SecondPlateWritten");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_AssertComposed(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Valid(_Eyes, "utils_eyes::Add returns a valid handle");
        Assert_Valid(_Plate, "the plate component handle");
        if (_Eyes.Get_HasPresentation() == false)
        { FinishFailure("the eyes have no presentation in this world - Get_CanExecuteCosmeticEvents was false"); }
    }

    UFUNCTION()
    private void Check_StyleWritten(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_IsSlot(_Plate, 0, 3.0f) && Get_IsSlot(_Plate, 1, 4.0f) && Get_IsSlot(_Plate, 7, 6.0f));
    }

    UFUNCTION()
    private void Step_AssertLookAndColor(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(Get_IsSlot(_Plate, 8, 0.0f), f"slot 8 holds LookX 0 (got [{Get_Slot(_Plate, 8)}])");
        Assert_True(Get_IsSlot(_Plate, 9, 0.0f), f"slot 9 holds LookY 0 (got [{Get_Slot(_Plate, 9)}])");
        Assert_True(Get_IsColor(_Plate, _StyleColor), f"slots 10..12 hold the style's colour (got [{Get_ColorText(_Plate)}])");
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
        Res.Set(Get_IsSlot(_Plate, 0, 16.0f) && Get_IsSlot(_Plate, 1, 16.0f));
    }

    UFUNCTION()
    private void Step_AssertPrevAndStrength(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(Get_IsSlot(_Plate, 2, 3.0f), f"slot 2 holds the previous left cell 3 (got [{Get_Slot(_Plate, 2)}])");
        Assert_True(Get_IsSlot(_Plate, 3, 4.0f), f"slot 3 holds the previous right cell 4 (got [{Get_Slot(_Plate, 3)}])");
        Assert_True(Get_IsSlot(_Plate, 7, 6.0f), f"slot 7 still holds the strength 6 (got [{Get_Slot(_Plate, 7)}])");
    }

    UFUNCTION()
    private void Step_SetStyleColor(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto NewStyle = _Eyes.Get_Style();
        NewStyle.Color = _NewStyleColor;
        _Eyes.Request_SetStyle(FMars_Request_Eyes_SetStyle(NewStyle));
    }

    UFUNCTION()
    private void Check_NewColorWritten(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_IsColor(_Plate, _NewStyleColor));
    }

    UFUNCTION()
    private void Step_SetSecondPlate(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _SecondPlate = MakePlate(_FaceNode, n"EyesTest_SecondPlate");
        Assert_Valid(_SecondPlate, "the second plate component handle");
        _Eyes.Set_Plate(_SecondPlate);
    }

    // Look stays (0, 0) here, which an unwritten plate also reads; the other groups carry non-zero values.
    UFUNCTION()
    private void Check_SecondPlateWritten(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_IsSlot(_SecondPlate, 0, 16.0f) && Get_IsSlot(_SecondPlate, 1, 16.0f)
            && Get_IsSlot(_SecondPlate, 2, 3.0f) && Get_IsSlot(_SecondPlate, 3, 4.0f)
            && Get_IsSlot(_SecondPlate, 4, 1.0f) && Get_IsSlot(_SecondPlate, 7, 6.0f)
            && Get_IsSlot(_SecondPlate, 8, 0.0f) && Get_IsSlot(_SecondPlate, 9, 0.0f)
            && Get_IsColor(_SecondPlate, _NewStyleColor));
    }

    private float32 Get_Slot(const FCk_Handle_UnrealComponent& InPlate, int32 InIndex) const
    {
        return utils_unreal_component::Get_CustomPrimitiveDataFloat(InPlate, InIndex);
    }

    private bool Get_IsSlot(const FCk_Handle_UnrealComponent& InPlate, int32 InIndex, float32 InExpected) const
    {
        return Math::Abs(Get_Slot(InPlate, InIndex) - InExpected) < 0.001f;
    }

    private bool Get_IsColor(const FCk_Handle_UnrealComponent& InPlate, const FLinearColor& InColor) const
    {
        return Get_IsSlot(InPlate, 10, InColor.R) && Get_IsSlot(InPlate, 11, InColor.G) && Get_IsSlot(InPlate, 12, InColor.B);
    }

    private FString Get_ColorText(const FCk_Handle_UnrealComponent& InPlate) const
    {
        return f"{Get_Slot(InPlate, 10)}, {Get_Slot(InPlate, 11)}, {Get_Slot(InPlate, 12)}";
    }

    // An engine plane under the face node, without collision so nothing bakes it into the static world.
    private FCk_Handle_UnrealComponent MakePlate(FCk_Handle_Transform& InFaceNode, FName InDebugName)
    {
        auto PlateNode = utils_scene_node::Create(InFaceNode, FTransform::Identity);

        auto Archetype = NewObject(this, UStaticMeshComponent);
        // Movable: the component is registered first and then receives the entity transform, which a Static component
        // refuses once the world has begun play.
        Archetype.SetMobility(EComponentMobility::Movable);
        Archetype.SetStaticMesh(Cast<UStaticMesh>(LoadObject(this, "/Engine/BasicShapes/Plane.Plane")));
        Archetype.SetCollisionProfileName(n"NoCollision");

        auto ComponentParams = utils_unreal_component::Make_Params_FromArchetype(
            Archetype, ECk_UnrealComponent_TickPolicy::DoNotTick, InDebugName);
        return utils_unreal_component::Add(FCk_Handle(PlateNode), ComponentParams);
    }
}
