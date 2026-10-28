// Isolated authored traversal prototype. Reuses the crawler's assembly and the public articulation/action player.
// This does not change the autonomous crawler's layouts, gait, combat, or navigation contract.
struct FMars_Crawler_DoorwayPose
{
    FVector Body;
    TArray<FVector> Feet;
    TArray<FVector> Bends;
    FString Label;
    float64 Seconds = 0.5;
    bool Intermediate = false;
}

struct FMars_Crawler_DoorwayPortal
{
    UPROPERTY()
    float64 Width = 200.0;
    UPROPERTY()
    float64 Height = 220.0;
    UPROPERTY()
    float64 Depth = 40.0;
}

struct FMars_Crawler_DoorwayBox
{
    FTransform Frame;
    FVector Half;
    FVector Min;
    FVector Max;
    TArray<FVector> Axes;
    int32 Leg = -1;

    FMars_Crawler_DoorwayBox() {}
    FMars_Crawler_DoorwayBox(FTransform InFrame, FVector InHalf, int32 InLeg)
    {
        Frame = InFrame;
        Half = InHalf;
        Leg = InLeg;
        Axes.Add(Frame.GetRotation().GetForwardVector());
        Axes.Add(Frame.GetRotation().GetRightVector());
        Axes.Add(Frame.GetRotation().GetUpVector());
        const auto X = Axes[0] * Half.X;
        const auto Y = Axes[1] * Half.Y;
        const auto Z = Axes[2] * Half.Z;
        const auto Extent = FVector(Math::Abs(X.X) + Math::Abs(Y.X) + Math::Abs(Z.X),
            Math::Abs(X.Y) + Math::Abs(Y.Y) + Math::Abs(Z.Y), Math::Abs(X.Z) + Math::Abs(Y.Z) + Math::Abs(Z.Z));
        Min = Frame.GetLocation() - Extent;
        Max = Frame.GetLocation() + Extent;
    }
}

namespace utils_crawler
{
    const FVector DoorwayBodyHalfExtents = FVector(80.0, 47.5, 40.0);
    const float32 DoorwayBoneLength = 180.0f;
    const float64 DoorwayStartX = -340.0;
    const float64 DoorwayStandingHeight = 270.0;
    const float64 DoorwayLoweredHeight = 110.0;
    const float64 DoorwayFootHeight = 8.0;

    FVector Get_DoorwayHip(int32 InIndex)
    {
        const auto Pair = InIndex < 4 ? InIndex : 7 - InIndex;
        // Two separate lateral lanes per side prevent one arch passing through the neighbouring arch. Short rigid
        // coxae connect these attachment points to the body; they are rendered and clearance-tested too.
        const auto Lateral = Pair == 0 || Pair == 3 ? 60.0 : 80.0;
        return FVector(75.0 - 50.0 * Pair, InIndex < 4 ? Lateral : -Lateral, 0.0);
    }

    float64 Get_DoorwayTallFootY(int32 InPair)
    { return InPair == 0 || InPair == 3 ? 240.0 : 205.0; }

    int32 Get_DoorwayPairOrder(int32 InStep)
    { return InStep == 2 ? 3 : (InStep == 3 ? 2 : InStep); }

    FTransform Get_DoorwayCoxaOffset(int32 InIndex)
    {
        const auto Hip = Get_DoorwayHip(InIndex);
        return FTransform(FVector(Hip.X, (Math::Abs(Hip.Y) + DoorwayBodyHalfExtents.Y) * 0.5 * (Hip.Y > 0.0 ? 1.0 : -1.0), 0.0));
    }

    FVector Get_DoorwayCoxaHalfExtents(int32 InIndex)
    { return FVector(6.0, (Math::Abs(Get_DoorwayHip(InIndex).Y) - DoorwayBodyHalfExtents.Y) * 0.5, 6.0); }

    FVector Get_DoorwayBend(int32 InIndex)
    {
        return FVector(0.0, InIndex < 4 ? 1.0 : -1.0, 1.0);
    }

