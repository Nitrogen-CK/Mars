// On the production player (the player-combat rig): a crouch drops the capsule's centre by the half heights' difference,
// and the eye node first keeps the view where it was (its offset jumps above Height by at most that difference) and then
// eases back down to Height. Isolated origin (-238000, 238000, 8000).
class UMars_AutoTest_EyeHeight_CrouchOffsetsThenEasesBack : UMars_AutoTestRig_PlayerCombat
{
    default _Origin = FVector(-238000.0, 238000.0, 8000.0);

    private FCk_Handle_EyeHeight _Eye;
    private float32 _Height = 0.0f;
    private float32 _CrouchDrop = 0.0f;
    private float64 _HighestOffsetZ = 0.0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        SpawnFloorAndPlayer(InHandle);

        Add_Step_WaitUntil("the pawn's entity is linked, Alive and standing on the floor", n"Check_PlayerReady", k_SlowPolls, 0);
        Add_Step("find the eye node, check it rests at Height, crouch", n"Step_FindEyeAndCrouch");
        Add_Step_WaitUntil("the character is crouched", n"Check_Crouched", k_SlowPolls, 0);
        Add_Step_WaitUntil("the eye has eased back to Height", n"Check_EyeBackAtHeight", k_SlowPolls, 0);
        Add_Step("the eye rose by at most the crouch drop before it eased back", n"Step_AssertEased");
        Add_Step("tear down", n"Step_TearDown");
        Add_Step_WaitUntil("the player's entity is gone", n"Check_PlayerEntityGone", k_SlowPolls, 0);
        Run_Steps(InHandle);
    }

    private float64 Get_EyeOffsetZ() const
    {
        return utils_scene_node::Get_Offset(_Eye.As_SceneNode()).GetLocation().Z;
    }

    UFUNCTION()
    private void Step_FindEyeAndCrouch(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        for (auto Dependent : _Player.Get_LifetimeDependents())
        {
            if (ck::IsValid(Dependent) && Dependent.Is_EyeHeight())
            { _Eye = Dependent.As_EyeHeight(); }
        }

        if (ck::Is_NOT_Valid(_Eye))
        {
            FinishFailure("the player has no EyeHeight node among its dependents");
            return;
        }

        auto Config = mars::Mars_PlayerCharacter_Config;
        _Height = Config.View.EyeHeight.Height;
        _CrouchDrop = Config.Body.CapsuleHalfHeight - Config.Body.CrouchedHalfHeight;
        _HighestOffsetZ = Get_EyeOffsetZ();
        Assert_Equals_Float(_HighestOffsetZ, _Height, 0.01, "standing, the eye rests at Height above the capsule centre");
        _Pawn.Crouch();
    }

    UFUNCTION()
    private void Check_Crouched(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        _HighestOffsetZ = Math::Max(_HighestOffsetZ, Get_EyeOffsetZ());
        Res.Set(_Pawn.bIsCrouched && Math::IsNearlyEqual(_Pawn.CapsuleComponent.GetScaledCapsuleHalfHeight(), mars::Mars_PlayerCharacter_Config.Body.CrouchedHalfHeight, 0.01));
    }

    UFUNCTION()
    private void Check_EyeBackAtHeight(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        const auto OffsetZ = Get_EyeOffsetZ();
        _HighestOffsetZ = Math::Max(_HighestOffsetZ, OffsetZ);
        Res.Set(_HighestOffsetZ > _Height + 1.0 && Math::Abs(OffsetZ - _Height) < 0.01);
    }

    UFUNCTION()
    private void Step_AssertEased(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_HighestOffsetZ > _Height + 1.0 && _HighestOffsetZ <= _Height + _CrouchDrop + 0.01,
            f"after the crouch the eye sat above Height by (1, {_CrouchDrop}] cm (highest offset {_HighestOffsetZ}, Height {_Height})");
        Assert_Equals_Float(Get_EyeOffsetZ(), _Height, 0.01, "the eye is back at Height");
    }
}

// The production pawn's spawn-time log noise is listed on the shared runner base.
class AMars_AutoTest_EyeHeight_CrouchOffsetsThenEasesBack_Actor : AMars_AutoTestRunner_PlayerCombat
{
    default _TestEntityScriptClass = UMars_AutoTest_EyeHeight_CrouchOffsetsThenEasesBack;
}
