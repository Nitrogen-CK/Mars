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

// The crawler net tests' shared steps, on top of the strike rig (whose striker only the strike row composes): each
// machine lays its own static floor owned by its subject (a copy's walker finds its ground in this machine's world);
// the server spawns a 4-leg crawler through its real entity script under the replicated spawn owner (its root 65
// above the floor, facing +X, without visuals, combat off). Each machine finds its copy by tag near where it was
// spawned, takes its leg parts in order and every leg's rig parts (segments, then the foot), counts what each of its
// own parts and its monster raise and the OnDamaged of its body Health, records the part ledger's rep-notifies off
// authority, and samples its copy from the row's polled predicates: the root's path and largest step, its farthest
// offset from the base, whether its gait ever read Failed and, between Begin_FeetRecord and the row's end, the feet
// of its attached legs. A severed limb is world-owned on every machine: a row ends only once no rig part of a
// severed leg is still valid there.
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

    // 4 legs roaming the box of InRoamHalfExtent around the crawler, dwelling 0.3 s, a severed limb living 2 s, combat
    // off.
    protected FMars_Crawler_Spec Make_RowSpec(FVector InRoamHalfExtent) const
    {
        auto Spec = FMars_Crawler_Spec(k_LegCount, FBox(_CrawlerAt - InRoamHalfExtent, _CrawlerAt + InRoamHalfExtent));
        Spec.RoamDwellSeconds = 0.3f;
        Spec.Vitals.LegDebris.LifetimeSeconds = 2.0f;
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

    // Every rig part of every severed leg is gone on this machine.
    UFUNCTION()
    protected void Is_SeveredLimbsGone(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        Sample_Crawler();
        auto Result = OutResult;
        Result.Set(Get_HasSeveredLimbLeft() == false);
    }

    protected bool Get_HasSeveredLimbLeft()
    {
        for (int32 Index = 0; Index < _LegRigs.Num(); ++Index)
        {
            if (_LegSignals[Index].Severed == 0 && Get_IsPartState(Index, EMars_BodyPart_State::Severed) == false)
            { continue; }

            if (Get_ValidRigParts(Index) > 0)
            { return true; }
        }

        return false;
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

    // Once its part 0 reads Severed: within ten frames leg 0 left its copy, raising OnSevered once with its zone off; a
    // second later the other legs walk on; then the limb dies on this machine and the row finishes.
    protected void Follow_ClientLeg0Sever(FString InRow)
    {
        _SeverRow = InRow;
        WaitUntil(n"Is_Leg0Severed", n"OnClientLeg0Severed", k_SlowPolls);
    }

    UFUNCTION()
    private void OnClientLeg0Severed(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _ClientSeveredFrame = int32(utils_time::Get_FrameCounter());
        WaitFrames(10, n"OnClientLeg0TenFrames");
    }

    UFUNCTION()
    private void OnClientLeg0TenFrames(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_Equals_Int(_LegSignals[0].Severed, 1, "the client's part 0 raised OnSevered once");
        Assert_False(Get_IsLegAttached(0), "the client's leg 0 is not attached");
        Assert_False(Get_IsPartZoneEnabled(0), "the client's part 0 zone is disabled");
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

        Log_CrawlerRow(_SeverRow, f"settled severedFrame={_ClientSeveredFrame}");
        WaitUntil(n"Is_SeveredLimbsGone", n"OnClientLeg0LimbGone", k_SlowPolls);
    }

    UFUNCTION()
    private void OnClientLeg0LimbGone(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Lived = _LegSignals[0].Seconds < 0.0 ? -1.0 : Get_WorldSeconds() - _LegSignals[0].Seconds;
        Finish_CrawlerRow(_SeverRow, f"severedFrame={_ClientSeveredFrame} limbLived={Lived}");
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
        const auto Line = f"[CrawlerNetTest] {InRow} {Get_MachineName()} authority={Authority} composed=[{Describe_Composed()}] gait={GaitText} everFailed={_CrawlerGaitEverFailed} bodyPose={PoseText} trusted={Get_Trusted()} attached={Get_AttachedLegs()} legs={Describe_Legs()}body=[{BodyText} damaged={_BodyDamaged} died={_CrawlerDied} diedFrame={_CrawlerDiedFrame}] root=[{RootText}] initialAtFind={_RosterInitialAtFind :n} initial={Get_RosterInitialState() :n} notifies=[{_RosterNotifies}] {Describe_Feet()} path={_CrawlerPath} largestStep={_CrawlerLargestStep} farthest={_CrawlerFarthestX},{_CrawlerFarthestY} tally=[applied {Tally.Applied} refused {Tally.Refused}] actions={_LegActions} foundFrame={_CrawlerFoundFrame} ensures={Get_NewEnsures()} frame={utils_time::Get_FrameCounter()} {InExtra} {_RowExtra}";
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
