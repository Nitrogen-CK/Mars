// The crawler owns damage, cooldown and cancellation policy. This adapter plays one of the combat profile's authored
// clips as an action of the crawler with explicit receipt delivery (the resolver needs every accepted interval): the
// pincer clip, its ClawRight and ClawLeft slots bound to the front legs, when both can be claimed, else the body-only jab.
// It cancels the action; the player releases it once the resolver has acknowledged its terminal record, and a pincer that
// is gone asks the gait to take back any claw its return left unplanted.
namespace utils_crawler
{
    // A crawler lifting both claws keeps at least this many enabled legs on the ground.
    const int32 PincerMinStandingLegs = 2;

    // How long the gait may take to step a released claw back onto the ground before the leg is given up as unplanted.
    const float32 PincerReturnTimeoutSeconds = 3.0f;

    // The action is gone before its terminal record was read: something other than its own release destroyed it.
    bool Get_IsAttackActionLost(const FCk_Handle_Crawler& InSelf)
    {
        const auto& Attack = InSelf.Get_Fragment(FMars_Fragment_Crawler_Attack);
        FCk_Handle Action = Attack.Action;
        return Attack.ActionIdentity.Get_Value() != 0 && Attack.TerminalSeen == false &&
            (ck::Is_NOT_Valid(Action) ||
                utils_entity_lifetime::Get_IsPendingDestroy(Action, ECk_EntityLifetime_DestructionPhase::BeginDestroy));
    }

    // Asks the gait to take back every limb an earlier action's return left unplanted (the return ran out of time or of
    // landing probes). Sent when a pincer's action is gone and again before the next attack's action is created, when the
    // crawler stands still: a leg left out of the gait is never the last word.
    bool Recover_UnplantedLimbs(FCk_Handle_Crawler& InSelf)
    {
        auto Subject = InSelf.Get_Articulation();
        if (utils_procedural_articulation::Get_UnplantedLimbIds(Subject).Num() == 0)
        { return false; }

        utils_procedural_articulation::Request_RecoverUnplantedLimbs(Subject, FCk_Request_ProceduralArticulation_RecoverUnplantedLimbs());
        return true;
    }

    // The two front legs the pincer would claim, right (the rig's first leg) then left (its last); empty when the profile
    // has no pincer clip, when either front leg is gone, disabled or not the gait's to lend (still returning from, or left
    // unplanted by, an earlier action), or when lifting both would leave fewer than PincerMinStandingLegs enabled legs
    // standing. An empty answer is a body-only jab, never a rejected attack.
    TArray<FMars_Crawler_AttackClaw> Find_AttackClaws(const FCk_Handle_Crawler& InSelf)
    {
        const auto Entry = Find_ResolvedAttack(InSelf.Get_Spec().ResolvedAttacks, GameplayTags::Attack_Mars_Pincer);
        if (Entry.IsSet() == false)
        { return TArray<FMars_Crawler_AttackClaw>(); }
        if (utils_procedural_gait::Get_EnabledLegCount(InSelf.Get_Gait()) - Entry.GetValue().Slots.Num() < PincerMinStandingLegs)
        { return TArray<FMars_Crawler_AttackClaw>(); }
        auto Claws = TArray<FMars_Crawler_AttackClaw>();
        for (const auto& Slot : Entry.GetValue().Slots)
        {
            auto Role = Capture_AttackRole(InSelf, Slot.Binding);
            Role.Limb.Planted = true;
            Role.Limb.Trusted = true;
            auto Roles = TArray<FMars_Attack_RoleObservation>();
            Roles.Add(Role);
            auto Check = FMars_Attack_Evaluation();
            Check.Capable = true;
            utils_attack::Evaluate_Role(Check, Slot, Roles);
            if (Check.Blockers.Num() > 0)
            { return TArray<FMars_Crawler_AttackClaw>(); }
            auto Claw = FMars_Crawler_AttackClaw();
            Claw.Leg = Find_AttackPart(InSelf, Slot.Binding.LimbId).Get_Leg();
            Claw.LegId = Slot.Binding.LimbId;
            Claw.Side = Slot.Slot == n"ClawRight" ? 1.0f : -1.0f;
            Claws.Add(Claw);
        }
        return Claws;
    }

