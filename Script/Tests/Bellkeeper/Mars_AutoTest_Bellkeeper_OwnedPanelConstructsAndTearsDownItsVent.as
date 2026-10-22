// Exercise the real opted-in assembly, not only a hand-composed Cycle fixture. A child spawn waits for its parent's
// local construction to finish; the kernel/commit sink must appear after that child is constructed and owned.
class UMars_AutoTest_Bellkeeper_OwnedPanelConstructsAndTearsDownItsVent : UCk_AutoTest_Base
{
    default _TimeoutSeconds = 12.0f;
    private FCk_Handle _Panel;
    private FCk_Handle_Bellkeeper _Lock;
    private FCk_Handle_Cycle _Cycle;
    private FCk_Handle_Hazard _Hazard;
    private FCk_Handle_MechanismSource _VentSource;
    private FCk_Handle_Timer _Timer;
    private int32 _Constructed = 0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Params = UMars_Bellkeeper_EntityScript::Params();
        Params.SpawnTransform = FTransform(FVector(42000.0, 340000.0, -41000.0));
        Params.Phrase.Add(EMars_Bellkeeper_Glyph::Diamond);
        Params.Phrase.Add(EMars_Bellkeeper_Glyph::Triangle);
        Params.Phrase.Add(EMars_Bellkeeper_Glyph::Cross);
        for (int32 Index = 0; Index < 3; ++Index)
        {
            Params.StartGlyphs.Add(EMars_Bellkeeper_Glyph::Square);
            Params.Rewards.Add(FMars_Bellkeeper_Reward(utils_held_item::Make_DefinitionSoft(mars_items::Ration()),
                FTransform(FVector(0.0, Index * 60.0, 50.0))));
        }
        Params.CommitChannel = GameplayTags::Mechanism_Channel_J;
        Params.VentChannel = GameplayTags::Mechanism_Channel_K;
        Params.Source.OutputChannel = GameplayTags::Mechanism_Channel_L;
        Params.OwnedVent.Enabled = true;
        Params.OwnedVent.OffsetWorld = FVector(500.0, 0.0, 0.0);
        auto Pending = utils_entity_script::Request_SpawnEntity(InHandle, UMars_Bellkeeper_EntityScript, Params);
        utils_pending_entity_script::Promise_OnConstructed(Pending, FCk_Delegate_EntityScript_Constructed(this, n"OnPanelConstructed"));
        Add_Step_WaitUntil("actual panel and owned vent finish their composition", n"Check_Ready", 900, 0);
        Add_Step("verify owned topology and commit the starting wrong phrase", n"Step_Commit");
        Add_Step_WaitUntil("actual child Cycle and Hazard fire", n"Check_Fire", 900, 0);
        Add_Step("destroy actual panel while child fires", n"Step_Destroy");
        Add_Step_WaitUntil("all owned assembly work is gone", n"Check_Gone", 900, 0);
        Add_Step_WaitSeconds("outlast the old pulse", 2.2f);
        Add_Step("assembly leaves no source or timer", n"Step_Assert");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void OnPanelConstructed(FCk_Handle_EntityScript InPanel)
    {
        _Panel = InPanel;
        ++_Constructed;
    }

    UFUNCTION()
    private void Check_Ready(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        if (ck::Is_NOT_Valid(_Panel))
        { Result.Set(false); return; }
        _Lock = _Panel.As_Bellkeeper(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(_Lock))
        { Result.Set(false); return; }
        _Cycle = _Lock.Get_Fragment(FMars_Fragment_Bellkeeper_Params).VentCycle;
        _VentSource = _Lock.Get_Fragment(FMars_Fragment_Bellkeeper_Params).VentSource;
        if (ck::Is_NOT_Valid(_Cycle))
        { Result.Set(false); return; }
        _Hazard = _Cycle.As_Hazard(ECk_SanityCheck::UnChecked);
        Result.Set(ck::IsValid(_Cycle) && ck::IsValid(_Hazard) && ck::IsValid(_VentSource)
            && _Lock.Has_Fragment(FMars_Tag_Bellkeeper_NeedsSetup) == false);
    }

    UFUNCTION()
    private void Step_Commit(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Constructed, 1, "actual panel constructed once");
        Assert_True(utils_entity_lifetime::Get_LifetimeOwner(_Cycle) == _Panel, "actual vent is directly owned by panel");
        Assert_False(_Cycle.Has_Fragment(FMars_Feature_MechanismSink), "actual vent has no competing power sink");
        auto VentScript = utils_entity_script::DoCast(_Cycle.H());
        Assert_True(VentScript.IsSet(), "actual vent carries the EntityScript feature");
        if (VentScript.IsSet())
        {
            Assert_True(utils_entity_script::Get_ScriptClass(VentScript.GetValue()) == UMars_Vent_EntityScript,
                "actual unchanged Vent entity script owns the Cycle");
        }
        _Lock.Request_Commit(FMars_Request_Bellkeeper_Commit());
    }

    UFUNCTION()
    private void Check_Fire(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_Cycle.Get_IsRunning() && _Cycle.Get_CurrentPhase() == GameplayTags::Mechanism_Phase_Fire
            && _Hazard.Get_IsArmed() && _VentSource.Get_IsAsserted());
    }

    UFUNCTION()
    private void Step_Destroy(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Timer = _Lock.Get_Fragment(FMars_Fragment_Bellkeeper).VentTimer;
        Log(f"[BellkeeperActualAssembly] constructed={_Constructed} cycleRunning={_Cycle.Get_IsRunning()} hazardArmed={_Hazard.Get_IsArmed()}");
        utils_entity_lifetime::Request_DestroyEntity(_Panel);
    }

    UFUNCTION()
    private void Check_Gone(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(ck::Is_NOT_Valid(_Panel) && ck::Is_NOT_Valid(_Cycle) && ck::Is_NOT_Valid(_Hazard)
            && ck::Is_NOT_Valid(_VentSource) && ck::Is_NOT_Valid(_Timer));
    }

    UFUNCTION()
    private void Step_Assert(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(utils_mechanism_source::Get_SourcesOn(InHandle, GameplayTags::Mechanism_Channel_K).Num(), 0, "no source survived");
        Assert_False(ck::IsValid(_Timer), "no pulse timer survived");
    }
}
