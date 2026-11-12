// A cut piece of a food that replicates: one half of a cut the authority made (utils_foodpiece::Request_SpawnCutPiece).
// Every machine composes its root transform and its entity tag and resolves its food from the recipe's definition id. The
// authority's copy carries its birth (the slice's geometry and the half's spec) and composes the FoodPiece from it, then
// dresses it; a copy without one keeps what rebuilding it needs (utils_foodpiece::Request_Replay) and is not a FoodPiece.
//
// Stance REPLICATES from the replicated spawn owner: the spawn data is the recipe, the identity and the mass, and the root
// transform replicates; the authority shares the cut's geometry, a client builds its own. Not a world item, so it has no
// pickup.
class UMars_FoodPiece_EntityScript : UCk_GenericEntityScript_UE
{
    // Replicates from the spawn owner; spawn data is the recipe, the identity and the mass.
    default _Replication = ECk_Replication::Replicates;

    UPROPERTY(ExposeOnSpawn)
    FTransform SpawnTransform;

    // The food definition's wire id (utils_food::Find_Definition).
    UPROPERTY(ExposeOnSpawn, meta = (Categories = "FoodDef.Mars"))
    FGameplayTag Definition;

    // Every cut of the piece's lineage, root first, in the definition mesh's frame.
    UPROPERTY(ExposeOnSpawn)
    TArray<FMars_FoodPiece_RecipeCut> Cuts;

    UPROPERTY(ExposeOnSpawn)
    FGuid Id;

    UPROPERTY(ExposeOnSpawn)
    FGuid ParentId;

    UPROPERTY(ExposeOnSpawn)
    FGuid Lineage;

    UPROPERTY(ExposeOnSpawn)
    float MassKg = 0.0;

    UFUNCTION(BlueprintOverride)
    ECk_EntityScript_ConstructionFlow DoConstruct(FCk_Handle& InHandle)
    {
        utils_transform::Add(InHandle, SpawnTransform, ECk_Replication::Replicates);

        // A machine without authority that parents this root locally keeps that parent, and the authority's pose applies
        // again when it lets go.
        auto Root = InHandle.As_Transform(ECk_SanityCheck::UnChecked);
        utils_transform::Request_SetReplicatedPosePolicy(Root, ECk_Transform_ReplicatedPosePolicy::YieldsToSceneNodeParent);

        utils_entity_tag::Add(InHandle, n"TAG_MarsFoodPiece");

        UMars_Food_Def Food = utils_food::Find_Definition(Definition);
        if (ck::EnsureIfNot(ck::IsValid(Food), f"[FoodPiece] [{InHandle.ToString()}] names no known food definition [{Definition.ToString()}]"))
        {
            utils_entity_lifetime::Request_DestroyEntity(InHandle);
            return ECk_EntityScript_ConstructionFlow::Finished;
        }

        if (utils_foodpiece::Get_IsBorn(InHandle))
        {
            const auto Piece = utils_foodpiece::Add_Born(InHandle);
            if (ck::Is_NOT_Valid(Piece))
            {
                utils_entity_lifetime::Request_DestroyEntity(InHandle);
                return ECk_EntityScript_ConstructionFlow::Finished;
            }

            Food.Add_Display(Piece);
            return ECk_EntityScript_ConstructionFlow::Finished;
        }

        utils_foodpiece::Request_Replay(InHandle, Make_ReplaySpec(Food));
        return ECk_EntityScript_ConstructionFlow::Finished;
    }

    // The piece the spawn data and the food give: its identity, lineage, mass and recipe, and the food's kind, tuners, cap
    // and body surface; the mesh the recipe replays on.
    private FMars_FoodPiece_ReplaySpec Make_ReplaySpec(UMars_Food_Def InFood) const
    {
        auto Data = FMars_FoodPiece_Data(MassKg);
        Data.Id = Id;
        Data.ParentId = ParentId;
        Data.Lineage = Lineage;
        Data.Recipe.Definition = Definition;
        Data.Recipe.Cuts = Cuts;
        Data.Definition = TWeakObjectPtr<UMars_Food_Def>(InFood);
        Data.Kind = InFood.Data.Kind;

        auto Spec = FMars_FoodPiece_ReplaySpec();
        Spec.Piece = FMars_FoodPiece_Spec(Data, InFood.Tuners, InFood.Visuals.Cap, InFood.Body);
        Spec.Mesh = InFood.Data.Mesh;
        return Spec;
    }
}
