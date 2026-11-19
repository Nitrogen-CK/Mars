// HeldItem presents a transient item on a character nobody's own view shows: the production pawn, unpossessed (its hand
// mount rides the body's grip_r, its gloves never tick), picks up a rock and gets a Visual-mode world item of its own for
// it, drawn as a world primitive at HeldOffset on the body's hand mount, and its arms take the hold from the local
// held-item change. Before the pickup it is asked for a spawn-from pose well away from the hand, as a pickup's gloves
// would ask (ruling C8): with no gloves to carry the item in from there, the visual still takes HeldOffset with no Arrival
// in flight. Its primitives, found from the component host (Assert_EveryHostedPrimitive), are world primitives. The
// owner's shadow (HeldItemShadow) stays empty on this copy. Isolated origin (-216000, 214000, 8000).
class UMars_AutoTest_HeldItem_ANonOwnedCharacterStillGetsItsHeldVisual : UMars_AutoTestRig_PlayerHand
{
    default _Origin = FVector(-216000.0, 214000.0, 8000.0);
    default _TimeoutSeconds = 30.0f;

    private const float64 k_ToleranceCm = 0.5;
    // The arms ease into a hold (TPBody.Hold.InterpSpeed 14/s): well settled after this long.
    private const float32 k_ArmsSettleSeconds = 0.75f;
    // The spawn-from pose asked for, from the hand mount: well away from HeldOffset.
    private const FVector k_SpawnFromInHand = FVector(60.0, -40.0, 50.0);

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        _ItemKinds = FMars_AutoTest_PrimitiveKinds(1, 0);
        Spawn_PawnAndSlab(InHandle);
        Spawn_Item(mars_items::Rock());

        Add_Step_WaitUntil("the unpossessed pawn's entity is linked and composed", n"Check_EntityComposed", k_SlowPolls, 0);
        Add_Step_WaitUntil("the rock is composed", n"Check_ItemReady", k_SlowPolls, 0);
        Add_Step("ask for a spawn-from pose away from the hand, then pick the rock up", n"Step_SpawnFromThenGive");
        Add_Step_WaitUntil("the pawn holds the rock, its visual settled in the body's hand", n"Check_ItemHeld", k_SlowPolls, 0);
        Add_Step_WaitSeconds("the arms take the rock's hold", k_ArmsSettleSeconds);
        Add_Step("the rock is the pawn's own visual at HeldOffset on the body's hand", n"Step_AssertVisual");
        Add_Step("tear down", n"Step_TearDown");
        Add_Step_WaitUntil("the player's entity is gone", n"Check_PlayerEntityGone", k_SlowPolls, 0);
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_SpawnFromThenGive(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto HeldItem = Get_HeldItem();
        const auto SpawnFrom = FTransform(FRotator::ZeroRotator, k_SpawnFromInHand) * Get_MountWorld();
        HeldItem.Request_SetNextSpawnFrom(FMars_Request_HeldItem_SetNextSpawnFrom(SpawnFrom));
        Step_GiveItem(InHandle, InPayload);
    }

    UFUNCTION()
    private void Step_AssertVisual(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto HeldItem = Get_HeldItem();
        const auto Presented = HeldItem.Get_PresentationEntity();
        const auto WorldItem = Presented.As_WorldItem(ECk_SanityCheck::UnChecked);
        const auto IsVisual = ck::IsValid(WorldItem) && WorldItem.Get_Mode() == EMars_WorldItem_Mode::Visual;
        const auto IsOwned = HeldItem.Get_Fragment(FMars_Fragment_HeldItem).PresentationOwnership == EMars_HeldItem_PresentationOwnership::Owned;

        const auto HeldOffset = _Item.Get_Presentation().Mounting.HeldOffset;
        const auto Expected = HeldOffset * Get_MountWorld();
        const auto Root = utils_transform::Get_EntityCurrentTransform(Presented.As_Transform(ECk_SanityCheck::UnChecked));
        const auto Error = (Root.GetLocation() - Expected.GetLocation()).Size();

        const auto Shadow = _Pawn.HeldItemShadow.GetStaticMesh();
        const auto Alpha = _Pawn.Get_BodyHoldFrame().Right.Alpha;
        ck::Trace(f"[HeldItem] non-owned visual: visual={IsVisual} owned={IsOwned} error={Error :.3} alpha={Alpha :.2} {Describe_Mount()} {Describe_Hold()}");
        Assert_False(_Pawn.Get_IsLocalPlayerView(), "the unpossessed pawn is not a player's own view");
        Assert_True(Get_MountParent() == Get_BodyGripTransform(), f"the mount rides BodyGrip ({Describe_Mount()})");
        Assert_True(IsVisual && IsOwned, f"the pawn presents the rock by a Visual-mode world item it owns (visual {IsVisual}, owned {IsOwned})");
        Assert_False(Presented.Has_Fragment(FMars_Fragment_WorldItem_Arrival), "the visual has no Arrival in flight");
        Assert_True(Error <= k_ToleranceCm,
            f"the visual's root sits at HeldOffset on the body's hand mount, not at the spawn-from pose (error {Error :.3} cm)");
        Assert_EveryHostedPrimitive(Presented, EFirstPersonPrimitiveType::None, "the rock's visual on the body");
        Assert_False(ck::IsValid(Shadow), "the body draws no shadow proxy on a copy that is not its player's view");
        Assert_True(Alpha > 0.5f, f"the body's right arm took the rock's hold from the local held-item change (alpha {Alpha :.2})");
    }
}

class AMars_AutoTest_HeldItem_ANonOwnedCharacterStillGetsItsHeldVisual_Actor : AMars_AutoTestRunner_PlayerCombat
{
    default _TimeoutSeconds = 30.0f;
    default _TestEntityScriptClass = UMars_AutoTest_HeldItem_ANonOwnedCharacterStillGetsItsHeldVisual;
}
