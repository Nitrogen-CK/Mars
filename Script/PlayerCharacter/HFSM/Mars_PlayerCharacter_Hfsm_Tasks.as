class UMars_SmTask_ViewpointSync : UCk_SmTask_EntityScript
{
    default _TaskMode = ECk_SmTaskMode::Tick;

    private APawn CachedPawn;
    private FCk_Handle_PlayerViewpoint CachedViewpoint;

    UFUNCTION(BlueprintOverride)
    void DoEnterTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        auto Player = ck::Ctx(InHandle);
        CachedPawn = Cast<APawn>(ck::ToActor(Player));
        CachedViewpoint = Player.As_PlayerViewpoint();
    }

    UFUNCTION(BlueprintOverride)
    ECk_SmTaskResult DoTick(FCk_Handle_SmTask InHandle, FCk_Time InDeltaT, ECk_Sm_NetContext InNetContext)
    {
        if (ck::Is_NOT_Valid(CachedPawn) || ck::Is_NOT_Valid(CachedPawn.Controller))
        { return ECk_SmTaskResult::Running; }

        FVector ViewLocation;
        FRotator ViewRotation;
        CachedPawn.Controller.GetPlayerViewPoint(ViewLocation, ViewRotation);
        CachedViewpoint.Request_SetView(ViewLocation, ViewRotation);

        return ECk_SmTaskResult::Running;
    }
}

// View trace -> focus. The nearest overlapped interactable wins; its targets are offered to the
// player's resolver and it is told who focuses it (which drives its prompt).
class UMars_SmTask_InteractionFocus : UCk_SmTask_EntityScript
{
    default _TaskMode = ECk_SmTaskMode::EnterExitOnly;

    private FCk_Handle _Player;
    private FCk_Handle_ProbeTrace _Trace;
    private FCk_Handle_InteractionResolver _Resolver;
    private TArray<FCk_Handle_Interactable> _Candidates;
    private FCk_Handle_Interactable _Focused;

    UFUNCTION(BlueprintOverride)
    void DoEnterTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        _Player = ck::Ctx(InHandle);
        _Trace = _Player.As_PlayerViewpoint().Get_InteractionTrace();
        _Resolver = _Player.As_InteractionResolver();

        _Trace.BindTo_OnBeginOverlap(FCk_Delegate_ProbeTrace_OnBeginOverlap(this, n"OnTraceBeginOverlap"));
        _Trace.BindTo_OnEndOverlap(FCk_Delegate_ProbeTrace_OnEndOverlap(this, n"OnTraceEndOverlap"));

        auto CurrentOverlaps = _Trace.Get_CurrentOverlaps();
        for (auto Overlap : CurrentOverlaps)
        { DoAddCandidate(Overlap.Get_OtherEntity()); }
    }

    UFUNCTION(BlueprintOverride)
    void DoExitTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        if (ck::IsValid(_Trace))
        {
            _Trace.UnbindFrom_OnBeginOverlap(FCk_Delegate_ProbeTrace_OnBeginOverlap(this, n"OnTraceBeginOverlap"));
            _Trace.UnbindFrom_OnEndOverlap(FCk_Delegate_ProbeTrace_OnEndOverlap(this, n"OnTraceEndOverlap"));
        }

        if (ck::IsValid(_Focused))
        { DoUnfocus(_Focused); }

        _Candidates.Empty();
        _Focused = FCk_Handle_Interactable();
    }

    UFUNCTION()
    private void OnTraceBeginOverlap(FCk_Handle_ProbeTrace InHandle, FCk_Probe_Payload_OnBeginOverlap InPayload)
    {
        DoAddCandidate(InPayload.Get_OtherEntity());
    }

    UFUNCTION()
    private void OnTraceEndOverlap(FCk_Handle_ProbeTrace InHandle, FCk_Probe_Payload_OnEndOverlap InPayload)
    {
        auto Interactable = InPayload.Get_OtherEntity().As_Interactable(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(Interactable))
        { return; }

        _Candidates.Remove(Interactable);
        Recompute_Focus();
    }

    private void DoAddCandidate(FCk_Handle InEntity)
    {
        auto Interactable = InEntity.As_Interactable(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(Interactable))
        { return; }

        _Candidates.AddUnique(Interactable);
        Recompute_Focus();
    }

    // Same distance metric the resolver sorts by, so the prompt and the interaction agree.
    private void Recompute_Focus()
    {
        const auto PlayerLocation = Get_Location(_Player);

        auto Best = FCk_Handle_Interactable();
        float64 BestDistSq = 0.0;
        for (int32 Index = _Candidates.Num() - 1; Index >= 0; --Index)
        {
            auto Candidate = _Candidates[Index];
            if (ck::Is_NOT_Valid(Candidate))
            {
                _Candidates.RemoveAt(Index);
                continue;
            }

            if (Candidate.Get_EnableDisable() == ECk_EnableDisable::Disable)
            { continue; }

            const auto DistSq = (Get_Location(Candidate) - PlayerLocation).SizeSquared();
            if (ck::Is_NOT_Valid(Best) || DistSq < BestDistSq)
            {
                Best = Candidate;
                BestDistSq = DistSq;
            }
        }

        if (Best == _Focused)
        { return; }

        if (ck::IsValid(_Focused))
        { DoUnfocus(_Focused); }

        _Focused = Best;

        if (ck::IsValid(_Focused))
        { DoFocus(_Focused); }
    }

    private void DoFocus(FCk_Handle_Interactable& InInteractable)
    {
        InInteractable.Request_Focus(FMars_Request_Interactable_Focus(_Player));

        for (auto Target : InInteractable.Get_AllInteractTargets())
        { _Resolver.Request_AddInteractTarget(FCk_Request_InteractionResolver_AddInteractTarget(Target)); }
    }

    private void DoUnfocus(FCk_Handle_Interactable& InInteractable)
    {
        InInteractable.Request_Unfocus(FMars_Request_Interactable_Unfocus(_Player));

        auto Targets = InInteractable.Get_AllInteractTargets();
        for (auto& Target : Targets)
        {
            Target.Request_CancelInteraction(FCk_Request_InteractTarget_CancelInteraction(_Player));
            _Resolver.Request_RemoveInteractTarget(FCk_Request_InteractionResolver_RemoveInteractTarget(Target));
        }
    }

    private FVector Get_Location(FCk_Handle InEntity) const
    {
        auto AsTransform = InEntity.As_Transform(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(AsTransform))
        { return FVector::ZeroVector; }

        return utils_transform::Get_EntityCurrentTransform(AsTransform).GetLocation();
    }
}

