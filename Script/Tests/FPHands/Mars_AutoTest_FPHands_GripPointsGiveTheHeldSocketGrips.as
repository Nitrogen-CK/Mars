// A persistent item's declared grip points give the gloves' hold: the Screaming Turnip's world item carries one grip node
// per point (offset from its root = the point), and utils_fphands::Make_Hold holds it two-handed with socket grips equal
// to each node's offset placed by HeldOffset; the held view (third person) carries the same socket grips. Beside the
// hands rig: a World-mode turnip on a static floor. Isolated origin (199000, -93300, -30000).
class UMars_AutoTest_FPHands_GripPointsGiveTheHeldSocketGrips : UMars_AutoTestRig_Hands
{
    default _TimeoutSeconds = 20.0f;

    private const FVector k_Origin = FVector(199000.0, -93300.0, -30000.0);

    private FCk_Handle _TurnipEntity;
    private FCk_Handle_WorldItem _Turnip;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Owner = InHandle;
        Add_StaticBox(Owner, k_Origin - FVector(0.0, 0.0, 1.0), FVector(80.0, 80.0, 1.0));
        _TurnipEntity = utils_world_item::Request_SpawnWorld(Owner, FMars_WorldItem_WorldSpec(
            utils_held_item::Make_DefinitionSoft(mars_items::ScreamingTurnip()), FTransform(FRotator::ZeroRotator, k_Origin + FVector(0.0, 0.0, 10.0))));

        Add_Step_WaitUntil("the turnip is a world item holding its item", n"Check_TurnipReady", 0, 0);
        Add_Step("its grip nodes are the declared points", n"Step_AssertNodes");
        Add_Step("the hold's socket grips are the nodes placed by HeldOffset", n"Step_AssertHold");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Check_TurnipReady(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto IsReady = ck::IsValid(_TurnipEntity) && _TurnipEntity.Is_WorldItem()
            && ck::IsValid(_TurnipEntity.As_WorldItem().Get_HeldItem());
        if (IsReady && ck::Is_NOT_Valid(_Turnip))
        { _Turnip = _TurnipEntity.As_WorldItem(); }

        auto Res = OutResult;
        Res.Set(IsReady);
    }

    // The grip node of InHand's entry, as its offset from the root; unset when the table has no such entry.
    private TOptional<FTransform> TryGet_NodeOffset(EMars_Hand InHand) const
    {
        for (const auto& Entry : _TurnipEntity.Get_Fragment(FMars_Fragment_FPHands_Grips).Entries)
        {
            if (Entry.Hand == InHand)
            { return TOptional<FTransform>(utils_scene_node::Get_Offset(Entry.Node.As_SceneNode())); }
        }
        return TOptional<FTransform>();
    }

    UFUNCTION()
    private void Step_AssertNodes(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_TurnipEntity.Has_Fragment(FMars_Fragment_FPHands_Grips), "the turnip carries a grip table");
        if (_TurnipEntity.Has_Fragment(FMars_Fragment_FPHands_Grips) == false)
        { return; }

        const UMars_ItemTrait_Presentation Presentation = _Turnip.Get_HeldItem().Get_Presentation();
        Assert_Equals_Int(_TurnipEntity.Get_Fragment(FMars_Fragment_FPHands_Grips).Entries.Num(), 2, "one node per point");
        const auto Right = TryGet_NodeOffset(EMars_Hand::Right);
        const auto Left = TryGet_NodeOffset(EMars_Hand::Left);
        Assert_True(Right.IsSet() && Right.GetValue().Equals(Presentation.Grip.Points.Right.GetValue(), 0.001), "the right node is the right point");
        Assert_True(Left.IsSet() && Left.GetValue().Equals(Presentation.Grip.Points.Left.GetValue(), 0.001), "the left node is the left point");
    }

    UFUNCTION()
    private void Step_AssertHold(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Item = _Turnip.Get_HeldItem();
        const UMars_ItemTrait_Presentation Presentation = Item.Get_Presentation();
        const auto Hold = utils_fphands::Make_Hold(Item);
        Assert_True(Hold.Kind == EMars_FPHands_HoldKind::TwoHanded, f"two-handed (got {Hold.Kind :n})");
        Assert_True(Hold.SocketGrips.IsSet(), "the hold has socket grips");
        const auto Right = TryGet_NodeOffset(EMars_Hand::Right);
        const auto Left = TryGet_NodeOffset(EMars_Hand::Left);
        if (Hold.SocketGrips.IsSet() == false || Right.IsSet() == false || Left.IsSet() == false)
        { return; }

        const auto HeldOffset = Presentation.Mounting.HeldOffset;
        const auto Grips = Hold.SocketGrips.GetValue();
        Assert_True(Grips.Right.Equals(Right.GetValue() * HeldOffset, 0.001), f"the right socket grip [{Grips.Right}] is the right node placed by HeldOffset");
        Assert_True(Grips.Left.Equals(Left.GetValue() * HeldOffset, 0.001), f"the left socket grip [{Grips.Left}] is the left node placed by HeldOffset");

        const auto View = utils_held_view::Make(Item);
        Assert_True(View.Grip.HasSocketGrips, "the held view carries socket grips");
        Assert_True(View.Grip.SocketGrip_R.Equals(Grips.Right, 0.001) && View.Grip.SocketGrip_L.Equals(Grips.Left, 0.001),
            "the held view's socket grips are the gloves'");
    }
}
