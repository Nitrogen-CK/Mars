// A potion's assembly: the flask is the item's ordinary Presentation mesh (glass and cork); this script hangs the liquid
// inside it (from the item's root: the visual's component entity carries no transform to hang from) and keeps its surface
// level and sloshing, in the world and in the hand. Nothing here is simulation: the slosh is a drawing (a spring on the
// surface's tilt, driven by the flask's own motion), so it lives in the assembly and runs only where something can render.
//
// The liquid (PotionLiquid_Mars_SM, Tools/Blender/mars_environment/unreal/mars_potion_ue.py) wears the instance the item's
// Potion Look trait names (PotionLiquid_Mars_MI by default); it is the flask body's sphere and neck as one solid, pivot at
// the sphere's centre. Its material clips every pixel above the plane dot(X - centre, Normal) = Level * radius and draws
// the surface on the back faces under it. Because the body is a sphere, a plane at a fixed distance from its centre holds
// the same volume however the flask is turned, so the level is set once from the fill and only the normal moves: up, plus
// the slosh tilt.
//
// A pickle jar (the look's Vessel) is the same with a cylinder: PickleJarLiquid_Mars_SM, pivot at its middle, and the plane
// passes through the jar's axis at the fill height (the level is the fill in half-heights), which holds the volume while
// the surface stays clear of the floor and the lid.

namespace constants_potion
{
    const FString k_LiquidMeshPath = "/Game/Mars/Gameplay/Items/Potion/Meshes/PotionLiquid_Mars_SM.PotionLiquid_Mars_SM";
    // The liquid's instance when the item's Potion Look names none.
    const FString k_LiquidMaterialPath = "/Game/Mars/Gameplay/Items/Potion/Materials/PotionLiquid_Mars_MI.PotionLiquid_Mars_MI";

    // The body sphere's centre over the flask's pivot (its flat base), cm at MeshScale 1 (mars_potion_ue.BODY_CENTRE_CM).
    const float64 k_BodyCentreHeight = 4.05;

    // The pickle jar's liquid cylinder, and its middle over the jar's pivot (its base), cm at MeshScale 1
    // (mars_potion_ue.JAR_LIQUID_CENTRE_CM).
    const FString k_JarLiquidMeshPath = "/Game/Mars/Gameplay/Items/Potion/Meshes/PickleJarLiquid_Mars_SM.PickleJarLiquid_Mars_SM";
    const float64 k_JarLiquidCentreHeight = 4.5;

    // The liquid's custom primitive data: 0-2 the surface normal (world, unit), 3 the level (radii from the centre; a jar's
    // in half-heights), 4 Slosh
    // (0..1, the ripples' energy), 5 Phase (0..1, this potion's own), 6 Agitation (0..1, the cap's breakup).
    const int32 k_Cpd_Surface = 0;
    const int32 k_Cpd_Slosh = 4;
    const int32 k_Cpd_Phase = 5;
    const int32 k_Cpd_Agitation = 6;

    // The surface is a pendulum: its tilt (the normal's horizontal part) is pulled back to level by a spring of this
    // frequency, lightly damped, so a jolt sets it rocking for a few swings. A 9 cm flask of water sloshes at about 3 Hz.
    const float32 k_SloshHz = 2.6f;
    const float32 k_SloshDamping = 0.12f;
    // The surface lies square to the felt gravity (gravity minus the flask's acceleration), so a change of velocity Dv tips
    // it by Dv / g: this many cm/s^2 of gravity, and this gain over the real tip (a little livelier than water).
    const float32 k_GravityCmPerS2 = 980.0f;
    const float32 k_AccelerationGain = 1.2f;
    // Turning the flask drags the liquid along a little (the walls' friction): a share of the change of the flask's up
    // axis kicks the tilt.
    const float32 k_TurnDrag = 0.35f;
    // The tilt never lays the surface past this (as a tangent: 0.8 is about 39 degrees).
    const float32 k_MaxTilt = 0.8f;
    // The flask's speed is clamped to this before it feeds the spring: a mount change is a step, not a throw.
    const float32 k_MaxSpeedCmPerS = 600.0f;
    // The ripples follow how hard the surface is moving; this tilt rate (per second) is full energy.
    const float32 k_FullSloshRate = 2.0f;
    // Agitation is the slosh with a slow tail: it jumps with every jolt and eases back at this rate (per second, as an
    // FInterpTo), so a shaken flask keeps its churned cap and its bubbles for a moment after the surface stops rocking.
    const float32 k_AgitationSettleRate = 1.2f;
}

