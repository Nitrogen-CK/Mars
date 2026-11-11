// The launch is its launch solution. A bare carrier (Hand node, a hotbar of two bag slots, HeldItem, HeldItemUse; no
// viewpoint, so it throws along its own +X) with a rock:
//   - with empty hands Get_LaunchSolution is unset;
//   - holding the rock, the Drop solution's speed is the rock's Throwable DropSpeed and the Throw solution's its ThrowSpeed;
//   - thrown, the launched world item's body, once Dynamic and past its launch, flies within 60 cm/s of the Throw
//     solution's velocity (two steps of gravity and damping are the slack), and its first Dynamic-frame location is within
//     8 cm of the solution's origin.
// The launched world item is destroyed in DoEndPlay. Isolated origin (240000, -40000, -30000).
class UMars_AutoTest_HeldItemUse_TheLaunchUsesItsLaunchSolution : UMars_AutoTestRig_Carrier
{
    default _TimeoutSeconds = 15.0f;

    private const FVector k_Origin = FVector(240000.0, -40000.0, -30000.0);
    private const float64 k_MaxVelocityErrorCmS = 60.0;
    private const float64 k_MaxOriginErrorCm = 8.0;

    private FCk_Handle_HeldItemUse _Use;
    private FMars_HeldItemUse_LaunchSolution _Solution;
    private FCk_Handle_WorldItem _Launched;
    private TArray<FCk_Handle> _LaunchedWorldItems;
    private bool _HasFirstDynamicLocation = false;
    private FVector _FirstDynamicLocation;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Add_CarrierBody(InHandle, k_Origin);
        Add_Hotbar(_Carrier, 2);
        _HeldItem = utils_held_item::Add(_Carrier);
        _Use = utils_held_item_use::Add(_Carrier);
        _Holders.Add(MakeSeededHolder(InHandle, mars_items::Rock()));

