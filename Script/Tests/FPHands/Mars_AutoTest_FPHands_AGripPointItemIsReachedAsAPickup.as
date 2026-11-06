// An item that declares grip points (the Screaming Turnip's Grip.Points) is reached through its grip nodes as a pickup:
// the target carries the pickup facts (the Presentation's proxy mesh, MeshScale and Sphere shape, the Cradle contact
// pose), is Authored, anchors both gloves to the item's root and puts each glove on its declared point. With the right
// glove holding something the free left glove takes the right point alone. Beside the hands rig: a World-mode turnip on a
// static floor. Isolated origin (198000, -93300, -30000).
class UMars_AutoTest_FPHands_AGripPointItemIsReachedAsAPickup : UMars_AutoTestRig_Hands
{
    default _TimeoutSeconds = 20.0f;

    private const FVector k_Origin = FVector(198000.0, -93300.0, -30000.0);

    private FCk_Handle _TurnipEntity;
    private FCk_Handle_WorldItem _Turnip;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Owner = InHandle;
        Add_StaticBox(Owner, k_Origin - FVector(0.0, 0.0, 1.0), FVector(80.0, 80.0, 1.0));
        _TurnipEntity = utils_world_item::Request_SpawnWorld(Owner, FMars_WorldItem_WorldSpec(
            utils_held_item::Make_DefinitionSoft(mars_items::ScreamingTurnip()), FTransform(FRotator(0.0, -40.0, 0.0), k_Origin + FVector(0.0, 0.0, 10.0))));

        Add_Step_WaitUntil("the turnip is a world item holding its item", n"Check_TurnipReady", 0, 0);
        Add_Step("an empty-handed reach is an Authored pickup on the declared points", n"Step_AssertEmptyHanded");
        Add_Step("with the right glove busy the left glove takes the right point", n"Step_AssertRightBusy");
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

    private TOptional<FMars_FPHands_ReachTarget> Resolve(EMars_FPHands_HoldKind InHeld) const
    {
        auto Held = FMars_FPHands_Hold();
        Held.Kind = InHeld;
        const auto HandState = FMars_FPHands_HandState(Held, FTransform::Identity, EMars_Hand::Right);
        const auto Query = FMars_FPHands_ReachQuery(FMars_FPHands_ReachSubject(_Turnip.Get_Pickup(), _TurnipEntity), HandState);
        return utils_fphands::Resolve_ReachTarget(FMars_FPHands_Spec().Reach, Query);
    }

    UFUNCTION()
    private void Step_AssertEmptyHanded(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_TurnipEntity.Has_Fragment(FMars_Fragment_FPHands_Grips), "the turnip carries a grip table");

        const auto MaybeTarget = Resolve(EMars_FPHands_HoldKind::Empty);
        Assert_True(MaybeTarget.IsSet(), "the reach resolves");
        if (MaybeTarget.IsSet() == false)
        { return; }

        const auto Target = MaybeTarget.GetValue();
        const UMars_ItemTrait_Presentation Presentation = _Turnip.Get_HeldItem().Get_Presentation();
        Assert_True(Target.Pickup.IsSet, "a pickup");
        Assert_True(Target.Pickup.Shape.Mesh.Get() == System::LoadAsset_Blocking(Presentation.Visual.Mesh), "the pickup closes on the Presentation mesh");
        Assert_True(Target.Pickup.Shape.Scale.Equals(Presentation.Visual.MeshScale), "at its MeshScale");
        Assert_True(Target.Pickup.Shape.Type == EMars_FPHands_GripShape::Sphere, "as a sphere");
        Assert_True(Target.ContactPose.IsSet() && Target.ContactPose.GetValue() == EMars_HandGripPose::Cradle, "with the Cradle pose");
        Assert_True(Target.Layout == EMars_FPHands_GripLayout::Authored, f"Authored (got {Target.Layout :n})");
        Assert_True(Target.Right.IsSet() && Target.Left.IsSet(), "both gloves reach");
        if (Target.Right.IsSet() == false || Target.Left.IsSet() == false)
        { return; }

        const auto Root = _TurnipEntity.As_Transform();
        const auto Right = Target.Right.GetValue();
        const auto Left = Target.Left.GetValue();
        Assert_True(Right.Anchor == Root && Left.Anchor == Root, "both gloves anchor to the turnip's root");
        Assert_True(Right.IsAuthored && Left.IsAuthored, "both grips are authored");
        Assert_True(Right.Grip.Equals(Presentation.Grip.Points.Right.GetValue(), 0.001), f"the right glove takes the right point [{Right.Grip}]");
        Assert_True(Left.Grip.Equals(Presentation.Grip.Points.Left.GetValue(), 0.001), f"the left glove takes the left point [{Left.Grip}]");
    }

    UFUNCTION()
    private void Step_AssertRightBusy(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto MaybeTarget = Resolve(EMars_FPHands_HoldKind::OneHanded);
        Assert_True(MaybeTarget.IsSet(), "the reach resolves");
        if (MaybeTarget.IsSet() == false)
        { return; }

        const auto Target = MaybeTarget.GetValue();
        const UMars_ItemTrait_Presentation Presentation = _Turnip.Get_HeldItem().Get_Presentation();
        Assert_True(Target.Pickup.IsSet, "still a pickup");
        Assert_False(Target.Right.IsSet(), "the busy right glove does not reach");
        Assert_True(Target.Left.IsSet() && Target.Left.GetValue().Grip.Equals(Presentation.Grip.Points.Right.GetValue(), 0.001),
            "the free left glove takes the right point");
    }
}
