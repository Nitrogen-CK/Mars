// The forage net tests' shared steps: the server spawns a forage source under the replicated spawn owner; each machine
// finds its copy by tag near the test's base, counts the Forage signals its own copy raises (in order) and counts the
// world items of a definition lying near the base. The server tracks what it finds for cleanup; nothing has a floor, so a
// yield is "near" by its horizontal distance only.
UCLASS(Abstract)
class UMars_AutoTestRig_NetForage : UCk_AutoTest_NetBase
{
    default _TimeoutSeconds = 20.0f;

    protected const int32 k_SlowPolls = 5000;
    protected const float32 k_SettleSeconds = 1.5f;
    protected const float32 k_ServerHoldSeconds = 4.0f;
    protected const float64 k_NearCm = 400.0;

    protected FVector _Base = FVector::ZeroVector;
    protected FCk_Handle _Source;
    protected FCk_Handle_Forage _Forage;
    protected int32 _EnsuresAtStart = 0;

    protected int32 _Released = 0;
    protected int32 _Exhausted = 0;
    protected int32 _Replenished = 0;
    protected TOptional<EMars_Forage_ReleaseReason> _LastReason;
    // The signals in the order this machine raised them: R released, E exhausted, P replenished.
    protected FString _Order;
    // Whether a regrow timer existed on this machine when it raised OnExhausted.
    protected bool _RegrowPendingAtExhaust = false;

    protected void Begin_Rig(FVector InBase)
    {
        _Base = InBase;
        _EnsuresAtStart = utils_ensure::Get_EnsureCount();
    }

    protected bool Get_IsServer()
    {
        return utils_net::Get_HasAuthority(Get_SubjectEntity());
    }

    protected int32 Get_NewEnsures() const
    {
        return utils_ensure::Get_EnsureCount() - _EnsuresAtStart;
    }

    UFUNCTION()
    protected void Is_ReplicatedSpawnOwnerPublished(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(utils_mars_net::Get_HasReplicatedSpawnOwner(Get_SubjectEntity()));
    }

    // Server: a fig vine (one fig, regrowing after InRegrowSeconds) at the base.
    protected void Spawn_ServerFigVine(float32 InRegrowSeconds)
    {
        auto Params = UMars_Forage_FigVine_EntityScript::Params();
        Params.SpawnTransform = FTransform(FRotator::ZeroRotator, _Base);
        Params.RegrowSeconds = InRegrowSeconds;
        Params.WithVisuals = false;
        utils_entity_script::Request_SpawnEntity(utils_mars_net::Get_ReplicatedSpawnOwner(Get_SubjectEntity()), UMars_Forage_FigVine_EntityScript, Params);
    }

    // This machine's copy of the source tagged InTag near the base has composed its forage; the first time, its signals are
    // counted from here (and the server tracks it).
    protected bool Get_IsSourceFound(FName InTag)
    {
        if (ck::IsValid(_Forage))
        { return true; }

        for (auto Candidate : utils_entity_tag::ForEach_Entity(Get_SubjectEntity(), InTag))
        {
            if (Get_IsNear(Candidate) == false)
            { continue; }

            auto Forage = Candidate.As_Forage(ECk_SanityCheck::UnChecked);
            if (ck::Is_NOT_Valid(Forage))
            { continue; }

            _Source = Candidate;
            _Forage = Forage;
            _Forage.BindTo_OnReleased(FMars_Delegate_Forage_OnReleased(this, n"OnForageReleased"));
            _Forage.BindTo_OnExhausted(FMars_Delegate_Forage_OnExhausted(this, n"OnForageExhausted"));
            _Forage.BindTo_OnReplenished(FMars_Delegate_Forage_OnReplenished(this, n"OnForageReplenished"));
            if (Get_IsServer())
            { Track_ForCleanup(Candidate); }

            return true;
        }

        return false;
    }

    protected bool Get_IsNear(FCk_Handle InEntity)
    {
        const auto Transform = InEntity.As_Transform(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(Transform))
        { return false; }

        auto Offset = utils_transform::Get_EntityCurrentTransform(Transform).GetLocation() - _Base;
        Offset.Z = 0.0;
        return Offset.Size() < k_NearCm;
    }

    // World items near the base whose held item is of InDefinition; the server tracks each one it counts.
    protected int32 Count_WorldItemsNear(const UCk_InventoryItem_Definition InDefinition)
    {
        auto Count = 0;
        for (auto Candidate : utils_entity_tag::ForEach_Entity(Get_SubjectEntity(), n"TAG_MarsWorldItem"))
        {
            auto WorldItem = Candidate.As_WorldItem(ECk_SanityCheck::UnChecked);
            if (ck::Is_NOT_Valid(WorldItem) || Get_IsNear(Candidate) == false)
            { continue; }

            const auto Item = WorldItem.Get_HeldItem();
            if (ck::Is_NOT_Valid(Item) || Item.Get_Definition() != InDefinition)
            { continue; }

            if (Get_IsServer())
            { Track_ForCleanup(Candidate); }

            Count += 1;
        }

        return Count;
    }

    // The first oscillator under the source (the censer's pivot), searched three dependents deep.
    protected FCk_Handle_Oscillator Get_SourceOscillator()
    {
        auto Frontier = utils_entity_lifetime::Get_LifetimeDependents(_Source);
        for (int32 Depth = 0; Depth < 3 && Frontier.Num() > 0; ++Depth)
        {
            auto Next = TArray<FCk_Handle>();
            for (auto Entity : Frontier)
            {
                const auto Oscillator = Entity.As_Oscillator(ECk_SanityCheck::UnChecked);
                if (ck::IsValid(Oscillator))
                { return Oscillator; }

                Next.Append(Entity.Get_LifetimeDependents());
            }

            Frontier = Next;
        }

        return FCk_Handle_Oscillator();
    }

    UFUNCTION()
    protected void OnServerHeld(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        FinishSuccess();
    }

    UFUNCTION()
    private void OnForageReleased(FCk_Handle_Forage InForage, FCk_Handle InWorldItem, EMars_Forage_ReleaseReason InReason)
    {
        _Released += 1;
        _LastReason = TOptional<EMars_Forage_ReleaseReason>(InReason);
        _Order += "R";
    }

    UFUNCTION()
    private void OnForageExhausted(FCk_Handle_Forage InForage)
    {
        _Exhausted += 1;
        _Order += "E";
        _RegrowPendingAtExhaust = InForage.Get_IsRegrowPending();
    }

    UFUNCTION()
    private void OnForageReplenished(FCk_Handle_Forage InForage)
    {
        _Replenished += 1;
        _Order += "P";
    }
}
