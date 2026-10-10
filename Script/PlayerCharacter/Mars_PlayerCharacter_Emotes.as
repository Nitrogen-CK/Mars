// The character's emotes on its first-person gloves. The body's half lives on AMars_PlayerCharacter (Request_Emote,
// Request_StopEmote); the HFSM tasks decide when.
namespace utils_player_emotes
{
    // Hands the gloves back to the procedural placement: stops a playing emote montage (a reach or a newly held item
    // takes over), and the body's emote with it (AMars_PlayerCharacter::Request_StopEmote). An entity with no character
    // (tests) plays no emotes.
    void Stop_Emote(const FCk_Handle_FPHands& InHands)
    {
        auto Character = Cast<AMars_PlayerCharacter>(ck::ToActor(InHands, ECk_SanityCheck::UnChecked));
        if (ck::Is_NOT_Valid(Character))
        { return; }

        auto AnimInstance = Character.FPHands.GetAnimInstance();
        if (ck::IsValid(AnimInstance) && AnimInstance.IsAnyMontagePlaying())
        { AnimInstance.Montage_Stop(InHands.Get_Spec().Emotes.CancelBlendSeconds); }

        Character.Request_StopEmote();
    }

    // Plays InEmote's montage on the gloves (both, through the spec's emote slot). Refused while the gloves are busy:
    // holding an item, or out of Rest (reaching, holding, pushing). An entity with no character (tests) plays no emotes.
    bool Play_Emote(const FCk_Handle_FPHands& InHands, EMars_FPEmote InEmote)
    {
        auto Character = Cast<AMars_PlayerCharacter>(ck::ToActor(InHands, ECk_SanityCheck::UnChecked));
        if (ck::Is_NOT_Valid(Character))
        { return false; }

        if (InHands.Get_Hold().Kind != EMars_FPHands_HoldKind::Empty || InHands.Get_Phase() != EMars_FPHands_Phase::None)
        { return false; }

        auto Montages = InHands.Get_Spec().Emotes.Montages;
        if (ck::EnsureIfNot(Montages.Contains(InEmote), f"[Emotes] the gloves have no montage for [{InEmote :n}]"))
        { return false; }

        auto Montage = System::LoadAsset_Blocking(Montages[InEmote]);
        auto AnimInstance = Character.FPHands.GetAnimInstance();
        if (ck::EnsureIfNot(ck::IsValid(Montage) && ck::IsValid(AnimInstance),
            f"[Emotes] [{InEmote :n}] cannot play: its montage does not load or the gloves have no anim instance"))
        { return false; }

        AnimInstance.Montage_Play(Montage);
        return true;
    }
}
