// The Forage tests' rig: a source entity (child of the test entity) with a transform root and a release point 50 uu up,
// plus the Forage signals recorded. Every released world item is owned by the transient entity and outlives the test, so
// each is tracked for the harness's cleanup (which runs before its leak check; DoEndPlay is later). There is no floor:
// released items fall until the test ends. Each test sets its own isolated origin.
UCLASS(Abstract)
class UMars_AutoTestRig_Forage : UCk_AutoTest_Base
{
    // The forage entity (child of the test entity).
    protected FCk_Handle _Source;
    protected FCk_Handle_Transform _Root;
    protected FCk_Handle_Transform _ReleasePoint;
    protected FCk_Handle_Forage _Forage;

    // World items under construction, from OnReleased.
    protected TArray<FCk_Handle> _Released;
    protected TArray<EMars_Forage_ReleaseReason> _ReleaseReasons;
    protected int32 _ExhaustedCount = 0;
    protected int32 _ReplenishedCount = 0;

    private const float64 k_ReleasePointHeight = 50.0;

    // A source at InOrigin: transform root and a release point node 50 uu up.
    protected void AddSource(FCk_Handle InHandle, FVector InOrigin)
    {
        _Source = utils_entity_lifetime::Request_CreateEntity(InHandle);
        _Root = utils_transform::Add(_Source, FTransform(FRotator::ZeroRotator, InOrigin), ECk_Replication::DoesNotReplicate);
        _ReleasePoint = utils_scene_node::Create(_Root, FTransform(FRotator::ZeroRotator, FVector(0.0, 0.0, k_ReleasePointHeight))).As_Transform();
    }

    // A Rock yield of InCharges exhausting by InExhaustion, released from the rig's node.
    protected FMars_Forage_Spec Make_RockSpec(int32 InCharges, FMars_Forage_ExhaustionSpec InExhaustion) const
    {
        auto Spec = FMars_Forage_Spec();
        Spec.Yield = FMars_Forage_YieldSpec(mars_items::Rock(), InCharges);
        Spec.Exhaustion = InExhaustion;
        Spec.Parts = FMars_Forage_Parts(_ReleasePoint);
        return Spec;
    }

    // utils_forage::Add on _Source with InSpec; binds the three signals.
    protected FCk_Handle_Forage AddForage(FMars_Forage_Spec InSpec)
    {
        _Forage = utils_forage::Add(_Source, InSpec);
        if (ck::Is_NOT_Valid(_Forage))
        {
            FinishFailure("utils_forage::Add rejected the rig's spec");
            return _Forage;
        }

        BindSignals(_Forage);
        return _Forage;
    }

    // Records InForage's three signals; it becomes the rig's _Forage.
    protected void BindSignals(FCk_Handle_Forage InForage)
    {
        _Forage = InForage;
        _Forage.BindTo_OnReleased(FMars_Delegate_Forage_OnReleased(this, n"OnForageReleased"));
        _Forage.BindTo_OnExhausted(FMars_Delegate_Forage_OnExhausted(this, n"OnForageExhausted"));
        _Forage.BindTo_OnReplenished(FMars_Delegate_Forage_OnReplenished(this, n"OnForageReplenished"));
    }

    // A source world object spawned through its entity script (Promise_OnConstructed) becomes _Source.
    UFUNCTION()
    protected void OnSourceConstructed(FCk_Handle_EntityScript InEntityScriptHandle)
    {
        _Source = InEntityScriptHandle;
    }

    // The spawned source composed its Forage and its strike zone.
    protected bool Get_IsSourceComposed() const
    {
        return ck::IsValid(_Source) && _Source.Is_Forage() && _Source.Is_HitZone();
    }

    // InDamage InDamageType on the source's zone.
    protected void HitSource(float32 InDamage, FGameplayTag InDamageType)
    {
        auto Zone = _Source.As_HitZone();
        Zone.Request_Hit(FMars_Request_HitZone_Hit(FMars_DamageEvent(InDamage, InDamageType)));
    }

    // A World-mode Rock at InLocation launched at InVelocity, owned by the transient entity and tracked for cleanup.
    protected FCk_Handle SpawnRock(FVector InLocation, FVector InVelocity)
    {
        auto Owner = ck::TransientEntity();
        auto Rock = utils_world_item::Request_SpawnWorld(Owner,
            FMars_WorldItem_WorldSpec(mars_items::Rock(), FTransform(FRotator::ZeroRotator, InLocation), InVelocity, FVector::ZeroVector));
        Track_ForCleanup(Rock);
        return Rock;
    }

    protected void RequestRelease(EMars_Forage_ReleaseReason InReason)
    {
        _Forage.Request_Release(FMars_Request_Forage_Release(InReason));
    }

    // The yield world item seeded its holder with an item of InDefinition.
    protected bool Get_IsSeededWith(FCk_Handle InReleased, const UCk_InventoryItem_Definition InDefinition)
    {
        auto WorldItem = InReleased.As_WorldItem(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(WorldItem) || WorldItem.Get_Mode() != EMars_WorldItem_Mode::World)
        { return false; }

        const auto Item = WorldItem.Get_HeldItem();
        return ck::IsValid(Item) && Item.Get_Definition() == InDefinition;
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Signals
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    protected void OnForageReleased(FCk_Handle_Forage InForage, FCk_Handle InWorldItem, EMars_Forage_ReleaseReason InReason)
    {
        _Released.Add(InWorldItem);
        _ReleaseReasons.Add(InReason);
        Track_ForCleanup(InWorldItem);
    }

    UFUNCTION()
    protected void OnForageExhausted(FCk_Handle_Forage InForage)
    {
        ++_ExhaustedCount;
    }

    UFUNCTION()
    protected void OnForageReplenished(FCk_Handle_Forage InForage)
    {
        ++_ReplenishedCount;
    }
}
