// The two transitions both Devour processors share. They write the devourer's state and the victim's marker, so they live
// on the processors and nowhere else; the caller broadcasts.
UCLASS(Abstract)
class UMars_Processor_Devour_Base : UCk_Processor_Script_Base_UE
{
    // Takes InVictim and enters Seize. A marker left on the victim by a devourer that is gone is overwritten.
    protected void DoSeize(FCk_Handle_Devour& InDevour, FMars_Fragment_Devour& InState, FCk_Handle InVictim)
    {
        // A by-value handle is read-only; the copy is the same entity.
        auto Victim = InVictim;
        Victim.AddOrGet_Fragment(FMars_Fragment_Devour_Victim).Devourer = InDevour;

        InState.Victim = Victim;
        InState.Phase = EMars_Devour_Phase::Seize;
        InState.PhaseSeconds = 0.0f;
        InDevour.Add_Fragment(FMars_Tag_Devour_Running());
    }

    // Lets the victim go and returns to Idle. Returns the victim that was held (it may be invalid).
    protected FCk_Handle DoRelease(FCk_Handle_Devour& InDevour, FMars_Fragment_Devour& InState)
    {
        auto Victim = InState.Victim;
        if (ck::IsValid(Victim) && Victim.Has_Fragment(FMars_Fragment_Devour_Victim))
        { Victim.Request_TryRemove(FMars_Fragment_Devour_Victim); }

        InState.Victim = FCk_Handle();
        InState.Phase = EMars_Devour_Phase::Idle;
        InState.PhaseSeconds = 0.0f;
        InDevour.Request_TryRemove(FMars_Tag_Devour_Running);
        return Victim;
    }
}
