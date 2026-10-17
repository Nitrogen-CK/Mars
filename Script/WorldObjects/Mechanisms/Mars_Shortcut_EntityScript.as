// A one-way shortcut: a barred gate and a single grip lever on one side of it. From the lever's side it opens for good;
// from the other side it is bars you see through. The street runs along local X and the gate spans local Y, as the anchor
// candidates (Mars_Anchor_Candidates.as), and the rest of the street beside the 2.4 m frame is closed by the same fillers.

enum EMars_Shortcut_LeverSide
{
    // Along local +X from the gate.
    Ahead,
    // Along local -X from the gate.
    Behind
}

class UMars_Shortcut_EntityScript : UCk_GenericEntityScript_UE
{
    default _ShowInPlaceActors = true;
    default _Replication = ECk_Replication::DoesNotReplicate;

    UPROPERTY(ExposeOnSpawn)
    FTransform SpawnTransform = FTransform::Identity;

    UPROPERTY(ExposeOnSpawn, meta = (Categories = "Shortcut.Mars"))
    FGameplayTag ShortcutId;

    // Unique per placement: the lever asserts it, the gate latches open on it.
    UPROPERTY(ExposeOnSpawn, meta = (Categories = "Mechanism.Channel"))
    FGameplayTag Channel;

    UPROPERTY(ExposeOnSpawn)
    float32 SpanCm = 250.0f;

    UPROPERTY(ExposeOnSpawn)
    EMars_Shortcut_LeverSide LeverSide = EMars_Shortcut_LeverSide::Behind;

    private const float64 k_LeverSetback = 150.0;
    private const float64 k_LeverWallInset = 30.0;

    UFUNCTION(BlueprintOverride)
    ECk_EntityScript_ConstructionFlow DoConstruct(FCk_Handle& InHandle)
    {
        if (ck::EnsureIfNot(Channel.IsValid(), f"[Shortcut] {ShortcutId.ToString()} has no channel: its lever would open nothing"))
        { return ECk_EntityScript_ConstructionFlow::Finished; }

        auto Root = utils_transform::Add(InHandle, SpawnTransform, ECk_Replication::DoesNotReplicate);
        utils_anchor::Add_CandidateSideFillers(this, Root, SpanCm);

        auto GateParams = UMars_Gate_EntityScript::Params();
        GateParams.SpawnTransform = SpawnTransform;
        GateParams.Leaf = EMars_Gate_Leaf::Bars;
        GateParams.Sink.InputChannels.Add(Channel);
        GateParams.Sink.Rule = EMars_MechanismSink_Rule::AllChannels;
        GateParams.Sink.Latch = true;
        utils_entity_script::Request_SpawnEntity(InHandle, UMars_Gate_EntityScript, GateParams);

        // The lever stands beside the doorway on its side and faces the gate (as the LeverGate candidate's pair).
        const auto SideY = float64(SpanCm) * 0.5 - k_LeverWallInset;
        const auto IsAhead = LeverSide == EMars_Shortcut_LeverSide::Ahead;
        const auto Local = IsAhead
            ? FTransform(FRotator(0.0, 180.0, 0.0), FVector(k_LeverSetback, -SideY, 0.0))
            : FTransform(FRotator(0.0, 0.0, 0.0), FVector(-k_LeverSetback, SideY, 0.0));

        auto LeverParams = UMars_Lever_EntityScript::Params();
        LeverParams.SpawnTransform = Local * SpawnTransform;
        LeverParams.Control.Interaction = ECk_Interaction_CompletionPolicy::ManuallyCompleted;
        LeverParams.PromptText = NSLOCTEXT("MarsInteraction", "PullLeverHoldPrompt", "Grip lever");
        LeverParams.Source.OutputChannel = Channel;
        utils_entity_script::Request_SpawnEntity(InHandle, UMars_Lever_EntityScript, LeverParams);

        return ECk_EntityScript_ConstructionFlow::Finished;
    }
}