// Resolver -> interaction start. Every newly-best target starts an interaction from the player.
class UMars_SmTask_InteractionResolverBinds : UCk_SmTask_EntityScript
{
    default _TaskMode = ECk_SmTaskMode::EnterExitOnly;

    private FCk_Handle _Player;
    private FCk_Handle_InteractionResolver _Resolver;

    UFUNCTION(BlueprintOverride)
    void DoEnterTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        _Player = ck::Ctx(InHandle);
        _Resolver = _Player.As_InteractionResolver();
        _Resolver.BindTo_OnBestTargetsChanged(
            FCk_Delegate_InteractionResolver_OnBestTargetsChanged(this, n"OnBestTargetsChanged"));
    }

    UFUNCTION(BlueprintOverride)
    void DoExitTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        if (ck::IsValid(_Resolver))
        {
            _Resolver.UnbindFrom_OnBestTargetsChanged(
                FCk_Delegate_InteractionResolver_OnBestTargetsChanged(this, n"OnBestTargetsChanged"));
        }
    }

    UFUNCTION()
    private void OnBestTargetsChanged(FCk_Handle_InteractionResolver InResolver, FGameplayTag InIntent,
                                      const TArray<FCk_Handle_InteractTarget>&in InPreviousTargets,
                                      const TArray<FCk_Handle_InteractTarget>&in InNewTargets,
                                      const TArray<FCk_Handle_InteractTarget>&in InRemovedTargets)
    {
        for (auto RemovedTarget : InRemovedTargets)
        {
            if (ck::Is_NOT_Valid(RemovedTarget))
            { continue; }

            auto MutableTarget = RemovedTarget;
            MutableTarget.Request_CancelInteraction(FCk_Request_InteractTarget_CancelInteraction(_Player));
        }

        for (auto NewTarget : InNewTargets)
        {
            if (ck::Is_NOT_Valid(NewTarget))
            { continue; }

            auto MutableTarget = NewTarget;
            MutableTarget.Request_StartInteraction(FCk_Try_InteractTarget_StartInteraction(_Player, _Player));
        }
    }
}

// Mirrors a CkIntent level row onto a resolver intent: Active opens it, Idle closes it.
class UMars_SmTask_IntentToResolver : UCk_SmTask_EntityScript
{
    default _TaskMode = ECk_SmTaskMode::Tick;

    protected FGameplayTag InputIntent;
    protected FGameplayTag ResolverIntent;

    private FCk_Handle_InputIntents _Intents;
    private FCk_Handle_InteractionResolver _Resolver;
    private bool _IntentOpen = false;

    UFUNCTION(BlueprintOverride)
    void DoEnterTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        auto Player = ck::Ctx(InHandle);
        _Intents = Player.As_InputIntents();
        _Resolver = Player.As_InteractionResolver();
        _IntentOpen = false;
    }

    UFUNCTION(BlueprintOverride)
    ECk_SmTaskResult DoTick(FCk_Handle_SmTask InHandle, FCk_Time InDeltaT, ECk_Sm_NetContext InNetContext)
    {
        const auto IsActive = _Intents.Get_IsIntentActive(InputIntent);
        if (IsActive == _IntentOpen)
        { return ECk_SmTaskResult::Running; }

        _IntentOpen = IsActive;
        if (IsActive)
        { _Resolver.Request_StartIntent(FCk_Request_InteractionResolver_StartIntent(ResolverIntent)); }
        else
        { _Resolver.Request_StopIntent(FCk_Request_InteractionResolver_StopIntent(ResolverIntent)); }

        return ECk_SmTaskResult::Running;
    }

    UFUNCTION(BlueprintOverride)
    void DoExitTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        if (_IntentOpen && ck::IsValid(_Resolver))
        { _Resolver.Request_StopIntent(FCk_Request_InteractionResolver_StopIntent(ResolverIntent)); }

        _IntentOpen = false;
    }
}

class UMars_SmTask_UseIntentToResolver : UMars_SmTask_IntentToResolver
{
    default InputIntent = GameplayTags::Mars_Intent_Interact_Use;
    default ResolverIntent = GameplayTags::InteractionIntent_Mars_Use;
}

class UMars_SmTask_PrimaryIntentToResolver : UMars_SmTask_IntentToResolver
{
    default InputIntent = GameplayTags::Mars_Intent_Interact_Primary;
    default ResolverIntent = GameplayTags::InteractionIntent_Mars_Primary;
}
