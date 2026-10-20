namespace utils_attack
{
    const int32 MaxEntries = 32;
    const int32 MaxRoles = 64;
    const int32 MaxEmitters = 8;
    const int32 MaxDiagnostics = 8192;

    bool Get_IsPositive(float64 InValue)
    { return Math::IsFinite(InValue) && InValue > 0.0; }

    bool Get_IsNonnegative(float64 InValue)
    { return Math::IsFinite(InValue) && InValue >= 0.0; }

    bool Get_IsFinite(const FVector& InValue)
    { return Math::IsFinite(InValue.X) && Math::IsFinite(InValue.Y) && Math::IsFinite(InValue.Z); }

    FMars_Attack_Diagnostic Make_Diagnostic(FName InCode, FString InField, const FMars_Attack_Comparison& InValues)
    {
        auto Diagnostic = FMars_Attack_Diagnostic();
        Diagnostic.Code = InCode;
        Diagnostic.Field = InField;
        Diagnostic.Expected = InValues.Expected;
        Diagnostic.Actual = InValues.Actual;
        return Diagnostic;
    }

    void Add_Check(FMars_Attack_ValidationReport& InOutReport, bool InPassed, const FMars_Attack_Diagnostic& InDiagnostic)
    {
        if (InPassed)
        { return; }

        if (InOutReport.Diagnostics.Num() < MaxDiagnostics)
        { InOutReport.Diagnostics.Add(InDiagnostic); }
        else
        { InOutReport.Truncated = true; }
    }

    void Append_Report(FMars_Attack_ValidationReport& InOutReport, const FMars_Attack_ValidationReport& InReport, FString InPrefix)
    {
        for (const auto& SourceDiagnostic : InReport.Diagnostics)
        {
            FMars_Attack_Diagnostic Diagnostic = SourceDiagnostic;
            Diagnostic.Field = f"{InPrefix}{Diagnostic.Field}";
            Add_Check(InOutReport, false, Diagnostic);
        }

        InOutReport.Truncated = InOutReport.Truncated || InReport.Truncated;
    }

    void Check_Positive(FMars_Attack_ValidationReport& InOutReport, float64 InValue, FString InField)
    {
        Add_Check(InOutReport, Get_IsPositive(InValue), Make_Diagnostic(n"PositiveFinite", InField,
            FMars_Attack_Comparison("finite > 0", f"{InValue}")));
    }

    void Check_Nonnegative(FMars_Attack_ValidationReport& InOutReport, float64 InValue, FString InField)
    {
        Add_Check(InOutReport, Get_IsNonnegative(InValue), Make_Diagnostic(n"NonnegativeFinite", InField,
            FMars_Attack_Comparison("finite >= 0", f"{InValue}")));
    }

    void Check_Condition(FMars_Attack_ValidationReport& InOutReport, EMars_BodyPart_Condition InCondition, FString InField)
    {
        Add_Check(InOutReport, int32(InCondition) >= 0 && int32(InCondition) <= int32(EMars_BodyPart_Condition::Ruined),
            Make_Diagnostic(n"ConditionEnum", InField, FMars_Attack_Comparison("Pristine, Damaged or Ruined", f"{int32(InCondition)}")));
    }

    FMars_Attack_ValidationReport Validate_SelectionPolicy(const FMars_Attack_SelectionPolicy& InPolicy)
    {
        auto Report = FMars_Attack_ValidationReport();
        Add_Check(Report, InPolicy.TemporaryReadiness == EMars_Attack_TemporaryReadinessPolicy::WaitPreferred ||
            InPolicy.TemporaryReadiness == EMars_Attack_TemporaryReadinessPolicy::UseReadyAlternative,
            Make_Diagnostic(n"ReadinessPolicyEnum", "Selection.TemporaryReadiness", FMars_Attack_Comparison("supported policy", f"{int32(InPolicy.TemporaryReadiness)}")));
        Add_Check(Report, InPolicy.ControlWait == EMars_Attack_ControlWaitPolicy::PreferAvailable ||
            InPolicy.ControlWait == EMars_Attack_ControlWaitPolicy::WaitForPreferred,
            Make_Diagnostic(n"ControlWaitPolicyEnum", "Selection.ControlWait", FMars_Attack_Comparison("supported policy", f"{int32(InPolicy.ControlWait)}")));
        Check_Nonnegative(Report, InPolicy.ReadyAlternativeDelaySeconds, "Selection.ReadyAlternativeDelaySeconds");
        return Report;
    }

    FMars_Attack_ValidationReport Validate_ExecutionPolicy(const FMars_Attack_ExecutionPolicy& InPolicy)
    {
        auto Report = FMars_Attack_ValidationReport();
        Check_Positive(Report, InPolicy.MaxRootDrift, "Execution.MaxRootDrift");
        Add_Check(Report, Get_IsPositive(InPolicy.MaxGroundSlopeDegrees) && InPolicy.MaxGroundSlopeDegrees <= 90.0f,
            Make_Diagnostic(n"SlopeBounds", "Execution.MaxGroundSlopeDegrees", FMars_Attack_Comparison("(0, 90] degrees", f"{InPolicy.MaxGroundSlopeDegrees}")));
        const auto Tuning = InPolicy.Tuning;
        const auto Transition = Tuning.Get_Transition();
        const auto Watchdogs = Tuning.Get_Watchdogs();
        const auto Sampling = Tuning.Get_Sampling();
        Check_Positive(Report, Tuning.Get_Playback().Get_PlayRate(), "Execution.Tuning.Playback.PlayRate");
        Check_Nonnegative(Report, Transition.Get_EntryBlend().Get_Seconds(), "Execution.Tuning.Transition.EntryBlend");
        Check_Positive(Report, Transition.Get_DedicatedReturn().Get_Seconds(), "Execution.Tuning.Transition.DedicatedReturn");
        Check_Positive(Report, Transition.Get_ReturnTimeout().Get_Seconds(), "Execution.Tuning.Transition.ReturnTimeout");
        Add_Check(Report, Transition.Get_ReturnTimeout() >= Transition.Get_DedicatedReturn(),
            Make_Diagnostic(n"ReturnTimeoutCoverage", "Execution.Tuning.Transition.ReturnTimeout", FMars_Attack_Comparison("at least DedicatedReturn", f"{Transition.Get_ReturnTimeout().Get_Seconds()}")));
        Check_Positive(Report, Watchdogs.Get_LoadTimeout().Get_Seconds(), "Execution.Tuning.Watchdogs.LoadTimeout");
        Check_Positive(Report, Watchdogs.Get_AcquisitionTimeout().Get_Seconds(), "Execution.Tuning.Watchdogs.AcquisitionTimeout");
        Check_Positive(Report, Watchdogs.Get_PublicationTimeout().Get_Seconds(), "Execution.Tuning.Watchdogs.PublicationTimeout");
        Check_Positive(Report, Sampling.Get_MaxAdvance().Get_Seconds(), "Execution.Tuning.Sampling.MaxAdvance");
        Check_Positive(Report, Sampling.Get_MaxEndpointTravelCm(), "Execution.Tuning.Sampling.MaxEndpointTravelCm");
        Check_Positive(Report, Sampling.Get_MaxSegmentAngularStepDegrees(), "Execution.Tuning.Sampling.MaxSegmentAngularStepDegrees");
        Add_Check(Report, Sampling.Get_MaxSamples() >= 1 && Sampling.Get_MaxSamples() <= 64,
            Make_Diagnostic(n"SamplingStepsBounds", "Execution.Tuning.Sampling.MaxSamples", FMars_Attack_Comparison("[1, 64]", f"{Sampling.Get_MaxSamples()}")));
        const auto Support = InPolicy.Locomotion.Get_Support();
        const auto Mode = Support.Get_Mode();
        Add_Check(Report, Mode == ECk_ProceduralLimbControl_SupportMode::Disabled || Mode == ECk_ProceduralLimbControl_SupportMode::CountOnly ||
            Mode == ECk_ProceduralLimbControl_SupportMode::ProjectedSupportRegion,
            Make_Diagnostic(n"SupportModeEnum", "Execution.Locomotion.Support.Mode", FMars_Attack_Comparison("supported mode", f"{int32(Mode)}")));
        Add_Check(Report, Support.Get_MinimumTrustedContacts() >= 0 && Support.Get_MinimumTrustedContacts() <= 64 &&
            (Mode == ECk_ProceduralLimbControl_SupportMode::Disabled || Support.Get_MinimumTrustedContacts() > 0),
            Make_Diagnostic(n"SupportCountBounds", "Execution.Locomotion.Support.MinimumTrustedContacts", FMars_Attack_Comparison("[1,64] when enabled, [0,64] when disabled", f"{Support.Get_MinimumTrustedContacts()}")));
        Check_Nonnegative(Report, Support.Get_ProjectedRegionInsetCm(), "Execution.Locomotion.Support.ProjectedRegionInsetCm");
        Add_Check(Report, Get_IsNonnegative(Support.Get_MaxContactNormalSpreadDegrees()) && Support.Get_MaxContactNormalSpreadDegrees() < 90.0f,
            Make_Diagnostic(n"NormalSpreadBounds", "Execution.Locomotion.Support.MaxContactNormalSpreadDegrees", FMars_Attack_Comparison("[0,90) degrees", f"{Support.Get_MaxContactNormalSpreadDegrees()}")));
        Check_Positive(Report, Support.Get_SupportHoldTimeout().Get_Seconds(), "Execution.Locomotion.Support.SupportHoldTimeout");
        const auto Return = InPolicy.Locomotion.Get_Return();
        Check_Positive(Report, Return.Get_Duration().Get_Seconds(), "Execution.Locomotion.Return.Duration");
        Check_Positive(Report, Return.Get_Timeout().Get_Seconds(), "Execution.Locomotion.Return.Timeout");
        Add_Check(Report, Return.Get_Timeout() >= Return.Get_Duration(),
            Make_Diagnostic(n"ReturnTimeoutCoverage", "Execution.Locomotion.Return.Timeout", FMars_Attack_Comparison("at least Duration", f"{Return.Get_Timeout().Get_Seconds()}")));
        Add_Check(Report, Return.Get_MaxProbeAttempts() >= 1 && Return.Get_MaxProbeAttempts() <= 16,
            Make_Diagnostic(n"ReturnProbeBounds", "Execution.Locomotion.Return.MaxProbeAttempts", FMars_Attack_Comparison("[1,16]", f"{Return.Get_MaxProbeAttempts()}")));
        Check_Nonnegative(Report, Return.Get_RetryInterval().Get_Seconds(), "Execution.Locomotion.Return.RetryInterval");
        Check_Nonnegative(Report, Return.Get_ContactToleranceCm(), "Execution.Locomotion.Return.ContactToleranceCm");
        return Report;
    }

    bool Get_HasWindow(UCk_ProceduralAction_Data InClip, FName InId)
    {
        for (const auto& Window : InClip.Get_Windows())
        {
            if (Window.Get_Id() == InId)
            { return true; }
        }

        return false;
    }

    FName Get_EmitterObstructionWindow(const FMars_Attack_Emitter& InEmitter, const FMars_Attack_MotionContract& InMotion)
    {
        return InEmitter.ObstructionWindow.IsNone() ? InMotion.ObstructionWindow : InEmitter.ObstructionWindow;
    }

    TOptional<float64> Get_WindowEdgeCoordinate(UCk_ProceduralAction_Data InClip, const FCk_ProceduralAction_TimeRef& InEdge)
    {
        const auto Phases = InClip.Get_Phases();
        for (int32 Index = 0; Index < Phases.Num(); ++Index)
        {
            if (Phases[Index].Get_Id() == InEdge.Get_PhaseId())
            { return TOptional<float64>(float64(Index) + InEdge.Get_Time().Get_Value()); }
        }

        return TOptional<float64>();
    }

    bool Get_IsWindowContained(UCk_ProceduralAction_Data InClip, FName InInner, FName InOuter)
    {
        auto InnerStart = TOptional<float64>();
        auto InnerEnd = TOptional<float64>();
        auto OuterStart = TOptional<float64>();
        auto OuterEnd = TOptional<float64>();
        for (const auto& Window : InClip.Get_Windows())
        {
            if (Window.Get_Id() == InInner)
            {
                InnerStart = Get_WindowEdgeCoordinate(InClip, Window.Get_Start());
                InnerEnd = Get_WindowEdgeCoordinate(InClip, Window.Get_End());
            }

            if (Window.Get_Id() == InOuter)
            {
                OuterStart = Get_WindowEdgeCoordinate(InClip, Window.Get_Start());
                OuterEnd = Get_WindowEdgeCoordinate(InClip, Window.Get_End());
            }
        }

        return InnerStart.IsSet() && InnerEnd.IsSet() && OuterStart.IsSet() && OuterEnd.IsSet() &&
            InnerStart.GetValue() >= OuterStart.GetValue() && InnerEnd.GetValue() <= OuterEnd.GetValue();
    }

    FMars_Attack_ValidationReport Validate_Definition(const FMars_Attack_Definition& InDefinition)
    {
        auto Report = FMars_Attack_ValidationReport();
        const auto Prepare = InDefinition.Prepare;
        Check_Nonnegative(Report, Prepare.MinDistance, "Prepare.MinDistance");
        if (Prepare.UseCreatureFrontRange)
        { Check_Nonnegative(Report, Prepare.CreatureFrontRangeMargin, "Prepare.CreatureFrontRangeMargin"); }
        else
        {
            Check_Positive(Report, Prepare.MaxDistance, "Prepare.MaxDistance");
            Add_Check(Report, Prepare.MinDistance <= Prepare.MaxDistance,
                Make_Diagnostic(n"RangeBounds", "Prepare", FMars_Attack_Comparison("MinDistance <= MaxDistance", f"{Prepare.MinDistance}, {Prepare.MaxDistance}")));
        }

        Add_Check(Report, Get_IsPositive(Prepare.FacingToleranceDegrees) && Prepare.FacingToleranceDegrees <= 180.0f,
            Make_Diagnostic(n"FacingBounds", "Prepare.FacingToleranceDegrees", FMars_Attack_Comparison("(0,180] degrees", f"{Prepare.FacingToleranceDegrees}")));
        Check_Nonnegative(Report, Prepare.MaxHeightDifference, "Prepare.MaxHeightDifference");
        Check_Nonnegative(Report, Prepare.MaxSpeedToStart, "Prepare.MaxSpeedToStart");
        Check_Positive(Report, Prepare.TimeoutSeconds, "Prepare.TimeoutSeconds");
        Check_Nonnegative(Report, InDefinition.Hit.Damage, "Hit.Damage");
        Add_Check(Report, InDefinition.Hit.DamageType.IsValid(),
            Make_Diagnostic(n"DamageTypeMissing", "Hit.DamageType", FMars_Attack_Comparison("valid gameplay tag", InDefinition.Hit.DamageType.ToString())));
        Check_Positive(Report, InDefinition.Cooldown.RecoverySeconds, "Cooldown.RecoverySeconds");
        Check_Nonnegative(Report, InDefinition.Cooldown.ReuseSeconds, "Cooldown.ReuseSeconds");
        Add_Check(Report, InDefinition.Requirements.Slots.Num() <= MaxRoles && InDefinition.Requirements.Parts.Num() <= MaxRoles,
            Make_Diagnostic(n"RequirementsBounds", "Requirements", FMars_Attack_Comparison("at most 64 slots and 64 parts", f"{InDefinition.Requirements.Slots.Num()}, {InDefinition.Requirements.Parts.Num()}")));
        auto Roles = TArray<FGameplayTag>();
        auto Slots = TArray<FName>();
        for (int32 Index = 0; Index < Math::Min(InDefinition.Requirements.Slots.Num(), MaxRoles); ++Index)
        {
            const auto Slot = InDefinition.Requirements.Slots[Index];
            const FString Field = f"Requirements.Slots[{Index}]";
            Add_Check(Report, Slot.Slot.IsNone() == false, Make_Diagnostic(n"SlotMissing", f"{Field}.Slot", FMars_Attack_Comparison("named slot", "None")));
            Add_Check(Report, Slot.Role.IsValid(), Make_Diagnostic(n"RoleMissing", f"{Field}.Role", FMars_Attack_Comparison("named role", "None")));
            Add_Check(Report, Slots.Contains(Slot.Slot) == false, Make_Diagnostic(n"DuplicateSlot", f"{Field}.Slot", FMars_Attack_Comparison("unique ignoring case", Slot.Slot.ToString())));
            Add_Check(Report, Roles.Contains(Slot.Role) == false, Make_Diagnostic(n"DuplicateRole", f"{Field}.Role", FMars_Attack_Comparison("unique claimed role", Slot.Role.ToString())));
            Check_Condition(Report, Slot.MaxCondition, f"{Field}.MaxCondition");
            Slots.Add(Slot.Slot);
            Roles.Add(Slot.Role);
        }

        auto Parts = TArray<FGameplayTag>();
        for (int32 Index = 0; Index < Math::Min(InDefinition.Requirements.Parts.Num(), MaxRoles); ++Index)
        {
            const auto Part = InDefinition.Requirements.Parts[Index];
            const FString Field = f"Requirements.Parts[{Index}]";
            Add_Check(Report, Part.Role.IsValid(), Make_Diagnostic(n"RoleMissing", f"{Field}.Role", FMars_Attack_Comparison("named role", "None")));
            Add_Check(Report, Parts.Contains(Part.Role) == false, Make_Diagnostic(n"DuplicateRole", f"{Field}.Role", FMars_Attack_Comparison("unique prerequisite role", Part.Role.ToString())));
            Check_Condition(Report, Part.MaxCondition, f"{Field}.MaxCondition");
            Parts.Add(Part.Role);
        }

        Add_Check(Report, InDefinition.Hit.Emitters.Num() > 0 && InDefinition.Hit.Emitters.Num() <= MaxEmitters,
            Make_Diagnostic(n"EmitterBounds", "Hit.Emitters", FMars_Attack_Comparison("[1,8] emitters", f"{InDefinition.Hit.Emitters.Num()}")));
        auto EmitterIds = TArray<FGameplayTag>();
        auto HasBodyEmitter = false;
        for (int32 Index = 0; Index < Math::Min(InDefinition.Hit.Emitters.Num(), MaxEmitters); ++Index)
        {
            const auto Emitter = InDefinition.Hit.Emitters[Index];
            const FString Field = f"Hit.Emitters[{Index}]";
            Add_Check(Report, Emitter.Id.IsValid(), Make_Diagnostic(n"EmitterIdMissing", f"{Field}.Id", FMars_Attack_Comparison("named emitter", "None")));
            Add_Check(Report, EmitterIds.Contains(Emitter.Id) == false, Make_Diagnostic(n"DuplicateEmitter", f"{Field}.Id", FMars_Attack_Comparison("unique emitter tag", Emitter.Id.ToString())));
            EmitterIds.Add(Emitter.Id);
            Add_Check(Report, Emitter.Source == EMars_Attack_EmitterSource::Body || Emitter.Source == EMars_Attack_EmitterSource::LimbEndpoint,
                Make_Diagnostic(n"EmitterSourceEnum", f"{Field}.Source", FMars_Attack_Comparison("Body or LimbEndpoint", f"{int32(Emitter.Source)}")));
            Add_Check(Report, Get_IsFinite(Emitter.LocalCenter), Make_Diagnostic(n"EmitterCenterFinite", f"{Field}.LocalCenter", FMars_Attack_Comparison("finite vector", Emitter.LocalCenter.ToString())));
            Check_Positive(Report, Emitter.Radius, f"{Field}.Radius");
            Check_Positive(Report, Emitter.MaxSampleTravel, f"{Field}.MaxSampleTravel");
            Add_Check(Report, Emitter.DamageWindow.IsNone() == false,
                Make_Diagnostic(n"DamageWindowMissing", f"{Field}.DamageWindow", FMars_Attack_Comparison("named damage window", "None")));
            if (Emitter.Source == EMars_Attack_EmitterSource::Body)
            {
                HasBodyEmitter = true;
                Add_Check(Report, Emitter.Slot.IsNone(), Make_Diagnostic(n"BodyEmitterSlot", f"{Field}.Slot", FMars_Attack_Comparison("None", Emitter.Slot.ToString())));
            }
            else if (Emitter.Source == EMars_Attack_EmitterSource::LimbEndpoint)
            {
                Add_Check(Report, Emitter.UseCreatureFrontCenter == false, Make_Diagnostic(n"EndpointCreatureCenter", f"{Field}.UseCreatureFrontCenter", FMars_Attack_Comparison("false for limb endpoints", "true")));
                Add_Check(Report, Slots.Contains(Emitter.Slot), Make_Diagnostic(n"EmitterSlotUnclaimed", f"{Field}.Slot", FMars_Attack_Comparison("declared claimed slot", Emitter.Slot.ToString())));
                Add_Check(Report, Emitter.LocalCenter.IsNearlyZero(0.0), Make_Diagnostic(n"EndpointEmitterOffset", f"{Field}.LocalCenter", FMars_Attack_Comparison("zero offset", Emitter.LocalCenter.ToString())));
            }
        }

        const auto Motion = InDefinition.Motion;
        Add_Check(Report, Motion.WindupPhase.IsNone() == false && Motion.StrikePhase.IsNone() == false && Motion.RecoverPhase.IsNone() == false &&
            Motion.WindupPhase != Motion.StrikePhase && Motion.WindupPhase != Motion.RecoverPhase && Motion.StrikePhase != Motion.RecoverPhase,
            Make_Diagnostic(n"MotionPhaseIds", "Motion", FMars_Attack_Comparison("three distinct named phases", "missing or duplicate phase")));
        Add_Check(Report, Motion.ObstructionWindow.IsNone() == false,
            Make_Diagnostic(n"ObstructionWindowMissing", "Motion.ObstructionWindow", FMars_Attack_Comparison("named window", "None")));
        Add_Check(Report, InDefinition.Clip.IsNull() == false,
            Make_Diagnostic(n"ClipMissing", "Clip", FMars_Attack_Comparison("configured loaded clip", "null soft path")));
        auto Clip = InDefinition.Clip.Get();
        if (ck::Is_NOT_Valid(Clip))
        {
            Add_Check(Report, false, Make_Diagnostic(n"ClipUnloaded", "Clip", FMars_Attack_Comparison("loaded before validation", InDefinition.Clip.ToString())));
            return Report;
        }

        const auto Compilation = utils_procedural_action::Validate_Data(Clip);
        for (const auto& Diagnostic : Compilation.Get_Diagnostics())
        {
            if (Diagnostic.Get_Severity() == ECk_ProceduralAction_DiagnosticSeverity::Error)
            {
                Add_Check(Report, false, Make_Diagnostic(Diagnostic.Get_Code(), f"Clip.{Diagnostic.Get_FieldPath()}",
                    FMars_Attack_Comparison(Diagnostic.Get_Expected(), Diagnostic.Get_Actual())));
            }
        }

        Add_Check(Report, Compilation.Get_Status() == ECk_ProceduralAction_ReportStatus::Valid,
            Make_Diagnostic(n"ClipInvalid", "Clip", FMars_Attack_Comparison("public compiler Valid", f"{Compilation.Get_Status() :n}")));
        const auto Phases = Clip.Get_Phases();
        const auto PhaseOrder = Phases.Num() == 3 && Phases[0].Get_Id() == Motion.WindupPhase &&
            Phases[1].Get_Id() == Motion.StrikePhase && Phases[2].Get_Id() == Motion.RecoverPhase;
        Add_Check(Report, PhaseOrder, Make_Diagnostic(n"ClipPhaseOrder", "Clip.Phases", FMars_Attack_Comparison("Windup, Strike, Recover contract order", f"{Phases.Num()} phases")));
        Add_Check(Report, Clip.Get_Slots().Num() == Slots.Num(), Make_Diagnostic(n"ClipSlotCoverage", "Requirements.Slots", FMars_Attack_Comparison("exact clip slot coverage", f"{Slots.Num()} bindings for {Clip.Get_Slots().Num()} slots")));
        for (const auto& Slot : Clip.Get_Slots())
        {
            Add_Check(Report, Slots.Contains(Slot.Get_Id()), Make_Diagnostic(n"ClipSlotUnbound", "Requirements.Slots", FMars_Attack_Comparison("clip slot declared", Slot.Get_Id().ToString())));
        }

        Add_Check(Report, Get_HasWindow(Clip, Motion.ObstructionWindow), Make_Diagnostic(n"ObstructionWindowMissing", "Clip.Windows", FMars_Attack_Comparison("obstruction window exists", Motion.ObstructionWindow.ToString())));
        for (const auto& Window : Clip.Get_Windows())
        {
            if (Window.Get_Id() == Motion.ObstructionWindow)
            {
                Add_Check(Report, Window.Get_Start().Get_PhaseId() == Motion.WindupPhase && Window.Get_Start().Get_Time().Get_Value() == 0.0 &&
                    Window.Get_End().Get_PhaseId() == Motion.RecoverPhase && Window.Get_End().Get_Time().Get_Value() == 1.0,
                    Make_Diagnostic(n"ObstructionWindowCoverage", "Clip.Windows", FMars_Attack_Comparison("covers Windup start through Recover end", Window.Get_Id().ToString())));
            }
        }

        for (int32 Index = 0; Index < Math::Min(InDefinition.Hit.Emitters.Num(), MaxEmitters); ++Index)
        {
            const auto Emitter = InDefinition.Hit.Emitters[Index];
            Add_Check(Report, Get_HasWindow(Clip, Emitter.DamageWindow), Make_Diagnostic(n"DamageWindowMissing", f"Hit.Emitters[{Index}].DamageWindow", FMars_Attack_Comparison("clip window exists", Emitter.DamageWindow.ToString())));
            const auto SweepWindow = Get_EmitterObstructionWindow(Emitter, Motion);
            Add_Check(Report, Get_HasWindow(Clip, SweepWindow), Make_Diagnostic(n"EmitterObstructionWindowMissing", f"Hit.Emitters[{Index}].ObstructionWindow", FMars_Attack_Comparison("clip window exists", SweepWindow.ToString())));
            Add_Check(Report, Get_IsWindowContained(Clip, Emitter.DamageWindow, SweepWindow),
                Make_Diagnostic(n"DamageOutsideObstructionWindow", f"Hit.Emitters[{Index}].DamageWindow", FMars_Attack_Comparison("damage window contained in emitter sweep window", Emitter.DamageWindow.ToString())));
            for (const auto& Window : Clip.Get_Windows())
            {
                if (Window.Get_Id() != Emitter.DamageWindow || Emitter.DamageWindow == Motion.ObstructionWindow)
                { continue; }

                Add_Check(Report, Window.Get_Start().Get_PhaseId() == Motion.StrikePhase && Window.Get_End().Get_PhaseId() == Motion.StrikePhase,
                    Make_Diagnostic(n"DamageWindowPhase", f"Hit.Emitters[{Index}].DamageWindow", FMars_Attack_Comparison("contained in Strike", Emitter.DamageWindow.ToString())));
            }
        }

        if (HasBodyEmitter)
        {
            Add_Check(Report, Clip.Get_BodyChannel().Get_Enabled(),
                Make_Diagnostic(n"BodyChannelContract", "Clip.BodyChannel", FMars_Attack_Comparison("enabled body for Body emitters", "disabled")));
        }

        if (Clip.Get_BodyChannel().Get_Enabled())
        {
            Add_Check(Report, Clip.Get_BodyChannel().Get_InitialSource() == ECk_ProceduralAction_InitialSource::IdentityOffset,
                Make_Diagnostic(n"BodyChannelContract", "Clip.BodyChannel", FMars_Attack_Comparison("IdentityOffset body motion", "unsupported body source")));
            for (int32 Index = 0; Index < Phases.Num(); ++Index)
            {
                const auto Phase = Phases[Index];
                const auto Keys = Phase.Get_BodyKeys();
                const FString Field = f"Clip.Phases[{Index}].BodyKeys";
                Add_Check(Report, Keys.Num() > 0, Make_Diagnostic(n"BodyKeysMissing", Field, FMars_Attack_Comparison("body keys", "empty")));
                Add_Check(Report, Phase.Get_BodyInterpolation() == ECk_ProceduralAction_Interpolation::Linear,
                    Make_Diagnostic(n"UnsupportedBodyCurve", f"Clip.Phases[{Index}].BodyInterpolation", FMars_Attack_Comparison("Linear supported body envelope", f"{Phase.Get_BodyInterpolation() :n}")));
                for (int32 KeyIndex = 0; KeyIndex < Keys.Num(); ++KeyIndex)
                {
                    const auto Key = Keys[KeyIndex];
                    const auto Rotation = Key.Get_Rotation();
                    const auto PitchOnly = Math::Abs(Rotation.X) <= KINDA_SMALL_NUMBER && Math::Abs(Rotation.Z) <= KINDA_SMALL_NUMBER &&
                        Math::RadiansToDegrees(Rotation.AngularDistance(FQuat::Identity)) <= 45.0 + KINDA_SMALL_NUMBER;
                    const auto Recover = Phase.Get_Id() == Motion.RecoverPhase;
                    Add_Check(Report, Get_IsFinite(Key.Get_Translation()) && PitchOnly && (Recover == false || Rotation.IsIdentity(KINDA_SMALL_NUMBER)),
                        Make_Diagnostic(n"BodyKeyEnvelope", f"{Field}[{KeyIndex}]", FMars_Attack_Comparison("finite pitch-only <=45 degrees; Recover identity rotation", Key.Get_Translation().ToString())));
                    Add_Check(Report, Key.Get_ArriveTangent().IsNearlyZero(0.0) && Key.Get_LeaveTangent().IsNearlyZero(0.0),
                        Make_Diagnostic(n"UnsupportedBodyCurve", f"{Field}[{KeyIndex}]", FMars_Attack_Comparison("zero body tangents", "nonzero tangent")));
                }

                if (Phase.Get_Id() == Motion.StrikePhase && Keys.Num() > 0)
                {
                    Add_Check(Report, Keys.Last().Get_Rotation().IsIdentity(KINDA_SMALL_NUMBER),
                        Make_Diagnostic(n"StrikeEndRotation", Field, FMars_Attack_Comparison("translation-only Strike end", "rotated Strike end")));
                }
            }
        }

        return Report;
    }

    FMars_Attack_ValidationReport Validate_Loadout(const FMars_Attack_Loadout& InLoadout)
    {
        auto Report = Validate_SelectionPolicy(InLoadout.Selection);
        Append_Report(Report, Validate_ExecutionPolicy(InLoadout.Execution), "");
        Add_Check(Report, InLoadout.Entries.Num() > 0 && InLoadout.Entries.Num() <= MaxEntries,
            Make_Diagnostic(n"EntryBounds", "Entries", FMars_Attack_Comparison("[1,32] entries", f"{InLoadout.Entries.Num()}")));
        auto Ids = TArray<FGameplayTag>();
        auto Enabled = 0;
        for (int32 Index = 0; Index < Math::Min(InLoadout.Entries.Num(), MaxEntries); ++Index)
        {
            const auto Entry = InLoadout.Entries[Index];
            const FString Field = f"Entries[{Index}]";
            Add_Check(Report, Entry.Id.IsValid(), Make_Diagnostic(n"AttackIdMissing", f"{Field}.Id", FMars_Attack_Comparison("named attack", "None")));
            Add_Check(Report, Ids.Contains(Entry.Id) == false, Make_Diagnostic(n"DuplicateAttackId", f"{Field}.Id", FMars_Attack_Comparison("unique attack tag", Entry.Id.ToString())));
            Ids.Add(Entry.Id);
            if (Entry.Enabled == false)
            { continue; }

            ++Enabled;
            auto Definition = Entry.Definition.Get();
            Add_Check(Report, Entry.Definition.IsNull() == false, Make_Diagnostic(n"DefinitionMissing", f"{Field}.Definition", FMars_Attack_Comparison("configured definition", "null soft path")));
            if (ck::Is_NOT_Valid(Definition))
            {
                Add_Check(Report, false, Make_Diagnostic(n"DefinitionUnloaded", f"{Field}.Definition", FMars_Attack_Comparison("loaded before validation", Entry.Definition.ToString())));
                continue;
            }

            Append_Report(Report, Validate_Definition(Definition.Def), f"{Field}.Definition.");
        }

        Add_Check(Report, Enabled > 0, Make_Diagnostic(n"NoEnabledEntries", "Entries", FMars_Attack_Comparison("at least one enabled attack", "0")));
        return Report;
    }

    bool Get_BindingsEqual(const FMars_Attack_AnatomyBinding& InLeft, const FMars_Attack_AnatomyBinding& InRight)
    {
        return InLeft.Role == InRight.Role && InLeft.Source == InRight.Source && InLeft.LimbId == InRight.LimbId && InLeft.Locomotor == InRight.Locomotor;
    }

    bool Get_HasBinding(const TArray<FMars_Attack_AnatomyBinding>& InSchema, const FMars_Attack_AnatomyBinding& InBinding)
    {
        for (const auto& Binding : InSchema)
        {
            if (Get_BindingsEqual(Binding, InBinding))
            { return true; }
        }

        return false;
    }

    FMars_Attack_ValidationReport Validate_ResolvedLoadout(const FMars_Attack_ResolvedLoadout& InLoadout)
    {
        auto Report = Validate_SelectionPolicy(InLoadout.Selection);
        Append_Report(Report, Validate_ExecutionPolicy(InLoadout.Execution), "");
        Add_Check(Report, InLoadout.Entries.Num() > 0 && InLoadout.Entries.Num() <= MaxEntries,
            Make_Diagnostic(n"EntryBounds", "Entries", FMars_Attack_Comparison("[1,32] resolved entries", f"{InLoadout.Entries.Num()}")));
        Add_Check(Report, InLoadout.GameRevision > 0, Make_Diagnostic(n"GameRevisionMissing", "GameRevision", FMars_Attack_Comparison("positive game revision", f"{InLoadout.GameRevision}")));
        Add_Check(Report, InLoadout.Anatomy.Num() > 0 && InLoadout.Anatomy.Num() <= MaxRoles,
            Make_Diagnostic(n"AnatomyBounds", "Anatomy", FMars_Attack_Comparison("[1,64] bindings", f"{InLoadout.Anatomy.Num()}")));
        auto Roles = TArray<FGameplayTag>();
        auto LimbIds = TArray<FName>();
        for (int32 Index = 0; Index < Math::Min(InLoadout.Anatomy.Num(), MaxRoles); ++Index)
        {
            const auto Binding = InLoadout.Anatomy[Index];
            const FString Field = f"Anatomy[{Index}]";
            Add_Check(Report, Binding.Role.IsValid(), Make_Diagnostic(n"RoleMissing", f"{Field}.Role", FMars_Attack_Comparison("named role", "None")));
            Add_Check(Report, Roles.Contains(Binding.Role) == false, Make_Diagnostic(n"DuplicateRole", f"{Field}.Role", FMars_Attack_Comparison("unique role tag", Binding.Role.ToString())));
            Roles.Add(Binding.Role);
            Add_Check(Report, Binding.Source == EMars_Attack_AnatomySource::Body || Binding.Source == EMars_Attack_AnatomySource::ProceduralLimb,
                Make_Diagnostic(n"AnatomySourceEnum", f"{Field}.Source", FMars_Attack_Comparison("Body or ProceduralLimb", f"{int32(Binding.Source)}")));
            if (Binding.Source == EMars_Attack_AnatomySource::ProceduralLimb)
            {
                Add_Check(Report, Binding.LimbId.IsNone() == false, Make_Diagnostic(n"LimbIdMissing", f"{Field}.LimbId", FMars_Attack_Comparison("stable limb id", "None")));
                Add_Check(Report, LimbIds.Contains(Binding.LimbId) == false, Make_Diagnostic(n"DuplicateLimbId", f"{Field}.LimbId", FMars_Attack_Comparison("one semantic role per limb", Binding.LimbId.ToString())));
                LimbIds.Add(Binding.LimbId);
            }
            else if (Binding.Source == EMars_Attack_AnatomySource::Body)
            {
                Add_Check(Report, Binding.LimbId.IsNone() && Binding.Locomotor == false,
                    Make_Diagnostic(n"BodyBindingContract", Field, FMars_Attack_Comparison("body has no limb id or locomotor control", Binding.LimbId.ToString())));
            }
        }

        auto Ids = TArray<FGameplayTag>();
        for (int32 Index = 0; Index < Math::Min(InLoadout.Entries.Num(), MaxEntries); ++Index)
        {
            const auto Entry = InLoadout.Entries[Index];
            const FString Field = f"Entries[{Index}]";
            Add_Check(Report, Entry.Identity.Id.IsValid(), Make_Diagnostic(n"AttackIdMissing", f"{Field}.Identity.Id", FMars_Attack_Comparison("named attack", "None")));
            Add_Check(Report, Ids.Contains(Entry.Identity.Id) == false, Make_Diagnostic(n"DuplicateAttackId", f"{Field}.Identity.Id", FMars_Attack_Comparison("unique attack tag", Entry.Identity.Id.ToString())));
            Ids.Add(Entry.Identity.Id);
            Add_Check(Report, Entry.Identity.GameRevision == InLoadout.GameRevision,
                Make_Diagnostic(n"GameRevisionMismatch", f"{Field}.Identity.GameRevision", FMars_Attack_Comparison(f"{InLoadout.GameRevision}", f"{Entry.Identity.GameRevision}")));
            Append_Report(Report, Validate_Definition(Entry.Definition), f"{Field}.Definition.");
            Add_Check(Report, Entry.Definition.Prepare.UseCreatureFrontRange == false,
                Make_Diagnostic(n"CreatureDefaultsUnresolved", f"{Field}.Definition.Prepare", FMars_Attack_Comparison("resolved numeric range", "creature default")));
            for (const auto& Emitter : Entry.Definition.Hit.Emitters)
            { Add_Check(Report, Emitter.UseCreatureFrontCenter == false, Make_Diagnostic(n"CreatureDefaultsUnresolved", f"{Field}.Definition.Hit.Emitters", FMars_Attack_Comparison("resolved numeric centre", "creature default"))); }

            Add_Check(Report, Entry.Slots.Num() == Entry.Definition.Requirements.Slots.Num() && Entry.Slots.Num() <= MaxRoles,
                Make_Diagnostic(n"ResolvedSlotCoverage", f"{Field}.Slots", FMars_Attack_Comparison("exact authored slots", f"{Entry.Slots.Num()}")));
            Add_Check(Report, Entry.Parts.Num() == Entry.Definition.Requirements.Parts.Num() && Entry.Parts.Num() <= MaxRoles,
                Make_Diagnostic(n"ResolvedPartCoverage", f"{Field}.Parts", FMars_Attack_Comparison("exact authored prerequisites", f"{Entry.Parts.Num()}")));
            auto BoundSlots = TArray<FName>();
            auto BoundLimbs = TArray<FName>();
            auto HasLocomotor = false;
            for (int32 SlotIndex = 0; SlotIndex < Math::Min(Entry.Slots.Num(), MaxRoles); ++SlotIndex)
            {
                const auto Slot = Entry.Slots[SlotIndex];
                const FString SlotField = f"{Field}.Slots[{SlotIndex}]";
                Add_Check(Report, Get_HasBinding(InLoadout.Anatomy, Slot.Binding), Make_Diagnostic(n"RoleUnbound", f"{SlotField}.Binding", FMars_Attack_Comparison("exact anatomy binding", Slot.Binding.Role.ToString())));
                Add_Check(Report, Slot.Binding.Source == EMars_Attack_AnatomySource::ProceduralLimb,
                    Make_Diagnostic(n"ClaimSource", f"{SlotField}.Binding.Source", FMars_Attack_Comparison("ProceduralLimb", f"{int32(Slot.Binding.Source)}")));
                Add_Check(Report, BoundSlots.Contains(Slot.Slot) == false, Make_Diagnostic(n"DuplicateSlot", f"{SlotField}.Slot", FMars_Attack_Comparison("unique claimed slot", Slot.Slot.ToString())));
                Add_Check(Report, BoundLimbs.Contains(Slot.Binding.LimbId) == false, Make_Diagnostic(n"DuplicateClaimedLimb", f"{SlotField}.Binding.LimbId", FMars_Attack_Comparison("distinct claimed limb", Slot.Binding.LimbId.ToString())));
                auto Matches = 0;
                for (const auto& Authored : Entry.Definition.Requirements.Slots)
                {
                    if (Authored.Slot == Slot.Slot && Authored.Role == Slot.Binding.Role && Authored.MaxCondition == Slot.MaxCondition)
                    { ++Matches; }
                }

                Add_Check(Report, Matches == 1, Make_Diagnostic(n"ResolvedSlotMismatch", SlotField, FMars_Attack_Comparison("exact authored slot, role and ceiling", Slot.Slot.ToString())));
                BoundSlots.Add(Slot.Slot);
                BoundLimbs.Add(Slot.Binding.LimbId);
                HasLocomotor = HasLocomotor || Slot.Binding.Locomotor;
            }

            auto BoundParts = TArray<FGameplayTag>();
            for (int32 PartIndex = 0; PartIndex < Math::Min(Entry.Parts.Num(), MaxRoles); ++PartIndex)
            {
                const auto Part = Entry.Parts[PartIndex];
                const FString PartField = f"{Field}.Parts[{PartIndex}]";
                Add_Check(Report, Get_HasBinding(InLoadout.Anatomy, Part.Binding), Make_Diagnostic(n"RoleUnbound", f"{PartField}.Binding", FMars_Attack_Comparison("exact anatomy binding", Part.Binding.Role.ToString())));
                Add_Check(Report, BoundParts.Contains(Part.Binding.Role) == false,
                    Make_Diagnostic(n"DuplicateResolvedPart", f"{PartField}.Binding.Role", FMars_Attack_Comparison("unique resolved prerequisite", Part.Binding.Role.ToString())));
                BoundParts.Add(Part.Binding.Role);
                auto Matches = 0;
                for (const auto& Authored : Entry.Definition.Requirements.Parts)
                {
                    if (Authored.Role == Part.Binding.Role && Authored.MaxCondition == Part.MaxCondition)
                    { ++Matches; }
                }

                Add_Check(Report, Matches == 1, Make_Diagnostic(n"ResolvedPartMismatch", PartField, FMars_Attack_Comparison("exact authored role and ceiling", Part.Binding.Role.ToString())));
            }

            for (const auto& Authored : Entry.Definition.Requirements.Parts)
            {
                Add_Check(Report, BoundParts.Contains(Authored.Role), Make_Diagnostic(n"ResolvedPartMissing", f"{Field}.Parts",
                    FMars_Attack_Comparison("every authored prerequisite resolved", Authored.Role.ToString())));
            }

            if (HasLocomotor)
            {
                const auto Support = InLoadout.Execution.Locomotion.Get_Support();
                Add_Check(Report, Support.Get_Mode() != ECk_ProceduralLimbControl_SupportMode::Disabled,
                    Make_Diagnostic(n"LocomotorSupportDisabled", f"{Field}.Slots", FMars_Attack_Comparison("enabled support policy for locomotor claims", "Disabled")));
                auto Clip = Entry.Definition.Clip.Get();
                const auto Rate = InLoadout.Execution.Tuning.Get_Playback().Get_PlayRate();
                if (ck::IsValid(Clip) && Get_IsPositive(Rate))
                {
                    float64 Duration = 0.0;
                    for (const auto& Phase : Clip.Get_Phases())
                    { Duration += Phase.Get_Duration().Get_Seconds(); }

                    const auto MinimumHold = Duration / Rate + InLoadout.Execution.Tuning.Get_Transition().Get_DedicatedReturn().Get_Seconds();
                    Add_Check(Report, Support.Get_SupportHoldTimeout().Get_Seconds() + 1.0e-5 >= MinimumHold,
                        Make_Diagnostic(n"SupportHoldCoverage", f"{Field}.Definition.Clip", FMars_Attack_Comparison(f"hold >= {MinimumHold} seconds", f"{Support.Get_SupportHoldTimeout().Get_Seconds()}")));
                }
            }
        }

        return Report;
    }

    // Whether a code blocks for good (the attack is incapable) or only until the creature, the target or a timer changes.
    // Exhaustive over the enum: a new code needs a case here.
    EMars_Attack_BlockerKind Get_BlockerKind(EMars_Attack_BlockerCode InCode)
    {
        switch (InCode)
        {
            case EMars_Attack_BlockerCode::PartMissing:
            case EMars_Attack_BlockerCode::PartPendingDestroy:
            case EMars_Attack_BlockerCode::PartWrongOwner:
            case EMars_Attack_BlockerCode::PartSevered:
            case EMars_Attack_BlockerCode::PartBroken:
            case EMars_Attack_BlockerCode::PartDepleted:
            case EMars_Attack_BlockerCode::ConditionDisallowed:
            case EMars_Attack_BlockerCode::LimbDetached:
            case EMars_Attack_BlockerCode::LimbDisabled:
            case EMars_Attack_BlockerCode::LimbUnavailable:
            case EMars_Attack_BlockerCode::SupportCapacity:
            case EMars_Attack_BlockerCode::Dead:
            case EMars_Attack_BlockerCode::HitContactInvalid:
            case EMars_Attack_BlockerCode::EmitterCount:
            case EMars_Attack_BlockerCode::EmitterIdentity:
            case EMars_Attack_BlockerCode::EmitterBounds:
            case EMars_Attack_BlockerCode::AcceptedSourceInvalid:
            case EMars_Attack_BlockerCode::AcceptedRootInvalid:
            case EMars_Attack_BlockerCode::RootInvalid:
            case EMars_Attack_BlockerCode::RootDrift:
            case EMars_Attack_BlockerCode::FacingDrift:
            case EMars_Attack_BlockerCode::AcceptedSourceMissing:
            case EMars_Attack_BlockerCode::SampleTravel:
            case EMars_Attack_BlockerCode::AcceptedPresentationMismatch:
                return EMars_Attack_BlockerKind::Permanent;
            case EMars_Attack_BlockerCode::ControlBusy:
            case EMars_Attack_BlockerCode::LimbReturning:
            case EMars_Attack_BlockerCode::LimbUnplanted:
            case EMars_Attack_BlockerCode::SupportStance:
            case EMars_Attack_BlockerCode::NotReady:
            case EMars_Attack_BlockerCode::Ungrounded:
            case EMars_Attack_BlockerCode::Slope:
            case EMars_Attack_BlockerCode::Moving:
            case EMars_Attack_BlockerCode::WindupBlocked:
            case EMars_Attack_BlockerCode::Cooldown:
            case EMars_Attack_BlockerCode::GlobalCooldown:
            case EMars_Attack_BlockerCode::TargetLost:
            case EMars_Attack_BlockerCode::OutOfRange:
            case EMars_Attack_BlockerCode::TooClose:
            case EMars_Attack_BlockerCode::Height:
            case EMars_Attack_BlockerCode::Facing:
                return EMars_Attack_BlockerKind::Temporary;
        }
    }

    // A Permanent blocker makes the evaluation incapable.
    void Add_Blocker(FMars_Attack_Evaluation& InOutEvaluation, const FMars_Attack_Blocker& InBlocker)
    {
        InOutEvaluation.Blockers.Add(InBlocker);
        if (InBlocker.Kind == EMars_Attack_BlockerKind::Permanent)
        { InOutEvaluation.Capable = false; }
    }

    FMars_Attack_Blocker Make_Blocker(EMars_Attack_BlockerCode InCode, FString InField, const FMars_Attack_Comparison& InValues)
    {
        auto Blocker = FMars_Attack_Blocker();
        Blocker.Code = InCode;
        Blocker.Kind = Get_BlockerKind(InCode);
        Blocker.Field = InField;
        Blocker.Expected = InValues.Expected;
        Blocker.Actual = InValues.Actual;
        return Blocker;
    }

    void Evaluate_Role(FMars_Attack_Evaluation& InOutEvaluation, const FMars_Attack_ResolvedSlot& InRequirement,
        const TArray<FMars_Attack_RoleObservation>& InRoles)
    {
        const auto Binding = InRequirement.Binding;
        auto Found = -1;
        for (int32 Index = 0; Index < InRoles.Num(); ++Index)
        {
            if (InRoles[Index].Role == Binding.Role)
            {
                Found = Index;
                break;
            }
        }

        const auto Field = f"Roles[{Binding.Role.ToString()}]";
        auto Failures = TArray<FMars_Attack_Blocker>();
        if (Found < 0)
        {
            Failures.Add(Make_Blocker(EMars_Attack_BlockerCode::PartMissing, Field, FMars_Attack_Comparison("copied role observation", "missing")));
        }
        else
        {
            const auto Observation = InRoles[Found];
            const auto Part = Observation.Part;
            if (Part.Live == false)
            { Failures.Add(Make_Blocker(EMars_Attack_BlockerCode::PartMissing, Field, FMars_Attack_Comparison("live", "false"))); }

            if (Part.PendingDestroy)
            { Failures.Add(Make_Blocker(EMars_Attack_BlockerCode::PartPendingDestroy, Field, FMars_Attack_Comparison("not pending destroy", "pending"))); }

            if (Part.OwnerMatches == false || Observation.Source != Binding.Source || Observation.LimbId != Binding.LimbId)
            { Failures.Add(Make_Blocker(EMars_Attack_BlockerCode::PartWrongOwner, Field, FMars_Attack_Comparison("expected owner/source/stable limb", Observation.LimbId.ToString()))); }

            if (Binding.Source != EMars_Attack_AnatomySource::Body && Part.State == EMars_BodyPart_State::Severed)
            { Failures.Add(Make_Blocker(EMars_Attack_BlockerCode::PartSevered, Field, FMars_Attack_Comparison("Attached", "Severed"))); }

            if (Binding.Source != EMars_Attack_AnatomySource::Body && Part.State == EMars_BodyPart_State::Broken)
            { Failures.Add(Make_Blocker(EMars_Attack_BlockerCode::PartBroken, Field, FMars_Attack_Comparison("Attached", "Broken"))); }

            if (Part.Depleted)
            { Failures.Add(Make_Blocker(EMars_Attack_BlockerCode::PartDepleted, Field, FMars_Attack_Comparison("not depleted", "depleted"))); }

            if (int32(Part.Condition) > int32(InRequirement.MaxCondition) || int32(Part.Condition) < 0)
            { Failures.Add(Make_Blocker(EMars_Attack_BlockerCode::ConditionDisallowed, Field, FMars_Attack_Comparison(f"<= {InRequirement.MaxCondition :n}", f"{Part.Condition :n}"))); }

            if (Binding.Source == EMars_Attack_AnatomySource::ProceduralLimb)
            {
                const auto Limb = Observation.Limb;
                if (Limb.Exists == false)
                { Failures.Add(Make_Blocker(EMars_Attack_BlockerCode::PartMissing, f"{Field}.Limb", FMars_Attack_Comparison("live procedural limb", "missing"))); }

                if (Limb.Attached == false)
                { Failures.Add(Make_Blocker(EMars_Attack_BlockerCode::LimbDetached, f"{Field}.Limb", FMars_Attack_Comparison("attached", "false"))); }

                if (Limb.Enabled == false)
                { Failures.Add(Make_Blocker(EMars_Attack_BlockerCode::LimbDisabled, f"{Field}.Limb", FMars_Attack_Comparison("enabled", "false"))); }

                if (InRequirement.Slot.IsNone() == false)
                {
                    if (Limb.Control == ECk_ProceduralLimbControl_State::Controlled)
                    { Failures.Add(Make_Blocker(EMars_Attack_BlockerCode::ControlBusy, f"{Field}.Control", FMars_Attack_Comparison("Default", "Controlled"))); }
                    else if (Limb.Control == ECk_ProceduralLimbControl_State::Returning)
                    { Failures.Add(Make_Blocker(EMars_Attack_BlockerCode::LimbReturning, f"{Field}.Control", FMars_Attack_Comparison("Default", "Returning"))); }
                    else if (Limb.Control == ECk_ProceduralLimbControl_State::Unplanted)
                    { Failures.Add(Make_Blocker(EMars_Attack_BlockerCode::LimbUnplanted, f"{Field}.Control", FMars_Attack_Comparison("Default", "Unplanted"))); }
                    else if (Limb.Control != ECk_ProceduralLimbControl_State::Default)
                    { Failures.Add(Make_Blocker(EMars_Attack_BlockerCode::LimbUnavailable, f"{Field}.Control", FMars_Attack_Comparison("Default", "Unavailable"))); }

                    if (Binding.Locomotor && (Limb.Planted == false || Limb.Trusted == false))
                    { Failures.Add(Make_Blocker(EMars_Attack_BlockerCode::SupportStance, f"{Field}.Foot", FMars_Attack_Comparison("planted trusted claimed foot", "unplanted or untrusted"))); }
                }
            }
        }

        for (const auto& Failure : Failures)
        {
            auto Blocker = Failure;
            Blocker.Role = Binding.Role;
            Blocker.Slot = InRequirement.Slot;
            Add_Blocker(InOutEvaluation, Blocker);
        }
    }

    bool Get_IsClaimed(const FMars_Attack_ResolvedEntry& InEntry, FName InLimbId)
    {
        for (const auto& Slot : InEntry.Slots)
        {
            if (Slot.Binding.LimbId == InLimbId)
            { return true; }
        }

        return false;
    }

    FMars_Attack_Evaluation Evaluate(const FMars_Attack_EvaluationQuery& InQuery)
    {
        auto Evaluation = FMars_Attack_Evaluation();
        Evaluation.AttackId = InQuery.Entry.Identity.Id;
        Evaluation.Capable = true;
        for (const auto& Slot : InQuery.Entry.Slots)
        { Evaluate_Role(Evaluation, Slot, InQuery.Roles); }

        for (const auto& Part : InQuery.Entry.Parts)
        {
            auto Requirement = FMars_Attack_ResolvedSlot();
            Requirement.Binding = Part.Binding;
            Requirement.MaxCondition = Part.MaxCondition;
            Evaluate_Role(Evaluation, Requirement, InQuery.Roles);
        }

        auto SeenSupport = TArray<FName>();
        for (const auto& Limb : InQuery.Self.SupportLimbs)
        {
            if (SeenSupport.Contains(Limb.LimbId) || Limb.LimbId.IsNone())
            { continue; }

            SeenSupport.Add(Limb.LimbId);
            if (Get_IsClaimed(InQuery.Entry, Limb.LimbId) || Limb.Part.Live == false || Limb.Part.PendingDestroy ||
                Limb.Part.OwnerMatches == false || Limb.Part.State != EMars_BodyPart_State::Attached || Limb.Part.Depleted ||
                Limb.Limb.Exists == false || Limb.Limb.Attached == false || Limb.Limb.Enabled == false)
            { continue; }

            ++Evaluation.EnabledSupport;
            if (Limb.Limb.Control == ECk_ProceduralLimbControl_State::Default && Limb.Limb.Planted && Limb.Limb.Trusted)
            { ++Evaluation.StandingSupport; }
        }

        const auto Support = InQuery.Execution.Locomotion.Get_Support();
        const auto Minimum = Support.Get_Mode() == ECk_ProceduralLimbControl_SupportMode::Disabled ? 0 : Support.Get_MinimumTrustedContacts();
        if (Evaluation.EnabledSupport < Minimum)
        { Add_Blocker(Evaluation, Make_Blocker(EMars_Attack_BlockerCode::SupportCapacity, "Support.EnabledUnclaimed", FMars_Attack_Comparison(f">= {Minimum}", f"{Evaluation.EnabledSupport}"))); }

        if (Evaluation.StandingSupport < Minimum)
        { Add_Blocker(Evaluation, Make_Blocker(EMars_Attack_BlockerCode::SupportStance, "Support.StandingUnclaimed", FMars_Attack_Comparison(f">= {Minimum}", f"{Evaluation.StandingSupport}"))); }

        const auto State = InQuery.Self.State;
        if (State.Alive == false)
        { Add_Blocker(Evaluation, Make_Blocker(EMars_Attack_BlockerCode::Dead, "Self.Alive", FMars_Attack_Comparison("alive", "false"))); }

        if (State.MobilityReady == false)
        { Add_Blocker(Evaluation, Make_Blocker(EMars_Attack_BlockerCode::SupportCapacity, "Self.MobilityReady", FMars_Attack_Comparison("required locomotion capacity", "false"))); }

        if (State.Ready == false)
        { Add_Blocker(Evaluation, Make_Blocker(EMars_Attack_BlockerCode::NotReady, "Self.Ready", FMars_Attack_Comparison("ready", "false"))); }

        if (State.Grounded == false)
        { Add_Blocker(Evaluation, Make_Blocker(EMars_Attack_BlockerCode::Ungrounded, "Self.Grounded", FMars_Attack_Comparison("grounded", "false"))); }

        if (Math::IsFinite(State.SlopeDegrees) == false || State.SlopeDegrees > InQuery.Execution.MaxGroundSlopeDegrees)
        { Add_Blocker(Evaluation, Make_Blocker(EMars_Attack_BlockerCode::Slope, "Self.SlopeDegrees", FMars_Attack_Comparison(f"<= {InQuery.Execution.MaxGroundSlopeDegrees}", f"{State.SlopeDegrees}"))); }

        if (Support.Get_Mode() == ECk_ProceduralLimbControl_SupportMode::ProjectedSupportRegion && State.SupportRegionReady == false)
        { Add_Blocker(Evaluation, Make_Blocker(EMars_Attack_BlockerCode::SupportStance, "Self.SupportRegionReady", FMars_Attack_Comparison("supported region", "false"))); }

        if (InQuery.Cooldown.EntryRemaining > 0.0f || Math::IsFinite(InQuery.Cooldown.EntryRemaining) == false)
        { Add_Blocker(Evaluation, Make_Blocker(EMars_Attack_BlockerCode::Cooldown, "Cooldown.EntryRemaining", FMars_Attack_Comparison("0", f"{InQuery.Cooldown.EntryRemaining}"))); }

        if (InQuery.Cooldown.GlobalRemaining > 0.0f || Math::IsFinite(InQuery.Cooldown.GlobalRemaining) == false)
        { Add_Blocker(Evaluation, Make_Blocker(EMars_Attack_BlockerCode::GlobalCooldown, "Cooldown.GlobalRemaining", FMars_Attack_Comparison("0", f"{InQuery.Cooldown.GlobalRemaining}"))); }

        const auto Prepare = InQuery.Entry.Definition.Prepare;
        const auto Target = InQuery.Target;
        if (Target.Valid == false)
        { Add_Blocker(Evaluation, Make_Blocker(EMars_Attack_BlockerCode::TargetLost, "Target.Valid", FMars_Attack_Comparison("live eligible target", "false"))); }

        if (Math::IsFinite(Target.Distance) == false || Target.Distance > Prepare.MaxDistance)
        { Add_Blocker(Evaluation, Make_Blocker(EMars_Attack_BlockerCode::OutOfRange, "Target.Distance", FMars_Attack_Comparison(f"<= {Prepare.MaxDistance}", f"{Target.Distance}"))); }

        if (Target.Distance < Prepare.MinDistance)
        { Add_Blocker(Evaluation, Make_Blocker(EMars_Attack_BlockerCode::TooClose, "Target.Distance", FMars_Attack_Comparison(f">= {Prepare.MinDistance}", f"{Target.Distance}"))); }

        if (Math::IsFinite(Target.HeightDifference) == false || Math::Abs(Target.HeightDifference) > Prepare.MaxHeightDifference)
        { Add_Blocker(Evaluation, Make_Blocker(EMars_Attack_BlockerCode::Height, "Target.HeightDifference", FMars_Attack_Comparison(f"absolute <= {Prepare.MaxHeightDifference}", f"{Target.HeightDifference}"))); }

        if (Math::IsFinite(Target.FacingDegrees) == false || Math::Abs(Target.FacingDegrees) > Prepare.FacingToleranceDegrees)
        { Add_Blocker(Evaluation, Make_Blocker(EMars_Attack_BlockerCode::Facing, "Target.FacingDegrees", FMars_Attack_Comparison(f"<= {Prepare.FacingToleranceDegrees}", f"{Target.FacingDegrees}"))); }

        if (Math::IsFinite(State.RootSpeed) == false || Math::Abs(State.RootSpeed) > Prepare.MaxSpeedToStart)
        { Add_Blocker(Evaluation, Make_Blocker(EMars_Attack_BlockerCode::Moving, "Self.RootSpeed", FMars_Attack_Comparison(f"<= {Prepare.MaxSpeedToStart}", f"{State.RootSpeed}"))); }

        if (InQuery.Self.WindupClear == false)
        { Add_Blocker(Evaluation, Make_Blocker(EMars_Attack_BlockerCode::WindupBlocked, "Self.WindupClear", FMars_Attack_Comparison("clear preflight", "false"))); }

        Evaluation.Availability = Evaluation.Capable == false ? EMars_Attack_Availability::Unavailable :
            Evaluation.Blockers.Num() > 0 ? EMars_Attack_Availability::Waiting : EMars_Attack_Availability::Ready;
        return Evaluation;
    }

    bool Get_HasBlocker(const FMars_Attack_Evaluation& InEvaluation, EMars_Attack_BlockerCode InCode)
    {
        for (const auto& Blocker : InEvaluation.Blockers)
        {
            if (Blocker.Code == InCode)
            { return true; }
        }

        return false;
    }

    bool Get_HasControlWait(const FMars_Attack_Evaluation& InEvaluation)
    {
        return Get_HasBlocker(InEvaluation, EMars_Attack_BlockerCode::ControlBusy) ||
            Get_HasBlocker(InEvaluation, EMars_Attack_BlockerCode::LimbReturning) ||
            Get_HasBlocker(InEvaluation, EMars_Attack_BlockerCode::LimbUnplanted);
    }

    bool Get_IsBefore(const FMars_Attack_SelectionCandidate& InLeft, const FMars_Attack_SelectionCandidate& InRight)
    {
        if (InLeft.Priority != InRight.Priority)
        { return InLeft.Priority > InRight.Priority; }

        if (InLeft.LastStartSequence != InRight.LastStartSequence)
        { return InLeft.LastStartSequence < InRight.LastStartSequence; }

        return InLeft.Id.ToString().ToLower() < InRight.Id.ToString().ToLower();
    }

    FMars_Attack_Selection Select(const FMars_Attack_SelectionQuery& InQuery)
    {
        auto Selection = FMars_Attack_Selection();
        auto Order = TArray<int32>();
        for (int32 Index = 0; Index < InQuery.Candidates.Num(); ++Index)
        {
            auto At = 0;
            while (At < Order.Num() && Get_IsBefore(InQuery.Candidates[Index], InQuery.Candidates[Order[At]]) == false)
            { ++At; }

            Order.Insert(Index, At);
        }

        auto CapableCount = 0;
        auto PreferredIndex = -1;
        auto ReadyIndex = -1;
        for (const auto Index : Order)
        {
            const auto Candidate = InQuery.Candidates[Index];
            if (Candidate.Evaluation.Capable == false)
            { continue; }

            ++CapableCount;
            const auto Eligible = InQuery.Policy.ControlWait == EMars_Attack_ControlWaitPolicy::WaitForPreferred || Get_HasControlWait(Candidate.Evaluation) == false;
            if (PreferredIndex < 0 && Eligible)
            { PreferredIndex = Index; }

            if (ReadyIndex < 0 && Candidate.Evaluation.Availability == EMars_Attack_Availability::Ready)
            { ReadyIndex = Index; }
        }

        const auto Preparation = InQuery.Preparation;
        const auto MatchesTarget = Preparation.TargetIdentity == InQuery.Target.Identity && Preparation.TargetGeneration == InQuery.Target.Generation;
        const auto Retain = Preparation.State == EMars_Attack_PreparationState::Active && MatchesTarget;
        if (Retain)
        {
            for (const auto Index : Order)
            {
                const auto Candidate = InQuery.Candidates[Index];
                if (Candidate.Id == Preparation.Preferred && Candidate.Evaluation.Capable &&
                    (InQuery.Policy.ControlWait == EMars_Attack_ControlWaitPolicy::WaitForPreferred || Get_HasControlWait(Candidate.Evaluation) == false))
                {
                    PreferredIndex = Index;
                    break;
                }
            }
        }

        if (ReadyIndex >= 0)
        { Selection.ReadyChoice = TOptional<FGameplayTag>(InQuery.Candidates[ReadyIndex].Id); }

        if (CapableCount == 0)
        { return Selection; }

        if (PreferredIndex < 0)
        {
            Selection.Disposition = EMars_Attack_SelectionDisposition::Wait;
            return Selection;
        }

        const auto Preferred = InQuery.Candidates[PreferredIndex];
        Selection.Preferred = TOptional<FGameplayTag>(Preferred.Id);
        if (Preparation.State == EMars_Attack_PreparationState::TimedOut && MatchesTarget)
        {
            Selection.Disposition = EMars_Attack_SelectionDisposition::Wait;
            return Selection;
        }

        if (Preferred.Evaluation.Availability == EMars_Attack_Availability::Ready)
        {
            Selection.Selected = TOptional<FGameplayTag>(Preferred.Id);
            Selection.Disposition = EMars_Attack_SelectionDisposition::Start;
            return Selection;
        }

        // A request without preparation has zero elapsed grace; it may fallback only when the authored delay is zero.
        const auto Elapsed = Retain ? Preparation.ElapsedReadinessWait : 0.0f;
        if (InQuery.Policy.TemporaryReadiness == EMars_Attack_TemporaryReadinessPolicy::UseReadyAlternative && ReadyIndex >= 0 &&
            Elapsed >= InQuery.Policy.ReadyAlternativeDelaySeconds)
        {
            Selection.Selected = TOptional<FGameplayTag>(InQuery.Candidates[ReadyIndex].Id);
            Selection.Disposition = EMars_Attack_SelectionDisposition::Start;
        }
        else
        {
            Selection.Disposition = Preparation.State == EMars_Attack_PreparationState::Active ?
                EMars_Attack_SelectionDisposition::Wait : EMars_Attack_SelectionDisposition::Prepare;
        }

        return Selection;
    }
}
