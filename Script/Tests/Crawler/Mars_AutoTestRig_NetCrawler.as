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

// The authority's diagnosis of one limb: which leg it was, when its bodies, joints and launch landed, its widest joint
// gap with what every piece did at that frame, the contacts its pieces reported, and the gap trace.
struct FMars_NetCrawlerTest_LimbDiag
{
    UPROPERTY()
    int32 Leg = -1;

    UPROPERTY()
    float64 LegDistance = -1.0;

    UPROPERTY()
    int32 BodiesFrame = -1;

    UPROPERTY()
    int32 JointsFrame = -1;

    UPROPERTY()
    int32 LaunchFrame = -1;

    UPROPERTY()
    int32 FloorContactFrame = -1;

    UPROPERTY()
    float64 FloorContactSeconds = -1.0;

    UPROPERTY()
    int32 LastSampleFrame = -1;

    UPROPERTY()
    int32 Samples = 0;

    UPROPERTY()
    int32 LargestSampleStep = 0;

    UPROPERTY()
    float64 PrevSeconds = -1.0;

    UPROPERTY()
    TArray<FQuat> PrevRotations;

    UPROPERTY()
    TArray<float64> KneeSignedStart;

    UPROPERTY()
    float64 PeakGap = -1.0;

    UPROPERTY()
    int32 PeakFrame = -1;

    UPROPERTY()
    float64 PeakAge = -1.0;

    UPROPERTY()
    int32 PeakJoint = -1;

    UPROPERTY()
    FString PeakKnee = "";

    UPROPERTY()
    FString PeakSpeeds = "";

    UPROPERTY()
    FString PeakTrace = "";

    UPROPERTY()
    int32 PeakTraceLeft = 0;

    UPROPERTY()
    TArray<FString> RecentGaps;

    UPROPERTY()
    FString GapTrace = "";

    UPROPERTY()
    int32 ForeignContacts = 0;

    UPROPERTY()
    TArray<int32> ContactFrames;

    UPROPERTY()
    TArray<FString> Contacts;

    UPROPERTY()
    FString Slide = "";

    UPROPERTY()
    float64 NextSlideSeconds = -1.0;

    UPROPERTY()
    TArray<FVector> SlideStart;

    UPROPERTY()
    FString PieceText = "";

    UPROPERTY()
    bool Logged = false;
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

    // Its lowest piece's height over the floor plane at any sample, and the most pieces it had.
    UPROPERTY()
    float64 LowestOverFloor = 1000000.0;

    UPROPERTY()
    int32 PieceCount = 0;

    // Authority: the contacts its pieces' bodies reported with another piece of the same limb.
    UPROPERTY()
    int32 NeighbourContacts = 0;

    UPROPERTY()
    bool ContactsBound = false;

    UPROPERTY()
    FMars_NetCrawlerTest_LimbDiag Diag;
}

// One attack generation as one machine saw it. The server reads its kernel: its phases from OnAttackPhaseChanged, its
// clip and slots from the plan. A copy reads its ledger and its show: its phases from its cue batches, its clip and
// slots from its own resolved entry. From FirstFrame on, every frame samples the presentation's offset in the root's
// frame and each claimed leg's foot in the root's frame, keeping their largest distance from FirstFrame.
struct FMars_NetCrawlerTest_AttackRecord
{
    UPROPERTY() int32 Generation = 0;
    UPROPERTY() FGameplayTag AttackId;
    UPROPERTY() FString SourceClip;
    UPROPERTY() FString Slots;
    UPROPERTY() TArray<int32> ClaimedLegs;
    // Server: Windup entered; copy: its action created.
    UPROPERTY() int32 FirstFrame = -1;
    UPROPERTY() float64 FirstSeconds = -1.0;
    UPROPERTY() TArray<EMars_Crawler_AttackPhase> Phases;
    UPROPERTY() int32 Admitted = 0;
    UPROPERTY() int32 Interrupted = 0;
    UPROPERTY() int32 Completed = 0;
    UPROPERTY() bool RecoverCuedAfterInterrupt = false;
    UPROPERTY() FCk_Handle_ProceduralAction Action;
    UPROPERTY() int64 ActionIdentity = 0;
    UPROPERTY() int32 Started = 0;
    UPROPERTY() int32 Finished = 0;
    UPROPERTY() ECk_ProceduralAction_Outcome Outcome = ECk_ProceduralAction_Outcome::None;
    UPROPERTY() int32 FinishedFrame = -1;
    UPROPERTY() float64 FinishedSeconds = -1.0;
    UPROPERTY() FVector BodyAtFirst = FVector::ZeroVector;
    UPROPERTY() TArray<FVector> FeetAtFirst;
    UPROPERTY() float64 BodyPeak = 0.0;
    UPROPERTY() float64 FootPeak = 0.0;
    UPROPERTY() int32 BackAtNeutralFrame = -1;
    UPROPERTY() float64 BackAtNeutralSeconds = -1.0;
    // Server: the ledger writes it sampled while this generation was the ledger's; a copy: the notifies carrying it.
    UPROPERTY() TArray<FMars_Fragment_Crawler_Net> Ledgers;
    UPROPERTY() TArray<int32> LedgerFrames;
    UPROPERTY() int32 NotifyFrame = -1;
    // The offensive phases the ledgers carried, in order, each once.
    UPROPERTY() TArray<EMars_Crawler_AttackPhase> Notified;
    UPROPERTY() int32 CancelFrame = -1;
    UPROPERTY() float64 CancelSeconds = -1.0;
    // A copy: the first frame from CancelFrame on its action read Cancelling, Returning or Finished, or was gone.
    UPROPERTY() int32 CancelSeenFrame = -1;
    // Server, read as the attack returns to Idle.
    UPROPERTY() FString LastCancelAtIdle;
    UPROPERTY() bool CommittedAtIdle = false;
}

// What the server publishes of one of its attacks for the client to compare against.
struct FMars_NetCrawlerTest_AttackSummary
{
    UPROPERTY() int32 Generation = 0;
    UPROPERTY() FGameplayTag AttackId;
    UPROPERTY() FString SourceClip;
    UPROPERTY() FString Slots;
    UPROPERTY() int32 FirstFrame = -1;
    UPROPERTY() float64 BodyPeak = 0.0;
    UPROPERTY() float64 FootPeak = 0.0;
}

// Test-only, on the crawler's root: the server's own record of its attacks once it has measured them, replicated so the
// client can set its copy's records beside them. HitFrame is the frame of the server's hit on the crawler's body (-1
// without one); StruckGeneration the attack whose blow first hurt the row's pawn (0 without one); Pawn* what the server
// read of that pawn's Health.
struct FMars_TESTONLY_Fragment_Crawler_ServerAttacks
{
    UPROPERTY() TArray<FMars_NetCrawlerTest_AttackSummary> Attacks;
    UPROPERTY() int32 HitFrame = -1;
    UPROPERTY() int32 StruckGeneration = 0;
    UPROPERTY() float32 PawnHealth = -1.0f;
    UPROPERTY() TArray<float32> PawnApplied;
}

// Test-only, on a limb's root: the server's world pose and half extents of every piece once its limb reads at rest,
// replicated so the client can set its own beside them.
struct FMars_TESTONLY_Fragment_SeveredLimb_RestPose
{
    UPROPERTY()
    TArray<FTransform> Pieces;

    UPROPERTY()
    TArray<FVector> HalfExtents;
}

// A placed lever's spawn: its transform only, so its class's own defaults (channel, prompt) stand; injection matches by
// property name.
struct FMars_TESTONLY_NetCrawler_LeverSpawnParams
{
    UPROPERTY()
    FTransform SpawnTransform;
}

// One named frame the server marked (a hit, a clear, a lever flip), on the shared frame counter.
struct FMars_NetCrawlerTest_Mark
{
    UPROPERTY() FString Name;
    UPROPERTY() int32 Frame = -1;
}

// Test-only, on the crawler's root: the spec the server composed and the frames it marked, replicated so a copy can
// compare its own against them. Written again (and marked dirty) as the server marks more frames.
struct FMars_TESTONLY_Fragment_Crawler_ServerReadout
{
    UPROPERTY() int32 LegCount = 0;
    UPROPERTY() EMars_Crawler_Layout Layout = EMars_Crawler_Layout::Radial;
    UPROPERTY() FBox RoamBounds;
    UPROPERTY() bool CombatEnabled = false;
    UPROPERTY() FVector BodyHalfExtents = FVector::ZeroVector;
    UPROPERTY() float32 HomeRadius = 0.0f;
    UPROPERTY() float32 AcquireRadius = 0.0f;
    UPROPERTY() TArray<FMars_NetCrawlerTest_Mark> Marks;
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
// the server spawns a crawler of the row's layout and leg count (4 Radial unless the row sets _LegCount and _Layout)
// through its real entity script under the replicated spawn owner (its root the layout's clearance above the floor,
// facing +X, without visuals, combat off). A row may tilt the floor about Y (_FloorPitchDegrees): every height is then
// measured to the floor's plane. Each machine finds its copy by tag near where it was
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
    // Decision tolerances: the authority's joints at every sample, a copy's at rest, a copy's piece against the
    // published rest pose, a knee's least swing and its farthest.
    protected const float64 k_AuthorityGapCm = 2.0;
    protected const float64 k_CopyGapCm = 4.0;
    protected const float64 k_RestPoseCm = 3.0;
    protected const float64 k_RestPoseDegrees = 3.0;
    protected const float64 k_KneeLeastSwingDegrees = 5.0;
    protected const float64 k_KneeMostSwingDegrees = 70.0;
    protected const float64 k_BelowFloorCm = 2.0;

    // A row sets these before Begin_*: the crawler's legs and layout (the 4-leg rows keep k_LegCount, Radial), the
    // radius its limbs are looked for in (k_LimbNearCm) and the floor's fall toward +X in degrees (level).
    protected int32 _LegCount = 4;
    protected EMars_Crawler_Layout _Layout = EMars_Crawler_Layout::Radial;
    protected float64 _LimbNearCm = 600.0;
    protected float64 _FloorPitchDegrees = 0.0;

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
    // The copy's spec's limb lifetime, read at the find.
    protected float64 _LimbLifetimeSeconds = 8.0;

    // This machine's floor box, and each leg's first segment where it was last seen attached.
    protected FCk_Handle _FloorEntity;
    private TArray<FVector> _LegFirstSegmentLast;

    // Every sampled frame and this machine's world seconds at it: the frame counter is the machines' shared clock.
    private TArray<int32> _ClockFrames;
    private TArray<float64> _ClockSeconds;
    // The server's readout as this machine last read it (a copy keeps it once its crawler is gone).
    protected FMars_TESTONLY_Fragment_Crawler_ServerReadout _Readout;
    protected bool _HasReadout = false;

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

    // A static Jolt box whose top face passes through the base, tilted to fall _FloorPitchDegrees toward +X, owned by
    // this machine's subject (it dies with the test).
    private void Spawn_CrawlerFloor()
    {
        auto Subject = Get_SubjectEntity();
        auto Box = utils_entity_lifetime::Request_CreateEntity(Subject);
        _FloorEntity = Box;
        utils_transform::Add(Box, FTransform(Get_FloorRotation(), _Base - Get_FloorNormal() * k_FloorHalfExtents.Z),
            ECk_Replication::DoesNotReplicate);
        auto Shape = FCk_Jolt_ShapeDimensions(ECk_Jolt_ShapeType::Box);
        Shape.Set_HalfExtents(k_FloorHalfExtents);
        auto BoxSpec = FCk_JoltBody_Spec(ECk_JoltBody_ShapeSource::ExplicitShape);
        BoxSpec.Set_ShapeDimensions(Shape);
        BoxSpec.Set_MotionType(ECk_MotionType::Static);
        BoxSpec.Set_CollisionProfileName(n"BlockAll");
        utils_jolt_body::Add(Box, BoxSpec);
    }

