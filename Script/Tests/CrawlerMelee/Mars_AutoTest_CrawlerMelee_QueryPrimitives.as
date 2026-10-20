// The query primitives the crawler's hit resolver relies on, observed at runtime against real
// registered Probe.Mars.HitZone hurtboxes, each with the resolver's settings (sphere, Blocking world policy, Silent):
//   (b) an ordinary sweep through a hurtbox reports it;
//   (a) a ZERO-TRAVEL sphere (Start == End) sitting inside a hurtbox, or centred on its face, reports it - the
//       point-blank, fully reach-constrained strike depends on this initial-overlap report (CollideWithBackFaces);
//   (c) a static Jolt wall between the start and a hurtbox blocks: the first hit is the World hit, not the hurtbox, also
//       when the sweep starts inside the wall (World at fraction 0);
//   (d) a hurtbox listed in Set_IgnoredEntities is not reported while a second hurtbox further along still is;
//   (e) a script processor in FGroup_Overlap, ordered after the five probe processors, sees a hurtbox at the location
//       its target was moved to in THIS frame's FGroup_Gameplay_Script - through a vertical-sweep measuring instrument
//       (synchronization) and through the zero-travel query itself.
// (b) runs before (a) so a failing zero-travel query cannot be mistaken for a hurtbox that has not joined the physics
// world yet. Each primitive has its own target, 1000 uu apart along Y, so no query sees another primitive's hurtbox.
// Every observation is also logged with the prefix [CrawlerMelee].
class UMars_AutoTest_CrawlerMelee_QueryPrimitives : UMars_AutoTestRig_CrawlerMelee
{
    default _TimeoutSeconds = 30.0f;
    default _Origin = FVector(-150000.0, -150000.0, 600.0);

    private const float32 k_Radius = 10.0f;
    private const FVector k_HalfExtents = FVector(20.0, 20.0, 20.0);
    private const float64 k_LocationTolerance = 1.0;

    private FCk_Handle _Self;

    // (a) / (b)
    private FMars_AutoTest_CrawlerMelee_Target _TargetA;
    private FCk_ShapeCast_Result _SweepA;

    // (c)
    private FMars_AutoTest_CrawlerMelee_Target _TargetC;
    private FCk_Handle _WallC;

    // (d)
    private FMars_AutoTest_CrawlerMelee_Target _TargetD;
    private FCk_Handle _FarHurtboxD;

    // (e)
    private FMars_AutoTest_CrawlerMelee_Target _TargetE;
    private FCk_Handle _Observer;

    private FVector Get_CenterA() const { return _Origin; }
    private FVector Get_CenterC() const { return _Origin + FVector(0.0, 1000.0, 0.0); }
    private FVector Get_CenterD() const { return _Origin + FVector(0.0, 2000.0, 0.0); }
    private FVector Get_OldLocationE() const { return _Origin + FVector(0.0, 3000.0, 0.0); }
    private FVector Get_NewLocationE() const { return _Origin + FVector(0.0, 3300.0, 0.0); }

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        _Self = InHandle;

        _TargetA = SpawnCombatTarget(InHandle, Get_CenterA(), k_HalfExtents);

        // The wall stands between x = -110 and -90; the hurtbox spans x = -20 .. 20.
        _TargetC = SpawnCombatTarget(InHandle, Get_CenterC(), k_HalfExtents);
        _WallC = SpawnWall(InHandle, Get_CenterC() + FVector(-100.0, 0.0, 0.0), FVector(10.0, 100.0, 100.0));

        // Near hurtbox at the root (x = -20 .. 20), far hurtbox at x = 100 .. 140.
        _TargetD = SpawnCombatTarget(InHandle, Get_CenterD(), k_HalfExtents);
        _FarHurtboxD = AddHurtbox(_TargetD, k_HalfExtents, FTransform(FRotator::ZeroRotator, FVector(120.0, 0.0, 0.0)));

