// The tumbler rig: a Tumbler station on a transform-only root at an isolated origin. The axle node (k_AxleLocal) carries the
// drum Mover (pitch 0 to 90 over 0.4 s) and the lever Control (ManuallyCompleted, pulled along the axle's -X); under it the
// lever grip node (k_LeverGripLocal) and the hatch hinge node, whose Mover swings the hatch up and open (pitch 0 to -70
// over 0.2 s) with the hatch tab node under it (k_HatchTabLocal). The hand node sits on the root at the workspace centre and
// a view node on the root looks down at the drum. No meshes and no physics: the kernel is headless. The rig is the
// operator and the test feed: it looks, presses, releases and cancels, and AddPiece releases piece {1, Slot}. The handlers
// record every signal.
UCLASS(Abstract)
class UMars_AutoTestRig_Tumbler : UCk_AutoTest_Base
{
    protected const FVector k_Origin = FVector(-60000.0, 40000.0, -60000.0);
    protected const FVector k_AxleLocal = FVector(0.0, 0.0, 112.0);
    // Under the axle: the top of the lever arm, out +Y and up.
    protected const FVector k_LeverGripLocal = FVector(0.0, 30.0, 38.0);
    // Under the hinge (at the axle): the hatch plate's bottom centre, in front of the drum.
    protected const FVector k_HatchTabLocal = FVector(-30.0, 0.0, -20.0);
    protected const FVector k_WorkspaceCentre = FVector(-42.0, 0.0, 112.0);
    protected const FVector k_ViewLocal = FVector(-110.0, 0.0, 185.0);
    protected const float64 k_ViewPitchDegrees = -35.0;
    // The release pose the rig's feed hands over (the kernel places pieces by slot and ignores it).
    protected const FVector k_ReleaseLocal = FVector(-20.0, 0.0, 112.0);
    // The generation every rig piece carries.
    protected const int32 k_Generation = 1;
    // Degrees of look pitch per rocking frame (down is +).
    protected const float32 k_RockDegrees = 4.0f;
    protected const float64 k_PoseTolerance = 0.5;

    protected FCk_Handle_Tumbler _Tumbler;
    // The spec the station was built from, nodes included.
    protected FMars_Tumbler_Spec _Spec;
    protected FCk_Handle_Control _Lever;
    protected FCk_Handle_Mover _Axle;
    protected FCk_Handle_Mover _HatchMover;

    // One entry per signal, in order (parallel arrays where a signal carries more than one value).
    protected TArray<EMars_Tumbler_HandMode> _HandModes;
    protected TArray<EMars_Tumbler_Target> _Hovers;
    protected TArray<EMars_Tumbler_Hatch> _Hatches;
    protected TArray<EMars_Tumbler_Drum> _Drums;
    protected TArray<EMars_Tumbler_Refusal> _Refusals;
    protected TArray<FMars_CookingFeed_PieceId> _AdmissionIds;
    protected TArray<EMars_CookingFeed_Admission> _Admissions;
    protected TArray<FString> _AdmissionReasons;
    protected TArray<FMars_CookingFeed_PieceId> _AddedIds;
    protected TArray<FCk_Handle> _Added;
    protected TArray<FMars_CookingFeed_PieceId> _CoverageIds;
    protected TArray<float32> _Coverages;
    protected int32 _LeverEngagedCount = 0;

    // The rocking plan Add_Step_Rock queues: each wait consumes the next entry, looking that many frames at that pitch.
    private TArray<float32> _RockPitches;
    private TArray<int32> _RockFrames;
    private int32 _RockNext = 0;
    private int32 _RockLeft = 0;
    private float32 _RockPitch = 0.0f;

    protected FMars_Tumbler_Spec Make_TestSpec()
    {
        auto Spec = FMars_Tumbler_Spec();
        Spec.Hand.WorkspaceCentreLocal = k_WorkspaceCentre;
        return Spec;
    }

