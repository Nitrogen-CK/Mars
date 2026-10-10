// Add food brings the joint from the input platter to the board by glove. An empty large platter docks on the input dock
// and is filled by hand through it: a cook (a carrier with gloves: Hotbar, HeldItem, Hand and Back nodes, FPHands and the
// Hands state machine) picks the meat slab up and uses the dock, which offers PlaceFood; the gloves carry the slab over the
// docked platter and it lands there. An operator whose intents read a real add-food key takes the station; the feed already
// draws from the docked platter. Nothing moves until the key is pressed. One press: the feed's glove runs Reach, Grasp,
// Carry, AwaitAdmission, Return and is Idle again, the board admitted it (one admission); the platter is empty and the same
// piece lies on the board at the pile (world XY within 0.5 cm), yawed by its food's layout (within 0.5 deg), no longer riding
// the platter, still shown and still whole, placed once. Isolated origin (16000, -9000, -30000).
class UMars_AutoTest_CuttingStation_AddFoodBringsTheJointToTheBoard : UMars_AutoTestRig_CuttingStation
{
    private const FVector k_Origin = FVector(16000.0, -9000.0, -30000.0);
    // Where the cook stands and its food lies, from the station's origin.
    private const FVector k_CookOffset = FVector(-150.0, -300.0, 0.0);
    private const FVector k_FoodOffset = FVector(-150.0, -150.0, 0.0);

    private FCk_Handle _Cook;
    private FCk_Handle_Transform _CookHand;
    private FCk_Handle_Hotbar _CookHotbar;
    private FCk_Handle_HeldItem _CookHeldItem;
    private FCk_Handle_FPHands _CookHands;

    private FCk_Handle _FoodEntity;
    private FCk_Handle_WorldItem _Slab;
    private FCk_Handle_FoodPiece _Joint;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Spawn_Station(InHandle, k_Origin);
        Arm_AddFoodKey(InHandle);
        _InputPlatterEntity = Spawn_PlatterAt(InHandle, k_InputPlatterOffset, FMars_Platter_SpawnSpec(FTransform::Identity, mars_items::Platter_Large()));
        Build_Cook(InHandle);
        Spawn_Food(InHandle);

