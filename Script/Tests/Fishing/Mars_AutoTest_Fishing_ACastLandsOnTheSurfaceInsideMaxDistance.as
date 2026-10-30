// A full-power cast down the frame's X leaves the anchor (OnCast once, forward and upward), flies, and meets the water at
// Z = SurfaceZ about MaxDistanceCm out (OnBaitLanded once, at the bait); the line out is that horizontal distance and the
// spot is Waiting. A cast before Engage is refused.
class UMars_AutoTest_Fishing_ACastLandsOnTheSurfaceInsideMaxDistance : UMars_AutoTestRig_Fishing
{
    default _TimeoutSeconds = 15.0f;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        BuildFishing(InHandle, Make_SpecWithNodes(InHandle));

        Add_Step("cast before engaging", n"Step_CastFull");
        Add_Step_WaitSeconds("a beat", 0.2f);
        Add_Step("the unengaged cast was refused", n"Step_AssertRefused");
        Add_Step("engage", n"Step_Engage");
        Add_Step_WaitUntil("the spot is engaged", n"Check_Engaged");
        Add_Step("cast at full power", n"Step_CastFull");
        Add_Step_WaitUntil("the bait is on the water", n"Check_Waiting");
        Add_Step("the bait landed on the surface inside the max distance", n"Step_AssertLanded");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_AssertRefused(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Fishing.Get_Phase() == EMars_Fishing_Phase::Idle, "the spot is still Idle");
        Assert_Equals_Int(_Casts, 0, "no OnCast");
    }

    UFUNCTION()
    private void Step_AssertLanded(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Spec = _Fishing.Get_Spec();
        Assert_Equals_Int(_Casts, 1, "one OnCast");
        Assert_True(_LastLaunchVelocity.X > 0.0 && _LastLaunchVelocity.Z > 0.0 && Math::Abs(_LastLaunchVelocity.Y) < 0.001,
            f"the launch is forward and up along X ({_LastLaunchVelocity})");
        Assert_Equals_Int(_BaitLandings, 1, "one OnBaitLanded");
        Assert_Equals_Int(Count_PhaseSeen(EMars_Fishing_Phase::Casting), 1, "Casting was broadcast once");
        Assert_Equals_Int(Count_PhaseSeen(EMars_Fishing_Phase::Waiting), 1, "Waiting was broadcast once");

        const auto Bait = _Fishing.Get_Bait();
        Assert_Equals_Float(float(Bait.Position.Z), float(Spec.Water.SurfaceZ), 0.001f, "the bait sits on the surface");
        Assert_Equals_Float(float(_LastLandingPoint.Z), float(Spec.Water.SurfaceZ), 0.001f, "OnBaitLanded carried the surface point");
        Assert_True(_LastLandingPoint.Equals(Bait.Position, 0.001), "OnBaitLanded carried the bait's position");

        const auto Distance = Get_BaitHorizontalDistance();
        Assert_True(Distance >= Spec.Launch.MaxDistanceCm - 5.0f && Distance <= Spec.Launch.MaxDistanceCm + 40.0f,
            f"the bait landed about MaxDistanceCm out ({Distance} cm of {Spec.Launch.MaxDistanceCm})");
        Assert_Equals_Float(_Fishing.Get_LineLengthCm(), Distance, 0.01f, "the line out is the horizontal distance");
        Assert_True(Math::Abs(Bait.Position.Y) < 1.0, f"the bait stayed on the frame's X ({Bait.Position})");
        Assert_True(_Fishing.Get_HasLineOut(), "a line is out");
    }
}