    protected void BuildStation(FCk_Handle InHandle, FMars_Tumbler_Spec InSpec)
    {
        _Spec = InSpec;

        auto StationEntity = utils_entity_lifetime::Request_CreateEntity(InHandle);
        auto Root = utils_transform::Add(StationEntity, FTransform(FRotator::ZeroRotator, k_Origin), ECk_Replication::DoesNotReplicate);

        auto AxleNode = utils_scene_node::Create(Root, FTransform(FRotator::ZeroRotator, k_AxleLocal));
        // The Mover writes the node's whole offset: both poses keep the axle where it stands.
        auto AxleSpec = FMars_Mover_Spec();
        AxleSpec.StartLocation = k_AxleLocal;
        AxleSpec.EndLocation = k_AxleLocal;
        AxleSpec.EndRotation = FRotator(float64(_Spec.Drum.ArcDegrees), 0.0, 0.0);
        AxleSpec.Duration = 0.4f;
        AxleSpec.Easing = ECk_TweenEasing::InOutSine;
        _Axle = utils_mover::Add(AxleNode, AxleSpec);

        auto LeverSpec = FMars_Control_Spec();
        LeverSpec.Interaction = ECk_Interaction_CompletionPolicy::ManuallyCompleted;
        LeverSpec.Manipulation.PullAxis = FVector(-1.0, 0.0, 0.0);
        LeverSpec.Manipulation.AlphaPerDegree = 0.02f;
        LeverSpec.Manipulation.EngageAlpha = 0.85f;
        LeverSpec.Manipulation.Stiffness = 60.0f;
        LeverSpec.Manipulation.Damping = 12.0f;
        auto AxleEntity = AxleNode.H();
        _Lever = utils_control::Add(AxleEntity, LeverSpec, _Axle);
        _Lever.BindTo_OnEngaged(FMars_Delegate_Control_OnEngaged(this, n"OnLeverEngaged"));

        auto Axle = AxleNode.As_Transform();
        auto GripNode = utils_scene_node::Create(Axle,
            FTransform(FRotator::MakeFromXZ(FVector::ForwardVector, -FVector::RightVector), k_LeverGripLocal));

        auto HingeNode = utils_scene_node::Create(Axle, FTransform::Identity);
        auto HatchSpec = FMars_Mover_Spec();
        HatchSpec.EndRotation = FRotator(-70.0, 0.0, 0.0);
        HatchSpec.Duration = 0.2f;
        _HatchMover = utils_mover::Add(HingeNode, HatchSpec);

        auto Hinge = HingeNode.As_Transform();
        auto TabNode = utils_scene_node::Create(Hinge, FTransform(FRotator::ZeroRotator, k_HatchTabLocal));

        auto HandNode = utils_scene_node::Create(Root, FTransform(FRotator::ZeroRotator, k_WorkspaceCentre));
        auto ViewNode = utils_scene_node::Create(Root, FTransform(FRotator(k_ViewPitchDegrees, 0.0, 0.0), k_ViewLocal));

        _Spec.Nodes = FMars_Tumbler_Nodes(HandNode, TabNode.As_Transform(), GripNode.As_Transform(), _Lever, _HatchMover,
            Axle, ViewNode.As_Transform());
        _Tumbler = utils_tumbler::Add(StationEntity, _Spec);

        _Tumbler.BindTo_OnHandModeChanged(FMars_Delegate_Tumbler_OnHandModeChanged(this, n"OnHandModeChanged"));
        _Tumbler.BindTo_OnHoverChanged(FMars_Delegate_Tumbler_OnHoverChanged(this, n"OnHoverChanged"));
        _Tumbler.BindTo_OnHatchChanged(FMars_Delegate_Tumbler_OnHatchChanged(this, n"OnHatchChanged"));
        _Tumbler.BindTo_OnDrumChanged(FMars_Delegate_Tumbler_OnDrumChanged(this, n"OnDrumChanged"));
        _Tumbler.BindTo_OnPressRefused(FMars_Delegate_Tumbler_OnPressRefused(this, n"OnPressRefused"));
        _Tumbler.BindTo_OnPieceAdmission(FMars_Delegate_Tumbler_OnPieceAdmission(this, n"OnPieceAdmission"));
        _Tumbler.BindTo_OnPieceAdded(FMars_Delegate_Tumbler_OnPieceAdded(this, n"OnPieceAdded"));
        _Tumbler.BindTo_OnCoverageChanged(FMars_Delegate_Tumbler_OnCoverageChanged(this, n"OnCoverageChanged"));
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Operator and feed
    //----------------------------------------------------------------------------------------------------------------------

    protected void Look(FVector InLookDelta)
    {
        _Tumbler.Request_Look(FMars_Request_Tumbler_Look(InLookDelta));
    }

    protected void Press()
    {
        _Tumbler.Request_Press(FMars_Request_Tumbler_Press());
    }

    protected void Release()
    {
        _Tumbler.Request_Release(FMars_Request_Tumbler_Release());
    }

    protected void Cancel()
    {
        _Tumbler.Request_Cancel(FMars_Request_Tumbler_Cancel());
    }

    protected void SetLoading(EMars_Tumbler_Loading InLoading)
    {
        _Tumbler.Request_SetLoading(FMars_Request_Tumbler_SetLoading(InLoading));
    }

    // Piece {k_Generation, InSlot} released at the rig's release pose with preset InSlot.
    protected FMars_CookingFeed_PieceId AddPiece(int32 InSlot)
    {
        const auto PieceId = FMars_CookingFeed_PieceId(k_Generation, InSlot);
        const auto RootWorld = _Tumbler.Get_RootWorld();
        const auto ReleaseWorld = FTransform(RootWorld.GetRotation(), RootWorld.TransformPosition(k_ReleaseLocal));
        _Tumbler.Request_AddPiece(FMars_Request_Tumbler_AddPiece(FMars_CookingFeed_Release(PieceId, ReleaseWorld, FVector::ZeroVector, InSlot)));
        return PieceId;
    }

    protected FMars_CookingFeed_PieceId Make_Id(int32 InSlot) const
    {
        return FMars_CookingFeed_PieceId(k_Generation, InSlot);
    }

    // One look that puts the cursor on InAnchor's YZ projection (station frame) from the workspace centre; the kernel clamps
    // it to the reach.
    protected void LookToAnchor(const FCk_Handle_Transform& InAnchor)
    {
        const auto AnchorLocal = Get_StationLocal(InAnchor);
        const auto Target = FVector2D(AnchorLocal.Y - k_WorkspaceCentre.Y, AnchorLocal.Z - k_WorkspaceCentre.Z);
        const auto Delta = Target - _Tumbler.Get_Cursor();
        const auto Step = float64(_Spec.Hand.CmPerLookDegree);
        Look(FVector(Delta.X / Step, -Delta.Y / Step, 0.0));
    }

    protected void LookToHatch()
    {
        LookToAnchor(_Spec.Nodes.HatchTab);
    }

    protected void LookToLever()
    {
        LookToAnchor(_Spec.Nodes.LeverGrip);
    }

    protected FVector Get_StationLocal(const FCk_Handle_Transform& InNode) const
    {
        return _Tumbler.Get_RootWorld().InverseTransformPosition(utils_transform::Get_EntityCurrentLocation(InNode));
    }

    protected FVector Get_GripWorld() const
    {
        return utils_transform::Get_EntityCurrentLocation(_Spec.Nodes.LeverGrip);
    }

    // Each Add_Step_Rock looks InFrames frames in a row at InPitchDegrees (down +): a held grip rocks the lever.
    protected void Add_Step_Rock(const FString& InDisplayName, float32 InPitchDegrees, int32 InFrames)
    {
        _RockPitches.Add(InPitchDegrees);
        _RockFrames.Add(InFrames);
        Add_Step_WaitUntil(InDisplayName, n"Check_Rocked", InFrames + 10);
    }

    // The hatch opened: aim at the tab, wait for the hover, press, wait for Open.
    protected void Add_Steps_OpenHatch()
    {
        Add_Step("look at the hatch", n"Step_LookToHatch");
        Add_Step_WaitUntil("the hatch is hovered", n"Check_HoveredHatch", 0, 2.0f);
        Add_Step("press on the hatch", n"Step_Press");
        Add_Step_WaitUntil("the hatch is open", n"Check_HatchOpen", 0, 2.0f);
    }

    protected void Add_Steps_CloseHatch()
    {
        Add_Step("look at the open hatch", n"Step_LookToHatch");
        Add_Step_WaitUntil("the hatch is hovered", n"Check_HoveredHatch", 0, 2.0f);
        Add_Step("press on the hatch", n"Step_Press");
        Add_Step_WaitUntil("the hatch is closed", n"Check_HatchClosed", 0, 2.0f);
    }

    protected void Add_Steps_Grip()
    {
        Add_Step("look at the lever", n"Step_LookToLever");
        Add_Step_WaitUntil("the lever is hovered", n"Check_HoveredLever", 0, 2.0f);
        Add_Step("press on the lever", n"Step_Press");
        Add_Step_WaitUntil("the lever is gripped", n"Check_Gripped", 0, 3.0f);
    }

    //----------------------------------------------------------------------------------------------------------------------
    // State checks
    //----------------------------------------------------------------------------------------------------------------------

    protected bool Check_Hovered(EMars_Tumbler_Target InTarget) const
    {
        return _Tumbler.Get_Hovered() == InTarget;
    }

    protected bool Check_HandMode(EMars_Tumbler_HandMode InMode) const
    {
        return _Tumbler.Get_HandMode() == InMode;
    }

    protected bool Check_Hatch(EMars_Tumbler_Hatch InHatch) const
    {
        return _Tumbler.Get_Hatch() == InHatch;
    }

    protected bool Check_Drum(EMars_Tumbler_Drum InDrum) const
    {
        return _Tumbler.Get_Drum() == InDrum;
    }

    protected int32 Count_Modes(EMars_Tumbler_HandMode InMode, int32 InFromIndex) const
    {
        auto Count = 0;
        for (int32 Index = InFromIndex; Index < _HandModes.Num(); ++Index)
        {
            if (_HandModes[Index] == InMode)
            { Count += 1; }
        }

        return Count;
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Handlers
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    protected void OnHandModeChanged(FCk_Handle_Tumbler InTumbler, EMars_Tumbler_HandMode InHandMode)
    {
        _HandModes.Add(InHandMode);
    }

    UFUNCTION()
    protected void OnHoverChanged(FCk_Handle_Tumbler InTumbler, EMars_Tumbler_Target InTarget)
    {
        _Hovers.Add(InTarget);
    }

    UFUNCTION()
    protected void OnHatchChanged(FCk_Handle_Tumbler InTumbler, EMars_Tumbler_Hatch InHatch)
    {
        _Hatches.Add(InHatch);
    }

    UFUNCTION()
    protected void OnDrumChanged(FCk_Handle_Tumbler InTumbler, EMars_Tumbler_Drum InDrum)
    {
        _Drums.Add(InDrum);
    }

    UFUNCTION()
    protected void OnPressRefused(FCk_Handle_Tumbler InTumbler, EMars_Tumbler_Refusal InRefusal)
    {
        _Refusals.Add(InRefusal);
    }

    UFUNCTION()
    protected void OnPieceAdmission(FCk_Handle_Tumbler InTumbler, FMars_CookingFeed_PieceId InPieceId,
        EMars_CookingFeed_Admission InAdmission, FString InReason)
    {
        _AdmissionIds.Add(InPieceId);
        _Admissions.Add(InAdmission);
        _AdmissionReasons.Add(InReason);
    }

    UFUNCTION()
    protected void OnPieceAdded(FCk_Handle_Tumbler InTumbler, FMars_CookingFeed_PieceId InPieceId, FCk_Handle InPiece)
    {
        _AddedIds.Add(InPieceId);
        _Added.Add(InPiece);
    }

    UFUNCTION()
    protected void OnCoverageChanged(FCk_Handle_Tumbler InTumbler, FMars_CookingFeed_PieceId InPieceId, float32 InCoverage)
    {
        _CoverageIds.Add(InPieceId);
        _Coverages.Add(InCoverage);
    }

    UFUNCTION()
    protected void OnLeverEngaged(FCk_Handle_Control InControl)
    {
        _LeverEngagedCount += 1;
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Steps
    //----------------------------------------------------------------------------------------------------------------------

    // The scene nodes composed their world poses: the lever grip sits where the axle and its offset put it.
    UFUNCTION()
    protected void Check_NodesPosed(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        if (ck::Is_NOT_Valid(_Tumbler))
        {
            Res.Set(false);
            return;
        }

        const auto Expected = _Tumbler.Get_RootWorld().TransformPosition(k_AxleLocal + k_LeverGripLocal);
        Res.Set((Get_GripWorld() - Expected).Size() <= 0.01);
    }

    UFUNCTION()
    protected void Step_LookToHatch(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        LookToHatch();
    }

    UFUNCTION()
    protected void Step_LookToLever(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        LookToLever();
    }

    UFUNCTION()
    protected void Step_Press(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Press();
    }

    UFUNCTION()
    protected void Step_Release(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Release();
    }

    UFUNCTION()
    protected void Step_Cancel(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Cancel();
    }

    UFUNCTION()
    protected void Check_Rocked(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        if (_RockLeft <= 0)
        {
            if (_RockNext >= _RockPitches.Num())
            {
                Assert_True(false, "a rock step has a planned rock");
                Res.Set(true);
                return;
            }

            _RockPitch = _RockPitches[_RockNext];
            _RockLeft = _RockFrames[_RockNext];
            _RockNext += 1;
        }

        Look(FVector(0.0, float64(_RockPitch), 0.0));
        _RockLeft -= 1;
        Res.Set(_RockLeft <= 0);
    }

    UFUNCTION()
    protected void Check_HoveredHatch(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Check_Hovered(EMars_Tumbler_Target::Hatch));
    }

    UFUNCTION()
    protected void Check_HoveredLever(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Check_Hovered(EMars_Tumbler_Target::Lever));
    }

    UFUNCTION()
    protected void Check_HandFree(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Check_HandMode(EMars_Tumbler_HandMode::Free));
    }

