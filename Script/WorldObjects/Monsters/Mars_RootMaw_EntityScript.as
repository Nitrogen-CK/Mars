// The Root Maw's pieces (Tools/Blender/mars_monsters/build_root_maw_pieces.py, imported by its
// unreal/mars_root_maw_ue.py), made from Stephen's model, in the body's frame (the ground under the bulb's axis at the
// origin, +X toward the maw): the head, ONE skinned mesh on two bones (`root` at the origin, `jaw` at the hinge on the
// back of the bulb, identity in component space; Stephen 2026-11-02: a rigid cut "looks like its tearing"), and the throat
// with the eyes, a rigid mesh. Change the art and these together.
namespace utils_root_maw
{
    const FString PieceFolder = "/Game/Mars/Gameplay/Monsters/RootMaw/Meshes";
    const FString HeadMeshPath = "/Game/Mars/Gameplay/Monsters/RootMaw/Meshes/RootMaw_Head_Mars_SKM.RootMaw_Head_Mars_SKM";
    const FName JawBone = n"jaw";

    // The jaw bone's pitch (component space; positive lifts the maw) at JawOpen 0 (the teeth meet) and 1 (gaping); the
    // model's own mouth, the bone's rest, is 0 degrees.
    const float64 JawShutDegrees = -10.0;
    const float64 JawWideDegrees = 32.0;

    TSoftObjectPtr<UStaticMesh> Get_PieceMesh(FString InPart)
    {
        const FString PieceName = f"RootMaw_{InPart}_Mars_SM";
        return TSoftObjectPtr<UStaticMesh>(FSoftObjectPath(f"{PieceFolder}/{PieceName}.{PieceName}"));
    }

    // The root trail (Tools/Blender/mars_monsters/unreal/mars_root_maw_niagara.py): its user parameters this script writes.
    const FString RootsSystemPath = "/Game/Mars/Gameplay/Monsters/RootMaw/Fx/RootMawRoots_Mars_NS.RootMawRoots_Mars_NS";
    const FName RootsParam_IdleRate = n"IdleRate";
    const FName RootsParam_Heading = n"Heading";
    const FName RootsParam_Speed = n"Speed";
    const FName RootsParam_RootScale = n"RootScale";

    // The throat's custom primitive data 0 is the eyes' Glow (RootMaw_Mars_M).
    const int32 ThroatCpd_Glow = 0;
    // Glow per second as the eyes come on, and as they go out.
    const float32 EyeOnRate = 3.0f;
    const float32 EyeOffRate = 1.2f;

    // A flinch: the Maw tips away from the blow by up to JoltDegrees about its base and is shoved JoltCm away, reaching the
    // full jolt JoltPeak of the way through the kernel's flinch and settling back over the rest.
    const float64 JoltDegrees = 10.0;
    const float64 JoltCm = 6.0;
    const float32 JoltPeak = 0.25f;

    // Alive and up it breathes (a slow bob, BobCm at BobHz) and leans into its glide (LeanDegrees at HuntSpeed).
    const float64 BobCm = 1.6;
    const float32 BobHz = 0.7f;
    const float64 LeanDegrees = 8.0;

    // Dead, it wilts back on its base as it sinks (WiltDegrees over WiltSeconds).
    const float64 WiltDegrees = 18.0;
    const float32 WiltSeconds = 1.2f;
}

// How the root trail is fed (RootMawRoots_Mars_NS; every other number is tuned on the asset).
struct FMars_RootMaw_Trail
{
    // Roots a second under a Maw that is up (on top of one per RootSpacing of its glide).
    UPROPERTY()
    float32 IdleRate = 6.0f;

    // Roots a second while it bursts up out of the ground: the bed grows in round it.
    UPROPERTY()
    float32 EmergeRate = 40.0f;

    // The whole trail's size (the roots, the bed under the head and how far they reach).
    UPROPERTY()
    float32 RootScale = 1.0f;
}

// `Mars.RootMaw.DebugKill 1`: every living Maw deals itself a lethal blow once (to watch it wilt in PIE).
const FConsoleVariable CVar_Mars_RootMawDebugKill("Mars.RootMaw.DebugKill", 0);
// Each new value of `Mars.RootMaw.DebugHit` lands one DebugHitDamage blow on every living Maw's body zone, struck by the
// combat target nearest it (to watch a startle and a flinch in PIE).
const FConsoleVariable CVar_Mars_RootMawDebugHit("Mars.RootMaw.DebugHit", 0);

