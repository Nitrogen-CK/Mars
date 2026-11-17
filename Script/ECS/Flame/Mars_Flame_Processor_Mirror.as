// Once per flame: the authority only drops the tag (its own processors broadcast). A client binds the ledger's rep-notify
// and reconciles once, so a ledger that replicated before the bind still counts; each reconcile reads the arrived ledger
// and hands the reading it last reconciled and this one to utils_flame::Apply_Changes, which keeps the Burning tag and
// raises the signals the authority raised, in its order (measures, condition, lit). The dressing and the light probe
// follow those on a client with nothing else to do.
class UMars_Processor_Flame_Mirror : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _MarkedDirtyBy = FMars_Tag_Flame_NeedsMirror;

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_Flame);
        Query.Require(FMars_Tag_Flame_NeedsMirror);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle)
    {
        InHandle.Request_TryRemove(FMars_Tag_Flame_NeedsMirror);

        if (utils_net::Get_HasAuthority(InHandle))
        { return; }

        InHandle.BindTo_OnRepNotify(FMars_Fragment_Flame, FCk_DynamicFragment_OnRepNotify(this, n"OnLedgerReplicated"));
        auto Flame = InHandle.As_Flame();
        Reconcile(Flame);
    }

    // An expected absence, not a defect: a notify can land on an entity already ending.
    UFUNCTION()
    private void OnLedgerReplicated(FCk_Handle InHandle, FCk_DynamicFragment_RepNotifyInfo InInfo)
    {
        if (ck::Is_NOT_Valid(InHandle) || utils_entity_lifetime::Get_IsPendingDestroy(InHandle, ECk_EntityLifetime_DestructionPhase::BeginDestroy)
            || InHandle.Is_Flame() == false)
        { return; }

        auto Flame = InHandle.As_Flame();
        Reconcile(Flame);
    }

    private void Reconcile(FCk_Handle_Flame& InFlame)
    {
        const auto& Params = InFlame.Get_Fragment(FMars_Fragment_Flame_Params);
        const auto Now = utils_flame::Make_Reading(Params, InFlame.Get_Fragment(FMars_Fragment_Flame));
        auto& Local = InFlame.Get_Fragment(FMars_Fragment_Flame_Local);
        const auto Last = Local.Last;
        Local.Last = Now;

        // Handlers refresh the flame's dressing: scope the script world to the flame's.
        const auto WorldContext = FAngelscriptGameThreadScopeWorldContext(utils_entity_lifetime::Get_WorldForEntity(InFlame));
        utils_flame::Apply_Changes(InFlame, Last, Now);
    }
}
