// The actual free-roam interaction, held-use and book tasks. Production shared keys mint separate Mapped identities;
// the private stack models those identities with separate keys and injects both level rows in the same sample frame.
class UMars_AutoTestState_CookbookPlayerPath : UCk_SmState_EntityScript
{
    UFUNCTION(BlueprintOverride)
    void DoDefineState(FCk_Handle_SmState_UnderConstruction& InHandle)
    {
        AddTask(InHandle, UMars_SmTask_InteractionFocus);
        AddTask(InHandle, UMars_SmTask_UseIntentToResolver);
        AddTask(InHandle, UMars_SmTask_PrimaryIntentToResolver);
        AddTask(InHandle, UMars_SmTask_HeldItemDrivesHands);
        AddTask(InHandle, UMars_SmTask_HandsSubSm);
        AddTask(InHandle, UMars_SmTask_HeldItemDrivesUse);
        AddTask(InHandle, UMars_SmTask_CookbookIntents);
        AddTask(InHandle, UMars_SmTask_EmoteWheelIntent);
    }
}

UCLASS(Abstract)
class UMars_AutoTestRig_Cookbook : UMars_AutoTestRig_PlayerPath
{
    default _TimeoutSeconds = 35.0f;

    protected FCk_Handle_WorldItem _WorldBook;
    protected UMars_CookbookPresentationComponent _Book;
    protected UMars_CookbookPresentationComponent _BookPresentation;
    protected FCk_Handle_Item _BookItem;
    protected FCk_Handle_HeldItemUse _BookUse;
    protected FCk_Handle_EmoteWheel _Wheel;

    protected void Build_Cookbook(FCk_Handle InHandle, FVector InOrigin)
    {
        Build_PlayerPath(InHandle, InOrigin);
        _BookUse = utils_held_item_use::Add(_Carrier);
        _Wheel = utils_emote_wheel::Add(_Carrier, mars::Mars_PlayerCharacter_Config.EmoteWheel);
        _PathRockEntity = Spawn_WorldItem(InHandle, mars_items::Cookbook(), FVector(120.0, 0.0, 8.0));
    }

    protected TSubclassOf<UCk_SmState_EntityScript> Get_RigStateClass() const override
    { return UMars_AutoTestState_CookbookPlayerPath; }

    protected FCk_InteractionResolver_Spec Make_ResolverSpec() const override
    { return mars::Mars_PlayerCharacter_Config.InteractionResolver; }

    protected TArray<FMars_AutoTestHelper_KeyRow> Get_ExtraKeyRows() const override
    {
        TArray<FMars_AutoTestHelper_KeyRow> Rows;
        Rows.Add(FMars_AutoTestHelper_KeyRow(EKeys::F10, GameplayTags::Mars_Intent_Interact_Primary, n"IP"));
        Rows.Add(FMars_AutoTestHelper_KeyRow(EKeys::Q, utils_cookbook::Get_PreviousIntent(), n"BP"));
        Rows.Add(FMars_AutoTestHelper_KeyRow(EKeys::E, utils_cookbook::Get_NextIntent(), n"BN"));
        Rows.Add(FMars_AutoTestHelper_KeyRow(EKeys::F11, GameplayTags::Mars_Intent_EmoteWheel, n"EM"));
        return Rows;
    }

    protected void Add_Steps_PickupAndOpen()
    {
        Add_Steps_UntilReady();
        Add_Step_WaitUntil("the physical cookbook rests on the floor", n"Check_PathRockStill", 0, 0);
        Add_Step("aim the real interaction trace at the book", n"Step_AimAtBook");
        Add_Step_WaitUntil("the book's pickup is focused", n"Check_BookFocused", 0, 0);
        Add_Step("tap Primary and Use together to pick up the book", n"Step_TapPrimary");
        Add_Step_WaitUntil("the same book is held, the skeletal presentation is ready and the gloves rest", n"Check_BookHeld", 0, 0);
        Add_Step("closed gloves and visual use the closed proxy frame", n"Step_AssertClosedGeometry");
        Add_Step("look away from world prompts", n"Step_LookAway");
        Add_Step_WaitFrames("the trace leaves the book", 4);
        Add_Step("tap Primary to open the held book", n"Step_TapPrimary");
        Add_Step_WaitUntil("the book is fully open", n"Check_BookOpen", 0, 0);
        Add_Step_WaitFrames("reading geometry reaches the component and hands", 4);
        Add_Step("open gloves flank the recentered pages", n"Step_AssertOpenGeometry");
    }

    UFUNCTION()
    protected void Step_AimAtBook(FCk_Handle InHandle, FInstancedStruct InPayload)
    { Aim_ViewAt(_PathRockLastLocation.GetValue()); }

    UFUNCTION()
    protected void Check_BookFocused(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(ck::IsValid(_PathRock) && _PathRock.Get_Pickup().Get_IsFocused());
    }

    UFUNCTION()
    protected void Step_TapPrimary(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _UseKey.Press();
        _UseKey.Press_Row(GameplayTags::Mars_Intent_Interact_Primary);
        _UseKey.Release();
        _UseKey.Release_Row(GameplayTags::Mars_Intent_Interact_Primary);
    }