    // Visible silhouette parts also participate in the swept-world and leg/body audits.
    TArray<FMars_Crawler_DoorwayBox> Make_DoorwaySilhouette()
    {
        auto Parts = TArray<FMars_Crawler_DoorwayBox>();
        Parts.Add(FMars_Crawler_DoorwayBox(FTransform(FVector(-35.0, 0.0, 24.0)), FVector(55.0, 44.0, 44.0), -1));
        Parts.Add(FMars_Crawler_DoorwayBox(FTransform(FVector(110.0, 0.0, -80.0)), FVector(22.0, 26.0, 22.0), -1));
        Parts.Add(FMars_Crawler_DoorwayBox(FTransform(FRotator(-45.0, 0.0, 0.0), FVector(80.0, 0.0, -60.0)), FVector(28.284, 18.0, 12.0), -1));
        for (int32 Side = -1; Side <= 1; Side += 2)
        {
            Parts.Add(FMars_Crawler_DoorwayBox(FTransform(FVector(134.0, Side * 10.0, -80.0)), FVector(2.0), -1));
        }
        return Parts;
    }

    TArray<FCk_ProceduralLeg_Spec> Make_DoorwayLegs()
    {
        auto Legs = TArray<FCk_ProceduralLeg_Spec>();
        for (int32 Index = 0; Index < 8; ++Index)
        {
            const auto Hip = Get_DoorwayHip(Index);
            const auto Front = Hip.X > 0.0;
            const auto Pair = Index < 4 ? Index : 7 - Index;
            auto Foot = FVector(Hip.X + (Front ? 100.0 : -100.0), Get_DoorwayTallFootY(Pair) * (Hip.Y > 0.0 ? 1.0 : -1.0),
                DoorwayFootHeight - DoorwayStandingHeight);
            auto Lengths = TArray<float32>();
            Lengths.Add(DoorwayBoneLength);
            Lengths.Add(DoorwayBoneLength);
            auto Geometry = FCk_ProceduralLeg_ChainGeometry();
            Geometry.Set_SegmentLengths(Lengths);
            Geometry.Set_PoleLocal(Get_DoorwayBend(Index) * 400.0);
            Legs.Add(FCk_ProceduralLeg_Spec(FName(f"Leg{Index}"), FCk_ProceduralLeg_Placement(Hip, Foot), Geometry));
        }
        return Legs;
    }

    asset Mars_CrawlerDoorwayRig8 of UCk_ProceduralRig_Data
    {
        _Legs.Append(utils_crawler::Make_DoorwayLegs());
    }

    FMars_Validation Validate_DoorwayPortal(const FMars_Crawler_DoorwayPortal& InPortal)
    {
        // Brace targets touch the faces of this exact authored frame. A wider/taller/shallower frame also needs a
        // different clip: fitting the body alone does not prove that a foot can plant on its masonry.
        if (Math::IsFinite(InPortal.Width) == false || Math::IsFinite(InPortal.Height) == false ||
            Math::IsFinite(InPortal.Depth) == false)
        { return FMars_Validation("Doorway dimensions must be finite"); }
        if (Math::Abs(InPortal.Width - 200.0) > 0.01 || Math::Abs(InPortal.Height - 220.0) > 0.01 ||
            Math::Abs(InPortal.Depth - 40.0) > 0.01)
        { return FMars_Validation("This authored traversal requires a 200 x 220 cm clear opening, 40 cm deep"); }
        return FMars_Validation();
    }

    void Append_DoorwayPose(TArray<FMars_Crawler_DoorwayPose>& InOutPoses,
        const FMars_Crawler_DoorwayPose& InPose, const FString& InLabel)
    {
        auto Pose = InPose;
        Pose.Label = InLabel;
        InOutPoses.Add(Pose);
    }

    void Move_DoorwayPair(TArray<FMars_Crawler_DoorwayPose>& InOutPoses, int32 InPair,
        const FVector& InRightTarget, float64 InSeconds = 0.22)
    {
        auto Pose = InOutPoses.Last();
        const auto Left = 7 - InPair;
        const auto RightStart = Pose.Feet[InPair];
        const auto LeftStart = Pose.Feet[Left];
        const auto RightTarget = InRightTarget;
        const auto LeftTarget = FVector(RightTarget.X, -RightTarget.Y, RightTarget.Z);
        Pose.Seconds = InSeconds * 0.5;
        Pose.Intermediate = true;
        Pose.Feet[InPair] = (RightStart + RightTarget) * 0.5 + FVector(0.0, 0.0, 24.0);
        Pose.Feet[Left] = (LeftStart + LeftTarget) * 0.5 + FVector(0.0, 0.0, 24.0);
        Append_DoorwayPose(InOutPoses, Pose, f"LiftPair{InPair}");
        Pose.Feet[InPair] = RightTarget;
        Pose.Feet[Left] = LeftTarget;
        Pose.Intermediate = false;
        Append_DoorwayPose(InOutPoses, Pose, f"PlantPair{InPair}");
    }

