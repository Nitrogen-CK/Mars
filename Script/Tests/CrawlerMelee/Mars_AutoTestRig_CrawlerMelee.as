// The crawler-melee rig. Floor and crawler are the crawler rig's recipe (Script/Tests/Crawler/Mars_AutoTestRig_Crawler.as):
// a crawler spawned through its real entity script, without visuals, 65 uu above a runtime static Jolt floor
// (3000 x 3000 uu, top face at _Origin.Z). It adds what the melee tests stand on: a tagged damageable target (the shape
// a combat target has to have for the crawler to find and hurt it), a static Jolt wall, settling steps that leave an
// armed crawler standing still, target placement relative to its neutral hit centre, a record of every attack phase
// change, and one-shot triggers timed against the attack's own state. Each test sets _Origin to its own isolated spot:
// the Mars autotest map has no floor there, and nothing else in the map is near it.
//
// Also here: a test-only processor in FGroup_Overlap, ordered after the five probe processors that synchronize probe
// bodies with their entities, which runs a zero-travel sphere query every tick and records what it saw and on which
// frame, with the crawler hit query's settings. It is how a test proves that a script processor placed where the crawler's hit resolver will run sees a
// hurtbox at the location it was moved to THIS frame. Only entities carrying FMars_TESTONLY_CrawlerMelee_OverlapSample
// are visited, so it costs nothing to any other test.

// One OnAttackPhaseChanged, with what the crawler's public getters read when it fired.
struct FMars_AutoTest_CrawlerMelee_PhaseRecord
{
    EMars_Crawler_AttackPhase Old = EMars_Crawler_AttackPhase::Idle;
    EMars_Crawler_AttackPhase New = EMars_Crawler_AttackPhase::Idle;
    int64 Frame = -1;
    int32 Generation = 0;
    bool DamageCommitted = false;
    int64 CommittedSampleId = 0;
    int64 AcknowledgedSampleId = 0;
    // The game offset whose correlated accepted receipt caused this phase transition.
    FVector ActionOffset = FVector::ZeroVector;
    int32 DamageRequests = 0;
    TOptional<EMars_Crawler_AttackCancel> LastCancel;
    // How the crawler stood and what its behaviour was doing.
    FVector RootLocation = FVector::ZeroVector;
    FVector RootForward = FVector::ZeroVector;
    float64 Speed = 0.0;
    bool NavigatorMoving = false;
    bool NavigatorPending = false;
    TSubclassOf<UCk_GoapAction_EntityScript> Leaf;
    EMars_Crawler_EngageStage EngageStage = EMars_Crawler_EngageStage::None;
}

// A damageable target built by SpawnCombatTarget.
struct FMars_AutoTest_CrawlerMelee_Target
{
    FCk_Handle Entity;
    FCk_Handle_Transform Root;
    FCk_Handle_Health Health;
    FCk_Handle_HitZone Zone;
    // The hurtbox node SpawnCombatTarget added (the one at the root's own transform).
    FCk_Handle Hurtbox;
}

//--------------------------------------------------------------------------------------------------------------------------
// The Overlap-group sampler
//--------------------------------------------------------------------------------------------------------------------------

// The sampler's input and output. The test writes the inputs before the first tick and never touches the outputs; the
// Overlap processor writes the outputs; the move producer writes MoveFrame and nothing else.
struct FMars_TESTONLY_CrawlerMelee_OverlapSample
{
    // Inputs.
    FVector OldLocation;
    FVector NewLocation;
    float32 Radius = 10.0f;
    FCk_Handle ExpectedHurtbox;

    // Written by UMars_TESTONLY_Processor_CrawlerMelee_MoveProducer: the frame it requested the move.
    int64 MoveFrame = -1;

    // Written by UMars_TESTONLY_Processor_CrawlerMelee_OverlapSample: the zero-travel queries (the resolver's query).
    int32 Ticks = 0;
    int64 LastTickFrame = -1;
    int64 OldLocationLastHitFrame = -1;
    // Hits of the expected hurtbox at NewLocation before any move was requested: a non-zero count makes the same-frame
    // assertion vacuous.
    int32 NewLocationHitsBeforeMove = 0;
    int64 FirstNewHitFrame = -1;
    FCk_Handle FirstNewHitEntity;
    FVector FirstNewHitLocation;
    // The hurtbox node's entity transform as the Overlap processor read it on FirstNewHitFrame.
    FVector HurtboxLocationAtFirstNewHit;
    bool OldLocationHitOnFirstNewHitFrame = false;

    // The same observations through a vertical sweep across each location (+-SweepHalfLength in Z). A MEASURING
    // INSTRUMENT for probe-body synchronization only, so that property is observable even when the zero-travel query
    // reports nothing; it is not a candidate for the resolver's query.
    float64 SweepHalfLength = 60.0;
    int64 SweepOldLocationLastHitFrame = -1;
    int32 SweepNewLocationHitsBeforeMove = 0;
    int64 SweepFirstNewHitFrame = -1;
    FCk_Handle SweepFirstNewHitEntity;
    FVector SweepHurtboxLocationAtFirstNewHit;
    bool SweepOldLocationHitOnFirstNewHitFrame = false;
}

// Armed by the test; the producer requests the move once, from FGroup_Gameplay_Script.
struct FMars_TESTONLY_CrawlerMelee_MoveRequest
{
    FCk_Handle_Transform TargetRoot;
    FTransform Destination;
    bool Armed = false;
    bool Done = false;
}

// The move is requested from a processor rather than from an autotest step so the stamped frame is unambiguous: an
// autotest continuation runs on a timer signal whose position in the frame is the timer's business, while this runs in
// FGroup_Gameplay_Script, the group the crawler's own attack processors (and every gameplay mover feeding SurfaceMotion)
// run in, before FGroup_Transform drains the transform request this frame.
class UMars_TESTONLY_Processor_CrawlerMelee_MoveProducer : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_TESTONLY_CrawlerMelee_MoveRequest);
        Query.Require(FMars_TESTONLY_CrawlerMelee_OverlapSample);
    }

    UFUNCTION(BlueprintOverride)
    void ForEachBatch(FCk_ScriptQueryBatch Batch, FCk_Time InDeltaT)
    {
        for (int32 Index = 0; Index < Batch.Num(); ++Index)
        {
            auto Entity = Batch.GetHandle(Index);
            auto& Move = Entity.Get_Fragment(FMars_TESTONLY_CrawlerMelee_MoveRequest);
            if (Move.Armed == false || Move.Done)
            { continue; }

            auto& Sample = Entity.Get_Fragment(FMars_TESTONLY_CrawlerMelee_OverlapSample);
            Sample.MoveFrame = utils_time::Get_FrameCounter();

            auto Root = Move.TargetRoot;
            utils_transform::Request_SetTransform(Root, Move.Destination);
            Move.Done = true;
        }
    }
}

