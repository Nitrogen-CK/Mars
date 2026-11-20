// What one machine's copy of a leg part raised: OnSevered, how many rig parts its detach released, and the frame and
// world seconds of the first.
struct FMars_NetCrawlerTest_PartSignals
{
    UPROPERTY()
    int32 Severed = 0;

    UPROPERTY()
    int32 Released = 0;

    UPROPERTY()
    int32 Frame = -1;

    UPROPERTY()
    float64 Seconds = -1.0;
}

// One foot over a feet record: its highest lift over the floor, and whether it was seen swinging and then planted.
struct FMars_NetCrawlerTest_FootRecord
{
    UPROPERTY()
    float64 HighestLift = -1000.0;

    UPROPERTY()
    bool Lifted = false;

    UPROPERTY()
    bool PlantedAgain = false;
}

// One severed limb as this machine saw it, from the first frame it was near the base to the row's end: when it arrived
// and left, its widest joint gap, each knee's angle when first seen and its largest departure from it, its first
// piece's first and last place, its ledger's notifies and the frame it first read at rest.
struct FMars_NetCrawlerTest_LimbRecord
{
    UPROPERTY()
    FCk_Handle Limb;

    UPROPERTY()
    int32 FirstFrame = -1;

    UPROPERTY()
    float64 FirstSeconds = -1.0;

    UPROPERTY()
    float64 GoneSeconds = -1.0;

    UPROPERTY()
    float64 WidestGap = 0.0;

    UPROPERTY()
    TArray<float64> KneeStart;

    UPROPERTY()
    TArray<float64> KneeSwing;

    UPROPERTY()
    FVector FirstPieceStart = FVector::ZeroVector;

    UPROPERTY()
    FVector FirstPieceLast = FVector::ZeroVector;

    UPROPERTY()
    int32 RestFrame = -1;

    UPROPERTY()
    float64 RestSeconds = -1.0;

    // Off authority: the ledger's rep-notifies, and how many had arrived before the one that read at rest.
    UPROPERTY()
    int32 Notifies = 0;

    UPROPERTY()
    int32 NotifiesBeforeRest = -1;

    // Off authority: whether the limb's ledger stood when this machine composed it, or arrived after.
    UPROPERTY()
    FString LedgerInitial = "";

    // Authority: the contacts its pieces' bodies reported with another piece of the same limb.
    UPROPERTY()
    int32 NeighbourContacts = 0;

    UPROPERTY()
    bool ContactsBound = false;
}

// Test-only, on a limb's root: the server's world pose of every piece once its limb reads at rest, replicated so the
// client can set its own beside it.
struct FMars_TESTONLY_Fragment_SeveredLimb_RestPose
{
    UPROPERTY()
    TArray<FTransform> Pieces;
}

// A crawler that severs its own leg part 0 (a 30 Sever cause) in its construction, with authority only: a copy is born
// into the sever.
class UMars_TESTONLY_NetCrawler_BornSevered_EntityScript : UMars_Crawler_EntityScript
{
    UFUNCTION(BlueprintOverride)
    ECk_EntityScript_ConstructionFlow DoConstruct(FCk_Handle& InHandle)
    {
        const auto Flow = Super::DoConstruct(InHandle);
        if (utils_net::Get_HasAuthority(InHandle) == false)
        { return Flow; }

        auto Crawler = InHandle.As_Crawler(ECk_SanityCheck::UnChecked);
        if (ck::IsValid(Crawler) && Crawler.Get_LegParts().Num() > 0)
        {
            auto Part = Crawler.Get_LegParts()[0];
            Part.Request_Sever(FMars_Request_BodyPart_Sever(FMars_DamageEvent(30.0f, GameplayTags::DamageType_Mars_Sever)));
        }

        return Flow;
    }
}

// The crawler net tests' shared steps, on top of the strike rig (whose striker only the strike row composes): each
// machine lays its own static floor owned by its subject (a copy's walker finds its ground in this machine's world);
// the server spawns a 4-leg crawler through its real entity script under the replicated spawn owner (its root 65
// above the floor, facing +X, without visuals, combat off). Each machine finds its copy by tag near where it was
// spawned, takes its leg parts in order and every leg's rig parts (segments, then the foot), counts what each of its
// own parts and its monster raise and the OnDamaged of its body Health, records the part ledger's rep-notifies off
// authority, and samples its copy from the row's polled predicates: the root's path and largest step, its farthest
// offset from the base, whether its gait ever read Failed and, between Begin_FeetRecord and the row's end, the feet
// of its attached legs. A severed leg's rig parts die on every machine at the cut, and the one limb the authority
// spawns for it lives under the replicated spawn owner: a row ends only once no limb is near its base there. Each
// machine samples the limbs near its base (Sample_Limbs) from the first frame each is seen.
UCLASS(Abstract)
class UMars_AutoTestRig_NetCrawler : UMars_AutoTestRig_NetStrike
{
    default _TimeoutSeconds = 28.0f;

    protected const int32 k_LegCount = 4;
    protected const FVector k_FloorHalfExtents = FVector(1500.0, 1500.0, 10.0);
    protected const float64 k_RootOverFloor = 65.0;
    // The server waits this long once its crawler reads settled, so the client's copy has composed.
    protected const float32 k_ComposeSeconds = 2.0f;
    protected const FVector k_StaysPut = FVector(10.0, 10.0, 200.0);
    protected const FVector k_Roams = FVector(500.0, 500.0, 200.0);
    protected const float32 k_LegHit = 20.0f;
    protected const float32 k_LegHitSpacingSeconds = 0.3f;
    protected const int32 k_MaxLegHits = 4;
    protected const int32 k_MaxLegClaims = 6;
    // A claimed leg's rest foot stands this far in front of the hand (+X).
    protected const float64 k_ClaimedFootFromHand = 60.0;
    // A limb within this of the base (horizontally) is this row's.
    protected const float64 k_LimbNearCm = 600.0;
    // Decision tolerances: the authority's joints at every sample, a copy's at rest, a copy's piece against the published
    // rest pose, a knee's least swing and its farthest.
    protected const float64 k_AuthorityGapCm = 2.0;
    protected const float64 k_CopyGapCm = 4.0;
    protected const float64 k_RestPoseCm = 3.0;
    protected const float64 k_RestPoseDegrees = 3.0;
    protected const float64 k_KneeLeastSwingDegrees = 5.0;
    protected const float64 k_KneeMostSwingDegrees = 70.0;
    protected const float64 k_BelowFloorCm = 2.0;

    protected FVector _CrawlerAt = FVector::ZeroVector;
    protected FCk_Handle_Crawler _Crawler;
    protected FCk_Handle _CrawlerRoot;
    protected FCk_Handle_Monster _CrawlerMonster;
    protected TArray<FCk_Handle_BodyPart> _LegParts;
    protected TArray<FMars_Crawler_LegRig> _LegRigs;
    protected TArray<FMars_NetCrawlerTest_PartSignals> _LegSignals;
    protected int32 _CrawlerDied = 0;
    protected int32 _CrawlerDiedFrame = -1;
    protected int32 _BodyDamaged = 0;
    protected int32 _CrawlerFoundFrame = -1;
    protected EMars_Net_InitialState _RosterInitialAtFind = EMars_Net_InitialState::Awaited;
    // Off authority: each rep-notify of the copy's part ledger, as frame:states.
    protected FString _RosterNotifies = "";

    protected float64 _CrawlerPath = 0.0;
    protected float64 _CrawlerLargestStep = 0.0;
    protected float64 _CrawlerFarthestX = 0.0;
    protected float64 _CrawlerFarthestY = 0.0;
    protected bool _CrawlerGaitEverFailed = false;
    private TOptional<FVector> _CrawlerLastSample;
    private float64 _CrawlerSampleUntil = 0.0;

