// A sweep releases both held boxes (1.2 kg and 0.3 kg) of a yawed board: each gets a Ready dynamic body with no setup
// failure, leaves Held for Released in order and loses its membership, and the board is touched. Both move along the release
// velocity rotated into the world by the board. A released piece cannot be placed again (Loose). The bodies carry the
// pieces' masses: one world impulse across the motion changes each body's speed by impulse / piece mass.
class UMars_AutoTest_FoodBoard_ReleaseMakesBodiesWithPieceMass : UMars_AutoTestRig_FoodBoard
{
    private float _HeavyKg = 1.2;
    private float _LightKg = 0.3;
    private FVector _VelocityLocal = FVector(0.0, 150.0, 0.0);
    private FVector _ImpulseWorld = FVector(0.0, 0.0, 0.0);

    private FCk_Handle_FoodBoard _Board;
    private FCk_Handle_FoodPiece _Heavy;
    private FCk_Handle_FoodPiece _Light;
    private FVector _VelocityWorld;
    private FVector _HeavyStart;
    private FVector _LightStart;
    private FVector _HeavyBeforeImpulse;
    private FVector _LightBeforeImpulse;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Tuners = Make_Tuners();
        Tuners.Release.VelocityLocal = _VelocityLocal;
        Tuners.Release.Friction = 0.4f;
        Tuners.Release.Restitution = 0.05f;
        _Board = Build_Board(InHandle, FTransform(FRotator(0.0, 90.0, 0.0), FVector(5200.0, 3000.0, -42000.0)), Tuners);
        _Heavy = Build_BoxOn(_Board, FTransform(FRotator(0.0, 20.0, 0.0), FVector(0.0, 0.0, 0.0)), _HeavyKg);
        _Light = Build_BoxOn(_Board, FTransform(FRotator::ZeroRotator, FVector(40.0, 0.0, 0.0)), _LightKg);
        Place(_Board, _Heavy);
        Place(_Board, _Light);

