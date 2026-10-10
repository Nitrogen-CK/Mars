// A food taken by hand while it waits in the platter's queue stays in the hand. The platter slides (60 cm/s: a tray carried
// to a dock), so a box loaded onto it waits queued; a hand node beside it takes the box, attaching it where it is as a
// pickup's Carry would. The platter forgets the box (it never landed: no OnLoaded, no OnUnloaded), and once the platter has
// stopped long enough for a drop, the box is still on the hand node where the hand put it: no drop pulled it back.
class UMars_AutoTest_Platter_AQueuedFoodTakenByHandIsNotPulledBack : UMars_AutoTestRig_Platter
{
    private const FVector k_Origin = FVector(42000.0, -25000.0, -30000.0);
    private const float64 k_Speed = 60.0;
    // Where the hand node waits, beside the box.
    private const FVector k_HandOffset = FVector(100.0, 60.0, 40.0);
    // A piece the platter still queued would drop one Settle.DropCadenceSeconds after the root stops: watch five.
    private const float32 k_DropCadencesWatched = 5.0f;

    private FCk_Handle_Platter _Platter;
    private FCk_Handle_FoodPiece _P;
    private FCk_Handle_Transform _Hand;
    private FTransform _TakenWorld;
    private float64 _MoveStart = 0.0;
    private bool _IsMoving = false;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        const auto Spec = Make_PlatterSpec(2);
        _Platter = Build_Platter(InHandle, FTransform(FRotator::ZeroRotator, k_Origin), Spec);
        _P = Build_BoxAt(FTransform(FRotator::ZeroRotator, k_Origin + FVector(100.0, 0.0, 0.0)), 0.5);

        auto Owner = InHandle;
        auto HandEntity = utils_entity_lifetime::Request_CreateEntity(Owner);
        _Hand = utils_transform::Add(HandEntity, FTransform(FRotator::ZeroRotator, k_Origin + k_HandOffset), ECk_Replication::DoesNotReplicate);
        utils_timer::Create_Tick(Owner, FCk_Delegate_Timer(this, n"OnMoveTick"));

        Add_Step_WaitUntil("P is Ready", n"Check_Ready", 0, 0);
        Add_Step("start the platter sliding, then load P", n"Step_MoveAndLoad");
        Add_Step_WaitUntil("P is accepted and queued", n"Check_Queued", 0, 0);
        Add_Step("the hand takes P where it is", n"Step_Take");
        Add_Step_WaitUntil("the platter forgot P", n"Check_Forgotten", 0, 0);
        Add_Step("stop the platter", n"Step_Stop");
        Add_Step_WaitSeconds("a drop would happen in this window",
            Spec.Settle.DropCadenceSeconds * k_DropCadencesWatched);
        Add_Step("P stays on the hand node; it never landed or left", n"Step_AssertInTheHand");
        Run_Steps(InHandle);
    }

    // The root's location this frame: k_Speed along +Y since the start, while moving.
    UFUNCTION()
    private void OnMoveTick(FCk_Handle_Timer InHandle, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        if (_IsMoving == false)
        { return; }

        const auto Elapsed = float64(System::GetGameTimeInSeconds()) - _MoveStart;
        Move_Platter(_Platter, k_Origin + FVector(0.0, k_Speed * Elapsed, 0.0));
    }

    UFUNCTION()
    private void Check_Ready(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_HasReadied(_P));
    }

    UFUNCTION()
    private void Step_MoveAndLoad(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _MoveStart = float64(System::GetGameTimeInSeconds());
        _IsMoving = true;
        Load(_Platter, _P);
    }

    UFUNCTION()
    private void Check_Queued(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_P.TryGet_Platter() == _Platter && _Platter.Get_Fragment(FMars_Fragment_Platter).Queue.Contains(_P));
    }

    UFUNCTION()
    private void Step_Take(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_False(Get_IsSceneNode(_P), "P waits in the queue unattached");
        Assert_False(TryGet_Motion(_P).IsSet(), "P was never dropped: it has no body");

        _TakenWorld = Get_World(_P);
        FCk_Handle Entity = _P;
        auto PieceTransform = Entity.As_Transform();
        const auto HandWorld = utils_transform::Get_EntityCurrentTransform(_Hand);
        utils_scene_node::Add(PieceTransform, _Hand, _TakenWorld.GetRelativeTransform(HandWorld));
    }

    UFUNCTION()
    private void Check_Forgotten(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(ck::Is_NOT_Valid(_P.TryGet_Platter()));
    }

    UFUNCTION()
    private void Step_Stop(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Platter.Get_Occupancy(), 0, "the platter holds nothing");
        _IsMoving = false;
    }

    UFUNCTION()
    private void Step_AssertInTheHand(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(Get_Parent(_P) == _Hand, "P's parent is still the hand node");
        Assert_True(Get_World(_P).GetLocation().Equals(_TakenWorld.GetLocation(), 0.5), "P stayed where the hand took it");
        Assert_False(TryGet_Motion(_P).IsSet(), "no drop gave P a body");
        Assert_Equals_Int(Get_LoadedCount(_Platter), 0, "no OnLoaded");
        Assert_Equals_Int(Get_UnloadedCount(_Platter), 0, "no OnUnloaded");
        Assert_Equals_Int(Get_AllRefusalCount(_Platter), 0, "no refusal");
        Assert_Equals_Int(_Platter.Get_Occupancy(), 0, "the platter is still empty");
    }
}
