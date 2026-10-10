// A pickup is committed once the gloves took its reach: on the player-path carrier the view rests on a still rock, Use is
// pressed and the gloves start reaching for it; then Use is released and the view turns away (the rock leaves the view
// ray), the player's ways of letting go. The pickup still lands at the gloves' Grip: neither the release nor the look-away
// cancels a WhileLive interaction, and the live pickup keeps the rock focused until it lands (the focus holds while the
// player's interaction on it is live). Isolated origin (84000, -40000, -30000).
class UMars_AutoTest_Interactable_AGripTaskPastAcceptanceSurvivesACancel : UMars_AutoTestRig_PlayerPath
{
    private const FVector k_Origin = FVector(84000.0, -40000.0, -30000.0);
    private const FVector k_RockLocal = FVector(120.0, 0.0, 16.0);

    private FCk_Handle _RockEntity;
    private FCk_Handle_WorldItem _Rock;
    private FCk_Handle_InteractTarget _RockTarget;
    private TOptional<FVector> _LastRockLocation;
    private int32 _StillFrames = 0;
    // The gloves' phases from the release on.
    private int32 _PhasesAtRelease = 0;
    // Before the stow: the rock left the view ray, and whether it ever lost the focus.
    private bool _LeftTheRayBeforeStow = false;
    private bool _UnfocusedBeforeStow = false;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Build_PlayerPath(InHandle, k_Origin);
        _RockEntity = Spawn_WorldItem(InHandle, mars_items::Rock(), k_RockLocal);

        Add_Steps_UntilReady();
        Add_Step_WaitUntil("the rock lies still on the floor", n"Check_RockStill", 0, 0);
        Add_Step("turn the view onto the rock", n"Step_AimAtRock");
        Add_Step_WaitUntil("the rock's pickup is focused", n"Check_RockFocused", 0, 0);
        Add_Step("press and hold Use", n"Step_PressUse");
        Add_Step_WaitUntil("the gloves took the reach for the rock and are reaching", n"Check_GlovesReaching", 0, 0);
        Add_Step("release Use and turn the view away while the gloves reach", n"Step_ReleaseAndLookAway");
        Add_Step_WaitUntil("the rock is stowed", n"Check_RockStowedWatchingFocus", 0, 0);
        Add_Step("the rock left the focus, yet the gloves closed on it and it is in a bag slot", n"Step_AssertLanded");
        Run_Steps(InHandle);
    }

    // A constructed rock world item whose location moved less than 1.5 mm a frame for 10 frames.
    UFUNCTION()
    private void Check_RockStill(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        if (ck::Is_NOT_Valid(_Rock))
        {
            const auto Constructed = ck::IsValid(_RockEntity) && _RockEntity.Is_WorldItem()
                && ck::IsValid(_RockEntity.As_WorldItem().Get_HeldItem());
            if (Constructed == false)
            {
                Res.Set(false);
                return;
            }

            _Rock = _RockEntity.As_WorldItem();
            _RockTarget = Get_UseTarget(_Rock);
        }

        const auto Location = utils_transform::Get_EntityCurrentTransform(_RockEntity.As_Transform()).GetLocation();
        const auto IsStill = _LastRockLocation.IsSet() && _LastRockLocation.GetValue().Equals(Location, 0.15);
        _StillFrames = IsStill ? _StillFrames + 1 : 0;
        _LastRockLocation = TOptional<FVector>(Location);
        Res.Set(_StillFrames >= 10);
    }

    UFUNCTION()
    private void Step_AimAtRock(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Aim_ViewAt(_LastRockLocation.GetValue());
    }

    UFUNCTION()
    private void Check_RockFocused(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Rock.Get_Pickup().Get_IsFocused());
    }

    UFUNCTION()
    private void Check_GlovesReaching(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Hands.Get_Phase() == EMars_FPHands_Phase::Reach && _Hands.Get_IsReachTarget(_RockTarget));
    }

    UFUNCTION()
    private void Step_ReleaseAndLookAway(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _PhasesAtRelease = _HandPhases.Num();
        _UseKey.Release();
        Aim_ViewAway();
    }

    // A transient rock's world item ends once its holder gives the item up; before then, notes whether the look-away has
    // taken the rock off the view ray, and whether it lost the focus.
    UFUNCTION()
    private void Check_RockStowedWatchingFocus(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto IsStowed = ck::Is_NOT_Valid(_Rock) || ck::Is_NOT_Valid(_Rock.Get_HeldItem());
        if (IsStowed == false)
        {
            FCk_Handle RockPickup = _Rock.Get_Pickup();
            if (Get_IsUnderTheTrace(RockPickup) == false)
            { _LeftTheRayBeforeStow = true; }

            if (_Rock.Get_Pickup().Get_IsFocused() == false)
            { _UnfocusedBeforeStow = true; }
        }

        auto Res = OutResult;
        Res.Set(IsStowed);
    }

    UFUNCTION()
    private void Step_AssertLanded(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_LeftTheRayBeforeStow, "the look-away took the rock off the view ray before it was stowed");
        Assert_False(_UnfocusedBeforeStow, "the live pickup kept the rock focused until it was stowed");
        Assert_False(Get_IsUseHeld(), "Use was released before the rock was stowed");

        auto GrippedAfterRelease = false;
        for (int32 Index = _PhasesAtRelease; Index < _HandPhases.Num(); ++Index)
        { GrippedAfterRelease = GrippedAfterRelease || _HandPhases[Index] == EMars_FPHands_Phase::Grip; }

        Assert_True(GrippedAfterRelease, "the gloves went on to their Grip after the release");
        Assert_True(ck::IsValid(_Hotbar.Get_ItemAt(0)) || ck::IsValid(_Hotbar.Get_ItemAt(1)), "the rock is in a bag slot");
    }
}
