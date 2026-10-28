// Editor-only acceptance aid. Explicit actor context avoids a global console command resolving the editor world.
// The camera director owns the view; queue its public rotation request rather than writing its controller output.
#if EDITOR
class UMars_ExpeditionAcceptance : UObject
{
    UFUNCTION()
    bool Aim(AMars_PlayerCharacter InCharacter, FRotator InWorldRotation)
    {
        if (ck::Is_NOT_Valid(InCharacter) || InCharacter.GetWorld().IsGameWorld() == false)
        { return false; }
        auto Player = InCharacter.TryGet_ActorEntityHandle();
        auto Viewpoint = Player.As_PlayerViewpoint(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(Viewpoint))
        { return false; }
        auto Camera = Viewpoint.Get_Camera();
        Camera.Request_SnapBoomRotation(InWorldRotation);
        return true;
    }

    UFUNCTION()
    bool Use(AMars_PlayerCharacter InCharacter, bool InPressed)
    { return Key(InCharacter, n"LeftMouseButton", InPressed); }

    // Same raw event path as the game's mapped buttons; no target, inventory or gate state is forced.
    UFUNCTION()
    bool Key(AMars_PlayerCharacter InCharacter, FName InKey, bool InPressed)
    {
        if (ck::Is_NOT_Valid(InCharacter) || InCharacter.GetWorld().IsGameWorld() == false)
        { return false; }
        auto Controller = Cast<APlayerController>(InCharacter.GetController());
        if (ck::Is_NOT_Valid(Controller))
        { return false; }
        auto SourceSubsystem = UCk_InputSource_Subsystem::Get(Controller);
        if (ck::Is_NOT_Valid(SourceSubsystem))
        { return false; }
        auto Source = SourceSubsystem.Get_InputSource();
        if (ck::Is_NOT_Valid(Source))
        { return false; }
        const auto EventType = InPressed ? ECk_InputSource_EventType::Pressed : ECk_InputSource_EventType::Released;
        const auto Device = InKey == n"LeftMouseButton" || InKey == n"RightMouseButton"
            ? ECk_InputSource_DeviceClass::Mouse : ECk_InputSource_DeviceClass::Keyboard;
        auto Event = FCk_InputSource_RawEvent(Device, FKey(InKey), EventType);
        Source.Request_InjectRawEvent(FCk_Request_InputSource_InjectRawEvent(Event));
        return true;
    }

    // Already-scaled degrees, through the gameplay input profile's look path (utils_input_intents::Request_Look).
    UFUNCTION()
    bool Look(AMars_PlayerCharacter InCharacter, FVector InDelta)
    {
        if (ck::Is_NOT_Valid(InCharacter) || InCharacter.GetWorld().IsGameWorld() == false)
        { return false; }
        auto Player = InCharacter.TryGet_ActorEntityHandle();
        auto Intents = Player.As_InputIntents(ECk_SanityCheck::UnChecked);
        auto Viewpoint = Player.As_PlayerViewpoint(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(Intents) || ck::Is_NOT_Valid(Viewpoint))
        { return false; }
        utils_input_intents::Request_Look(Player, InDelta);
        return true;
    }

