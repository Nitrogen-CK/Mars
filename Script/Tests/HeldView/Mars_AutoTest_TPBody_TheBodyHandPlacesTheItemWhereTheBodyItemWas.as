// The hand mount on the body puts a held item where the body's proxy used to draw it, and the item there is its own world
// item. The production pawn, unpossessed (its mount rides grip_r, and it is nobody's own view), is given a rock, a
// cleaver, a cookbook and a torch in turn; its arms take each hold from the local held-item change. For each: the mount's
// body offset is the item's (utils_held_view::Get_BodyHandMountOffset with the body's palm); the item's presentation (the
// Visual-mode world item HeldItem spawns for the transient rock and cleaver, the persistent cookbook's and torch's own
// body) has its root at HeldOffset on the mount, within k_ToleranceCm and k_ToleranceDeg of the proxy's old transform
// (Get_BodyItemTransform on grip_r at the bone's scale); the owner's shadow (HeldItemShadow) is empty on this copy.
// Isolated origin (-192000, 214000, 8000).
class UMars_AutoTest_TPBody_TheBodyHandPlacesTheItemWhereTheBodyItemWas : UMars_AutoTestRig_PlayerHand
{
    default _Origin = FVector(-192000.0, 214000.0, 8000.0);
    default _TimeoutSeconds = 45.0f;

    private const float64 k_ToleranceCm = 0.5;
    private const float64 k_ToleranceDeg = 0.5;
    // The arms ease into a hold (TPBody.Hold.InterpSpeed 14/s): well settled after this long.
    private const float32 k_ArmsSettleSeconds = 0.75f;

    private TArray<UCk_InventoryItem_Definition> _Definitions;
    private int32 _Index = 0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        _Definitions.Add(mars_items::Rock());
        _Definitions.Add(mars_items::Cleaver());
        _Definitions.Add(mars_items::Cookbook());
        _Definitions.Add(mars_items::Torch());
        Spawn_PawnAndSlab(InHandle);

        Add_Step_WaitUntil("the unpossessed pawn's entity is linked and composed", n"Check_EntityComposed", k_SlowPolls, 0);
        for (int32 Index = 0; Index < _Definitions.Num(); ++Index)
        {
            const auto Name = _Definitions[Index].GetName().ToString();
            Add_Step(f"spawn the {Name}", n"Step_SpawnNext");
            Add_Step_WaitUntil(f"the {Name} is composed", n"Check_ItemReady", k_SlowPolls, 0);
            Add_Step(f"the pawn picks the {Name} up", n"Step_GiveItem");
            Add_Step_WaitUntil(f"the pawn holds the {Name}, settled in the body's hand", n"Check_ItemHeld", k_SlowPolls, 0);
            Add_Step_WaitSeconds(f"the arms take the {Name}'s hold", k_ArmsSettleSeconds);
            Add_Step(f"the {Name} sits where the body item was", n"Step_AssertParity");
        }
        Add_Step("tear down", n"Step_TearDown");
        Add_Step_WaitUntil("the player's entity is gone", n"Check_PlayerEntityGone", k_SlowPolls, 0);
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_SpawnNext(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Spawn_Item(_Definitions[_Index]);
    }

