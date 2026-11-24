// The grip the body derives from an item describes the same hold the gloves play: for real sandbox items (the Rock, a
// fitted sphere, and the Cleaver, a fitted box) utils_held_view::Make_Grip carries utils_fphands::Make_Hold's grip, and the
// grip targets rebuilt from it (To_Hold -> Get_RestTargets) are the first-person ones. An invalid item makes an empty grip.
class UMars_AutoTest_HeldView_MakeMatchesFPHold : UCk_AutoTest_Base
{
    private FCk_Handle_Inventory_DataOnly _RockHolder;
    private FCk_Handle_Inventory_DataOnly _CleaverHolder;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        _RockHolder = MakeSeededHolder(InHandle, mars_items::Rock());
        _CleaverHolder = MakeSeededHolder(InHandle, mars_items::Cleaver());

        Add_Step_WaitUntil("both holders are seeded with their item", n"Check_Seeded", 0, 0);
        Add_Step("the grip of each item matches its first-person hold", n"Step_AssertViews");
        Add_Step("an invalid item makes an empty grip", n"Step_AssertEmpty");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Check_Seeded(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_RockHolder.Get_NumItems() == 1 && _CleaverHolder.Get_NumItems() == 1);
    }

    UFUNCTION()
    private void Step_AssertViews(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        AssertMatches(_RockHolder.Get_Items()[0], "Rock");
        AssertMatches(_CleaverHolder.Get_Items()[0], "Cleaver");
    }

    UFUNCTION()
    private void Step_AssertEmpty(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Grip = utils_held_view::Make_Grip(FCk_Handle_Item());
        Assert_True(Grip.Kind == EMars_FPHands_HoldKind::Empty, "an invalid item is not held");
    }

    private void AssertMatches(FCk_Handle_Item InItem, const FString& InName)
    {
        Assert_True(InItem.Has_Presentation(), f"{InName} has a Presentation");
        if (InItem.Has_Presentation() == false)
        { return; }

        const auto Hold = utils_fphands::Make_Hold(InItem);
        const auto Grip = utils_held_view::Make_Grip(InItem);

        Assert_True(Grip.Kind != EMars_FPHands_HoldKind::Empty && Hold.Kind != EMars_FPHands_HoldKind::Empty, f"{InName}: the grip and the gloves both hold it");
        Assert_True(Grip.Kind == Hold.Kind, f"{InName}: the hold kind matches ({Grip.Kind :n})");
        Assert_True(Grip.Pose == Hold.Pose, f"{InName}: the grip pose matches");
        Assert_True(Grip.HasSocketGrips == Hold.SocketGrips.IsSet(), f"{InName}: socket grips match");
        Assert_True(Math::Abs(Grip.RightFaceY - Hold.Faces.RightY) < 0.001, f"{InName}: RightFaceY [{Grip.RightFaceY}] matches [{Hold.Faces.RightY}]");
        Assert_True(Math::Abs(Grip.LeftFaceY - Hold.Faces.LeftY) < 0.001, f"{InName}: LeftFaceY [{Grip.LeftFaceY}] matches [{Hold.Faces.LeftY}]");
        if (Grip.HasSocketGrips == false)
        { Assert_True(Grip.RightFaceY > 0.0 && Grip.LeftFaceY < 0.0, f"{InName}: the fitted faces straddle the hand node"); }
        else
        {
            Assert_True(Grip.SocketGrip_R.Equals(Hold.SocketGrips.GetValue().Right, 0.001), f"{InName}: the right socket grip matches the gloves'");
            Assert_True(Grip.SocketGrip_L.Equals(Hold.SocketGrips.GetValue().Left, 0.001), f"{InName}: the left socket grip matches the gloves'");
        }

        const auto Spec = FMars_FPHands_Spec();
        const auto Expected = utils_fphands::Get_RestTargets(Spec.Rest, Hold, FMars_FPHands_TargetFrame());
        const auto Rebuilt = utils_held_view::Get_GripTargets(Spec, Grip);
        Assert_True(Rebuilt.Right.Equals(Expected.Right.GripInHand, 0.001), f"{InName}: the rebuilt right grip is the gloves' [{Expected.Right.GripInHand}]");
        Assert_True(Rebuilt.Left.Equals(Expected.Left.GripInHand, 0.001), f"{InName}: the rebuilt left grip is the gloves' [{Expected.Left.GripInHand}]");
    }

    private FCk_Handle_Inventory_DataOnly MakeSeededHolder(FCk_Handle InHandle, UCk_InventoryItem_Definition InDefinition)
    {
        auto HolderOwner = utils_entity_lifetime::Request_CreateEntity(InHandle);
        auto Params = utils_inventory_data_only::Make_Params_Bounded(
            GameplayTags::Inventory_Mars_WorldItemHolder, 1,
            FCk_Delegate_Inventory_CustomCanAcceptItem_Dynamic(),
            FCk_Delegate_Inventory_CustomCanStackItems_Dynamic());
        auto Holder = utils_inventory_data_only::Add(HolderOwner, Params, ECk_Replication::DoesNotReplicate);

        auto Request = FCk_Request_Inventory_AddItemByDefinition(InDefinition, 1);
        Request.Set_Policy(ECk_Inventory_AddPolicy::ForceNewItem);
        Holder.Request_AddItemByDefinition(Request, FCk_Delegate_Inventory_OnOperationResult_AddByDefinition());
        return Holder;
    }
}
