// A Catenary chain between two anchors 4 m apart on the same level with 1 m of slack (5 m of chain) lays one link per
// pitch along a curve that passes through both anchors and sags by the catenary depth. For d = 400, L = 500 the
// parameter solves 2a sinh(200 / a) = 500 (a ~ 169) and the vertex sits at a (1 - cosh(200 / a)) ~ -132 cm; the spline
// through 24 samples is marginally shorter than the true arc, so the count tolerates +/- 2 links. A second Rebuild lays
// the same chain again instead of doubling it (the HISM is a DefaultComponent and survives reruns).
class UMars_AutoTest_HangingChain_CatenaryLaysLinksAndSags : UCk_AutoTest_Base
{
    private AMars_HangingChain _Chain;

    private const float Span = 400.0;
    private const float Pitch = 10.0;
    private const float ExpectedSagZ = -132.0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        _Chain = Cast<AMars_HangingChain>(SpawnActor(AMars_HangingChain, FVector(0.0, 0.0, 5000.0), FRotator::ZeroRotator));
        if (ck::IsValid(_Chain))
        {
            _Chain.Layout = EMars_ChainLayout::Catenary;
            _Chain.EndOffset = FVector(Span, 0.0, 0.0);
            _Chain.Slack = 1.0f;
            _Chain.LinkPitchOverride = float32(Pitch);
            _Chain.AlternateRoll = true;
            _Chain.Rebuild();
        }

        Add_Step("the links count the chain and sag through the vertex", n"Step_AssertLaid");
        Add_Step("a second rebuild lays the same chain", n"Step_AssertRebuildIdempotent");
        Add_Step("cleanup", n"Step_Cleanup");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_AssertLaid(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(ck::IsValid(_Chain), "the chain actor spawned");
        if (ck::Is_NOT_Valid(_Chain))
        { return; }

        Assert_Equals_Float(_Chain.Get_ChainLength(), 500.0, 10.0, "the spline measures the straight run plus the slack");

        const int32 Count = _Chain.Get_LinkCount();
        Assert_True(Math::Abs(Count - 50) <= 2, f"one link per pitch along 5 m of chain (got {Count})");

        float LowestZ = 0.0;
        FTransform First;
        FTransform Second;
        FTransform Last;
        for (int32 Index = 0; Index < Count; ++Index)
        {
            FTransform Link;
            if (_Chain.Get_LinkTransform(Index, Link) == false)
            { continue; }

            LowestZ = Math::Min(LowestZ, Link.GetLocation().Z);
            if (Index == 0)
            { First = Link; }
            else if (Index == 1)
            { Second = Link; }
            Last = Link;
        }

        Assert_Equals_Float(LowestZ, ExpectedSagZ, 12.0, "the lowest link sits at the catenary vertex");

        // The end links centre half a pitch in from the anchors, plus up to a pitch of floor(length / pitch) remainder.
        const float AnchorSlack = Pitch * 1.5;
        Assert_True(First.GetLocation().Size() <= AnchorSlack,
            f"the first link hangs at the origin anchor (at {First.GetLocation().ToString()})");
        Assert_True((Last.GetLocation() - FVector(Span, 0.0, 0.0)).Size() <= AnchorSlack,
            f"the last link hangs at the far anchor (at {Last.GetLocation().ToString()})");

        // Neighbouring links are turned 90 degrees about the tangent: their Y axes are perpendicular.
        const float AxisDot = Math::Abs(First.GetRotation().GetAxisY().DotProduct(Second.GetRotation().GetAxisY()));
        Assert_True(AxisDot < 0.1, f"consecutive links alternate their roll (axis dot {AxisDot})");
    }

    UFUNCTION()
    private void Step_AssertRebuildIdempotent(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        if (ck::Is_NOT_Valid(_Chain))
        { return; }

        const int32 Before = _Chain.Get_LinkCount();
        _Chain.Rebuild();
        Assert_Equals_Int(_Chain.Get_LinkCount(), Before, "rebuilding clears the previous links first");
    }

    UFUNCTION()
    private void Step_Cleanup(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        if (ck::IsValid(_Chain))
        { _Chain.DestroyActor(); }
    }
}
