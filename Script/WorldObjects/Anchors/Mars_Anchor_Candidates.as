// What a resolved anchor can become. Every candidate takes the anchor's SpawnTransform and its FMars_Anchor_Context
// (property `Anchor`) and is spawned as the anchor's child. The street runs along local X; a gate's opening spans local
// Y (Mars_Gate_EntityScript.as), so a gate placed here blocks travel along X. Existing presets are spawned with runtime
// params, never subclassed or edited.

namespace utils_anchor
{
    const float64 k_CandidateFrameWidth = 240.0;
    const float64 k_CandidateFillerDepth = 40.0;
    const float64 k_CandidateFillerHeight = 260.0;

    // Two blocking walls that close the rest of the street beside a 2 m gate frame.
    void Add_CandidateSideFillers(UCk_EntityScript_UE InOuter, FCk_Handle_Transform& InRoot, float32 InSpanCm)
    {
        const auto FillerWidth = (float64(InSpanCm) - k_CandidateFrameWidth) * 0.5;
        if (FillerWidth <= 0.0)
        { return; }

        auto CubeMesh = engine::load::Cube();
        auto WallMaterial = assets::load::ProtoGrid_Wall_Mars_MI();
        const auto CentreY = k_CandidateFrameWidth * 0.5 + FillerWidth * 0.5;
        const auto Scale = FVector(k_CandidateFillerDepth, FillerWidth, k_CandidateFillerHeight) * 0.01;
        InRoot.Add_MeshPart(InOuter, FMars_MeshPart(FTransform(FRotator::ZeroRotator, FVector(0.0, -CentreY, k_CandidateFillerHeight * 0.5), Scale),
            CubeMesh, WallMaterial, collision::profile::BlockAll, n"AnchorFiller_Left"));
        InRoot.Add_MeshPart(InOuter, FMars_MeshPart(FTransform(FRotator::ZeroRotator, FVector(0.0, CentreY, k_CandidateFillerHeight * 0.5), Scale),
            CubeMesh, WallMaterial, collision::profile::BlockAll, n"AnchorFiller_Right"));
    }
}

// A closed street: a solid gate with no sink, and the fillers.
class UMars_Anchor_Rubble_EntityScript : UCk_GenericEntityScript_UE
{
    default _ShowInPlaceActors = false;
    default _Replication = ECk_Replication::DoesNotReplicate;

    UPROPERTY(ExposeOnSpawn)
    FTransform SpawnTransform = FTransform::Identity;

    UPROPERTY(ExposeOnSpawn)
    FMars_Anchor_Context Anchor;

    UFUNCTION(BlueprintOverride)
    ECk_EntityScript_ConstructionFlow DoConstruct(FCk_Handle& InHandle)
    {
        auto Root = utils_transform::Add(InHandle, SpawnTransform, ECk_Replication::DoesNotReplicate);
        utils_anchor::Add_CandidateSideFillers(this, Root, Anchor.SpanCm);

        auto GateParams = UMars_Gate_EntityScript::Params();
        GateParams.SpawnTransform = SpawnTransform;
        GateParams.Leaf = EMars_Gate_Leaf::Solid;
        GateParams.Gate.StartOpen = false;
        utils_entity_script::Request_SpawnEntity(InHandle, UMars_Gate_EntityScript, GateParams);

        return ECk_EntityScript_ConstructionFlow::Finished;
    }
}

// A passable street with a barred portcullis and a grip lever on each side; either lever opens it for good.
class UMars_Anchor_LeverGate_EntityScript : UCk_GenericEntityScript_UE
{
    default _ShowInPlaceActors = false;
    default _Replication = ECk_Replication::DoesNotReplicate;

    UPROPERTY(ExposeOnSpawn)
    FTransform SpawnTransform = FTransform::Identity;

    UPROPERTY(ExposeOnSpawn)
    FMars_Anchor_Context Anchor;

    private const float64 k_LeverSetback = 150.0;
    private const float64 k_LeverWallInset = 30.0;

