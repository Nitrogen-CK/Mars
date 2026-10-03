// The body's hold spec (Config.TPBody.Hold) is valid as configured and rejects a scaled or broken hand frame, non-finite
// offsets and negative tunables. From it, utils_held_view::Make_HoldFrame lays a fitted two-handed grip out in the hand
// frame: both arms at full alpha, mirror images across the chef's middle, the grip offsets shrunk to body units and
// turned to the chef's facing (hand-node +Y = the chef's right = component -X). A one-handed hold raises only the right
// arm, moved by OneHandedOffset. Ease_Arm takes the target pose at once from zero alpha and eases only the alpha.
class UMars_AutoTest_TPBody_HoldSpecValidates : UCk_AutoTest_Base
{
    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Add_Step("the configured hold spec is valid and the broken ones are rejected", n"Step_Validate");
        Add_Step("a fitted two-handed grip lays out mirrored in the hand frame, in body units", n"Step_TwoHanded");
        Add_Step("a one-handed grip raises only the right arm, moved by OneHandedOffset", n"Step_OneHanded");
        Add_Step("an arm coming up from zero alpha takes the target pose and eases its alpha", n"Step_Ease");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_Validate(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Config = mars::Mars_PlayerCharacter_Config;
        const auto Configured = Config.TPBody.Hold.Validate();
        Assert_True(Configured.IsValid(), f"the configured hold spec is valid ({Configured.Get_Error()})");
        Assert_True(Config.TPBody.Validate().IsValid(), f"the configured body spec is valid ({Config.TPBody.Validate().Get_Error()})");

        auto ScaledFrame = FMars_TPBody_Hold();
        ScaledFrame.HandFrame.SetScale3D(FVector(2.0, 2.0, 2.0));
        Assert_False(ScaledFrame.Validate().IsValid(), "a scaled hand frame is rejected");

        auto BrokenFrame = FMars_TPBody_Hold();
        BrokenFrame.HandFrame.SetTranslation(FVector(Math::Sqrt(-1.0), 0.0, 0.0));
        Assert_False(BrokenFrame.Validate().IsValid(), "a non-finite hand frame is rejected");

        auto BrokenElbow = FMars_TPBody_Hold();
        BrokenElbow.ElbowOffset_R = FVector(0.0, Math::Sqrt(-1.0), 0.0);
        Assert_False(BrokenElbow.Validate().IsValid(), "a non-finite elbow target is rejected");

        auto BrokenOneHanded = FMars_TPBody_Hold();
        BrokenOneHanded.OneHandedOffset = FVector(0.0, 0.0, Math::Sqrt(-1.0));
        Assert_False(BrokenOneHanded.Validate().IsValid(), "a non-finite one-handed offset is rejected");

        auto NegativePalm = FMars_TPBody_Hold();
        NegativePalm.PalmSurfaceOffset = -1.0f;
        Assert_False(NegativePalm.Validate().IsValid(), "a negative palm offset is rejected");

        auto NegativeSpeed = FMars_TPBody_Hold();
        NegativeSpeed.InterpSpeed = -1.0f;
        Assert_False(NegativeSpeed.Validate().IsValid(), "a negative interp speed is rejected");

        auto BodyWithBrokenHold = Config.TPBody;
        BodyWithBrokenHold.Hold.PalmSurfaceOffset = -1.0f;
        Assert_False(BodyWithBrokenHold.Validate().IsValid(), "the body spec rejects a broken hold");
    }

