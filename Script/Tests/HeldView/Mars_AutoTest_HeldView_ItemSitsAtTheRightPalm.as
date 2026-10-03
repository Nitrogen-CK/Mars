// The body holds the item where the gloves do: for the sandbox Rock (a fitted two-handed sphere, HeldOffset identity) the
// right grip sits PalmSurfaceOffset outside the item's right face, the item relative to that grip
// (utils_held_view::Get_ItemInGrip) composed back with the grip reproduces HeldOffset, the item's centre is
// RightFaceY + PalmSurfaceOffset from the palm, and the body component's transform under a grip bone carrying the body's
// scale (Get_BodyItemTransform) puts the item at the same place and size as first person.
class UMars_AutoTest_HeldView_ItemSitsAtTheRightPalm : UCk_AutoTest_Base
{
    private FCk_Handle_Inventory_DataOnly _RockHolder;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        _RockHolder = MakeSeededHolder(InHandle, mars_items::Rock());

        Add_Step_WaitUntil("the holder is seeded with a rock", n"Check_Seeded", 0, 5.0f);
        Add_Step("the rock sits between the palms, relative to the right grip as in first person", n"Step_AssertItemInGrip");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Check_Seeded(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_RockHolder.Get_NumItems() == 1);
    }

    UFUNCTION()
    private void Step_AssertItemInGrip(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto View = utils_held_view::Make(_RockHolder.Get_Items()[0]);
        Assert_True(View.IsHolding && View.Grip.IsTwoHanded && View.Grip.HasSocketGrips == false,
            "the rock is a fitted two-handed hold");
        Assert_True(View.HeldOffset.Equals(FTransform::Identity), "the rock's HeldOffset is identity (centred on the hand node)");

        const auto Spec = FMars_FPHands_Spec();
        const auto Grips = utils_held_view::Get_GripTargets(Spec, View.Grip);
        const auto PalmGap = Grips.Right.GetLocation().Y - View.Grip.RightFaceY;
        Assert_True(Math::Abs(PalmGap - Spec.PalmSurfaceOffset) < 0.001,
            f"the right grip sits PalmSurfaceOffset [{Spec.PalmSurfaceOffset}] outside the right face (gap {PalmGap})");

        const auto ItemInGrip = utils_held_view::Get_ItemInGrip(Spec, View);
        const auto Composed = ItemInGrip * Grips.Right;
        Assert_True(Composed.Equals(View.HeldOffset, 0.001), f"item-in-grip composed with the right grip is HeldOffset (got [{Composed}])");

        const auto Reach = ItemInGrip.GetLocation().Size();
        const auto Expected = View.Grip.RightFaceY + Spec.PalmSurfaceOffset;
        Assert_True(Math::Abs(Reach - Expected) < 0.001, f"the rock's centre is RightFaceY + PalmSurfaceOffset [{Expected}] from the palm (got {Reach})");
        // The palm (grip Z) faces the item: its centre is on the palm side of the grip.
        Assert_True(ItemInGrip.GetLocation().Z > 0.5 * Reach, f"the rock is on the palm side of the right grip ([{ItemInGrip.GetLocation()}])");

        // On the body the component hangs under grip_r, which carries the body's scale.
        const auto BodyScale = 1.0969f;
        const auto BodyItem = utils_held_view::Get_BodyItemTransform(ItemInGrip, View.MeshScale, BodyScale);
        const auto GripBone = FTransform(Grips.Right.GetRotation(), Grips.Right.GetLocation(), FVector(BodyScale, BodyScale, BodyScale));
        const auto OnBody = BodyItem * GripBone;
        Assert_True(OnBody.GetLocation().Equals(View.HeldOffset.GetLocation(), 0.001), f"the body item sits where the first-person item does (got [{OnBody.GetLocation()}])");
        Assert_True(OnBody.GetScale3D().Equals(View.MeshScale, 0.001), f"the body item keeps the item's world size (got [{OnBody.GetScale3D()}])");
    }

    private FCk_Handle_Inventory_DataOnly MakeSeededHolder(FCk_Handle InHandle, UCk_InventoryItem_Definition InDefinition)
    {
        auto HolderOwner = utils_entity_lifetime::Request_CreateEntity(InHandle);
        auto Params = utils_inventory_data_only::Make_Params_Bounded(
            utils_gameplay_tag::ResolveGameplayTag(n"Inventory.Mars.WorldItemHolder"), 1,
            FCk_Delegate_Inventory_CustomCanAcceptItem_Dynamic(),
            FCk_Delegate_Inventory_CustomCanStackItems_Dynamic());
        auto Holder = utils_inventory_data_only::Add(HolderOwner, Params, ECk_Replication::DoesNotReplicate);

        auto Request = FCk_Request_Inventory_AddItemByDefinition(InDefinition, 1);
        Request.Set_Policy(ECk_Inventory_AddPolicy::ForceNewItem);
        Holder.Request_AddItemByDefinition(Request, FCk_Delegate_Inventory_OnOperationResult_AddByDefinition());
        return Holder;
    }
}