    // The enabled legs other than InClaws whose foot is planted on trusted ground: what would hold the crawler up with the
    // claws lifted, by the gait's own count (a swinging foot and a guessed plant hold nothing).
    int32 Count_StandingLegs(const FCk_Handle_Crawler& InSelf, const TArray<FMars_Crawler_AttackClaw>& InClaws)
    {
        int32 Standing = 0;
        for (const auto& Part : InSelf.Get_LegParts())
        {
            FCk_Handle LegEntity = Part;
            if (ck::Is_NOT_Valid(LegEntity))
            { continue; }

            const auto Leg = LegEntity.As_ProceduralLeg(ECk_SanityCheck::UnChecked);
            if (ck::Is_NOT_Valid(Leg) || utils_procedural_leg::Get_Status(Leg) != ECk_ProceduralLeg_Status::Enabled)
            { continue; }

            auto IsClaw = false;
            for (const auto& Claw : InClaws)
            { IsClaw = IsClaw || Claw.LegId == utils_procedural_leg::Get_Id(Leg); }

            const auto Foot = utils_procedural_leg::Get_Foot(Leg);
            if (IsClaw == false && Foot.Get_Phase() == ECk_ProceduralLeg_FootPhase::Planted && Foot.Get_Contact() == ECk_ProceduralLeg_FootContact::Trusted)
            { ++Standing; }
        }

        return Standing;
    }

    // A pincer may start: every claw's own foot is planted (the clip's windup lifts it from where it stands, so that is a
    // spot on the ground, not a point of a step in flight) and enough of the other legs stand to hold the crawler up
    // without them.
    bool Get_IsPincerStanceReady(const FCk_Handle_Crawler& InSelf, const TArray<FMars_Crawler_AttackClaw>& InClaws)
    {
        for (const auto& Claw : InClaws)
        {
            if (utils_procedural_leg::Get_Foot(Claw.Leg).Get_Phase() != ECk_ProceduralLeg_FootPhase::Planted)
            { return false; }
        }

        return Count_StandingLegs(InSelf, InClaws) >= PincerMinStandingLegs;
    }

    // The clip an attack admitted now would play: the pincer when Find_AttackClaws claims both front legs, else the jab.
    EMars_Crawler_AttackClipKind Get_NextClipKind(const FCk_Handle_Crawler& InSelf)
    {
        return Find_AttackClaws(InSelf).Num() > 0 ? EMars_Crawler_AttackClipKind::Pincer : EMars_Crawler_AttackClipKind::Jab;
    }

    // Recovers unplanted limbs, finds the claws and plays the pincer clip with its claw slots bound to their legs, or the
    // jab when no claw is claimed. False (nothing created) without a player, without that clip loaded (an ensure: Validate
    // admitted the spec with it) or when the action is not created.
    bool Create_AttackAction(FCk_Handle_Crawler& InSelf, const FMars_Attack_ResolvedPlan& InPlan)
    {
        const auto Player = InSelf.Get_ActionPlayer();
        if (ck::Is_NOT_Valid(Player) || ck::Is_NOT_Valid(InPlan.Entry.Definition.Clip.Get()))
        { return false; }
        // A claw an earlier return left out of the gait is taken back before this action claims anything.
        Recover_UnplantedLimbs(InSelf);
        auto Bindings = TArray<FCk_ProceduralAction_SlotBinding>();
        auto Claimed = TArray<FName>();
        for (const auto& Slot : InPlan.Entry.Slots)
        {
            Bindings.Add(FCk_ProceduralAction_SlotBinding(Slot.Slot, Slot.Binding.LimbId));
            Claimed.Add(Slot.Binding.LimbId);
        }
        auto PlaySpec = FCk_ProceduralAction_PlaySpec(InPlan.Entry.Definition.Clip);
        PlaySpec.Set_SlotBindings(Bindings);
        PlaySpec.Set_Delivery(ECk_ProceduralAction_Delivery::Explicit);
        FCk_Handle Owner = InSelf;
        const auto Action = utils_procedural_action::Create_FromClip(Owner, Player, PlaySpec);
        if (ck::Is_NOT_Valid(Action))
        { return false; }
        auto& Attack = InSelf.Get_Fragment(FMars_Fragment_Crawler_Attack);
        Attack.Plan = InPlan;
        Attack.Action = Action;
        Attack.ActionIdentity = Action.Get_Identity();
        Attack.Claws = InPlan.Entry.Identity.Id == GameplayTags::Attack_Mars_Pincer ? Find_AttackClaws(InSelf) : TArray<FMars_Crawler_AttackClaw>();
        if (InPlan.Entry.Identity.Id == GameplayTags::Attack_Mars_Pincer) { Attack.ClipKind = EMars_Crawler_AttackClipKind::Pincer; }
        else if (InPlan.Entry.Identity.Id == GameplayTags::Attack_Mars_Jab) { Attack.ClipKind = EMars_Crawler_AttackClipKind::Jab; }
        Attack.ReceiptCursor = 0;
        Attack.CancelRequested = false;
        Attack.TerminalSeen = false;
        Attack.Cleanup = FMars_Crawler_AttackCleanup();
        Attack.Cleanup.ClaimedIds = Claimed;
        return true;
    }

