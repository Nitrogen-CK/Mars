// Every frame a jab is in flight, a throw waits or a combo is live: advances each fist's clock (a fist that reaches its
// blow turns back, one that is home again rests), starts a waiting throw the moment the rhythm allows, and ends the combo
// ComboSeconds after its last jab, so the next throw leads again. A fist that dealt its blow this frame sweeps through the
// thrower's DamageDealer here, on this clock, whoever asked for the throw. With nothing in flight, nothing waiting and no
// combo live it does nothing.
class UMars_Processor_Punch_Tick : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _RunAfter.Add(n"/Script/Angelscript.Mars_Processor_Punch_HandleRequests");

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_Punch);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle, FMars_Fragment_Punch& InState)
    {
        if (utils_punch::Get_AreFistsHome(InState) && InState.HasWaitingThrow == false && InState.SinceThrow.IsSet() == false)
        { return; }

        const auto Spec = InHandle.Get_Fragment(FMars_Fragment_Punch_Params).Spec;
        const auto DeltaSeconds = float32(InDeltaT.Get_Seconds());

        if (InState.SinceThrow.IsSet())
        { InState.SinceThrow = TOptional<float32>(InState.SinceThrow.GetValue() + DeltaSeconds); }

        // Advanced before a waiting throw starts, so a jab thrown this frame keeps its whole clock.
        TArray<EMars_Hand> Blows;
        if (Advance_Fist(Spec.Rhythm, InState.Left, DeltaSeconds))
        { Blows.Add(EMars_Hand::Left); }

        if (Advance_Fist(Spec.Rhythm, InState.Right, DeltaSeconds))
        { Blows.Add(EMars_Hand::Right); }

        auto Thrown = TOptional<EMars_Hand>();
        if (InState.HasWaitingThrow && utils_punch::Get_CanThrow(Spec.Rhythm, InState))
        {
            Thrown = TOptional<EMars_Hand>(InState.NextHand);
            InState.HasWaitingThrow = false;
            utils_punch::Start_Jab(InState, InState.NextHand, true);
        }

        const auto IsComboOver = InState.SinceThrow.IsSet() && InState.SinceThrow.GetValue() >= Spec.Rhythm.ComboSeconds;
        if (IsComboOver && InState.HasWaitingThrow == false && utils_punch::Get_AreFistsHome(InState))
        {
            InState.NextHand = Spec.LeadHand;
            InState.SinceThrow.Reset();
        }

        // InState is not touched past this line: a sweep requests damage and a listener may compose anything.
        auto Self = InHandle.As_Punch();
        for (auto Hand : Blows)
        { Deal_Blow(Self, Spec.Blow, Hand); }

        if (Thrown.IsSet() && Self.Has_Fragment(FMars_Fragment_Punch_Signals))
        { Self.Get_Fragment(FMars_Fragment_Punch_Signals).OnThrown.Broadcast(Self, Thrown.GetValue()); }
    }

    // Advances a fist in flight by InDeltaSeconds. True when it reached its blow this frame and deals it.
    private bool Advance_Fist(const FMars_Punch_Rhythm& InRhythm, FMars_Punch_Fist& InOutFist, float32 InDeltaSeconds)
    {
        if (InOutFist.Stroke == EMars_Punch_Stroke::None)
        { return false; }

        const auto Previous = InOutFist.Stroke;
        InOutFist.Elapsed += InDeltaSeconds;
        InOutFist.Stroke = utils_punch::Get_StrokeAt(InRhythm, InOutFist.Elapsed);

        const auto ReachedBlow = Previous == EMars_Punch_Stroke::Out && InOutFist.Stroke != EMars_Punch_Stroke::Out;
        const auto DealsBlow = ReachedBlow && InOutFist.DealsBlow;
        if (InOutFist.Stroke == EMars_Punch_Stroke::None)
        { InOutFist = FMars_Punch_Fist(); }

        return DealsBlow;
    }

    // One sphere sweep from the thrower's view along its forward, through its DamageDealer, which requests the damage of
    // the first hurtbox met. A thrower without a dealer hits nothing.
    private void Deal_Blow(FCk_Handle_Punch& InPunch, const FMars_Punch_Blow& InBlow, EMars_Hand InHand)
    {
        auto Hit = FCk_ShapeCast_Result();

        FCk_Handle Thrower = InPunch;
        auto Dealer = Thrower.As_DamageDealer(ECk_SanityCheck::UnChecked);
        if (ck::IsValid(Dealer))
        {
            const auto Origin = utils_punch::Get_BlowOrigin(Thrower);
            const auto Forward = Origin.GetRotation().GetForwardVector();
            const auto Start = Origin.GetLocation();

            auto Template = utils_damage_dealer::Make_Event(Dealer, InBlow.Damage, InBlow.DamageType);
            Template.Hit.Impulse = Forward * InBlow.ImpulseSpeed;
            Hit = Dealer.Request_StrikeSweep(FMars_DamageDealer_Sweep(Start, Start + Forward * InBlow.Reach, InBlow.Radius), Template);
        }

        if (InPunch.Has_Fragment(FMars_Fragment_Punch_Signals))
        { InPunch.Get_Fragment(FMars_Fragment_Punch_Signals).OnBlow.Broadcast(InPunch, InHand, Hit); }
    }
}