// Runs in FGroup_Overlap (TG_PostPhysics) after the probe processors have pushed this frame's entity transforms into the
// probe bodies, which is where the crawler's hit resolver runs. The five RunAfter names are native processor names
// resolved by suffix (CkDynamic_ScriptProcessor_Host.cpp DoResolveGroupName); one that does not resolve is logged by the
// processor graph as "declares RunAfter [...] which is not registered".
class UMars_TESTONLY_Processor_CrawlerMelee_OverlapSample : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Overlap";
    default _RunAfter.Add(n"FProcessor_Probe_Setup");
    default _RunAfter.Add(n"FProcessor_Probe_HandleRequests");
    default _RunAfter.Add(n"FProcessor_Probe_UpdateShape");
    default _RunAfter.Add(n"FProcessor_Probe_UpdateTransform");
    default _RunAfter.Add(n"FProcessor_Probe_UpdateTransform_LinearCast");

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_TESTONLY_CrawlerMelee_OverlapSample);
    }

    UFUNCTION(BlueprintOverride)
    void ForEachBatch(FCk_ScriptQueryBatch Batch, FCk_Time InDeltaT)
    {
        for (int32 Index = 0; Index < Batch.Num(); ++Index)
        {
            auto Entity = Batch.GetHandle(Index);
            auto& Sample = Entity.Get_Fragment(FMars_TESTONLY_CrawlerMelee_OverlapSample);
            const auto Frame = utils_time::Get_FrameCounter();

            ++Sample.Ticks;
            Sample.LastTickFrame = Frame;

            SampleSweeps(Entity, Sample, Frame);

            const auto OldHit = QueryAt(Entity, Sample.OldLocation, Sample.Radius);
            const auto OldHitsExpected = ck::IsValid(OldHit.Get_HitEntity()) && OldHit.Get_HitEntity() == Sample.ExpectedHurtbox;
            if (OldHitsExpected)
            { Sample.OldLocationLastHitFrame = Frame; }

            const auto NewHit = QueryAt(Entity, Sample.NewLocation, Sample.Radius);
            const auto NewHitsExpected = ck::IsValid(NewHit.Get_HitEntity()) && NewHit.Get_HitEntity() == Sample.ExpectedHurtbox;
            if (NewHitsExpected == false)
            { continue; }

            if (Sample.MoveFrame < 0)
            {
                ++Sample.NewLocationHitsBeforeMove;
                continue;
            }

            if (Sample.FirstNewHitFrame >= 0)
            { continue; }

            auto Hurtbox = Sample.ExpectedHurtbox;
            Sample.FirstNewHitFrame = Frame;
            Sample.FirstNewHitEntity = NewHit.Get_HitEntity();
            Sample.FirstNewHitLocation = NewHit.Get_HitLocation();
            Sample.HurtboxLocationAtFirstNewHit = utils_transform::Get_EntityCurrentLocation(Hurtbox.As_Transform());
            Sample.OldLocationHitOnFirstNewHitFrame = OldHitsExpected;
        }
    }

    // The sweep instrument: the same bookkeeping as the zero-travel queries, through vertical sweeps.
    private void SampleSweeps(FCk_Handle InAnyHandle, FMars_TESTONLY_CrawlerMelee_OverlapSample& InOutSample, int64 InFrame)
    {
        const auto Offset = FVector(0.0, 0.0, InOutSample.SweepHalfLength);

        const auto OldHit = SweepBetween(InAnyHandle, InOutSample.OldLocation - Offset, InOutSample.OldLocation + Offset, InOutSample.Radius);
        const auto OldHitsExpected = ck::IsValid(OldHit.Get_HitEntity()) && OldHit.Get_HitEntity() == InOutSample.ExpectedHurtbox;
        if (OldHitsExpected)
        { InOutSample.SweepOldLocationLastHitFrame = InFrame; }

        const auto NewHit = SweepBetween(InAnyHandle, InOutSample.NewLocation - Offset, InOutSample.NewLocation + Offset, InOutSample.Radius);
        const auto NewHitsExpected = ck::IsValid(NewHit.Get_HitEntity()) && NewHit.Get_HitEntity() == InOutSample.ExpectedHurtbox;
        if (NewHitsExpected == false)
        { return; }

        if (InOutSample.MoveFrame < 0)
        {
            ++InOutSample.SweepNewLocationHitsBeforeMove;
            return;
        }

        if (InOutSample.SweepFirstNewHitFrame >= 0)
        { return; }

        auto Hurtbox = InOutSample.ExpectedHurtbox;
        InOutSample.SweepFirstNewHitFrame = InFrame;
        InOutSample.SweepFirstNewHitEntity = NewHit.Get_HitEntity();
        InOutSample.SweepHurtboxLocationAtFirstNewHit = utils_transform::Get_EntityCurrentLocation(Hurtbox.As_Transform());
        InOutSample.SweepOldLocationHitOnFirstNewHitFrame = OldHitsExpected;
    }

    // A zero-travel (Start == End) sphere with the crawler hit query's settings (see Make_HitQuery) at a point.
    private FCk_ShapeCast_Result QueryAt(FCk_Handle InAnyHandle, FVector InLocation, float32 InRadius)
    {
        return SweepBetween(InAnyHandle, InLocation, InLocation, InRadius);
    }

    private FCk_ShapeCast_Result SweepBetween(FCk_Handle InAnyHandle, FVector InStart, FVector InEnd, float32 InRadius)
    {
        auto Settings = FCk_ShapeCast_Settings(InStart, InEnd,
            utils_shapes::Make_Sphere(FCk_ShapeSphere_Dimensions(InRadius)),
            GameplayTag::MakeContainerFromTag(GameplayTags::Probe_Mars_HitZone));
        Settings.Set_WorldHitPolicy(ECk_ProbeTrace_WorldHitPolicy::Blocking);
        Settings.Set_OverlapNotifyPolicy(ECk_ProbeResponse_Policy::Silent);
        Settings.Set_BackFaceModeConvex(ECk_BackFaceMode::CollideWithBackFaces);
        return utils_probe_trace::Request_SingleShapeTrace(InAnyHandle, Settings);
    }
}

//--------------------------------------------------------------------------------------------------------------------------
// Attack triggers: one-shot test actions timed against the attack's own state
//--------------------------------------------------------------------------------------------------------------------------

// When a trigger fires, read from the crawler's public attack getters.
enum EMars_TESTONLY_CrawlerMelee_When
{
    // The frame the kernel entered Strike (no Strike sample submitted yet).
    StrikeEntered,
    // The frame the first Strike sample was submitted.
    StrikeSampleSubmitted,
    // The frame Strike's endpoint sample was submitted.
    StrikeEndpointSubmitted,
    // The frame the kernel entered CancelRecover.
    CancelRecoverEntered,
    // A hit candidate is waiting for the next attack tick (FGroup_Overlap, after the resolver).
    CandidatePending,
    // Every frame the attack is in StealPhase (DropAcknowledgement only).
    WhilePhase
}

