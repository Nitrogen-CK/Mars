// A Persistent item's predicted flight starts at its own mounted body and flies with that body's flight. The rig of
// Mars_AutoTest_WorldItem_PersistentCarryHoldRelease: a backpack world item stowed by the carrier, its slot selected so it
// is Held on the Hand, over a Static floor 300 cm below the hand. While held and aiming: the path starts within 1 cm of the
// mounted world item's transform applied to its BoundsFit.Centre, is longer than 300 cm (the item's own mounted body did
// not block it), and Get_FlightBody's flight is the body's own. Thrown, the real body's bounds centre at its first
// contact, projected onto the landing surface (the plane through the landing with its normal), is within 30 cm of the
// predicted landing. The centre and not the contact point, because a swept sphere touches down under its centre while a
// flat-bottomed body lands on the corners of its bottom face. The nearest contact point's distance is logged with the other
// measured numbers. Isolated origin (248000, -40000, -30000).
class UMars_AutoTest_ThrowPreview_APersistentItemFliesFromItsMountWithItsOwnFlight : UMars_AutoTestRig_ThrowPreview
{
    private const float64 k_HandAboveFloor = 300.0;
    private const float64 k_MaxLandingErrorCm = 30.0;
    private const float64 k_MaxStartErrorCm = 1.0;
    private const float64 k_MinPathLengthCm = 300.0;

    private FCk_Handle_WorldItem _WorldItem;
    private FCk_Handle_Item _Item;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        _Origin = FVector(248000.0, -40000.0, -30000.0);
        Add_CarrierBodyWithBack(InHandle, _Origin);
        Add_PreviewParts(1);

        auto SpawnParams = UMars_WorldItem_EntityScript::Params();
        SpawnParams.Definition = mars_items::Backpack();
        SpawnParams.Mode = EMars_WorldItem_Mode::World;
        SpawnParams.SpawnTransform = FTransform(FRotator::ZeroRotator, _Origin + FVector(200.0, 0.0, 0.0));

        auto Pending = utils_entity_script::Request_SpawnEntity(InHandle, UMars_WorldItem_EntityScript, SpawnParams);
        utils_pending_entity_script::Promise_OnConstructed(
            Pending,
            FCk_Delegate_EntityScript_Constructed(this, n"OnWorldItemConstructed"));

        Add_Step_WaitUntil("the backpack world item's holder holds its seeded item", n"Check_HolderSeeded");
        Add_Step("stow the backpack into the carrier's stow target", n"Step_Stow");
        Add_Step_WaitUntil("the carrier wears the backpack", n"Check_Wearing");
        Add_Step("select the backpack slot", n"Step_SelectBackpackSlot");
        Add_Step_WaitUntil("Held on the Hand node with a Kinematic body", n"Check_Held");
        Add_Step("a floor slab 300 cm under the hand", n"Step_BuildFloor");
        Add_Step("aim", n"Step_Aim");
        Add_Step_WaitUntil("the path meets a surface", n"Check_PathMeetsASurface", k_SlowPolls);
        Add_Step("the path starts at the mount, is not blocked by it, flies the body's flight; throw", n"Step_AssertPathAndThrow");
        Add_Step_WaitUntil("the thrown backpack touches something", n"Check_FlightLanded", k_SlowPolls);
        Add_Step("its centre came down where predicted", n"Step_AssertLanding");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void OnWorldItemConstructed(FCk_Handle_EntityScript InEntityScriptHandle)
    {
        _WorldItem = InEntityScriptHandle.As_WorldItem();
    }

    UFUNCTION()
    private void Check_HolderSeeded(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(ck::IsValid(_WorldItem) && ck::IsValid(_WorldItem.Get_HeldItem()));
    }

    UFUNCTION()
    private void Step_Stow(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Item = _WorldItem.Get_HeldItem();
        auto Target = _Hotbar.TryGet_StowTarget(_Item);
        if (ck::Is_NOT_Valid(Target) || Target != _Hotbar.Get_BackpackSlot())
        {
            FinishFailure("stow precondition: the backpack's stow target is the backpack slot");
            return;
        }

        auto Holder = _WorldItem.Get_Holder();
        Holder.Request_TransferItem_ToDataOnly(FCk_Request_Inventory_TransferItem_ToDataOnly(_Item, Target),
            FCk_Delegate_Inventory_OnOperationResult_Transfer());
    }