    void Bend_DoorwayPair(TArray<FMars_Crawler_DoorwayPose>& InOutPoses, int32 InPair, FVector InRightBend)
    {
        auto Pose = InOutPoses.Last();
        Pose.Bends[InPair] = InRightBend;
        Pose.Bends[7 - InPair] = FVector(InRightBend.X, -InRightBend.Y, InRightBend.Z);
        Pose.Seconds = 0.1;
        Append_DoorwayPose(InOutPoses, Pose, f"AimKnees{InPair}");
    }

    // Author receiving-room coordinates in cm, then convert to the action's RootAtStart space.
    void Reach_DoorwayPair(TArray<FMars_Crawler_DoorwayPose>& InOutPoses, int32 InPair, FVector InTarget)
    {
        Move_DoorwayPair(InOutPoses, InPair, InTarget - FVector(DoorwayStartX, 0.0, DoorwayStandingHeight));
    }

    // A moving handoff, not a separate foot swing followed by a body hold. Six feet remain planted while one
    // bilateral pair transfers; all body keys advance at positive velocity until the trailing legs clear.
    void Append_DoorwayMovingPair(TArray<FMars_Crawler_DoorwayPose>& InOutPoses, int32 InPair,
        const FVector& InTarget, const FVector& InBend, float64 InSeconds, const FString& InLabel)
    {
        const auto Start = InOutPoses.Last();
        Move_DoorwayPair(InOutPoses, InPair, InTarget, InSeconds);
        for (int32 Key = 0; Key < 2; ++Key)
        {
            const auto Index = InOutPoses.Num() - 2 + Key;
            auto Pose = InOutPoses[Index];
            const auto Alpha = (Key + 1) * 0.5;
            Pose.Body.X = Start.Body.X + 20.0 * Alpha;
            Pose.Bends[InPair] = Math::Lerp(Start.Bends[InPair], InBend, Alpha);
            Pose.Bends[7 - InPair] = FVector(Pose.Bends[InPair].X, -Pose.Bends[InPair].Y, Pose.Bends[InPair].Z);
            if (Key == 1)
            { Pose.Label = InLabel; }
            InOutPoses[Index] = Pose;
        }
    }

    TArray<FMars_Crawler_DoorwayPose> Make_DoorwayPoses()
    {
        auto Poses = TArray<FMars_Crawler_DoorwayPose>();
        auto Pose = FMars_Crawler_DoorwayPose();
        for (int32 Index = 0; Index < 8; ++Index)
        {
            Pose.Feet.Add(Mars_CrawlerDoorwayRig8.Get_Legs()[Index].Get_Placement().Get_RestFootLocal());
            Pose.Bends.Add(Get_DoorwayBend(Index));
        }
        Append_DoorwayPose(Poses, Pose, "TallHeadFirst");
        Pose.Body.Z = DoorwayLoweredHeight - DoorwayStandingHeight;
        Pose.Seconds = 0.65;
        for (int32 Index = 0; Index < 8; ++Index)
        { Pose.Bends[Index] = FVector::UpVector; }
        Append_DoorwayPose(Poses, Pose, "CrouchBeforeEntry");
        for (int32 Order = 0; Order < 4; ++Order)
        {
            const auto Pair = Get_DoorwayPairOrder(Order);
            auto Target = Poses.Last().Feet[Pair];
            Target.Y = Get_DoorwayHip(Pair).Y;
            if (Pair >= 2)
            { Target.X -= 80.0; }
            Move_DoorwayPair(Poses, Pair, Target);
        }
        const auto Origin = FVector(DoorwayStartX, 0.0, DoorwayStandingHeight);
        // Catch the entry face while approaching, then unhook toward the hip. The body advances throughout both
        // grips and releases. Moving these contacts to the receiving face needs a different, independently checked path.
        Append_DoorwayMovingPair(Poses, 0, FVector(-28.0, 60.0, 235.0) - Origin,
            FVector::UpVector, 0.22, "MovingLintelGrip");
        Append_DoorwayMovingPair(Poses, 1, FVector(-28.0, 145.0, 150.0) - Origin,
            FVector::UpVector, 0.22, "MovingJambGrip");
        Append_DoorwayMovingPair(Poses, 0, FVector(-105.0, 60.0, DoorwayFootHeight) - Origin,
            FVector::UpVector, 0.22, "MovingLintelRelease");
        Append_DoorwayMovingPair(Poses, 1, FVector(-135.0, 80.0, DoorwayFootHeight) - Origin,
            FVector::UpVector, 0.22, "MovingJambRelease");
        for (int32 Step = 0; Step < 34; ++Step)
        {
            const auto Pair = Get_DoorwayPairOrder(Step % 4);
            auto Target = Poses.Last().Feet[Pair] + FVector(80.0, 0.0, 0.0);
            auto Bend = Poses.Last().Bends[Pair];
            // Inner front pair opens first, followed by the outer pair. Both unfold into free receiving-room space
            // during their ordinary swing; neither adds a body pause at the threshold.
            if (Step == 13 || Step == 16)
            {
                Target.Y = Get_DoorwayTallFootY(Pair);
                Bend = Get_DoorwayBend(Pair);
            }
            Append_DoorwayMovingPair(Poses, Pair, Target, Bend, 0.12, f"StridePair{Pair}");
        }
        // All geometry is beyond the far face before these recovery/rise poses. The timing audit uses the actual
        // trailing box, not this label, to decide when the crossing ends.
        for (int32 Order = 3; Order >= 2; --Order)
        {
            const auto Pair = Get_DoorwayPairOrder(Order);
            const auto Hip = Get_DoorwayHip(Pair);
            const auto X = 420.0 + Hip.X - 100.0;
            Reach_DoorwayPair(Poses, Pair, FVector(X, Hip.Y, DoorwayFootHeight));
            Reach_DoorwayPair(Poses, Pair, FVector(X, Get_DoorwayTallFootY(Pair), DoorwayFootHeight));
            Bend_DoorwayPair(Poses, Pair, Get_DoorwayBend(Pair));
        }
        Pose = Poses.Last();
        Pose.Body.Z = 0.0;
        Pose.Seconds = 0.7;
        Append_DoorwayPose(Poses, Pose, "StandAfterTrailingLegsClear");
        Pose.Seconds = 0.5;
        Append_DoorwayPose(Poses, Pose, "ExitHold");
        const auto ForwardCount = Poses.Num();
        for (int32 Index = ForwardCount - 2; Index >= 0; --Index)
        {
            Pose = Poses[Index];
            Pose.Seconds = Poses[Index + 1].Seconds;
            Append_DoorwayPose(Poses, Pose, f"Return{Index}");
        }
        return Poses;
    }