    // Deprecated target-only fixture adapter; action selection itself is shared with the kernel.
    bool Create_AttackAction(FCk_Handle_Crawler& InSelf)
    {
        const auto Advice = Evaluate_AttackLoadout(InSelf, InSelf.Get_CombatTarget());
        if (Advice.Selection.Selected.IsSet() == false)
        { return false; }
        const auto Entry = Find_ResolvedAttack(InSelf.Get_Spec().ResolvedAttacks, Advice.Selection.Selected.GetValue());
        if (Entry.IsSet() == false)
        { return false; }
        auto Plan = FMars_Attack_ResolvedPlan();
        Plan.Entry = Entry.GetValue();
        Plan.Execution = InSelf.Get_Spec().ResolvedAttacks.Execution;
        Plan.Target = InSelf.Get_CombatTarget();
        Plan.TargetGeneration = InSelf.Get_CombatTargetGeneration();
        Plan.SelectionGeneration = Advice.SelectionGeneration;
        Plan.GameRevision = InSelf.Get_Spec().ResolvedAttacks.GameRevision;
        return Create_AttackAction(InSelf, Plan);
    }

    // Once per attack; the action's own return owns neutralization from wherever the body and the claws are.
    void Cancel_AttackAction(FCk_Handle_Crawler& InSelf)
    {
        auto& Attack = InSelf.Get_Fragment(FMars_Fragment_Crawler_Attack);
        if (Attack.CancelRequested || Get_IsAttackActionLost(InSelf) || ck::Is_NOT_Valid(Attack.Action) ||
            Attack.Action.Get_State() == ECk_ProceduralAction_State::Finished)
        { return; }

        Attack.CancelRequested = true;
        Attack.Action.Request_Cancel(FCk_Request_ProceduralAction_Cancel());
    }

    // True once the attack's action is gone after its terminal record was read: the player released it when the resolver
    // acknowledged that record. Forgets the action and lets the gait take back the claws.
    bool Forget_ReleasedAttackAction(FCk_Handle_Crawler& InSelf)
    {
        auto& Attack = InSelf.Get_Fragment(FMars_Fragment_Crawler_Attack);
        FCk_Handle Action = Attack.Action;
        const auto Gone = ck::Is_NOT_Valid(Action) ||
            utils_entity_lifetime::Get_IsPendingDestroy(Action, ECk_EntityLifetime_DestructionPhase::BeginDestroy);
        if (Gone == false || (Attack.TerminalSeen == false &&
            InSelf.Get_Fragment(FMars_Fragment_Crawler_AttackObservations).StreamUnavailable == false))
        { return false; }

        if (Attack.TerminalSeen == false)
        {
            // The owned action really disappeared. No native terminal result was observed or invented.
            if (Attack.Result.Evidence.Failure.IsNone())
            { Attack.Result.Evidence.Failure = n"ActionLost"; }
        }

        Attack.Action = FCk_Handle_ProceduralAction();
        Attack.ActionIdentity = FCk_ProceduralAction_Identity();
        Attack.Cleanup.Released = true;
        // The gait takes back any claimed claw the return left unplanted, whatever admission reached (an unadmitted
        // action may still have acquired its claims); Settle then waits for it to plant.
        if (Attack.Cleanup.ClaimedIds.Num() > 0 && Recover_UnplantedLimbs(InSelf))
        { Attack.Cleanup.Requested = true; }
        Attack.Claws.Empty();
        return true;
    }
}