    UFUNCTION()
    private void Check_Wearing(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Hotbar.Get_IsWearingBackpack() && ck::IsValid(_WorldItem));
    }

    UFUNCTION()
    private void Step_SelectBackpackSlot(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Hotbar.Request_Select(FMars_Request_Hotbar_Select(_Hotbar.Get_BackpackIndex().GetValue()));
    }

    UFUNCTION()
    private void Check_Held(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        const auto Body = _WorldItem.Get_Body();
        Res.Set(ck::IsValid(_WorldItem) && _WorldItem.Get_Mount() == EMars_WorldItem_Mount::Held
            && Get_MountParent(_WorldItem) == _HandNode && _HeldItem.Get_CurrentItem() == _Item
            && ck::IsValid(Body) && utils_jolt_body::Get_MotionType(Body) == ECk_MotionType::Kinematic);
    }

    UFUNCTION()
    private void Step_BuildFloor(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Hand = Get_HandLocation();
        const auto Top = Hand.Z - k_HandAboveFloor;
        Spawn_StaticSlab(InHandle, FVector(Hand.X + 400.0, Hand.Y, Top - 10.0), FVector(800.0, 400.0, 10.0));
    }

    UFUNCTION()
    private void Step_AssertPathAndThrow(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Keep_PredictedPath();

        FCk_Handle WorldItemEntity = _WorldItem;
        const auto Mounted = utils_transform::Get_EntityCurrentTransform(WorldItemEntity.As_Transform());
        const auto ExpectedStart = Mounted.TransformPosition(_WorldItem.Get_BoundsFit().Centre);
        const auto StartError = _Predicted.Points.Num() > 0 ? _Predicted.Points[0].Distance(ExpectedStart) : -1.0;
        Assert_True(StartError >= 0.0 && StartError <= k_MaxStartErrorCm,
            f"the path starts within {k_MaxStartErrorCm} cm of the mounted body's bounds centre (got {StartError} cm)");

        const auto Length = Get_PolylineLength(_Predicted.Points);
        Assert_True(Length > k_MinPathLengthCm,
            f"the path is longer than {k_MinPathLengthCm} cm: the item's own mounted body did not block it (got {Length} cm)");

        const auto FlightBody = _Item.Get_FlightBody();
        Assert_True(FlightBody.IsSet(), "the held backpack has a flight body");
        if (FlightBody.IsSet())
        {
            const auto Got = FlightBody.GetValue().Flight;
            const auto Body = utils_jolt_body::Get_BallisticFlight(_WorldItem.Get_Body());
            Assert_True(Math::IsNearlyEqual(Got.Get_LinearDamping(), Body.Get_LinearDamping())
                && Math::IsNearlyEqual(Got.Get_GravityFactor(), Body.Get_GravityFactor())
                && Math::IsNearlyEqual(Got.Get_MaxLinearVelocity(), Body.Get_MaxLinearVelocity()),
                f"Get_FlightBody's flight is the body's own (damping {Got.Get_LinearDamping()} vs {Body.Get_LinearDamping()}, "
                + f"gravity {Got.Get_GravityFactor()} vs {Body.Get_GravityFactor()}, max {Got.Get_MaxLinearVelocity()} vs {Body.Get_MaxLinearVelocity()})");
        }

        _Flying = _WorldItem;
        _Use.Request_Throw(FMars_Request_HeldItemUse_Throw());
    }

    UFUNCTION()
    private void Step_AssertLanding(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Log_Flight("backpack");

        const auto CentreError = Get_CentreLandingErrorCm();
        Assert_True(CentreError >= 0.0, "the backpack touched something");
        Assert_True(CentreError <= k_MaxLandingErrorCm,
            f"the backpack's centre at its first contact, on the landing surface, is within {k_MaxLandingErrorCm} cm of the "
            + f"predicted landing (got {CentreError} cm; centre {_ContactCentre}, landing {_Predicted.Landing.Location}; nearest "
            + f"contact point {_LandingErrorCm} cm away)");
    }
}
