// One recorded scream: the root, its sequence, and the commit time on that root's own kernel clock.
struct FMars_AutoTestHelper_TurnipCommit
{
    FCk_Handle_ScreamingTurnip Turnip;
    int32 Sequence = 0;
    float32 At = 0.0f;
}

// One recorded placement change, with the root's kernel clock at it.
struct FMars_AutoTestHelper_TurnipPlacement
{
    FCk_Handle_ScreamingTurnip Turnip;
    EMars_ScreamingTurnip_Placement Previous = EMars_ScreamingTurnip_Placement::Loose;
    EMars_ScreamingTurnip_Placement New = EMars_ScreamingTurnip_Placement::Loose;
    float32 At = 0.0f;
}

// The Screaming Turnip tests' rig. Roots are spawned through their entity script (World mode, owned by the test entity)
// with SHORT timings (Make_ShortVocal: Anticipate 0.1, Inhale 0.2, Scream 0.1, Recover 0.1, Cooldown 0.6, so an
// uninterrupted start-to-start period is 0.9 s) on a static slab, and every OnScreamCommitted and OnPlacementChanged is
// recorded with the root's kernel clock. The checks sample each root's clock every poll, so the largest kernel tick seen is
// the "within one tick" tolerance for the interval assertions. A carrier (body with Back, a two-slot hotbar, HeldItem) is
// built only by the tests that hold a root (Build_Carrier); it picks a root up as the pickup task does (a holder transfer
// into its hotbar's stow target).
UCLASS(Abstract)
class UMars_AutoTestRig_ScreamingTurnip : UMars_AutoTestRig_Carrier
{
    default _TimeoutSeconds = 30.0f;

    // A poll budget, not a ceiling: a root falls, bounces and settles, then screams on a 0.9 s period.
    protected const int32 k_SlowPolls = 1800;
    // Far from every other test's origin.
    protected FVector _Origin = FVector(430000.0, 0.0, -30000.0);

    protected TArray<FCk_Handle_ScreamingTurnip> _Turnips;
    protected TArray<FCk_Handle_WorldItem> _WorldItems;
    protected TArray<FMars_AutoTestHelper_TurnipCommit> _Commits;
    protected TArray<FMars_AutoTestHelper_TurnipPlacement> _Placements;
    protected int32 _PhaseChangeCount = 0;
    // The largest kernel clock step seen between two polls of one root (the tick tolerance).
    protected float32 _MaxTick = 0.0f;
    private TArray<float32> _LastClocks;

    // The bed (Spawn_Bed), its Forage and Use target, and what its Forage and target reported.
    protected FCk_Handle _Bed;
    protected FCk_Handle_Forage _BedForage;
    protected FCk_Handle_Interactable _BedInteractable;
    protected FCk_Handle_InteractTarget _BedTarget;
    protected TArray<FCk_Handle> _Released;
    protected TArray<EMars_Forage_ReleaseReason> _ReleaseReasons;
    protected int32 _ExhaustedCount = 0;
    protected int32 _RefusedCount = 0;
    protected TArray<ECk_SucceededFailed> _PullResults;
    protected int32 _PullsStarted = 0;

    // Anticipate 0.1, Inhale 0.2, Scream 0.1, Recover 0.1, Cooldown 0.6: period 0.9 s.
    protected FMars_ScreamingTurnip_Vocal Make_ShortVocal() const
    {
        auto Vocal = FMars_ScreamingTurnip_Vocal();
        Vocal.AnticipateSeconds = 0.1f;
        Vocal.InhaleSeconds = 0.2f;
        Vocal.ScreamSeconds = 0.1f;
        Vocal.RecoverSeconds = 0.1f;
        Vocal.CooldownSeconds = 0.6f;
        return Vocal;
    }

    // Cooldown + Anticipate + Inhale: the uninterrupted start-to-start period.
    protected float32 Get_Period(const FMars_ScreamingTurnip_Vocal& InVocal) const
    {
        return InVocal.CooldownSeconds + InVocal.AnticipateSeconds + InVocal.InhaleSeconds;
    }

    // A static BlockAll slab whose top is at the origin, 600 x 300 cm half extents, under InHandle.
    protected void Build_Floor(FCk_Handle InHandle)
    {
        Spawn_StaticSlab(InHandle, _Origin + FVector(150.0, 0.0, -10.0), FVector(600.0, 300.0, 10.0));
    }

