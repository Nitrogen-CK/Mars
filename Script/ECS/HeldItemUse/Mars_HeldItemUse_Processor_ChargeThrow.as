// Charges an armed throw: ThrowCharge rises from 0 to 1 over the held item's ChargeSeconds and holds there until the
// throw disarms (the requests drain zeroes it on every arm and disarm). After the drain, so a release drained this frame
// throws at the charge reached by the end of the last one.
class UMars_Processor_HeldItemUse_ChargeThrow : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _RunAfter.Add(n"/Script/Angelscript.Mars_Processor_HeldItemUse_HandleRequests");

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_HeldItemUse);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle, FMars_Fragment_HeldItemUse& InState)
    {
        if (InState.ThrowArmed == false || InState.ThrowCharge >= 1.0f)
        { return; }

        const auto ChargeSeconds = InHandle.As_HeldItemUse().Get_ThrowTuning().ChargeSeconds;
        if (ChargeSeconds <= 0.0f)
        {
            InState.ThrowCharge = 1.0f;
            return;
        }

        InState.ThrowCharge = Math::Min(1.0f, InState.ThrowCharge + float32(InDeltaT.Get_Seconds()) / ChargeSeconds);
    }
}
