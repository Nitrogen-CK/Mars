// The Eyes tests' rig: a face node of its own in the test's isolated Z band, the eyes composed on it, the presentation
// check every eyes test opens with, and the layer clears.
UCLASS(Abstract)
class UMars_AutoTestRig_Eyes : UCk_AutoTest_Base
{
    // A poll budget, not a ceiling: a timed expression or a blink interval runs out on its own clock.
    protected const int32 k_SlowPolls = 900;

    protected FCk_Handle_Eyes _Eyes;

    // The plate's custom primitive data slots (constants_eyes::k_Slot_*), by value.
    protected const int32 LeftCellSlot = constants_eyes::k_Slot_Cells;
    protected const int32 RightCellSlot = constants_eyes::k_Slot_Cells + 1;
    protected const int32 PrevLeftCellSlot = constants_eyes::k_Slot_Cells + 2;
    protected const int32 PrevRightCellSlot = constants_eyes::k_Slot_Cells + 3;
    protected const int32 BlendSlot = constants_eyes::k_Slot_Anim;
    protected const int32 StrengthSlot = constants_eyes::k_Slot_Anim + 3;
    protected const int32 LookXSlot = constants_eyes::k_Slot_Look;
    protected const int32 LookYSlot = constants_eyes::k_Slot_Look + 1;

    // A transform root of its own at InLocation.
    protected FCk_Handle_Transform Make_FaceNode(FCk_Handle InHandle, FVector InLocation)
    {
        auto FaceEntity = utils_entity_lifetime::Request_CreateEntity(InHandle);
        return utils_transform::Add(FaceEntity, FTransform(FRotator::ZeroRotator, InLocation), ECk_Replication::DoesNotReplicate);
    }

    // An engine plane on a node under InFaceNode, made through CkUnrealComponent so its custom primitive data can be read
    // back; no material and no collision (nothing bakes it into the static world).
    protected FCk_Handle_UnrealComponent Make_PlatePrimitive(FCk_Handle_Transform& InFaceNode, FName InDebugName)
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
        FCk_Handle NodeHandle = Node;
        return utils_unreal_component::Add(NodeHandle, ComponentParams);
    }

    protected UPrimitiveComponent Get_PrimitiveComponent(const FCk_Handle_UnrealComponent& InPrimitive) const
    {
        if (ck::Is_NOT_Valid(InPrimitive))
        { return nullptr; }

        return Cast<UPrimitiveComponent>(utils_unreal_component::Get_Component(InPrimitive));
    }

    protected float32 Get_Slot(const FCk_Handle_UnrealComponent& InPrimitive, int32 InIndex) const
    {
        return utils_unreal_component::Get_CustomPrimitiveDataFloat(InPrimitive, InIndex);
    }

    protected bool Get_IsSlot(const FCk_Handle_UnrealComponent& InPrimitive, int32 InIndex, float32 InExpected) const
    {
        return Math::Abs(Get_Slot(InPrimitive, InIndex) - InExpected) < 0.001f;
    }

    // The colour slots (constants_eyes::k_Slot_Color, +1, +2) hold InColor's RGB.
    protected bool Get_IsColor(const FCk_Handle_UnrealComponent& InPrimitive, const FLinearColor& InColor) const
    {
        return Get_IsSlot(InPrimitive, constants_eyes::k_Slot_Color, InColor.R)
            && Get_IsSlot(InPrimitive, constants_eyes::k_Slot_Color + 1, InColor.G)
            && Get_IsSlot(InPrimitive, constants_eyes::k_Slot_Color + 2, InColor.B);
    }

    protected FString Get_ColorText(const FCk_Handle_UnrealComponent& InPrimitive) const
    {
        const auto Slot = constants_eyes::k_Slot_Color;
        return f"{Get_Slot(InPrimitive, Slot)}, {Get_Slot(InPrimitive, Slot + 1)}, {Get_Slot(InPrimitive, Slot + 2)}";
    }

    // Fails the test, and returns false, when the eyes have no presentation in this world.
    protected bool Assert_HasPresentation()
    {
        Assert_Valid(_Eyes, "Add with a valid spec returns a valid handle");
        if (_Eyes.Get_HasPresentation() == false)
        {
            FinishFailure("the eyes have no presentation in this world - Get_CanExecuteCosmeticEvents was false");
            return false;
        }

        return true;
    }

    // What a test asserts in Step_AssertPresentation once the eyes are known to be presented.
    protected void Assert_AfterPresentation()
    {
    }

    UFUNCTION()
    protected void Step_AssertPresentation(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        if (Assert_HasPresentation())
        { Assert_AfterPresentation(); }
    }

    UFUNCTION()
    protected void Step_ClearEmote(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Eyes.Request_ClearExpression(FMars_Request_Eyes_ClearExpression(EMars_Eyes_Layer::Emote));
    }

    UFUNCTION()
    protected void Step_ClearState(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Eyes.Request_ClearExpression(FMars_Request_Eyes_ClearExpression(EMars_Eyes_Layer::State));
    }

    UFUNCTION()
    protected void Check_EmotePlaying(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Eyes.Get_HasEmote());
    }
}