    // The carrier at the origin (body with Back, a two-slot hotbar, HeldItem).
    protected void Build_Carrier(FCk_Handle InHandle)
    {
        Add_CarrierBodyWithBack(InHandle, _Origin + FVector(-200.0, 0.0, 0.0));
        Add_Hotbar(_Carrier, 2);
        _HeldItem = utils_held_item::Add(_Carrier);
    }

    // A World-mode root at InLocal (from the origin) with InVocal, owned by InHandle; recorded once constructed.
    protected void Spawn_Turnip(FCk_Handle InHandle, FVector InLocal, FMars_ScreamingTurnip_Vocal InVocal)
    {
        auto Params = UMars_ScreamingTurnip_EntityScript::Params();
        Params.SpawnTransform = FTransform(FRotator::ZeroRotator, _Origin + InLocal);
        Params.Definition = mars_items::ScreamingTurnip();
        Params.Mode = EMars_WorldItem_Mode::World;
        Params.Vocal = InVocal;

        auto Owner = InHandle;
        auto Pending = utils_entity_script::Request_SpawnEntity(Owner, UMars_ScreamingTurnip_EntityScript, Params);
        utils_pending_entity_script::Promise_OnConstructed(Pending, FCk_Delegate_EntityScript_Constructed(this, n"OnTurnipConstructed"));
    }

    // The commits of InTurnip, in order.
    protected TArray<FMars_AutoTestHelper_TurnipCommit> Get_CommitsOf(FCk_Handle_ScreamingTurnip InTurnip) const
    {
        TArray<FMars_AutoTestHelper_TurnipCommit> Result;
        for (const auto& Commit : _Commits)
        {
            if (Commit.Turnip == InTurnip)
            { Result.Add(Commit); }
        }

        return Result;
    }

    // The kernel clock InTurnip first entered InPlacement at (after InAfter); unset if it has not.
    protected TOptional<float32> TryGet_EnteredAt(FCk_Handle_ScreamingTurnip InTurnip, EMars_ScreamingTurnip_Placement InPlacement, float32 InAfter) const
    {
        for (const auto& Change : _Placements)
        {
            if (Change.Turnip == InTurnip && Change.New == InPlacement && Change.At >= InAfter)
            { return TOptional<float32>(Change.At); }
        }

        return TOptional<float32>();
    }

    // InFirst..InLast (commits of one root) each start InPeriod after the one before, within one tick (never earlier).
    protected void Assert_Intervals(const TArray<FMars_AutoTestHelper_TurnipCommit>& InCommits, float32 InPeriod, const FString& InWhat)
    {
        const auto Tolerance = _MaxTick + 0.001f;
        for (int32 Index = 1; Index < InCommits.Num(); ++Index)
        {
            const auto Interval = InCommits[Index].At - InCommits[Index - 1].At;
            Assert_True(Interval >= InPeriod - 0.001f && Interval <= InPeriod + Tolerance,
                f"{InWhat}: scream {InCommits[Index].Sequence} starts {Interval :.3} s after the one before (period {InPeriod :.3}, one tick {_MaxTick :.3})");
        }
    }

    // Samples every root's kernel clock: the largest step between two polls is the tick tolerance.
    protected void Sample_Ticks()
    {
        for (int32 Index = 0; Index < _Turnips.Num(); ++Index)
        {
            if (ck::Is_NOT_Valid(_Turnips[Index]))
            { continue; }

            const auto Clock = _Turnips[Index].Get_Clock();
            if (_LastClocks[Index] >= 0.0f)
            { _MaxTick = Math::Max(_MaxTick, Clock - _LastClocks[Index]); }

            _LastClocks[Index] = Clock;
        }
    }

    // What the pickup task does: InWorldItem's item into the carrier's hotbar stow target.
    protected void Stow(FCk_Handle_WorldItem InWorldItem)
    {
        auto Item = InWorldItem.Get_HeldItem();
        auto Target = _Hotbar.TryGet_StowTarget(Item);
        if (ck::Is_NOT_Valid(Item) || ck::Is_NOT_Valid(Target))
        {
            FinishFailure("stow precondition: a seeded root and a stow target for it");
            return;
        }

        auto Holder = InWorldItem.Get_Holder();
        Holder.Request_TransferItem_ToDataOnly(FCk_Request_Inventory_TransferItem_ToDataOnly(Item, Target),
            FCk_Delegate_Inventory_OnOperationResult_Transfer());
    }

