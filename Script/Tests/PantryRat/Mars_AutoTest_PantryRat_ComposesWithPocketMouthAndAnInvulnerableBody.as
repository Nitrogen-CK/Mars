// Compose: the rat's entity script (no visuals: zero assets) composing utils_pantry_rat::Add on its root, with a raid and a
// den to belong to (composed by their own Add). The rat composes its
// SurfaceMotion body and navigator (agent radius 25), a monster whose 1-point Health is born invulnerable, a body zone with
// one hurtbox, the mouth node published as AttachPoint.Mars.RatMouth, and a capacity-1 pocket on a child entity whose
// lifetime owner is the rat (what the drain-time policy and the food's mount resolve). It starts Emerge, empty, FadeAlpha 1.
// The edge table refuses a loaded rat's return, den entry and fade, and any Advance into a kernel-only phase. Add compose
// test, and the table half of R23.
class UMars_AutoTest_PantryRat_ComposesWithPocketMouthAndAnInvulnerableBody : UCk_AutoTest_Base
{
    default _AutoStageOriginField = false;

    private const FVector k_Origin = FVector(620000.0, -200000.0, -60000.0);
    private FCk_Handle _RatEntity;
    private FCk_Handle_PantryRat _Rat;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto RaidOwner = utils_entity_lifetime::Request_CreateEntity(InHandle);
        utils_transform::Add(RaidOwner, FTransform(FRotator::ZeroRotator, k_Origin), ECk_Replication::DoesNotReplicate);
        auto Raid = utils_pantry_raid::Add(RaidOwner, FMars_PantryRaid_Spec());

        auto DenOwner = utils_entity_lifetime::Request_CreateEntity(InHandle);
        utils_transform::Add(DenOwner, FTransform(FRotator::ZeroRotator, k_Origin + FVector(-300.0, 0.0, 0.0)), ECk_Replication::DoesNotReplicate);
        auto Den = utils_rat_den::Add(DenOwner, FMars_RatDen_Spec(2));

        auto Spec = FMars_PantryRat_Spec();
        Spec.Links.Raid = Raid;
        Spec.Links.Den = Den;
        Spec.Links.ResidentSlot = 0;
        Spec.Links.OperationId = 1;
        Spec.Tuning = utils_pantry_raid::Make_RatTuning(FMars_PantryRaid_Spec());

        auto Params = UMars_PantryRat_EntityScript::Params();
        Params.SpawnTransform = FTransform(FRotator::ZeroRotator, k_Origin);
        Params.Spec = Spec;
        Params.WithVisuals = false;
        _RatEntity = utils_entity_script::Request_SpawnEntity(InHandle, UMars_PantryRat_EntityScript, Params).Get_EntityUnderConstruction();

        Add_Step_WaitUntil("the rat's entity script constructed it", n"Check_Constructed");
        Add_Step("every part composed", n"Step_AssertComposed");
        Add_Step("the edge table keeps a loaded rat fleeing", n"Step_AssertEdges");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Check_Constructed(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        _Rat = _RatEntity.As_PantryRat(ECk_SanityCheck::UnChecked);
        auto Result = OutResult;
        Result.Set(ck::IsValid(_Rat));
    }

    UFUNCTION()
    private void Step_AssertComposed(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Valid(_Rat, "the rat composed");
        Assert_True(_Rat.Get_Phase() == EMars_PantryRat_Phase::Emerge, "it starts Emerge");
        Assert_False(_Rat.Get_IsLoaded(), "empty");
        Assert_True(_Rat.Get_FadeAlpha() == 1.0f, "FadeAlpha starts solid (1)");

        const auto Pocket = _Rat.Get_Pocket();
        Assert_Valid(Pocket, "the pocket");
        Assert_Equals_Int(Pocket.Get_NumItems(), 0, "the pocket is empty");
        FCk_Handle RatEntity = _Rat;
        Assert_True(utils_entity_lifetime::Get_LifetimeOwner(Pocket) == RatEntity, "the pocket's lifetime owner is the rat");
        FCk_Handle PocketEntity = Pocket;
        Assert_False(PocketEntity == RatEntity, "the pocket is on its own child entity");

        const auto AttachPoints = RatEntity.As_AttachPoints(ECk_SanityCheck::UnChecked);
        Assert_True(ck::IsValid(AttachPoints) && AttachPoints.Has_AttachPoint(utils_pantry_rat::Get_MouthPoint()),
            "the rat publishes AttachPoint.Mars.RatMouth");

        auto Health = _Rat.Get_Monster().Get_BodyHealth();
        Assert_True(Health.Get_IsInvulnerable(), "the body Health is born invulnerable");
        Assert_True(Health.Get_Max() == 1.0f, "the body Health max is 1");
        Assert_Valid(_Rat.Get_Monster().Get_BodyZone(), "the body zone");

        Assert_True(_Rat.Get_Navigator().Get_Spec().AgentRadius == utils_pantry_rat::k_AgentRadius, "the navigator's agent radius");
        Assert_True(_Rat.Get_Navigator().Get_Speed() == _Rat.Get_Tuning().Speeds.Creep, "the navigator starts at creep speed");
    }

    UFUNCTION()
    private void Step_AssertEdges(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Loaded = true;
        Assert_False(utils_pantry_rat::Get_IsAllowedAdvance(EMars_PantryRat_Phase::FleeWithLoot, EMars_PantryRat_Phase::ReturnEmpty, Loaded),
            "FleeWithLoot -> ReturnEmpty refused");
        Assert_False(utils_pantry_rat::Get_IsAllowedAdvance(EMars_PantryRat_Phase::FleePause, EMars_PantryRat_Phase::DenEnter, Loaded),
            "FleePause -> DenEnter refused");
        Assert_False(utils_pantry_rat::Get_IsAllowedAdvance(EMars_PantryRat_Phase::FleeWithLoot, EMars_PantryRat_Phase::CorpseFade, Loaded),
            "a loaded fade refused");
        Assert_False(utils_pantry_rat::Get_IsAllowedAdvance(EMars_PantryRat_Phase::Observe, EMars_PantryRat_Phase::ReturnEmpty, Loaded),
            "a loaded rat in an empty phase still cannot return");
        Assert_True(utils_pantry_rat::Get_IsAllowedAdvance(EMars_PantryRat_Phase::FleeWithLoot, EMars_PantryRat_Phase::FleePause, Loaded),
            "FleeWithLoot -> FleePause allowed");
        Assert_False(utils_pantry_rat::Get_IsAllowedAdvance(EMars_PantryRat_Phase::Observe, EMars_PantryRat_Phase::FleeWithLoot, false),
            "an empty rat never flees with loot");
        Assert_False(utils_pantry_rat::Get_IsAllowedAdvance(EMars_PantryRat_Phase::ClaimTell, EMars_PantryRat_Phase::ClaimTransfer, false),
            "ClaimTransfer is entered only by the Claim request");
        Assert_False(utils_pantry_rat::Get_IsAllowedAdvance(EMars_PantryRat_Phase::Observe, EMars_PantryRat_Phase::DenEnter, false),
            "DenEnter only from ReturnEmpty");
        Assert_True(utils_pantry_rat::Get_IsAllowedAdvance(EMars_PantryRat_Phase::ReturnEmpty, EMars_PantryRat_Phase::DenEnter, false),
            "ReturnEmpty -> DenEnter allowed for an empty rat");
        Assert_False(utils_pantry_rat::Get_IsAllowedAdvance(EMars_PantryRat_Phase::DeadHold, EMars_PantryRat_Phase::Observe, false),
            "nothing leaves a death phase by Advance");
    }
}