    UFUNCTION()
    FString Inspect(AMars_PlayerCharacter InCharacter)
    {
        if (ck::Is_NOT_Valid(InCharacter) || InCharacter.GetWorld().IsGameWorld() == false)
        { return "no live character"; }
        auto Player = InCharacter.TryGet_ActorEntityHandle();
        auto Hotbar = Player.As_Hotbar(ECk_SanityCheck::UnChecked);
        auto Held = Player.As_HeldItem(ECk_SanityCheck::UnChecked);
        auto Operator = Player.As_Operator(ECk_SanityCheck::UnChecked);
        FString Result = f"player {InCharacter.GetActorLocation()}";
        auto Health = Player.As_Health(ECk_SanityCheck::UnChecked);
        if (ck::IsValid(Health))
        { Result += f" health={Health.Get_Current()}"; }
        if (ck::IsValid(Hotbar))
        {
            Result += f" pack={Hotbar.Get_IsWearingBackpack()} selected={Hotbar.Get_SelectedItem().ToString()}";
            for (int32 Index = 0; Index < Hotbar.Get_BagSlotCount(); ++Index)
            { Result += f" slot{Index + 1}={Hotbar.Get_ItemAt(Index).ToString()}"; }
        }
        if (ck::IsValid(Held))
        { Result += f" held={Held.Get_CurrentItem().ToString()}"; }
        if (ck::IsValid(Operator))
        {
            Result += f" operating={Operator.Get_IsOperating()}";
            auto Station = Operator.Get_Station();
            if (ck::IsValid(Station))
            {
                auto Board = Station.As_FoodBoard(ECk_SanityCheck::UnChecked);
                if (ck::IsValid(Board))
                { Result += f" board_pieces={Board.Get_HeldCount()}"; }
                auto Batter = Station.As_Batter(ECk_SanityCheck::UnChecked);
                if (ck::IsValid(Batter))
                {
                    Result += f" batter_pieces={Batter.Get_PieceCount()} coated={Batter.Get_CoatedCount()}";
                    for (auto Id : Batter.Get_PieceIds())
                    { Result += f" [coat={Batter.Get_PieceCoat(Id)} immersion={Batter.Get_PieceImmersion(Id)}]"; }
                }
                auto Fry = Station.As_Fry(ECk_SanityCheck::UnChecked);
                if (ck::IsValid(Fry))
                {
                    const auto Summary = Fry.Get_Summary();
                    Result += f" fry_oil={Summary.InOil} scoop={Summary.OnSkimmer} airborne={Summary.Airborne} basket={Summary.InBasket} drained={Summary.Drained} lost={Summary.Lost} pale={Summary.PaleFaces} overdone={Summary.OverdoneFaces}";
                    Result += f" skim={Fry.Get_Skim() :n} target={Fry.Get_SkimmerTarget()} in_pot={Fry.Get_IsScoopInPot()} clear_rim={Fry.Get_IsScoopClearOfRim()} over_basket={Fry.Get_IsScoopOverBasket()}";
                    for (auto Id : Fry.Get_PieceIds())
                    {
                        Result += f" [centre={Fry.Get_PieceCentre(Id)} where={Fry.Get_PieceWhereabouts(Id) :n} drain={Fry.Get_PieceDrainProgress(Id)} heat=";
                        for (auto Face : Fry.Get_PieceState(Id).FaceHeat)
                        { Result += f"{Face},"; }
                        Result += "]";
                    }
                }
                auto Pan = Station.As_Searing(ECk_SanityCheck::UnChecked);
                if (ck::IsValid(Pan))
                {
                    Result += f" pan_pieces={Pan.Get_PieceIds().Num()} ready={Pan.Get_TakeableCount()}";
                    for (auto Id : Pan.Get_PieceIds())
                    {
                        Result += f" [seared={Pan.Get_SearedFaceCount(Id)} down={Pan.Get_DownFace(Id) :n} faces=";
                        for (auto Face : Pan.Get_PieceState(Id).FaceSear)
                        { Result += f"{Face},"; }
                        Result += "]";
                        auto PieceEntity = Pan.Get_PieceEntity(Id);
                        if (ck::IsValid(PieceEntity))
                        {
                            Result += f" local={Pan.Get_PiecePanLocal(Id)} contact={Pan.Get_PieceContact(Id) :n}";
                            auto Resting = PieceEntity.As_Resting();
                            Result += f" rest={Resting.Get_State() :n} sleep={utils_jolt_body::Get_SleepState(Resting.Get_Body()) :n}";
                        }
                    }
                }
            }
        }
        for (auto Entity : utils_entity_tag::ForEach_Entity(Player, n"TAG_MarsCrawler"))
        {
            auto Crawler = Entity.As_Crawler();
            Result += f"\ncrawler {utils_transform::Get_EntityCurrentLocation(Entity.As_Transform())} armed={Crawler.Get_IsCombatArmed()} aggressive={Crawler.Get_IsAggressive()} target={ck::IsValid(Crawler.Get_CombatTarget())} phase={Crawler.Get_AttackPhase() :n} attacks={Crawler.Get_AttackGeneration()}";
            auto Navigator = Crawler.Get_Navigator();
            Result += f" dead={Crawler.Get_IsCombatDead()} hurts={Crawler.Get_HurtCount()} nav={Navigator.Get_Status() :n} nav_fail={Navigator.Get_FailReason() :n}";
            Result += f" hp={Crawler.Get_Monster().Get_BodyHealth().Get_Current()}";
        }
        for (auto Entity : utils_entity_tag::ForEach_Entity(Player, n"TAG_MarsForageVine"))
        {
            auto Forage = Entity.As_Forage();
            Result += f"\nforage {utils_transform::Get_EntityCurrentLocation(Entity.As_Transform())} released={Forage.Get_ReleasedCount()} exhausted={Forage.Get_IsExhausted()}";
        }
        return Result;
    }