    // A turnip bed at the origin (on the slab), owned by InHandle; its parts are found once it is constructed.
    protected void Spawn_Bed(FCk_Handle InHandle)
    {
        auto Params = UMars_ScreamingTurnipBed_EntityScript::Params();
        Params.SpawnTransform = FTransform(FRotator::ZeroRotator, _Origin);
        // The tests' own stages (0.7 s in all): the bed's defaults are a design knob the tests must not move with.
        Params.GripSeconds = 0.2f;
        Params.TugSeconds = 0.5f;

        auto Owner = InHandle;
        auto Pending = utils_entity_script::Request_SpawnEntity(Owner, UMars_ScreamingTurnipBed_EntityScript, Params);
        utils_pending_entity_script::Promise_OnConstructed(Pending, FCk_Delegate_EntityScript_Constructed(this, n"OnBedConstructed"));
    }

    // The test entity (no gloves, no hotbar: free hands) starts a pull on the bed's Use target, as a press does.
    protected void Start_Pull()
    {
        _BedTarget.Request_StartInteraction(FCk_Try_InteractTarget_StartInteraction(_Carrier, _Carrier));
    }

    // The pull's press ends early: the live interaction is cancelled, as letting go of Use does.
    protected void Cancel_Pull()
    {
        _BedTarget.Request_CancelInteraction(FCk_Request_InteractTarget_CancelInteraction(_Carrier));
    }

    // World items within a metre of the bed (the bed spawns its yield under the transient entity).
    protected int32 Get_YieldCountNearBed(FCk_Handle InHandle) const
    {
        auto Count = 0;
        for (const auto& Entity : utils_entity_tag::ForEach_Entity(InHandle, n"TAG_MarsWorldItem"))
        {
            if (ck::Is_NOT_Valid(Entity) || Entity.Is_WorldItem() == false)
            { continue; }

            const auto Location = utils_transform::Get_EntityCurrentTransform(Entity.As_Transform()).GetLocation();
            if (Location.Distance(_Origin) < 400.0)
            { ++Count; }
        }

        return Count;
    }

    // The bed is constructed and its parts are found.
    UFUNCTION()
    protected void Check_BedReady(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(ck::IsValid(_BedTarget) && ck::IsValid(_BedForage));
    }

    UFUNCTION()
    private void OnBedConstructed(FCk_Handle_EntityScript InEntityScriptHandle)
    {
        _Bed = InEntityScriptHandle;
        _BedForage = _Bed.As_Forage(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(_BedForage))
        {
            FinishFailure("the bed composed no Forage");
            return;
        }

        for (const auto& Dependent : utils_entity_lifetime::Get_LifetimeDependents(_Bed))
        {
            auto Interactable = Dependent.As_Interactable(ECk_SanityCheck::UnChecked);
            if (ck::IsValid(Interactable))
            { _BedInteractable = Interactable; }
        }

        if (ck::Is_NOT_Valid(_BedInteractable))
        {
            FinishFailure("the bed composed no interactable");
            return;
        }

        _BedTarget = _BedInteractable.Get_InteractTarget(GameplayTags::InteractionChannel_Mars_Use);
        _BedForage.BindTo_OnReleased(FMars_Delegate_Forage_OnReleased(this, n"OnBedReleased"));
        _BedForage.BindTo_OnExhausted(FMars_Delegate_Forage_OnExhausted(this, n"OnBedExhausted"));
        _BedForage.BindTo_OnReleaseRefused(FMars_Delegate_Forage_OnReleaseRefused(this, n"OnBedRefused"));
        _BedTarget.BindTo_OnNewInteraction(FCk_Delegate_InteractTarget_OnNewInteraction(this, n"OnBedPullStarted"));
        _BedTarget.BindTo_OnInteractionFinished(FCk_Delegate_InteractTarget_OnInteractionFinished(this, n"OnBedPullFinished"));
    }

    UFUNCTION()
    private void OnBedReleased(FCk_Handle_Forage InForage, FCk_Handle InWorldItem, EMars_Forage_ReleaseReason InReason)
    {
        _Released.Add(InWorldItem);
        _ReleaseReasons.Add(InReason);
        Track_ForCleanup(InWorldItem);
    }

    UFUNCTION()
    private void OnBedExhausted(FCk_Handle_Forage InForage)
    {
        ++_ExhaustedCount;
    }

    UFUNCTION()
    private void OnBedRefused(FCk_Handle_Forage InForage, EMars_Forage_ReleaseReason InReason)
    {
        ++_RefusedCount;
    }