enum EMars_TESTONLY_CrawlerMelee_Action
{
    // Request_SetTransform(TargetRoot, Destination).
    MoveTarget,
    // A zero-speed SurfaceMotion steer toward SteerDirection: the root turns in place.
    SteerCrawler,
    // Request_Hit on HitZone with Amount of blunt damage.
    HitZone,
    // Request_ApplyDamage on Health with Amount of blunt damage.
    DamageHealth,
    DestroyEntity,
    CancelAttack,
    // Test-only post-resolver fault: the game ignores a real published receipt so its own acknowledgement watchdog runs.
    DropAcknowledgement
}

// Armed by the test, read and written only by the two trigger processors once armed.
struct FMars_TESTONLY_CrawlerMelee_Trigger
{
    FCk_Handle_Crawler Crawler;
    EMars_TESTONLY_CrawlerMelee_When When = EMars_TESTONLY_CrawlerMelee_When::StrikeEntered;
    EMars_TESTONLY_CrawlerMelee_Action Action = EMars_TESTONLY_CrawlerMelee_Action::MoveTarget;

    FCk_Handle_Transform TargetRoot;
    FTransform Destination;
    FVector SteerDirection = FVector::ZeroVector;
    FCk_Handle_HitZone HitZone;
    FCk_Handle_Health Health;
    float32 Amount = 0.0f;
    FCk_Handle Entity;
    EMars_Crawler_AttackCancel CancelReason = EMars_Crawler_AttackCancel::StateExit;
    EMars_Crawler_AttackPhase StealPhase = EMars_Crawler_AttackPhase::CancelRecover;

    bool Armed = false;
    bool Fired = false;
    int64 FiredFrame = -1;
    int32 FiredGeneration = 0;
    int32 DroppedAcknowledgements = 0;

    // Written by the Overlap trigger processor whatever the trigger: a candidate was pending after the resolver ran.
    bool SawCandidate = false;
    int64 SawCandidateFrame = -1;
}

// Runs right after the attack tick, so it reads the frame's final attack state, and before the Health and HitZone drains,
// so a Health or zone hit lands later this frame: after this frame's attack tick, before the resolver.
class UMars_TESTONLY_Processor_CrawlerMelee_Trigger : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _RunAfter.Add(n"/Script/Angelscript.Mars_Processor_Crawler_AttackTick");
    default _RunBefore.Add(n"/Script/Angelscript.Mars_Processor_Health_HandleRequests");
    default _RunBefore.Add(n"/Script/Angelscript.Mars_Processor_HitZone_HandleRequests");

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_TESTONLY_CrawlerMelee_Trigger);
    }

    UFUNCTION(BlueprintOverride)
    void ForEachBatch(FCk_ScriptQueryBatch Batch, FCk_Time InDeltaT)
    {
        for (int32 Index = 0; Index < Batch.Num(); ++Index)
        {
            auto Entity = Batch.GetHandle(Index);
            auto& Trigger = Entity.Get_Fragment(FMars_TESTONLY_CrawlerMelee_Trigger);
            if (Trigger.Armed == false || ck::Is_NOT_Valid(Trigger.Crawler) || Trigger.When == EMars_TESTONLY_CrawlerMelee_When::CandidatePending)
            { continue; }

            if (Trigger.When == EMars_TESTONLY_CrawlerMelee_When::WhilePhase)
            { continue; }

            if (Trigger.Fired || Get_IsDue(Trigger) == false)
            { continue; }

            utils_crawler_melee_trigger::Fire(Trigger);
        }
    }

    private bool Get_IsDue(const FMars_TESTONLY_CrawlerMelee_Trigger& InTrigger)
    {
        const auto Crawler = InTrigger.Crawler;
        if (InTrigger.When == EMars_TESTONLY_CrawlerMelee_When::CancelRecoverEntered)
        { return Crawler.Get_AttackPhase() == EMars_Crawler_AttackPhase::CancelRecover; }

        if (Crawler.Get_AttackPhase() != EMars_Crawler_AttackPhase::Strike)
        { return false; }

        switch (InTrigger.When)
        {
            case EMars_TESTONLY_CrawlerMelee_When::StrikeEntered: return Crawler.Get_AttackPendingSampleId() == 0;
            case EMars_TESTONLY_CrawlerMelee_When::StrikeSampleSubmitted: return Crawler.Get_AttackPendingSampleId() != 0;
            case EMars_TESTONLY_CrawlerMelee_When::StrikeEndpointSubmitted: return Crawler.Get_AttackEndpointSubmitted();
            default: return false;
        }
    }

}

// In FGroup_Overlap after the resolver: records that a candidate was pending, and fires CandidatePending triggers.
class UMars_TESTONLY_Processor_CrawlerMelee_CandidateTrigger : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Overlap";
    default _RunAfter.Add(n"/Script/Angelscript.Mars_Processor_Crawler_AttackResolve");

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_TESTONLY_CrawlerMelee_Trigger);
    }

    UFUNCTION(BlueprintOverride)
    void ForEachBatch(FCk_ScriptQueryBatch Batch, FCk_Time InDeltaT)
    {
        for (int32 Index = 0; Index < Batch.Num(); ++Index)
        {
            auto Entity = Batch.GetHandle(Index);
            auto& Trigger = Entity.Get_Fragment(FMars_TESTONLY_CrawlerMelee_Trigger);
            if (Trigger.Armed && Trigger.When == EMars_TESTONLY_CrawlerMelee_When::WhilePhase &&
                Trigger.Action == EMars_TESTONLY_CrawlerMelee_Action::DropAcknowledgement &&
                ck::IsValid(Trigger.Crawler) && Trigger.Crawler.Get_AttackPhase() == Trigger.StealPhase)
            {
                const auto PendingId = Trigger.Crawler.Get_AttackPendingSampleId();
                auto& Observations = Trigger.Crawler.Get_Fragment(FMars_Fragment_Crawler_AttackObservations);
                if (PendingId != 0 && Observations.AckSampleId == PendingId)
                {
                    Observations.AckSampleId = 0;
                    ++Trigger.DroppedAcknowledgements;
                }
                continue;
            }
            if (Trigger.Armed == false || ck::Is_NOT_Valid(Trigger.Crawler) || Trigger.Crawler.Get_AttackCandidatePending() == false)
            { continue; }

            if (Trigger.SawCandidate == false)
            {
                Trigger.SawCandidate = true;
                Trigger.SawCandidateFrame = utils_time::Get_FrameCounter();
            }

            if (Trigger.When == EMars_TESTONLY_CrawlerMelee_When::CandidatePending && Trigger.Fired == false)
            { utils_crawler_melee_trigger::Fire(Trigger); }
        }
    }
}

