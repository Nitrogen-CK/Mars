// The roster packs heads into exactly four slots, parking the unused ones at the sentinel (0, 0, k_AbsentHeadZ) and
// dropping any past the fourth; and a running roster puts a watched stand-in head on the slot after the world's player
// characters, with every later slot at the sentinel. The test spawns its own roster (the world's subsystem may have one
// too; both write the same values). EyeSwarm_Mars_MPC need not exist: Get_LastWritten updates without it. Isolated Z
// band: -85000.
class UMars_AutoTest_EyeSwarm_RosterWritesPlayers : UCk_AutoTest_Base
{
    private const FVector FakeHead = FVector(123.0, -456.0, -85000.0);

    private FCk_Handle _RosterEntity;
    private UMars_EyeSwarmRoster_EntityScript _Roster;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Add_Step("packing fills four slots in order and parks the rest", n"Step_AssertPacking");
        Add_Step("spawn a roster and a watched stand-in head", n"Step_SpawnRoster");
        Add_Step_WaitUntil("the roster is constructed", n"Check_RosterConstructed");
        Add_Step_WaitUntil("the roster has written the stand-in head", n"Check_HeadWritten");
        Add_Step("the stand-in follows the players and every later slot is the sentinel", n"Step_AssertSlots");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_AssertPacking(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Absent = utils_eye_swarm::Get_AbsentHead();

        auto Empty = utils_eye_swarm::Pack_PlayerSlots(TArray<FVector>());
        Assert_Equals_Int(Empty.Num(), constants_eye_swarm::k_NumPlayerSlots, "no heads: slot count");
        for (int32 Slot = 0; Slot < Empty.Num(); ++Slot)
        { Assert_True(Empty[Slot].Equals(Absent, 0.01), f"no heads: slot {Slot} is the sentinel (got [{Empty[Slot].ToString()}])"); }

        TArray<FVector> One;
        One.Add(FakeHead);
        auto OneSlots = utils_eye_swarm::Pack_PlayerSlots(One);
        Assert_Equals_Int(OneSlots.Num(), constants_eye_swarm::k_NumPlayerSlots, "one head: slot count");
        Assert_True(OneSlots[0].Equals(FakeHead, 0.01), f"one head: slot 0 is the head (got [{OneSlots[0].ToString()}])");
        for (int32 Slot = 1; Slot < OneSlots.Num(); ++Slot)
        { Assert_True(OneSlots[Slot].Equals(Absent, 0.01), f"one head: slot {Slot} is the sentinel (got [{OneSlots[Slot].ToString()}])"); }

        TArray<FVector> Six;
        for (int32 Index = 0; Index < 6; ++Index)
        { Six.Add(FVector(float(Index), 0.0, 0.0)); }
        auto SixSlots = utils_eye_swarm::Pack_PlayerSlots(Six);
        Assert_Equals_Int(SixSlots.Num(), constants_eye_swarm::k_NumPlayerSlots, "six heads: slot count");
        for (int32 Slot = 0; Slot < SixSlots.Num(); ++Slot)
        { Assert_True(SixSlots[Slot].Equals(Six[Slot], 0.01), f"six heads: slot {Slot} is head {Slot} (got [{SixSlots[Slot].ToString()}])"); }

        Assert_True(utils_eye_swarm::Get_IsAbsentHead(Absent), "the sentinel reads as absent");
        Assert_False(utils_eye_swarm::Get_IsAbsentHead(FakeHead), "a head in the test band does not read as absent");
    }

    UFUNCTION()
    private void Step_SpawnRoster(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto HeadEntity = utils_entity_lifetime::Request_CreateEntity(InHandle);
        auto Head = utils_transform::Add(HeadEntity, FTransform(FRotator::ZeroRotator, FakeHead), ECk_Replication::DoesNotReplicate);
        utils_eye_swarm::Add_Watched(Head);

        auto Pending = utils_entity_script::Request_SpawnEntity(InHandle, UMars_EyeSwarmRoster_EntityScript,
            UMars_EyeSwarmRoster_EntityScript::Params());
        utils_pending_entity_script::Promise_OnConstructed(
            Pending,
            FCk_Delegate_EntityScript_Constructed(this, n"OnRosterConstructed"));
    }

    UFUNCTION()
    private void OnRosterConstructed(FCk_Handle_EntityScript InEntityScriptHandle)
    {
        _RosterEntity = InEntityScriptHandle;
        _Roster = Cast<UMars_EyeSwarmRoster_EntityScript>(utils_entity_script::TryGet_EntityScript(_RosterEntity));
    }

    UFUNCTION()
    private void Check_RosterConstructed(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(ck::IsValid(_Roster));
    }

    UFUNCTION()
    private void Check_HeadWritten(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_FakeHeadSlot() != -1);
    }

    UFUNCTION()
    private void Step_AssertSlots(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        TArray<AMars_PlayerCharacter> Players;
        GetAllActorsOfClass(Players);
        const int32 NumPlayers = Players.Num();
        if (NumPlayers >= constants_eye_swarm::k_NumPlayerSlots)
        {
            FinishFailure(f"the test world has {NumPlayers} player characters: no slot is left for the stand-in head");
            return;
        }

        const auto Written = _Roster.Get_LastWritten();
        Assert_Equals_Int(Written.Num(), constants_eye_swarm::k_NumPlayerSlots, "the roster writes four slots");
        Assert_Equals_Int(Get_FakeHeadSlot(), NumPlayers, f"the stand-in head follows the {NumPlayers} player head(s)");

        for (int32 Slot = 0; Slot < NumPlayers && Slot < Written.Num(); ++Slot)
        { Assert_False(utils_eye_swarm::Get_IsAbsentHead(Written[Slot]), f"slot {Slot} holds a player head (got [{Written[Slot].ToString()}])"); }

        const auto Absent = utils_eye_swarm::Get_AbsentHead();
        for (int32 Slot = NumPlayers + 1; Slot < Written.Num(); ++Slot)
        { Assert_True(Written[Slot].Equals(Absent, 0.01), f"slot {Slot} is the sentinel (got [{Written[Slot].ToString()}])"); }
    }

    // The slot holding the stand-in head in the roster's last write, or -1.
    private int32 Get_FakeHeadSlot() const
    {
        if (ck::Is_NOT_Valid(_Roster))
        { return -1; }

        const auto Written = _Roster.Get_LastWritten();
        for (int32 Slot = 0; Slot < Written.Num(); ++Slot)
        {
            if (Written[Slot].Equals(FakeHead, 0.5))
            { return Slot; }
        }

        return -1;
    }
}
