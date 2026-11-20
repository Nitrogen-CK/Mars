// A direct sever of leg 0 of a crawler that stays put leaves exactly one severed limb near it. Within ten frames of its
// first sight every joint reads added; at every frame from then to the end every joint gap is within 2 cm and no piece's
// body touches another piece of the limb; a knee moves more than 5 degrees from the angle it had at the cut and never
// beyond 70; the limb reads at rest within 5 s of the sever, no piece's centre below the floor's top; it is gone after its
// 6 s lifetime.
class UMars_AutoTest_BodyPart_ASeveredLimbStaysJointedAndComesToRest : UMars_AutoTestRig_Crawler
{
    default _TimeoutSeconds = 25.0f;
    default _Origin = FVector(130000.0, 104000.0, 600.0);

    private const float32 k_LimbSeconds = 6.0f;
    private const float64 k_MostGapCm = 2.0;
    private const float64 k_LeastKneeSwingDegrees = 5.0;
    private const float64 k_MostKneeSwingDegrees = 70.0;
    private const float64 k_RestWithinSeconds = 5.0;

    private float64 _SeveredAt = 0.0;
    private FCk_Handle_SeveredLimb _Limb;
    private int32 _FirstSeenFrame = -1;
    // The lowest piece centre above the floor's top when the limb was first seen.
    private float64 _FirstSeenLowest = 0.0;
    private float64 _RestAt = -1.0;
    private float64 _WidestGap = 0.0;
    private TArray<float64> _KneeStart;
    private TArray<float64> _KneeSwing;
    private float64 _WidestHingeDegrees = 0.0;
    // The contacts the pieces' bodies reported with another piece of the same limb.
    private int32 _NeighbourContacts = 0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        SpawnFloorAndCrawler(InHandle, Make_Spec());

