// The searing rig: a Searing station on a transform-only root at an isolated origin, its pan node 100 uu up carrying the
// pan Implement (no swirl: the tests pin the ledger) and the pan: the pan mesh at the station's scale, a kinematic
// triangle-mesh body on its own child node (built by utils_searing::Add_PanBody, as the station builds it). There is no
// table or floor: a lost steak falls into the void until the kernel destroys it. The handlers record every signal; the
// steps heat the pan, look, and wait on the steak.
UCLASS(Abstract)
class UMars_AutoTestRig_Searing : UCk_AutoTest_Base
{
    protected const FVector k_Origin = FVector(-60000.0, 16000.0, -60000.0);
    // The station's pan: cooking_spec.py's pan (base radius 9.5, rim radius 14.5 at height 4.6, in the mesh's own cm) at
    // the station's scale, and its 4 cm cube at the station's own cube scale.
    protected const float32 k_PanScale = 2.5f;
    protected const float32 k_CubeScale = 3.0f;
    protected const float32 k_PanRimRadius = 14.5f;
    protected const float32 k_CubeHalf = 2.0f;

    protected FCk_Handle_Searing _Searing;
    // The specs the station was built from, nodes included.
    protected FMars_Searing_Spec _Spec;
    protected FMars_Implement_Spec _PanSpec;
    protected FCk_Handle_SceneNode _PanNode;
    protected FCk_Handle_Implement _Pan;
    protected FCk_Handle_JoltBody _PanBaseBody;

    protected TArray<FCk_Handle> _Spawned;
    protected TArray<EMars_Searing_Phase> _ContactPhases;
    protected TArray<EMars_Searing_Face> _Seared;
    protected int32 _ProgressSignals = 0;
    protected TArray<EMars_Searing_Sizzle> _Sizzles;
    protected TArray<EMars_Searing_Heat> _Heats;
    protected TArray<FCk_Handle> _Lost;
    protected int32 _Completed = 0;
    protected FMars_Searing_Tally _CompletedTally;

    // The game time of the first steak spawn and of its first landing (the settle time is their difference).
    protected float32 _FirstSpawnTime = -1.0f;
    protected float32 _FirstLandingTime = -1.0f;

    // SecondsPerFace 0.2, RespawnSeconds 0.2, LingerSeconds 0.5; the rest default.
    protected FMars_Searing_Spec Make_TestSpec()
    {
        auto Spec = FMars_Searing_Spec();
        Spec.Cook.SecondsPerFace = 0.2f;
        Spec.Loss.RespawnSeconds = 0.2f;
        Spec.Loss.LingerSeconds = 0.5f;
        // The station's values, so the kernel is tested on the pan it ships with.
        Spec.Loss.PanRadius = k_PanRimRadius * k_PanScale;
        Spec.Steak.HalfSize = k_CubeHalf * k_CubeScale;
        return Spec;
    }

    // InPanSpec is the pan Implement's (tilt, lift, orbit); its default has no orbit.
    protected void BuildStation(FCk_Handle InHandle, FMars_Searing_Spec InSpec, FMars_Implement_Spec InPanSpec = FMars_Implement_Spec())
    {
        _Spec = InSpec;
        _PanSpec = InPanSpec;

        auto StationEntity = utils_entity_lifetime::Request_CreateEntity(InHandle);
        auto Root = utils_transform::Add(StationEntity, FTransform(FRotator::ZeroRotator, k_Origin), ECk_Replication::DoesNotReplicate);
        _PanNode = utils_scene_node::Create(Root, FTransform(FRotator::ZeroRotator, FVector(0.0, 0.0, 100.0)));

        _PanSpec.Nodes = FMars_Implement_Nodes(_PanNode);
        _Pan = utils_implement::Add(_PanNode.H(), _PanSpec);
        _PanBaseBody = Build_Pan(_PanNode);

        _Spec.Nodes = FMars_Searing_Nodes(_Pan, _PanBaseBody);
        _Searing = utils_searing::Add(StationEntity, _Spec);

        _Searing.BindTo_OnHeatChanged(FMars_Delegate_Searing_OnHeatChanged(this, n"OnHeatChanged"));
        _Searing.BindTo_OnSteakSpawned(FMars_Delegate_Searing_OnSteakSpawned(this, n"OnSteakSpawned"));
        _Searing.BindTo_OnPanContactChanged(FMars_Delegate_Searing_OnPanContactChanged(this, n"OnPanContactChanged"));
        _Searing.BindTo_OnSearProgress(FMars_Delegate_Searing_OnSearProgress(this, n"OnSearProgress"));
        _Searing.BindTo_OnFaceSeared(FMars_Delegate_Searing_OnFaceSeared(this, n"OnFaceSeared"));
        _Searing.BindTo_OnSizzleChanged(FMars_Delegate_Searing_OnSizzleChanged(this, n"OnSizzleChanged"));
        _Searing.BindTo_OnSteakLost(FMars_Delegate_Searing_OnSteakLost(this, n"OnSteakLost"));
        _Searing.BindTo_OnCompleted(FMars_Delegate_Searing_OnCompleted(this, n"OnCompleted"));
    }