        Add_Step_WaitUntil("the holder holds its rock", n"Check_HoldersSeeded");
        Add_Step("empty hands have no launch solution", n"Step_AssertEmptyHands");
        Add_Step("stow the rock into the hands", n"Step_StowFirst");
        Add_Step_WaitUntil("the hands hold it", n"Check_Holding");
        Add_Step("the Drop and Throw solutions use the rock's speeds; throw", n"Step_ReadSolutionsAndThrow");
        Add_Step_WaitUntil("the launched body is Dynamic and has taken its launch", n"Check_LaunchTaken", 600);
        Add_Step("the body flies the solution's velocity from the solution's origin", n"Step_AssertLaunch");
        Run_Steps(InHandle);
    }

    UFUNCTION(BlueprintOverride)
    void DoEndPlay(FCk_Handle InHandle)
    {
        for (auto Entity : _LaunchedWorldItems)
        {
            if (ck::IsValid(Entity))
            { utils_entity_lifetime::Request_DestroyEntity(Entity); }
        }
    }

    UFUNCTION()
    private void Step_AssertEmptyHands(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_False(ck::IsValid(_HeldItem.Get_CurrentItem()), "the hands start empty");
        Assert_False(_Use.Get_LaunchSolution(EMars_LaunchKind::Throw).IsSet(), "empty hands have no Throw solution");
        Assert_False(_Use.Get_LaunchSolution(EMars_LaunchKind::Drop).IsSet(), "empty hands have no Drop solution");
    }

    UFUNCTION()
    private void Check_Holding(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_HeldItem.Get_CurrentItem() == _Items[0]);
    }

    UFUNCTION()
    private void Step_ReadSolutionsAndThrow(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const UMars_ItemTrait_Throwable Throwable = _Items[0].Get_Throwable();

        const auto Drop = _Use.Get_LaunchSolution(EMars_LaunchKind::Drop);
        Assert_True(Drop.IsSet(), "holding the rock, there is a Drop solution");
        if (Drop.IsSet())
        {
            const auto Speed = Drop.GetValue().LinearVelocity.Size();
            Assert_True(Math::Abs(Speed - Throwable.DropSpeed) < 0.01,
                f"the Drop solution's speed is the rock's DropSpeed {Throwable.DropSpeed} (got {Speed})");
        }

        const auto Throw = _Use.Get_LaunchSolution(EMars_LaunchKind::Throw);
        Assert_True(Throw.IsSet(), "holding the rock, there is a Throw solution");
        if (Throw.IsSet() == false)
        { return; }

        _Solution = Throw.GetValue();
        const auto ThrowSpeed = _Solution.LinearVelocity.Size();
        Assert_True(Math::Abs(ThrowSpeed - Throwable.ThrowSpeed) < 0.01,
            f"the Throw solution's speed is the rock's ThrowSpeed {Throwable.ThrowSpeed} (got {ThrowSpeed})");
        Assert_True(_Solution.AngularVelocityDeg.Equals(Throwable.AngularVelocityDeg, 0.01),
            f"the Throw solution spins as the rock's Throwable (got {_Solution.AngularVelocityDeg})");

        _Use.Request_Throw(FMars_Request_HeldItemUse_Throw());
    }

    // Finds the launched world item from the frame it exists, records its body's first Dynamic-frame location, and holds
    // once the launch fragment is gone and the body moves at least half the solution's speed (the velocity request has
    // been applied).
    UFUNCTION()
    private void Check_LaunchTaken(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        if (ck::Is_NOT_Valid(_Launched))
        { _Launched = Find_LaunchedWorldItem(InHandle); }

        if (ck::Is_NOT_Valid(_Launched) || ck::Is_NOT_Valid(_Launched.Get_Body()))
        {
            Res.Set(false);
            return;
        }

        const auto Body = _Launched.Get_Body();
        const auto IsDynamic = utils_jolt_body::Get_IsBodyAdded(Body) && utils_jolt_body::Get_MotionType(Body) == ECk_MotionType::Dynamic;
        if (IsDynamic == false)
        {
            Res.Set(false);
            return;
        }

        if (_HasFirstDynamicLocation == false)
        {
            FCk_Handle Entity = _Launched;
            _FirstDynamicLocation = utils_transform::Get_EntityCurrentTransform(Entity.As_Transform()).GetLocation();
            _HasFirstDynamicLocation = true;
        }

        const auto Taken = _Launched.Has_Fragment(FMars_Fragment_WorldItem_PendingLaunch) == false
            && utils_jolt_body::Get_LinearVelocity(Body).Size() > 0.5 * _Solution.LinearVelocity.Size();
        Res.Set(Taken);
    }

    UFUNCTION()
    private void Step_AssertLaunch(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Velocity = utils_jolt_body::Get_LinearVelocity(_Launched.Get_Body());
        const auto VelocityError = Velocity.Distance(_Solution.LinearVelocity);
        const auto OriginError = _FirstDynamicLocation.Distance(_Solution.Origin.GetLocation());
        Log(f"[HeldItemUse] launch solution: velocity {_Solution.LinearVelocity}, body {Velocity} (off {VelocityError} cm/s); "
            + f"origin {_Solution.Origin.GetLocation()}, first Dynamic location {_FirstDynamicLocation} (off {OriginError} cm)");

        Assert_True(VelocityError <= k_MaxVelocityErrorCmS,
            f"the body flies within {k_MaxVelocityErrorCmS} cm/s of the solution's velocity (off by {VelocityError} cm/s)");
        Assert_True(OriginError <= k_MaxOriginErrorCm,
            f"the body's first Dynamic-frame location is within {k_MaxOriginErrorCm} cm of the solution's origin (off by {OriginError} cm)");
    }

    // The World-mode world item near the carrier: the one the throw spawned. Recorded for destruction in DoEndPlay.
    private FCk_Handle_WorldItem Find_LaunchedWorldItem(FCk_Handle InHandle)
    {
        for (const auto& Entity : utils_entity_tag::ForEach_Entity(InHandle, n"TAG_MarsWorldItem"))
        {
            if (ck::Is_NOT_Valid(Entity) || Entity.Is_WorldItem() == false)
            { continue; }

            const auto WorldItem = Entity.As_WorldItem();
            if (WorldItem.Get_Mode() != EMars_WorldItem_Mode::World)
            { continue; }

            const auto Location = utils_transform::Get_EntityCurrentTransform(Entity.As_Transform()).GetLocation();
            if (Location.Distance(k_Origin) < 2000.0)
            {
                _LaunchedWorldItems.Add(Entity);
                return WorldItem;
            }
        }

        return FCk_Handle_WorldItem();
    }
}