    protected FRotator Get_FloorRotation() const
    {
        return FRotator(-_FloorPitchDegrees, 0.0, 0.0);
    }

    protected FVector Get_FloorNormal() const
    {
        return Get_FloorRotation().RotateVector(FVector::UpVector);
    }

    // InLocation's height over the floor's plane (the plane through the base).
    protected float64 Get_HeightOverFloor(FVector InLocation) const
    {
        return (InLocation - _Base).DotProduct(Get_FloorNormal());
    }

    // The row's legs and layout roaming the box of InRoamHalfExtent around the crawler, dwelling 0.3 s, a severed limb
    // living 8 s, combat off.
    protected FMars_Crawler_Spec Make_RowSpec(FVector InRoamHalfExtent) const
    {
        auto Spec = FMars_Crawler_Spec(_LegCount, FBox(_CrawlerAt - InRoamHalfExtent, _CrawlerAt + InRoamHalfExtent));
        Spec.Layout = _Layout;
        Spec.RoamDwellSeconds = 0.3f;
        Spec.Vitals.LegDebris.LifetimeSeconds = 8.0f;
        Spec.Combat.Enabled = false;
        return Spec;
    }

    // Where leg InIndex's foot rests in the row's crawler's body frame.
    protected FVector Get_RestFootLocal(int32 InIndex) const
    {
        const TArray<FCk_ProceduralLeg_Spec> Legs = utils_crawler::Get_LayoutRigData(_Layout, _LegCount).Get_Legs();
        return Legs[InIndex].Get_Placement().Get_RestFootLocal();
    }

    protected void Spawn_ServerCrawler(FMars_Crawler_Spec InSpec)
    {
        Spawn_ServerCrawlerOfClass(InSpec, UMars_Crawler_EntityScript);
    }

    // The crawler of InClass under the replicated spawn owner, its root the layout's clearance above the floor, facing
    // +X, without visuals.
    protected void Spawn_ServerCrawlerOfClass(FMars_Crawler_Spec InSpec, TSubclassOf<UCk_EntityScript_UE> InClass)
    {
        const auto Clearance = float64(utils_crawler::Get_LayoutClearance(_Layout));
        Spawn_ServerCrawlerAt(InSpec, InClass, FTransform(FRotator::ZeroRotator, _CrawlerAt + FVector(0.0, 0.0, Clearance)), false);
    }

    // The crawler of InClass at InTransform under the replicated spawn owner (the channel a spawner with authority
    // queues a placed crawler under). The base script's params: native injection matches by property name, so a preset
    // class takes them too.
    protected void Spawn_ServerCrawlerAt(FMars_Crawler_Spec InSpec, TSubclassOf<UCk_EntityScript_UE> InClass, FTransform InTransform, bool InWithVisuals)
    {
        auto Params = UMars_Crawler_EntityScript::Params();
        Params.SpawnTransform = InTransform;
        Params.Spec = InSpec;
        Params.WithVisuals = InWithVisuals;
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
        if (_LegParts.Num() == _LegCount)
        { return true; }

        for (auto Candidate : utils_entity_tag::ForEach_Entity(Get_SubjectEntity(), n"TAG_MarsCrawler"))
        {
            if (Get_IsNear(Candidate, _CrawlerAt) == false)
            { continue; }

            auto Crawler = Candidate.As_Crawler(ECk_SanityCheck::UnChecked);
            if (ck::Is_NOT_Valid(Crawler) || Crawler.Get_LegParts().Num() != _LegCount)
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
        _LimbLifetimeSeconds = float64(InCrawler.Get_Spec().Vitals.LegDebris.LifetimeSeconds);
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
            && _CrawlerMonster.Get_Parts().Num() == _LegCount);
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

    // Once its part 0 reads Severed: within ten frames of its OnSevered leg 0 left its copy, raising OnSevered once
    // with its zone off, and every captured leg-0 rig part is gone (no local limb); a second later the other legs walk
    // on and exactly one limb is near, not this machine's; then the client's rest asserts, and the row finishes once no
    // limb is left.
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
        for (int32 Index = 1; Index < _LegCount; ++Index)
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
        Finish_ClientLeg0Row();
    }

    // The end of a client's leg-0 sever, once no limb is near: a row may add its asserts first.
    protected void Finish_ClientLeg0Row()
    {
        Finish_CrawlerRow(_SeverRow, f"severedFrame={_ClientSeveredFrame}");
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Server: its leg-0 sever and the one limb it spawns
    //----------------------------------------------------------------------------------------------------------------------

    // From the sever on: within ten frames of OnSevered every captured leg-0 rig part is gone; a second later exactly
    // one limb is near, with authority, a body per piece and every joint added, and leg 0's entity is valid and
    // detached with its part Severed. Once the limb reads at rest (the sampler publishes its rest pose), the server
    // waits until it is gone: its widest joint gap stayed within k_AuthorityGapCm and it lived between 7.5 and 9 s. The
    // row's own tail (Assert_ServerLimbTail) runs, and the row holds.
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
            const auto Shortest = _LimbLifetimeSeconds - 0.5;
            const auto Longest = _LimbLifetimeSeconds + 1.0;
            Assert_True(Lived >= Shortest && Lived <= Longest, f"the server's limb lived {Lived} s ({Shortest} to {Longest})");
        }

        Assert_ServerLimbTail();
        Hold_CrawlerServerRow(_LimbRow, "");
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Limbs
    //----------------------------------------------------------------------------------------------------------------------

    // Every valid limb within _LimbNearCm of the base (horizontally), not pending destroy.
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
            if (Offset.Size() < _LimbNearCm)
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