        Add_Step_WaitUntil("the station composed its Cutting, FoodBoard, feed and docks", n"Check_StationReady", 0, 5.0f);
        Add_Steps_ArmTheAddFoodKey();
        Add_Step_WaitUntil("the empty input platter is constructed", n"Check_EmptyInputPlatterReady", 0, 10.0f);
        Add_Step_WaitUntil("the food item is constructed and the cook's gloves rest", n"Check_FoodAndCookReady", 0, 10.0f);
        Add_Step("dock the empty platter", n"Step_DockInput");
        Add_Step_WaitUntil("the empty platter is docked", n"Check_InputDocked", 0, 5.0f);
        Add_Step("the cook focuses the slab's pickup", n"Step_FocusFood");
        Add_Step_WaitFrames("the slab's target enters Focused", 3);
        Add_Step("the cook picks the slab up", n"Step_PickUpFood");
        Add_Step_WaitUntil("the slab is Held", n"Check_FoodHeld", 0, 5.0f);
        Add_Step_WaitSeconds("the hold's arrival settles", 0.5f);
        Add_Step("the cook unfocuses the slab and focuses the input dock", n"Step_FocusDock");
        Add_Step_WaitFrames("the dock's prompt follows the cook", 3);
        Add_Step("the dock offers to place the slab; the cook uses it", n"Step_PlaceThroughTheDock");
        Add_Step_WaitUntil("the slab landed and froze on the docked platter", n"Check_OnTheDockedPlatter", 0, 8.0f);
        Add_Step("an operator takes the station", n"Step_Take");
        Add_Step_WaitUntil("the station's state machine is Operated", n"Check_Operated", 0, 2.0f);
        Add_Step_WaitUntil("the feed draws from the docked platter, its joint frozen", n"Check_FeedSourced", 0, 5.0f);
        Add_Step_WaitFrames("a joint taken without a press would have moved by now", 10);
        Add_Step("the joint still waits on the platter, the glove at rest", n"Step_AssertNothingMoved");
        Add_Step("press add food", n"Step_PressAddFood");
        Add_Step_WaitUntil("the press is seen", n"Check_AddFoodHeld", 0, 2.0f);
        Add_Step_WaitUntil("the feed laid one shown joint on the board and the glove is back", n"Check_JointOnBoardAndFeedIdle", 0, 5.0f);
        Add_Step("release add food", n"Step_ReleaseAddFood");
        Add_Step_WaitFrames("a second transfer would have drained by now", 5);
        Add_Step("the platter is empty; the joint lies at the pile in its layout, shown and whole", n"Step_Assert");
        Run_Steps(InHandle);
    }

    // What the player composes for carrying and placing, on an entity of its own under the test.
    private void Build_Cook(FCk_Handle InHandle)
    {
        auto Owner = InHandle;
        _Cook = utils_entity_lifetime::Request_CreateEntity(Owner);
        // Its own context, as the player is: the Hands state machine's ck::Ctx must be the cook, not the test.
        _Cook.Request_OverrideToSelf();
        auto Root = utils_transform::Add(_Cook, FTransform(FRotator::ZeroRotator, k_Origin + k_CookOffset), ECk_Replication::DoesNotReplicate);
        _CookHand = utils_scene_node::Create(Root, FTransform(FRotator::ZeroRotator, FVector(40.0, 20.0, 60.0))).As_Transform();
        auto Back = utils_scene_node::Create(Root, FTransform(FRotator::ZeroRotator, FVector(-30.0, 0.0, 20.0))).As_Transform();

        auto AttachPointsSpec = FMars_AttachPoints_Spec();
        AttachPointsSpec.Points.Add(FMars_AttachPoint_Entry(GameplayTags::AttachPoint_Mars_Hand, _CookHand));
        AttachPointsSpec.Points.Add(FMars_AttachPoint_Entry(GameplayTags::AttachPoint_Mars_Back, Back));
        utils_attach_points::Add(_Cook, AttachPointsSpec);

        auto HotbarSpec = FMars_Hotbar_Spec();
        HotbarSpec.BagSlotCount = 1;
        _CookHotbar = utils_hotbar::Add(_Cook, HotbarSpec);
        _CookHeldItem = utils_held_item::Add(_Cook);

        auto HandsSpec = FMars_FPHands_Spec();
        HandsSpec.HandNode = _CookHand;
        _CookHands = utils_fphands::Add(_Cook, HandsSpec);
        utils_state_machine::Add(_Cook, FCk_StateMachine_Spec(UMars_SmState_Hands_Rest));

        _CookHotbar.BindTo_OnSelectionChanged(FMars_Delegate_Hotbar_OnSelectionChanged(this, n"OnCookSelectionChanged"));
        _CookHotbar.BindTo_OnSlotItemChanged(FMars_Delegate_Hotbar_OnSlotItemChanged(this, n"OnCookSlotItemChanged"));
    }

    // The meat slab's food item on a floor of its own beside the cook.
    private void Spawn_Food(FCk_Handle InHandle)
    {
        Spawn_PlatterFloor(InHandle, k_Origin + k_FoodOffset);

        auto SpawnParams = UMars_FoodItem_EntityScript::Params();
        SpawnParams.SpawnTransform = FTransform(FRotator::ZeroRotator, k_Origin + k_FoodOffset + FVector(0.0, 0.0, 5.0));
        SpawnParams.Definition = utils_held_item::Make_DefinitionSoft(mars_items::Food_MeatSlab());
        SpawnParams.Mode = EMars_WorldItem_Mode::World;

        // A piece outlives its spawner: under the world's transient entity, tracked for cleanup.
        auto PieceOwner = ck::TransientEntity();
        _FoodEntity = utils_entity_script::Request_SpawnEntity(PieceOwner, UMars_FoodItem_EntityScript, SpawnParams).Get_EntityUnderConstruction();
        Track_ForCleanup(_FoodEntity);
    }

    // What the player HFSM's HotbarDrivesHeldItem task and the player's hold sync do on every hotbar change.
    private void Push_CookSelection()
    {
        _CookHeldItem.Request_SetSlot(FMars_Request_HeldItem_SetSlot(_CookHotbar.Get_SelectedSlot(), _CookHotbar.Get_SelectedItem()));
        _CookHands.Request_SetHold(FMars_Request_FPHands_SetHold(_CookHotbar.Get_SelectedItem()));
    }

    UFUNCTION()
    private void OnCookSelectionChanged(FCk_Handle_Hotbar InHotbar)
    {
        Push_CookSelection();
    }

    UFUNCTION()
    private void OnCookSlotItemChanged(FCk_Handle_Hotbar InHotbar, int32 InIndex, FCk_Handle_Item InMaybeItem)
    {
        Push_CookSelection();
    }

    private FCk_Handle_InteractTarget Get_DockTarget() const
    {
        auto DockInteractable = _InputDock.Get_Interactable();
        return DockInteractable.Get_InteractTarget(GameplayTags::InteractionChannel_Mars_Use);
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Steps
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void Step_FocusFood(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Pickup = _Slab.Get_Pickup();
        Pickup.Request_Focus(FMars_Request_Interactable_Focus(_Cook));
    }

    UFUNCTION()
    private void Step_PickUpFood(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Pickup = _Slab.Get_Pickup();
        auto Target = Pickup.Get_InteractTarget(GameplayTags::InteractionChannel_Mars_Use);
        Target.Request_StartInteraction(FCk_Try_InteractTarget_StartInteraction(_Cook, _Cook));
    }

    UFUNCTION()
    private void Step_FocusDock(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto FoodPickup = _Slab.Get_Pickup();
        FoodPickup.Request_Unfocus(FMars_Request_Interactable_Unfocus(_Cook));

        auto DockInteractable = _InputDock.Get_Interactable();
        DockInteractable.Request_Focus(FMars_Request_Interactable_Focus(_Cook));
    }

    UFUNCTION()
    private void Step_PlaceThroughTheDock(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Action = _InputDock.Get_ActionFor(_Cook);
        Assert_True(Action == EMars_PlatterDock_Action::PlaceFood, f"the input dock offers PlaceFood to a cook holding the slab (got [{Action :n}])");

        auto Target = Get_DockTarget();
        Target.Request_StartInteraction(FCk_Try_InteractTarget_StartInteraction(_Cook, _Cook));
    }

    UFUNCTION()
    private void Step_AssertNothingMoved(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_InputPlatter.Get_HeldCount() == 1 && _InputPlatter.Get_Held()[0] == _Joint, "the joint waits on the input platter");
        Assert_Equals_Int(_Board.Get_HeldCount(), 0, "the board is empty");
        Assert_Equals_Int(_FeedPhases.Num(), 0, "the feed's glove never left its rest");
        Assert_Equals_Int(_Feed.Get_Available(), 1, "the feed counts the joint");
    }

    UFUNCTION()
    private void Step_Assert(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Expected = TArray<EMars_CookingFeed_Phase>();
        Expected.Add(EMars_CookingFeed_Phase::Reach);
        Expected.Add(EMars_CookingFeed_Phase::Grasp);
        Expected.Add(EMars_CookingFeed_Phase::Carry);
        Expected.Add(EMars_CookingFeed_Phase::AwaitAdmission);
        Expected.Add(EMars_CookingFeed_Phase::Return);
        Expected.Add(EMars_CookingFeed_Phase::Idle);
        Assert_Equals_Int(_FeedPhases.Num(), Expected.Num(), "the glove ran one transfer's phases");
        for (int32 Index = 0; Index < Math::Min(_FeedPhases.Num(), Expected.Num()); ++Index)
        { Assert_True(_FeedPhases[Index] == Expected[Index], f"phase {Index} is {Expected[Index] :n} (got {_FeedPhases[Index] :n})"); }

        Assert_Equals_Int(_Feed.Get_Admitted(), 1, "the board admitted the joint");
        Assert_Equals_Int(_FeedRefusals.Num(), 0, "the feed refused nothing");
        Assert_Equals_Int(_InputPlatter.Get_HeldCount(), 0, "the input platter is empty");
        Assert_Equals_Int(_InputPlatter.Get_PendingCount(), 0, "nothing waits to land on the input platter");
        Assert_True(_Board.Get_HeldCount() == 1 && _Board.Get_Held()[0] == _Joint, "the board holds the slab's joint");
        Assert_Equals_Int(_Placed.Num(), 1, "the joint was placed once");
        Assert_True(ck::Is_NOT_Valid(_Joint.TryGet_Platter()), "the joint no longer names a platter");
        Assert_False(ck::IsValid(Get_Parent(_Joint)), "the joint no longer rides the platter");
        Assert_True(_Board.Get_IsUntouched(), "a whole joint on an empty board leaves it untouched");
        Assert_True(_Joint.Get_IsWhole(), "the joint is still whole");
        Assert_True(Get_IsShown(_Joint), "the joint is still shown");

        const auto StationWorld = Get_StationWorld();
        const auto Pile = (utils_cutting::Get_PileLocal() * StationWorld).GetLocation();
        const auto JointWorld = Get_World(_Joint);
        const auto Offset = JointWorld.GetLocation() - Pile;
        Assert_True(Math::Abs(Offset.X) <= 0.5 && Math::Abs(Offset.Y) <= 0.5, f"the joint lies at the pile ({JointWorld.GetLocation()} vs {Pile})");

        const UMars_ItemTrait_Food FoodTrait = mars_items::Food_MeatSlab().Get_ItemTraitByClass(UMars_ItemTrait_Food);
        const auto Yaw = JointWorld.Rotator().Yaw - StationWorld.Rotator().Yaw;
        const auto YawError = Math::Abs(Math::UnwindDegrees(Yaw - FoodTrait.Food.Layout.YawDegrees));
        Assert_True(YawError <= 0.5, f"the joint is yawed by its layout ({Yaw} vs {FoodTrait.Food.Layout.YawDegrees} deg)");
        Assert_True(JointWorld.GetScale3D().Equals(FVector::OneVector, 0.0001), f"the joint is unscaled ({JointWorld.GetScale3D()})");
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Checks
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void Check_EmptyInputPlatterReady(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto IsReady = Get_IsPlatterConstructed(_InputPlatterEntity);
        if (IsReady && ck::Is_NOT_Valid(_InputPlatter))
        {
            _InputPlatter = _InputPlatterEntity.As_Platter();
            _InputPlatterItem = _InputPlatterEntity.As_WorldItem().Get_HeldItem();
        }

        auto Res = OutResult;
        Res.Set(IsReady);
    }

    UFUNCTION()
    private void Check_FoodAndCookReady(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto FoodReady = ck::IsValid(_FoodEntity) && _FoodEntity.Is_WorldItem() && ck::IsValid(_FoodEntity.As_WorldItem().Get_HeldItem());
        if (FoodReady && ck::Is_NOT_Valid(_Slab))
        {
            _Slab = _FoodEntity.As_WorldItem();
            _Joint = _FoodEntity.As_FoodPiece();
        }

        const auto HandsRest = _CookHands.Get_Phase() == EMars_FPHands_Phase::None
            && _CookHands.Has_Fragment(FMars_Fragment_FPHands_Signals)
            && _CookHands.Get_Fragment(FMars_Fragment_FPHands_Signals).OnReachRequested._Inner.IsBound();

        auto Res = OutResult;
        Res.Set(FoodReady && HandsRest);
    }

    UFUNCTION()
    private void Check_FoodHeld(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Node = _Slab.As_SceneNode(ECk_SanityCheck::UnChecked);
        auto Res = OutResult;
        Res.Set(_Slab.Get_Mount() == EMars_WorldItem_Mount::Held && ck::IsValid(Node) && utils_scene_node::Get_Parent(Node) == _CookHand);
    }

    UFUNCTION()
    private void Check_OnTheDockedPlatter(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_InputPlatter.Get_HeldCount() == 1 && _InputPlatter.Get_Held()[0] == _Joint);
    }
}