namespace utils_crawler_melee_trigger
{
    void Fire(FMars_TESTONLY_CrawlerMelee_Trigger& InOutTrigger)
    {
        InOutTrigger.Fired = true;
        InOutTrigger.FiredFrame = utils_time::Get_FrameCounter();
        InOutTrigger.FiredGeneration = InOutTrigger.Crawler.Get_AttackGeneration();

        const auto Action = InOutTrigger.Action;
        if (Action == EMars_TESTONLY_CrawlerMelee_Action::MoveTarget)
        {
            auto TargetRoot = InOutTrigger.TargetRoot;
            utils_transform::Request_SetTransform(TargetRoot, InOutTrigger.Destination);
        }
        else if (Action == EMars_TESTONLY_CrawlerMelee_Action::SteerCrawler)
        {
            auto Motion = InOutTrigger.Crawler.Get_Motion();
            utils_surface_motion::Request_Steering(Motion, FCk_Request_SurfaceMotion_Steering(InOutTrigger.SteerDirection, 0.0f));
        }
        else if (Action == EMars_TESTONLY_CrawlerMelee_Action::HitZone)
        {
            auto Zone = InOutTrigger.HitZone;
            Zone.Request_Hit(FMars_Request_HitZone_Hit(FMars_DamageEvent(InOutTrigger.Amount, GameplayTags::DamageType_Mars_Blunt)));
        }
        else if (Action == EMars_TESTONLY_CrawlerMelee_Action::DamageHealth)
        {
            auto Health = InOutTrigger.Health;
            Health.Request_ApplyDamage(FMars_Request_Health_ApplyDamage(FMars_DamageEvent(InOutTrigger.Amount, GameplayTags::DamageType_Mars_Blunt)));
        }
        else if (Action == EMars_TESTONLY_CrawlerMelee_Action::DestroyEntity)
        { utils_entity_lifetime::Request_DestroyEntity(InOutTrigger.Entity); }
        else if (Action == EMars_TESTONLY_CrawlerMelee_Action::CancelAttack)
        {
            auto Crawler = InOutTrigger.Crawler;
            Crawler.Request_CancelAttack(FMars_Request_Crawler_CancelAttack(InOutTrigger.CancelReason));
        }
    }
}

//--------------------------------------------------------------------------------------------------------------------------
// Engage watch: the behaviour's stage changes and every MoveTo the navigator drains
//--------------------------------------------------------------------------------------------------------------------------

// One change of the crawler's Engage stage, as the frame it happened in saw it.
struct FMars_AutoTest_CrawlerMelee_StageRecord
{
    EMars_Crawler_EngageStage Stage = EMars_Crawler_EngageStage::None;
    int64 Frame = -1;
    // The watch's clock.
    float64 Time = 0.0;
    EMars_SurfaceNavigator_Status NavigatorStatus = EMars_SurfaceNavigator_Status::Idle;
    EMars_SurfaceNavigator_FailReason FailReason = EMars_SurfaceNavigator_FailReason::None;
    FVector RootLocation = FVector::ZeroVector;
}

// One MoveTo the navigator was about to drain.
struct FMars_AutoTest_CrawlerMelee_MoveToRecord
{
    int64 Frame = -1;
    float64 Time = 0.0;
    FVector Goal = FVector::ZeroVector;
    EMars_Crawler_EngageStage Stage = EMars_Crawler_EngageStage::None;
}

// Added to a crawler root by the test; written only by the two watch processors.
struct FMars_TESTONLY_CrawlerMelee_EngageWatch
{
    // Seconds of world time since the watch was added.
    float64 Clock = 0.0;
    EMars_Crawler_EngageStage LastStage = EMars_Crawler_EngageStage::None;
    TArray<FMars_AutoTest_CrawlerMelee_StageRecord> Stages;
    TArray<FMars_AutoTest_CrawlerMelee_MoveToRecord> MoveTos;
}

// Every frame: advances the watch's clock and records a changed Engage stage. The stage tasks tick in FGroup_Gameplay_AI,
// so by FGroup_Gameplay_Script the frame's stage is final.
class UMars_TESTONLY_Processor_CrawlerMelee_EngageWatch : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _RunBefore.Add(n"/Script/Angelscript.Mars_TESTONLY_Processor_CrawlerMelee_MoveToWatch");

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_Crawler);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle, FMars_TESTONLY_CrawlerMelee_EngageWatch& InWatch)
    {
        InWatch.Clock += InDeltaT.Get_Seconds();

        const auto Crawler = InHandle.As_Crawler();
        const auto Stage = Crawler.Get_EngageStage();
        if (Stage == InWatch.LastStage)
        { return; }

        InWatch.LastStage = Stage;

        const auto Navigator = Crawler.Get_Navigator();
        auto Record = FMars_AutoTest_CrawlerMelee_StageRecord();
        Record.Stage = Stage;
        Record.Frame = utils_time::Get_FrameCounter();
        Record.Time = InWatch.Clock;
        Record.NavigatorStatus = Navigator.Get_Status();
        Record.FailReason = Navigator.Get_FailReason();
        Record.RootLocation = utils_transform::Get_EntityCurrentLocation(Crawler.As_Transform());
        InWatch.Stages.Add(Record);
    }
}

// Marked dirty by the navigator's request fragment and ordered before its drain, so it sees every queued MoveTo exactly
// once, in whichever pass of the frame the drain runs.
class UMars_TESTONLY_Processor_CrawlerMelee_MoveToWatch : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _MarkedDirtyBy = FMars_Fragment_SurfaceNavigator_Requests;
    default _RunBefore.Add(n"/Script/Angelscript.Mars_Processor_SurfaceNavigator_HandleRequests");

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_TESTONLY_CrawlerMelee_EngageWatch);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle, FMars_Fragment_SurfaceNavigator_Requests& InRequests)
    {
        auto& Watch = InHandle.Get_Fragment(FMars_TESTONLY_CrawlerMelee_EngageWatch);
        const auto Stage = InHandle.As_Crawler().Get_EngageStage();
        for (const auto& MoveTo : InRequests.MoveToRequests)
        {
            auto Record = FMars_AutoTest_CrawlerMelee_MoveToRecord();
            Record.Frame = utils_time::Get_FrameCounter();
            Record.Time = Watch.Clock;
            Record.Goal = MoveTo.Goal;
            Record.Stage = Stage;
            Watch.MoveTos.Add(Record);
        }
    }
}

//--------------------------------------------------------------------------------------------------------------------------
// The rig
//--------------------------------------------------------------------------------------------------------------------------

UCLASS(Abstract)
class UMars_AutoTestRig_CrawlerMelee : UCk_AutoTest_Base
{
    // Composition, physics falls and deferred probe/body joins outrun the default poll budget at lane frame rate.
    protected const int32 k_SlowPolls = 900;

    protected FVector _Origin;
    protected FCk_Handle_Crawler _Crawler;

    //----------------------------------------------------------------------------------------------------------------------
    // Targets and walls
    //----------------------------------------------------------------------------------------------------------------------

    // A combat target at InLocation: a transform root on team One (the player's team; the crawler is on Two, so it reads
    // Hostile), Health 100, a flesh HitZone on HitZone.Mars.Body, one box hurtbox of InHalfExtents at the root's own
    // transform, and TAG_MarsCombatTarget added last, once the receiver is complete.
    protected FMars_AutoTest_CrawlerMelee_Target SpawnCombatTarget(FCk_Handle InHandle, FVector InLocation, FVector InHalfExtents)
    {
        return SpawnCombatTargetAt(InHandle, FTransform(FRotator::ZeroRotator, InLocation), InHalfExtents);
    }

