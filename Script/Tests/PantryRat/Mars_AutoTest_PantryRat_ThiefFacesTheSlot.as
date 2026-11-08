// The thief faces the slot it steals from. A rat is placed at its target slot's work point with its root yawed 180 deg
// away from the slot and advanced straight to Observe, so its only way to the claim is Observe -> Inspect (with the lease)
// -> ClaimTell -> the claim, standing still. From 0.6 s after Inspect began until the claim, the planar dot of the root's
// forward with (slot - rat) stays >= 0.95, and the rat turned in place (within 5 cm of where Inspect found it). Once the
// thief flees, a Face sent while its move runs is dropped by the navigator (a move owns the steer).
class UMars_AutoTest_PantryRat_ThiefFacesTheSlot : UMars_AutoTestRig_PantryRaid
{
    default _TimeoutSeconds = 60.0f;

    private const int32 k_OperationId = 931;
    private const float32 k_TurnSeconds = 0.6f;
    private const float64 k_FacingDot = 0.95;

    private FCk_Handle _ThiefEntity;
    private FCk_Handle_PantryRat _Thief;
    private FVector _WorkPoint;
    private FVector _AwayDirection;
    private bool _Advanced = false;
    private TOptional<float32> _InspectAt;
    private float64 _DotAtInspect = 0.0;
    private FVector _InspectLocation;
    private float64 _MinDot = 1.0;
    private int32 _Samples = 0;
    private float64 _MaxDrift = 0.0;
    private bool _SawClaimTell = false;
    private bool _ClaimSeen = false;
    private FString _FirstLowDot;
    private int32 _FacesAtClaim = 0;
    private int32 _DroppedBefore = -1;
    private int32 _AppliedBefore = -1;
    private bool _FleeFaceSent = false;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        _Origin = FVector(752000.0, -200000.0, -60000.0);
        _Spec = Make_CourtSpec();
        _Spec.Population.ResidentsPerDen = 1;
        _Spec.Scent.NoTargetReturnSeconds = 600.0f;
        Arrange_Court(InHandle, 0);
        utils_timer::Create_Tick(InHandle, FCk_Delegate_Timer(this, n"OnWatch"));

        Add_CourtSteps();
        Add_Step_WaitUntil("the armed pack is a target; its slot's work point is known", n"Check_Target", k_LongPolls, 0);
        Add_Step("a rat at the work point, yawed 180 deg away from the slot", n"Step_Spawn");
        Add_Step_WaitUntil("the placed rat is in Observe at the work point", n"Check_Placed", k_LongPolls, 0);
        Add_Step_WaitUntil("the placed rat inspects, rummages and claims", n"Check_Claimed", k_LongPolls, 0);
        Add_Step_WaitUntil("the loaded thief's flee move runs; a Face is sent into it", n"Check_FleeFace", k_LongPolls, 0);
        Add_Step("the thief faced the slot through Inspect and ClaimTell; the mid-move Face was dropped", n"Step_Assert");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Check_Target(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        if (ck::Is_NOT_Valid(_Raid) || _Raid.Get_IsReady() == false)
        {
            Result.Set(false);
            return;
        }

        auto Query = FMars_PantryRaid_TargetQuery();
        Query.RatLocation = _Origin + k_PackOffset - FVector(150.0, 0.0, 0.0);
        Query.Seed = k_OperationId;
        const auto View = _Raid.TryGet_Target(Query);
        if (View.IsSet() == false || View.GetValue().Guarded)
        {
            Result.Set(false);
            return;
        }

        _WorkPoint = utils_pantry_raid::Get_WorkPoint(View.GetValue().SlotLocation, View.GetValue().PackLocation,
            _Spec.Theft.WorkStandoffCm, _Origin.Z);
        auto Away = _WorkPoint - View.GetValue().SlotLocation;
        Away.Z = 0.0;
        _AwayDirection = Away.GetSafeNormal();
        Result.Set(true);
    }

    UFUNCTION()
    private void Step_Spawn(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Spec = FMars_PantryRat_Spec();
        Spec.Links.Raid = _RaidEntity;
        Spec.Links.Den = _DenEntity;
        Spec.Links.ResidentSlot = 0;
        Spec.Links.OperationId = k_OperationId;
        Spec.Tuning = utils_pantry_raid::Make_RatTuning(_Spec);

        auto Params = UMars_PantryRat_EntityScript::Params();
        Params.SpawnTransform = FTransform(_AwayDirection.Rotation(), _WorkPoint);
        Params.Spec = Spec;
        _ThiefEntity = utils_entity_script::Request_SpawnEntity(InHandle, UMars_PantryRat_EntityScript, Params).Get_EntityUnderConstruction();
        _OwnedExtra.Add(_ThiefEntity);
    }

    // Straight to Observe (the den's emergence walk is not part of this test); a Creep move the control layer asked before
    // the advance landed is stopped.
    UFUNCTION()
    private void Check_Placed(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        _Thief = _ThiefEntity.As_PantryRat(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(_Thief))
        {
            Result.Set(false);
            return;
        }

        if (_Advanced == false)
        {
            _Advanced = true;
            _Thief.Request_Stop(FMars_Request_PantryRat_Stop());
            _Thief.Request_Advance(FMars_Request_PantryRat_Advance(EMars_PantryRat_Phase::Emerge, EMars_PantryRat_Phase::Observe));
            Result.Set(false);
            return;
        }

        if (_Thief.Get_Route().Status == EMars_PantryRat_RouteStatus::Moving && _Thief.Has_Fragment(FMars_Fragment_PantryRat_Requests) == false)
        { _Thief.Request_Stop(FMars_Request_PantryRat_Stop()); }

        Result.Set(_Thief.Get_Phase() != EMars_PantryRat_Phase::Emerge);
    }

