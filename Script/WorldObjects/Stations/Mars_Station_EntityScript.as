namespace constants_station
{
    // Every station's work surface height, sized to the 1.5 m chef (a station with Camera.ViewLocal frames its view in
    // its own frame, so this moves the table under the view, not the view).
    const float64 k_CounterHeight = 70.0;
}

// Base placeable station: composes the transform and the Station feature (see FMars_Station_Spec for the frame: the root
// is the station's origin on the floor; the operator stands at StandLocal facing its +X). Concrete stations fill in the
// geometry-bound spec fields (stand, grips), the Use probe, the visuals and the nodes their grips name. The visuals are
// built first so the grip nodes exist when the station resolves its grips.
UCLASS(Abstract)
class UMars_Station_EntityScript : UCk_GenericEntityScript_UE
{
    default _Replication = ECk_Replication::DoesNotReplicate;

    UPROPERTY(ExposeOnSpawn)
    FTransform SpawnTransform = FTransform::Identity;

    // Not a `default` in subclasses: set geometry-bound fields in Configure_Spec (the spawn-params generator emits a
    // non-default script struct as a positional constructor call).
    UPROPERTY(ExposeOnSpawn)
    FMars_Station_Spec Station;

    UFUNCTION(BlueprintOverride)
    ECk_EntityScript_ConstructionFlow DoConstruct(FCk_Handle& InHandle)
    {
        auto Root = utils_transform::Add(InHandle, SpawnTransform, ECk_Replication::DoesNotReplicate);

        auto Spec = Station;
        Configure_Spec(Spec);
        AddVisuals(Root);

        Spec.Setup.Probe = Make_Probe();
        Register_GripNodes(Spec.Setup.GripNodes);
        Spec.Setup.UsePrompt = FMars_InteractPrompt_Spec(mars::Mars_IA_Interact_Use, Spec.Prompt.Text);

        // A rejected spec or grip already ensured in utils_station::Add.
        auto StationHandle = utils_station::Add(Root, Spec);
        if (ck::IsValid(StationHandle))
        {
            StationHandle.BindTo_OnReserved(FMars_Delegate_Station_OnReserved(this, n"OnStationReserved"));
            StationHandle.BindTo_OnReleased(FMars_Delegate_Station_OnReleased(this, n"OnStationReleased"));
        }

        return ECk_EntityScript_ConstructionFlow::Finished;
    }

    // The Use prompt reads Prompt.OccupiedText while an operator holds the station, and Prompt.Text once it is free.
    UFUNCTION()
    private void OnStationReserved(FCk_Handle_Station InStation, FCk_Handle InOperator)
    {
        Sync_UsePromptText(InStation);
    }

    // A same-drain re-seat broadcasts Released then Reserved; reading the station keeps the text right either way. A
    // station released by its own destruction has nothing left to word.
    UFUNCTION()
    private void OnStationReleased(FCk_Handle_Station InStation, FCk_Handle InOperator, EMars_Station_ReleaseReason InReason)
    {
        if (ck::Is_NOT_Valid(InStation))
        { return; }

        Sync_UsePromptText(InStation);
    }

    private void Sync_UsePromptText(FCk_Handle_Station InStation)
    {
        auto Prompt = InStation.Get_UseTarget().As_InteractPrompt(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(Prompt))
        { return; }

        const auto PromptSpec = InStation.Get_Spec().Prompt;
        const auto Text = InStation.Get_IsOperated() ? PromptSpec.OccupiedText : PromptSpec.Text;
        Prompt.Request_UpdateText(FMars_Request_InteractPrompt_UpdateText(Text));
    }

    protected void Configure_Spec(FMars_Station_Spec& InOutSpec)
    {
    }

    // Unset = a transform-only Use interactable (no view-trace focus).
    protected TOptional<FMars_Interactable_ProbeInfo> Make_Probe() const
    {
        return TOptional<FMars_Interactable_ProbeInfo>();
    }

    protected void AddVisuals(FCk_Handle_Transform& InRoot)
    {
    }

    // Called after AddVisuals: publish, under its Station.Node.* tag, every node a spec grip names.
    protected void Register_GripNodes(TArray<FMars_Station_GripNode>& OutNodes)
    {
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Building blocks for Configure_Spec
    //----------------------------------------------------------------------------------------------------------------------

    // InHand on the node registered under InNode, in the node's own frame (its rotation built with
    // utils_fphands::Make_GripRotation), posed InPose.
    protected FMars_Station_Grip Make_NodeGrip(EMars_Hand InHand, FGameplayTag InNode, EMars_HandGripPose InPose) const
    {
        return FMars_Station_Grip(InHand, InNode, NAME_None, InPose, TOptional<float32>(), EMars_FPHands_GripFrame::Node, EMars_FPHands_GripRoll::Fixed);
    }

    // A Captured view held InDistance back from InFocus (station frame) along the line pitched InPitchDegrees (negative looks
    // down), so InFocus is dead centre on screen.
    protected FMars_Station_CameraSpec Make_CapturedCamera(FVector InFocus, float32 InPitchDegrees, float64 InDistance) const
    {
        return Make_CapturedCameraAt(Make_ViewLocal(InFocus, InPitchDegrees, InDistance).GetLocation(), InPitchDegrees);
    }

    // A Captured view held at InEyeLocal (station frame), pitched InPitchDegrees.
    protected FMars_Station_CameraSpec Make_CapturedCameraAt(FVector InEyeLocal, float32 InPitchDegrees) const
    {
        auto Camera = Station.Camera;
        Camera.LookControl = EMars_Station_LookControl::Captured;
        Camera.PitchOffset = InPitchDegrees;
        Camera.ViewLocal = TOptional<FTransform>(FTransform(FRotator(InPitchDegrees, 0.0, 0.0), InEyeLocal));
        return Camera;
    }

    // A view (station frame) InDistance back from InFocus along the line pitched InPitchDegrees (negative looks down).
    protected FTransform Make_ViewLocal(FVector InFocus, float32 InPitchDegrees, float64 InDistance) const
    {
        const auto PitchRadians = Math::DegreesToRadians(float64(-InPitchDegrees));
        return FTransform(FRotator(InPitchDegrees, 0.0, 0.0),
            FVector(InFocus.X - InDistance * Math::Cos(PitchRadians), InFocus.Y, InFocus.Z + InDistance * Math::Sin(PitchRadians)));
    }
}
