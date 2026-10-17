// Anchors, the resolver driver and the candidates in the shared AutoTest world. Every spawn is owned by the test's own
// handle, so the anchors, their candidates and the resolver die with the test (a leaked resolver would resolve the
// next test's anchors). Isolated Z band: -82000. Test candidates carry tags no other test uses.

// Two inert candidates: a transform and a private tag.
class UMars_TESTONLY_AnchorCandidateA_EntityScript : UCk_GenericEntityScript_UE
{
    default _Replication = ECk_Replication::DoesNotReplicate;

    UPROPERTY(ExposeOnSpawn)
    FTransform SpawnTransform = FTransform::Identity;

    UPROPERTY(ExposeOnSpawn)
    FMars_Anchor_Context Anchor;

    UFUNCTION(BlueprintOverride)
    ECk_EntityScript_ConstructionFlow DoConstruct(FCk_Handle& InHandle)
    {
        utils_transform::Add(InHandle, SpawnTransform, ECk_Replication::DoesNotReplicate);
        utils_entity_tag::Add(InHandle, n"TAG_MarsTestAnchorCandidateA");
        return ECk_EntityScript_ConstructionFlow::Finished;
    }
}

class UMars_TESTONLY_AnchorCandidateB_EntityScript : UCk_GenericEntityScript_UE
{
    default _Replication = ECk_Replication::DoesNotReplicate;

    UPROPERTY(ExposeOnSpawn)
    FTransform SpawnTransform = FTransform::Identity;

    UPROPERTY(ExposeOnSpawn)
    FMars_Anchor_Context Anchor;

    UFUNCTION(BlueprintOverride)
    ECk_EntityScript_ConstructionFlow DoConstruct(FCk_Handle& InHandle)
    {
        utils_transform::Add(InHandle, SpawnTransform, ECk_Replication::DoesNotReplicate);
        utils_entity_tag::Add(InHandle, n"TAG_MarsTestAnchorCandidateB");
        return ECk_EntityScript_ConstructionFlow::Finished;
    }
}

// Row 0 A (Open), row 1 B (Closed), row 2 Nothing (Open), row 3 A (Other).
asset Mars_AnchorTable_Test of UMars_AnchorTable_Def
{
    Family = EMars_Anchor_Family::Route;
    Rows.Add(FMars_AnchorTable_Row(UMars_TESTONLY_AnchorCandidateA_EntityScript, 1.0f, EMars_Anchor_Role::Open));
    Rows.Add(FMars_AnchorTable_Row(UMars_TESTONLY_AnchorCandidateB_EntityScript, 1.0f, EMars_Anchor_Role::Closed));
    Rows.Add(FMars_AnchorTable_Row(TSubclassOf<UCk_EntityScript_UE>(), 1.0f, EMars_Anchor_Role::Open));
    Rows.Add(FMars_AnchorTable_Row(UMars_TESTONLY_AnchorCandidateA_EntityScript, 1.0f, EMars_Anchor_Role::Other));
}

namespace utils_anchor
{
    UMars_AnchorTable_Def Table_Test()
    { return Mars_AnchorTable_Test; }
}

class UMars_TESTONLY_Anchor_EntityScript : UMars_Anchor_EntityScript
{
    default Channel = GameplayTags::ResolveGameplayTag(n"Mechanism.Channel.Anchor.Test.A");

    protected UMars_AnchorTable_Def Get_Table() const override
    { return utils_anchor::Table_Test(); }
}

// What the test anchor is spawned with; injection matches by property name.
struct FMars_TESTONLY_AnchorSpawnParams
{
    UPROPERTY()
    FTransform SpawnTransform;

    UPROPERTY()
    FName AnchorId;

    // Unique per placement (the resolver ensures on a shared one); Spawn_Anchor defaults it to Test.A.
    UPROPERTY()
    FGameplayTag Channel;

    UPROPERTY()
    TOptional<int32> PinnedRow;
}