    UFUNCTION()
    protected void Check_BookHeld(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        _WorldBook = _PathRock;
        _Book = utils_cookbook::TryGet_HeldBook(_Carrier);
        _BookPresentation = _Book;

        _BookItem = _HeldItem.Get_CurrentItem();
        auto Result = OutResult;
        Result.Set(ck::IsValid(_WorldBook) && ck::IsValid(_Book) && ck::IsValid(_BookPresentation)
            && _WorldBook.Get_Mount() == EMars_WorldItem_Mount::Held
            && _HeldItem.Get_PresentationEntity() == _WorldBook
            && _Hands.Get_Phase() == EMars_FPHands_Phase::None);
    }

    UFUNCTION()
    protected void Step_LookAway(FCk_Handle InHandle, FInstancedStruct InPayload)
    { Aim_ViewAt(_Origin + FVector(0.0, 200.0, _EyeHeight)); }

    UFUNCTION()
    protected void Check_BookOpen(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(ck::IsValid(_BookPresentation) && _BookPresentation.Get_IsOpen() && _BookPresentation.Get_IsTransitioning() == false);
    }

    UFUNCTION()
    protected void Check_BookClosed(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(ck::IsValid(_BookPresentation) && _BookPresentation.Get_IsOpen() == false && _BookPresentation.Get_IsTransitioning() == false);
    }

    UFUNCTION()
    protected void Step_AssertClosedGeometry(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Hold = _Hands.Get_Hold();
        Assert_True(Math::IsNearlyEqual(Hold.Faces.RightY, 11.4444, 0.02), "closed gloves fit the 20 percent larger proxy");
        Assert_True(_WorldBook.Get_BoundsFit().HalfExtents.Equals(FVector(11.4444, 16.0175832, 1.684704), 0.02),
            "physical pickup fit spans the 20 percent larger closed book");
        Assert_True(Hold.Shape.Scale.Equals(FVector(1.2, 1.2, 1.2), 0.001), "finger contact uses the physical mesh scale");
        Assert_True(_BookPresentation.GetWorldTransform().GetScale3D().Equals(FVector(1.2, 1.2, 1.2), 0.001),
            "the native skeletal visual matches the scaled physical proxy");
        Assert_False(Hold.SocketGrips.IsSet(), "closed hands regain the ordinary side grips");
        const auto RootWorld = utils_transform::Get_EntityCurrentTransform(_WorldBook.As_Transform());
        Assert_True(_BookPresentation.GetWorldLocation().Equals(RootWorld.GetLocation(), 0.05), "closed visual returns to its original mount origin");
        auto ComponentHandle = utils_unreal_component::TryGet_OwningHandle_FromComponent(_BookPresentation);
        Assert_True(utils_unreal_component::Get_CanEnableTransformPush(ComponentHandle), "the hosted skeletal component accepts authoritative transform ownership");
        const auto VisualOwner = utils_unreal_component::Get_OwningEntity(ComponentHandle).As_SceneNode();
        Assert_True(utils_scene_node::Get_Parent(VisualOwner) == _WorldBook, "the reverse component bridge resolves the dedicated visual child of this book");
    }

    UFUNCTION()
    protected void Step_AssertOpenGeometry(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Hold = _Hands.Get_Hold();
        Assert_True(Math::IsNearlyEqual(Hold.Faces.RightY, 21.7872, 0.001), "open hold spans both enlarged covers");
        Assert_True(Hold.Pose == EMars_HandGripPose::Cradle, "the authored Cradle fingers remain selected");
        Assert_True(Hold.SocketGrips.IsSet(), "reading provides explicit unobstructed page-edge grips");
        if (Hold.SocketGrips.IsSet())
        {
            const auto Right = Hold.SocketGrips.GetValue().Right.GetLocation();
            const auto Expected = _BookPresentation.ReadingHandOffset + FVector(0.0,
                21.7872 + _Hands.Get_Spec().Rest.PalmSurfaceOffset, -_BookPresentation.ReadingGripBelowCentre);
            Assert_True(Right.Equals(Expected, 0.01), "the right glove sits below the outer reading edge");
        }
        const auto RootWorld = utils_transform::Get_EntityCurrentTransform(_WorldBook.As_Transform());
        const auto LocalVisual = RootWorld.InverseTransformPosition(_BookPresentation.GetWorldLocation());
        const auto ClosedHold = utils_fphands::Make_Hold(_BookItem);
        const auto ExpectedOffset = FVector(10.3428, 0.0, 0.0)
            + ClosedHold.HeldOffset.InverseTransformVector(_BookPresentation.ReadingHandOffset);
        Assert_True(LocalVisual.Equals(ExpectedOffset, 0.05), f"the visual shifts about the spine and toward the reading position once: actual [{LocalVisual}], expected [{ExpectedOffset}]");
        const auto HandWorld = utils_transform::Get_EntityCurrentTransform(_Hands.Get_Spec().HandNode);
        const auto Normal = RootWorld.TransformVector(FVector::UpVector);
        Assert_True(Normal.Equals(-HandWorld.TransformVector(FVector::ForwardVector), 0.01), "the page normal faces the player");
    }
}