    UFUNCTION()
    protected void Check_Reaching(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Check_HandMode(EMars_Tumbler_HandMode::Reaching));
    }

    // The kernel's hand, the lever's Control and the drum all hold the grip.
    UFUNCTION()
    protected void Check_Gripped(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Check_HandMode(EMars_Tumbler_HandMode::Gripped) && _Lever.Get_IsManipulating() && Check_Drum(EMars_Tumbler_Drum::Gripped));
    }

    UFUNCTION()
    protected void Check_HatchOpening(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Check_Hatch(EMars_Tumbler_Hatch::Opening));
    }

    UFUNCTION()
    protected void Check_HatchOpen(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Check_Hatch(EMars_Tumbler_Hatch::Open));
    }

    UFUNCTION()
    protected void Check_HatchClosing(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Check_Hatch(EMars_Tumbler_Hatch::Closing));
    }

    UFUNCTION()
    protected void Check_HatchClosed(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Check_Hatch(EMars_Tumbler_Hatch::Closed));
    }

    UFUNCTION()
    protected void Check_DrumHome(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Check_Drum(EMars_Tumbler_Drum::Home));
    }

    UFUNCTION()
    protected void Check_DrumReturning(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Check_Drum(EMars_Tumbler_Drum::Returning));
    }
}