    FCk_ProceduralAction_ValidationReport Build_DoorwayClip(UCk_ProceduralAction_Data InClip)
    {
        auto Slots = TArray<FCk_ProceduralAction_Slot>();
        for (int32 Index = 0; Index < 8; ++Index)
        {
            auto Slot = FCk_ProceduralAction_Slot(FName(f"Leg{Index}"));
            Slot.Set_Space(ECk_ProceduralAction_TrackSpace::RootAtStart);
            Slots.Add(Slot);
        }
        auto Body = FCk_ProceduralAction_BodyChannel();
        Body.Set_Enabled(true);
        InClip.Set_BodyChannel(Body);
        InClip.Set_Slots(Slots);
        auto Phases = TArray<FCk_ProceduralAction_Phase>();
        const auto Poses = Make_DoorwayPoses();
        for (int32 Index = 1; Index < Poses.Num(); ++Index)
        {
            const auto Start = Poses[Index - 1];
            const auto Mid = Poses[Index];
            const auto HasMid = Mid.Intermediate && Index + 1 < Poses.Num();
            const auto End = Poses[HasMid ? Index + 1 : Index];
            const auto Duration = HasMid ? Mid.Seconds + End.Seconds : End.Seconds;
            const auto MidTime = float32(Mid.Seconds / Duration);
            auto Phase = FCk_ProceduralAction_Phase(FName(f"P{Index}_{End.Label}"), FCk_Time(Duration));
            Phase.Set_Easing(ECk_ProceduralAction_Easing::Linear);
            // Constant translation during consecutive strides, smooth acceleration for crouch/rise. Limb curves
            // ease at touchdown independently, rather than stopping the whole animal at each action boundary.
            Phase.Set_BodyInterpolation(Start.Body.X != End.Body.X ?
                ECk_ProceduralAction_Interpolation::Linear : ECk_ProceduralAction_Interpolation::Smooth);
            auto BodyKeys = TArray<FCk_ProceduralAction_TransformKey>();
            BodyKeys.Add(FCk_ProceduralAction_TransformKey(FCk_FloatRange_0to1(0.0f), Start.Body, FQuat::Identity));
            if (HasMid)
            { BodyKeys.Add(FCk_ProceduralAction_TransformKey(FCk_FloatRange_0to1(MidTime), Mid.Body, FQuat::Identity)); }
            BodyKeys.Add(FCk_ProceduralAction_TransformKey(FCk_FloatRange_0to1(1.0f), End.Body, FQuat::Identity));
            Phase.Set_BodyKeys(BodyKeys);
            auto Tracks = TArray<FCk_ProceduralAction_LimbTrack>();
            for (int32 Leg = 0; Leg < 8; ++Leg)
            {
                auto Track = FCk_ProceduralAction_LimbTrack(FName(f"Leg{Leg}"));
                auto Keys = TArray<FCk_ProceduralAction_VectorKey>();
                Keys.Add(FCk_ProceduralAction_VectorKey(FCk_FloatRange_0to1(0.0f), Start.Feet[Leg]));
                if (HasMid)
                { Keys.Add(FCk_ProceduralAction_VectorKey(FCk_FloatRange_0to1(MidTime), Mid.Feet[Leg])); }
                Keys.Add(FCk_ProceduralAction_VectorKey(FCk_FloatRange_0to1(1.0f), End.Feet[Leg]));
                Track.Set_Interpolation(ECk_ProceduralAction_Interpolation::Smooth);
                if (HasMid)
                {
                    auto MidKey = Keys[1];
                    const auto Tangent = End.Feet[Leg] - Start.Feet[Leg];
                    MidKey.Set_ArriveTangent(Tangent);
                    MidKey.Set_LeaveTangent(Tangent);
                    Keys[1] = MidKey;
                }
                Track.Set_PositionKeys(Keys);
                auto BendKeys = TArray<FCk_ProceduralAction_VectorKey>();
                BendKeys.Add(FCk_ProceduralAction_VectorKey(FCk_FloatRange_0to1(0.0f), Start.Bends[Leg].GetSafeNormal()));
                if (HasMid)
                { BendKeys.Add(FCk_ProceduralAction_VectorKey(FCk_FloatRange_0to1(MidTime), Mid.Bends[Leg].GetSafeNormal())); }
                BendKeys.Add(FCk_ProceduralAction_VectorKey(FCk_FloatRange_0to1(1.0f), End.Bends[Leg].GetSafeNormal()));
                Track.Set_BendKeys(BendKeys);
                Tracks.Add(Track);
            }
            Phase.Set_LimbTracks(Tracks);
            Phases.Add(Phase);
            if (HasMid)
            { ++Index; }
        }
        InClip.Set_Phases(Phases);
        return utils_procedural_action::Validate_Data(InClip);
    }