    UFUNCTION()
    FString InspectCrawlerCombat(AMars_PlayerCharacter InCharacter)
    {
        if (ck::Is_NOT_Valid(InCharacter) || InCharacter.GetWorld().IsGameWorld() == false)
        { return "no live character"; }
        auto Player = InCharacter.TryGet_ActorEntityHandle();
        if (ck::Is_NOT_Valid(Player))
        { return "no live player entity"; }
        FString Result = f"frame={utils_time::Get_FrameCounter()}";
        for (auto Entity : utils_entity_tag::ForEach_Entity(Player, n"TAG_MarsCrawler"))
        {
            auto Crawler = Entity.As_Crawler(ECk_SanityCheck::UnChecked);
            auto Root = Entity.As_Transform(ECk_SanityCheck::UnChecked);
            if (ck::Is_NOT_Valid(Crawler) || ck::Is_NOT_Valid(Root))
            { continue; }
            const auto At = utils_transform::Get_EntityCurrentLocation(Root);
            const auto Target = Crawler.Get_CombatTarget();
            const auto Decision = Crawler.Get_AttackDecision();
            const auto Evaluation = Crawler.Get_AttackEvaluation();
            const auto Admission = Crawler.Get_AttackAdmission();
            const auto Preparation = Crawler.Get_AttackPreparation();
            Result += f"\ncrawler={Entity.ToString()} at={At} player_cm={At.Distance(InCharacter.GetActorLocation())} armed={Crawler.Get_IsCombatArmed()} aggressive={Crawler.Get_IsAggressive()} dead={Crawler.Get_IsCombatDead()} target={Target.ToString()} target_is_player={Target == Player} target_valid={Crawler.Get_IsCombatTargetValid(Target)} target_generation={Crawler.Get_CombatTargetGeneration()} warded={Crawler.Get_IsWarded(Target)} engage={Crawler.Get_EngageStage() :n} phase={Crawler.Get_AttackPhase() :n} attack_generation={Crawler.Get_AttackGeneration()} cooldown={Crawler.Get_AttackCooldownRemaining()}";
            if (ck::IsValid(Target))
            {
                auto TargetPose = Target.As_Transform(ECk_SanityCheck::UnChecked);
                if (ck::IsValid(TargetPose))
                {
                    const auto Delta = utils_transform::Get_EntityCurrentLocation(TargetPose) - At;
                    Result += f" target_xy_cm={Delta.Size2D()} target_dz_cm={Delta.Z} target_xyz_cm={Delta.Size()}";
                }
            }
            Result += f"\n decision_frame={Evaluation.ObservationFrame} selection_generation={Evaluation.SelectionGeneration} disposition={Evaluation.Selection.Disposition :n} reason={Decision.LastReason.ToString()} signature={Decision.Signature} selection_signature={Decision.SelectionSignature}";
            Result += f"\n admission_id={Admission.AttackId.ToString()} accepted={Admission.Accepted} attempt_generation={Admission.AttemptGeneration} selection_generation={Admission.SelectionGeneration} sample={Admission.SampleId} preparation={Preparation.State :n} preferred={Preparation.Preferred.ToString()} target_identity={Preparation.TargetIdentity} target_generation={Preparation.TargetGeneration} readiness_wait={Preparation.ElapsedReadinessWait}";
            for (const auto Entry : Evaluation.Evaluations)
            {
                Result += f"\n  attack={Entry.AttackId.ToString()} availability={Entry.Availability :n} capable={Entry.Capable} support_enabled={Entry.EnabledSupport} support_standing={Entry.StandingSupport}";
                for (const auto Blocker : Entry.Blockers)
                { Result += f"\n   blocker={Blocker.Code :n} kind={Blocker.Kind :n} field={Blocker.Field} role={Blocker.Role.ToString()} slot={Blocker.Slot.ToString()} expected={Blocker.Expected} actual={Blocker.Actual}"; }
            }
            auto Navigator = Crawler.Get_Navigator();
            if (ck::IsValid(Navigator))
            { Result += f"\n nav={Navigator.Get_Status() :n} nav_fail={Navigator.Get_FailReason() :n} pending_nav={Navigator.Get_HasPendingRequests()}"; }
        }
        return Result;
    }

