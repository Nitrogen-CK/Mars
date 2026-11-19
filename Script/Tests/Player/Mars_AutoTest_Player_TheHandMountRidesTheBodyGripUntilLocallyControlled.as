// The production pawn's hand mount (AttachPoint.Mars.Hand) rides the body until the pawn is its player's own view. Nobody
// possesses it: the mount is under Player.BodyGrip at the empty hold's body offset, BodyGrip follows grip_r at unit scale,
// and the mount sits within k_ToleranceCm of that offset composed with the socket. The local player controller possesses
// it: the mount moves under the gloves' hand node at identity. The controller lets go again: the mount stays there (the
// move is one-way), and so does everything that reads the latch (Get_IsHandMountFirstPerson): the hand node still renders
// first-person and the gloves still tick. Isolated origin (-186000, 214000, 8000).
class UMars_AutoTest_Player_TheHandMountRidesTheBodyGripUntilLocallyControlled : UMars_AutoTestRig_PlayerHand
{
    default _Origin = FVector(-186000.0, 214000.0, 8000.0);

    private const float64 k_ToleranceCm = 0.5;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Spawn_PawnAndSlab(InHandle);

        Add_Step_WaitUntil("the unpossessed pawn's entity is linked and composed", n"Check_EntityComposed", k_SlowPolls, 0);
        Add_Step_WaitFrames("the scene nodes take their first poses", 4);
        Add_Step("unpossessed: the mount rides BodyGrip at the composed socket offset", n"Step_AssertOnBody");
        Add_Step("possess the pawn", n"Step_Possess");
        Add_Step_WaitUntil("the mount moves under the gloves' hand node", n"Check_OnHandNode", k_SlowPolls, 0);
        Add_Step_WaitFrames("the mount takes the hand node's pose", 2);
        Add_Step("possessed: the mount is the gloves' hand node at identity; unpossess", n"Step_AssertOnHandNodeAndUnpossess");
        Add_Step_WaitFrames("let the pawn tick unpossessed", k_HoldFrames);
        Add_Step("unpossessed again: the mount stayed under the hand node", n"Step_AssertStillOnHandNode");
        Add_Step("tear down", n"Step_TearDown");
        Add_Step_WaitUntil("the player's entity is gone", n"Check_PlayerEntityGone", k_SlowPolls, 0);
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_AssertOnBody(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto BodyGrip = Get_BodyGripTransform();
        const auto GripWorld = utils_transform::Get_EntityCurrentTransform(BodyGrip);
        const auto Socket = Get_UnscaledGripSocket();
        const auto ExpectedOffset = utils_held_view::Get_BodyHandMountOffset(Make_BodyHandsSpec(), FMars_HeldView_Grip());
        const auto Expected = ExpectedOffset * Socket;
        const auto Error = (Get_MountWorld().GetLocation() - Expected.GetLocation()).Size();
        ck::Trace(f"[HandMount] unpossessed {Describe_Mount()} bodyGrip=[{GripWorld}] socket=[{Socket}] error={Error :.3}");

        Assert_False(_Pawn.Get_IsLocalPlayerView(), "unpossessed: the pawn is not its player's own view");
        Assert_False(utils_fphands::Get_IsFirstPersonView(_Player.As_FPHands()), "unpossessed: the gloves do not run as a first-person view");
        Assert_True(ck::IsValid(BodyGrip) && Get_MountParent() == BodyGrip, f"unpossessed: the mount's parent is Player.BodyGrip ({Describe_Mount()})");
        Assert_True(Get_MountOffset().Equals(ExpectedOffset, 0.001), f"unpossessed: the mount's offset is the empty hold's body offset [{ExpectedOffset}] ({Describe_Mount()})");
        Assert_True(GripWorld.GetScale3D().Equals(FVector::OneVector, 0.001), f"BodyGrip follows grip_r at unit scale (scale [{GripWorld.GetScale3D()}])");
        Assert_True(Error <= k_ToleranceCm, f"unpossessed: the mount is within {k_ToleranceCm} cm of its offset composed with grip_r (error {Error :.3} cm)");
        Assert_True(_Player.As_AttachPoints().Get_AttachPoint(GameplayTags::AttachPoint_Mars_Hand) == Get_Mount(),
            "AttachPoint.Mars.Hand is the hand mount");
    }

    UFUNCTION()
    private void Step_Possess(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        PossessPawn();
    }

    UFUNCTION()
    private void Check_OnHandNode(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_MountParent() == Get_GloveHandNode());
    }

    UFUNCTION()
    private void Step_AssertOnHandNodeAndUnpossess(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        AssertOnHandNode("possessed");
        Assert_True(_Pawn.Get_IsLocalPlayerView(), "possessed: the pawn is its player's own view");
        Assert_True(Get_IsHandNodeFirstPerson(), "possessed: the gloves' hand node is the first-person hand");
        if (ck::IsValid(_Controller))
        { _Controller.UnPossess(); }
    }

    UFUNCTION()
    private void Step_AssertStillOnHandNode(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_False(_Pawn.Get_IsLocalPlayerView(), "unpossessed again: the pawn is not its player's own view");
        AssertOnHandNode(f"unpossessed again after {k_HoldFrames} frames");
        Assert_True(_Pawn.Get_IsHandMountFirstPerson(), "unpossessed again: the hand mount's latch holds");
        Assert_True(Get_IsHandNodeFirstPerson(),
            "unpossessed again: the gloves' hand node is still the first-person hand (it reads the latch, not the live view)");
        Assert_True(utils_fphands::Get_IsFirstPersonView(_Player.As_FPHands()),
            "unpossessed again: the gloves still run as the first-person view (their tick reads the latch)");
    }

    private bool Get_IsHandNodeFirstPerson()
    {
        FCk_Handle HandNode = Get_GloveHandNode();
        return utils_fphands::Get_IsFirstPersonHandNode(HandNode);
    }

    private void AssertOnHandNode(const FString& InWhen)
    {
        const auto HandWorld = utils_transform::Get_EntityCurrentTransform(Get_GloveHandNode());
        const auto Error = (Get_MountWorld().GetLocation() - HandWorld.GetLocation()).Size();
        ck::Trace(f"[HandMount] {InWhen} {Describe_Mount()} hand=[{HandWorld.GetLocation()}] error={Error :.3}");
        Assert_True(Get_MountParent() == Get_GloveHandNode(), f"{InWhen}: the mount's parent is the gloves' hand node ({Describe_Mount()})");
        Assert_True(Get_MountOffset().Equals(FTransform::Identity, 0.001), f"{InWhen}: the mount is at identity under it ({Describe_Mount()})");
        Assert_True(Error <= k_ToleranceCm, f"{InWhen}: the mount is where the hand node is (error {Error :.3} cm)");
    }
}

class AMars_AutoTest_Player_TheHandMountRidesTheBodyGripUntilLocallyControlled_Actor : AMars_AutoTestRunner_PlayerCombat
{
    default _TimeoutSeconds = 30.0f;
    default _TestEntityScriptClass = UMars_AutoTest_Player_TheHandMountRidesTheBodyGripUntilLocallyControlled;
}