    // SpawnCombatTarget with the root (and so the hurtbox) at InTransform.
    protected FMars_AutoTest_CrawlerMelee_Target SpawnCombatTargetAt(FCk_Handle InHandle, FTransform InTransform, FVector InHalfExtents)
    {
        auto Target = SpawnBystanderAt(InHandle, InTransform, InHalfExtents);
        utils_entity_tag::Add(Target.Entity, n"TAG_MarsCombatTarget");
        return Target;
    }

    // A combat target without TAG_MarsCombatTarget: a creature no crawler chooses, which can still stand in the way.
    protected FMars_AutoTest_CrawlerMelee_Target SpawnBystanderAt(FCk_Handle InHandle, FTransform InTransform, FVector InHalfExtents)
    {
        auto Target = FMars_AutoTest_CrawlerMelee_Target();
        Target.Entity = utils_entity_lifetime::Request_CreateEntity(InHandle);
        Target.Root = utils_transform::Add(Target.Entity, InTransform, ECk_Replication::DoesNotReplicate);
        utils_team::Add(Target.Entity, ECk_Team_ID::One, ECk_Replication::DoesNotReplicate);
        Target.Health = utils_health::Add(Target.Entity, FMars_Health_Spec(100.0f));
        Target.Zone = utils_hit_zone::Add(Target.Entity, utils_hit_zone::Make_FleshZoneSpec(GameplayTags::HitZone_Mars_Body, 1.0f));
        Target.Hurtbox = utils_hit_zone::AddHurtbox_Box(Target.Zone, Target.Root, FMars_HitZone_Hurtbox(InHalfExtents, FTransform::Identity));
        return Target;
    }

    // A second (or further) box hurtbox on InTarget's zone, InLocalOffset from its root. Returns the hurtbox node.
    protected FCk_Handle AddHurtbox(FMars_AutoTest_CrawlerMelee_Target& InTarget, FVector InHalfExtents, FTransform InLocalOffset)
    {
        return utils_hit_zone::AddHurtbox_Box(InTarget.Zone, InTarget.Root, FMars_HitZone_Hurtbox(InHalfExtents, InLocalOffset));
    }

    // A static Jolt box centred at InCenter, BlockAll, like the floor. Returns the wall entity (a World hit's attribution).
    protected FCk_Handle SpawnWall(FCk_Handle InHandle, FVector InCenter, FVector InHalfExtents)
    {
        return SpawnWallAt(InHandle, FTransform(FRotator::ZeroRotator, InCenter), InHalfExtents);
    }

    // SpawnWall with the box at InTransform.
    protected FCk_Handle SpawnWallAt(FCk_Handle InHandle, FTransform InTransform, FVector InHalfExtents)
    {
        auto Wall = utils_entity_lifetime::Request_CreateEntity(InHandle);
        utils_transform::Add(Wall, InTransform, ECk_Replication::DoesNotReplicate);
        auto Shape = FCk_Jolt_ShapeDimensions(ECk_Jolt_ShapeType::Box);
        Shape.Set_HalfExtents(InHalfExtents);
        auto WallSpec = FCk_JoltBody_Spec(ECk_JoltBody_ShapeSource::ExplicitShape);
        WallSpec.Set_ShapeDimensions(Shape);
        WallSpec.Set_MotionType(ECk_MotionType::Static);
        WallSpec.Set_CollisionProfileName(n"BlockAll");
        utils_jolt_body::Add(Wall, WallSpec);
        return Wall;
    }