    UFUNCTION()
    private void Step_TwoHanded(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Spec = FMars_FPHands_Spec();
        auto Grip = FMars_HeldView_Grip();
        Grip.IsTwoHanded = true;
        Grip.RightFaceY = 15.0;
        Grip.LeftFaceY = -15.0;

        const auto BodyScale = 1.0969f;
        auto Query = FMars_TPBody_HoldQuery();
        Query.Grips = utils_held_view::Get_GripTargets(Spec, Grip);
        Query.IsTwoHanded = true;
        Query.Hold = FMars_TPBody_Hold();
        Query.BodyScale = BodyScale;
        // Identity: each hand bone is its grip bone, so the targets are the laid-out grips themselves.
        Query.HandInGrip_R = FTransform::Identity;
        Query.HandInGrip_L = FTransform::Identity;
        const auto Frame = utils_held_view::Make_HoldFrame(Query);

        Assert_True(Math::Abs(Frame.Right.Alpha - 1.0f) < 0.001f && Math::Abs(Frame.Left.Alpha - 1.0f) < 0.001f, "both arms hold a two-handed item");

        // Right grip at hand-node (0, 15 + 2.5, 0) world cm -> component (-17.5 / Scale, 0, 0) + the frame's origin.
        const auto FrameOrigin = Query.Hold.HandFrame.GetLocation();
        const auto ExpectedRight = FrameOrigin + FVector(-(15.0 + Spec.PalmSurfaceOffset) / BodyScale, 0.0, 0.0);
        Assert_True(Frame.Right.HandLocation.Equals(ExpectedRight, 0.01), f"the right hand is on the chef's right, in body units [{ExpectedRight}] (got [{Frame.Right.HandLocation}])");

        const auto Mirrored = FVector(-Frame.Left.HandLocation.X, Frame.Left.HandLocation.Y, Frame.Left.HandLocation.Z);
        Assert_True(Frame.Right.HandLocation.Equals(Mirrored, 0.01), f"the hands mirror across the chef's middle (right [{Frame.Right.HandLocation}], left [{Frame.Left.HandLocation}])");
        Assert_True(Frame.Right.ElbowTarget.Equals(Query.Hold.ElbowOffset_R) && Frame.Left.ElbowTarget.Equals(Query.Hold.ElbowOffset_L), "the elbows take the spec's pole targets");
        Assert_True(Frame.Right.ElbowTarget.X < 0.0 && Frame.Right.ElbowTarget.Y < FrameOrigin.Y, "the right elbow pole is on the chef's right, behind the hands");

        // The grip's palm (its Z) faces the item, toward the chef's middle (+X for the right hand).
        const auto PalmR = Frame.Right.HandRotation.Quaternion().GetAxisZ();
        Assert_True(PalmR.X > 0.5, f"the right palm faces the chef's middle (palm [{PalmR}])");
    }

    UFUNCTION()
    private void Step_OneHanded(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Spec = FMars_FPHands_Spec();
        auto Grip = FMars_HeldView_Grip();
        Grip.IsTwoHanded = false;

        auto Query = FMars_TPBody_HoldQuery();
        Query.Grips = utils_held_view::Get_GripTargets(Spec, Grip);
        Query.IsTwoHanded = false;
        Query.Hold = FMars_TPBody_Hold();
        Query.BodyScale = 1.0f;
        Query.HandInGrip_R = FTransform::Identity;
        Query.HandInGrip_L = FTransform::Identity;
        const auto Frame = utils_held_view::Make_HoldFrame(Query);

        Assert_True(Math::Abs(Frame.Right.Alpha - 1.0f) < 0.001f, "the right arm holds a one-handed item");
        Assert_True(Frame.Left.Alpha < 0.001f, "the left arm stays in its locomotion pose");

        // The right grip rests at the hand node's origin; the frame moves right by OneHandedOffset (hand +Y = component -X).
        const auto Expected = Query.Hold.HandFrame.GetLocation() + FVector(-Query.Hold.OneHandedOffset.Y, Query.Hold.OneHandedOffset.X, Query.Hold.OneHandedOffset.Z);
        Assert_True(Frame.Right.HandLocation.Equals(Expected, 0.01), f"the right hand moves by OneHandedOffset to [{Expected}] (got [{Frame.Right.HandLocation}])");
    }

    UFUNCTION()
    private void Step_Ease(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Target = FMars_TPBody_ArmTarget();
        Target.Alpha = 1.0f;
        Target.HandLocation = FVector(-16.0, 16.0, 50.0);
        Target.HandRotation = FRotator(10.0, 20.0, 30.0);

        const auto Up = utils_held_view::Ease_Arm(FMars_TPBody_ArmTarget(), Target, 0.25f);
        Assert_True(Math::Abs(Up.Alpha - 0.25f) < 0.001f, f"the alpha eases a step (got {Up.Alpha})");
        Assert_True(Up.HandLocation.Equals(Target.HandLocation), "an arm coming up from zero alpha takes the target location at once");

        auto Moved = Target;
        Moved.HandLocation = FVector(-26.0, 16.0, 50.0);
        const auto Between = utils_held_view::Ease_Arm(Target, Moved, 0.5f);
        Assert_True(Between.HandLocation.Equals(FVector(-21.0, 16.0, 50.0), 0.001), f"a held arm eases toward a new target (got [{Between.HandLocation}])");
    }
}
