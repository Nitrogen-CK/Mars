// A loaded piece rides its platter's move; unloaded, it stops being a scene node where it stood, its body Kinematic, and
// drops its membership. Loaded again after the platter moves on, it drops onto the moved platter with the body it already
// has and freezes on its root again: a plain Transform becomes a scene node, is detached back to a plain Transform, and
// becomes a scene node again.
class UMars_AutoTest_Platter_UnloadKeepsTheWorldPoseAndReloadsAfterAMove : UMars_AutoTestRig_Platter
{
    private const FVector k_Origin = FVector(14000.0, -11000.0, -30000.0);

    private FCk_Handle_Platter _Platter;
    private FCk_Handle_FoodPiece _P;
    private FVector _BeforeUnload;
    private FVector _BeforeMove;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        _Platter = Build_Platter(InHandle, FTransform(FRotator(0.0, -20.0, 0.0), k_Origin), Make_PlatterSpec(2));
        _P = Build_BoxAt(FTransform(FRotator::ZeroRotator, k_Origin + FVector(100.0, 0.0, 0.0)), 0.5);

        Add_Step_WaitUntil("P is Ready", n"Check_Ready");
        Add_Step("load P", n"Step_Load");
        Add_Step_WaitUntil("P landed", n"Check_FirstLanded");
        Add_Step("record P, then move the platter 200 cm along Y", n"Step_Move");
        Add_Step_WaitFrames("the move lands and P follows", 2);
        Add_Step("record P's world, then unload it", n"Step_Unload");
        Add_Step_WaitUntil("P was unloaded", n"Check_Unloaded");
        Add_Step_WaitFrames("an unload that moved P would show here", 2);
        Add_Step("P kept its world pose and left the ledger; move the platter again and reload P", n"Step_AssertUnloadedAndReload");
        Add_Step_WaitUntil("P landed again", n"Check_SecondLanded");
        Add_Step_WaitFrames("the attach composes the world pose", 2);
        Add_Step("P froze on the moved platter", n"Step_AssertReloaded");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Check_Ready(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_HasReadied(_P));
    }

    UFUNCTION()
    private void Step_Load(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Load(_Platter, _P);
    }

    UFUNCTION()
    private void Check_FirstLanded(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_LoadedCount(_Platter) >= 1 || Get_AllRefusalCount(_Platter) > 0);
    }

    UFUNCTION()
    private void Step_Move(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _BeforeMove = Get_World(_P).GetLocation();
        Move_Platter(_Platter, Get_PlatterWorld(_Platter).GetLocation() + FVector(0.0, 200.0, 0.0));
    }

    UFUNCTION()
    private void Step_Unload(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Moved = Get_World(_P).GetLocation() - _BeforeMove;
        Assert_True(Moved.Equals(FVector(0.0, 200.0, 0.0), 0.5), f"P rode the platter's move (moved {Moved})");

        _BeforeUnload = Get_World(_P).GetLocation();
        Unload(_Platter, _P);
    }

    UFUNCTION()
    private void Check_Unloaded(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_UnloadedCount(_Platter) >= 1);
    }

    UFUNCTION()
    private void Step_AssertUnloadedAndReload(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_False(Get_IsSceneNode(_P), "the unloaded P is no longer a scene node");
        const auto Now = Get_World(_P).GetLocation();
        Assert_True(Now.Equals(_BeforeUnload, 0.1), f"the unloaded P kept its world location ({Now} vs {_BeforeUnload})");
        Assert_Equals_Int(_Platter.Get_Occupancy(), 0, "the platter is empty");
        Assert_True(ck::Is_NOT_Valid(_P.TryGet_Platter()), "the unloaded P carries no platter");
        Assert_True(TryGet_Motion(_P) == ECk_MotionType::Kinematic, "the unloaded P's body reads Kinematic");

        Move_Platter(_Platter, Get_PlatterWorld(_Platter).GetLocation() + FVector(0.0, 200.0, 0.0));
        Load(_Platter, _P);
    }

    UFUNCTION()
    private void Check_SecondLanded(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_LoadedCount(_Platter) >= 2 || Get_AllRefusalCount(_Platter) > 0);
    }

    UFUNCTION()
    private void Step_AssertReloaded(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(Get_AllRefusalCount(_Platter), 0, "nothing was refused");
        Assert_Equals_Int(Get_LoadedCount(_Platter), 2, "P landed twice");
        Assert_True(Get_IsFrozenOn(_Platter, _P), "P is frozen on the platter root again");
        Assert_True(Get_IsInsideWalls(_Platter, _P), f"P rests inside the moved platter's walls ({Get_World(_P).GetLocation()})");
        Assert_True(Get_PlatterWorld(_Platter).GetLocation().Equals(k_Origin + FVector(0.0, 400.0, 0.0), 0.1), "the platter moved 400 cm in all");
        Assert_True(_P.TryGet_Platter() == _Platter, "P carries the platter again");
    }
}