// `Mars.Potion.DebugSlosh 1`: every potion prints its speed, tilt and slosh once a second.
const FConsoleVariable CVar_Mars_PotionDebugSlosh("Mars.Potion.DebugSlosh", 0);

class UMars_Potion_EntityScript : UMars_WorldItem_EntityScript
{
    private FCk_Handle _Self;
    private UStaticMeshComponent _Liquid;
    private FCk_Handle_Timer _SloshTick;
    private float32 _Level = 0.0f;

    // The last sample the slosh measured from (the liquid's rendered location and up axis, game seconds); unset until the
    // first tick after the liquid appears or the flask changes mount.
    private bool _HasPrevSample = false;
    private FVector _PrevLocation = FVector::ZeroVector;
    private FVector _PrevUp = FVector::UpVector;
    private float64 _PrevTime = 0.0;
    private FVector _PrevVelocity = FVector::ZeroVector;

    // The surface normal's horizontal part (world) and its rate.
    private FVector _Tilt = FVector::ZeroVector;
    private FVector _TiltRate = FVector::ZeroVector;
    private float32 _Agitation = 0.0f;
    private float32 _DebugClock = 0.0f;

    UFUNCTION(BlueprintOverride)
    ECk_EntityScript_ConstructionFlow DoConstruct(FCk_Handle& InHandle)
    {
        _Self = InHandle;
        const auto Flow = Super::DoConstruct(InHandle);
        const auto Look = Get_Look();
        _Level = Look.Vessel == EMars_PotionVessel::Jar ? Math::Clamp(Look.Fill, 0.0f, 1.0f) * 2.0f - 1.0f : Get_LevelForFill(Look.Fill);
        return Flow;
    }

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Super::DoBeginPlay(InHandle);