    // Full 15-axis OBB separating-axis test, after a cheap world AABB rejection. Tests actual rendered boxes rather than
    // conservative sibling capsules, whose end caps would incorrectly reject legitimate articulated joint contacts.
    bool Get_DoorwayBoxesOverlap(const FMars_Crawler_DoorwayBox& InA, const FMars_Crawler_DoorwayBox& InB)
    {
        if (InA.Max.X < InB.Min.X || InB.Max.X < InA.Min.X || InA.Max.Y < InB.Min.Y ||
            InB.Max.Y < InA.Min.Y || InA.Max.Z < InB.Min.Z || InB.Max.Z < InA.Min.Z)
        { return false; }
        auto Axes = InA.Axes;
        Axes.Append(InB.Axes);
        for (const auto& A : InA.Axes)
        {
            for (const auto& B : InB.Axes)
            { Axes.Add(A.CrossProduct(B)); }
        }
        const auto Delta = InB.Frame.GetLocation() - InA.Frame.GetLocation();
        const auto HalfA = InA.Half - FVector(0.02);
        const auto HalfB = InB.Half - FVector(0.02);
        for (const auto& Axis : Axes)
        {
            if (Axis.SizeSquared() < 0.000000000001)
            { continue; }
            const auto RadiusA = Math::Abs(Axis.DotProduct(InA.Axes[0])) * HalfA.X +
                Math::Abs(Axis.DotProduct(InA.Axes[1])) * HalfA.Y + Math::Abs(Axis.DotProduct(InA.Axes[2])) * HalfA.Z;
            const auto RadiusB = Math::Abs(Axis.DotProduct(InB.Axes[0])) * HalfB.X +
                Math::Abs(Axis.DotProduct(InB.Axes[1])) * HalfB.Y + Math::Abs(Axis.DotProduct(InB.Axes[2])) * HalfB.Z;
            if (Math::Abs(Axis.DotProduct(Delta)) >= RadiusA + RadiusB)
            { return false; }
        }
        return true;
    }
}