UCLASS(Abstract)
class UMars_AutoTestRig_Anchor : UCk_AutoTest_Base
{
    default _AutoStageOriginField = false;

    protected FVector _Base = FVector(0.0, 0.0, -82000.0);

    protected FCk_Handle Spawn_Anchor(FCk_Handle InHandle, FName InId, FVector InOffset, TOptional<int32> InPinnedRow)
    {
        auto Params = FMars_TESTONLY_AnchorSpawnParams();
        Params.SpawnTransform = FTransform(FRotator::ZeroRotator, _Base + InOffset);
        Params.AnchorId = InId;
        Params.Channel = GameplayTags::ResolveGameplayTag(n"Mechanism.Channel.Anchor.Test.A");
        Params.PinnedRow = InPinnedRow;
        return Spawn_Anchor(InHandle, Params);
    }

    protected FCk_Handle Spawn_Anchor(FCk_Handle InHandle, const FMars_TESTONLY_AnchorSpawnParams& InParams)
    {
        auto Pending = utils_entity_script::Request_SpawnEntity(InHandle, UMars_TESTONLY_Anchor_EntityScript, InParams);
        return Pending.Get_EntityUnderConstruction();
    }

    protected FCk_Handle Spawn_Resolver(FCk_Handle InHandle, const FMars_AnchorRun_Result& InResult)
    {
        auto Pending = utils_entity_script::Request_SpawnEntity(
            InHandle, UMars_AnchorResolver_EntityScript, FMars_AnchorResolver_SpawnParams(InResult));
        return Pending.Get_EntityUnderConstruction();
    }

    protected FCk_Handle Spawn_Candidate(FCk_Handle InHandle, TSubclassOf<UCk_EntityScript_UE> InClass, FMars_Anchor_Context InContext)
    {
        auto Params = FMars_Anchor_SpawnParams(FTransform(FRotator::ZeroRotator, _Base), InContext);
        auto Pending = utils_entity_script::Request_SpawnEntity(InHandle, InClass, Params);
        return Pending.Get_EntityUnderConstruction();
    }

    // T-A Open, T-B Closed, T-C Other.
    protected FMars_AnchorRun_Result Make_Result(int32 InSeed) const
    {
        auto Result = FMars_AnchorRun_Result();
        Result.Seed = InSeed;
        Result.Roles.Add(FMars_AnchorRun_RoleEntry(n"T-A", EMars_Anchor_Role::Open));
        Result.Roles.Add(FMars_AnchorRun_RoleEntry(n"T-B", EMars_Anchor_Role::Closed));
        Result.Roles.Add(FMars_AnchorRun_RoleEntry(n"T-C", EMars_Anchor_Role::Other));
        return Result;
    }

    protected bool Get_IsAnchorReady(FCk_Handle InEntity) const
    { return ck::IsValid(InEntity) && InEntity.Has_Fragment(FMars_Feature_Anchor); }

    protected bool Get_IsResolverReady(FCk_Handle InEntity) const
    { return ck::IsValid(InEntity) && InEntity.Has_Fragment(FMars_Feature_AnchorResolver); }

    protected bool Get_IsSpawned(FCk_Handle InEntity) const
    { return Get_IsAnchorReady(InEntity) && InEntity.As_Anchor().Get_State() == EMars_Anchor_State::Spawned; }

    protected int32 Count_Tagged(FCk_Handle InAny, FName InTag) const
    { return utils_entity_tag::ForEach_Entity(InAny, InTag).Num(); }

    // Tagged entities whose lifetime owner is InOwner: the ones a candidate spawned.
    protected TArray<FCk_Handle> Get_OwnedTagged(FCk_Handle InOwner, FName InTag) const
    {
        auto Owned = TArray<FCk_Handle>();
        for (auto Entity : utils_entity_tag::ForEach_Entity(InOwner, InTag))
        {
            if (ck::IsValid(Entity) && Entity.Get_LifetimeOwner() == InOwner)
            { Owned.Add(Entity); }
        }
        return Owned;
    }
}
