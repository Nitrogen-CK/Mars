namespace utils_body_probe
{
    // Creates the probe node under InParent (the character's transform), sized to InCharacter's capsule.
    FCk_Handle_BodyProbe Create(FCk_Handle_Transform& InParent, FCk_Probe_Spec InProbeSpec, ACharacter InCharacter)
    {
        if (ck::EnsureIfNot(ck::IsValid(InCharacter), f"[BodyProbe] [{InParent.ToString()}] needs a valid character"))
        { return FCk_Handle_BodyProbe(); }

        const auto Capsule = InCharacter.CapsuleComponent;
        auto ProbeNode = utils_prefab::Create_ProbeNode_Capsule(
            InParent, Capsule.GetScaledCapsuleHalfHeight(), Capsule.GetScaledCapsuleRadius(), InProbeSpec);

        auto Params = FMars_Fragment_BodyProbe_Params();
        Params.Character = InCharacter;

        auto State = FMars_Fragment_BodyProbe();
        State.HalfHeight = Capsule.GetScaledCapsuleHalfHeight();

        ProbeNode.Add_Fragment(FMars_Feature_BodyProbe());
        ProbeNode.Add_Fragment(Params);
        ProbeNode.Add_Fragment(State);
        return ProbeNode.As_BodyProbe();
    }
}