        _TargetE = SpawnCombatTarget(InHandle, Get_OldLocationE(), k_HalfExtents);
        _Observer = utils_entity_lifetime::Request_CreateEntity(InHandle);
        auto Sample = FMars_TESTONLY_CrawlerMelee_OverlapSample();
        Sample.OldLocation = Get_OldLocationE();
        Sample.NewLocation = Get_NewLocationE();
        Sample.Radius = k_Radius;
        Sample.ExpectedHurtbox = _TargetE.Hurtbox;
        _Observer.Add_Fragment(Sample);
        auto Move = FMars_TESTONLY_CrawlerMelee_MoveRequest();
        Move.TargetRoot = _TargetE.Root;
        Move.Destination = FTransform(FRotator::ZeroRotator, Get_NewLocationE());
        _Observer.Add_Fragment(Move);

        Add_Step_WaitUntil("(b) a sweep through target A's hurtbox reports it", n"Check_SweepHitsA", k_SlowPolls, 0);
        Add_Step("(b) the sweep hit is A's hurtbox; (a) a zero-travel sphere inside it reports it", n"Step_AssertSweepAndZeroTravel");
        Add_Step_WaitUntil("(c) target C's hurtbox and the wall are both traceable", n"Check_WallAndTargetCLive", k_SlowPolls, 0);
        Add_Step("(c) a sweep through the wall toward C's hurtbox is blocked by the wall", n"Step_AssertWallBlocks");
        Add_Step_WaitUntil("(d) target D's near and far hurtboxes are both traceable", n"Check_BothHurtboxesDLive", k_SlowPolls, 0);
        Add_Step("(d) ignoring D's near hurtbox reports the far one and never the near one", n"Step_AssertIgnoredHurtbox");
        Add_Step_WaitUntil("(e) the Overlap-group sampler has ticked", n"Check_SamplerTicked", k_SlowPolls, 0);
        Add_Step_WaitUntil("(e) the sampler's sweep instrument sees target E's hurtbox at its old location", n"Check_SamplerSeesOldLocation", k_SlowPolls, 0);
        Add_Step("(e) arm the Gameplay_Script move of target E", n"Step_ArmMove");
        Add_Step_WaitUntil("(e) the sampler's sweep instrument sees target E's hurtbox at its new location", n"Check_SamplerSeesNewLocation", k_SlowPolls, 0);
        Add_Step("(e) the new location was seen in the frame of the move", n"Step_AssertSameFrame");
        Run_Steps(InHandle);
    }

    //----------------------------------------------------------------------------------------------------------------------
    // (a) / (b)
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void Check_SweepHitsA(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        _SweepA = utils_probe_trace::Request_SingleShapeTrace(_Self,
            Make_HitQuery(Get_CenterA() + FVector(-200.0, 0.0, 0.0), Get_CenterA() + FVector(200.0, 0.0, 0.0), k_Radius));

        // A miss returns a default result whose HitKind reads Probe, so the hit entity is what tells a hit apart.
        auto Res = OutResult;
        Res.Set(ck::IsValid(_SweepA.Get_HitEntity()));
    }

    UFUNCTION()
    private void Step_AssertSweepAndZeroTravel(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto SweepIsHurtbox = _SweepA.Get_HitKind() == ECk_ProbeTrace_HitKind::Probe && _SweepA.Get_HitEntity() == _TargetA.Hurtbox;
        ck::Trace(f"[CrawlerMelee] (b) sweep: kind={_SweepA.Get_HitKind() :n} isHurtboxA={SweepIsHurtbox} location={_SweepA.Get_HitLocation().ToString()}");
        Assert_True(SweepIsHurtbox, f"(b) an ordinary sweep through target A reports A's hurtbox as a Probe hit (kind {_SweepA.Get_HitKind() :n})");

        // Fully inside: a 10 uu sphere at the centre of a 20 uu half-extent box, Start == End.
        const auto ZeroTravel = utils_probe_trace::Request_SingleShapeTrace(_Self, Make_HitQuery(Get_CenterA(), Get_CenterA(), k_Radius));
        const auto ZeroTravelIsHurtbox = ck::IsValid(ZeroTravel.Get_HitEntity()) && ZeroTravel.Get_HitKind() == ECk_ProbeTrace_HitKind::Probe
            && ZeroTravel.Get_HitEntity() == _TargetA.Hurtbox;
        ck::Trace(f"[CrawlerMelee] (a) zero-travel: valid={ck::IsValid(ZeroTravel.Get_HitEntity())} kind={ZeroTravel.Get_HitKind() :n} isHurtboxA={ZeroTravelIsHurtbox} location={ZeroTravel.Get_HitLocation().ToString()} fraction={ZeroTravel.Get_Fraction()} normal={ZeroTravel.Get_SurfaceNormal().ToString()}");
        Assert_True(ZeroTravelIsHurtbox,
            "(a) a zero-travel sphere (Start == End) wholly inside a registered hurtbox reports that hurtbox (initial overlap)");
        Assert_True((ZeroTravel.Get_HitLocation() - Get_CenterA()).Size() <= k_LocationTolerance,
            f"(a) the zero-travel hit location is the query point (got {ZeroTravel.Get_HitLocation().ToString()})");
        Assert_True(ZeroTravel.Get_HitKind() == ECk_ProbeTrace_HitKind::Probe,
            f"(a) the zero-travel hit is a Probe hit (kind {ZeroTravel.Get_HitKind() :n})");
        Assert_True(ZeroTravel.Get_SurfaceNormal().ContainsNaN() == false,
            f"(a) the zero-travel hit carries a finite surface normal; the documented fallback for an initial overlap is up (got {ZeroTravel.Get_SurfaceNormal().ToString()})");

        // Straddling: a 10 uu sphere centred on the hurtbox's +X face, half inside it.
        const auto FacePoint = Get_CenterA() + FVector(k_HalfExtents.X, 0.0, 0.0);
        const auto Straddle = utils_probe_trace::Request_SingleShapeTrace(_Self, Make_HitQuery(FacePoint, FacePoint, k_Radius));
        const auto StraddleIsHurtbox = Straddle.Get_HitEntity() == _TargetA.Hurtbox;
        ck::Trace(f"[CrawlerMelee] (a-straddle) zero-travel on the face: valid={ck::IsValid(Straddle.Get_HitEntity())} kind={Straddle.Get_HitKind() :n} isHurtboxA={StraddleIsHurtbox} location={Straddle.Get_HitLocation().ToString()} fraction={Straddle.Get_Fraction()} normal={Straddle.Get_SurfaceNormal().ToString()}");
        Assert_True(StraddleIsHurtbox,
            "(a) a zero-travel sphere centred on the hurtbox's face (half inside) reports that hurtbox");
        Assert_True(Straddle.Get_HitKind() == ECk_ProbeTrace_HitKind::Probe,
            f"(a) the straddling zero-travel hit is a Probe hit (kind {Straddle.Get_HitKind() :n})");
        Assert_True(Straddle.Get_SurfaceNormal().ContainsNaN() == false,
            f"(a) the straddling zero-travel hit carries a finite surface normal (got {Straddle.Get_SurfaceNormal().ToString()})");
    }

    //----------------------------------------------------------------------------------------------------------------------
    // (c)
    //----------------------------------------------------------------------------------------------------------------------

    // C's hurtbox, swept from the far side (the path never reaches the wall), and the wall alone, swept above the hurtbox.
    UFUNCTION()
    private void Check_WallAndTargetCLive(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto Control = utils_probe_trace::Request_SingleShapeTrace(_Self,
            Make_HitQuery(Get_CenterC() + FVector(200.0, 0.0, 0.0), Get_CenterC() + FVector(-50.0, 0.0, 0.0), k_Radius));
        const auto WallOnly = utils_probe_trace::Request_SingleShapeTrace(_Self,
            Make_HitQuery(Get_CenterC() + FVector(-200.0, 0.0, 80.0), Get_CenterC() + FVector(-50.0, 0.0, 80.0), k_Radius));

        auto Res = OutResult;
        Res.Set(Control.Get_HitEntity() == _TargetC.Hurtbox && WallOnly.Get_HitKind() == ECk_ProbeTrace_HitKind::World);
    }

    UFUNCTION()
    private void Step_AssertWallBlocks(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Settings = Make_HitQuery(Get_CenterC() + FVector(-200.0, 0.0, 0.0), Get_CenterC() + FVector(200.0, 0.0, 0.0), k_Radius);
        const auto Single = utils_probe_trace::Request_SingleShapeTrace(_Self, Settings);
        const auto Multi = utils_probe_trace::Request_MultiShapeTrace(_Self, Settings);

        auto HurtboxReported = false;
        for (const auto& Hit : Multi)
        {
            if (Hit.Get_HitEntity() == _TargetC.Hurtbox)
            { HurtboxReported = true; }
        }

        ck::Trace(f"[CrawlerMelee] (c) wall: kind={Single.Get_HitKind() :n} isWall={Single.Get_HitEntity() == _WallC} location={Single.Get_HitLocation().ToString()} multi={Multi.Num()} hurtboxReported={HurtboxReported}");
        Assert_True(Single.Get_HitKind() == ECk_ProbeTrace_HitKind::World,
            f"(c) a static Jolt wall between the start and C's hurtbox is the first hit, a World hit (kind {Single.Get_HitKind() :n})");
        Assert_True(Single.Get_HitEntity() == _WallC,
            "(c) the World hit is attributed to the wall entity");
        Assert_True(Single.Get_HitLocation().X < Get_CenterC().X - 80.0,
            f"(c) the World hit lies at the wall, short of the hurtbox (hit x {Single.Get_HitLocation().X - Get_CenterC().X} relative to C)");
        Assert_True(HurtboxReported == false,
            f"(c) with the Blocking world policy, C's hurtbox beyond the wall is not reported at all ({Multi.Num()} hit(s))");

        // A sweep that STARTS inside the wall (its centre, x = -100) and runs on through C's hurtbox.
        const auto Inside = Make_HitQuery(Get_CenterC() + FVector(-100.0, 0.0, 0.0), Get_CenterC() + FVector(200.0, 0.0, 0.0), k_Radius);
        const auto InsideSingle = utils_probe_trace::Request_SingleShapeTrace(_Self, Inside);
        const auto InsideMulti = utils_probe_trace::Request_MultiShapeTrace(_Self, Inside);

        auto InsideHurtboxReported = false;
        for (const auto& Hit : InsideMulti)
        {
            if (Hit.Get_HitEntity() == _TargetC.Hurtbox)
            { InsideHurtboxReported = true; }
        }

        ck::Trace(f"[CrawlerMelee] (c-inside) sweep starting inside the wall: kind={InsideSingle.Get_HitKind() :n} isWall={InsideSingle.Get_HitEntity() == _WallC} fraction={InsideSingle.Get_Fraction()} location={InsideSingle.Get_HitLocation().ToString()} multi={InsideMulti.Num()} hurtboxReported={InsideHurtboxReported}");
        Assert_True(InsideSingle.Get_HitKind() == ECk_ProbeTrace_HitKind::World,
            f"(c) a sweep that starts inside the wall reports the World hit first (kind {InsideSingle.Get_HitKind() :n})");
        Assert_True(InsideSingle.Get_HitEntity() == _WallC,
            "(c) the starting-inside World hit is attributed to the wall entity");
        Assert_True(InsideSingle.Get_Fraction() == 0.0f,
            f"(c) the starting-inside World hit is at fraction 0 (got {InsideSingle.Get_Fraction()})");
        Assert_True(InsideHurtboxReported == false,
            f"(c) a sweep that starts inside the wall never reports C's hurtbox behind it ({InsideMulti.Num()} hit(s))");
    }

    //----------------------------------------------------------------------------------------------------------------------
    // (d)
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void Check_BothHurtboxesDLive(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto Near = utils_probe_trace::Request_SingleShapeTrace(_Self,
            Make_HitQuery(Get_CenterD() + FVector(-200.0, 0.0, 0.0), Get_CenterD() + FVector(300.0, 0.0, 0.0), k_Radius));
        const auto Far = utils_probe_trace::Request_SingleShapeTrace(_Self,
            Make_HitQuery(Get_CenterD() + FVector(60.0, 0.0, 0.0), Get_CenterD() + FVector(300.0, 0.0, 0.0), k_Radius));

        auto Res = OutResult;
        Res.Set(Near.Get_HitEntity() == _TargetD.Hurtbox && Far.Get_HitEntity() == _FarHurtboxD);
    }

    UFUNCTION()
    private void Step_AssertIgnoredHurtbox(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Ignored = TArray<FCk_Handle>();
        Ignored.Add(_TargetD.Hurtbox);

        auto Settings = Make_HitQuery(Get_CenterD() + FVector(-200.0, 0.0, 0.0), Get_CenterD() + FVector(300.0, 0.0, 0.0), k_Radius);
        Settings.Set_IgnoredEntities(Ignored);

        const auto Single = utils_probe_trace::Request_SingleShapeTrace(_Self, Settings);
        const auto Multi = utils_probe_trace::Request_MultiShapeTrace(_Self, Settings);

        auto NearReported = false;
        auto FarReported = false;
        for (const auto& Hit : Multi)
        {
            if (Hit.Get_HitEntity() == _TargetD.Hurtbox)
            { NearReported = true; }

            if (Hit.Get_HitEntity() == _FarHurtboxD)
            { FarReported = true; }
        }

        ck::Trace(f"[CrawlerMelee] (d) ignored: singleIsFar={Single.Get_HitEntity() == _FarHurtboxD} singleIsNear={Single.Get_HitEntity() == _TargetD.Hurtbox} multi={Multi.Num()} nearReported={NearReported} farReported={FarReported}");
        Assert_True(Single.Get_HitEntity() == _FarHurtboxD,
            "(d) with D's near hurtbox ignored, the first hit is the far hurtbox further along the same sweep");
        Assert_True(NearReported == false,
            f"(d) the ignored near hurtbox appears nowhere in the multi-hit list ({Multi.Num()} hit(s))");
        Assert_True(FarReported,
            "(d) the far hurtbox, not ignored, is in the multi-hit list");
    }

    //----------------------------------------------------------------------------------------------------------------------
    // (e)
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void Check_SamplerTicked(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Observer.Get_Fragment(FMars_TESTONLY_CrawlerMelee_OverlapSample).Ticks > 0);
    }

    UFUNCTION()
    private void Check_SamplerSeesOldLocation(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Observer.Get_Fragment(FMars_TESTONLY_CrawlerMelee_OverlapSample).SweepOldLocationLastHitFrame >= 0);
    }

    UFUNCTION()
    private void Step_ArmMove(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto& Move = _Observer.Get_Fragment(FMars_TESTONLY_CrawlerMelee_MoveRequest);
        Move.Armed = true;
    }

    UFUNCTION()
    private void Check_SamplerSeesNewLocation(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Observer.Get_Fragment(FMars_TESTONLY_CrawlerMelee_OverlapSample).SweepFirstNewHitFrame >= 0);
    }

    // Why the same frame is the proof. The resolver will run in FGroup_Overlap and query the hurtboxes after the probe
    // processors have pushed this frame's entity transforms into the probe bodies; the target (the player, moved before
    // FGroup_Transform) has to be found where it IS this frame, not where it was last frame, or a strike sweeps against a
    // stale target and a dodge is judged a frame late. A first hit at the new location on MoveFrame + 1 would mean the probe
    // body still sat at the old location when the Overlap group ran on MoveFrame. The sampler also proves the converse on
    // MoveFrame: the old location no longer reports the hurtbox, and the new location never reported it before the move,
    // so the hit cannot come from a stale or oversized body.
    //
    // The sweep instrument proves the synchronization itself; the zero-travel assertions prove it for the resolver's own
    // query.
    UFUNCTION()
    private void Step_AssertSameFrame(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto& Sample = _Observer.Get_Fragment(FMars_TESTONLY_CrawlerMelee_OverlapSample);
        ck::Trace(f"[CrawlerMelee] (e) same-frame sweep instrument: moveFrame={Sample.MoveFrame} firstNewHitFrame={Sample.SweepFirstNewHitFrame} ticks={Sample.Ticks} newHitsBeforeMove={Sample.SweepNewLocationHitsBeforeMove} oldHitOnFirstNewHitFrame={Sample.SweepOldLocationHitOnFirstNewHitFrame} hurtboxAt={Sample.SweepHurtboxLocationAtFirstNewHit.ToString()}");
        ck::Trace(f"[CrawlerMelee] (e) same-frame zero-travel: moveFrame={Sample.MoveFrame} firstNewHitFrame={Sample.FirstNewHitFrame} oldLastHitFrame={Sample.OldLocationLastHitFrame} newHitsBeforeMove={Sample.NewLocationHitsBeforeMove} oldHitOnFirstNewHitFrame={Sample.OldLocationHitOnFirstNewHitFrame} hitLocation={Sample.FirstNewHitLocation.ToString()} hurtboxAt={Sample.HurtboxLocationAtFirstNewHit.ToString()}");

        Assert_True(Sample.MoveFrame >= 0, "(e) the Gameplay_Script producer requested the move and stamped its frame");

        // Synchronization, through the sweep instrument.
        Assert_True(Sample.SweepFirstNewHitFrame == Sample.MoveFrame,
            f"(e) the Overlap-group sampler's sweep reports the hurtbox at its new location in the frame of the move (move frame {Sample.MoveFrame}, first hit frame {Sample.SweepFirstNewHitFrame})");
        Assert_True(Sample.SweepFirstNewHitEntity == _TargetE.Hurtbox, "(e) the swept hit at the new location is target E's hurtbox");
        Assert_True((Sample.SweepHurtboxLocationAtFirstNewHit - Get_NewLocationE()).Size() <= k_LocationTolerance,
            f"(e) the hurtbox entity reads the new location within 1 cm in that frame (got {Sample.SweepHurtboxLocationAtFirstNewHit.ToString()})");
        Assert_True(Sample.SweepOldLocationHitOnFirstNewHitFrame == false,
            "(e) in the frame of the move a sweep across the old location no longer reports the hurtbox (the probe body moved, it did not grow)");
        Assert_Equals_Int(Sample.SweepNewLocationHitsBeforeMove, 0,
            "(e) a sweep across the new location never reported the hurtbox before the move (the same-frame assertion is not vacuous)");

        // The resolver's own zero-travel query.
        Assert_True(Sample.FirstNewHitFrame == Sample.MoveFrame,
            f"(e, zero-travel) the zero-travel query reports the hurtbox at its new location in the frame of the move (move frame {Sample.MoveFrame}, first hit frame {Sample.FirstNewHitFrame})");
        Assert_True(Sample.FirstNewHitEntity == _TargetE.Hurtbox, "(e, zero-travel) the zero-travel hit at the new location is target E's hurtbox");
        Assert_True((Sample.FirstNewHitLocation - Get_NewLocationE()).Size() <= k_LocationTolerance,
            f"(e, zero-travel) the zero-travel hit location is the new location within 1 cm (got {Sample.FirstNewHitLocation.ToString()})");
        Assert_True(Sample.OldLocationHitOnFirstNewHitFrame == false,
            "(e, zero-travel) in the frame of the move the old location no longer reports the hurtbox to the zero-travel query");
        Assert_Equals_Int(Sample.NewLocationHitsBeforeMove, 0,
            "(e, zero-travel) the zero-travel query never reported the hurtbox at the new location before the move");
    }
}