        Add_Step_WaitUntil("both boxes are Ready and placed", n"Check_ReadyAndPlaced");
        Add_Step("sweep the board", n"Step_Release");
        Add_Step_WaitUntil("both pieces are released with Ready bodies", n"Check_BodiesReady");
        Add_Step("the ledger, the bodies, and a released piece placed again", n"Step_AssertReleased");
        Add_Step_WaitUntil("both pieces moved along the release velocity", n"Check_Moved");
        Add_Step("the motion follows the board-rotated velocity; push both across it", n"Step_AssertMotionAndPush");
        Add_Step_WaitUntil("both bodies took the impulse", n"Check_Pushed");
        Add_Step("each body's speed changed by impulse / piece mass", n"Step_AssertMass");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Check_ReadyAndPlaced(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_PlacedCount(_Board) == 2 && Get_HasReadied(_Heavy) && Get_HasReadied(_Light));
    }

    UFUNCTION()
    private void Step_Release(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _VelocityWorld = Get_BoardWorld(_Board).GetRotation().RotateVector(_VelocityLocal);
        _HeavyStart = Get_World(_Heavy).GetLocation();
        _LightStart = Get_World(_Light).GetLocation();
        _ImpulseWorld = FVector::UpVector.CrossProduct(_VelocityWorld).GetSafeNormal() * 30.0;

        auto Board = _Board;
        Board.Request_Release(FMars_Request_FoodBoard_Release());
    }

    // A body that failed settles at once so the assertions report it.
    UFUNCTION()
    private void Check_BodiesReady(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_ReleasedEvents(_Board).Num() >= 2 && Get_BodySettled(_Heavy) && Get_BodySettled(_Light));
    }

    private bool Get_BodySettled(FCk_Handle_FoodPiece InPiece) const
    {
        FCk_Handle Entity = InPiece;
        if (Entity.Is_JoltBody() == false)
        { return false; }

        return utils_jolt_body::Get_SetupState(Entity.As_JoltBody()) != ECk_JoltBody_SetupState::Pending;
    }

    UFUNCTION()
    private void Step_AssertReleased(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_False(_VelocityWorld.Equals(_VelocityLocal, 1.0), f"the board's yaw turns the release velocity ({_VelocityWorld})");

        Assert_Equals_Int(_Board.Get_HeldCount(), 0, "nothing is held");
        TArray<FCk_Handle_FoodPiece> Expected;
        Expected.Add(_Heavy);
        Expected.Add(_Light);
        Assert_True(Get_IsSameOrder(_Board.Get_Released(), Expected), "both pieces are released, in board order");
        Assert_True(Get_IsSameOrder(Get_ReleasedEvents(_Board), Expected), "OnReleased named both, in board order");
        Assert_False(_Board.Get_IsUntouched(), "a release touches the board");

        Assert_Body(_Heavy);
        Assert_Body(_Light);

        Place(_Board, _Heavy);
    }

    private void Assert_Body(FCk_Handle_FoodPiece InPiece)
    {
        FCk_Handle Entity = InPiece;
        const auto Body = Entity.As_JoltBody();
        Assert_True(utils_jolt_body::Get_SetupState(Body) == ECk_JoltBody_SetupState::Ready, f"[{InPiece.ToString()}] has a Ready body");
        Assert_True(utils_jolt_body::Get_SetupFailure(Body) == ECk_JoltBody_SetupFailure::None,
            f"[{InPiece.ToString()}] body setup failure is None (got {utils_jolt_body::Get_SetupFailure(Body) :n})");
        Assert_True(utils_jolt_body::Get_SetupDiagnostic(Body).IsEmpty(), f"[{InPiece.ToString()}] body has no diagnostic");
        Assert_True(utils_jolt_body::Get_MotionType(Body) == ECk_MotionType::Dynamic, f"[{InPiece.ToString()}] body is dynamic");
        Assert_True(ck::Is_NOT_Valid(InPiece.TryGet_FoodBoard()), f"[{InPiece.ToString()}] no longer carries the board");
    }

    UFUNCTION()
    private void Check_Moved(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_Refusals(_Board).Num() >= 1 && Get_Along(_Heavy, _HeavyStart) > 3.0 && Get_Along(_Light, _LightStart) > 3.0);
    }

    // How far InPiece has moved from InStart along the release velocity's direction.
    private float Get_Along(FCk_Handle_FoodPiece InPiece, FVector InStart) const
    {
        return (Get_World(InPiece).GetLocation() - InStart).DotProduct(_VelocityWorld.GetSafeNormal());
    }

    UFUNCTION()
    private void Step_AssertMotionAndPush(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Refusals = Get_Refusals(_Board);
        Assert_True(Refusals.Num() == 1 && Refusals[0].Piece == _Heavy && Refusals[0].Refusal == EMars_FoodBoard_PlaceRefusal::Loose,
            "a released piece placed again is refused Loose");

        Assert_Motion(_Heavy, _HeavyStart);
        Assert_Motion(_Light, _LightStart);

        _HeavyBeforeImpulse = Get_Velocity(_Heavy);
        _LightBeforeImpulse = Get_Velocity(_Light);
        Push(_Heavy);
        Push(_Light);
    }

    private void Assert_Motion(FCk_Handle_FoodPiece InPiece, FVector InStart)
    {
        auto Moved = Get_World(InPiece).GetLocation() - InStart;
        Moved.Z = 0.0;
        Assert_True(Moved.GetSafeNormal().DotProduct(_VelocityWorld.GetSafeNormal()) > 0.99,
            f"[{InPiece.ToString()}] moved horizontally along the release velocity ({Moved})");

        auto Velocity = Get_Velocity(InPiece);
        Velocity.Z = 0.0;
        Assert_True(Velocity.Equals(_VelocityWorld, 3.0), f"[{InPiece.ToString()}] moves at the release velocity ({Velocity} vs {_VelocityWorld})");
    }

    private FVector Get_Velocity(FCk_Handle_FoodPiece InPiece) const
    {
        FCk_Handle Entity = InPiece;
        return utils_jolt_body::Get_LinearVelocity(Entity.As_JoltBody());
    }

    private void Push(FCk_Handle_FoodPiece InPiece)
    {
        FCk_Handle Entity = InPiece;
        utils_jolt_body::Request_AddImpulse(Entity.As_JoltBody(), FCk_Request_JoltBody_AddImpulse(_ImpulseWorld));
    }

    UFUNCTION()
    private void Check_Pushed(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_Across(_Heavy, _HeavyBeforeImpulse) > 0.5 * _ImpulseWorld.Size() / _HeavyKg
            && Get_Across(_Light, _LightBeforeImpulse) > 0.5 * _ImpulseWorld.Size() / _LightKg);
    }

    // InPiece's change of velocity since InBefore, along the impulse.
    private float Get_Across(FCk_Handle_FoodPiece InPiece, FVector InBefore) const
    {
        return (Get_Velocity(InPiece) - InBefore).DotProduct(_ImpulseWorld.GetSafeNormal());
    }

    // Linear damping (0.05/s) takes well under 1% in the frames between the impulse and this read.
    UFUNCTION()
    private void Step_AssertMass(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto HeavyExpected = _ImpulseWorld.Size() / _HeavyKg;
        const auto LightExpected = _ImpulseWorld.Size() / _LightKg;
        Assert_Equals_Float(Get_Across(_Heavy, _HeavyBeforeImpulse), HeavyExpected, 0.03 * HeavyExpected,
            "the 1.2 kg piece's body gains impulse / 1.2 kg");
        Assert_Equals_Float(Get_Across(_Light, _LightBeforeImpulse), LightExpected, 0.03 * LightExpected,
            "the 0.3 kg piece's body gains impulse / 0.3 kg");
    }
}
