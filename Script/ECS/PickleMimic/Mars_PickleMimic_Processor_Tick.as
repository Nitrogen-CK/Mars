// The pickle mimic's one clock, after the request drain, every frame:
// 0. hurt: the flinch runs down (a dead mimic has none), the crack stage rises with the body health lost, and the first
//    frame it is dead its jar spills (OnSpill, Vitals.SpilledPickles);
// 1. posture: Rise runs toward the stance (StandSeconds up, TuckSeconds down) and the walker body node sinks or rises
//    with it (moved only when its drop changes); reaching the stance broadcasts OnStance, and standing fully up ends a
//    startle;
// 2. the cooldown runs down, and the running bite advances (Windup -> Active -> Recover -> over) and steers the root: it
//    turns in place toward the target through the windup, lunges along the line it faced through the active phase and
//    stands through the recovery; with no bite it follows the latched Drive, but only once it stands. The mouth sweeps
//    the bite's blow through the frame while Active, each zone hurt at most once a bite. A flinch stops it where it
//    stands and holds a windup at its start (the drain restarted it); an active or recovering bite runs on;
// 3. the lid: the bite sets it (gape wide, slam shut, stay shut); otherwise it eases toward the latched Gape, except
//    through a flinch, which holds it where the blow left it.
// This processor writes no root transform: steering goes through SurfaceMotion.
class UMars_Processor_PickleMimic_Tick : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _RunAfter.Add(n"/Script/Angelscript.Mars_Processor_PickleMimic_HandleRequests");

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_PickleMimic);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle)
    {
        if (utils_entity_lifetime::Get_IsPendingDestroy(InHandle, ECk_EntityLifetime_DestructionPhase::BeginDestroy))
        { return; }

        auto Self = InHandle.As_PickleMimic();
        const auto DeltaSeconds = float32(InDeltaT.Get_Seconds());

        TickHurt(Self, DeltaSeconds);
        TickPosture(Self, DeltaSeconds);
        TickAction(Self, DeltaSeconds);
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Hurt
    //----------------------------------------------------------------------------------------------------------------------

    private void TickHurt(FCk_Handle_PickleMimic& InSelf, float32 InDeltaSeconds)
    {
        auto Hurt = InSelf.Get_Hurt();
        Hurt.FlinchLeft = Math::Max(Hurt.FlinchLeft - InDeltaSeconds, 0.0f);
        if (InSelf.Get_IsDead())
        {
            Hurt.FlinchLeft = 0.0f;
            Hurt.Startled = false;
        }

        const auto Health = InSelf.Get_Monster().Get_BodyHealth();
        const auto Max = Health.Get_Max();
        if (Max > 0.0f)
        { Hurt.CrackStage = Math::Max(Hurt.CrackStage, utils_pickle_mimic::Get_CrackStageFor(InSelf.Get_Spec().Vitals, Health.Get_Current() / Max)); }

        const auto Spill = InSelf.Get_IsDead() && Hurt.Spilled == false;
        Hurt.Spilled = Hurt.Spilled || Spill;
        InSelf.Get_Fragment(FMars_Fragment_PickleMimic_Hurt) = Hurt;
        if (Spill && InSelf.Has_Fragment(FMars_Fragment_PickleMimic_Signals))
        { InSelf.Get_Fragment(FMars_Fragment_PickleMimic_Signals).OnSpill.Broadcast(InSelf, InSelf.Get_Spec().Vitals.SpilledPickles); }
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Posture
    //----------------------------------------------------------------------------------------------------------------------

    private void TickPosture(FCk_Handle_PickleMimic& InSelf, float32 InDeltaSeconds)
    {
        const auto Spec = InSelf.Get_Spec();
        auto Posture = InSelf.Get_Fragment(FMars_Fragment_PickleMimic_Posture);
        const auto Standing = Posture.Stance == EMars_PickleMimic_Stance::Standing;
        const auto Target = Standing ? 1.0f : 0.0f;
        const auto Rate = 1.0f / (Standing ? Spec.Posture.StandSeconds : Spec.Posture.TuckSeconds);
        const auto Previous = Posture.Rise;
        Posture.Rise = Math::FInterpConstantTo(Posture.Rise, Target, InDeltaSeconds, Rate);
        const auto Reached = Previous != Target && Posture.Rise == Target;

        const auto Drop = float32(-utils_pickle_mimic::Get_BodyOffset(Posture.Rise).GetLocation().Z);
        if (Math::Abs(Drop - Posture.AppliedDrop) > 0.01f)
        {
            Posture.AppliedDrop = Drop;
            auto Body = Spec.Rig.Body;
            utils_scene_node::Request_UpdateOffset(Body, FCk_Request_SceneNode_UpdateRelativeTransform(utils_pickle_mimic::Get_BodyOffset(Posture.Rise)));
        }

        InSelf.Get_Fragment(FMars_Fragment_PickleMimic_Posture) = Posture;
        if (Reached && Posture.Stance == EMars_PickleMimic_Stance::Standing)
        { InSelf.Get_Fragment(FMars_Fragment_PickleMimic_Hurt).Startled = false; }

        if (Reached && InSelf.Has_Fragment(FMars_Fragment_PickleMimic_Signals))
        { InSelf.Get_Fragment(FMars_Fragment_PickleMimic_Signals).OnStance.Broadcast(InSelf, Posture.Stance); }
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Action
    //----------------------------------------------------------------------------------------------------------------------

    private void TickAction(FCk_Handle_PickleMimic& InSelf, float32 InDeltaSeconds)
    {
        const auto Spec = InSelf.Get_Spec();
        auto Action = InSelf.Get_Action();
        Action.BiteCooldown = Math::Max(Action.BiteCooldown - InDeltaSeconds, 0.0f);

        if (InSelf.Get_IsDead() && Action.Kind != EMars_PickleMimic_Action::None)
        {
            InSelf.Get_Fragment(FMars_Fragment_PickleMimic_Action) = Action;
            const auto Ended = utils_pickle_mimic::End_Action(InSelf);
            utils_pickle_mimic::Broadcast_ActionPhase(InSelf, Ended, EMars_PickleMimic_ActionPhase::None);
            Action = InSelf.Get_Action();
        }

        const auto Flinching = InSelf.Get_IsFlinching();
        if (Action.Kind == EMars_PickleMimic_Action::None)
        {
            InSelf.Get_Fragment(FMars_Fragment_PickleMimic_Action) = Action;
            const auto Drive = InSelf.Get_Fragment(FMars_Fragment_PickleMimic_Drive);
            const auto CanWalk = InSelf.Get_IsDead() == false && InSelf.Get_IsStanding() && Flinching == false;
            Steer(InSelf, Drive.Direction, CanWalk ? Drive.Speed : 0.0f);
            if (Flinching == false)
            { EaseLid(InSelf, InDeltaSeconds); }

            return;
        }

        // A flinch holds the windup at its start, the lid where the blow slammed it.
        if (Flinching && Action.Phase == EMars_PickleMimic_ActionPhase::Windup)
        {
            InSelf.Get_Fragment(FMars_Fragment_PickleMimic_Action) = Action;
            Steer(InSelf, Action.CommittedDirection, 0.0f);
            return;
        }

        const auto Up = InSelf.Get_SurfaceUp();

        // A windup keeps turning toward the target; what it faces when the windup ends is the committed line.
        if (Action.Phase == EMars_PickleMimic_ActionPhase::Windup && utils_pickle_mimic::Get_IsTargetValid(Action.Target))
        {
            const auto Toward = utils_pickle_mimic::Get_Tangent(utils_transform::Get_EntityCurrentLocation(Action.Target.As_Transform()) - InSelf.Get_Location(), Up);
            if (Toward.IsNearlyZero() == false)
            { Action.CommittedDirection = Toward; }
        }

        const auto PreviousFrame = utils_pickle_mimic::Make_Frame(Spec, Action);
        Action.PhaseElapsed += InDeltaSeconds;

        auto Changed = false;
        if (Action.PhaseElapsed >= utils_pickle_mimic::Get_PhaseSeconds(Spec.Bite.Timing, Action.Phase))
        {
            Advance(Action);
            Changed = true;
        }

        const auto Kind = Action.Kind;
        const auto Phase = Action.Phase;
        const auto Committed = Action.CommittedDirection;
        const auto WasActive = PreviousFrame.Phase == EMars_PickleMimic_ActionPhase::Active;
        const auto LastBlowCentre = Action.LastBlowCentre;
        const auto BlowCentre = InSelf.Get_MouthLocation();
        Action.LastBlowCentre = BlowCentre;
        const auto Lid = utils_pickle_mimic::Get_BiteLid(utils_pickle_mimic::Make_Frame(Spec, Action), Action.LidAtStart);

        InSelf.Get_Fragment(FMars_Fragment_PickleMimic_Action) = Action;
        if (Phase == EMars_PickleMimic_ActionPhase::None)
        { utils_pickle_mimic::End_Action(InSelf); }

        InSelf.Get_Fragment(FMars_Fragment_PickleMimic_Mouth).LidOpen = Lid;

        const auto Lunging = Phase == EMars_PickleMimic_ActionPhase::Active;
        Steer(InSelf, Committed, Lunging ? Spec.Bite.LungeSpeed : 0.0f);

        // The blow runs after the action is written: a damage request adds fragments to this entity.
        if (WasActive)
        { Sweep(InSelf, Kind, LastBlowCentre, BlowCentre); }

        if (Changed)
        { utils_pickle_mimic::Broadcast_ActionPhase(InSelf, Kind, Phase); }
    }

    private void Advance(FMars_Fragment_PickleMimic_Action& InOutAction)
    {
        InOutAction.PhaseElapsed = 0.0f;
        if (InOutAction.Phase == EMars_PickleMimic_ActionPhase::Windup)
        { InOutAction.Phase = EMars_PickleMimic_ActionPhase::Active; }
        else if (InOutAction.Phase == EMars_PickleMimic_ActionPhase::Active)
        { InOutAction.Phase = EMars_PickleMimic_ActionPhase::Recover; }
        else
        { InOutAction.Phase = EMars_PickleMimic_ActionPhase::None; }
    }

    private void EaseLid(FCk_Handle_PickleMimic& InSelf, float32 InDeltaSeconds)
    {
        auto& Mouth = InSelf.Get_Fragment(FMars_Fragment_PickleMimic_Mouth);
        Mouth.LidOpen = Math::FInterpConstantTo(Mouth.LidOpen, Mouth.Gape, InDeltaSeconds, utils_pickle_mimic::LidEaseRate);
    }

    private void Steer(FCk_Handle_PickleMimic& InSelf, FVector InDirection, float32 InSpeed)
    {
        auto Motion = InSelf.Get_Motion();
        if (utils_surface_motion::Get_Status(Motion) != ECk_ProceduralAnimation_Status::Ready)
        { return; }

        const auto Direction = InDirection.GetSafeNormal();
        utils_surface_motion::Request_Steering(Motion, FCk_Request_SurfaceMotion_Steering(Direction, Direction.IsNearlyZero() ? 0.0f : InSpeed));
    }

    // The bite through the frame: a swept sphere from InFrom to InTo that passes through every zone this bite already hurt;
    // a hit is recorded and announced.
    private void Sweep(FCk_Handle_PickleMimic& InSelf, EMars_PickleMimic_Action InKind, FVector InFrom, FVector InTo)
    {
        const auto Blow = InSelf.Get_Spec().Bite.Blow;
        auto Dealer = InSelf.Get_Fragment(FMars_Fragment_PickleMimic).Dealer;
        auto Sweep = FMars_DamageDealer_Sweep(InFrom, InTo, Blow.Radius);
        for (auto Zone : InSelf.Get_Action().HitZones)
        {
            if (ck::IsValid(Zone))
            { Sweep.IgnoredEntities.Append(Zone.Get_Hurtboxes()); }
        }

        const auto Result = Dealer.Request_StrikeSweep(Sweep, utils_damage_dealer::Make_Event(Dealer, Blow.Damage, Blow.DamageType));
        if (ck::Is_NOT_Valid(Result.Get_HitEntity()) || Result.Get_HitKind() != ECk_ProbeTrace_HitKind::Probe)
        { return; }

        auto Zone = utils_hit_zone::TryGet_Zone(Result.Get_HitEntity());
        if (ck::Is_NOT_Valid(Zone))
        { return; }

        InSelf.Get_Fragment(FMars_Fragment_PickleMimic_Action).HitZones.AddUnique(Zone);
        if (InSelf.Has_Fragment(FMars_Fragment_PickleMimic_Signals))
        { InSelf.Get_Fragment(FMars_Fragment_PickleMimic_Signals).OnBlowLanded.Broadcast(InSelf, InKind, Zone); }
    }
}
