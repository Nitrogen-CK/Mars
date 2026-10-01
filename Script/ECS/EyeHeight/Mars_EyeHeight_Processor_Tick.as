// Polls the capsule rather than reacting to the crouch request: Crouch() only sets bWantsToCrouch, the resize lands in a
// CharacterMovement tick that is unordered against the ECS world. CMC resizes and moves the capsule in one call, so the
// half-height read here and the actor location FGroup_Transform_SyncFrom reads are the same CMC state, and the offset
// request drains in this frame's FGroup_Transform, before the camera composes.
class UMars_Processor_EyeHeight_Tick : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_EyeHeight);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle, FMars_Fragment_EyeHeight& InState)
    {
        const auto& Params = InHandle.Get_Fragment(FMars_Fragment_EyeHeight_Params);
        auto Character = Params.Character.Get();
        if (ck::Is_NOT_Valid(Character))
        { return; }

        // CMC keeps the capsule's base planted (moving the centre by the resize) only while walking; in the air it
        // resizes in place, the centre stays put and the eye owes nothing.
        const auto HalfHeight = Character.CapsuleComponent.GetScaledCapsuleHalfHeight();
        if (HalfHeight != InState.LastHalfHeight && Character.CharacterMovement.bCrouchMaintainsBaseLocation)
        { InState.Offset += InState.LastHalfHeight - HalfHeight; }
        InState.LastHalfHeight = HalfHeight;

        if (InState.Offset == 0.0f)
        { return; }

        const auto DeltaSeconds = float32(InDeltaT.Get_Seconds());
        if (DeltaSeconds > 0.0f)
        { InState.Offset *= float32(Math::Exp(-Params.BlendRate * DeltaSeconds)); }

        if (Math::Abs(InState.Offset) < 0.01f)
        { InState.Offset = 0.0f; }

        auto Node = InHandle.As_SceneNode();
        utils_scene_node::Request_UpdateOffset_Location(Node, FVector(0.0, 0.0, Params.Height + InState.Offset));
    }
}