    UFUNCTION()
    private void Step_AssertParity(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Name = _Definitions[_Index].GetName().ToString();
        _Index += 1;

        const auto HeldItem = Get_HeldItem();
        const auto Item = HeldItem.Get_CurrentItem();
        const auto Presentation = Item.Get_Presentation();
        const auto HeldOffset = Presentation.Mounting.HeldOffset;
        const auto Grip = utils_held_view::Make_Grip(Item);
        const auto Spec = Make_BodyHandsSpec();
        const auto ExpectedOffset = utils_held_view::Get_BodyHandMountOffset(Spec, Grip);
        const auto Mounted = HeldOffset * Get_MountWorld();
        const auto IsPersistent = Get_IsPersistent(Item);

        Assert_True(Get_MountParent() == Get_BodyGripTransform(), f"{Name}: the mount rides BodyGrip ({Describe_Mount()})");
        Assert_True(Get_MountOffset().Equals(ExpectedOffset, 0.001),
            f"{Name}: the mount's offset is the item's body offset [{ExpectedOffset}] ({Describe_Mount()})");

        // The proxy as it was placed: relative to grip_r, which carries the bone's scale.
        const auto GripWorld = utils_transform::Get_EntityCurrentTransform(Get_BodyGripTransform());
        const auto BoneScale = _Pawn.Mesh.GetSocketTransform(n"grip_r").GetScale3D();
        const auto ScaledGrip = FTransform(GripWorld.GetRotation(), GripWorld.GetLocation(), BoneScale);
        const auto ItemInGrip = utils_held_view::Get_ItemInGrip(Spec, HeldOffset, Grip);
        const auto Proxy = utils_held_view::Get_BodyItemTransform(ItemInGrip, Presentation.Visual.MeshScale, float32(BoneScale.X)) * ScaledGrip;

        const auto Presented = HeldItem.Get_PresentationEntity();
        const auto PresentedWorldItem = Presented.As_WorldItem(ECk_SanityCheck::UnChecked);
        const auto Mode = ck::IsValid(PresentedWorldItem) ? PresentedWorldItem.Get_Mode() : EMars_WorldItem_Mode::World;
        const auto ExpectedMode = IsPersistent ? EMars_WorldItem_Mode::World : EMars_WorldItem_Mode::Visual;
        Assert_True(ck::IsValid(PresentedWorldItem) && Mode == ExpectedMode,
            f"{Name}: the item is presented by its own world item ({Mode :n}, expected {ExpectedMode :n})");

        const auto Root = utils_transform::Get_EntityCurrentTransform(Presented.As_Transform(ECk_SanityCheck::UnChecked));
        const auto RootError = (Root.GetLocation() - Mounted.GetLocation()).Size();
        Assert_True(RootError <= k_ToleranceCm, f"{Name}: the item's own root sits at HeldOffset on the mount (error {RootError :.3} cm)");
        Assert_True(ck::Is_NOT_Valid(_Pawn.HeldItemShadow.GetStaticMesh()),
            f"{Name}: the body draws no shadow proxy on a copy that is not its player's view (HeldItemShadow mesh {Describe_ShadowMesh()})");

        const auto Error = (Mounted.GetLocation() - Proxy.GetLocation()).Size();
        const auto AngleDeg = Math::RadiansToDegrees(Mounted.GetRotation().AngularDistance(Proxy.GetRotation()));
        ck::Trace(f"[HandMount] {Name} persistent={IsPersistent} mounted=[{Mounted}] proxy=[{Proxy}] error={Error :.3} angle={AngleDeg :.3} {Describe_Mount()}");
        Assert_True(Error <= k_ToleranceCm, f"{Name}: HeldOffset on the mount is where the body item was drawn (error {Error :.3} cm)");
        Assert_True(AngleDeg <= k_ToleranceDeg, f"{Name}: ... and turned as it was (off by {AngleDeg :.3} deg)");
        Assert_True(_Pawn.Get_BodyHoldFrame().Right.Alpha > 0.5f,
            f"{Name}: the body's right arm took the hold from the local held-item change (alpha {_Pawn.Get_BodyHoldFrame().Right.Alpha :.2})");
    }

    private FString Describe_ShadowMesh()
    {
        const auto Mesh = _Pawn.HeldItemShadow.GetStaticMesh();
        return ck::IsValid(Mesh) ? Mesh.GetName().ToString() : "none";
    }
}

class AMars_AutoTest_TPBody_TheBodyHandPlacesTheItemWhereTheBodyItemWas_Actor : AMars_AutoTestRunner_PlayerCombat
{
    default _TimeoutSeconds = 45.0f;
    default _TestEntityScriptClass = UMars_AutoTest_TPBody_TheBodyHandPlacesTheItemWhereTheBodyItemWas;
}