    // The feet record (Begin_FeetRecord to the row's end).
    protected bool _FeetRecording = false;
    protected TArray<FMars_NetCrawlerTest_FootRecord> _FeetRecords;
    protected float64 _FeetWorstPlanted = 0.0;
    protected int32 _FeetFrames = 0;
    protected int32 _FeetLowestTrusted = -1;

    // The server's hits, or the client's claims, on one leg.
    protected int32 _LegActions = 0;
    // A row's own notes, appended to every log line.
    protected FString _RowExtra = "";

    // Every limb this machine has seen near its base, in the order it first saw them.
    protected TArray<FMars_NetCrawlerTest_LimbRecord> _Limbs;
    // The row this machine follows a leg-0 sever under, and the first frame every captured leg-0 rig part read gone.
    protected FString _LimbRow = "";
    protected int32 _Leg0PartsGoneFrame = -1;

    // A row without the striker: the base, the ensure count, this machine's floor; the crawler at the base.
    protected void Begin_CrawlerRow(FVector InBase)
    {
        _Base = InBase;
        _TargetAt = InBase;
        _CrawlerAt = InBase;
        _EnsuresAtStart = utils_ensure::Get_EnsureCount();
        Spawn_CrawlerFloor();
    }

    // A row with the striker: the crawler placed so that leg 0's rest foot stands k_ClaimedFootFromHand in front of
    // the hand.
    protected void Begin_CrawlerStrikeRow(FVector InBase)
    {
        Begin_Strike(InBase);
        Spawn_CrawlerFloor();
        const auto RestFoot = Get_RestFootLocal(0);
        _CrawlerAt = Get_HandLocation() + FVector(k_ClaimedFootFromHand - RestFoot.X, -RestFoot.Y, 0.0);
        _CrawlerAt.Z = _Base.Z;
        _TargetAt = _CrawlerAt;
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Each machine: the floor. Server: the crawler
    //----------------------------------------------------------------------------------------------------------------------

    // A static Jolt box whose top face is at the base's Z, owned by this machine's subject (it dies with the test).
    private void Spawn_CrawlerFloor()
    {
        auto Subject = Get_SubjectEntity();
        auto Box = utils_entity_lifetime::Request_CreateEntity(Subject);
        utils_transform::Add(Box, FTransform(FRotator::ZeroRotator, _Base - FVector(0.0, 0.0, k_FloorHalfExtents.Z)),
            ECk_Replication::DoesNotReplicate);
        auto Shape = FCk_Jolt_ShapeDimensions(ECk_Jolt_ShapeType::Box);
        Shape.Set_HalfExtents(k_FloorHalfExtents);
        auto BoxSpec = FCk_JoltBody_Spec(ECk_JoltBody_ShapeSource::ExplicitShape);
        BoxSpec.Set_ShapeDimensions(Shape);
        BoxSpec.Set_MotionType(ECk_MotionType::Static);
        BoxSpec.Set_CollisionProfileName(n"BlockAll");
        utils_jolt_body::Add(Box, BoxSpec);
    }

    // 4 legs roaming the box of InRoamHalfExtent around the crawler, dwelling 0.3 s, a severed limb living 8 s, combat
    // off.
    protected FMars_Crawler_Spec Make_RowSpec(FVector InRoamHalfExtent) const
    {
        auto Spec = FMars_Crawler_Spec(k_LegCount, FBox(_CrawlerAt - InRoamHalfExtent, _CrawlerAt + InRoamHalfExtent));
        Spec.RoamDwellSeconds = 0.3f;
        Spec.Vitals.LegDebris.LifetimeSeconds = 8.0f;
        Spec.Combat.Enabled = false;
        return Spec;
    }

    // Where leg InIndex's foot rests in the 4-leg crawler's body frame.
    protected FVector Get_RestFootLocal(int32 InIndex) const
    {
        const auto Spec = FMars_Crawler_Spec(k_LegCount, FBox(FVector::ZeroVector, FVector::OneVector));
        const TArray<FCk_ProceduralLeg_Spec> Legs = Spec.Get_RigData().Get_Legs();
        return Legs[InIndex].Get_Placement().Get_RestFootLocal();
    }

    protected void Spawn_ServerCrawler(FMars_Crawler_Spec InSpec)
    {
        Spawn_ServerCrawlerOfClass(InSpec, UMars_Crawler_EntityScript);
    }

    // The crawler of InClass under the replicated spawn owner, its root 65 above the floor, facing +X, without visuals.
    protected void Spawn_ServerCrawlerOfClass(FMars_Crawler_Spec InSpec, TSubclassOf<UCk_EntityScript_UE> InClass)
    {
        auto Params = UMars_Crawler_EntityScript::Params();
        Params.SpawnTransform = FTransform(FRotator::ZeroRotator, _CrawlerAt + FVector(0.0, 0.0, k_RootOverFloor));
        Params.Spec = InSpec;
        Params.WithVisuals = false;
        utils_entity_script::Request_SpawnEntity(utils_mars_net::Get_ReplicatedSpawnOwner(Get_SubjectEntity()), InClass, Params);
    }

    // Server: a Sever zone hit of InAmount on its copy of part InPart's zone, with no instigator.
    protected void Hit_ServerLeg(int32 InPart, float32 InAmount)
    {
        auto Zone = _LegParts[InPart].Get_Zone();
        Zone.Request_Hit(FMars_Request_HitZone_Hit(FMars_DamageEvent(InAmount, GameplayTags::DamageType_Mars_Sever)));
    }

    // Part InPart's zone address on this machine, the cleaver, the location of this machine's last segment of leg
    // InPart, +X.
    protected FMars_HeldItemUse_Strike Make_LegClaim(int32 InPart)
    {
        const auto Address = _LegParts[InPart].Get_Zone().Get_Address();
        auto Claim = FMars_HeldItemUse_Strike();
        Claim.ZoneRoot = Address.Root;
        Claim.ZoneIndex = Address.Index;
        Claim.Item = utils_held_item::Make_DefinitionSoft(mars_items::Cleaver());
        Claim.Location = Get_LastSegmentLocation(InPart);
        Claim.Normal = FVector(-1.0, 0.0, 0.0);
        Claim.Impulse = FVector::ForwardVector;
        return Claim;
    }

    protected FVector Get_LastSegmentLocation(int32 InLeg) const
    {
        return utils_transform::Get_EntityCurrentLocation(_LegRigs[InLeg].Segments.Last());
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Each machine: its copy
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    protected void Is_CrawlerFound(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsCrawlerFound());
        Sample_Crawler();
    }

    // This machine's copy near the crawler's spot has composed with its four leg parts; the first time, its signals are
    // counted from here (and the server tracks it).
    protected bool Get_IsCrawlerFound()
    {
        if (_LegParts.Num() == k_LegCount)
        { return true; }

        for (auto Candidate : utils_entity_tag::ForEach_Entity(Get_SubjectEntity(), n"TAG_MarsCrawler"))
        {
            if (Get_IsNear(Candidate, _CrawlerAt) == false)
            { continue; }

            auto Crawler = Candidate.As_Crawler(ECk_SanityCheck::UnChecked);
            if (ck::Is_NOT_Valid(Crawler) || Crawler.Get_LegParts().Num() != k_LegCount)
            { continue; }

            Take_Crawler(Candidate, Crawler);
            return true;
        }

        return false;
    }

    private void Take_Crawler(FCk_Handle InRoot, FCk_Handle_Crawler InCrawler)
    {
        _Crawler = InCrawler;
        _CrawlerRoot = InRoot;
        _CrawlerMonster = InCrawler.Get_Monster();
        _Target = InRoot;
        _Health = _CrawlerMonster.Get_BodyHealth();
        _Zone = _CrawlerMonster.Get_BodyZone();
        _LegParts = InCrawler.Get_LegParts();
        _LegSignals.SetNum(_LegParts.Num());
        for (int32 Index = 0; Index < _LegParts.Num(); ++Index)
        {
            _LegRigs.Add(InCrawler.Get_LegRig(Index));
            auto Part = _LegParts[Index];
            Part.BindTo_OnSevered(FMars_Delegate_BodyPart_OnSevered(this, n"OnLegSevered"));
        }

        _CrawlerMonster.BindTo_OnDied(FMars_Delegate_Monster_OnDied(this, n"OnCrawlerDied"));
        _Health.BindTo_OnDamaged(FMars_Delegate_Health_OnDamaged(this, n"OnCrawlerBodyDamaged"));
        _CrawlerFoundFrame = int32(utils_time::Get_FrameCounter());
        _RosterInitialAtFind = Get_RosterInitialState();
        if (Get_IsServer())
        { Track_ForCleanup(InRoot); }
        else
        { _CrawlerRoot.BindTo_OnRepNotify(FMars_Fragment_BodyPart_Net, FCk_DynamicFragment_OnRepNotify(this, n"OnRosterLedgerNotify")); }
    }

    protected bool Get_IsCrawlerGone()
    {
        FCk_Handle Entity = _Crawler;
        return ck::Is_NOT_Valid(Entity) || utils_entity_lifetime::Get_IsPendingDestroy(Entity, ECk_EntityLifetime_DestructionPhase::BeginDestroy);
    }

    // Found, its gait Ready and its four parts registered (a failed gait is sampled, not waited out).
    UFUNCTION()
    protected void Is_CrawlerSettled(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        Sample_Crawler();
        auto Result = OutResult;
        Result.Set(Get_IsCrawlerFound() && Get_IsCrawlerGone() == false
            && Get_GaitStatus() == ECk_ProceduralAnimation_Status::Ready
            && _CrawlerMonster.Get_Parts().Num() == k_LegCount);
    }

    UFUNCTION()
    protected void Is_CrawlerGone(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsCrawlerGone());
    }

