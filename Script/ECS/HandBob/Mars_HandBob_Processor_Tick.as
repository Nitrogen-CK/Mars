// Reads the owning character's locomotion, advances the bob (utils_hand_bob::Advance) and publishes the node offset
// when it changed. Only the locally controlled character's hands move (TryGet_LocalCharacter); remote copies never render
// them.
class UMars_Processor_HandBob_Tick : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_HandBob);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle, FMars_Fragment_HandBob& InState)
    {
        auto Character = utils_hand_bob::TryGet_LocalCharacter(InHandle);
        if (ck::Is_NOT_Valid(Character))
        { return; }

        const auto DeltaSeconds = float32(InDeltaT.Get_Seconds());
        if (DeltaSeconds <= 0.0f)
        { return; }

        const auto& Spec = InHandle.Get_Fragment(FMars_Fragment_HandBob_Params).Spec;
        const auto Movement = Character.CharacterMovement;
        const auto Velocity = Character.GetVelocity();

        auto Input = FMars_HandBob_Input();
        Input.DeltaSeconds = DeltaSeconds;
        Input.IsFalling = ck::IsValid(Movement) && Movement.IsFalling();
        Input.IsCrouched = Character.bIsCrouched;
        Input.GroundSpeed = Input.IsFalling ? 0.0 : Velocity.Size2D();
        Input.VerticalSpeed = float32(Velocity.Z);

        utils_hand_bob::Advance(Spec, InState, Input);

        auto Node = utils_scene_node::DoCastChecked(InHandle);
        const auto Offset = utils_hand_bob::Make_NodeOffset(Spec, InState);
        if (Offset.Equals(utils_scene_node::Get_Offset(Node), 1.0e-4))
        { return; }

        utils_scene_node::Request_UpdateOffset(Node, FCk_Request_SceneNode_UpdateRelativeTransform(Offset));
    }
}