    UFUNCTION(BlueprintOverride)
    ECk_EntityScript_ConstructionFlow DoConstruct(FCk_Handle& InHandle)
    {
        auto Root = utils_transform::Add(InHandle, SpawnTransform, ECk_Replication::DoesNotReplicate);
        utils_anchor::Add_CandidateSideFillers(this, Root, Anchor.SpanCm);

        auto GateParams = UMars_Gate_EntityScript::Params();
        GateParams.SpawnTransform = SpawnTransform;
        GateParams.Leaf = EMars_Gate_Leaf::Bars;
        GateParams.Sink.InputChannels.Add(Anchor.Channel);
        GateParams.Sink.Rule = EMars_MechanismSink_Rule::AllChannels;
        GateParams.Sink.Latch = true;
        utils_entity_script::Request_SpawnEntity(InHandle, UMars_Gate_EntityScript, GateParams);

        const auto SideY = float64(Anchor.SpanCm) * 0.5 - k_LeverWallInset;
        Spawn_Lever(InHandle, FVector(-k_LeverSetback, SideY, 0.0), 0.0);
        Spawn_Lever(InHandle, FVector(k_LeverSetback, -SideY, 0.0), 180.0);

        return ECk_EntityScript_ConstructionFlow::Finished;
    }

    // A grip lever beside the doorway, facing it along local X: Use grips the handle and the look input pulls it over
    // (the motion version, as UMars_Sandbox_PulledLever_EntityScript), never a press.
    private void Spawn_Lever(FCk_Handle& InHandle, FVector InLocalOffset, float64 InLocalYaw)
    {
        const auto Local = FTransform(FRotator(0.0, InLocalYaw, 0.0), InLocalOffset);
        auto LeverParams = UMars_Lever_EntityScript::Params();
        LeverParams.SpawnTransform = Local * SpawnTransform;
        LeverParams.Control.Interaction = ECk_Interaction_CompletionPolicy::ManuallyCompleted;
        LeverParams.PromptText = NSLOCTEXT("MarsInteraction", "PullLeverHoldPrompt", "Grip lever");
        LeverParams.Source.OutputChannel = Anchor.Channel;
        utils_entity_script::Request_SpawnEntity(InHandle, UMars_Lever_EntityScript, LeverParams);
    }
}

// The quarry: the Sandbox Crawler4 look and attack loadout, homed on the anchor instead of Room 5, aggressive from the
// start, with no aggression channel.
class UMars_Anchor_QuarryCrawler4_EntityScript : UMars_Crawler_EntityScript
{
    default _ShowInPlaceActors = false;

    UPROPERTY(ExposeOnSpawn)
    FMars_Anchor_Context Anchor;

    UFUNCTION(BlueprintOverride)
    ECk_EntityScript_ConstructionFlow DoConstruct(FCk_Handle& InHandle)
    {
        Spec.LegCount = 4;
        Spec.Layout = EMars_Crawler_Layout::Radial;
        Spec.MinLegsToWalk = 3;
        Color = FLinearColor(0.75f, 0.35f, 0.2f, 1.0f);
        Look = FMars_Crawler_Look();

        const auto Home = float64(Anchor.HomeRadiusCm);
        const auto Centre = SpawnTransform.GetLocation();
        Spec.RoamBounds = FBox(Centre - FVector(Home, Home * 0.8, 80.0), Centre + FVector(Home, Home * 0.8, 200.0));
        Spec.Combat.Enabled = true;
        Spec.Combat.StartAggressive = ECk_EnableDisable::Enable;
        Spec.Combat.Targeting.HomeRadius = Anchor.HomeRadiusCm;
        Spec.Combat.Targeting.AcquireRadius = Anchor.HomeRadiusCm + 100.0f;
        Spec.Combat.Targeting.LoseRadius = Anchor.HomeRadiusCm + 400.0f;
        Spec.Combat.Loadout = utils_crawler::Get_AttackReferenceLoadout(EMars_Crawler_AttackPreset::Crawler4, false);
        Spec.Combat.JabClip = TSoftObjectPtr<UCk_ProceduralAction_Data>();
        Spec.Combat.PincerClip = TSoftObjectPtr<UCk_ProceduralAction_Data>();
        return Super::DoConstruct(InHandle);
    }
}

// The navigation island for one 30 x 24 m hunt court; the greybox builder places one at every Hunt anchor.
class UMars_Anchor_CourtNavField_EntityScript : UCk_GroundNavVolume_EntityScript
{
    default _ShowInPlaceActors = true;
    default _Params = utils_surface_navigator::Make_NavFieldSpec(FBox(FVector(-1400.0, -1100.0, -100.0), FVector(1400.0, 1100.0, 600.0)));
}
