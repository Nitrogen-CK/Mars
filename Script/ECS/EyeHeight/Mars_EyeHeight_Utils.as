namespace utils_eye_height
{
    // Creates the eye node under InParent (the character's transform) at InSpec.Height; compose the view under it.
    FCk_Handle_EyeHeight Create(FCk_Handle_Transform& InParent, FMars_EyeHeight_Spec InSpec, ACharacter InCharacter)
    {
        const auto Validation = InSpec.Validate();
        if (ck::EnsureIfNot(Validation.IsValid, f"[EyeHeight] [{InParent.ToString()}] rejected the spec: {Validation.Get_Error()}"))
        { return FCk_Handle_EyeHeight(); }

        if (ck::EnsureIfNot(ck::IsValid(InCharacter), f"[EyeHeight] [{InParent.ToString()}] needs a valid character"))
        { return FCk_Handle_EyeHeight(); }

        auto EyeNode = utils_scene_node::Create(InParent, FTransform(FVector(0.0, 0.0, InSpec.Height)));

        auto Params = FMars_Fragment_EyeHeight_Params();
        Params.Height = InSpec.Height;
        Params.BlendRate = InSpec.BlendRate;
        Params.Character = InCharacter;

        auto State = FMars_Fragment_EyeHeight();
        State.LastHalfHeight = InCharacter.CapsuleComponent.GetScaledCapsuleHalfHeight();

        EyeNode.Add_Fragment(FMars_Feature_EyeHeight());
        EyeNode.Add_Fragment(Params);
        EyeNode.Add_Fragment(State);
        return EyeNode.As_EyeHeight();
    }
}

//--------------------------------------------------------------------------------------------------------------------------
// Getters
//--------------------------------------------------------------------------------------------------------------------------

mixin float32 Get_Offset(const FCk_Handle_EyeHeight& Self)
{
    return Self.Get_Fragment(FMars_Fragment_EyeHeight).Offset;
}