    UFUNCTION()
    protected void Is_CrawlerDead(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        Sample_Crawler();
        auto Result = OutResult;
        Result.Set(Get_IsCrawlerFound() && Get_IsCrawlerGone() == false && _CrawlerMonster.Get_IsDead());
    }

    UFUNCTION()
    protected void Is_Leg0Severed(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        Sample_Crawler();
        auto Result = OutResult;
        Result.Set(Get_IsCrawlerFound() && Get_IsPartState(0, EMars_BodyPart_State::Severed));
    }

    // No limb is near the base on this machine.
    UFUNCTION()
    protected void Is_SeveredLimbsGone(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        Sample_Crawler();
        auto Result = OutResult;
        Result.Set(Get_HasSeveredLimbLeft() == false);
    }

    protected bool Get_HasSeveredLimbLeft()
    {
        return Get_LimbsNear().Num() > 0;
    }

    // Every rig part of every leg is gone on this machine.
    UFUNCTION()
    protected void Is_EveryRigPartGone(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        auto Valid = 0;
        for (int32 Index = 0; Index < _LegRigs.Num(); ++Index)
        { Valid += Get_ValidRigParts(Index); }

        Result.Set(Valid == 0);
    }

    // A wall-clock settle that keeps sampling the copy every frame, then InContinuation.
    protected void WaitSampling(float32 InSeconds, FName InContinuation)
    {
        _CrawlerSampleUntil = Get_WorldSeconds() + InSeconds;
        WaitUntil(n"Is_CrawlerSampledLongEnough", InContinuation, k_SlowPolls);
    }

    UFUNCTION()
    protected void Is_CrawlerSampledLongEnough(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        Sample_Crawler();
        auto Result = OutResult;
        Result.Set(Get_WorldSeconds() >= _CrawlerSampleUntil);
    }

    protected float64 Get_WorldSeconds()
    {
        const auto SubjectWorld = utils_entity_lifetime::Get_WorldForEntity(Get_SubjectEntity());
        return float64(SubjectWorld.GetTimeSeconds());
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Client: a sever of leg 0 reaching its copy
    //----------------------------------------------------------------------------------------------------------------------

    protected FString _SeverRow = "";
    protected int32 _ClientSeveredFrame = -1;
    // The row's sever spilled into the body: the copy's body Health raised OnDamaged.
    protected bool _ExpectBodySpill = false;

    // Once its part 0 reads Severed: within ten frames of its OnSevered leg 0 left its copy, raising OnSevered once with
    // its zone off, and every captured leg-0 rig part is gone (no local limb); a second later the other legs walk on and
    // exactly one limb is near, not this machine's; then the client's rest asserts, and the row finishes once no limb is
    // left.
    protected void Follow_ClientLeg0Sever(FString InRow)
    {
        _SeverRow = InRow;
        _LimbRow = InRow;
        WaitUntil(n"Is_Leg0Severed", n"OnClientLeg0Severed", k_SlowPolls);
    }

    UFUNCTION()
    private void OnClientLeg0Severed(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _ClientSeveredFrame = int32(utils_time::Get_FrameCounter());
        WaitUntil(n"Is_TenFramesSinceLeg0Severed", n"OnClientLeg0TenFrames", k_SlowPolls);
    }

    UFUNCTION()
    private void OnClientLeg0TenFrames(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_Equals_Int(_LegSignals[0].Severed, 1, "the client's part 0 raised OnSevered once");
        Assert_False(Get_IsLegAttached(0), "the client's leg 0 is not attached");
        Assert_False(Get_IsPartZoneEnabled(0), "the client's part 0 zone is disabled");
        Assert_Leg0PartsGoneInTenFrames();
        WaitSampling(k_SettleSeconds, n"OnClientLeg0Settled");
    }

    UFUNCTION()
    private void OnClientLeg0Settled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        for (int32 Index = 1; Index < k_LegCount; ++Index)
        { Assert_True(Get_IsLegAttached(Index), f"the client's leg {Index} is attached"); }

        Assert_True(Get_GaitStatus() == ECk_ProceduralAnimation_Status::Ready, "the client's gait reads Ready");
        Assert_False(_CrawlerGaitEverFailed, "the client's gait never read Failed");
        Assert_True(Get_BodyPoseStatus() == ECk_ProceduralAnimation_Status::Ready, "the client's body pose reads Ready");
        Assert_True(Get_Trusted() >= 1, f"the client's gait trusts a contact (reads {Get_Trusted()})");
        if (_ExpectBodySpill)
        { Assert_True(_BodyDamaged >= 1, f"the client's body Health raised OnDamaged (the spill) ({_BodyDamaged})"); }

        Assert_OneCopyLimb(Get_RigParts(0).Num());
        Log_CrawlerRow(_SeverRow, f"settled severedFrame={_ClientSeveredFrame}");
        Await_ClientLimbRest(n"OnClientLeg0LimbGone");
    }

