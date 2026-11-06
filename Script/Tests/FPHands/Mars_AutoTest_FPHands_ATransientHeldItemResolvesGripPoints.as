// A transient item held in the hand is presented by a Visual-mode world item, and that visual registers the item's grip
// points as grip nodes too: a stowed Cleaver's held visual carries two grip nodes whose offsets from its root are the
// cleaver's resolved points (its mesh sockets turned by the twists), and the gloves' hold - made when the item was
// equipped, before the visual was constructed - has socket grips equal to those nodes placed by HeldOffset. A bare carrier
// (hand chain, a hotbar of two bag slots, HeldItem, the gloves and their held-item link). Isolated origin
// (196000, -93300, -30000).
class UMars_AutoTest_FPHands_ATransientHeldItemResolvesGripPoints : UMars_AutoTestRig_Carrier
{
    default _TimeoutSeconds = 20.0f;

    private const FVector k_Origin = FVector(196000.0, -93300.0, -30000.0);

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Add_CarrierBody(InHandle, k_Origin);
        Add_Hotbar(_Carrier, 2);
        _HeldItem = utils_held_item::Add(_Carrier);
        Add_CarrierHands();
        _Holders.Add(MakeSeededHolder(InHandle, mars_items::Cleaver()));

        Add_Step_WaitUntil("the holder holds its cleaver", n"Check_HoldersSeeded");
        Add_Step_WaitUntil("the gloves rest, listening for a reach", n"Check_CarrierHandsRest", 0, 0);
        Add_Step("stow the cleaver into the hand", n"Step_StowFirst");
        Add_Step_WaitUntil("the cleaver's held visual is a constructed world item and the gloves hold it", n"Check_VisualHeld", 0, 0);
        Add_Step("the visual's grip nodes are the cleaver's points; the hold's socket grips are those nodes", n"Step_AssertVisualGrips");
        Run_Steps(InHandle);
    }

    private FCk_Handle_WorldItem TryGet_Visual() const
    {
        return _HeldItem.Get_PresentationEntity().As_WorldItem(ECk_SanityCheck::UnChecked);
    }

    UFUNCTION()
    private void Check_VisualHeld(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto Visual = TryGet_Visual();
        auto Res = OutResult;
        Res.Set(_HeldItem.Get_CurrentItem() == _Items[0] && ck::IsValid(Visual)
            && _Hands.Get_Hold().Kind != EMars_FPHands_HoldKind::Empty);
    }

    UFUNCTION()
    private void Step_AssertVisualGrips(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Visual = TryGet_Visual();
        FCk_Handle VisualEntity = Visual;
        Assert_True(Visual.Get_Mode() == EMars_WorldItem_Mode::Visual, f"the held presentation is a Visual-mode world item (got {Visual.Get_Mode() :n})");
        Assert_True(VisualEntity.Has_Fragment(FMars_Fragment_FPHands_Grips), "the held visual carries a grip table");
        if (VisualEntity.Has_Fragment(FMars_Fragment_FPHands_Grips) == false)
        { return; }

        const UMars_ItemTrait_Presentation Presentation = _Items[0].Get_Presentation();
        const auto Points = utils_world_item::Get_WorldItemScriptClass(_Items[0]).GetDefaultObject().Resolve_GripPoints(Presentation);
        Assert_True(Points.Right.IsSet() && Points.Left.IsSet(), "the cleaver resolves two points");
        if (Points.Right.IsSet() == false || Points.Left.IsSet() == false)
        { return; }

        auto NodeRight = TOptional<FTransform>();
        auto NodeLeft = TOptional<FTransform>();
        for (const auto& Entry : VisualEntity.Get_Fragment(FMars_Fragment_FPHands_Grips).Entries)
        {
            const auto Offset = TOptional<FTransform>(utils_scene_node::Get_Offset(Entry.Node.As_SceneNode()));
            if (Entry.Hand == EMars_Hand::Right)
            { NodeRight = Offset; }
            else
            { NodeLeft = Offset; }
        }

        Assert_True(NodeRight.IsSet() && NodeRight.GetValue().Equals(Points.Right.GetValue(), 0.001), "the visual's right node is the right point");
        Assert_True(NodeLeft.IsSet() && NodeLeft.GetValue().Equals(Points.Left.GetValue(), 0.001), "the visual's left node is the left point");
        if (NodeRight.IsSet() == false || NodeLeft.IsSet() == false)
        { return; }

        const auto Hold = _Hands.Get_Hold();
        Assert_True(Hold.Kind == EMars_FPHands_HoldKind::TwoHanded, f"the gloves hold it two-handed (got {Hold.Kind :n})");
        Assert_True(Hold.SocketGrips.IsSet(), "the gloves' hold has socket grips");
        if (Hold.SocketGrips.IsSet() == false)
        { return; }

        const auto HeldOffset = Presentation.Mounting.HeldOffset;
        Assert_True(Hold.SocketGrips.GetValue().Right.Equals(NodeRight.GetValue() * HeldOffset, 0.001), "the right socket grip is the visual's right node placed by HeldOffset");
        Assert_True(Hold.SocketGrips.GetValue().Left.Equals(NodeLeft.GetValue() * HeldOffset, 0.001), "the left socket grip is the visual's left node placed by HeldOffset");
    }
}