    protected FCk_Handle_JoltBody Build_Pan(FCk_Handle_SceneNode InPanNode)
    {
        auto PanNode = InPanNode;
        return utils_searing::Add_PanBody(PanNode, FMars_Searing_PanBodySpec(assets::FryPan_Mars_SM(), k_PanScale));
    }

    protected void Heat()
    {
        _Searing.Request_SetHeat(FMars_Request_Searing_SetHeat(EMars_Searing_Heat::Hot));
    }

    protected void Look(FVector InLookDelta)
    {
        _Searing.Request_Look(FMars_Request_Searing_Look(InLookDelta));
    }

    protected float32 Get_Now()
    {
        return float32(System::GetGameTimeInSeconds());
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Handlers
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    protected void OnHeatChanged(FCk_Handle_Searing InSearing, EMars_Searing_Heat InHeat)
    {
        _Heats.Add(InHeat);
    }

    UFUNCTION()
    protected void OnSteakSpawned(FCk_Handle_Searing InSearing, FCk_Handle InSteak)
    {
        _Spawned.Add(InSteak);
        if (_FirstSpawnTime < 0.0f)
        { _FirstSpawnTime = Get_Now(); }
    }

    UFUNCTION()
    protected void OnPanContactChanged(FCk_Handle_Searing InSearing, EMars_Searing_Phase InPhase)
    {
        _ContactPhases.Add(InPhase);
        if (InPhase == EMars_Searing_Phase::OnPan && _FirstLandingTime < 0.0f)
        { _FirstLandingTime = Get_Now(); }
    }

    UFUNCTION()
    protected void OnSearProgress(FCk_Handle_Searing InSearing, EMars_Searing_Face InFace, float32 InAlpha)
    {
        _ProgressSignals += 1;
    }

    UFUNCTION()
    protected void OnFaceSeared(FCk_Handle_Searing InSearing, EMars_Searing_Face InFace)
    {
        _Seared.Add(InFace);
    }

    UFUNCTION()
    protected void OnSizzleChanged(FCk_Handle_Searing InSearing, EMars_Searing_Sizzle InSizzle)
    {
        _Sizzles.Add(InSizzle);
    }

    UFUNCTION()
    protected void OnSteakLost(FCk_Handle_Searing InSearing, FCk_Handle InSteak)
    {
        _Lost.Add(InSteak);
    }

    UFUNCTION()
    protected void OnCompleted(FCk_Handle_Searing InSearing, FMars_Searing_Tally InTally)
    {
        _Completed += 1;
        _CompletedTally = InTally;
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Steps
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    protected void Step_Heat(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(ck::IsValid(_Searing), "the feature composed");
        Heat();
    }

    UFUNCTION()
    protected void Check_OnPan(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Searing.Get_IsOnPan());
    }

    UFUNCTION()
    protected void Check_Spawned1(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Spawned.Num() >= 1);
    }

    UFUNCTION()
    protected void Check_Spawned2(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Spawned.Num() >= 2);
    }

    UFUNCTION()
    protected void Check_DownFaceSeared(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Searing.Get_HasSteak() && _Searing.Get_IsDownFaceSeared());
    }

    UFUNCTION()
    protected void Check_Lost1(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Lost.Num() >= 1);
    }

    UFUNCTION()
    protected void Check_Completed(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Completed > 0);
    }

    // Every steak recorded lost has been destroyed.
    UFUNCTION()
    protected void Check_LostDestroyed(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto AllGone = true;
        for (const auto& Lost : _Lost)
        {
            if (ck::IsValid(Lost))
            { AllGone = false; }
        }

        auto Res = OutResult;
        Res.Set(AllGone);
    }
}

// The runner for every test that builds the pan: it REQUIRES the one warning CkJolt logs while baking the pan mesh (the
// two handle sweeps are inconsistently wound and get flipped), so the tests pass on the mesh as shipped and fail the day
// the mesh is fixed, which is when this class and the wrappers below it go.
UCLASS(Abstract)
class AMars_AutoTestRunner_SearingPan : ACk_AutoTestRunner
{
    UFUNCTION(BlueprintOverride)
    TArray<FString> Get_RequiredLogErrors() const
    {
        TArray<FString> Errors;
        Errors.Add("had 2 individually inside-out component(s) and 0 aggregate no-verdict component(s) normalized during the Jolt bake (1 healthy, 0 no-verdict, 0 open, 0 non-manifold, 2 inconsistent, 0 malformed)");
        return Errors;
    }
}