        Add_Step_WaitUntil("the crawler is composed, its gait Ready and its 4 parts registered", n"Check_Ready", k_SlowPolls, 0);
        Add_Step("sever leg 0 directly (30 Sever)", n"Step_Sever");
        Add_Step_WaitUntil("exactly one severed limb is near", n"Check_OneLimb", k_SlowPolls, 0);
        Add_Step_WaitUntil("every joint reads added within ten frames of the limb's first sight", n"Check_JointsAdded", 0, 0);
        Add_Step_WaitUntil("the limb reads at rest, every joint gap within 2 cm on the way", n"Check_AtRest", k_SlowPolls, 0);
        Add_Step("a knee bent more than 5 degrees and never beyond 70; at rest within 5 s", n"Step_AssertArticulated");
        Add_Step_WaitUntil("the limb is gone after its lifetime, every joint gap within 2 cm until then", n"Check_LimbGone", k_SlowPolls, 0);
        Add_Step("the limb lived its lifetime", n"Step_AssertLifetime");
        Run_Steps(InHandle);
    }

    private FMars_Crawler_Spec Make_Spec()
    {
        auto Spec = Make_CrawlerSpec(FVector(10.0, 10.0, 200.0));
        Spec.Vitals.LegDebris.LifetimeSeconds = k_LimbSeconds;
        return Spec;
    }

    // One sample of the limb: its widest joint gap (fails beyond k_MostGapCm), each knee's angle between its two
    // segments' X axes against the angle at first sight, and the hinges' own reading.
    private bool Sample_Limb()
    {
        if (ck::Is_NOT_Valid(_Limb))
        { return true; }

        for (int32 Index = 0; Index < _Limb.Get_JointCount(); ++Index)
        {
            const auto Gap = _Limb.Get_JointGap(Index);
            _WidestGap = Math::Max(_WidestGap, Gap);
            if (Gap > k_MostGapCm)
            {
                FinishFailure(f"joint {Index} of the limb gaps {Gap} cm (at most {k_MostGapCm}) {Describe_Limb()}");
                return false;
            }
        }

        const auto Pieces = _Limb.Get_Pieces();
        for (int32 Index = 0; Index + 2 < Pieces.Num(); ++Index)
        {
            const auto Upper = utils_transform::Get_EntityCurrentTransform(Pieces[Index]).GetRotation().GetAxisX();
            const auto Lower = utils_transform::Get_EntityCurrentTransform(Pieces[Index + 1]).GetRotation().GetAxisX();
            const auto Angle = Math::RadiansToDegrees(Math::Acos(Math::Clamp(Upper.DotProduct(Lower), -1.0, 1.0)));
            if (_KneeStart.Num() <= Index)
            {
                _KneeStart.Add(Angle);
                _KneeSwing.Add(0.0);
            }

            _KneeSwing[Index] = Math::Max(_KneeSwing[Index], Math::Abs(Angle - _KneeStart[Index]));
        }

        const auto Joints = _Limb.Get_Joints();
        for (int32 Index = 0; Index + 1 < Joints.Num(); ++Index)
        {
            if (ck::IsValid(Joints[Index]) && utils_jolt_constraint::Get_IsConstraintAdded(Joints[Index]))
            { _WidestHingeDegrees = Math::Max(_WidestHingeDegrees, float64(Math::Abs(utils_jolt_constraint::Get_Hinge_CurrentAngleDegrees(Joints[Index])))); }
        }

        return true;
    }

    private FString Describe_Limb()
    {
        FString Knees = "";
        for (int32 Index = 0; Index < _KneeStart.Num(); ++Index)
        { Knees += f"{_KneeStart[Index]}/{_KneeSwing[Index]},"; }

        FString Poses = "";
        auto Lift = -1.0;
        if (ck::IsValid(_Limb))
        {
            Lift = _Limb.Get_BirthLift();
            for (auto Piece : _Limb.Get_Pieces())
            { Poses += f"({utils_transform::Get_EntityCurrentLocation(Piece) - _Origin}),"; }
        }

        return f"[widestGap {_WidestGap} contacts {_NeighbourContacts} knees(start/swing) {Knees} widestHinge {_WidestHingeDegrees} lift {Lift} bornLowest {_FirstSeenLowest} restAt {_RestAt - _SeveredAt} pieces {Poses}]";
    }

    private void Bind_PieceContacts()
    {
        for (auto Piece : _Limb.Get_Pieces())
        {
            FCk_Handle Entity = Piece;
            auto Body = Entity.As_JoltBody(ECk_SanityCheck::UnChecked);
            if (ck::IsValid(Body))
            {
                utils_jolt_body::BindTo_OnJoltBodyContactAdded(Body, FCk_Delegate_JoltBody_OnContact(this, n"OnPieceContact"));
                utils_jolt_body::BindTo_OnJoltBodyContactPersisted(Body, FCk_Delegate_JoltBody_OnContact(this, n"OnPieceContact"));
            }
        }
    }

    UFUNCTION()
    private void OnPieceContact(FCk_Handle_JoltBody InBody, FCk_JoltBody_Payload_OnContact InPayload)
    {
        if (ck::Is_NOT_Valid(_Limb))
        { return; }

        FCk_Handle BodyEntity = InBody;
        const FCk_Handle OtherEntity = InPayload.Get_OtherEntity();
        const auto Pieces = _Limb.Get_Pieces();
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
        { return; }

        _NeighbourContacts += 1;
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Steps
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void Step_Sever(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Part = _Crawler.Get_LegParts()[0];
        Part.Request_Sever(FMars_Request_BodyPart_Sever(FMars_DamageEvent(30.0f, GameplayTags::DamageType_Mars_Sever)));
        _SeveredAt = System::GetGameTimeInSeconds();
    }

    UFUNCTION()
    private void Check_OneLimb(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto Limbs = Get_LimbsNear(InHandle);
        if (Limbs.Num() > 1)
        {
            FinishFailure(f"{Limbs.Num()} limbs near the crawler for one severed leg");
            return;
        }

        auto Res = OutResult;
        if (Limbs.Num() == 0)
        {
            Res.Set(false);
            return;
        }

        _Limb = Limbs[0];
        _FirstSeenFrame = int32(utils_time::Get_FrameCounter());
        _FirstSeenLowest = 1000000.0;
        for (auto Piece : _Limb.Get_Pieces())
        { _FirstSeenLowest = Math::Min(_FirstSeenLowest, utils_transform::Get_EntityCurrentLocation(Piece).Z - _Origin.Z); }
        Res.Set(Sample_Limb());
    }

    UFUNCTION()
    private void Check_JointsAdded(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        if (Sample_Limb() == false)
        { return; }

        const auto Frames = int32(utils_time::Get_FrameCounter()) - _FirstSeenFrame;
        const auto Simulated = Get_IsLimbSimulated(_Limb);
        if (Simulated)
        { Bind_PieceContacts(); }

        if (Simulated == false && Frames > 10)
        {
            FinishFailure(f"the limb's bodies and joints are not all added {Frames} frames after its first sight {Describe_Limb()}");
            return;
        }

        auto Res = OutResult;
        Res.Set(Simulated);
    }

    UFUNCTION()
    private void Check_AtRest(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        if (Sample_Limb() == false)
        { return; }

        if (ck::Is_NOT_Valid(_Limb))
        {
            FinishFailure(f"the limb ended before it read at rest {Describe_Limb()}");
            return;
        }

        auto Res = OutResult;
        Res.Set(_Limb.Get_IsAtRest());
        if (_Limb.Get_IsAtRest())
        { _RestAt = System::GetGameTimeInSeconds(); }
    }

    UFUNCTION()
    private void Step_AssertArticulated(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Widest = 0.0;
        for (auto Swing : _KneeSwing)
        { Widest = Math::Max(Widest, Swing); }

        const auto Described = Describe_Limb();
        Log(f"[SeveredLimbTest] at rest {Described}");
        Assert_True(Widest > k_LeastKneeSwingDegrees, f"a knee moved {Widest} deg from its angle at the cut (more than {k_LeastKneeSwingDegrees}) {Describe_Limb()}");
        Assert_True(Widest <= k_MostKneeSwingDegrees, f"no knee moved beyond {k_MostKneeSwingDegrees} deg (the most {Widest})");
        Assert_True(_RestAt - _SeveredAt <= k_RestWithinSeconds, f"the limb read at rest {_RestAt - _SeveredAt} s after the sever (within {k_RestWithinSeconds})");
        Assert_Equals_Int(_NeighbourContacts, 0, f"no piece of the limb touched another piece of the same limb {Describe_Limb()}");
        if (ck::IsValid(_Limb))
        {
            const auto Pieces = _Limb.Get_Pieces();
            for (int32 Index = 0; Index < Pieces.Num(); ++Index)
            {
                const auto Height = utils_transform::Get_EntityCurrentLocation(Pieces[Index]).Z - _Origin.Z;
                Assert_True(Height >= 0.0, f"piece {Index} rests with its centre {Height} above the floor's top (not below it) {Describe_Limb()}");
            }
        }
    }

    UFUNCTION()
    private void Check_LimbGone(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        if (Sample_Limb() == false)
        { return; }

        auto Res = OutResult;
        Res.Set(Get_LimbsNear(InHandle).Num() == 0);
    }

    UFUNCTION()
    private void Step_AssertLifetime(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Lived = System::GetGameTimeInSeconds() - _SeveredAt;
        const auto Described = Describe_Limb();
        Log(f"[SeveredLimbTest] gone after {Lived} s {Described}");
        Assert_True(Lived >= k_LimbSeconds - 0.5, f"the limb lived {Lived} s (its lifetime is {k_LimbSeconds})");
    }
}