namespace utils_root_maw
{
    const float32 DebugHitDamage = 25.0f;
}

// Placeable enemy: the Root Maw, composed by utils_root_maw::Add on the root at SpawnTransform (Clearance over the floor
// under the bulb). This script is the assembly: it builds the body node the kernel moves (it sinks while the Maw lies
// buried) and hangs everything seen off it: the skinned head (a poseable mesh: its jaw bone opens the maw) and the throat
// with the eyes; and,
// on a node at the ground under the root, the root trail (RootMawRoots_Mars_NS): roots grow round the Maw per unit it glides
// and in a bed under its head, and shrink and twist away behind it (Stephen 2026-11-02). Every frame it turns the jaw bone
// from the kernel's JawOpen, fades the eyes in while the Maw is up, breathes and leans it into its glide, jolts it on each of the
// kernel's flinches, wilts it once dead, and feeds the trail the kernel's ground velocity and how far it is up.
class UMars_RootMaw_EntityScript : UCk_GenericEntityScript_UE
{
    default _ShowInPlaceActors = true;
    default _Replication = ECk_Replication::DoesNotReplicate;

    // The root's transform: place it Clearance (30) above the floor it starts on.
    UPROPERTY(ExposeOnSpawn)
    FTransform SpawnTransform = FTransform::Identity;

    UPROPERTY(ExposeOnSpawn)
    FMars_RootMaw_Spec Spec;

    UPROPERTY(ExposeOnSpawn)
    bool WithVisuals = true;

    UPROPERTY(ExposeOnSpawn)
    bool DebugDraw = false;

    UPROPERTY(ExposeOnSpawn)
    FMars_RootMaw_Trail Trail;

    private FCk_Handle _Self;
    private FCk_Handle_RootMaw _Maw;

    private FCk_Handle_SceneNode _LookNode;

    private UPoseableMeshComponent _Head;
    private UStaticMeshComponent _Throat;
    private UNiagaraComponent _Roots;
    private float32 _Glow = 0.0f;
    private float32 _WrittenGlow = -1.0f;
    private float32 _JawPosed = -1.0f;
    private float32 _Time = 0.0f;
    private float32 _Wilt = 0.0f;
    private float32 _LastEmerge = 0.0f;

    private bool _DebugKillSent = false;
    private int32 _DebugHitSeen = 0;

