// The two transitions the three Devour processors share (the request drain and the tick with authority, the mirror on
// a copy without it). They write the devourer's state and the victim's marker, so they live on the processors and
// nowhere else; the caller broadcasts.
UCLASS(Abstract)
class UMars_Processor_Devour_Base : UCk_Processor_Script_Base_UE
{
    // Takes InVictim and enters Seize, one run more. A marker left on the victim by a devourer that is gone is
    // overwritten. An invalid victim (a copy that cannot see it) is shown as no victim and marks nothing.
    protected void DoSeize(FCk_Handle_Devour& InDevour, FMars_Fragment_Devour& InState, FCk_Handle InVictim)
    {
        if (ck::IsValid(InVictim))
        {
            // A by-value handle is read-only; the copy is the same entity.
            auto Victim = InVictim;
            Victim.AddOrGet_Fragment(FMars_Fragment_Devour_Victim).Devourer = InDevour;
        }

        InState.Victim = InVictim;
        InState.Phase = EMars_Devour_Phase::Seize;
        InState.PhaseSeconds = 0.0f;
        InState.Serial += 1;
        InDevour.Add_Fragment(FMars_Tag_Devour_Running());
    }

    // Lets the victim go, returns to Idle and keeps how the run ended. Returns the victim that was held (it may be
    // invalid).
    protected FCk_Handle DoRelease(FCk_Handle_Devour& InDevour, FMars_Fragment_Devour& InState, EMars_Devour_End InEnd)
    {
        auto Victim = InState.Victim;
        if (ck::IsValid(Victim) && Victim.Has_Fragment(FMars_Fragment_Devour_Victim))
        { Victim.Request_TryRemove(FMars_Fragment_Devour_Victim); }

        InState.Victim = FCk_Handle();
        InState.Phase = EMars_Devour_Phase::Idle;
        InState.PhaseSeconds = 0.0f;
        InState.LastEnd = InEnd;
        InDevour.Request_TryRemove(FMars_Tag_Devour_Running);
        return Victim;
    }
}
