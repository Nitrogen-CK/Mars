// After a centre chop on the real meat station, the sweep (the board release Interact_Secondary issues) releases both halves:
// each gets a Ready dynamic body of its own mass, the board holds nothing and is touched, and both keep their displays. The
// table, board, bowl and tray are static bodies, so the pieces slide toward the finished tray (+Y) and come to rest with their
// centroids above the table top, still shown and still the pieces they were.
class UMars_AutoTest_DicingStation_SweepReleasesPiecesOntoTheTable : UMars_AutoTestRig_DicingStation
{
    private const FVector k_Origin = FVector(12800.0, -9000.0, -30000.0);
    // A piece slower than this (cm/s) for k_RestPolls polls in a row is at rest: one slow poll may be the top of a tumble.
    private const float64 k_RestSpeed = 2.0;
    private const int32 k_RestPolls = 20;

    private TArray<FCk_Handle_FoodPiece> _Halves;
    private TArray<FVector> _StartCentroids;
    private int32 _RestPollsSeen = 0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Spawn_Station(InHandle, k_Origin, mars::CuttableFood_MeatSlab_Mars);

        Add_Step_WaitUntil("the station composed its Dicing and FoodBoard", n"Check_StationReady", 0, 5.0f);
        Add_Step_WaitUntil("the board holds one shown joint", n"Check_JointShown", 0, 10.0f);
        Add_Step("an operator takes the station", n"Step_Take");
        Add_Step_WaitUntil("the station's state machine is Operated", n"Check_Operated", 0, 2.0f);
        Add_Step("chop at the board's centre", n"Step_Chop");
        Add_Step_WaitUntil("the cut committed and both halves are shown", n"Check_TwoShown", 0, 5.0f);
        Add_Step("sweep the board", n"Step_Sweep");
        Add_Step_WaitUntil("both halves are released and their bodies set up", n"Check_BodiesSettled", 0, 5.0f);
        Add_Step("the board is empty and touched; each half has a Ready dynamic body and its display", n"Step_AssertReleased");
        Add_Step_WaitUntil("both pieces come to rest", n"Check_AtRest", 0, 6.0f);
        Add_Step("both rest on the furniture, moved toward the tray, still shown", n"Step_AssertOnTheTable");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_Take(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Take();
    }

    UFUNCTION()
    private void Step_Chop(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Chop();
    }

    // A chop that issued nothing settles at once so the assertions report it.
    UFUNCTION()
    private void Check_TwoShown(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set((_Issues.Num() > 0 && _Issues[0].Issued == 0) || (_PieceCuts >= 1 && _Board.Get_HeldCount() == 2 && Get_AllHeldShown()));
    }

    UFUNCTION()
    private void Step_Sweep(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Halves = _Board.Get_Held();
        Assert_Equals_Int(_Halves.Num(), 2, "two halves are on the board");
        for (const auto& Half : _Halves)
        { _StartCentroids.Add(Get_WorldCentroid(Half)); }

        _Board.Request_Release(FMars_Request_FoodBoard_Release());
    }

    // A body that failed settles at once so the assertions report it.
    UFUNCTION()
    private void Check_BodiesSettled(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Settled = _Released.Num() >= _Halves.Num();
        for (const auto& Half : _Halves)
        {
            FCk_Handle Entity = Half;
            Settled = Settled && Entity.Is_JoltBody() && utils_jolt_body::Get_SetupState(Entity.As_JoltBody()) != ECk_JoltBody_SetupState::Pending;
        }

        auto Res = OutResult;
        Res.Set(Settled);
    }

    UFUNCTION()
    private void Step_AssertReleased(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Board.Get_HeldCount(), 0, "the board holds nothing");
        Assert_False(_Board.Get_IsUntouched(), "a sweep touches the board");
        Assert_Equals_Int(_Released.Num(), 2, "both halves were released");

        for (const auto& Half : _Halves)
        {
            FCk_Handle Entity = Half;
            const auto Body = Entity.As_JoltBody();
            Assert_True(utils_jolt_body::Get_SetupState(Body) == ECk_JoltBody_SetupState::Ready,
                f"[{Half.ToString()}] has a Ready body ({utils_jolt_body::Get_SetupFailure(Body) :n} {utils_jolt_body::Get_SetupDiagnostic(Body)})");
            Assert_True(utils_jolt_body::Get_MotionType(Body) == ECk_MotionType::Dynamic, f"[{Half.ToString()}] has a dynamic body");
            Assert_True(ck::Is_NOT_Valid(Half.TryGet_FoodBoard()), f"[{Half.ToString()}] no longer belongs to the board");
            Assert_True(Get_IsShown(Half), f"[{Half.ToString()}] keeps its display");
        }
    }

    UFUNCTION()
    private void Check_AtRest(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto AllSlow = true;
        for (const auto& Half : _Halves)
        {
            FCk_Handle Entity = Half;
            AllSlow = AllSlow && utils_jolt_body::Get_LinearVelocity(Entity.As_JoltBody()).Size() < k_RestSpeed;
        }

        _RestPollsSeen = AllSlow ? _RestPollsSeen + 1 : 0;

        auto Res = OutResult;
        Res.Set(_RestPollsSeen >= k_RestPolls);
    }

    UFUNCTION()
    private void Step_AssertOnTheTable(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto StationWorld = Get_StationWorld();
        const auto TableTopZ = StationWorld.TransformPosition(FVector(0.0, 0.0, constants_station::k_CounterHeight)).Z;
        const auto Toward = StationWorld.TransformVectorNoScale(FVector::RightVector);

        for (int32 Index = 0; Index < _Halves.Num(); ++Index)
        {
            const auto Half = _Halves[Index];
            Assert_True(ck::IsValid(Half), f"released piece {Index} is alive");
            if (ck::Is_NOT_Valid(Half))
            { continue; }

            const auto Centroid = Get_WorldCentroid(Half);
            const auto Moved = (Centroid - _StartCentroids[Index]).DotProduct(Toward);
            ck::Trace(f"[DicingStation test] released piece {Index} rests at {Centroid} ({Centroid.Z - TableTopZ :.2} cm above the table top, {Moved :.1} cm toward the tray)");

            Assert_True(Centroid.Z > TableTopZ, f"[{Half.ToString()}] rests above the table top ({Centroid.Z - TableTopZ :.2} cm)");
            Assert_True(Moved > 1.0, f"[{Half.ToString()}] moved toward the tray ({Moved :.1} cm)");
            Assert_True(Get_IsShown(Half), f"[{Half.ToString()}] is still shown");
            Assert_True(Half.Get_Status() == EMars_FoodPiece_Status::Ready, f"[{Half.ToString()}] is still a Ready piece");
        }
    }
}
