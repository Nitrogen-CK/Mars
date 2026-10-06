// What every step of one Searing's tick reads: the kernel, its spec and the frame's real time.
struct FMars_Searing_Frame
{
    FCk_Handle_Searing Searing;
    FMars_Searing_Spec Spec;
    float32 DeltaSeconds = 0.0f;
}

// Every frame, in order: the steak's spawn, whether it is on the pan (on/off edges), the face it rests on (flips), its loss
// (and the lingering lost bodies), the sear of the face on the pan, the tally, and the sizzle edge last. The pan moves
// itself (an Implement); Jolt owns the steak's pose; the kernel reads it back through the entity transform and never
// writes it.
class UMars_Processor_Searing_Tick : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";

    // The steak's Resting counts a landing after this long apart as a hop (its own default; the kernel does not read hops).
    private const float32 k_HopMinSeconds = 0.12f;

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_Searing);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle, FMars_Fragment_Searing& InState)
    {
        auto Frame = FMars_Searing_Frame();
        Frame.Searing = InHandle.As_Searing();
        Frame.Spec = Frame.Searing.Get_Spec();
        Frame.DeltaSeconds = float32(InDeltaT.Get_Seconds());

        Advance_Spawn(Frame, InState);
        Advance_Contact(Frame, InState);
        Advance_RestingFace(Frame, InState);
        Advance_Loss(Frame, InState);
        Advance_Sear(Frame, InState);
        Advance_Tally(Frame, InState);
        Broadcast_SizzleEdge(Frame, InState);
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Steak lifecycle
    //----------------------------------------------------------------------------------------------------------------------

    // NoSteak counts down, then a fresh steak entity (a lifetime child of the station) appears HalfSize + SpawnLift above
    // the pan base top, flat (NegZ down, its resting face), with a dynamic box body and a Resting on the pan base body
    // (which tells whether it lies on the pan). It starts Airborne and becomes OnPan once it rests on the base.
    private void Advance_Spawn(FMars_Searing_Frame& InFrame, FMars_Fragment_Searing& InState)
    {
        if (InState.Phase != EMars_Searing_Phase::NoSteak)
        { return; }

        InState.Steak.RespawnCountdown -= InFrame.DeltaSeconds;
        if (InState.Steak.RespawnCountdown > 0.0f)
        { return; }

        const auto& SteakSpec = InFrame.Spec.Steak;
        const auto PanBaseWorld = InFrame.Searing.Get_PanBaseWorld();
        const auto SpawnLocal = FVector(0.0, 0.0, utils_searing::k_PanBaseHalfHeight + SteakSpec.HalfSize + SteakSpec.SpawnLift);

        auto Entity = utils_entity_lifetime::Request_CreateEntity(InFrame.Searing);
        utils_transform::Add(Entity, FTransform(PanBaseWorld.Rotator(), PanBaseWorld.TransformPosition(SpawnLocal)),
            ECk_Replication::DoesNotReplicate);

        auto Shape = FCk_Jolt_ShapeDimensions(ECk_Jolt_ShapeType::Box);
        Shape.Set_HalfExtents(FVector(SteakSpec.HalfSize, SteakSpec.HalfSize, SteakSpec.HalfSize));
        auto BodySpec = FCk_JoltBody_Spec(ECk_JoltBody_ShapeSource::ExplicitShape);
        BodySpec.Set_ShapeDimensions(Shape);
        BodySpec.Set_MotionType(ECk_MotionType::Dynamic);
        BodySpec.Set_MotionQuality(ECk_MotionQuality::LinearCast);
        BodySpec.Set_MassSource(ECk_JoltBody_MassSource::Explicit);
        BodySpec.Set_MassKg(SteakSpec.MassKg);
        BodySpec.Set_SurfaceSource(ECk_JoltBody_SurfaceSource::Explicit);
        BodySpec.Set_Friction(SteakSpec.Friction);
        BodySpec.Set_Restitution(SteakSpec.Restitution);
        BodySpec.Set_LinearDamping(SteakSpec.LinearDamping);
        BodySpec.Set_AngularDamping(SteakSpec.AngularDamping);
        // The Resting needs a Persisted contact every step from a resting awake steak.
        BodySpec.Set_PersistContacts(ECk_EnableDisable::Enable);
        auto Body = utils_jolt_body::Add(Entity, BodySpec);

        utils_resting::Add(Entity, FMars_Resting_Spec(InFrame.Spec.Nodes.PanBaseBody, SteakSpec.ContactGraceSeconds, k_HopMinSeconds));

        InState.Steak = FMars_Searing_SteakState();
        InState.Steak.Entity = Entity;
        InState.Steak.Body = Body;
        for (int32 Index = 0; Index < utils_searing::k_FaceCount; ++Index)
        { InState.Steak.FaceSear.Add(0.0f); }

        InState.Phase = EMars_Searing_Phase::Airborne;
        InState.LastProgressStep = -1;

        ck::Trace(f"[Searing] [{InFrame.Searing.ToString()}] spawned steak [{Entity.ToString()}]");

        if (InFrame.Searing.Has_Fragment(FMars_Fragment_Searing_Signals))
        { InFrame.Searing.Get_Fragment(FMars_Fragment_Searing_Signals).OnSteakSpawned.Broadcast(InFrame.Searing, Entity); }
    }

    // On the pan = the steak rests on the pan base (Resting) and its centre is over the disc. Done never changes here.
    private void Advance_Contact(FMars_Searing_Frame& InFrame, FMars_Fragment_Searing& InState)
    {
        if (InState.Phase != EMars_Searing_Phase::OnPan && InState.Phase != EMars_Searing_Phase::Airborne)
        { return; }

        const auto IsOnPan = InState.Steak.Entity.As_Resting().Get_IsResting() && Get_IsOverDisc(InFrame);

        if (InState.Phase == EMars_Searing_Phase::Airborne && IsOnPan)
        {
            InState.LastProgressStep = -1;
            InState.Phase = EMars_Searing_Phase::OnPan;

            ck::Trace(f"[Searing] [{InFrame.Searing.ToString()}] steak on the pan");
            Broadcast_PanContactChanged(InFrame, EMars_Searing_Phase::OnPan);
            return;
        }

        if (InState.Phase == EMars_Searing_Phase::OnPan && IsOnPan == false)
        {
            InState.Phase = EMars_Searing_Phase::Airborne;

            ck::Trace(f"[Searing] [{InFrame.Searing.ToString()}] steak off the pan");
            Broadcast_PanContactChanged(InFrame, EMars_Searing_Phase::Airborne);
        }
    }

    // A flip is the resting face changing: while on the pan, a down face other than the resting one that stays down for
    // k_FaceSettleSeconds becomes the resting face. Nothing is sampled at the on/off edges (a tumbling cube shows passing
    // faces there), and a tumble on the pan without leaving it counts too.
    private void Advance_RestingFace(FMars_Searing_Frame& InFrame, FMars_Fragment_Searing& InState)
    {
        if (InState.Phase != EMars_Searing_Phase::OnPan)
        { return; }

        const auto Down = InFrame.Searing.Get_DownFace();
        if (Down == InState.Steak.RestingFace)
        {
            InState.Steak.CandidateSeconds = 0.0f;
            return;
        }

        InState.Steak.CandidateSeconds += InFrame.DeltaSeconds;
        if (InState.Steak.CandidateSeconds < utils_searing::k_FaceSettleSeconds)
        { return; }

        const auto Previous = InState.Steak.RestingFace;
        InState.Steak.RestingFace = Down;
        InState.Steak.CandidateSeconds = 0.0f;
        InState.Tally.Flips += 1;

        ck::Trace(f"[Searing] [{InFrame.Searing.ToString()}] flipped {utils_searing::Get_FaceName(Previous)} -> "
            + f"{utils_searing::Get_FaceName(Down)} (flips {InState.Tally.Flips})");
    }

    // The steak's centre, in the pan base's frame, within PanRadius of the axis and between HalfSize below and three
    // HalfSizes above the base top (a steak hovering over the pan is not on it).
    private bool Get_IsOverDisc(const FMars_Searing_Frame& InFrame)
    {
        const auto Local = InFrame.Searing.Get_SteakPanLocal();
        const auto AboveTop = Local.Z - utils_searing::k_PanBaseHalfHeight;
        const auto HalfSize = InFrame.Spec.Steak.HalfSize;
        return Local.Size2D() <= InFrame.Spec.Loss.PanRadius && AboveTop >= -HalfSize && AboveTop <= 3.0 * HalfSize;
    }

    // A live steak whose centre left the disc (past PanRadius + HalfSize, or HalfSize below the base top) is lost: it
    // keeps simulating as a lingering body, the pan empties and a fresh steak follows RespawnSeconds later. Lingering
    // bodies are destroyed at LingerSeconds.
    private void Advance_Loss(FMars_Searing_Frame& InFrame, FMars_Fragment_Searing& InState)
    {
        Advance_LostSteaks(InFrame, InState);

        if (InState.Phase != EMars_Searing_Phase::OnPan && InState.Phase != EMars_Searing_Phase::Airborne)
        { return; }

        const auto Local = InFrame.Searing.Get_SteakPanLocal();
        const auto AboveTop = Local.Z - utils_searing::k_PanBaseHalfHeight;
        const auto HalfSize = InFrame.Spec.Steak.HalfSize;
        const auto OffTheDisc = Local.Size2D() > InFrame.Spec.Loss.PanRadius + HalfSize;
        const auto BelowTheTop = AboveTop < -HalfSize;
        if (OffTheDisc == false && BelowTheTop == false)
        { return; }

        const auto Lost = InState.Steak.Entity;
        InState.LostSteaks.Add(FMars_Searing_LostSteak(Lost));
        InState.Steak = FMars_Searing_SteakState();
        InState.Steak.RespawnCountdown = InFrame.Spec.Loss.RespawnSeconds;
        InState.Phase = EMars_Searing_Phase::NoSteak;
        InState.LastProgressStep = -1;
        InState.Tally.Losses += 1;

        ck::Trace(f"[Searing] [{InFrame.Searing.ToString()}] lost steak [{Lost.ToString()}] at pan-local {Local} (losses {InState.Tally.Losses})");

        if (InFrame.Searing.Has_Fragment(FMars_Fragment_Searing_Signals))
        { InFrame.Searing.Get_Fragment(FMars_Fragment_Searing_Signals).OnSteakLost.Broadcast(InFrame.Searing, Lost); }
    }

    private void Advance_LostSteaks(FMars_Searing_Frame& InFrame, FMars_Fragment_Searing& InState)
    {
        for (int32 Index = InState.LostSteaks.Num() - 1; Index >= 0; --Index)
        {
            InState.LostSteaks[Index].Age += InFrame.DeltaSeconds;
            if (InState.LostSteaks[Index].Age < InFrame.Spec.Loss.LingerSeconds)
            { continue; }

            const auto Entity = InState.LostSteaks[Index].Entity;
            InState.LostSteaks.RemoveAt(Index);

            // Already gone with a station torn down around it.
            if (ck::Is_NOT_Valid(Entity))
            { continue; }

            ck::Trace(f"[Searing] [{InFrame.Searing.ToString()}] destroyed lost steak [{Entity.ToString()}]");
            utils_entity_lifetime::Request_DestroyEntity(Entity);
        }
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Ledger
    //----------------------------------------------------------------------------------------------------------------------

    // The face on a hot pan sears toward 1 (never past it). Progress is reported at tenths, each face once at 1, and the
    // sixth seared face completes the steak.
    private void Advance_Sear(FMars_Searing_Frame& InFrame, FMars_Fragment_Searing& InState)
    {
        if (InState.Heat != EMars_Searing_Heat::Hot || InState.Phase != EMars_Searing_Phase::OnPan)
        { return; }

        const auto Face = InFrame.Searing.Get_DownFace();
        const auto Index = int32(Face);
        const auto Before = InState.Steak.FaceSear[Index];
        const auto After = Math::Min(1.0f, Before + InFrame.DeltaSeconds / InFrame.Spec.Cook.SecondsPerFace);
        InState.Steak.FaceSear[Index] = After;

        const auto Step = Math::FloorToInt(After * float32(utils_searing::k_SearSignalSteps));
        if (Step != InState.LastProgressStep)
        {
            InState.LastProgressStep = Step;
            if (InFrame.Searing.Has_Fragment(FMars_Fragment_Searing_Signals))
            {
                const auto Alpha = float32(Step) / float32(utils_searing::k_SearSignalSteps);
                InFrame.Searing.Get_Fragment(FMars_Fragment_Searing_Signals).OnSearProgress.Broadcast(InFrame.Searing, Face, Alpha);
            }
        }

        if (Before >= 1.0f || After < 1.0f)
        { return; }

        ck::Trace(f"[Searing] [{InFrame.Searing.ToString()}] face {utils_searing::Get_FaceName(Face)} seared");
        if (InFrame.Searing.Has_Fragment(FMars_Fragment_Searing_Signals))
        { InFrame.Searing.Get_Fragment(FMars_Fragment_Searing_Signals).OnFaceSeared.Broadcast(InFrame.Searing, Face); }

        if (InFrame.Searing.Get_SearedFaceCount() < utils_searing::k_FaceCount)
        { return; }

        InState.Phase = EMars_Searing_Phase::Done;

        ck::Trace(f"[Searing] [{InFrame.Searing.ToString()}] completed in {InState.Tally.Seconds :.2} s ({InState.Tally.Losses} lost, {InState.Tally.Flips} flips)");
        if (InFrame.Searing.Has_Fragment(FMars_Fragment_Searing_Signals))
        { InFrame.Searing.Get_Fragment(FMars_Fragment_Searing_Signals).OnCompleted.Broadcast(InFrame.Searing, InState.Tally); }
    }

    private void Advance_Tally(FMars_Searing_Frame& InFrame, FMars_Fragment_Searing& InState)
    {
        if (InState.Heat != EMars_Searing_Heat::Hot || InState.Phase == EMars_Searing_Phase::Done)
        { return; }

        InState.Tally.Seconds += InFrame.DeltaSeconds;
    }

    // Sizzling while hot, on the pan and the face on the pan is not yet seared; edges only.
    private void Broadcast_SizzleEdge(FMars_Searing_Frame& InFrame, FMars_Fragment_Searing& InState)
    {
        const auto Searing = InState.Heat == EMars_Searing_Heat::Hot
            && InState.Phase == EMars_Searing_Phase::OnPan
            && InFrame.Searing.Get_IsDownFaceSeared() == false;
        const auto Now = Searing ? EMars_Searing_Sizzle::Sizzling : EMars_Searing_Sizzle::Quiet;
        if (Now == InState.Sizzle)
        { return; }

        InState.Sizzle = Now;
        if (InFrame.Searing.Has_Fragment(FMars_Fragment_Searing_Signals))
        { InFrame.Searing.Get_Fragment(FMars_Fragment_Searing_Signals).OnSizzleChanged.Broadcast(InFrame.Searing, Now); }
    }

    private void Broadcast_PanContactChanged(FMars_Searing_Frame& InFrame, EMars_Searing_Phase InPhase)
    {
        if (InFrame.Searing.Has_Fragment(FMars_Fragment_Searing_Signals))
        { InFrame.Searing.Get_Fragment(FMars_Fragment_Searing_Signals).OnPanContactChanged.Broadcast(InFrame.Searing, InPhase); }
    }
}