        auto WorldItem = InHandle.As_WorldItem(ECk_SanityCheck::UnChecked);
        if (ck::IsValid(WorldItem))
        { WorldItem.BindTo_OnMountChanged(FMars_Delegate_WorldItem_OnMountChanged(this, n"OnMountChanged_Potion")); }
    }

    UFUNCTION(BlueprintOverride)
    void DoEndPlay(FCk_Handle InHandle)
    {
        Super::DoEndPlay(InHandle);
        DoDestroy_SloshTick();
        _Liquid = nullptr;
    }

    // The definition's Potion Look trait, else the defaults (the green potion, two thirds full).
    private FMars_PotionLook Get_Look() const
    {
        const UCk_InventoryItem_Definition ItemDefinition = Definition.Get();
        if (ck::IsValid(ItemDefinition))
        {
            const UMars_ItemTrait_PotionLook Trait = ItemDefinition.Get_ItemTraitByClass(UMars_ItemTrait_PotionLook);
            if (ck::IsValid(Trait))
            { return Trait.Look; }
        }
        return FMars_PotionLook();
    }

    // The liquid hangs from the item's root at the body's centre (the jar's middle), at the vessel's scale (the root is
    // unit scale; the Presentation's MeshScale lives on the vessel's component). Headless, there is nothing to slosh.
    protected void DoOnVisualMeshAdded(UStaticMeshComponent InMesh) override
    {
        if (FApp::CanEverRender() == false)
        { return; }

        const auto Look = Get_Look();
        const auto IsJar = Look.Vessel == EMars_PotionVessel::Jar;
        UStaticMesh Mesh = System::LoadAsset_Blocking(TSoftObjectPtr<UStaticMesh>(FSoftObjectPath(
            IsJar ? constants_potion::k_JarLiquidMeshPath : constants_potion::k_LiquidMeshPath)));
        auto MaterialPath = Look.LiquidMaterial;
        if (MaterialPath.IsNull())
        { MaterialPath = TSoftObjectPtr<UMaterialInterface>(FSoftObjectPath(constants_potion::k_LiquidMaterialPath)); }
        UMaterialInterface Material = System::LoadAsset_Blocking(MaterialPath);
        auto Root = _Self.As_Transform(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(Mesh) || ck::Is_NOT_Valid(Material) || ck::Is_NOT_Valid(Root))
        { return; }

        const auto Scale = InMesh.GetWorldScale();
        const auto CentreHeight = IsJar ? constants_potion::k_JarLiquidCentreHeight : constants_potion::k_BodyCentreHeight;
        auto Part = FMars_MeshPart(FTransform(FRotator::ZeroRotator, FVector(0.0, 0.0, CentreHeight * Scale.Z), Scale),
            Mesh, Material, collision::profile::NoCollision, n"Potion_Liquid");
        Part.CastShadow = false;
        Part.ReceivesDecals = false;

        auto Liquid = Root.Add_MeshPart(this, Part);
        if (ck::IsValid(Liquid))
        { utils_unreal_component::BindTo_OnAdded(Liquid, FCk_Delegate_UnrealComponent_OnAdded(this, n"OnLiquidAdded")); }
    }

    // The plane's distance from the sphere's centre, in radii (-1 empty .. 1 full), that leaves InFill of the sphere's
    // volume under it: a cap x radii high holds x^2 (3 - x) / 4 of the sphere (mars_potion_ue.level_for_fill).
    private float32 Get_LevelForFill(float32 InFill) const
    {
        const auto Target = Math::Clamp(InFill, 0.0f, 1.0f);
        auto Low = 0.0f;
        auto High = 2.0f;
        for (auto Iteration = 0; Iteration < 32; ++Iteration)
        {
            const auto Mid = 0.5f * (Low + High);
            if (Mid * Mid * (3.0f - Mid) * 0.25f < Target)
            { Low = Mid; }
            else
            { High = Mid; }
        }
        return 0.5f * (Low + High) - 1.0f;
    }

    private void Apply_Look(UStaticMeshComponent InLiquid)
    {
        InLiquid.SetCustomPrimitiveDataFloat(constants_potion::k_Cpd_Phase, Math::RandRange(0.0f, 1.0f));
        Write_Surface(0.0f);
    }

    private void Write_Surface(float32 InSlosh)
    {
        if (ck::Is_NOT_Valid(_Liquid))
        { return; }

        const auto Normal = (FVector::UpVector + _Tilt).GetSafeNormal();
        _Liquid.SetCustomPrimitiveDataVector4(constants_potion::k_Cpd_Surface, FVector4(Normal.X, Normal.Y, Normal.Z, _Level));
        _Liquid.SetCustomPrimitiveDataFloat(constants_potion::k_Cpd_Slosh, InSlosh);
        _Liquid.SetCustomPrimitiveDataFloat(constants_potion::k_Cpd_Agitation, _Agitation);
    }

    // The flask's motion feeds the spring: its change of velocity tips the surface toward the acceleration (the liquid piles
    // up behind), its turning drags it, and the spring rocks it back to level. Velocity is measured against game time
    // between samples that moved (a second tick in one frame, or a transform not pushed yet, sees the same place).
    private void Advance_Slosh(float32 InDeltaSeconds)
    {
        const auto Now = System::GetGameTimeInSeconds();
        const auto Location = _Liquid.GetWorldLocation();
        const auto Up = _Liquid.GetUpVector();
        if (_HasPrevSample == false)
        {
            _PrevLocation = Location;
            _PrevUp = Up;
            _PrevTime = Now;
            _PrevVelocity = FVector::ZeroVector;
            _HasPrevSample = true;
            return;
        }

        const auto Elapsed = float32(Now - _PrevTime);
        const auto Step = Location - _PrevLocation;
        auto Velocity = _PrevVelocity;
        auto Kick = FVector::ZeroVector;
        if (Elapsed > 1e-4f && (Step.SizeSquared() > 1e-6 || (Up - _PrevUp).SizeSquared() > 1e-8))
        {
            Velocity = (Step / Elapsed).GetClampedToMaxSize(constants_potion::k_MaxSpeedCmPerS);
            const auto Omega = 2.0f * PI * constants_potion::k_SloshHz;
            const auto DeltaVelocity = Velocity - _PrevVelocity;
            Kick = FVector(DeltaVelocity.X, DeltaVelocity.Y, 0.0) * (Omega * Omega / constants_potion::k_GravityCmPerS2 * constants_potion::k_AccelerationGain);
            const auto Turn = Up - _PrevUp;
            Kick += FVector(Turn.X, Turn.Y, 0.0) * (Omega * constants_potion::k_TurnDrag);

            _PrevLocation = Location;
            _PrevUp = Up;
            _PrevTime = Now;
        }
        else if (Elapsed > 0.1f)
        {
            // still for a tenth of a second: at rest
            Velocity = FVector::ZeroVector;
            _PrevTime = Now;
        }

        _PrevVelocity = Velocity;
        _TiltRate += Kick;
        Advance_Spring(InDeltaSeconds);

        const auto Slosh = Math::Clamp(float32(_TiltRate.Size()) / constants_potion::k_FullSloshRate, 0.0f, 1.0f);
        _Agitation = Math::Max(Slosh, Math::FInterpTo(_Agitation, Slosh, InDeltaSeconds, constants_potion::k_AgitationSettleRate));
        Write_Surface(Slosh);
        Print_DebugSlosh(Velocity, Slosh, InDeltaSeconds);
    }

    // A damped spring from the tilt to level (semi-implicit Euler in steps of at most 1/120 s, so a long frame cannot
    // blow it up), capped at k_MaxTilt.
    private void Advance_Spring(float32 InDeltaSeconds)
    {
        const auto Omega = 2.0f * PI * constants_potion::k_SloshHz;
        auto Remaining = Math::Min(InDeltaSeconds, 0.1f);
        while (Remaining > 0.0f)
        {
            const auto Step = Math::Min(Remaining, 1.0f / 120.0f);
            const auto Acceleration = _Tilt * -(Omega * Omega) - _TiltRate * (2.0f * constants_potion::k_SloshDamping * Omega);
            _TiltRate = _TiltRate + Acceleration * Step;
            _Tilt = _Tilt + _TiltRate * Step;
            Remaining -= Step;
        }

        if (_Tilt.Size() > constants_potion::k_MaxTilt)
        {
            _Tilt = _Tilt.GetSafeNormal() * constants_potion::k_MaxTilt;
            // the liquid hit the cap: what pushed it on is spent against the glass
            _TiltRate = _TiltRate - _Tilt.GetSafeNormal() * Math::Max(0.0, _TiltRate.DotProduct(_Tilt.GetSafeNormal()));
        }
    }

    private void Reset_Slosh()
    {
        _HasPrevSample = false;
        _PrevVelocity = FVector::ZeroVector;
        _Tilt = FVector::ZeroVector;
        _TiltRate = FVector::ZeroVector;
        _Agitation = 0.0f;
        Write_Surface(0.0f);
    }

    private void DoDestroy_SloshTick()
    {
        if (ck::Is_NOT_Valid(_SloshTick))
        { return; }

        utils_entity_lifetime::Request_DestroyEntity(_SloshTick.H());
        _SloshTick = FCk_Handle_Timer();
    }

    // Once a second while Mars.Potion.DebugSlosh is on.
    private void Print_DebugSlosh(FVector InVelocity, float32 InSlosh, float32 InDeltaSeconds)
    {
        if (CVar_Mars_PotionDebugSlosh.GetInt() == 0)
        { return; }

        _DebugClock += InDeltaSeconds;
        if (_DebugClock < 1.0f)
        { return; }

        _DebugClock = 0.0f;
        Print(f"[Potion] [{_Self.ToString()}] speed [{InVelocity.Size() :.0}] cm/s tilt [{_Tilt}] rate [{_TiltRate.Size() :.2}] slosh [{InSlosh :.2}] agitation [{_Agitation :.2}] level [{_Level :.2}]", 1.0f);
    }

    //--------------------------------------------------------------------------------------------------------------------------
    // Callbacks
    //--------------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void OnLiquidAdded(FCk_Handle_UnrealComponent InHandle)
    {
        _Liquid = Cast<UStaticMeshComponent>(utils_unreal_component::Get_Component(InHandle));
        if (ck::EnsureIfNot(ck::IsValid(_Liquid), f"[Potion] [{_Self.ToString()}] got no UStaticMeshComponent for its liquid"))
        { return; }

        _Liquid.SetFirstPersonPrimitiveType(utils_fphands::Get_FirstPersonType(_Self));
        Apply_Look(_Liquid);
        Reset_Slosh();

        if (ck::Is_NOT_Valid(_SloshTick))
        { _SloshTick = utils_timer::Create_Tick(_Self, FCk_Delegate_Timer(this, n"OnSloshTick")); }
    }

    // A pick-up, a stow or a drop is a jump, not a jolt: the surface restarts level.
    UFUNCTION()
    private void OnMountChanged_Potion(FCk_Handle_WorldItem InWorldItem, EMars_WorldItem_Mount InPrev, EMars_WorldItem_Mount InNew)
    {
        Reset_Slosh();
    }

    UFUNCTION()
    private void OnSloshTick(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        if (ck::IsValid(_Liquid))
        { Advance_Slosh(float32(InDeltaT.Get_Seconds())); }
    }
}

