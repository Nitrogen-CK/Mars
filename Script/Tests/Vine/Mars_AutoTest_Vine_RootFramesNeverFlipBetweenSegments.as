// A vertical 3-storey GiantRoot: along every spline-segment chain (consecutive segments share an end point) the up
// directions of neighbouring segments never turn more than 90 degrees (dot > 0) and stay within 30 degrees on 95 % of
// the joints. The rotation-minimising frames give a vertical drop a stable up instead of the default (0, 0, 1), which
// would be parallel to its tangent.
class UMars_AutoTest_Vine_RootFramesNeverFlipBetweenSegments : UMars_AutoTestRig_Vine
{
    default _Slot = 11;
    private AMars_Vine _Vine;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Add_Step("a three-storey atrium", n"Step_Room");
        Add_Step_WaitFrames("let the slab bodies register", 2);
        Add_Step("a giant root", n"Step_Vine");
        Add_Step("the segment frames never flip", n"Step_Assert");
        Add_Step("cleanup", n"Step_Cleanup");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_Room(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto O = Get_Origin();
        SpawnFloor(O, O.Z, FVector(1600.0, 1600.0, 50.0));
        SpawnCeiling(O, O.Z + 1050.0, FVector(1600.0, 1600.0, 50.0));
    }

    UFUNCTION()
    private void Step_Vine(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Spawn = Make_Spawn(Make_Profile(EMars_VinePreset::GiantRoot), EMars_VineLayout::Drop, EMars_VineEnd::Ground);
        Spawn.Location = Get_Origin() + FVector(0.0, 0.0, 900.0);
        Spawn.Seed = 777;
        _Vine = SpawnVine(Spawn);
    }

    UFUNCTION()
    private void Step_Assert(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        if (ck::Is_NOT_Valid(_Vine))
        { return; }

        TArray<UPrimitiveComponent> Emitted;
        _Vine.Get_EmittedComponents(Emitted);
        TArray<USplineMeshComponent> Segments;
        for (auto Component : Emitted)
        {
            auto Segment = Cast<USplineMeshComponent>(Component);
            if (ck::IsValid(Segment))
            { Segments.Add(Segment); }
        }
        Assert_True(Segments.Num() > 10, f"the root laid segments ({Segments.Num()})");

        int32 Joints = 0;
        int32 Calm = 0;
        int32 Flips = 0;
        const auto Cos30 = Math::Cos(Math::DegreesToRadians(30.0));
        for (int32 Index = 0; Index + 1 < Segments.Num(); ++Index)
        {
            const auto A = Segments[Index];
            const auto B = Segments[Index + 1];
            if (A.GetEndPosition().Distance(B.GetStartPosition()) > 0.01)
            { continue; }

            ++Joints;
            const auto Dot = A.GetSplineUpDir().GetSafeNormal().DotProduct(B.GetSplineUpDir().GetSafeNormal());
            if (Dot <= 0.0)
            { ++Flips; }
            if (Dot > Cos30)
            { ++Calm; }
        }
        Assert_True(Joints >= 10, f"the chains were walked ({Joints} joints)");
        Assert_Equals_Int(Flips, 0, "no joint turns its up direction more than 90 degrees");
        Assert_True(float(Calm) >= 0.95 * float(Joints), f"95 % of joints turn less than 30 degrees ({Calm} of {Joints})");
    }
}