    // The crawler hit query's settings from InStart to InEnd: a sphere filtered on
    // Probe.Mars.HitZone, Blocking world policy, Silent, and CollideWithBackFaces for convex bodies. Jolt keeps a convex
    // cast hit only when that flag is set or the contact normal points along the cast direction, so without it a
    // zero-travel query, or a sweep that starts inside a body, reports nothing for that body. With it, a body the sphere
    // already overlaps at the start is reported at fraction 0 with the fallback up normal.
    protected FCk_ShapeCast_Settings Make_HitQuery(FVector InStart, FVector InEnd, float32 InRadius) const
    {
        auto Settings = FCk_ShapeCast_Settings(InStart, InEnd,
            utils_shapes::Make_Sphere(FCk_ShapeSphere_Dimensions(InRadius)),
            GameplayTag::MakeContainerFromTag(GameplayTags::Probe_Mars_HitZone));
        Settings.Set_WorldHitPolicy(ECk_ProbeTrace_WorldHitPolicy::Blocking);
        Settings.Set_OverlapNotifyPolicy(ECk_ProbeResponse_Policy::Silent);
        Settings.Set_BackFaceModeConvex(ECk_BackFaceMode::CollideWithBackFaces);
        return Settings;
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Floor and crawler (the crawler rig's recipe)
    //----------------------------------------------------------------------------------------------------------------------

    // 4 legs, roaming the box of InRoamHalfExtent around _Origin.
    protected FMars_Crawler_Spec Make_CrawlerSpec(FVector InRoamHalfExtent) const
    {
        return FMars_Crawler_Spec(4, FBox(_Origin - InRoamHalfExtent, _Origin + InRoamHalfExtent));
    }

    // Returns the floor.
    protected FCk_Handle SpawnFloorAndCrawler(FCk_Handle InHandle, FMars_Crawler_Spec InSpec)
    {
        auto Floor = SpawnWall(InHandle, _Origin - FVector(0.0, 0.0, 10.0), FVector(1500.0, 1500.0, 10.0));

        auto SpawnParams = UMars_Crawler_EntityScript::Params();
        SpawnParams.SpawnTransform = FTransform(FRotator::ZeroRotator, _Origin + FVector(0.0, 0.0, 65.0));
        SpawnParams.Spec = InSpec;
        SpawnParams.WithVisuals = false;
        auto Pending = utils_entity_script::Request_SpawnEntity(InHandle, UMars_Crawler_EntityScript, SpawnParams);
        utils_pending_entity_script::Promise_OnConstructed(Pending, FCk_Delegate_EntityScript_Constructed(this, n"OnCrawlerConstructed"));
        return Floor;
    }

    protected FVector BodyLocation() const
    {
        return utils_transform::Get_EntityCurrentLocation(_Crawler.As_Transform());
    }

    // False until the crawler is constructed; a failed gait fails the test.
    protected bool Get_IsGaitReady()
    {
        if (ck::Is_NOT_Valid(_Crawler))
        { return false; }

        const auto Gait = _Crawler.Get_Gait();
        if (utils_procedural_gait::Get_Status(Gait) == ECk_ProceduralAnimation_Status::Failed)
        {
            FinishFailure(f"the crawler's gait failed: {utils_procedural_gait::Get_Failure(Gait) :n}");
            return false;
        }

        return utils_procedural_gait::Get_Status(Gait) == ECk_ProceduralAnimation_Status::Ready;
    }

    UFUNCTION()
    protected void OnCrawlerConstructed(FCk_Handle_EntityScript InEntityScriptHandle)
    {
        _Crawler = InEntityScriptHandle.As_Crawler();
        _Crawler.BindTo_OnAttackPhaseChanged(FMars_Delegate_Crawler_OnAttackPhaseChanged(this, n"OnAttackPhaseChanged"));
    }

    // The gait is Ready and the monster has registered one part per leg.
    UFUNCTION()
    protected void Check_Ready(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_IsGaitReady() && _Crawler.Get_Monster().Get_Parts().Num() == _Crawler.Get_Spec().LegCount);
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Armed crawler: settling, geometry, attacks, the phase record
    //----------------------------------------------------------------------------------------------------------------------

    // The target the attack steps aim at.
    protected FMars_AutoTest_CrawlerMelee_Target _Target;
    // Every OnAttackPhaseChanged of the rig's crawler(s), in order.
    protected TArray<FMars_AutoTest_CrawlerMelee_PhaseRecord> _Records;
    // _Records.Num() when the last attack was requested.
    protected int32 _RecordMark = 0;
    protected int32 _AdmissionPolls = 0;
    private float64 _RestSince = -1.0;
    private FVector _RestForward;
    // Where and how the crawler stood when Check_AtRest last held.
    protected FVector _SettledLocation;
    protected FVector _SettledForward;
    private int32 _TraceablePolls = 0;

    // A combat-enabled, passive crawler of InLegCount legs, roaming +-150 around _Origin but dwelling 120 s after a stop,
    // so once stopped it stands still for the whole test. Passive: it chooses no target and its HasCombatTarget fact never
    // rises, so its behaviour stays out of attacks a test drives directly. Behaviour tests make it aggressive.
    protected FMars_Crawler_Spec Make_ArmedCrawlerSpec(int32 InLegCount) const
    {
        auto Spec = FMars_Crawler_Spec(InLegCount, FBox(_Origin - FVector(150.0, 150.0, 200.0), _Origin + FVector(150.0, 150.0, 200.0)));
        Spec.RoamDwellSeconds = 120.0f;
        Spec.Combat.Enabled = true;
        Spec.Combat.StartAggressive = ECk_EnableDisable::Disable;
        return Spec;
    }

    // Make_ArmedCrawlerSpec, aggressive: it chooses its own targets and engages them.
    protected FMars_Crawler_Spec Make_AggressiveCrawlerSpec(int32 InLegCount) const
    {
        auto Spec = Make_ArmedCrawlerSpec(InLegCount);
        Spec.Combat.StartAggressive = ECk_EnableDisable::Enable;
        return Spec;
    }

    // Composed and Ready -> in Roam (its first MoveTo is out) -> stopped -> at rest.
    protected void Add_SettleSteps()
    {
        Add_Step_WaitUntil("the crawler is composed, its gait Ready and every leg part registered", n"Check_Ready", k_SlowPolls, 0);
        Add_Step_WaitUntil("the behaviour sub-SM is in Roam", n"Check_CrawlerInRoam", k_SlowPolls, 0);
        Add_Step("stop the navigator", n"Step_StopCrawlerNavigator");
        Add_Step_WaitUntil("the navigator has drained the stop and is not Moving", n"Check_CrawlerNavigatorStopped", k_SlowPolls, 0);
        Add_Step_WaitUntil("the crawler has been at rest (speed under 0.5 cm/s, heading within 0.25 deg) for 1 s", n"Check_AtRest", k_SlowPolls, 0);
    }

    // The root's forward on the horizontal plane.
    protected FVector Get_Forward() const
    {
        return utils_transform::Get_EntityCurrentTransform(_Crawler.As_Transform()).GetRotation().GetForwardVector().GetSafeNormal2D();
    }

    protected FVector Get_Right() const
    {
        return FVector::UpVector.CrossProduct(Get_Forward());
    }

    // Where the hit sphere's centre sits with no action offset.
    protected FVector Get_NeutralHitCenter() const
    {
        const auto Presentation = utils_transform::Get_EntityCurrentTransform(_Crawler.Get_Presentation());
        return utils_crawler::Get_HitCenter(Presentation, _Crawler.Get_Spec().Combat.Hit.LocalCenter);
    }

    // InAhead along the forward and InRight to the right of the neutral hit centre, at its height.
    protected FVector Get_PointAhead(float64 InAhead, float64 InRight) const
    {
        return Get_NeutralHitCenter() + Get_Forward() * InAhead + Get_Right() * InRight;
    }

    // A box of InHalfExtents squared to the crawler's forward, at InPoint.
    protected FTransform Get_FacingTransform(FVector InPoint) const
    {
        return FTransform(Get_Forward().Rotation(), InPoint, FVector::OneVector);
    }

    // A target whose near face is InFaceAhead in front of the neutral hit centre. The default jab's sphere (radius 20) reaches
    // 20 in front at rest, 10 at the end of the windup and 44 at the end of the strike.
    protected FMars_AutoTest_CrawlerMelee_Target SpawnTargetAhead(FCk_Handle InHandle, float64 InFaceAhead, FVector InHalfExtents)
    {
        return SpawnCombatTargetAt(InHandle, Get_FacingTransform(Get_PointAhead(InFaceAhead + InHalfExtents.X, 0.0)), InHalfExtents);
    }

    // Dealt plus rejected: every damage request the crawler's dealer has drained.
    protected int32 Get_DamageRequestCount() const
    {
        const auto Dealer = _Crawler.Get_CombatDealer();
        return Dealer.Get_HitsDealt() + Dealer.Get_HitsRejected();
    }

    // "Windup > Strike > ..." of the records from InFrom on.
    protected FString Get_PhaseText(int32 InFrom) const
    {
        FString Text = "";
        for (int32 Index = InFrom; Index < _Records.Num(); ++Index)
        { Text = f"{Text} > {_Records[Index].New :n}"; }
        return Text;
    }

    // The phases entered since the last attack request, in order.
    protected TArray<EMars_Crawler_AttackPhase> Get_PhasesSinceMark() const
    {
        auto Phases = TArray<EMars_Crawler_AttackPhase>();
        for (int32 Index = _RecordMark; Index < _Records.Num(); ++Index)
        { Phases.Add(_Records[Index].New); }
        return Phases;
    }

    // The first record since the last attack request that entered InPhase; -1 when none.
    protected int32 Find_RecordSinceMark(EMars_Crawler_AttackPhase InPhase) const
    {
        for (int32 Index = _RecordMark; Index < _Records.Num(); ++Index)
        {
            if (_Records[Index].New == InPhase)
            { return Index; }
        }
        return -1;
    }

    protected FString Get_LastCancelText() const
    {
        const auto LastCancel = _Crawler.Get_AttackLastCancel();
        return LastCancel.IsSet() ? f"{LastCancel.GetValue() :n}" : "none";
    }

    protected FString Get_LastRejectText() const
    {
        const auto LastReject = _Crawler.Get_AttackLastReject();
        return LastReject.IsSet() ? f"{LastReject.GetValue() :n}" : "none";
    }

    // A trigger entity armed for InWhen / InAction on the rig's crawler; the caller fills the action's inputs.
    protected FMars_TESTONLY_CrawlerMelee_Trigger Make_Trigger(EMars_TESTONLY_CrawlerMelee_When InWhen, EMars_TESTONLY_CrawlerMelee_Action InAction) const
    {
        auto Trigger = FMars_TESTONLY_CrawlerMelee_Trigger();
        Trigger.Crawler = _Crawler;
        Trigger.When = InWhen;
        Trigger.Action = InAction;
        Trigger.Armed = true;
        return Trigger;
    }

    protected FCk_Handle Add_Trigger(FCk_Handle InHandle, FMars_TESTONLY_CrawlerMelee_Trigger InTrigger)
    {
        auto Entity = utils_entity_lifetime::Request_CreateEntity(InHandle);
        Entity.Add_Fragment(InTrigger);
        return Entity;
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Behaviour: the Engage watch, target placement from the root
    //----------------------------------------------------------------------------------------------------------------------

    // InAhead along the root's horizontal forward and InRight to its right, at the neutral hit centre's height.
    protected FVector Get_PointFromRoot(float64 InAhead, float64 InRight) const
    {
        auto Point = BodyLocation() + Get_Forward() * InAhead + Get_Right() * InRight;
        Point.Z = Get_NeutralHitCenter().Z;
        return Point;
    }

    // From now on the rig's crawler records its Engage stage changes and its navigator's MoveTos.
    protected void Watch_Engage()
    {
        _Crawler.Add_Fragment(FMars_TESTONLY_CrawlerMelee_EngageWatch());
    }

    protected TArray<FMars_AutoTest_CrawlerMelee_StageRecord> Get_StageRecords() const
    {
        if (ck::Is_NOT_Valid(_Crawler) || _Crawler.Has_Fragment(FMars_TESTONLY_CrawlerMelee_EngageWatch) == false)
        { return TArray<FMars_AutoTest_CrawlerMelee_StageRecord>(); }

        return _Crawler.Get_Fragment(FMars_TESTONLY_CrawlerMelee_EngageWatch).Stages;
    }

    protected TArray<FMars_AutoTest_CrawlerMelee_MoveToRecord> Get_MoveToRecords() const
    {
        if (ck::Is_NOT_Valid(_Crawler) || _Crawler.Has_Fragment(FMars_TESTONLY_CrawlerMelee_EngageWatch) == false)
        { return TArray<FMars_AutoTest_CrawlerMelee_MoveToRecord>(); }

        return _Crawler.Get_Fragment(FMars_TESTONLY_CrawlerMelee_EngageWatch).MoveTos;
    }

    // The watch's clock now.
    protected float64 Get_WatchClock() const
    {
        if (ck::Is_NOT_Valid(_Crawler) || _Crawler.Has_Fragment(FMars_TESTONLY_CrawlerMelee_EngageWatch) == false)
        { return 0.0; }

        return _Crawler.Get_Fragment(FMars_TESTONLY_CrawlerMelee_EngageWatch).Clock;
    }

    // " > Approach > Prepare ..." of the stage records from InFrom on.
    protected FString Get_StageText(int32 InFrom) const
    {
        const auto Stages = Get_StageRecords();
        FString Text = "";
        for (int32 Index = InFrom; Index < Stages.Num(); ++Index)
        { Text = f"{Text} > {Stages[Index].Stage :n}"; }
        return Text;
    }

    // The first stage record at or after InFrom that entered InStage; -1 when none.
    protected int32 Find_StageRecord(EMars_Crawler_EngageStage InStage, int32 InFrom) const
    {
        const auto Stages = Get_StageRecords();
        for (int32 Index = InFrom; Index < Stages.Num(); ++Index)
        {
            if (Stages[Index].Stage == InStage)
            { return Index; }
        }
        return -1;
    }

    protected int32 Count_StageRecords(EMars_Crawler_EngageStage InStage) const
    {
        int32 Count = 0;
        for (const auto& Record : Get_StageRecords())
        {
            if (Record.Stage == InStage)
            { ++Count; }
        }
        return Count;
    }

    // Phase records since the last mark that entered InPhase.
    protected int32 Count_RecordsSinceMark(EMars_Crawler_AttackPhase InPhase) const
    {
        int32 Count = 0;
        for (int32 Index = _RecordMark; Index < _Records.Num(); ++Index)
        {
            if (_Records[Index].New == InPhase)
            { ++Count; }
        }
        return Count;
    }

    // The planar angle between InForward and the direction from InFrom to InPoint, in degrees.
    protected float64 Get_HeadingErrorTo(FVector InForward, FVector InFrom, FVector InPoint) const
    {
        return utils_crawler::Get_PlanarAngleDegrees(InForward, InPoint - InFrom, FVector::UpVector);
    }

    protected bool Get_HasCombatTargetFact() const
    {
        return _Crawler.Get_Brain().Get_Fact(utils_crawler::Get_HasCombatTargetFact());
    }

    UFUNCTION()
    protected void Check_InEngageApproach(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Crawler.Get_EngageStage() == EMars_Crawler_EngageStage::Approach);
    }

    UFUNCTION()
    protected void Check_InEngagePrepare(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Crawler.Get_EngageStage() == EMars_Crawler_EngageStage::Prepare);
    }

    UFUNCTION()
    protected void Check_InEngageWait(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Crawler.Get_EngageStage() == EMars_Crawler_EngageStage::Wait);
    }