    UFUNCTION()
    private void OnClientLeg0LimbGone(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Finish_CrawlerRow(_SeverRow, f"severedFrame={_ClientSeveredFrame}");
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Server: its leg-0 sever and the one limb it spawns
    //----------------------------------------------------------------------------------------------------------------------

    // From the sever on: within ten frames of OnSevered every captured leg-0 rig part is gone; a second later exactly one
    // limb is near, with authority, a body per piece and every joint added, and leg 0's entity is valid and detached with
    // its part Severed. Once the limb reads at rest (the sampler publishes its rest pose), the server waits until it is
    // gone: its widest joint gap stayed within k_AuthorityGapCm and it lived between 7.5 and 9 s. The row's own tail
    // (Assert_ServerLimbTail) runs, and the row holds.
    protected void Follow_ServerLeg0Limb(FString InRow)
    {
        _LimbRow = InRow;
        WaitUntil(n"Is_TenFramesSinceLeg0Severed", n"OnServerLeg0TenFrames", k_SlowPolls);
    }

    // A row's own asserts once the server's limb is gone.
    protected void Assert_ServerLimbTail() {}

    UFUNCTION()
    private void OnServerLeg0TenFrames(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_Leg0PartsGoneInTenFrames();
        WaitSampling(k_SettleSeconds, n"OnServerLeg0LimbSecond");
    }

    UFUNCTION()
    private void OnServerLeg0LimbSecond(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_OneAuthorityLimb();
        FCk_Handle Leg = _LegParts[0].Get_Leg();
        Assert_True(ck::IsValid(Leg), "the server's leg 0 entity is still valid");
        Assert_False(Get_IsLegAttached(0), "the server's leg 0 is not attached");
        Assert_True(Get_IsPartState(0, EMars_BodyPart_State::Severed), "the server's part 0 is Severed");
        WaitUntil(n"Is_EveryLimbAtRest", n"OnServerLeg0LimbAtRest", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerLeg0LimbAtRest(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Log_CrawlerRow(_LimbRow, "limbAtRest");
        WaitUntil(n"Is_SeveredLimbsGone", n"OnServerLeg0LimbGone", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerLeg0LimbGone(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Sample_Limbs();
        if (_Limbs.Num() > 0)
        {
            const auto Record = _Limbs[0];
            Assert_True(Record.WidestGap <= k_AuthorityGapCm, f"the server's limb's widest joint gap {Record.WidestGap} is at most {k_AuthorityGapCm}");
            const auto Lived = Record.GoneSeconds - Record.FirstSeconds;
            Assert_True(Lived >= 7.5 && Lived <= 9.0, f"the server's limb lived {Lived} s (7.5 to 9)");
        }

        Assert_ServerLimbTail();
        Hold_CrawlerServerRow(_LimbRow, "");
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Limbs
    //----------------------------------------------------------------------------------------------------------------------

    // Every valid limb within k_LimbNearCm of the base (horizontally), not pending destroy.
    protected TArray<FCk_Handle> Get_LimbsNear()
    {
        auto Limbs = TArray<FCk_Handle>();
        for (auto Candidate : utils_entity_tag::ForEach_Entity(Get_SubjectEntity(), n"TAG_MarsSeveredLimb"))
        {
            if (ck::Is_NOT_Valid(Candidate) || utils_entity_lifetime::Get_IsPendingDestroy(Candidate, ECk_EntityLifetime_DestructionPhase::BeginDestroy))
            { continue; }

            const auto Transform = Candidate.As_Transform(ECk_SanityCheck::UnChecked);
            if (ck::Is_NOT_Valid(Transform))
            { continue; }

            auto Offset = utils_transform::Get_EntityCurrentLocation(Transform) - _Base;
            Offset.Z = 0.0;
            if (Offset.Size() < k_LimbNearCm)
            { Limbs.Add(Candidate); }
        }

        return Limbs;
    }

    // The limb's pieces, in chain order; none before it composed.
    protected TArray<FCk_Handle_Transform> Get_LimbPieces(FCk_Handle InLimb)
    {
        const auto Limb = InLimb.As_SeveredLimb(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(Limb))
        { return TArray<FCk_Handle_Transform>(); }

        return Limb.Get_Pieces();
    }

    // Every joint's gap that both pieces can still be read for.
    protected TArray<float64> Get_LimbJointGaps(FCk_Handle InLimb)
    {
        auto Gaps = TArray<float64>();
        const auto Limb = InLimb.As_SeveredLimb(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(Limb))
        { return Gaps; }

        for (int32 Index = 0; Index < Limb.Get_JointCount(); ++Index)
        {
            const auto Gap = Limb.Get_JointGap(Index);
            if (Gap >= 0.0)
            { Gaps.Add(Gap); }
        }

        return Gaps;
    }

    protected bool Get_LimbIsAtRest(FCk_Handle InLimb)
    {
        const auto Limb = InLimb.As_SeveredLimb(ECk_SanityCheck::UnChecked);
        return ck::IsValid(Limb) && Limb.Get_IsAtRest();
    }

    // How far the kernel raised the limb at its birth (cm); -1 for an invalid limb.
    protected float64 Get_LimbBirthLift(FCk_Handle InLimb)
    {
        const auto Limb = InLimb.As_SeveredLimb(ECk_SanityCheck::UnChecked);
        return ck::IsValid(Limb) ? Limb.Get_BirthLift() : -1.0;
    }

    // The authority's joints (none on a copy), and how many read added.
    protected int32 Get_LimbJoints(FCk_Handle InLimb)
    {
        const auto Limb = InLimb.As_SeveredLimb(ECk_SanityCheck::UnChecked);
        return ck::IsValid(Limb) ? Limb.Get_Joints().Num() : 0;
    }

    protected int32 Get_LimbJointsAdded(FCk_Handle InLimb)
    {
        const auto Limb = InLimb.As_SeveredLimb(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(Limb))
        { return 0; }

        auto Added = 0;
        for (auto Joint : Limb.Get_Joints())
        {
            if (ck::IsValid(Joint) && utils_jolt_constraint::Get_IsConstraintAdded(Joint))
            { Added += 1; }
        }

        return Added;
    }

    // Off authority: counts the limb's ledger notifies into its record.
    protected void Bind_LimbLedger(FCk_Handle InLimb)
    {
        auto Limb = InLimb;
        Limb.BindTo_OnRepNotify(FMars_Fragment_SeveredLimb_Net, FCk_DynamicFragment_OnRepNotify(this, n"OnLimbLedgerNotify"));
    }

    // Whether the limb's ledger stood when this machine composed it, or arrived after.
    protected FString Get_LimbLedgerInitial(FCk_Handle InLimb)
    {
        if (InLimb.Has_Fragment(FMars_Fragment_SeveredLimb_Local) == false)
        { return "uncomposed"; }

        return InLimb.Get_Fragment(FMars_Fragment_SeveredLimb_Local).InitialState == EMars_Net_InitialState::Taken ? "stood" : "arrived";
    }

    // A notify can land on a limb already ending.
    UFUNCTION()
    private void OnLimbLedgerNotify(FCk_Handle InHandle, FCk_DynamicFragment_RepNotifyInfo InInfo)
    {
        const auto Index = Find_LimbRecord(InHandle);
        if (Index < 0 || ck::Is_NOT_Valid(InHandle) || InHandle.Has_Fragment(FMars_Fragment_SeveredLimb_Net) == false)
        { return; }

        auto& Record = _Limbs[Index];
        Record.Notifies += 1;
        if (Record.NotifiesBeforeRest < 0 && InHandle.Get_Fragment(FMars_Fragment_SeveredLimb_Net).AtRest)
        { Record.NotifiesBeforeRest = Record.Notifies - 1; }
    }

    protected int32 Get_LimbBodies(FCk_Handle InLimb)
    {
        auto Bodies = 0;
        for (auto Piece : Get_LimbPieces(InLimb))
        {
            FCk_Handle Entity = Piece;
            if (ck::IsValid(Entity.As_JoltBody(ECk_SanityCheck::UnChecked)))
            { Bodies += 1; }
        }

        return Bodies;
    }

    // Each knee's angle (between two neighbouring segments' X axes; the foot is not a segment), from the transforms.
    protected TArray<float64> Get_LimbKneeAngles(FCk_Handle InLimb)
    {
        const auto Pieces = Get_LimbPieces(InLimb);
        auto Angles = TArray<float64>();
        for (int32 Index = 0; Index + 2 < Pieces.Num(); ++Index)
        {
            const auto Upper = utils_transform::Get_EntityCurrentTransform(Pieces[Index]).GetRotation().GetAxisX();
            const auto Lower = utils_transform::Get_EntityCurrentTransform(Pieces[Index + 1]).GetRotation().GetAxisX();
            Angles.Add(Math::RadiansToDegrees(Math::Acos(Math::Clamp(Upper.DotProduct(Lower), -1.0, 1.0))));
        }

        return Angles;
    }

    protected int32 Find_LimbRecord(FCk_Handle InLimb) const
    {
        for (int32 Index = 0; Index < _Limbs.Num(); ++Index)
        {
            if (_Limbs[Index].Limb == InLimb)
            { return Index; }
        }

        return -1;
    }

    // One sample of every limb near the base: a new one gets its record (off authority its ledger is bound), each is
    // measured, one that left is stamped gone. The server publishes a limb's rest pose the first time it reads at rest.
    protected void Sample_Limbs()
    {
        if (_LegRigs.Num() > 0 && _LegSignals.Num() > 0 && _LegSignals[0].Severed > 0 && _Leg0PartsGoneFrame < 0 && Get_ValidRigParts(0) == 0)
        { _Leg0PartsGoneFrame = int32(utils_time::Get_FrameCounter()); }

        for (auto Limb : Get_LimbsNear())
        {
            auto Index = Find_LimbRecord(Limb);
            if (Index < 0)
            {
                auto Record = FMars_NetCrawlerTest_LimbRecord();
                Record.Limb = Limb;
                Record.FirstFrame = int32(utils_time::Get_FrameCounter());
                Record.FirstSeconds = Get_WorldSeconds();
                if (utils_net::Get_HasAuthority(Limb) == false)
                { Record.LedgerInitial = Get_LimbLedgerInitial(Limb); }

                _Limbs.Add(Record);
                Index = _Limbs.Num() - 1;
                if (utils_net::Get_HasAuthority(Limb) == false)
                { Bind_LimbLedger(Limb); }
            }

            Sample_Limb(Index);
        }

        for (int32 Index = 0; Index < _Limbs.Num(); ++Index)
        {
            auto& Record = _Limbs[Index];
            if (Record.GoneSeconds >= 0.0)
            { continue; }

            if (ck::Is_NOT_Valid(Record.Limb) || utils_entity_lifetime::Get_IsPendingDestroy(Record.Limb, ECk_EntityLifetime_DestructionPhase::BeginDestroy))
            { Record.GoneSeconds = Get_WorldSeconds(); }
        }
    }

    private void Sample_Limb(int32 InIndex)
    {
        const auto Limb = _Limbs[InIndex].Limb;
        const auto Gaps = Get_LimbJointGaps(Limb);
        const auto Knees = Get_LimbKneeAngles(Limb);
        const auto Pieces = Get_LimbPieces(Limb);
        const auto AtRest = Get_LimbIsAtRest(Limb);

        auto& Record = _Limbs[InIndex];
        for (auto Gap : Gaps)
        { Record.WidestGap = Math::Max(Record.WidestGap, Gap); }

        if (Record.KneeStart.Num() == 0)
        {
            Record.KneeStart = Knees;
            Record.KneeSwing.SetNum(Knees.Num());
        }

        for (int32 Index = 0; Index < Knees.Num() && Index < Record.KneeStart.Num(); ++Index)
        { Record.KneeSwing[Index] = Math::Max(Record.KneeSwing[Index], Math::Abs(Knees[Index] - Record.KneeStart[Index])); }

        if (Pieces.Num() > 0)
        {
            const auto FirstPiece = utils_transform::Get_EntityCurrentLocation(Pieces[0]);
            if (Record.FirstPieceStart.IsZero())
            { Record.FirstPieceStart = FirstPiece; }

            Record.FirstPieceLast = FirstPiece;
        }

        if (Record.ContactsBound == false && utils_net::Get_HasAuthority(Limb) && Pieces.Num() > 0 && Get_LimbBodies(Limb) == Pieces.Num())
        {
            Record.ContactsBound = true;
            for (auto Piece : Pieces)
            {
                FCk_Handle Entity = Piece;
                auto Body = Entity.As_JoltBody(ECk_SanityCheck::UnChecked);
                utils_jolt_body::BindTo_OnJoltBodyContactAdded(Body, FCk_Delegate_JoltBody_OnContact(this, n"OnLimbPieceContact"));
            }
        }

        if (Record.RestFrame >= 0 || AtRest == false)
        { return; }

        Record.RestFrame = int32(utils_time::Get_FrameCounter());
        Record.RestSeconds = Get_WorldSeconds();
        if (Get_IsServer())
        { Publish_RestPose(Limb); }
    }

    UFUNCTION()
    private void OnLimbPieceContact(FCk_Handle_JoltBody InBody, FCk_JoltBody_Payload_OnContact InPayload)
    {
        FCk_Handle BodyEntity = InBody;
        const FCk_Handle OtherEntity = InPayload.Get_OtherEntity();
        for (int32 RecordIndex = 0; RecordIndex < _Limbs.Num(); ++RecordIndex)
        {
            const auto Pieces = Get_LimbPieces(_Limbs[RecordIndex].Limb);
            auto Mine = -1;
            auto Other = -1;
            for (int32 Index = 0; Index < Pieces.Num(); ++Index)
            {
                FCk_Handle Entity = Pieces[Index];
                if (Entity == BodyEntity)
                { Mine = Index; }
                if (Entity == OtherEntity)
                { Other = Index; }
            }

            if (Mine < 0 || Other < 0)
            { continue; }

            _Limbs[RecordIndex].NeighbourContacts += 1;
            return;
        }
    }

    // Server: the readout on the limb's root, its pieces' world poses now.
    private void Publish_RestPose(FCk_Handle InLimb)
    {
        auto Limb = InLimb;
        if (Limb.Has_Fragment(FMars_TESTONLY_Fragment_SeveredLimb_RestPose))
        { return; }

        auto Readout = FMars_TESTONLY_Fragment_SeveredLimb_RestPose();
        for (auto Piece : Get_LimbPieces(Limb))
        { Readout.Pieces.Add(utils_transform::Get_EntityCurrentTransform(Piece)); }

        Limb.Add_Fragment(Readout, ECk_Replication::Replicates);
    }

    protected bool Get_HasPublishedRestPose(FCk_Handle InLimb)
    {
        return ck::IsValid(InLimb) && InLimb.Has_Fragment(FMars_TESTONLY_Fragment_SeveredLimb_RestPose)
            && InLimb.Get_Fragment(FMars_TESTONLY_Fragment_SeveredLimb_RestPose).Pieces.Num() > 0;
    }

    // Within ten frames of this machine's OnSevered every captured leg-0 rig part was invalid or pending destroy.
    protected void Assert_Leg0PartsGoneInTenFrames()
    {
        const auto Severed = _LegSignals[0].Frame;
        Assert_True(_Leg0PartsGoneFrame >= 0 && _Leg0PartsGoneFrame - Severed <= 10,
            f"every captured leg-0 rig part on the {Get_MachineName()} is gone within ten frames of OnSevered (severed {Severed}, gone {_Leg0PartsGoneFrame}, valid now {Get_ValidRigParts(0)})");
    }

    // Exactly one limb near the base, with authority, a Jolt body on every piece and every joint added.
    protected void Assert_OneAuthorityLimb()
    {
        const auto Limbs = Get_LimbsNear();
        Assert_Equals_Int(Limbs.Num(), 1, "exactly one limb (TAG_MarsSeveredLimb) is near the server's base");
        if (Limbs.Num() != 1)
        { return; }

        const auto Limb = Limbs[0];
        const auto Pieces = Get_LimbPieces(Limb).Num();
        Assert_True(utils_net::Get_HasAuthority(Limb), "the server's limb has authority");
        Assert_Equals_Int(Get_LimbBodies(Limb), Pieces, "every piece of the server's limb carries a Jolt body");
        Assert_Equals_Int(Get_LimbJointsAdded(Limb), Pieces - 1, "every joint of the server's limb is added");
    }

    // Exactly one limb near the base, without authority, InPieces pieces, no piece with a Jolt body and no joint.
    protected void Assert_OneCopyLimb(int32 InPieces)
    {
        const auto Limbs = Get_LimbsNear();
        Assert_Equals_Int(Limbs.Num(), 1, "exactly one limb (TAG_MarsSeveredLimb) is near the client's base");
        if (Limbs.Num() != 1)
        { return; }

        const auto Limb = Limbs[0];
        Assert_False(utils_net::Get_HasAuthority(Limb), "the client's limb has no authority");
        Assert_Equals_Int(Get_LimbPieces(Limb).Num(), InPieces, "the client's limb has the authority's pieces");
        Assert_Equals_Int(Get_LimbBodies(Limb), 0, "no piece of the client's limb carries a Jolt body");
        Assert_Equals_Int(Get_LimbJoints(Limb), 0, "the client's limb has no joint");
    }

    // Every limb near the base reads at rest (and there is one).
    UFUNCTION()
    protected void Is_EveryLimbAtRest(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        Sample_Crawler();
        const auto Limbs = Get_LimbsNear();
        auto AtRest = Limbs.Num() > 0;
        for (auto Limb : Limbs)
        { AtRest = AtRest && Get_LimbIsAtRest(Limb); }

        auto Result = OutResult;
        Result.Set(AtRest);
    }

    UFUNCTION()
    protected void Is_TenFramesSinceLeg0Severed(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        Sample_Crawler();
        auto Result = OutResult;
        Result.Set(_LegSignals[0].Frame >= 0 && int32(utils_time::Get_FrameCounter()) >= _LegSignals[0].Frame + 10);
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Client: its limb at rest against the published one
    //----------------------------------------------------------------------------------------------------------------------

    private FName _AfterClientLimbRest;

    // Once the server published its limb's rest pose and this copy's limb reads at rest: every piece within k_RestPoseCm
    // and k_RestPoseDegrees of the published pose and not more than k_BelowFloorCm below the floor, every joint gap within
    // k_CopyGapCm; again 0.5 s later; then InContinuation once no limb is near.
    protected void Await_ClientLimbRest(FName InContinuation)
    {
        _AfterClientLimbRest = InContinuation;
        WaitUntil(n"Is_ClientLimbRestReady", n"OnClientLimbRestReady", k_SlowPolls);
    }

    UFUNCTION()
    protected void Is_ClientLimbRestReady(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        Sample_Crawler();
        const auto Limbs = Get_LimbsNear();
        auto Result = OutResult;
        Result.Set(Limbs.Num() == 1 && Get_HasPublishedRestPose(Limbs[0]) && Get_LimbIsAtRest(Limbs[0]));
    }

    UFUNCTION()
    private void OnClientLimbRestReady(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_ClientLimbAtRest("at rest");
        WaitSampling(0.5f, n"OnClientLimbRestHeld");
    }

    UFUNCTION()
    private void OnClientLimbRestHeld(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_ClientLimbAtRest("0.5 s later");
        Log_CrawlerRow(_LimbRow, "limbAtRest");
        WaitUntil(n"Is_SeveredLimbsGone", _AfterClientLimbRest, k_SlowPolls);
    }

    protected void Assert_ClientLimbAtRest(FString InWhen)
    {
        const auto Limbs = Get_LimbsNear();
        if (Limbs.Num() != 1)
        {
            Assert_Equals_Int(Limbs.Num(), 1, f"one limb is near the client's base {InWhen}");
            return;
        }

        const auto Limb = Limbs[0];
        const auto Pieces = Get_LimbPieces(Limb);
        const auto Published = Limb.Get_Fragment(FMars_TESTONLY_Fragment_SeveredLimb_RestPose).Pieces;
        Assert_Equals_Int(Pieces.Num(), Published.Num(), f"the client's limb has the published piece count {InWhen}");
        for (int32 Index = 0; Index < Pieces.Num() && Index < Published.Num(); ++Index)
        {
            const auto Mine = utils_transform::Get_EntityCurrentTransform(Pieces[Index]);
            const auto Distance = (Mine.GetLocation() - Published[Index].GetLocation()).Size();
            const auto Degrees = Math::RadiansToDegrees(Mine.GetRotation().AngularDistance(Published[Index].GetRotation()));
            Assert_True(Distance <= k_RestPoseCm && Degrees <= k_RestPoseDegrees,
                f"the client's piece {Index} is {Distance} cm and {Degrees} deg from the server's rest pose {InWhen}");
            Assert_True(Mine.GetLocation().Z >= _Base.Z - k_BelowFloorCm,
                f"the client's piece {Index} is not below the floor ({Mine.GetLocation().Z - _Base.Z}) {InWhen}");
        }

        const auto Gaps = Get_LimbJointGaps(Limb);
        for (int32 Index = 0; Index < Gaps.Num(); ++Index)
        { Assert_True(Gaps[Index] <= k_CopyGapCm, f"the client's joint {Index} gap {Gaps[Index]} is at most {k_CopyGapCm} {InWhen}"); }
    }

    // Every limb this machine saw, one line each: authority / bodies / joints / widest gap / knee start and swing / birth
    // lift / same-limb contacts / at rest / piece poses, and the published rest pose.
    protected FString Describe_Limbs()
    {
        FString Text = f"leg0PartsGone={_Leg0PartsGoneFrame} ";
        for (const auto& Record : _Limbs)
        {
            const auto Limb = Record.Limb;
            FString Knees = "";
            for (int32 Index = 0; Index < Record.KneeStart.Num() && Index < Record.KneeSwing.Num(); ++Index)
            { Knees += f"{Record.KneeStart[Index]}/{Record.KneeSwing[Index]},"; }

            const auto Moved = (Record.FirstPieceLast - Record.FirstPieceStart).Size();
            Text += f"[limb first={Record.FirstFrame}@{Record.FirstSeconds} gone={Record.GoneSeconds} widestGap={Record.WidestGap} knees(start/swing)={Knees} firstPieceMoved={Moved} rest={Record.RestFrame}@{Record.RestSeconds} notifies={Record.Notifies} beforeRest={Record.NotifiesBeforeRest} ledger={Record.LedgerInitial} contacts={Record.NeighbourContacts}";
            if (ck::IsValid(Limb) && utils_entity_lifetime::Get_IsPendingDestroy(Limb, ECk_EntityLifetime_DestructionPhase::BeginDestroy) == false)
            {
                FString Poses = "";
                for (auto Piece : Get_LimbPieces(Limb))
                {
                    const auto Pose = utils_transform::Get_EntityCurrentTransform(Piece);
                    Poses += f"({Pose.GetLocation()}|{Pose.GetRotation().Rotator()})";
                }

                FString Gaps = "";
                for (auto Gap : Get_LimbJointGaps(Limb))
                { Gaps += f"{Gap},"; }

                Text += f" auth={utils_net::Get_HasAuthority(Limb)} bodies={Get_LimbBodies(Limb)} joints={Get_LimbJointsAdded(Limb)}/{Get_LimbJoints(Limb)} lift={Get_LimbBirthLift(Limb)} gaps={Gaps} atRest={Get_LimbIsAtRest(Limb)} poses={Poses}";
                if (Get_HasPublishedRestPose(Limb))
                {
                    FString Published = "";
                    for (const auto& Pose : Limb.Get_Fragment(FMars_TESTONLY_Fragment_SeveredLimb_RestPose).Pieces)
                    { Published += f"({Pose.GetLocation()}|{Pose.GetRotation().Rotator()})"; }

                    Text += f" published={Published}";
                }
            }

            Text += "] ";
        }

        return Text;
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Readers
    //----------------------------------------------------------------------------------------------------------------------

    protected ECk_ProceduralAnimation_Status Get_GaitStatus()
    {
        if (Get_IsCrawlerGone())
        { return ECk_ProceduralAnimation_Status::Failed; }

        return utils_procedural_gait::Get_Status(_Crawler.Get_Gait());
    }

    protected ECk_ProceduralAnimation_Status Get_BodyPoseStatus()
    {
        if (Get_IsCrawlerGone())
        { return ECk_ProceduralAnimation_Status::Failed; }

        return utils_procedural_body_pose::Get_Status(_Crawler.Get_BodyPose());
    }

    protected int32 Get_Trusted()
    {
        if (Get_IsCrawlerGone() || ck::Is_NOT_Valid(_Crawler.Get_Gait()))
        { return -1; }

        return utils_procedural_gait::Get_TrustedContactCount(_Crawler.Get_Gait());
    }

    protected bool Get_IsPartState(int32 InPart, EMars_BodyPart_State InState)
    {
        return _LegParts.IsValidIndex(InPart) && ck::IsValid(_LegParts[InPart]) && _LegParts[InPart].Get_State() == InState;
    }

    protected bool Get_IsLegAttached(int32 InLeg)
    {
        return _LegParts.IsValidIndex(InLeg) && ck::IsValid(_LegParts[InLeg])
            && utils_procedural_leg::Get_IsAttached(_LegParts[InLeg].Get_Leg());
    }

    protected int32 Get_AttachedLegs()
    {
        auto Count = 0;
        for (int32 Index = 0; Index < _LegParts.Num(); ++Index)
        {
            if (Get_IsLegAttached(Index))
            { Count += 1; }
        }

        return Count;
    }

    protected bool Get_IsPartZoneEnabled(int32 InPart)
    {
        return ck::IsValid(_LegParts[InPart]) && _LegParts[InPart].Get_Zone().Get_IsEnabled();
    }

    // Leg InLeg's rig parts as captured at the find: segments, then the foot.
    protected TArray<FCk_Handle_Transform> Get_RigParts(int32 InLeg) const
    {
        auto Parts = _LegRigs[InLeg].Segments;
        Parts.Add(_LegRigs[InLeg].Foot);
        return Parts;
    }

    protected int32 Get_ValidRigParts(int32 InLeg)
    {
        auto Count = 0;
        for (auto Part : Get_RigParts(InLeg))
        {
            FCk_Handle Entity = Part;
            if (ck::IsValid(Entity) && utils_entity_lifetime::Get_IsPendingDestroy(Entity, ECk_EntityLifetime_DestructionPhase::BeginDestroy) == false)
            { Count += 1; }
        }

        return Count;
    }

    // This machine's roster's level now; Awaited while there is none.
    protected EMars_Net_InitialState Get_RosterInitialState()
    {
        if (ck::Is_NOT_Valid(_CrawlerRoot) || _CrawlerRoot.Has_Fragment(FMars_Fragment_BodyPart_Roster) == false)
        { return EMars_Net_InitialState::Awaited; }

        return _CrawlerRoot.Get_Fragment(FMars_Fragment_BodyPart_Roster).InitialState;
    }

    protected FVector Get_RootLocation()
    {
        return utils_transform::Get_EntityCurrentLocation(_Crawler.As_Transform());
    }

    // One sample of this machine's copy: the root's step, path and offset from the base, the gait and, while recording,
    // the feet. Quiet once the copy is gone.
    protected void Sample_Crawler()
    {
        Sample_Limbs();
        if (Get_IsCrawlerGone())
        { return; }

        const auto Here = Get_RootLocation();
        if (_CrawlerLastSample.IsSet())
        {
            const auto Step = (Here - _CrawlerLastSample.GetValue()).Size();
            _CrawlerPath += Step;
            _CrawlerLargestStep = Math::Max(_CrawlerLargestStep, Step);
        }

        _CrawlerLastSample = Here;
        _CrawlerFarthestX = Math::Max(_CrawlerFarthestX, Math::Abs(Here.X - _CrawlerAt.X));
        _CrawlerFarthestY = Math::Max(_CrawlerFarthestY, Math::Abs(Here.Y - _CrawlerAt.Y));
        _CrawlerGaitEverFailed = _CrawlerGaitEverFailed || Get_GaitStatus() == ECk_ProceduralAnimation_Status::Failed;

        if (_FeetRecording)
        { Sample_Feet(); }
    }

    //----------------------------------------------------------------------------------------------------------------------
    // The feet
    //----------------------------------------------------------------------------------------------------------------------

    protected void Begin_FeetRecord()
    {
        _FeetRecording = true;
        _FeetRecords.Reset();
        for (int32 Index = 0; Index < k_LegCount; ++Index)
        { _FeetRecords.Add(FMars_NetCrawlerTest_FootRecord()); }
    }

    private void Sample_Feet()
    {
        for (int32 Index = 0; Index < _LegParts.Num() && Index < _FeetRecords.Num(); ++Index)
        {
            if (Get_IsLegAttached(Index) == false)
            { continue; }

            const auto Foot = utils_procedural_leg::Get_Foot(_LegParts[Index].Get_Leg());
            const auto Lift = Foot.Get_Position().Z - _Base.Z;
            auto& Record = _FeetRecords[Index];
            Record.HighestLift = Math::Max(Record.HighestLift, Lift);
            if (Foot.Get_Phase() == ECk_ProceduralLeg_FootPhase::Planted)
            {
                _FeetWorstPlanted = Math::Max(_FeetWorstPlanted, Math::Abs(Lift));
                Record.PlantedAgain = Record.PlantedAgain || Record.Lifted;
            }
            else
            { Record.Lifted = true; }
        }

        ++_FeetFrames;
        const auto Trusted = Get_Trusted();
        if (_FeetLowestTrusted < 0 || Trusted < _FeetLowestTrusted)
        { _FeetLowestTrusted = Trusted; }
    }

    // Every foot lifted more than InLift over the floor and was seen planted again.
    protected bool Get_HaveAllFeetStepped(float64 InLift) const
    {
        if (_FeetRecords.Num() != k_LegCount)
        { return false; }

        for (const auto& Record : _FeetRecords)
        {
            if (Record.HighestLift <= InLift || Record.PlantedAgain == false)
            { return false; }
        }

        return true;
    }

    protected FString Describe_Feet() const
    {
        FString Lifts = "";
        for (const auto& Record : _FeetRecords)
        { Lifts += f"{Record.HighestLift}/{Record.Lifted}/{Record.PlantedAgain},"; }

        return f"feet=[frames {_FeetFrames} lifts {Lifts} worstPlanted {_FeetWorstPlanted} lowestTrusted {_FeetLowestTrusted}]";
    }

    //----------------------------------------------------------------------------------------------------------------------
    // The log line
    //----------------------------------------------------------------------------------------------------------------------

    protected FString Describe_Composed()
    {
        if (Get_IsCrawlerGone())
        { return "gone"; }

        const auto Motion = ck::IsValid(_Crawler.Get_Motion());
        const auto Navigator = ck::IsValid(_Crawler.Get_Navigator());
        const auto Brain = ck::IsValid(_CrawlerRoot.As_Brain(ECk_SanityCheck::UnChecked));
        const auto Machine = ck::IsValid(_CrawlerRoot.As_StateMachine(ECk_SanityCheck::UnChecked));
        const auto Interpolated = utils_transform_interpolation::Has(_CrawlerRoot);
        return f"motion {Motion} navigator {Navigator} brain {Brain} sm {Machine} armed {_Crawler.Get_IsCombatArmed()} interpolation {Interpolated}";
    }

    protected FString Describe_Legs()
    {
        FString Text = "";
        for (int32 Index = 0; Index < _LegParts.Num(); ++Index)
        {
            const auto Part = _LegParts[Index];
            const auto Signals = _LegSignals[Index];
            const auto State = ck::IsValid(Part) ? f"{Part.Get_State() :n}" : FString("invalid");
            const auto ZoneEnabled = ck::IsValid(Part) && Get_IsPartZoneEnabled(Index);
            Text += f"[{Index} {State} attached={Get_IsLegAttached(Index)} zone={ZoneEnabled} severed={Signals.Severed} released={Signals.Released} frame={Signals.Frame} rig={Describe_RigParts(Index)}] ";
        }

        return Text;
    }

    // Leg InLeg's captured rig parts: how many are valid, how many carry a Jolt body, and their Z.
    protected FString Describe_RigParts(int32 InLeg)
    {
        auto Valid = 0;
        auto WithBody = 0;
        FString Heights = "";
        for (auto Part : Get_RigParts(InLeg))
        {
            FCk_Handle Entity = Part;
            if (ck::Is_NOT_Valid(Entity))
            { continue; }

            Valid += 1;
            if (ck::IsValid(Entity.As_JoltBody(ECk_SanityCheck::UnChecked)))
            { WithBody += 1; }

            Heights += f"{utils_transform::Get_EntityCurrentLocation(Part).Z - _Base.Z},";
        }

        return f"{Valid}/{WithBody}/[{Heights}]";
    }

    // The row's one log line on this machine.
    protected void Log_CrawlerRow(FString InRow, FString InExtra)
    {
        const auto IsFound = Get_IsCrawlerGone() == false;
        const auto Authority = IsFound && utils_net::Get_HasAuthority(_CrawlerRoot);
        FString GaitText = "gone";
        FString PoseText = "gone";
        FString RootText = "gone";
        FString BodyText = "gone";
        if (IsFound)
        {
            const auto Gait = _Crawler.Get_Gait();
            GaitText = f"{utils_procedural_gait::Get_Status(Gait) :n}/{utils_procedural_gait::Get_Failure(Gait) :n}";
            PoseText = f"{Get_BodyPoseStatus() :n}";
            const auto Root = Get_RootLocation();
            RootText = f"{Root.X - _CrawlerAt.X},{Root.Y - _CrawlerAt.Y},{Root.Z - _Base.Z}";
            BodyText = f"{_Health.Get_Current()} dead={_CrawlerMonster.Get_IsDead()} bodyZone={_Zone.Get_IsEnabled()}";
        }

        // Only the striker row composes the carrier whose tally the server keeps.
        const auto Tally = ck::IsValid(_Carrier.Use) ? Get_Tally() : FMars_HeldItemUse_StrikeTally();
        const auto Line = f"[CrawlerNetTest] {InRow} {Get_MachineName()} authority={Authority} composed=[{Describe_Composed()}] gait={GaitText} everFailed={_CrawlerGaitEverFailed} bodyPose={PoseText} trusted={Get_Trusted()} attached={Get_AttachedLegs()} legs={Describe_Legs()}body=[{BodyText} damaged={_BodyDamaged} died={_CrawlerDied} diedFrame={_CrawlerDiedFrame}] root=[{RootText}] initialAtFind={_RosterInitialAtFind :n} initial={Get_RosterInitialState() :n} notifies=[{_RosterNotifies}] {Describe_Feet()} path={_CrawlerPath} largestStep={_CrawlerLargestStep} farthest={_CrawlerFarthestX},{_CrawlerFarthestY} tally=[applied {Tally.Applied} refused {Tally.Refused}] actions={_LegActions} foundFrame={_CrawlerFoundFrame} ensures={Get_NewEnsures()} frame={utils_time::Get_FrameCounter()} limbs=[{Describe_Limbs()}] {InExtra} {_RowExtra}";
        Log(Line);
    }

    protected void Finish_CrawlerRow(FString InRow, FString InExtra)
    {
        Log_CrawlerRow(InRow, InExtra);
        Assert_Equals_Int(Get_NewEnsures(), 0, f"no ensure on the {Get_MachineName()}");
        FinishSuccess();
    }

    // Server: the row's log line and no ensure, then the hold after its last write before it finishes.
    protected void Hold_CrawlerServerRow(FString InRow, FString InExtra)
    {
        Log_CrawlerRow(InRow, InExtra);
        Assert_Equals_Int(Get_NewEnsures(), 0, "no ensure on the server");
        WaitSeconds(k_ServerHoldSeconds, n"OnServerHeld");
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Signals
    //----------------------------------------------------------------------------------------------------------------------

    private int32 Get_LegIndex(FCk_Handle_BodyPart InPart) const
    {
        for (int32 Index = 0; Index < _LegParts.Num(); ++Index)
        {
            if (_LegParts[Index] == InPart)
            { return Index; }
        }

        return -1;
    }

    UFUNCTION()
    private void OnLegSevered(FCk_Handle_BodyPart InPart, FMars_DamageEvent InCause, TArray<FCk_Handle_Transform> InReleased)
    {
        const auto Index = Get_LegIndex(InPart);
        if (Index < 0)
        { return; }

        auto& Signals = _LegSignals[Index];
        Signals.Severed += 1;
        Signals.Released = InReleased.Num();
        if (Signals.Frame < 0)
        {
            Signals.Frame = int32(utils_time::Get_FrameCounter());
            Signals.Seconds = Get_WorldSeconds();
        }
    }

    UFUNCTION()
    private void OnCrawlerDied(FCk_Handle_Monster InMonster, FMars_DamageEvent InCause)
    {
        _CrawlerDied += 1;
        if (_CrawlerDiedFrame < 0)
        { _CrawlerDiedFrame = int32(utils_time::Get_FrameCounter()); }
    }

    UFUNCTION()
    private void OnCrawlerBodyDamaged(FCk_Handle_Health InHealth, FMars_DamageEvent InEvent, float32 InApplied, float32 InRemaining)
    {
        _BodyDamaged += 1;
    }

    // A notify can land on a crawler already ending.
    UFUNCTION()
    private void OnRosterLedgerNotify(FCk_Handle InHandle, FCk_DynamicFragment_RepNotifyInfo InInfo)
    {
        if (ck::Is_NOT_Valid(InHandle) || InHandle.Has_Fragment(FMars_Fragment_BodyPart_Net) == false)
        { return; }

        FString States = "";
        for (const auto& Entry : InHandle.Get_Fragment(FMars_Fragment_BodyPart_Net).Parts)
        { States += f"{Entry.State :n},"; }

        _RosterNotifies += f"{utils_time::Get_FrameCounter()}:{States} ";
    }
}
