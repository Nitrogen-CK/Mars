// Every frame: resting = a contact with the target within GraceSeconds, or asleep while already resting (Jolt reports no
// contacts for a sleeping pair, and a sleeping body has not moved, so the last verdict stands). A landing after at least
// HopMinSeconds apart is a hop. Writes land first, then OnLanded, then OnRestingChanged.
class UMars_Processor_Resting_Tick : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_Resting);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle, FMars_Fragment_Resting& InState)
    {
        auto Self = InHandle.As_Resting();
        const auto Spec = Self.Get_Spec();
        const auto DeltaSeconds = float32(InDeltaT.Get_Seconds());

        InState.ContactAge += DeltaSeconds;

        const auto Recent = InState.ContactAge <= Spec.GraceSeconds;
        const auto SleepingWhileResting = InState.State == EMars_Resting_State::Resting
            && utils_jolt_body::Get_SleepState(InState.Body) == ECk_Jolt_SleepState::Asleep;
        const auto IsResting = Recent || SleepingWhileResting;

        if (InState.State == EMars_Resting_State::Apart && IsResting)
        {
            const auto ApartSeconds = InState.ApartSeconds;
            const auto Hopped = ApartSeconds >= Spec.HopMinSeconds;
            if (Hopped)
            { InState.Hops += 1; }

            InState.ApartSeconds = 0.0f;
            InState.State = EMars_Resting_State::Resting;

            if (Self.Has_Fragment(FMars_Fragment_Resting_Signals) == false)
            { return; }

            if (Hopped)
            { Self.Get_Fragment(FMars_Fragment_Resting_Signals).OnLanded.Broadcast(Self, ApartSeconds); }

            if (Self.Has_Fragment(FMars_Fragment_Resting_Signals))
            { Self.Get_Fragment(FMars_Fragment_Resting_Signals).OnRestingChanged.Broadcast(Self, EMars_Resting_State::Resting); }

            return;
        }

        const auto Left = InState.State == EMars_Resting_State::Resting && IsResting == false;
        if (Left)
        { InState.State = EMars_Resting_State::Apart; }

        if (InState.State == EMars_Resting_State::Apart)
        { InState.ApartSeconds += DeltaSeconds; }

        if (Left && Self.Has_Fragment(FMars_Fragment_Resting_Signals))
        { Self.Get_Fragment(FMars_Fragment_Resting_Signals).OnRestingChanged.Broadcast(Self, EMars_Resting_State::Apart); }
    }
}