    UFUNCTION(BlueprintOverride)
    ECk_EntityScript_ConstructionFlow DoConstruct(FCk_Handle& InHandle)
    {
        InHandle.Request_OverrideToSelf();
        utils_handle::Set_DebugName(InHandle, n"RootMaw");
        _Self = InHandle;
        _DebugHitSeen = CVar_Mars_RootMawDebugHit.GetInt();

        auto Root = utils_transform::Add(InHandle, SpawnTransform, ECk_Replication::DoesNotReplicate);
        auto Body = utils_scene_node::Create(Root, utils_root_maw::Get_BodyOffset(0.0f));
        auto MawSpec = Spec;
        MawSpec.Rig.Body = Body;

        _Maw = utils_root_maw::Add(Root, MawSpec);
        utils_entity_tag::Add(InHandle, n"TAG_MarsRootMaw");
        if (ck::Is_NOT_Valid(_Maw))
        { return ECk_EntityScript_ConstructionFlow::Finished; }

        if (WithVisuals)
        { BuildLook(Root, Body); }

        if (WithVisuals || DebugDraw)
        { utils_timer::Create_Tick(InHandle, FCk_Delegate_Timer(this, n"OnTick")); }

        return ECk_EntityScript_ConstructionFlow::Finished;
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Assembly
    //----------------------------------------------------------------------------------------------------------------------

    // The look node on the body (the flinch, the breath, the lean and the wilt move it) carries the head and the throat;
    // the trail rides its own node on the ground under the root, so burial does not take it under.
    private void BuildLook(FCk_Handle_Transform& InRoot, FCk_Handle_SceneNode InBody)
    {
        auto BodyNode = InBody.As_Transform();
        _LookNode = utils_scene_node::Create(BodyNode, FTransform::Identity);
        auto Look = _LookNode.As_Transform();

        if (FApp::CanEverRender() == false)
        { return; }

        // The component is created later; the mesh is set once it exists (OnHeadAdded).
        auto HeadParams = utils_unreal_component::Make_Params(UPoseableMeshComponent, ECk_UnrealComponent_TickPolicy::DoNotTick, n"RootMaw_Head");
        auto HeadPart = utils_unreal_component::Add(Look.H(), HeadParams);
        utils_unreal_component::BindTo_OnAdded(HeadPart, FCk_Delegate_UnrealComponent_OnAdded(this, n"OnHeadAdded"));

        UStaticMesh ThroatMesh = System::LoadAsset_Blocking(utils_root_maw::Get_PieceMesh("Throat"));
        if (ck::IsValid(ThroatMesh))
        {
            auto ThroatPart = Look.Add_MeshPart(this, FMars_MeshPart(FTransform::Identity, ThroatMesh, nullptr,
                collision::profile::NoCollision, n"RootMaw_Throat"));
            if (ck::IsValid(ThroatPart))
            { utils_unreal_component::BindTo_OnAdded(ThroatPart, FCk_Delegate_UnrealComponent_OnAdded(this, n"OnThroatAdded")); }
        }

        auto System = System::LoadAsset_Blocking(TSoftObjectPtr<UNiagaraSystem>(FSoftObjectPath(utils_root_maw::RootsSystemPath)));
        if (ck::IsValid(System))
        {
            auto Ground = utils_scene_node::Create(InRoot, FTransform(FRotator::ZeroRotator, FVector(0.0, 0.0, -utils_root_maw::Clearance)));
            auto Archetype = NewObject(this, UNiagaraComponent);
            Archetype.SetMobility(EComponentMobility::Movable);
            Archetype.SetAsset(System);
            Archetype.SetAutoActivate(true);
            auto Params = utils_unreal_component::Make_Params_FromArchetype(Archetype, ECk_UnrealComponent_TickPolicy::DoNotTick, n"RootMaw_Roots");
            auto Roots = utils_unreal_component::Add(Ground.H(), Params);
            utils_unreal_component::BindTo_OnAdded(Roots, FCk_Delegate_UnrealComponent_OnAdded(this, n"OnRootsAdded"));
        }
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Every frame
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void OnTick(FCk_Handle_Timer InHandle, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        FCk_Handle Entity = _Maw;
        if (ck::Is_NOT_Valid(_Maw) || utils_entity_lifetime::Get_IsPendingDestroy(Entity, ECk_EntityLifetime_DestructionPhase::BeginDestroy))
        { return; }

        const auto DeltaSeconds = float32(InDeltaT.Get_Seconds());
        _Time += DeltaSeconds;
        if (CVar_Mars_RootMawDebugKill.GetInt() != 0 && _DebugKillSent == false && _Maw.Get_IsDead() == false)
        {
            _DebugKillSent = true;
            auto Health = _Maw.Get_Monster().Get_BodyHealth();
            Health.Request_ApplyDamage(FMars_Request_Health_ApplyDamage(FMars_DamageEvent(100000.0f, GameplayTags::DamageType_Mars_Blunt)));
        }

        const auto DebugHit = CVar_Mars_RootMawDebugHit.GetInt();
        if (DebugHit != _DebugHitSeen)
        {
            _DebugHitSeen = DebugHit;
            if (DebugHit != 0 && _Maw.Get_IsDead() == false)
            { DebugStrike(); }
        }

        if (WithVisuals)
        {
            PoseJaw();
            PoseLook(DeltaSeconds);
            FadeEyes(DeltaSeconds);
            FeedRoots();
        }

        if (DebugDraw)
        { Draw(); }
    }

    private void PoseJaw()
    {
        const auto Jaw = _Maw.Get_JawOpen();
        if (Math::Abs(Jaw - _JawPosed) < 1e-4f || ck::Is_NOT_Valid(_Head))
        { return; }

        _JawPosed = Jaw;
        const auto Pitch = Math::Lerp(utils_root_maw::JawShutDegrees, utils_root_maw::JawWideDegrees, float64(Jaw));
        _Head.SetBoneRotationByName(utils_root_maw::JawBone, FRotator(Pitch, 0.0, 0.0), EBoneSpaces::ComponentSpace);
    }

    // The look node's offset on the body: the flinch's jolt away from the blow, the breath, the lean into the glide, and
    // once dead the wilt back on its base, all about the base (the body's origin, on the ground).
    private void PoseLook(float32 InDeltaSeconds)
    {
        if (ck::Is_NOT_Valid(_LookNode))
        { return; }

        const auto Body = _Maw.Get_BodyTransform();
        const auto MawSpec = _Maw.Get_Spec();
        auto Turn = FQuat::Identity;
        auto Shift = FVector::ZeroVector;

        if (_Maw.Get_IsDead())
        {
            _Wilt = Math::Min(_Wilt + InDeltaSeconds / utils_root_maw::WiltSeconds, 1.0f);
            Turn = FQuat(FRotator(utils_root_maw::WiltDegrees * utils_root_maw::Get_EaseInOut(_Wilt), 0.0, 0.0));
        }
        else
        {
            const auto Up = _Maw.Get_Emerge();
            Shift.Z = utils_root_maw::BobCm * Math::Sin(2.0 * PI * utils_root_maw::BobHz * _Time) * Up;

            const auto Velocity = Body.GetRotation().UnrotateVector(_Maw.Get_GroundVelocity());
            const auto Forward = Math::Clamp(Velocity.X / Math::Max(MawSpec.Locomotion.HuntSpeed, 1.0f), -1.0, 1.0);
            Turn = FQuat(FRotator(-utils_root_maw::LeanDegrees * Forward, 0.0, 0.0));

            if (_Maw.Get_IsFlinching())
            {
                auto Away = -_Maw.Get_Hurt().FlinchFrom;
                if (Away.IsNearlyZero())
                { Away = -Body.GetRotation().GetForwardVector(); }

                const auto Alpha = _Maw.Get_FlinchAlpha();
                const auto Peak = utils_root_maw::JoltPeak;
                const auto Jolt = Alpha < Peak ? utils_root_maw::Get_EaseOut(Alpha / Peak) : 1.0f - utils_root_maw::Get_EaseInOut((Alpha - Peak) / (1.0f - Peak));
                const auto AwayLocal = Body.GetRotation().UnrotateVector(Away);
                const auto Flat = FVector(AwayLocal.X, AwayLocal.Y, 0.0).GetSafeNormal();
                const auto Axis = FVector::UpVector.CrossProduct(Flat).GetSafeNormal();
                if (Axis.IsNearlyZero() == false)
                {
                    Turn = FQuat(Axis, Math::DegreesToRadians(utils_root_maw::JoltDegrees * Jolt)) * Turn;
                    Shift += Flat * utils_root_maw::JoltCm * Jolt;
                }
            }
        }

        utils_scene_node::Request_UpdateOffset(_LookNode, FCk_Request_SceneNode_UpdateRelativeTransform(FTransform(Turn, Shift)));
    }

    private void FadeEyes(float32 InDeltaSeconds)
    {
        const auto Awake = _Maw.Get_IsDead() == false && (_Maw.Get_Stance() == EMars_RootMaw_Stance::Emerged || _Maw.Get_Emerge() > 0.0f);
        const auto Target = Awake ? 1.0f : 0.0f;
        _Glow = Math::FInterpConstantTo(_Glow, Target, InDeltaSeconds, Awake ? utils_root_maw::EyeOnRate : utils_root_maw::EyeOffRate);
        if (ck::IsValid(_Throat) && Math::Abs(_Glow - _WrittenGlow) > 0.005f)
        {
            _WrittenGlow = _Glow;
            _Throat.SetCustomPrimitiveDataFloat(utils_root_maw::ThroatCpd_Glow, _Glow);
        }
    }

    // The trail: roots per unit of glide come from the system's own SpawnPerUnit (its component rides the ground node);
    // this writes the idle bed's rate (none buried or dead, a burst while it comes up, Trail.IdleRate once up) and the
    // kernel's ground velocity as the heading and speed the roots lead by.
    private void FeedRoots()
    {
        if (ck::Is_NOT_Valid(_Roots))
        { return; }

        const auto Emerge = _Maw.Get_Emerge();
        const auto Rising = Emerge > _LastEmerge && Emerge < 1.0f;
        _LastEmerge = Emerge;
        auto Rate = 0.0f;
        if (_Maw.Get_IsDead() == false)
        { Rate = Rising ? Trail.EmergeRate : (_Maw.Get_IsEmerged() ? Trail.IdleRate : 0.0f); }

        const auto Velocity = _Maw.Get_GroundVelocity();
        _Roots.SetVariableFloat(utils_root_maw::RootsParam_IdleRate, Rate);
        _Roots.SetVariableVec3(utils_root_maw::RootsParam_Heading, Velocity.GetSafeNormal());
        _Roots.SetVariableFloat(utils_root_maw::RootsParam_Speed, float32(Velocity.Size()));
    }

    private void DebugStrike()
    {
        const auto Here = _Maw.Get_Location();
        auto Striker = FCk_Handle();
        auto Best = 0.0;
        for (auto Candidate : utils_entity_tag::ForEach_Entity(_Maw, n"TAG_MarsCombatTarget"))
        {
            if (utils_root_maw::Get_IsTargetValid(Candidate) == false)
            { continue; }

            const auto Distance = (utils_transform::Get_EntityCurrentLocation(Candidate.As_Transform()) - Here).Size();
            if (ck::Is_NOT_Valid(Striker) || Distance < Best)
            {
                Striker = Candidate;
                Best = Distance;
            }
        }

        auto Event = FMars_DamageEvent(utils_root_maw::DebugHitDamage, GameplayTags::DamageType_Mars_Blunt);
        Event.Source.Instigator = Striker;
        Event.Source.Causer = Striker;
        auto Zone = _Maw.Get_Monster().Get_BodyZone();
        Zone.Request_Hit(FMars_Request_HitZone_Hit(Event));
    }

    private void Draw() const
    {
        const auto Frame = _Maw.Get_ActionFrame();
        if (Frame.Action == EMars_RootMaw_Action::None)
        { return; }

        const auto Color = Frame.Phase == EMars_RootMaw_ActionPhase::Active ? FLinearColor::Red : FLinearColor::Yellow;
        utils_debug_draw::DrawDebugSphere(_Maw.Get_MouthLocation(), _Maw.Get_Spec().Bite.Blow.Radius, 12, Color, 0.0f, 1.5f);
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Components
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void OnHeadAdded(FCk_Handle_UnrealComponent InHandle)
    {
        _Head = Cast<UPoseableMeshComponent>(utils_unreal_component::Get_Component(InHandle));
        if (ck::EnsureIfNot(ck::IsValid(_Head), f"[RootMaw] [{_Self.ToString()}] got no UPoseableMeshComponent for its head"))
        { return; }

        // Nothing on the Maw collides: its hurtbox and its surface motion's rays are its only physics.
        _Head.SetCollisionEnabled(ECollisionEnabled::NoCollision);
        USkeletalMesh HeadMesh = System::LoadAsset_Blocking(TSoftObjectPtr<USkeletalMesh>(FSoftObjectPath(utils_root_maw::HeadMeshPath)));
        if (ck::EnsureIfNot(ck::IsValid(HeadMesh), f"[RootMaw] [{_Self.ToString()}] its head mesh did not load"))
        { return; }

        _Head.SetSkinnedAssetAndUpdate(HeadMesh, true);
        _JawPosed = -1.0f;
    }

    UFUNCTION()
    private void OnThroatAdded(FCk_Handle_UnrealComponent InHandle)
    {
        _Throat = Cast<UStaticMeshComponent>(utils_unreal_component::Get_Component(InHandle));
        _WrittenGlow = -1.0f;
    }

    UFUNCTION()
    private void OnRootsAdded(FCk_Handle_UnrealComponent InHandle)
    {
        _Roots = Cast<UNiagaraComponent>(utils_unreal_component::Get_Component(InHandle));
        if (ck::EnsureIfNot(ck::IsValid(_Roots), f"[RootMaw] [{_Self.ToString()}] got no UNiagaraComponent for its roots"))
        { return; }

        _Roots.SetVariableFloat(utils_root_maw::RootsParam_RootScale, Trail.RootScale);
        FeedRoots();
    }
}