    private float64 Get_SlotDot() const
    {
        const auto Target = _Thief.Get_Target();
        if (Target.IsSet() == false)
        { return -2.0; }

        FCk_Handle SlotEntity = Target.GetValue().Pack.As_Backpack().Get_CargoSlot(Target.GetValue().Slot);
        auto ToSlot = utils_transform::Get_EntityCurrentLocation(SlotEntity.As_Transform()) - _Thief.Get_Location();
        ToSlot.Z = 0.0;
        auto Forward = utils_transform::Get_EntityCurrentRotation(_Thief.As_Transform()).GetForwardVector();
        Forward.Z = 0.0;
        return Forward.GetSafeNormal().DotProduct(ToSlot.GetSafeNormal());
    }

    UFUNCTION()
    private void OnWatch(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        if (IsFinished() || ck::Is_NOT_Valid(_Thief) || _ClaimSeen)
        { return; }

        const auto Phase = _Thief.Get_Phase();
        if (Phase == EMars_PantryRat_Phase::Inspect && _InspectAt.IsSet() == false)
        {
            _InspectAt = TOptional<float32>(_Thief.Get_Clock() - _Thief.Get_PhaseAge());
            _DotAtInspect = Get_SlotDot();
            _InspectLocation = _Thief.Get_Location();
        }

        if (_InspectAt.IsSet() == false)
        { return; }

        if (Phase == EMars_PantryRat_Phase::Inspect || Phase == EMars_PantryRat_Phase::ClaimTell)
        {
            _SawClaimTell = _SawClaimTell || Phase == EMars_PantryRat_Phase::ClaimTell;
            _MaxDrift = Math::Max(_MaxDrift, (_Thief.Get_Location() - _InspectLocation).Size2D());
            const auto Since = _Thief.Get_Clock() - _InspectAt.GetValue();
            if (Since >= k_TurnSeconds)
            {
                const auto Dot = Get_SlotDot();
                ++_Samples;
                if (Dot < k_FacingDot && _FirstLowDot.IsEmpty())
                { _FirstLowDot = f"dot [{Dot}] at [{Since}] s in [{Phase :n}]"; }
                _MinDot = Math::Min(_MinDot, Dot);
            }
            return;
        }

        // The claim was requested: ClaimTell ended in ClaimTransfer (or straight in its answer).
        if (_Thief.Get_ClaimTransfersIssued() > 0)
        {
            _ClaimSeen = true;
            _FacesAtClaim = _Thief.Get_FacesIssued();
        }
    }

    UFUNCTION()
    private void Check_Claimed(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_ClaimSeen);
    }

    UFUNCTION()
    private void Check_FleeFace(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        auto Navigator = _Thief.Get_Navigator();
        if (_FleeFaceSent)
        {
            Result.Set(Navigator.Get_HasPendingRequests() == false);
            return;
        }

        if (_Thief.Get_Phase() != EMars_PantryRat_Phase::FleeWithLoot || Navigator.Get_Status() != EMars_SurfaceNavigator_Status::Moving
            || Navigator.Get_HasPendingRequests())
        {
            Result.Set(false);
            return;
        }

        _DroppedBefore = Navigator.Get_FacesDropped();
        _AppliedBefore = Navigator.Get_FacesApplied();
        const auto Forward = utils_transform::Get_EntityCurrentRotation(_Thief.As_Transform()).GetForwardVector();
        Navigator.Request_Face(FMars_Request_SurfaceNavigator_Face(FVector(-Forward.Y, Forward.X, 0.0)));
        _FleeFaceSent = true;
        Result.Set(false);
    }

    UFUNCTION()
    private void Step_Assert(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_DotAtInspect <= -0.8, f"the rat began Inspect facing away from the slot (dot {_DotAtInspect})");
        Assert_True(_SawClaimTell, "the rat rummaged (ClaimTell) before its claim");
        Assert_True(_Samples > 10, f"the heading was sampled through Inspect and ClaimTell ({_Samples} frames)");
        Assert_True(_MinDot >= k_FacingDot, f"from {k_TurnSeconds} s after Inspect began until the claim the rat faced the slot "
            + f"(min dot {_MinDot}; first below {k_FacingDot}: {_FirstLowDot})");
        Assert_True(_MaxDrift <= 5.0, f"the rat turned in place (drifted {_MaxDrift} cm during Inspect / ClaimTell)");
        Assert_True(_FacesAtClaim >= 3, f"the kernel faced the slot on Inspect, ClaimTell and the claim ({_FacesAtClaim} Faces)");

        auto Navigator = _Thief.Get_Navigator();
        Assert_Equals_Int(Navigator.Get_FacesDropped(), _DroppedBefore + 1, "the Face sent during the flee move was dropped");
        Assert_Equals_Int(Navigator.Get_FacesApplied(), _AppliedBefore, "no Face was applied while the move ran");
    }
}
