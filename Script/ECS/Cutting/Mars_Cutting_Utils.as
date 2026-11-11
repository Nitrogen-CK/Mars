namespace utils_cutting
{
    // Composes the cleaver on InHandle (the station entity; the feature does not need the Station feature). The spec's Nodes
    // are built by the caller: the hand slides Nodes.LateralNode along local Y. The chop is the kernel's clock alone: what
    // draws the cleaver follows its signals. It adds the replicated ledger unless it already arrived, and the mirror starts
    // from the arrived ledger: chops started or landed before this machine composed are not raised. A rejected spec or a
    // missing node ensures and returns an invalid handle.
    FCk_Handle_Cutting Add(FCk_Handle& InHandle, FMars_Cutting_Spec InSpec)
    {
        const auto Validation = InSpec.Validate();
        if (ck::EnsureIfNot(Validation.IsValid(), f"[Cutting] [{InHandle.ToString()}] rejected the spec: {Validation.Get_Error()}"))
        { return FCk_Handle_Cutting(); }

        if (ck::EnsureIfNot(ck::IsValid(InSpec.Nodes.LateralNode), f"[Cutting] [{InHandle.ToString()}] needs a lateral node"))
        { return FCk_Handle_Cutting(); }

        auto Params = FMars_Fragment_Cutting_Params();
        Params.Spec = InSpec;

        InHandle.Add_Fragment(FMars_Feature_Cutting());
        InHandle.Add_Fragment(Params);

        // A client's copy can receive the replicated ledger before it composes: the arrived ledger stands then.
        if (InHandle.Has_Fragment(FMars_Fragment_Cutting) == false)
        { InHandle.Add_Fragment(FMars_Fragment_Cutting(), ECk_Replication::Replicates); }

        auto Local = FMars_Fragment_Cutting_Local();
        Local.Last = TOptional<FMars_Fragment_Cutting>(InHandle.Get_Fragment(FMars_Fragment_Cutting));
        InHandle.Add_Fragment(Local);
        InHandle.Add_Fragment(FMars_Tag_Cutting_NeedsMirror());
        return InHandle.As_Cutting();
    }

    // The lateral node's offset Y is the hand; X and Z stay where the entity script put them.
    void Apply_HandToNode(FCk_Handle_SceneNode InLateralNode, float32 InHandLateral)
    {
        auto LateralNode = InLateralNode;
        auto Location = utils_scene_node::Get_Offset_Location(LateralNode);
        Location.Y = InHandLateral;
        utils_scene_node::Request_UpdateOffset_Location(LateralNode, Location, ECk_RelativeAbsolute::Absolute);
    }

    // Whether InOperator may chop at InCutting: the station on InCutting's entity is operated by InOperator. A Cutting with no
    // Station on its entity answers no.
    bool Get_MayChopFor(const FCk_Handle_Cutting& InCutting, FCk_Handle InOperator)
    {
        const auto Station = InCutting.H().As_Station(ECk_SanityCheck::UnChecked);
        return ck::IsValid(Station) && Station.Get_IsOperatedBy(InOperator);
    }

    // InOperator chops at InCutting with the hand at InLateralCm. A Cutting with a replication driver is reached through
    // Cue.Mars.Cutting.Chop, which only its authority applies; a local one has no other machine to reach and takes the Chop
    // directly. Either way the chop is refused unless InOperator operates the station, and starts only from Idle.
    void Request_ChopFor(FCk_Handle_Cutting& InCutting, FCk_Handle InOperator, float32 InLateralCm)
    {
        if (utils_entity_replication_driver::Has(InCutting))
        {
            utils_cue_generic::Request_ExecuteCue(InCutting, GameplayTags::Cue_Mars_Cutting_Chop,
                FMars_Cutting_ChopAim(InOperator, InLateralCm), ECk_Cue_ReliabilityPolicy::Reliable, ECk_Cue_MulticastPolicy::ServerOnly);
            return;
        }

        if (Get_MayChopFor(InCutting, InOperator))
        { InCutting.Request_Chop(FMars_Request_Cutting_Chop(InLateralCm)); }
    }
}

