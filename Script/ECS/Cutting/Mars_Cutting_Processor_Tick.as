// The chop clock, while a chop runs: the strike counts down Spec.ChopSeconds and lands (LandSerial, OnChopLanded, the
// cleaver at the board), then the recover counts down Spec.ChopSeconds and the next press may chop. A long frame finishes
// at most one phase, so the landing is never skipped. The clock is the authority's: a client raises the landing from the
// ledger (UMars_Processor_Cutting_Mirror).
class UMars_Processor_Cutting_Tick : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _RunAfter.Add(n"/Script/Angelscript.Mars_Processor_Cutting_HandleRequests");

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_Cutting);
        Query.Require(FMars_Tag_Cutting_Chopping);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle, FMars_Fragment_Cutting& InState)
    {
        if (utils_net::Get_HasAuthority(InHandle) == false)
        { return; }

        auto Self = InHandle.As_Cutting();
        auto& Local = InHandle.Get_Fragment(FMars_Fragment_Cutting_Local);

        Local.ChopSecondsLeft = Math::Max(0.0f, Local.ChopSecondsLeft - float32(InDeltaT.Get_Seconds()));
        if (Local.ChopSecondsLeft > 0.0f)
        { return; }

        if (Local.ChopPhase == EMars_Cutting_ChopPhase::Recovering)
        {
            Local.ChopPhase = EMars_Cutting_ChopPhase::Idle;
            Self.Request_TryRemove(FMars_Tag_Cutting_Chopping);
            return;
        }

        Local.ChopPhase = EMars_Cutting_ChopPhase::Recovering;
        Local.ChopSecondsLeft = Self.Get_Spec().ChopSeconds;
        InState.LandSerial += 1;
        InHandle.Request_MarkReplicationDirty(FMars_Fragment_Cutting);

        // InState and Local are not read past this line: a listener may add fragments to the station.
        if (Self.Has_Fragment(FMars_Fragment_Cutting_Signals))
        { Self.Get_Fragment(FMars_Fragment_Cutting_Signals).OnChopLanded.Broadcast(Self); }
    }
}
