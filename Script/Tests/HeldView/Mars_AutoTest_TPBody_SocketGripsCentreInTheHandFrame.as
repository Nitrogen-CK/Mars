// A socket-gripped tool (both hands stacked on one handle) is held in front of the body's chest whatever its first-person
// framing: the grips' midpoint lands on the hand frame pushed SocketGripForward along it, the hands keep their spacing
// and rotations, and a fitted (faces) hold is untouched by the rule. The first-person upright mount
// (utils_fphands::Make_UprightHeldOffset) stands a +X handle on end with its -Z face forward and leans it toward
// screen centre.
class UMars_AutoTest_TPBody_SocketGripsCentreInTheHandFrame : UCk_AutoTest_Base
{
    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Add_Step("socket grips centre in the hand frame", n"Step_Assert");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_Assert(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        // The cleaver's grips: rear grip at the upright mount's pivot, the front grip 14 cm up the standing handle.
        const auto Mount = utils_fphands::Make_UprightHeldOffset(FVector(-4.0, 22.0, -14.0), 90.0f, 0.0f);
        const auto Up = Mount.TransformVector(FVector::ForwardVector);
        Assert_True(Up.Equals(FVector::UpVector, 0.001), f"a 90 degree stand turns the handle's +X up (got [{Up}])");
        const auto Face = Mount.TransformVector(-FVector::UpVector);
        Assert_True(Face.Equals(FVector::ForwardVector, 0.001), f"the tool's -Z face turns forward (got [{Face}])");

        const auto Leaned = utils_fphands::Make_UprightHeldOffset(FVector::ZeroVector, 90.0f, 12.0f).TransformVector(FVector::ForwardVector);
        Assert_True(Leaned.Y < -0.1 && Leaned.Z > 0.9, f"a positive lean tips the top toward -Y, screen left (got [{Leaned}])");

        auto Grip = FMars_HeldView_Grip();
        Grip.IsTwoHanded = true;
        Grip.HasSocketGrips = true;
        Grip.SocketGrip_R = FTransform(FRotator::ZeroRotator, FVector::ZeroVector, FVector::OneVector) * Mount;
        Grip.SocketGrip_L = FTransform(FRotator::ZeroRotator, FVector(14.0, 0.0, 0.0), FVector::OneVector) * Mount;

        auto Query = FMars_TPBody_HoldQuery();
        Query.Grips = utils_held_view::Get_GripTargets(FMars_FPHands_Spec(), Grip);
        Query.IsTwoHanded = true;
        Query.IsSocketGrip = true;
        Query.Hold = FMars_TPBody_Hold();
        Query.BodyScale = 1.6453f;

        const auto Frame = utils_held_view::Make_HoldFrame(Query);
        const auto Midpoint = (Frame.Right.HandLocation + Frame.Left.HandLocation) * 0.5;
        const auto Expected = Query.Hold.HandFrame.TransformPosition(FVector(Query.Hold.SocketGripForward, 0.0, 0.0));
        Assert_True(Expected.Y > Query.Hold.HandFrame.GetLocation().Y, "the push is forward (component +Y, the chef's front)");
        Assert_True(Midpoint.Equals(Expected, 0.01),
            f"the hands' midpoint sits SocketGripForward ahead of the hand frame (got [{Midpoint}], expected [{Expected}])");

        const auto Spacing = (Frame.Left.HandLocation - Frame.Right.HandLocation).Size();
        Assert_Equals_Float(Spacing, 14.0 / Query.BodyScale, 0.01, "the hands keep the handle's 14 cm spacing, in body units");
        Assert_True((Frame.Left.HandLocation - Frame.Right.HandLocation).Z > 0.0, "the front grip is the upper hand on the standing handle");

        // Moving the first-person framing changes nothing on the body.
        auto Reframed = Grip;
        const auto Shift = FTransform(FRotator::ZeroRotator, FVector(10.0, -30.0, 25.0), FVector::OneVector);
        Reframed.SocketGrip_R = Grip.SocketGrip_R * Shift;
        Reframed.SocketGrip_L = Grip.SocketGrip_L * Shift;
        auto ReframedQuery = Query;
        ReframedQuery.Grips = utils_held_view::Get_GripTargets(FMars_FPHands_Spec(), Reframed);
        const auto ReframedFrame = utils_held_view::Make_HoldFrame(ReframedQuery);
        Assert_True(ReframedFrame.Right.HandLocation.Equals(Frame.Right.HandLocation, 0.01)
            && ReframedFrame.Left.HandLocation.Equals(Frame.Left.HandLocation, 0.01),
            "a different first-person framing leaves the body's hands where they were");

        // A fitted hold is laid out as before.
        auto Faces = FMars_HeldView_Grip();
        Faces.IsTwoHanded = true;
        Faces.RightFaceY = 15.0;
        Faces.LeftFaceY = -15.0;
        auto FacesQuery = FMars_TPBody_HoldQuery();
        FacesQuery.Grips = utils_held_view::Get_GripTargets(FMars_FPHands_Spec(), Faces);
        FacesQuery.IsTwoHanded = true;
        FacesQuery.Hold = FMars_TPBody_Hold();
        FacesQuery.BodyScale = 1.6453f;
        const auto FacesFrame = utils_held_view::Make_HoldFrame(FacesQuery);
        const auto FacesMidpoint = (FacesFrame.Right.HandLocation + FacesFrame.Left.HandLocation) * 0.5;
        Assert_True(FacesMidpoint.Equals(FacesQuery.Hold.HandFrame.GetLocation(), 0.5),
            f"a fitted hold stays centred on the hand frame itself (got [{FacesMidpoint}])");
    }
}