    UFUNCTION()
    FString WorldItems(AMars_PlayerCharacter InCharacter)
    {
        if (ck::Is_NOT_Valid(InCharacter) || InCharacter.GetWorld().IsGameWorld() == false)
        { return ""; }
        auto Player = InCharacter.TryGet_ActorEntityHandle();
        FString Result;
        for (auto Entity : utils_entity_tag::ForEach_Entity(Player, n"TAG_MarsWorldItem"))
        {
            auto Item = Entity.As_WorldItem(ECk_SanityCheck::UnChecked);
            if (ck::Is_NOT_Valid(Item) || ck::Is_NOT_Valid(Item.Get_Definition()))
            { continue; }
            auto ItemTransform = utils_transform::Get_EntityCurrentTransform(Entity.As_Transform());
            Result += f"{Item.Get_Definition().GetName()}|{ItemTransform.TransformPosition(Item.Get_BoundsFit().Centre)}|mount={Item.Get_Mount() :n}\n";
            auto Piece = Entity.As_FoodPiece(ECk_SanityCheck::UnChecked);
            if (ck::IsValid(Piece))
            {
                const auto Cook = Piece.Get_CookState();
                Result += f"  food ready={Piece.Get_Status() :n} whole={Piece.Get_IsWhole()} mass={Piece.Get_MassKg()} sear=";
                for (auto Face : Cook.Sear)
                { Result += f"{Face},"; }
                Result += " batter=";
                for (auto Face : Cook.Batter)
                { Result += f"{Face},"; }
                Result += f" battered={Cook.Battered} crumb={Cook.Crumb}\n";
            }
            auto Platter = Entity.As_Platter(ECk_SanityCheck::UnChecked);
            if (ck::IsValid(Platter))
            {
                Result += f"  platter pieces={Platter.Get_Pieces().Num()}\n";
                for (auto Food : Platter.Get_Pieces())
                {
                    Result += f"    whole={Food.Get_IsWhole()} sear=";
                    for (auto Face : Food.Get_CookState().Sear)
                    { Result += f"{Face},"; }
                    Result += " batter=";
                    for (auto Face : Food.Get_CookState().Batter)
                    { Result += f"{Face},"; }
                    Result += f" battered={Food.Get_CookState().Battered}\n";
                }
            }
        }
        return Result;
    }
}
#endif