    UFUNCTION()
    private void OnBedPullStarted(FCk_Handle_InteractTarget InTarget, FCk_Handle_Interaction InInteraction)
    {
        ++_PullsStarted;
    }

    UFUNCTION()
    private void OnBedPullFinished(FCk_Handle_InteractTarget InTarget, FCk_Handle_Interaction InInteraction, ECk_SucceededFailed InResult)
    {
        _PullResults.Add(InResult);
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Shared checks
    //----------------------------------------------------------------------------------------------------------------------

    // Every spawned root is constructed and its holder seeded.
    UFUNCTION()
    protected void Check_TurnipsReady(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Ready = _WorldItems.Num() > 0;
        for (const auto& WorldItem : _WorldItems)
        { Ready = Ready && ck::IsValid(WorldItem) && ck::IsValid(WorldItem.Get_HeldItem()); }

        Sample_Ticks();
        auto Res = OutResult;
        Res.Set(Ready);
    }

    // The first root is LooseSettled.
    UFUNCTION()
    protected void Check_FirstSettled(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        Sample_Ticks();
        auto Res = OutResult;
        Res.Set(_Turnips.Num() > 0 && _Turnips[0].Get_Placement() == EMars_ScreamingTurnip_Placement::LooseSettled);
    }

    // The first root is Held.
    UFUNCTION()
    protected void Check_FirstHeld(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        Sample_Ticks();
        auto Res = OutResult;
        Res.Set(_Turnips.Num() > 0 && _Turnips[0].Get_Placement() == EMars_ScreamingTurnip_Placement::Held);
    }

    // The first root is in its Inhale.
    UFUNCTION()
    protected void Check_FirstInhaling(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        Sample_Ticks();
        auto Res = OutResult;
        Res.Set(_Turnips.Num() > 0 && _Turnips[0].Get_Phase() == EMars_ScreamingTurnip_Phase::Inhale);
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Signals
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void OnTurnipConstructed(FCk_Handle_EntityScript InEntityScriptHandle)
    {
        FCk_Handle Entity = InEntityScriptHandle;
        auto Turnip = Entity.As_ScreamingTurnip(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(Turnip))
        {
            FinishFailure("a spawned root composed no ScreamingTurnip kernel");
            return;
        }

        _Turnips.Add(Turnip);
        _WorldItems.Add(Entity.As_WorldItem());
        _LastClocks.Add(-1.0f);
        Turnip.BindTo_OnScreamCommitted(FMars_Delegate_ScreamingTurnip_OnScreamCommitted(this, n"OnRigScreamCommitted"));
        Turnip.BindTo_OnPlacementChanged(FMars_Delegate_ScreamingTurnip_OnPlacementChanged(this, n"OnRigPlacementChanged"));
        Turnip.BindTo_OnPhaseChanged(FMars_Delegate_ScreamingTurnip_OnPhaseChanged(this, n"OnRigPhaseChanged"));
    }

    UFUNCTION()
    protected void OnRigScreamCommitted(FCk_Handle_ScreamingTurnip InTurnip, int32 InSequence, FVector InWorldPosition)
    {
        auto Commit = FMars_AutoTestHelper_TurnipCommit();
        Commit.Turnip = InTurnip;
        Commit.Sequence = InSequence;
        Commit.At = InTurnip.Get_Clock();
        _Commits.Add(Commit);

        const auto CommittedAt = InTurnip.Get_LastScreamCommittedAt();
        Assert_True(CommittedAt.IsSet() && CommittedAt.GetValue() == Commit.At, "a commit is broadcast on the tick it is stamped");
        Assert_True(InWorldPosition.Equals(InTurnip.Get_LastScreamPosition()), "the broadcast carries the stamped world position");
    }

    UFUNCTION()
    protected void OnRigPlacementChanged(FCk_Handle_ScreamingTurnip InTurnip, EMars_ScreamingTurnip_Placement InPrevious,
                                         EMars_ScreamingTurnip_Placement InNew)
    {
        auto Change = FMars_AutoTestHelper_TurnipPlacement();
        Change.Turnip = InTurnip;
        Change.Previous = InPrevious;
        Change.New = InNew;
        Change.At = InTurnip.Get_Clock();
        _Placements.Add(Change);
    }

    UFUNCTION()
    protected void OnRigPhaseChanged(FCk_Handle_ScreamingTurnip InTurnip, EMars_ScreamingTurnip_Phase InPrevious, EMars_ScreamingTurnip_Phase InNew)
    {
        ++_PhaseChangeCount;
    }
}