//--------------------------------------------------------------------------------------------------------------------------
// Getters
//--------------------------------------------------------------------------------------------------------------------------

mixin FMars_Cutting_Spec Get_Spec(const FCk_Handle_Cutting& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Cutting_Params).Spec;
}

mixin float32 Get_HandLateral(const FCk_Handle_Cutting& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Cutting).HandLateral;
}

// The chop clock's phase on this machine; it advances only with authority, so a client reads Idle.
mixin EMars_Cutting_ChopPhase Get_ChopPhase(const FCk_Handle_Cutting& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Cutting_Local).ChopPhase;
}

// Chops started, by the ledger.
mixin int32 Get_ChopSerial(const FCk_Handle_Cutting& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Cutting).ChopSerial;
}

// Chops landed, by the ledger.
mixin int32 Get_LandSerial(const FCk_Handle_Cutting& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Cutting).LandSerial;
}

// The hand this machine's operator predicts; unset while none stands.
mixin TOptional<float32> TryGet_PredictedHand(const FCk_Handle_Cutting& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Cutting_Local).PredictedHand;
}

// The hand the lateral node shows on this machine: the prediction while one stands, else the ledger's.
mixin float32 Get_ShownHand(const FCk_Handle_Cutting& Self)
{
    const auto Predicted = Self.TryGet_PredictedHand();
    return Predicted.IsSet() ? Predicted.GetValue() : Self.Get_HandLateral();
}

// From a chop's start until its recover ends: a press meanwhile is ignored.
mixin bool Get_IsChopping(const FCk_Handle_Cutting& Self)
{
    return Self.Get_ChopPhase() != EMars_Cutting_ChopPhase::Idle;
}

//--------------------------------------------------------------------------------------------------------------------------
// Requests
//--------------------------------------------------------------------------------------------------------------------------

mixin void Request_Nudge(FCk_Handle_Cutting& Self, const FMars_Request_Cutting_Nudge& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_Cutting_Requests);
    Requests.NudgeRequests.Add(InRequest);
}

mixin void Request_Chop(FCk_Handle_Cutting& Self, const FMars_Request_Cutting_Chop& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_Cutting_Requests);
    Requests.ChopRequests.Add(InRequest);
}

mixin void Request_Reset(FCk_Handle_Cutting& Self, const FMars_Request_Cutting_Reset& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_Cutting_Requests);
    Requests.ResetRequests.Add(InRequest);
}

mixin void Request_PredictHand(FCk_Handle_Cutting& Self, const FMars_Request_Cutting_PredictHand& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_Cutting_Requests);
    Requests.PredictHandRequests.Add(InRequest);
}

mixin void Request_ClearPrediction(FCk_Handle_Cutting& Self, const FMars_Request_Cutting_ClearPrediction& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_Cutting_Requests);
    Requests.ClearPredictionRequests.Add(InRequest);
}

//--------------------------------------------------------------------------------------------------------------------------
// Signal Binding
//--------------------------------------------------------------------------------------------------------------------------

mixin void BindTo_OnChopStarted(FCk_Handle_Cutting& Self, FMars_Delegate_Cutting_OnChopStarted InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_Cutting_Signals);
    Fragment.OnChopStarted.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnChopStarted(FCk_Handle_Cutting& Self, FMars_Delegate_Cutting_OnChopStarted InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_Cutting_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_Cutting_Signals).OnChopStarted.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void BindTo_OnChopLanded(FCk_Handle_Cutting& Self, FMars_Delegate_Cutting_OnChopLanded InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_Cutting_Signals);
    Fragment.OnChopLanded.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnChopLanded(FCk_Handle_Cutting& Self, FMars_Delegate_Cutting_OnChopLanded InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_Cutting_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_Cutting_Signals).OnChopLanded.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}
