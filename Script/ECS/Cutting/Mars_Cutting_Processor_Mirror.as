// Once per cleaver: the authority drops the mirror state (its own drain and chop clock broadcast). A client binds the
// ledger's rep-notify and reconciles once, so a ledger that replicated before the bind still counts; each reconcile slides
// this machine's lateral node to the ledger's hand unless this machine predicts its own, then raises, from the arrived
// ledger against the one it last reconciled, OnChopStarted once per ChopSerial and OnChopLanded once per LandSerial it had
// not seen, each chop's start before its landing. The cleaver's mover, the sound and the burst follow those on a client.
class UMars_Processor_Cutting_Mirror : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _MarkedDirtyBy = FMars_Tag_Cutting_NeedsMirror;

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_Cutting);
        Query.Require(FMars_Tag_Cutting_NeedsMirror);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle)
    {
        InHandle.Request_TryRemove(FMars_Tag_Cutting_NeedsMirror);
        auto Cutting = InHandle.As_Cutting();

        if (utils_net::Get_HasAuthority(InHandle))
        {
            Cutting.Get_Fragment(FMars_Fragment_Cutting_Local).Last = TOptional<FMars_Fragment_Cutting>();
            return;
        }

        InHandle.BindTo_OnRepNotify(FMars_Fragment_Cutting, FCk_DynamicFragment_OnRepNotify(this, n"OnLedgerReplicated"));
        Reconcile(Cutting);
    }

    UFUNCTION()
    private void OnLedgerReplicated(FCk_Handle InHandle, FCk_DynamicFragment_RepNotifyInfo InInfo)
    {
        auto Cutting = InHandle.As_Cutting();
        Reconcile(Cutting);
    }

    // Last is written before any broadcast: a handler may compose on another entity and move the fragment storage.
    private void Reconcile(FCk_Handle_Cutting& InCutting)
    {
        const auto Ledger = InCutting.Get_Fragment(FMars_Fragment_Cutting);
        auto& Local = InCutting.Get_Fragment(FMars_Fragment_Cutting_Local);
        if (ck::EnsureIfNot(Local.Last.IsSet(), f"[Cutting] [{InCutting.ToString()}] has no mirror state off authority"))
        { return; }

        const auto Last = Local.Last.GetValue();
        Local.Last = TOptional<FMars_Fragment_Cutting>(Ledger);
        const auto IsPredicting = Local.PredictedHand.IsSet();

        if (IsPredicting == false)
        { utils_cutting::Apply_HandToNode(InCutting.Get_Spec().Nodes.LateralNode, Ledger.HandLateral); }

        if (InCutting.Has_Fragment(FMars_Fragment_Cutting_Signals) == false)
        { return; }

        // A chop starts only once the one before it landed, so the next start waits for the landing it follows.
        auto Started = Last.ChopSerial;
        auto Landed = Last.LandSerial;
        while (Started < Ledger.ChopSerial || Landed < Ledger.LandSerial)
        {
            const auto StartsNext = Started < Ledger.ChopSerial && (Started <= Landed || Landed >= Ledger.LandSerial);
            if (StartsNext)
            {
                Started += 1;
                InCutting.Get_Fragment(FMars_Fragment_Cutting_Signals).OnChopStarted.Broadcast(InCutting);
                continue;
            }

            Landed += 1;
            InCutting.Get_Fragment(FMars_Fragment_Cutting_Signals).OnChopLanded.Broadcast(InCutting);
        }
    }
}