        _LegFirstSegmentLast.SetNum(_LegRigs.Num());
        for (int32 Leg = 0; Leg < _LegRigs.Num(); ++Leg)
        {
            if (_LegRigs[Leg].Segments.Num() > 0 && ck::IsValid(_LegRigs[Leg].Segments[0])
                && utils_entity_lifetime::Get_IsPendingDestroy(_LegRigs[Leg].Segments[0], ECk_EntityLifetime_DestructionPhase::BeginDestroy) == false)
            { _LegFirstSegmentLast[Leg] = utils_transform::Get_EntityCurrentLocation(_LegRigs[Leg].Segments[0]); }
        }

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
            {
                Record.GoneSeconds = Get_WorldSeconds();
                Log_LimbDiag(Index);
            }
        }
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Limb diagnosis (authority)
    //----------------------------------------------------------------------------------------------------------------------

    // Knee InKnee's angle from the upper piece's X to the lower's, signed about the upper piece's Z (the hinge's axis).
    private float64 Get_SignedKnee(const TArray<FCk_Handle_Transform>& InPieces, int32 InKnee)
    {
        const auto Upper = utils_transform::Get_EntityCurrentTransform(InPieces[InKnee]).GetRotation();
        const auto Lower = utils_transform::Get_EntityCurrentTransform(InPieces[InKnee + 1]).GetRotation();
        const auto UpperX = Upper.GetAxisX();
        const auto LowerX = Lower.GetAxisX();
        const auto Sine = UpperX.CrossProduct(LowerX).DotProduct(Upper.GetAxisZ());
        return Math::RadiansToDegrees(Math::Atan2(Sine, UpperX.DotProduct(LowerX)));
    }

    private FCk_Handle_JoltBody Get_PieceBody(FCk_Handle_Transform InPiece)
    {
        FCk_Handle Entity = InPiece;
        return Entity.As_JoltBody(ECk_SanityCheck::UnChecked);
    }

    // Once per frame per limb on the authority: the leg it was cut from, the frames its bodies, joints and launch
    // landed, its peak gap with each piece's speeds and the knee's swing at that frame, the gap trace and, on a slope,
    // the slide.
    private void Sample_LimbDiag(int32 InIndex, const TArray<float64>& InGaps)
    {
        const auto Limb = _Limbs[InIndex].Limb;
        const auto Pieces = Get_LimbPieces(Limb);
        const auto Frame = int32(utils_time::Get_FrameCounter());
        const auto Now = Get_WorldSeconds();
        auto& Diag = _Limbs[InIndex].Diag;
        if (Pieces.Num() == 0 || Diag.LastSampleFrame == Frame)
        { return; }

        if (Diag.LastSampleFrame >= 0)
        { Diag.LargestSampleStep = Math::Max(Diag.LargestSampleStep, Frame - Diag.LastSampleFrame); }

        Diag.LastSampleFrame = Frame;
        Diag.Samples += 1;

        if (Diag.Leg < 0)
        {
            const auto FirstPiece = utils_transform::Get_EntityCurrentLocation(Pieces[0]);
            for (int32 Leg = 0; Leg < _LegFirstSegmentLast.Num(); ++Leg)
            {
                const auto Distance = (_LegFirstSegmentLast[Leg] - FirstPiece).Size();
                if (Diag.Leg < 0 || Distance < Diag.LegDistance)
                {
                    Diag.Leg = Leg;
                    Diag.LegDistance = Distance;
                }
            }

            for (int32 Knee = 0; Knee + 2 < Pieces.Num(); ++Knee)
            { Diag.KneeSignedStart.Add(Get_SignedKnee(Pieces, Knee)); }

            const auto Severed = Limb.As_SeveredLimb(ECk_SanityCheck::UnChecked);
            const TArray<FCk_ProceduralLeg_Spec> Legs = utils_crawler::Get_LayoutRigData(_Layout, _LegCount).Get_Legs();
            for (int32 Piece = 0; Piece < Pieces.Num(); ++Piece)
            {
                const auto HalfX = Severed.Get_PieceHalfExtents(Piece).X;
                auto HalfLength = -1.0;
                if (Diag.Leg >= 0 && Diag.Leg < Legs.Num() && Piece < Legs[Diag.Leg].Get_Chain().Get_SegmentLengths().Num())
                { HalfLength = float64(Legs[Diag.Leg].Get_Chain().Get_SegmentLengths()[Piece]) * 0.5; }

                Diag.PieceText += f"p{Piece}:halfX {HalfX :.2} halfLength {HalfLength :.2};";
            }
        }

        auto BodiesAdded = 0;
        for (auto Piece : Pieces)
        {
            const auto Body = Get_PieceBody(Piece);
            if (ck::IsValid(Body) && utils_jolt_body::Get_IsBodyAdded(Body))
            { BodiesAdded += 1; }
        }

        if (Diag.BodiesFrame < 0 && BodiesAdded == Pieces.Num())
        { Diag.BodiesFrame = Frame; }

        if (Diag.JointsFrame < 0 && Get_LimbJointsAdded(Limb) == Pieces.Num() - 1)
        { Diag.JointsFrame = Frame; }

        if (Diag.LaunchFrame < 0 && Limb.Has_Fragment(FMars_Fragment_BodyPart_PendingDebris) == false)
        { Diag.LaunchFrame = Frame; }

        auto Widest = -1.0;
        auto WidestJoint = -1;
        for (int32 Joint = 0; Joint < InGaps.Num(); ++Joint)
        {
            if (InGaps[Joint] > Widest)
            {
                Widest = InGaps[Joint];
                WidestJoint = Joint;
            }
        }

        const auto GapPair = f"{Frame}:{Widest :.2}";
        if (Diag.Samples <= 30)
        { Diag.GapTrace += f"{GapPair},"; }

        if (Diag.PeakTraceLeft > 0)
        {
            Diag.PeakTrace += f"{GapPair},";
            Diag.PeakTraceLeft -= 1;
        }

        const auto DeltaSeconds = Diag.PrevSeconds >= 0.0 ? Now - Diag.PrevSeconds : 0.0;
        if (Widest > Diag.PeakGap)
        {
            Diag.PeakGap = Widest;
            Diag.PeakFrame = Frame;
            Diag.PeakAge = Now - _Limbs[InIndex].FirstSeconds;
            Diag.PeakJoint = WidestJoint;
            Diag.PeakTrace = "";
            for (const auto& Recent : Diag.RecentGaps)
            { Diag.PeakTrace += f"{Recent},"; }

            Diag.PeakTrace += f"[{GapPair}],";
            Diag.PeakTraceLeft = 5;

            Diag.PeakKnee = "";
            if (WidestJoint + 2 < Pieces.Num() && WidestJoint < Diag.KneeSignedStart.Num())
            {
                const auto Swing = Get_SignedKnee(Pieces, WidestJoint) - Diag.KneeSignedStart[WidestJoint];
                const auto Limit = float64(constants_severed_limb::k_KneeLimitDegrees);
                FString Where = "inside";
                if (Math::Abs(Swing) > Limit)
                { Where = "past"; }
                else if (Math::Abs(Swing) >= Limit - 1.0)
                { Where = "at"; }

                Diag.PeakKnee = f"swing {Swing :.2} {Where} limit";
            }
            else
            { Diag.PeakKnee = "ankle"; }

            Diag.PeakSpeeds = "";
            for (int32 Piece = 0; Piece < Pieces.Num(); ++Piece)
            {
                const auto Body = Get_PieceBody(Pieces[Piece]);
                const auto Linear = ck::IsValid(Body) ? utils_jolt_body::Get_LinearVelocity(Body).Size() : -1.0;
                auto Angular = -1.0;
                if (DeltaSeconds > 0.0 && Piece < Diag.PrevRotations.Num())
                {
                    const auto Rotation = utils_transform::Get_EntityCurrentTransform(Pieces[Piece]).GetRotation();
                    Angular = Math::RadiansToDegrees(Rotation.AngularDistance(Diag.PrevRotations[Piece])) / DeltaSeconds;
                }

                Diag.PeakSpeeds += f"p{Piece}:{Linear :.1}cm/s,{Angular :.1}deg/s ";
            }
        }

        Diag.RecentGaps.Add(GapPair);
        if (Diag.RecentGaps.Num() > 5)
        { Diag.RecentGaps.RemoveAt(0); }

        Diag.PrevRotations.SetNum(Pieces.Num());
        for (int32 Piece = 0; Piece < Pieces.Num(); ++Piece)
        { Diag.PrevRotations[Piece] = utils_transform::Get_EntityCurrentTransform(Pieces[Piece]).GetRotation(); }

        Diag.PrevSeconds = Now;
        Sample_LimbSlide(InIndex, Pieces);
    }

    // On a sloped floor, from the limb's first floor contact, every 0.25 s per piece: its speed down the slope, its
    // speed along the floor's normal, its sleep state and how far down the slope it moved since that contact.
    private void Sample_LimbSlide(int32 InIndex, const TArray<FCk_Handle_Transform>& InPieces)
    {
        auto& Diag = _Limbs[InIndex].Diag;
        if (_FloorPitchDegrees == 0.0 || Diag.FloorContactFrame < 0 || Get_WorldSeconds() < Diag.NextSlideSeconds)
        { return; }

        const auto Downhill = Get_FloorRotation().RotateVector(FVector::ForwardVector);
        const auto Normal = Get_FloorNormal();
        if (Diag.SlideStart.Num() == 0)
        {
            for (auto Piece : InPieces)
            { Diag.SlideStart.Add(utils_transform::Get_EntityCurrentLocation(Piece)); }
        }

        FString Line = f"t+{Get_WorldSeconds() - Diag.FloorContactSeconds :.2}[";
        for (int32 Piece = 0; Piece < InPieces.Num() && Piece < Diag.SlideStart.Num(); ++Piece)
        {
            const auto Body = Get_PieceBody(InPieces[Piece]);
            const auto Velocity = ck::IsValid(Body) ? utils_jolt_body::Get_LinearVelocity(Body) : FVector::ZeroVector;
            const auto Sleep = ck::IsValid(Body) ? f"{utils_jolt_body::Get_SleepState(Body) :n}" : FString("none");
            const auto Moved = (utils_transform::Get_EntityCurrentLocation(InPieces[Piece]) - Diag.SlideStart[Piece]).DotProduct(Downhill);
            Line += f"p{Piece}:down {Velocity.DotProduct(Downhill) :.1} normal {Velocity.DotProduct(Normal) :.1} {Sleep} moved {Moved :.1};";
        }

        Diag.Slide += f"{Line}] ";
        Diag.NextSlideSeconds = Get_WorldSeconds() + 0.25;
    }

    // One line per limb on the authority, once, when it goes (or when the row logs it still standing).
    protected void Log_LimbDiag(int32 InIndex)
    {
        auto& Record = _Limbs[InIndex];
        if (Record.Diag.Logged || Record.Diag.Samples == 0)
        { return; }

        Record.Diag.Logged = true;
        const auto& Diag = Record.Diag;
        FString PeakContacts = "";
        for (int32 Contact = 0; Contact < Diag.Contacts.Num() && Contact < Diag.ContactFrames.Num(); ++Contact)
        {
            if (Math::Abs(Diag.ContactFrames[Contact] - Diag.PeakFrame) <= 2)
            { PeakContacts += f"{Diag.Contacts[Contact]};"; }
        }

        FString FloorContacts = "";
        auto Shown = 0;
        for (int32 Contact = 0; Contact < Diag.Contacts.Num() && Shown < 12; ++Contact)
        {
            FloorContacts += f"{Diag.Contacts[Contact]};";
            Shown += 1;
        }

        const auto Machine = Get_MachineName();
        Log(f"[CrawlerNetLimbDiag] {_LimbRow} {Machine} limb={InIndex} leg={Diag.Leg} legDistance={Diag.LegDistance :.2} first={Record.FirstFrame} "
            + f"bodies={Diag.BodiesFrame} joints={Diag.JointsFrame} launch={Diag.LaunchFrame} floorContact={Diag.FloorContactFrame} "
            + f"samples={Diag.Samples} largestStep={Diag.LargestSampleStep} peak=[gap {Diag.PeakGap :.2} frame {Diag.PeakFrame} age {Diag.PeakAge :.3} "
            + f"joint {Diag.PeakJoint} knee {Diag.PeakKnee} speeds {Diag.PeakSpeeds}contacts {PeakContacts}] foreign={Diag.ForeignContacts} "
            + f"sameLimb={Record.NeighbourContacts} rest={Record.RestSeconds - Record.FirstSeconds :.2} pieces=[{Diag.PieceText}] "
            + f"firstContacts=[{FloorContacts}] gapTrace=[{Diag.GapTrace}] peakTrace=[{Diag.PeakTrace}] slide=[{Diag.Slide}]");
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

        Record.PieceCount = Math::Max(Record.PieceCount, Pieces.Num());
        for (auto Piece : Pieces)
        { Record.LowestOverFloor = Math::Min(Record.LowestOverFloor, Get_HeightOverFloor(utils_transform::Get_EntityCurrentLocation(Piece))); }

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

        if (utils_net::Get_HasAuthority(Limb))
        { Sample_LimbDiag(InIndex, Gaps); }

        if (_Limbs[InIndex].RestFrame >= 0 || AtRest == false)
        { return; }

        auto& Resting = _Limbs[InIndex];
        Resting.RestFrame = int32(utils_time::Get_FrameCounter());
        Resting.RestSeconds = Get_WorldSeconds();
        if (Get_IsServer())
        { Publish_RestPose(Limb); }
    }

    UFUNCTION()
    private void OnLimbPieceContact(FCk_Handle_JoltBody InBody, FCk_JoltBody_Payload_OnContact InPayload)
    {
        FCk_Handle BodyEntity = InBody;
        const FCk_Handle OtherEntity = InPayload.Get_OtherEntity();
        auto MineRecord = -1;
        auto MinePiece = -1;
        auto OtherRecord = -1;
        auto OtherPiece = -1;
        for (int32 RecordIndex = 0; RecordIndex < _Limbs.Num(); ++RecordIndex)
        {
            const auto Pieces = Get_LimbPieces(_Limbs[RecordIndex].Limb);
            for (int32 Index = 0; Index < Pieces.Num(); ++Index)
            {
                FCk_Handle Entity = Pieces[Index];
                if (Entity == BodyEntity)
                {
                    MineRecord = RecordIndex;
                    MinePiece = Index;
                }
                if (Entity == OtherEntity)
                {
                    OtherRecord = RecordIndex;
                    OtherPiece = Index;
                }
            }
        }

        if (MineRecord < 0)
        { return; }

        auto& Record = _Limbs[MineRecord];
        const auto Frame = int32(utils_time::Get_FrameCounter());
        FString Class = "other";
        if (OtherRecord == MineRecord)
        {
            Class = f"sameLimb p{OtherPiece}";
            Record.NeighbourContacts += 1;
        }
        else if (OtherRecord >= 0)
        {
            Class = f"limb{OtherRecord} p{OtherPiece}";
            Record.Diag.ForeignContacts += 1;
        }
        else if (OtherEntity == _FloorEntity)
        {
            Class = "floor";
            if (Record.Diag.FloorContactFrame < 0)
            {
                Record.Diag.FloorContactFrame = Frame;
                Record.Diag.FloorContactSeconds = Get_WorldSeconds();
            }
        }

        if (Record.Diag.Contacts.Num() < 200)
        {
            Record.Diag.ContactFrames.Add(Frame);
            Record.Diag.Contacts.Add(f"{Frame}:p{MinePiece}:{Class}:{InPayload.Get_RelativeNormalSpeed() :.1}");
        }
    }

    // Server: the readout on the limb's root, its pieces' world poses now.
    private void Publish_RestPose(FCk_Handle InLimb)
    {
        auto Limb = InLimb;
        if (Limb.Has_Fragment(FMars_TESTONLY_Fragment_SeveredLimb_RestPose))
        { return; }

        auto Readout = FMars_TESTONLY_Fragment_SeveredLimb_RestPose();
        const auto Pieces = Get_LimbPieces(Limb);
        const auto Severed = Limb.As_SeveredLimb(ECk_SanityCheck::UnChecked);
        for (int32 Index = 0; Index < Pieces.Num(); ++Index)
        {
            Readout.Pieces.Add(utils_transform::Get_EntityCurrentTransform(Pieces[Index]));
            Readout.HalfExtents.Add(ck::IsValid(Severed) ? Severed.Get_PieceHalfExtents(Index) : FVector::ZeroVector);
        }

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

    // Once the server published its limb's rest pose and this copy's limb reads at rest: every piece within
    // k_RestPoseCm and k_RestPoseDegrees of the published pose and not more than k_BelowFloorCm below the floor, every
    // joint gap within k_CopyGapCm; again 0.5 s later; then InContinuation once no limb is near.
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
            Assert_True(Get_HeightOverFloor(Mine.GetLocation()) >= -k_BelowFloorCm,
                f"the client's piece {Index} is not below the floor ({Get_HeightOverFloor(Mine.GetLocation())}) {InWhen}");
        }

        const auto Gaps = Get_LimbJointGaps(Limb);
        for (int32 Index = 0; Index < Gaps.Num(); ++Index)
        { Assert_True(Gaps[Index] <= k_CopyGapCm, f"the client's joint {Index} gap {Gaps[Index]} is at most {k_CopyGapCm} {InWhen}"); }
    }

    // Every limb this machine saw, one line each: authority / bodies / joints / widest gap / knee start and swing /
    // birth lift / same-limb contacts / at rest / piece poses, and the published rest pose.
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
            Text += f"[limb first={Record.FirstFrame}@{Record.FirstSeconds} gone={Record.GoneSeconds} widestGap={Record.WidestGap} knees(start/swing)={Knees} firstPieceMoved={Moved} rest={Record.RestFrame}@{Record.RestSeconds} notifies={Record.Notifies} beforeRest={Record.NotifiesBeforeRest} ledger={Record.LedgerInitial} contacts={Record.NeighbourContacts} lowest={Record.LowestOverFloor} pieces={Record.PieceCount}";
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

    // A rig's own per-sample work, before the copy's.
    protected void Sample_RowExtra()
    {
    }

    // One sample of this machine's copy: the root's step, path and offset from the base, the gait and, while recording,
    // the feet. Quiet once the copy is gone.
    protected void Sample_Crawler()
    {
        Sample_Clock();
        Sample_Limbs();
        Sample_RowExtra();
        if (Get_IsCrawlerGone())
        { return; }

        if (_CrawlerRoot.Has_Fragment(FMars_TESTONLY_Fragment_Crawler_ServerReadout))
        {
            _Readout = _CrawlerRoot.Get_Fragment(FMars_TESTONLY_Fragment_Crawler_ServerReadout);
            _HasReadout = true;
        }

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

        if (_AttackRecording)
        { Sample_Attacks(); }
    }

    //----------------------------------------------------------------------------------------------------------------------
    // The feet
    //----------------------------------------------------------------------------------------------------------------------

    protected void Begin_FeetRecord()
    {
        _FeetRecording = true;
        _FeetRecords.Reset();
        for (int32 Index = 0; Index < _LegCount; ++Index)
        { _FeetRecords.Add(FMars_NetCrawlerTest_FootRecord()); }
    }

    private void Sample_Feet()
    {
        for (int32 Index = 0; Index < _LegParts.Num() && Index < _FeetRecords.Num(); ++Index)
        {
            if (Get_IsLegAttached(Index) == false)
            { continue; }

            const auto Foot = utils_procedural_leg::Get_Foot(_LegParts[Index].Get_Leg());
            const auto Lift = Get_HeightOverFloor(Foot.Get_Position());
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
        if (_FeetRecords.Num() != _LegCount)
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
    // Attacks: an armed crawler, its prey, and every attack generation each machine sees
    //----------------------------------------------------------------------------------------------------------------------

    // The prey's near face stands this far in front of the jab's neutral hit centre (where the pincer row stands it).
    protected const float64 k_PreyFaceAhead = 30.0;
    protected const FVector k_PreyHalfExtents = FVector(10.0, 20.0, 20.0);
    protected const float64 k_NeutralCm = 1.0;

    // Server: the prey its attacks are driven at; a copy: its decoy, its own, where the prey stands.
    protected FCk_Handle _Prey;
    protected FCk_Handle_Health _PreyHealth;
    protected TArray<float32> _PreyApplied;

    protected bool _AttackRecording = false;
    protected TArray<FMars_NetCrawlerTest_AttackRecord> _Attacks;
    protected FMars_Fragment_Crawler_Net _LedgerLast;
    // Server: every ledger write it sampled; a copy: every rep-notify of its ledger. As frame:ledger.
    protected FString _LedgerLog = "";
    protected int32 _LedgerNotifies = 0;
    protected EMars_Net_InitialState _LedgerInitialAtFind = EMars_Net_InitialState::Awaited;
    protected int32 _AttackCues = 0;
    // A copy: whether its kernel ever read a phase other than Idle.
    protected bool _CopyEverOutOfIdle = false;

    // Server: a hit of this on the body zone the frame an attack enters Strike, and aggression switched off this long
    // after Windup or at Strike if sooner.
    protected TOptional<float32> _HurtAtStrike;
    protected TOptional<float32> _DisableAfterWindupSeconds;
    protected int32 _HitFrame = -1;
    protected int32 _DisabledFrame = -1;
    private bool _ServerTargetRequested = false;

    // A copy: the frame and seconds its hurt count first read above 0; every sampled frame's world seconds.
    protected int32 _CopyHurtFrame = -1;
    protected float64 _CopyHurtSeconds = -1.0;
    private TArray<int32> _SampleFrames;
    private TArray<float64> _SampleSeconds;

    // Combat on, the row's aggression and the shipped 4-leg parity loadout (its jab and pincer): a content asset, so
    // its soft path resolves on the client.
    protected FMars_Crawler_Spec Make_ArmedRowSpec(FVector InRoamHalfExtent, ECk_EnableDisable InAggression) const
    {
        auto Spec = Make_RowSpec(InRoamHalfExtent);
        Spec.Combat.Enabled = true;
        Spec.Combat.StartAggressive = InAggression;
        Spec.Combat.Loadout = utils_crawler::Get_AttackReferenceLoadout(EMars_Crawler_AttackPreset::Crawler4, EMars_AttackReference_Kind::Parity);
        return Spec;
    }

    // This machine's copy's action (its show's); invalid with authority.
    protected FCk_Handle_ProceduralAction Get_CopyAction()
    {
        if (Get_IsCrawlerGone())
        { return FCk_Handle_ProceduralAction(); }

        return _Crawler.Get_AttackShow().Action;
    }

    // This machine's ledger.
    protected FMars_Fragment_Crawler_Net Get_CopyLedger()
    {
        if (Get_IsCrawlerGone())
        { return FMars_Fragment_Crawler_Net(); }

        return _Crawler.Get_AttackLedger();
    }

    // How many actions this machine's copy started; 0 with authority.
    protected int32 Get_CopyStarted()
    {
        if (Get_IsCrawlerGone())
        { return 0; }

        return _Crawler.Get_AttackShow().Started;
    }

    // The attack generation this machine's copy took as it stood (never played); -1 without a mirror state.
    protected int32 Get_CopyStoodGeneration()
    {
        if (Get_IsCrawlerGone() || _CrawlerRoot.Has_Fragment(FMars_Fragment_Crawler_Local) == false)
        { return -1; }

        return _CrawlerRoot.Get_Fragment(FMars_Fragment_Crawler_Local).StoodGeneration;
    }

    protected EMars_Net_InitialState Get_CopyLedgerInitial()
    {
        if (Get_IsCrawlerGone() || _CrawlerRoot.Has_Fragment(FMars_Fragment_Crawler_Local) == false)
        { return EMars_Net_InitialState::Awaited; }

        return _CrawlerRoot.Get_Fragment(FMars_Fragment_Crawler_Local).InitialState;
    }

    protected bool Get_HasCopyShow()
    {
        return Get_IsCrawlerGone() == false && _CrawlerRoot.Has_Fragment(FMars_Fragment_Crawler_AttackShow);
    }

    // From here on: each machine binds the crawler's cues, the server its phase changes and a copy its ledger's
    // rep-notifies, and every sample records the attack generations.
    protected void Begin_AttackRecord()
    {
        _AttackRecording = true;
        _LedgerInitialAtFind = Get_CopyLedgerInitial();
        _Crawler.BindTo_OnAttackCue(FMars_Delegate_Crawler_OnAttackCue(this, n"OnRowAttackCue"));
        if (Get_IsServer())
        {
            _Crawler.BindTo_OnAttackPhaseChanged(FMars_Delegate_Crawler_OnAttackPhaseChanged(this, n"OnRowAttackPhaseChanged"));
            return;
        }

        if (_CrawlerRoot.Has_Fragment(FMars_Fragment_Crawler_Net))
        { _CrawlerRoot.BindTo_OnRepNotify(FMars_Fragment_Crawler_Net, FCk_DynamicFragment_OnRepNotify(this, n"OnRowLedgerNotify")); }
    }

    // The prey (the server's) or the decoy (a copy's): team One, Health 100, a flesh body zone and one box hurtbox,
    // squared to the crawler's forward with its near face k_PreyFaceAhead in front of the jab's neutral hit centre. It
    // carries no tag: the rows drive the kernel, the scan is not under test.
    protected void Spawn_Prey()
    {
        const auto Jab = utils_crawler::Find_ResolvedAttack(_Crawler.Get_Spec().ResolvedAttacks, GameplayTags::Attack_Mars_Jab);
        if (Jab.IsSet() == false || Jab.GetValue().Definition.Hit.Emitters.Num() == 0)
        {
            FinishFailure(f"the {Get_MachineName()}'s crawler has no resolved jab emitter");
            return;
        }

        const auto Root = utils_transform::Get_EntityCurrentTransform(_Crawler.As_Transform());
        const auto Forward = Root.GetRotation().GetForwardVector().GetSafeNormal2D();
        const auto Presentation = utils_transform::Get_EntityCurrentTransform(_Crawler.Get_Presentation());
        const auto Center = utils_crawler::Get_HitCenter(Presentation, Jab.GetValue().Definition.Hit.Emitters[0].LocalCenter);
        const auto At = Center + Forward * (k_PreyFaceAhead + k_PreyHalfExtents.X);

        _Prey = utils_entity_lifetime::Request_CreateEntity(Get_SubjectEntity());
        auto PreyRoot = utils_transform::Add(_Prey, FTransform(Forward.Rotation(), At), ECk_Replication::DoesNotReplicate);
        utils_team::Add(_Prey, ECk_Team_ID::One, ECk_Replication::DoesNotReplicate);
        _PreyHealth = utils_health::Add(_Prey, FMars_Health_Spec(100.0f));
        auto PreyZone = utils_hit_zone::Add(_Prey, utils_hit_zone::Make_FleshZoneSpec(GameplayTags::HitZone_Mars_Body, 1.0f));
        utils_hit_zone::AddHurtbox_Box(PreyZone, PreyRoot, FMars_HitZone_Hurtbox(k_PreyHalfExtents, FTransform::Identity));
        _PreyHealth.BindTo_OnDamaged(FMars_Delegate_Health_OnDamaged(this, n"OnRowPreyDamaged"));
    }

    // Server: the prey as the combat target (once), then, once the attack is Idle and would be admitted, one attack at
    // it with fresh selection. True when the start was requested.
    protected bool Request_ServerAttack()
    {
        if (_ServerTargetRequested == false)
        {
            _Crawler.Request_SetCombatTarget(FMars_Request_Crawler_SetCombatTarget(_Prey));
            _ServerTargetRequested = true;
            return false;
        }

        if (_Crawler.Get_HasPendingCombatRequests() || _Crawler.Get_AttackPhase() != EMars_Crawler_AttackPhase::Idle
            || _Crawler.Get_StartRejection(_Prey).IsSet())
        { return false; }

        _Crawler.Request_StartAttack(FMars_Request_Crawler_StartAttack(_Prey));
        return true;
    }

    private int32 _AttacksBeforeRequest = 0;
    private FName _AfterServerAttack;

    // Server: one attack driven at the prey (Request_ServerAttack until one is admitted) and waited back to Idle, then
    // InContinuation. Samples every frame.
    protected void Run_ServerAttack(FName InContinuation)
    {
        _AttacksBeforeRequest = Count_StartedAttacks();
        _AfterServerAttack = InContinuation;
        WaitUntil(n"Is_ServerAttackAdmitted", n"OnServerAttackAdmitted", k_SlowPolls);
    }

    UFUNCTION()
    protected void Is_ServerAttackAdmitted(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        Sample_Crawler();
        const auto Admitted = Count_StartedAttacks() > _AttacksBeforeRequest;
        if (Admitted == false)
        { Request_ServerAttack(); }

        auto Result = OutResult;
        Result.Set(Admitted);
    }

    UFUNCTION()
    private void OnServerAttackAdmitted(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitUntil(n"Is_ServerAttackIdle", _AfterServerAttack, k_SlowPolls);
    }

    // The newest attack went back to Idle.
    UFUNCTION()
    protected void Is_ServerAttackIdle(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        Sample_Crawler();
        auto Result = OutResult;
        Result.Set(_Crawler.Get_AttackPhase() == EMars_Crawler_AttackPhase::Idle && _Attacks.Num() > 0
            && _Attacks.Last().Phases.Num() > 0 && _Attacks.Last().Phases.Last() == EMars_Crawler_AttackPhase::Idle);
    }

    // The newest record that started an action; -1 without one.
    protected int32 Find_LastStartedAttack() const
    {
        for (int32 Index = _Attacks.Num() - 1; Index >= 0; --Index)
        {
            if (_Attacks[Index].Started > 0)
            { return Index; }
        }

        return -1;
    }

    // Server: a hit of InAmount of InType on its copy of the body zone, no instigator.
    protected void Hit_ServerBody(float32 InAmount, FGameplayTag InType)
    {
        _Zone.Request_Hit(FMars_Request_HitZone_Hit(FMars_DamageEvent(InAmount, InType)));
        _HitFrame = int32(utils_time::Get_FrameCounter());
    }

    protected void Request_ServerDisable()
    {
        if (_DisabledFrame >= 0)
        { return; }

        _Crawler.Request_SetAggression(FMars_Request_Crawler_SetAggression(ECk_EnableDisable::Disable));
        _DisabledFrame = int32(utils_time::Get_FrameCounter());
    }

    // The record of InGeneration; added when InAdd and there is none. -1 without one.
    protected int32 Find_Attack(int32 InGeneration, bool InAdd)
    {
        for (int32 Index = 0; Index < _Attacks.Num(); ++Index)
        {
            if (_Attacks[Index].Generation == InGeneration)
            { return Index; }
        }

        if (InAdd == false)
        { return -1; }

        auto Record = FMars_NetCrawlerTest_AttackRecord();
        Record.Generation = InGeneration;
        _Attacks.Add(Record);
        return _Attacks.Num() - 1;
    }

    // The record whose action was InIdentity; -1 without one.
    private int32 Find_AttackByAction(int64 InIdentity)
    {
        for (int32 Index = 0; Index < _Attacks.Num(); ++Index)
        {
            if (InIdentity != 0 && _Attacks[Index].ActionIdentity == InIdentity)
            { return Index; }
        }

        return -1;
    }

    // The entry's id, source clip, slots and the leg index each slot claims.
    private void Take_Entry(int32 InIndex, const FMars_Attack_ResolvedEntry& InEntry)
    {
        auto& Record = _Attacks[InIndex];
        Record.AttackId = InEntry.Identity.Id;
        Record.SourceClip = InEntry.SourceClip.ToSoftObjectPath().ToString();
        Record.Slots = "";
        Record.ClaimedLegs.Reset();
        for (const auto& Slot : InEntry.Slots)
        {
            Record.Slots += f"{Slot.Slot}:{Slot.Binding.LimbId},";
            for (int32 Leg = 0; Leg < _LegRigs.Num(); ++Leg)
            {
                if (_LegRigs[Leg].LegId == Slot.Binding.LimbId)
                { Record.ClaimedLegs.Add(Leg); }
            }
        }
    }

    private FVector Get_PresentationInRoot() const
    {
        const auto Root = utils_transform::Get_EntityCurrentTransform(_Crawler.As_Transform());
        const auto Presentation = utils_transform::Get_EntityCurrentTransform(_Crawler.Get_Presentation());
        return Presentation.GetRelativeTransform(Root).GetLocation();
    }

    private FVector Get_FootInRoot(int32 InLeg) const
    {
        const auto Root = utils_transform::Get_EntityCurrentTransform(_Crawler.As_Transform());
        return Root.InverseTransformPosition(utils_transform::Get_EntityCurrentLocation(_LegRigs[InLeg].Foot));
    }

    // FirstFrame: now, with the presentation and the claimed feet where they stand.
    private void Begin_AttackMotion(int32 InIndex)
    {
        if (_Attacks[InIndex].FirstFrame >= 0)
        { return; }

        auto& Record = _Attacks[InIndex];
        Record.FirstFrame = int32(utils_time::Get_FrameCounter());
        Record.FirstSeconds = Get_WorldSeconds();
        Record.BodyAtFirst = Get_PresentationInRoot();
        Record.FeetAtFirst.Reset();
        for (const auto Leg : Record.ClaimedLegs)
        { Record.FeetAtFirst.Add(Get_FootInRoot(Leg)); }
    }

    // Each new action identity is one start; this machine hears its OnFinished.
    private void Attach_Action(int32 InIndex, FCk_Handle_ProceduralAction InAction)
    {
        auto Action = InAction;
        if (ck::Is_NOT_Valid(Action) || Action.Get_Identity().Get_Value() == _Attacks[InIndex].ActionIdentity)
        { return; }

        auto& Record = _Attacks[InIndex];
        Record.Action = Action;
        Record.ActionIdentity = Action.Get_Identity().Get_Value();
        Record.Started += 1;
        utils_procedural_action::BindTo_OnFinished(Action, FCk_Delegate_ProceduralAction_OnFinished(this, n"OnRowActionFinished"));
    }

    // One ledger this machine saw (a server's write, a copy's notify): logged, and kept on its generation's record.
    private void Note_Ledger(const FMars_Fragment_Crawler_Net& InLedger)
    {
        const auto Frame = int32(utils_time::Get_FrameCounter());
        _LedgerLog += f"{Frame}:{Describe_Ledger(InLedger)} ";
        if (InLedger.AttackGeneration <= 0)
        { return; }

        const auto Index = Find_Attack(InLedger.AttackGeneration, true);
        auto& Record = _Attacks[Index];
        Record.Ledgers.Add(InLedger);
        Record.LedgerFrames.Add(Frame);
        if (Record.NotifyFrame < 0)
        { Record.NotifyFrame = Frame; }

        if (utils_crawler::Get_IsOffensivePhase(InLedger.Phase) && (Record.Notified.IsEmpty() || Record.Notified.Last() != InLedger.Phase))
        { Record.Notified.Add(InLedger.Phase); }

        if (InLedger.Cancelled && Record.CancelFrame < 0)
        {
            Record.CancelFrame = Frame;
            Record.CancelSeconds = Get_WorldSeconds();
        }
    }

    protected FString Describe_Ledger(const FMars_Fragment_Crawler_Net& InLedger) const
    {
        return f"{InLedger.AttackId.ToString()}/{InLedger.AttackGeneration}/{InLedger.Phase :n}/c{InLedger.Cancelled}/h{InLedger.HurtCount}";
    }

    private bool Get_IsLedgerEqual(const FMars_Fragment_Crawler_Net& InA, const FMars_Fragment_Crawler_Net& InB) const
    {
        return InA.AttackId == InB.AttackId && InA.AttackGeneration == InB.AttackGeneration && InA.Phase == InB.Phase
            && InA.Cancelled == InB.Cancelled && InA.HurtCount == InB.HurtCount;
    }

    private void Sample_Attacks()
    {
        const auto Frame = int32(utils_time::Get_FrameCounter());
        _SampleFrames.Add(Frame);
        _SampleSeconds.Add(Get_WorldSeconds());

        if (Get_IsServer())
        {
            const auto Ledger = Get_CopyLedger();
            if (Get_IsLedgerEqual(Ledger, _LedgerLast) == false)
            {
                _LedgerLast = Ledger;
                Note_Ledger(Ledger);
            }

            if (_DisableAfterWindupSeconds.IsSet() && _Attacks.Num() > 0 && _Attacks.Last().FirstSeconds >= 0.0
                && Get_WorldSeconds() - _Attacks.Last().FirstSeconds >= _DisableAfterWindupSeconds.GetValue())
            { Request_ServerDisable(); }
        }
        else
        {
            _CopyEverOutOfIdle = _CopyEverOutOfIdle || _Crawler.Get_AttackPhase() != EMars_Crawler_AttackPhase::Idle;
            if (_CopyHurtFrame < 0 && _Crawler.Get_HurtCount() > 0)
            {
                _CopyHurtFrame = Frame;
                _CopyHurtSeconds = Get_WorldSeconds();
            }
        }

        for (int32 Index = 0; Index < _Attacks.Num(); ++Index)
        { Sample_AttackRecord(Index); }
    }

    private void Sample_AttackRecord(int32 InIndex)
    {
        if (_Attacks[InIndex].FirstFrame < 0 || _Attacks[InIndex].BackAtNeutralFrame >= 0)
        { return; }

        const auto Frame = int32(utils_time::Get_FrameCounter());
        auto& Record = _Attacks[InIndex];
        FCk_Handle ActionEntity = Record.Action;
        const auto ActionGone = Record.ActionIdentity != 0 && (ck::Is_NOT_Valid(ActionEntity)
            || utils_entity_lifetime::Get_IsPendingDestroy(ActionEntity, ECk_EntityLifetime_DestructionPhase::BeginDestroy));
        if (Record.CancelFrame >= 0 && Record.CancelSeenFrame < 0 && Record.ActionIdentity != 0)
        {
            const auto State = ActionGone ? ECk_ProceduralAction_State::Finished : Record.Action.Get_State();
            if (State == ECk_ProceduralAction_State::Cancelling || State == ECk_ProceduralAction_State::Returning
                || State == ECk_ProceduralAction_State::Finished)
            { Record.CancelSeenFrame = Frame; }
        }

        // An action gone without its OnFinished: finished here, outcome None.
        if (ActionGone && Record.Finished == 0 && Record.FinishedFrame < 0)
        {
            Record.FinishedFrame = Frame;
            Record.FinishedSeconds = Get_WorldSeconds();
        }

        const auto Body = (Get_PresentationInRoot() - Record.BodyAtFirst).Size();
        Record.BodyPeak = Math::Max(Record.BodyPeak, Body);
        auto Neutral = Body <= k_NeutralCm;
        auto Subject = _Crawler.Get_Articulation();
        for (int32 Claim = 0; Claim < Record.ClaimedLegs.Num() && Claim < Record.FeetAtFirst.Num(); ++Claim)
        {
            const auto Leg = Record.ClaimedLegs[Claim];
            Record.FootPeak = Math::Max(Record.FootPeak, (Get_FootInRoot(Leg) - Record.FeetAtFirst[Claim]).Size());
            const auto Control = Subject.Get_LimbControl(_LegRigs[Leg].LegId).Get_State();
            const auto Phase = utils_procedural_leg::Get_Foot(_LegParts[Leg].Get_Leg()).Get_Phase();
            Neutral = Neutral && Control == ECk_ProceduralLimbControl_State::Default && Phase == ECk_ProceduralLeg_FootPhase::Planted;
        }

        if (Record.FinishedFrame >= 0 && Neutral)
        {
            Record.BackAtNeutralFrame = Frame;
            Record.BackAtNeutralSeconds = Get_WorldSeconds();
        }
    }

    // This machine's world seconds at InFrame (the first sample at or after it); -1 when none was sampled.
    protected float64 Get_SecondsAtFrame(int32 InFrame) const
    {
        for (int32 Index = 0; Index < _SampleFrames.Num(); ++Index)
        {
            if (_SampleFrames[Index] >= InFrame)
            { return _SampleSeconds[Index]; }
        }

        return -1.0;
    }

    // Server: its records as summaries, with its hit frame and its pawn's readings, on the crawler's root, replicated.
    protected void Publish_ServerAttacks(int32 InStruckGeneration, float32 InPawnHealth, TArray<float32> InPawnApplied)
    {
        if (_CrawlerRoot.Has_Fragment(FMars_TESTONLY_Fragment_Crawler_ServerAttacks))
        { return; }

        auto Readout = FMars_TESTONLY_Fragment_Crawler_ServerAttacks();
        for (const auto& Record : _Attacks)
        {
            if (Record.FirstFrame < 0)
            { continue; }

            auto Summary = FMars_NetCrawlerTest_AttackSummary();
            Summary.Generation = Record.Generation;
            Summary.AttackId = Record.AttackId;
            Summary.SourceClip = Record.SourceClip;
            Summary.Slots = Record.Slots;
            Summary.FirstFrame = Record.FirstFrame;
            Summary.BodyPeak = Record.BodyPeak;
            Summary.FootPeak = Record.FootPeak;
            Readout.Attacks.Add(Summary);
        }

        Readout.HitFrame = _HitFrame;
        Readout.StruckGeneration = InStruckGeneration;
        Readout.PawnHealth = InPawnHealth;
        Readout.PawnApplied = InPawnApplied;
        _CrawlerRoot.Add_Fragment(Readout, ECk_Replication::Replicates);
    }

    protected bool Get_HasServerAttacks()
    {
        return Get_IsCrawlerGone() == false && _CrawlerRoot.Has_Fragment(FMars_TESTONLY_Fragment_Crawler_ServerAttacks);
    }

    protected FMars_TESTONLY_Fragment_Crawler_ServerAttacks Get_ServerAttacks()
    {
        if (Get_HasServerAttacks() == false)
        { return FMars_TESTONLY_Fragment_Crawler_ServerAttacks(); }

        return _CrawlerRoot.Get_Fragment(FMars_TESTONLY_Fragment_Crawler_ServerAttacks);
    }

    // A copy waits on the server's readout this long at most from the wait's start.
    protected const float32 k_ReadoutCeilingSeconds = 22.0f;
    private float64 _AwaitSince = -1.0;
    private float64 _ReadoutSeenSeconds = -1.0;

    // A copy: once the server's readout has been here for a second (the server's last step had that long to arrive),
    // or k_ReadoutCeilingSeconds after this call without one, InContinuation. Samples every frame.
    protected void Await_ServerAttacks(FName InContinuation)
    {
        _AwaitSince = Get_WorldSeconds();
        WaitUntil(n"Is_ServerAttacksSettled", InContinuation, k_SlowPolls);
    }

    UFUNCTION()
    protected void Is_ServerAttacksSettled(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        Sample_Crawler();
        const auto Now = Get_WorldSeconds();
        if (_ReadoutSeenSeconds < 0.0 && Get_HasServerAttacks())
        { _ReadoutSeenSeconds = Now; }

        auto Result = OutResult;
        Result.Set((_ReadoutSeenSeconds >= 0.0 && Now - _ReadoutSeenSeconds >= 1.0) || Now - _AwaitSince >= k_ReadoutCeilingSeconds);
    }

    protected FString Describe_ServerAttacks()
    {
        const auto Readout = Get_ServerAttacks();
        FString Text = "";
        for (const auto& Summary : Readout.Attacks)
        {
            Text += f"[gen {Summary.Generation} {Summary.AttackId.ToString()} clip {Summary.SourceClip} slots {Summary.Slots} "
                + f"first {Summary.FirstFrame} body {Summary.BodyPeak} foot {Summary.FootPeak}] ";
        }

        return f"readout=[present {Get_HasServerAttacks()} seenAt {_ReadoutSeenSeconds} hitFrame {Readout.HitFrame} "
            + f"struck {Readout.StruckGeneration} pawnHealth {Readout.PawnHealth} attacks {Text}]";
    }

    // A copy, against one attack the server published: a record of the same generation, attack, source clip and slot
    // list, one action started for it, its cued phases the posed phases its notifies carried, its body and claimed feet
    // within InTolerance of the server's peaks, and back at neutral within InNeutralSeconds of its OnFinished.
    protected void Assert_CopyPlayedTheServersAttack(const FMars_NetCrawlerTest_AttackSummary& InServer, float64 InTolerance, float64 InNeutralSeconds)
    {
        const auto Index = Find_Attack(InServer.Generation, false);
        if (Index < 0)
        {
            Assert_True(false, f"the client recorded the server's generation {InServer.Generation}");
            return;
        }

        const auto Record = _Attacks[Index];
        const auto Gen = InServer.Generation;
        Assert_True(Record.AttackId == InServer.AttackId && Record.SourceClip == InServer.SourceClip && Record.Slots == InServer.Slots,
            f"gen {Gen}: the copy played the server's attack, clip and slots (copy {Record.AttackId.ToString()} {Record.SourceClip} {Record.Slots}; server {InServer.AttackId.ToString()} {InServer.SourceClip} {InServer.Slots})");
        Assert_Equals_Int(Record.Started, 1, f"gen {Gen}: the copy started one action for it");
        Assert_True(Get_IsPosedSubsequence(Record.Phases) && Describe_Phases(Record.Phases) == Describe_Phases(Record.Notified),
            f"gen {Gen}: the copy cued each posed phase its notifies carried, once, in order (cued {Describe_Phases(Record.Phases)} notified {Describe_Phases(Record.Notified)})");
        Assert_True(Math::Abs(Record.BodyPeak - InServer.BodyPeak) <= InTolerance * InServer.BodyPeak,
            f"gen {Gen}: the copy's body peak is within {InTolerance * 100.0} percent of the server's ({Record.BodyPeak} against {InServer.BodyPeak})");
        Assert_True(Math::Abs(Record.FootPeak - InServer.FootPeak) <= InTolerance * InServer.FootPeak,
            f"gen {Gen}: the copy's claimed-foot peak is within {InTolerance * 100.0} percent of the server's ({Record.FootPeak} against {InServer.FootPeak})");
        Assert_True(Record.BackAtNeutralSeconds >= 0.0 && Record.BackAtNeutralSeconds - Record.FinishedSeconds <= InNeutralSeconds,
            f"gen {Gen}: the copy is back at neutral within {InNeutralSeconds} s of its OnFinished ({Record.BackAtNeutralSeconds - Record.FinishedSeconds} s, neutral frame {Record.BackAtNeutralFrame})");
    }

    // A copy, for a cancelled attack: its action was created before the cancel arrived, reads Cancelling, Returning or
    // Finished within ten frames of that notify, finished once short of Completed, raised Admitted and Interrupted once
    // and Completed never, cued no Recover after the cancel, and is back at neutral within 1.5 s of its OnFinished.
    protected void Assert_CopyCancelledTheAttack(int32 InGeneration)
    {
        const auto Index = Find_Attack(InGeneration, false);
        if (Index < 0)
        {
            Assert_True(false, f"the client recorded the server's generation {InGeneration}");
            return;
        }

        const auto Record = _Attacks[Index];
        Assert_True(Record.FirstFrame >= 0 && Record.CancelFrame >= 0 && Record.FirstFrame <= Record.CancelFrame,
            f"the copy's action was created before the cancel arrived (created {Record.FirstFrame}, cancel notify {Record.CancelFrame})");
        Assert_True(Record.CancelSeenFrame >= 0 && Record.CancelSeenFrame - Record.CancelFrame <= 10,
            f"the copy's action reads Cancelling, Returning or Finished within ten frames of the cancel (cancel {Record.CancelFrame}, seen {Record.CancelSeenFrame})");
        Assert_Equals_Int(Record.Finished, 1, "the copy's action raised OnFinished once");
        Assert_True(Record.Outcome != ECk_ProceduralAction_Outcome::Completed, f"the copy's action ended short of Completed ({Record.Outcome :n})");
        Assert_True(Record.Admitted == 1 && Record.Interrupted == 1 && Record.Completed == 0,
            f"the copy raised Admitted 1, Interrupted 1, Completed 0 (raised {Record.Admitted}/{Record.Interrupted}/{Record.Completed})");
        Assert_False(Record.RecoverCuedAfterInterrupt, "the copy cued no Recover after the cancel");
        Assert_True(Record.BackAtNeutralSeconds >= 0.0 && Record.BackAtNeutralSeconds - Record.FinishedSeconds <= 1.5,
            f"the copy is back at neutral within 1.5 s of its OnFinished ({Record.BackAtNeutralSeconds - Record.FinishedSeconds} s)");
    }

    // The records that started an action on this machine.
    protected int32 Count_StartedAttacks() const
    {
        auto Count = 0;
        for (const auto& Record : _Attacks)
        {
            if (Record.Started > 0)
            { Count += 1; }
        }

        return Count;
    }

    protected FString Describe_Phases(const TArray<EMars_Crawler_AttackPhase>& InPhases) const
    {
        FString Text = "";
        for (const auto Phase : InPhases)
        { Text += f"{Phase :n},"; }

        return Text;
    }

    // Each of InPhases is a posed phase later than the one before it.
    protected bool Get_IsPosedSubsequence(const TArray<EMars_Crawler_AttackPhase>& InPhases) const
    {
        auto Last = -1;
        for (const auto Phase : InPhases)
        {
            if (utils_crawler::Get_IsOffensivePhase(Phase) == false || int32(Phase) <= Last)
            { return false; }

            Last = int32(Phase);
        }

        return true;
    }

    protected FString Describe_Attacks()
    {
        FString Text = "";
        for (const auto& Record : _Attacks)
        {
            FString Ledgers = "";
            for (int32 Index = 0; Index < Record.Ledgers.Num(); ++Index)
            { Ledgers += f"{Record.LedgerFrames[Index]}:{Record.Ledgers[Index].Phase :n}/c{Record.Ledgers[Index].Cancelled}/h{Record.Ledgers[Index].HurtCount},"; }

            Text += f"[gen {Record.Generation} {Record.AttackId.ToString()} clip {Record.SourceClip} slots {Record.Slots} "
                + f"first {Record.FirstFrame} phases {Describe_Phases(Record.Phases)} cues {Record.Admitted}/{Record.Interrupted}/{Record.Completed} "
                + f"recoverAfterInterrupt {Record.RecoverCuedAfterInterrupt} started {Record.Started} finished {Record.Finished} "
                + f"outcome {Record.Outcome :n} finishedFrame {Record.FinishedFrame} body {Record.BodyPeak} foot {Record.FootPeak} "
                + f"neutralFrame {Record.BackAtNeutralFrame} neutralAfter {Record.BackAtNeutralSeconds - Record.FinishedSeconds} "
                + f"notify {Record.NotifyFrame} notified {Describe_Phases(Record.Notified)} cancel {Record.CancelFrame} "
                + f"cancelSeen {Record.CancelSeenFrame} lastCancelAtIdle {Record.LastCancelAtIdle} committed {Record.CommittedAtIdle} "
                + f"ledgers {Ledgers}] ";
        }

        return Text;
    }

    protected FString Describe_AttackState()
    {
        if (Get_IsCrawlerGone())
        { return "attack=[gone]"; }

        FString Applied = "";
        for (const auto Amount : _PreyApplied)
        { Applied += f"{Amount},"; }

        const auto PreyHealth = ck::IsValid(_PreyHealth) ? _PreyHealth.Get_Current() : -1.0f;
        return f"attack=[armed {_Crawler.Get_IsCombatArmed()} player {ck::IsValid(_Crawler.Get_ActionPlayer())} "
            + f"ledger {Describe_Ledger(Get_CopyLedger())} initialAtFind {_LedgerInitialAtFind :n} stood {Get_CopyStoodGeneration()} "
            + f"show {Get_HasCopyShow()} copyStarted {Get_CopyStarted()} hurt {_Crawler.Get_HurtCount()} copyHurtFrame {_CopyHurtFrame} "
            + f"hitFrame {_HitFrame} disabledFrame {_DisabledFrame} cues {_AttackCues} everOutOfIdle {_CopyEverOutOfIdle} "
            + f"prey [health {PreyHealth} damaged {_PreyApplied.Num()} applied {Applied}] notifies {_LedgerNotifies} "
            + f"ledgerLog [{_LedgerLog}] records {Describe_Attacks()}]";
    }

    // A copy plays, and keeps nothing it could attack with: not armed, no combat, attack, observation, intent or
    // request state, no dealer, its kernel Idle at every sample, its gait Ready and never Failed and four legs enabled.
    protected void Assert_CopyKeepsNoAttackOfItsOwn()
    {
        Assert_True(ck::IsValid(_Crawler.Get_ActionPlayer()), "the client's copy composes an action player");
        Assert_False(_Crawler.Get_IsCombatArmed(), "the client's copy is not armed");
        Assert_False(_CrawlerRoot.Has_Fragment(FMars_Fragment_Crawler_Combat) || _CrawlerRoot.Has_Fragment(FMars_Fragment_Crawler_Attack)
            || _CrawlerRoot.Has_Fragment(FMars_Fragment_Crawler_AttackObservations) || _CrawlerRoot.Has_Fragment(FMars_Fragment_Crawler_AttackIntents)
            || _CrawlerRoot.Has_Fragment(FMars_Fragment_Crawler_Requests),
            "the client's copy has no combat, attack, observation, intent or request state");
        Assert_False(ck::IsValid(_Crawler.Get_CombatDealer()), "the client's copy has no damage dealer");
        Assert_False(_CopyEverOutOfIdle, "the client's copy's kernel read Idle at every sample");
        Assert_True(Get_GaitStatus() == ECk_ProceduralAnimation_Status::Ready, "the client's gait reads Ready");
        Assert_False(_CrawlerGaitEverFailed, "the client's gait never read Failed");
        Assert_Equals_Int(utils_procedural_gait::Get_EnabledLegCount(_Crawler.Get_Gait()), _LegCount, f"the client's {_LegCount} legs are enabled");
    }

    // A copy's decoy: nothing the copy did touched it.
    protected void Assert_DecoyUntouched()
    {
        Assert_True(ck::IsValid(_PreyHealth) && Math::IsNearlyEqual(_PreyHealth.Get_Current(), 100.0f, 0.01f),
            "the client's decoy reads 100");
        Assert_Equals_Int(_PreyApplied.Num(), 0, "the client's decoy raised no OnDamaged");
    }

    UFUNCTION()
    private void OnRowPreyDamaged(FCk_Handle_Health InHealth, FMars_DamageEvent InEvent, float32 InApplied, float32 InRemaining)
    {
        _PreyApplied.Add(InApplied);
    }

    // Server only: Windup opens the admission's record, every phase is appended to the newest record, and the row's
    // hit or aggression switch fires at Strike.
    UFUNCTION()
    private void OnRowAttackPhaseChanged(FCk_Handle_Crawler InCrawler, EMars_Crawler_AttackPhase InOld, EMars_Crawler_AttackPhase InNew)
    {
        if (InNew == EMars_Crawler_AttackPhase::Windup)
        {
            const auto Index = Find_Attack(_Crawler.Get_AttackAdmission().AttemptGeneration, true);
            Take_Entry(Index, _Crawler.Get_AttackPlan().Entry);
            Begin_AttackMotion(Index);
            Attach_Action(Index, _Crawler.Get_AttackAction());
        }

        if (_Attacks.Num() == 0)
        { return; }

        const auto Last = _Attacks.Num() - 1;
        _Attacks[Last].Phases.Add(InNew);
        if (InNew == EMars_Crawler_AttackPhase::Idle)
        {
            const auto LastCancel = _Crawler.Get_AttackLastCancel();
            _Attacks[Last].LastCancelAtIdle = LastCancel.IsSet() ? f"{LastCancel.GetValue() :n}" : FString("");
            _Attacks[Last].CommittedAtIdle = _Crawler.Get_AttackDamageCommitted();
        }

        if (InNew != EMars_Crawler_AttackPhase::Strike)
        { return; }

        if (_HurtAtStrike.IsSet() && _HitFrame < 0)
        { Hit_ServerBody(_HurtAtStrike.GetValue(), GameplayTags::DamageType_Mars_Blunt); }

        if (_DisableAfterWindupSeconds.IsSet())
        { Request_ServerDisable(); }
    }

    // Both machines count the batches per generation; a copy's Admitted opens its record on its action, and its posed
    // observations are its phases.
    UFUNCTION()
    private void OnRowAttackCue(FCk_Handle_Crawler InCrawler, FMars_Attack_CueBatch InBatch)
    {
        _AttackCues += 1;
        const auto Index = Find_Attack(InBatch.AdmissionAttemptGeneration, true);
        if (InBatch.Admitted)
        {
            _Attacks[Index].Admitted += 1;
            if (Get_IsServer() == false)
            {
                const auto Entry = utils_crawler::Find_ResolvedAttack(_Crawler.Get_Spec().ResolvedAttacks, InBatch.AttackId);
                if (Entry.IsSet())
                { Take_Entry(Index, Entry.GetValue()); }

                Begin_AttackMotion(Index);
                Attach_Action(Index, Get_CopyAction());
            }
        }

        if (InBatch.Interrupted)
        { _Attacks[Index].Interrupted += 1; }

        if (InBatch.Completed)
        { _Attacks[Index].Completed += 1; }

        if (Get_IsServer())
        { return; }

        for (const auto& Observation : InBatch.Observations)
        {
            const auto PhaseId = Observation.Interval.Get_PhaseId();
            auto Phase = EMars_Crawler_AttackPhase::Idle;
            if (PhaseId == InBatch.Motion.WindupPhase)
            { Phase = EMars_Crawler_AttackPhase::Windup; }
            else if (PhaseId == InBatch.Motion.StrikePhase)
            { Phase = EMars_Crawler_AttackPhase::Strike; }
            else if (PhaseId == InBatch.Motion.RecoverPhase)
            { Phase = EMars_Crawler_AttackPhase::Recover; }

            _Attacks[Index].Phases.Add(Phase);
            if (Phase == EMars_Crawler_AttackPhase::Recover && _Attacks[Index].Interrupted > 0)
            { _Attacks[Index].RecoverCuedAfterInterrupt = true; }
        }
    }

    UFUNCTION()
    private void OnRowActionFinished(FCk_Handle_ProceduralAction InAction, FCk_ProceduralAction_Terminal InTerminal)
    {
        const auto Index = Find_AttackByAction(InTerminal.Get_Identity().Get_Value());
        if (Index < 0)
        { return; }

        _Attacks[Index].Finished += 1;
        _Attacks[Index].Outcome = InTerminal.Get_Result().Get_Outcome();
        if (_Attacks[Index].FinishedFrame < 0)
        {
            _Attacks[Index].FinishedFrame = int32(utils_time::Get_FrameCounter());
            _Attacks[Index].FinishedSeconds = Get_WorldSeconds();
        }
    }

    // A notify can land on a crawler already ending.
    UFUNCTION()
    private void OnRowLedgerNotify(FCk_Handle InHandle, FCk_DynamicFragment_RepNotifyInfo InInfo)
    {
        if (ck::Is_NOT_Valid(InHandle) || InHandle.Has_Fragment(FMars_Fragment_Crawler_Net) == false)
        { return; }

        _LedgerNotifies += 1;
        const auto Ledger = InHandle.Get_Fragment(FMars_Fragment_Crawler_Net);
        Note_Ledger(Ledger);
    }

    //----------------------------------------------------------------------------------------------------------------------
    // The shared clock and the server's readout
    //----------------------------------------------------------------------------------------------------------------------

    private void Sample_Clock()
    {
        const auto Frame = int32(utils_time::Get_FrameCounter());
        if (_ClockFrames.Num() > 0 && _ClockFrames.Last() == Frame)
        { return; }

        _ClockFrames.Add(Frame);
        _ClockSeconds.Add(Get_WorldSeconds());
    }

    // This machine's world seconds at InFrame (its first sample at or after it); -1 when it sampled none.
    protected float64 Get_ClockSecondsAtFrame(int32 InFrame) const
    {
        if (InFrame < 0)
        { return -1.0; }

        for (int32 Index = 0; Index < _ClockFrames.Num(); ++Index)
        {
            if (_ClockFrames[Index] >= InFrame)
            { return _ClockSeconds[Index]; }
        }

        return -1.0;
    }

    // The seconds between two frames on this machine's clock; -1 when either was not sampled.
    protected float64 Get_SecondsBetweenFrames(int32 InFrom, int32 InTo) const
    {
        const auto From = Get_ClockSecondsAtFrame(InFrom);
        const auto To = Get_ClockSecondsAtFrame(InTo);
        return From < 0.0 || To < 0.0 ? -1.0 : To - From;
    }

    // Server: the spec it composed, on the crawler's root, replicated (once).
    protected void Publish_ServerReadout()
    {
        auto Root = _CrawlerRoot;
        if (Root.Has_Fragment(FMars_TESTONLY_Fragment_Crawler_ServerReadout))
        { return; }

        const auto Spec = _Crawler.Get_Spec();
        auto Readout = FMars_TESTONLY_Fragment_Crawler_ServerReadout();
        Readout.LegCount = Spec.LegCount;
        Readout.Layout = Spec.Layout;
        Readout.RoamBounds = Spec.RoamBounds;
        Readout.CombatEnabled = Spec.Combat.Enabled;
        Readout.BodyHalfExtents = Spec.Rig.BodyHalfExtents;
        Readout.HomeRadius = Spec.Combat.Targeting.HomeRadius;
        Readout.AcquireRadius = Spec.Combat.Targeting.AcquireRadius;
        Root.Add_Fragment(Readout, ECk_Replication::Replicates);
        _Readout = Readout;
        _HasReadout = true;
    }

    // Server: InName marked at InFrame on the readout (published first if it was not).
    protected void Publish_ServerMark(FString InName, int32 InFrame)
    {
        Publish_ServerReadout();
        auto Root = _CrawlerRoot;
        auto& Readout = Root.Get_Fragment(FMars_TESTONLY_Fragment_Crawler_ServerReadout);
        auto Mark = FMars_NetCrawlerTest_Mark();
        Mark.Name = InName;
        Mark.Frame = InFrame;
        Readout.Marks.Add(Mark);
        Root.Request_MarkReplicationDirty(FMars_TESTONLY_Fragment_Crawler_ServerReadout);
        _Readout = Readout;
    }

    // The frame the server marked InName at, as this machine last read the readout; -1 without it.
    protected int32 Get_ServerMark(FString InName) const
    {
        for (const auto& Mark : _Readout.Marks)
        {
            if (Mark.Name == InName)
            { return Mark.Frame; }
        }

        return -1;
    }

    protected FString Describe_Readout() const
    {
        FString Marks = "";
        for (const auto& Mark : _Readout.Marks)
        { Marks += f"{Mark.Name}@{Mark.Frame},"; }

        return f"readoutSpec=[present {_HasReadout} legs {_Readout.LegCount} layout {_Readout.Layout :n} bounds {_Readout.RoamBounds.Min}/{_Readout.RoamBounds.Max} "
            + f"combat {_Readout.CombatEnabled} body {_Readout.BodyHalfExtents} home {_Readout.HomeRadius} acquire {_Readout.AcquireRadius} marks {Marks}]";
    }

    private FString _AwaitedMark = "";

    // Off authority: once the server's readout carries InMark (InMark empty: once the readout is here), InContinuation.
    // Samples every frame.
    protected void Await_ServerMark(FString InMark, FName InContinuation)
    {
        _AwaitedMark = InMark;
        WaitUntil(n"Is_ServerMarkHere", InContinuation, k_SlowPolls);
    }

    UFUNCTION()
    protected void Is_ServerMarkHere(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        Sample_Crawler();
        auto Result = OutResult;
        Result.Set(_HasReadout && (_AwaitedMark.IsEmpty() || Get_ServerMark(_AwaitedMark) >= 0));
    }

    protected bool Get_IsNearlyEqualVector(FVector InA, FVector InB, float64 InTolerance) const
    {
        return Math::Abs(InA.X - InB.X) <= InTolerance && Math::Abs(InA.Y - InB.Y) <= InTolerance && Math::Abs(InA.Z - InB.Z) <= InTolerance;
    }

    // A copy, against the server's readout: no authority over its root; no surface motion, navigator, brain or state
    // machine; its gait Ready and never Failed; and the server's LegCount, Layout, RoamBounds (within 0.01) and
    // Combat.Enabled in its own spec.
    protected void Assert_CopyLikeTheServer()
    {
        if (Get_IsCrawlerGone())
        {
            Assert_True(false, "the client's copy is here to compare against the server's readout");
            return;
        }

        Assert_True(_HasReadout, "the server's readout reached the client");
        Assert_False(utils_net::Get_HasAuthority(_CrawlerRoot), "the client has no authority over its root");
        Assert_False(ck::IsValid(_Crawler.Get_Motion()), "the client's copy has no surface motion");
        Assert_False(ck::IsValid(_Crawler.Get_Navigator()), "the client's copy has no navigator");
        Assert_False(ck::IsValid(_CrawlerRoot.As_Brain(ECk_SanityCheck::UnChecked)), "the client's copy has no brain");
        Assert_False(ck::IsValid(_CrawlerRoot.As_StateMachine(ECk_SanityCheck::UnChecked)), "the client's copy has no state machine");
        Assert_True(Get_GaitStatus() == ECk_ProceduralAnimation_Status::Ready, "the client's gait reads Ready");
        Assert_False(_CrawlerGaitEverFailed, "the client's gait never read Failed");

        const auto Spec = _Crawler.Get_Spec();
        Assert_Equals_Int(Spec.LegCount, _Readout.LegCount, "the client's copy has the server's LegCount");
        Assert_True(Spec.Layout == _Readout.Layout, f"the client's copy has the server's Layout ({Spec.Layout :n} against {_Readout.Layout :n})");
        Assert_True(Get_IsNearlyEqualVector(Spec.RoamBounds.Min, _Readout.RoamBounds.Min, 0.01)
            && Get_IsNearlyEqualVector(Spec.RoamBounds.Max, _Readout.RoamBounds.Max, 0.01),
            f"the client's copy has the server's RoamBounds ({Spec.RoamBounds.Min}/{Spec.RoamBounds.Max} against {_Readout.RoamBounds.Min}/{_Readout.RoamBounds.Max})");
        Assert_True(Spec.Combat.Enabled == _Readout.CombatEnabled, f"the client's copy has the server's Combat.Enabled ({Spec.Combat.Enabled})");
    }

    // The C1 shape for the row's leg count: InLegs attached and registered, a body Health of 120 and each leg's zone
    // addressed through its root.
    protected void Assert_CopyComposedWithLegs(int32 InLegs)
    {
        Assert_Equals_Int(Get_AttachedLegs(), InLegs, f"the client's {InLegs} legs are attached");
        Assert_Equals_Int(_CrawlerMonster.Get_Parts().Num(), InLegs, f"the client's monster lists {InLegs} parts");
        Assert_Equals_Int(_Crawler.Get_Spec().LegCount, InLegs, f"the client's copy was spawned with LegCount {InLegs}");
        Assert_True(Math::IsNearlyEqual(_Health.Get_Current(), 120.0f, 0.01f), f"the client's body Health reads 120 ({_Health.Get_Current()})");
        for (int32 Index = 0; Index < _LegParts.Num(); ++Index)
        {
            const auto Zone = _LegParts[Index].Get_Zone();
            const auto Address = Zone.Get_Address();
            Assert_True(Address.Root == _CrawlerRoot && Address.Index == Index + 1,
                f"the client's leg {Index} zone's address is its root and {Index + 1} (reads {Address.Index})");
            Assert_True(utils_hit_zone::TryGet_ZoneAt(Address) == Zone, f"the client's leg {Index} zone's address resolves back to it");
        }
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Server: an anchor of a family, local to it, resolving a pinned row
    //----------------------------------------------------------------------------------------------------------------------

    // The test entity: a local anchor is its child.
    protected FCk_Handle _Runner;
    protected FCk_Handle _Anchor;
    private int32 _AnchorRow = 0;
    private EMars_Anchor_Role _AnchorRole = EMars_Anchor_Role::Other;

    // An anchor of InClass at the crawler's spot, local to the server and the runner's, pinned to InRow; once it is
    // constructed it resolves InRow as InRole with its own context.
    protected void Spawn_ServerAnchor(TSubclassOf<UCk_EntityScript_UE> InClass, int32 InRow, EMars_Anchor_Role InRole)
    {
        _AnchorRow = InRow;
        _AnchorRole = InRole;
        auto Params = FMars_TESTONLY_AnchorSpawnParams();
        Params.SpawnTransform = FTransform(FRotator::ZeroRotator, _CrawlerAt);
        Params.AnchorId = GameplayTags::Anchor_Mars_Test_A;
        Params.Channel = GameplayTags::ResolveGameplayTag(n"Mechanism.Channel.Anchor.Test.A");
        Params.PinnedRow = TOptional<int32>(InRow);
        auto Pending = utils_entity_script::Request_SpawnEntity(_Runner, InClass, Params);
        utils_pending_entity_script::Promise_OnConstructed(Pending, FCk_Delegate_EntityScript_Constructed(this, n"OnServerAnchorConstructed"));
    }

    UFUNCTION()
    private void OnServerAnchorConstructed(FCk_Handle_EntityScript InEntityScriptHandle)
    {
        _Anchor = FCk_Handle(InEntityScriptHandle);
        auto Anchor = _Anchor.As_Anchor();
        auto Context = FMars_Anchor_Context();
        Context.AnchorId = Anchor.Get_AnchorId();
        Context.Channel = Anchor.Get_Channel();
        Context.SpanCm = Anchor.Get_SpanCm();
        Context.HomeRadiusCm = Anchor.Get_HomeRadiusCm();
        Anchor.Request_Resolve(FMars_Request_Anchor_Resolve(_AnchorRow, _AnchorRole, Context));
    }

    // Server: the anchor's spawned candidate is this machine's crawler.
    protected bool Get_IsAnchorsCrawler()
    {
        if (ck::Is_NOT_Valid(_Anchor) || Get_IsCrawlerGone())
        { return false; }

        const auto Anchor = _Anchor.As_Anchor(ECk_SanityCheck::UnChecked);
        return ck::IsValid(Anchor) && Anchor.Get_Spawned() == _CrawlerRoot;
    }

    protected void Request_ServerClearAnchor()
    {
        auto Anchor = _Anchor.As_Anchor();
        Anchor.Request_Clear(FMars_Request_Anchor_Clear());
    }

    protected FString Describe_Anchor()
    {
        if (ck::Is_NOT_Valid(_Anchor))
        { return f"anchor=[none here {Count_AnchorsNear()}]"; }

        const auto Anchor = _Anchor.As_Anchor(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(Anchor))
        { return "anchor=[gone]"; }

        const auto Spawned = Anchor.Get_Spawned();
        const auto Replicates = ck::IsValid(Spawned) && utils_mars_net::Get_ReplicatesHere(Spawned);
        return f"anchor=[family {Anchor.Get_Family() :n} state {Anchor.Get_State() :n} role {Anchor.Get_Role() :n} home {Anchor.Get_HomeRadiusCm()} "
            + f"spawnedIsCrawler {Get_IsAnchorsCrawler()} replicates {Replicates} near {Count_AnchorsNear()}]";
    }

    // The anchors (TAG_MarsAnchor) near the base on this machine.
    protected int32 Count_AnchorsNear()
    {
        auto Count = 0;
        for (auto Candidate : utils_entity_tag::ForEach_Entity(Get_SubjectEntity(), n"TAG_MarsAnchor"))
        {
            if (Get_IsNear(Candidate, _CrawlerAt))
            { Count += 1; }
        }

        return Count;
    }

    //----------------------------------------------------------------------------------------------------------------------
    // A lever, placed by the server, engaged by a client's cue
    //----------------------------------------------------------------------------------------------------------------------

    protected FCk_Handle_Control _Lever;

    // Server: the lever of InClass at InTransform under the replicated spawn owner, with nothing but its transform
    // injected (its class's own channel and behaviour stand).
    protected void Spawn_ServerLever(TSubclassOf<UCk_EntityScript_UE> InClass, FTransform InTransform)
    {
        auto Params = FMars_TESTONLY_NetCrawler_LeverSpawnParams();
        Params.SpawnTransform = InTransform;
        utils_entity_script::Request_SpawnEntity(utils_mars_net::Get_ReplicatedSpawnOwner(Get_SubjectEntity()), InClass, Params);
    }

    // This machine's lever (TAG_MarsLever) within k_NearCm of InAt; the server tracks it the first time.
    protected bool Get_IsLeverFound(FVector InAt)
    {
        if (ck::IsValid(_Lever))
        { return true; }

        for (auto Candidate : utils_entity_tag::ForEach_Entity(Get_SubjectEntity(), n"TAG_MarsLever"))
        {
            if (Get_IsNear(Candidate, InAt) == false)
            { continue; }

            const auto Control = Candidate.As_Control(ECk_SanityCheck::UnChecked);
            if (ck::Is_NOT_Valid(Control))
            { continue; }

            _Lever = Control;
            if (Get_IsServer())
            { Track_ForCleanup(Candidate); }

            return true;
        }

        return false;
    }

    // A client: the control's engage cue on its copy of the lever, to the server.
    protected void Fire_LeverEngageCue()
    {
        utils_cue_generic::Request_ExecuteCue(_Lever, GameplayTags::Cue_Mars_Control_Engage, UMars_Cue_Control_Engage::Params(),
            ECk_Cue_ReliabilityPolicy::Reliable, ECk_Cue_MulticastPolicy::ServerOnly);
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

            Heights += f"{Get_HeightOverFloor(utils_transform::Get_EntityCurrentLocation(Part))},";
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
            RootText = f"{Root.X - _CrawlerAt.X},{Root.Y - _CrawlerAt.Y},{Get_HeightOverFloor(Root)}";
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
        Assert_Equals_Int(Get_NewEnsures(), 0, f"no ensure in this PIE process (both machines share the counter), on the {Get_MachineName()}");
        FinishSuccess();
    }

    // Server: the row's log line and no ensure, then the hold after its last write before it finishes.
    protected void Hold_CrawlerServerRow(FString InRow, FString InExtra)
    {
        Log_CrawlerRow(InRow, InExtra);
        Assert_Equals_Int(Get_NewEnsures(), 0, "no ensure in this PIE process (both machines share the counter), on the server");
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