    // The crawler holds _Target as its combat target.
    UFUNCTION()
    protected void Check_TargetAcquired(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Crawler.Get_CombatTarget() == _Target.Entity);
    }

    // A Windup was entered since the last mark, whoever started the attack.
    UFUNCTION()
    protected void Check_WindupSinceMark(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Find_RecordSinceMark(EMars_Crawler_AttackPhase::Windup) >= 0);
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Steps and predicates shared by the attack tests
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    protected void Step_StopCrawlerNavigator(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _RestSince = -1.0;
        auto Navigator = _Crawler.Get_Navigator();
        Navigator.Request_Stop(FMars_Request_SurfaceNavigator_Stop());
    }

    UFUNCTION()
    protected void Check_CrawlerInRoam(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Crawler.Get_BehaviorStateClass() == UMars_SmState_Crawler_Roam);
    }

    UFUNCTION()
    protected void Check_CrawlerNavigatorStopped(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Navigator = _Crawler.Get_Navigator();
        auto Res = OutResult;
        Res.Set(Navigator.Get_HasPendingRequests() == false && Navigator.Get_Status() != EMars_SurfaceNavigator_Status::Moving);
    }

    UFUNCTION()
    protected void Check_AtRest(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto Now = System::GetGameTimeInSeconds();
        const auto Forward = Get_Forward();
        const auto Moving = utils_surface_motion::Get_Velocity(_Crawler.Get_Motion()).Size() > 0.5;
        const auto Turning = _RestSince >= 0.0 && Forward.DotProduct(_RestForward) < Math::Cos(Math::DegreesToRadians(0.25));
        if (Moving)
        { _RestSince = -1.0; }
        else if (_RestSince < 0.0 || Turning)
        {
            _RestSince = Now;
            _RestForward = Forward;
        }

        const auto Rested = _RestSince >= 0.0 && Now - _RestSince >= 1.0;
        if (Rested)
        {
            _SettledLocation = BodyLocation();
            _SettledForward = Get_Forward();
            _TraceablePolls = 0;
        }

        auto Res = OutResult;
        Res.Set(Rested);
    }

    // Where the crawler is and what it is doing, against how it stood when it settled: for failure messages.
    protected FString Get_CrawlerDiagnostics() const
    {
        const auto Behaviour = _Crawler.Get_BehaviorStateClass();
        const FString BehaviourName = ck::IsValid(Behaviour) ? f"{Behaviour.Get().GetName()}" : "-";
        const auto Turned = Math::RadiansToDegrees(Math::Acos(Math::Clamp(Get_Forward().DotProduct(_SettledForward), -1.0, 1.0)));
        return f"behaviour {BehaviourName}, navigator {_Crawler.Get_Navigator().Get_Status() :n}, speed {utils_surface_motion::Get_Velocity(_Crawler.Get_Motion()).Size() :.2} cm/s, moved {(BodyLocation() - _SettledLocation).Size() :.2} cm and turned {Turned :.2} deg since settling, support {utils_surface_motion::Get_Support(_Crawler.Get_Motion()) :n}";
    }

    // A sweep across _Target, past the crawler's own hurtboxes, reports a hurtbox of _Target's zone: its probe bodies are in
    // the world.
    UFUNCTION()
    protected void Check_TargetTraceable(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto Center = utils_transform::Get_EntityCurrentLocation(_Target.Root);
        const auto Across = Get_Right() * 200.0;
        auto Settings = Make_HitQuery(Center - Across, Center + Across, 5.0f);
        Settings.Set_IgnoredEntities(_Crawler.Get_AttackIgnoredEntities());
        const auto Result = utils_probe_trace::Request_SingleShapeTrace(InHandle, Settings);
        FCk_Handle HitZone = utils_hit_zone::TryGet_Zone(Result.Get_HitEntity());
        FCk_Handle TargetZone = _Target.Zone;
        const auto Traceable = ck::IsValid(HitZone) && HitZone == TargetZone;

        ++_TraceablePolls;
        if (Traceable == false && _TraceablePolls > 240)
        {
            const FString HitName = ck::IsValid(Result.Get_HitEntity()) ? f"{utils_handle::Get_DebugName(Result.Get_HitEntity())}" : "nothing";
            FinishFailure(f"no hurtbox of the target's zone (first hurtbox valid {ck::IsValid(_Target.Hurtbox)}) is the first hit across it: hit {HitName} ({Result.Get_HitKind() :n}) at {Result.Get_HitLocation().ToString()}, target at {Center.ToString()}; {Get_CrawlerDiagnostics()}");
        }

        auto Res = OutResult;
        Res.Set(Traceable);
    }

    // Target and start in one frame, so they drain together.
    UFUNCTION()
    protected void Step_TargetAndStart(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _RecordMark = _Records.Num();
        _AdmissionPolls = 0;
        _Crawler.Request_SetCombatTarget(FMars_Request_Crawler_SetCombatTarget(_Target.Entity));
        _Crawler.Request_StartAttack(FMars_Request_Crawler_StartAttack(_Target.Entity));
    }

    // Holds once Windup was entered; fails the test with the recorded reason if the start was rejected.
    UFUNCTION()
    protected void Check_Admitted(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        if (Find_RecordSinceMark(EMars_Crawler_AttackPhase::Windup) >= 0)
        {
            Res.Set(true);
            return;
        }

        ++_AdmissionPolls;
        if (_AdmissionPolls > 60 && _Crawler.Get_HasPendingCombatRequests() == false)
        {
            const auto ToTarget = utils_transform::Get_EntityCurrentLocation(_Target.Root) - BodyLocation();
            const auto FacingError = utils_crawler::Get_PlanarAngleDegrees(Get_Forward(), ToTarget, FVector::UpVector);
            FinishFailure(f"the start was not admitted (last reject {Get_LastRejectText()}, phase {_Crawler.Get_AttackPhase() :n}, facing error {FacingError :.2} deg, target {ToTarget.Size2D() :.1} cm away; {Get_CrawlerDiagnostics()})");
        }

        Res.Set(false);
    }

    // Holds once the attack requested last has come back to Idle.
    UFUNCTION()
    protected void Check_AttackFinished(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Find_RecordSinceMark(EMars_Crawler_AttackPhase::Idle) >= 0);
    }

    UFUNCTION()
    protected void Check_InWindup(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Crawler.Get_AttackPhase() == EMars_Crawler_AttackPhase::Windup);
    }

    UFUNCTION()
    protected void Check_InRecover(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Crawler.Get_AttackPhase() == EMars_Crawler_AttackPhase::Recover);
    }

    UFUNCTION()
    protected void Check_InCancelRecover(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Crawler.Get_AttackPhase() == EMars_Crawler_AttackPhase::CancelRecover);
    }

    UFUNCTION()
    protected void Check_InCooldown(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Crawler.Get_AttackPhase() == EMars_Crawler_AttackPhase::Cooldown);
    }

    UFUNCTION()
    protected void OnAttackPhaseChanged(FCk_Handle_Crawler InCrawler, EMars_Crawler_AttackPhase InOld, EMars_Crawler_AttackPhase InNew)
    {
        auto Record = FMars_AutoTest_CrawlerMelee_PhaseRecord();
        Record.Old = InOld;
        Record.New = InNew;
        Record.Frame = utils_time::Get_FrameCounter();
        Record.Generation = InCrawler.Get_AttackGeneration();
        Record.DamageCommitted = InCrawler.Get_AttackDamageCommitted();
        Record.CommittedSampleId = InCrawler.Get_AttackCommittedSampleId();
        Record.AcknowledgedSampleId = InCrawler.Get_AttackAcknowledgedSampleId();
        Record.ActionOffset = InCrawler.Get_Fragment(FMars_Fragment_Crawler_Attack).RequestedActionOffset.GetLocation();
        Record.DamageRequests = InCrawler.Get_CombatDealer().Get_HitsDealt() + InCrawler.Get_CombatDealer().Get_HitsRejected();
        Record.LastCancel = InCrawler.Get_AttackLastCancel();
        const auto RootTransform = utils_transform::Get_EntityCurrentTransform(InCrawler.As_Transform());
        Record.RootLocation = RootTransform.GetLocation();
        Record.RootForward = RootTransform.GetRotation().GetForwardVector();
        Record.Speed = utils_surface_motion::Get_Velocity(InCrawler.Get_Motion()).Size();
        const auto Navigator = InCrawler.Get_Navigator();
        Record.NavigatorMoving = Navigator.Get_Status() == EMars_SurfaceNavigator_Status::Moving;
        Record.NavigatorPending = Navigator.Get_HasPendingRequests();
        Record.Leaf = InCrawler.Get_Brain().Get_LeafClass();
        Record.EngageStage = InCrawler.Get_EngageStage();
        _Records.Add(Record);
    }
}
