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
    void Recover_UnplantedLimbs(FCk_Handle_Crawler& InSelf)
    {
        auto Subject = InSelf.Get_Articulation();
        if (utils_procedural_articulation::Get_UnplantedLimbIds(Subject).Num() > 0)
        { utils_procedural_articulation::Request_RecoverUnplantedLimbs(Subject, FCk_Request_ProceduralArticulation_RecoverUnplantedLimbs()); }
    }

    // The two front legs the pincer would claim, right (the rig's first leg) then left (its last); empty when the profile
    // has no pincer clip, when either front leg is gone, disabled or not the gait's to lend (still returning from, or left
    // unplanted by, an earlier action), or when lifting both would leave fewer than PincerMinStandingLegs enabled legs
    // standing. An empty answer is a body-only jab, never a rejected attack.
    TArray<FMars_Crawler_AttackClaw> Find_AttackClaws(const FCk_Handle_Crawler& InSelf)
    {
        const auto Subject = InSelf.Get_Articulation();

        const auto Spec = InSelf.Get_Spec();
        const auto Parts = InSelf.Get_LegParts();
        if (Spec.Combat.Get_HasPincer() == false || Parts.Num() != Spec.LegCount)
        { return TArray<FMars_Crawler_AttackClaw>(); }

        if (utils_procedural_gait::Get_EnabledLegCount(InSelf.Get_Gait()) - 2 < PincerMinStandingLegs)
        { return TArray<FMars_Crawler_AttackClaw>(); }

        auto Indices = TArray<int32>();
        Indices.Add(0);
        Indices.Add(Parts.Num() - 1);

        auto Claws = TArray<FMars_Crawler_AttackClaw>();
        for (const auto Index : Indices)
        {
            FCk_Handle LegEntity = Parts[Index];
            if (ck::Is_NOT_Valid(LegEntity))
            { return TArray<FMars_Crawler_AttackClaw>(); }

            const auto Leg = LegEntity.As_ProceduralLeg(ECk_SanityCheck::UnChecked);
            if (ck::Is_NOT_Valid(Leg) || utils_procedural_leg::Get_Status(Leg) != ECk_ProceduralLeg_Status::Enabled)
            { return TArray<FMars_Crawler_AttackClaw>(); }

            const auto LegId = utils_procedural_leg::Get_Id(Leg);
            if (Subject.Get_LimbControl(LegId).Get_State() != ECk_ProceduralLimbControl_State::Default)
            { return TArray<FMars_Crawler_AttackClaw>(); }

            auto Claw = FMars_Crawler_AttackClaw();
            Claw.Leg = Leg;
            Claw.LegId = LegId;
            Claw.Side = Index == 0 ? 1.0f : -1.0f;
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
    bool Create_AttackAction(FCk_Handle_Crawler& InSelf)
    {
        const auto Player = InSelf.Get_ActionPlayer();
        if (ck::Is_NOT_Valid(Player))
        { return false; }

        Recover_UnplantedLimbs(InSelf);

        const auto Spec = InSelf.Get_Spec();
        const auto Claws = Find_AttackClaws(InSelf);
        const auto Kind = Claws.Num() > 0 ? EMars_Crawler_AttackClipKind::Pincer : EMars_Crawler_AttackClipKind::Jab;
        auto Clip = Spec.Combat.Get_Clip(Kind);
        if (ck::EnsureIfNot(ck::IsValid(Clip), f"[Crawler] [{InSelf.ToString()}] its {Kind :n} clip is not loaded"))
        { return false; }

        auto Bindings = TArray<FCk_ProceduralAction_SlotBinding>();
        for (const auto& Claw : Claws)
        { Bindings.Add(FCk_ProceduralAction_SlotBinding(Get_ClawSlotId(Claw), Claw.LegId)); }

        auto PlaySpec = FCk_ProceduralAction_PlaySpec(TSoftObjectPtr<UCk_ProceduralAction_Data>(Clip));
        PlaySpec.Set_SlotBindings(Bindings);
        PlaySpec.Set_Delivery(ECk_ProceduralAction_Delivery::Explicit);

        FCk_Handle Owner = InSelf;
        const auto Action = utils_procedural_action::Create_FromClip(Owner, Player, PlaySpec);
        if (ck::Is_NOT_Valid(Action))
        { return false; }

        auto& Attack = InSelf.Get_Fragment(FMars_Fragment_Crawler_Attack);
        Attack.Action = Action;
        Attack.ActionIdentity = Action.Get_Identity();
        Attack.Claws = Claws;
        Attack.ClipKind = Kind;
        Attack.ReceiptCursor = 0;
        Attack.CancelRequested = false;
        Attack.TerminalSeen = false;
        return true;
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
        if (Attack.TerminalSeen == false || (ck::IsValid(Action) &&
            utils_entity_lifetime::Get_IsPendingDestroy(Action, ECk_EntityLifetime_DestructionPhase::BeginDestroy) == false))
        { return false; }

        Attack.Action = FCk_Handle_ProceduralAction();
        Attack.ActionIdentity = FCk_ProceduralAction_Identity();
        const auto HeldClaws = Attack.Claws.Num() > 0;
        Attack.Claws.Empty();
        if (HeldClaws)
        { Recover_UnplantedLimbs(InSelf); }
        return true;
    }
}
