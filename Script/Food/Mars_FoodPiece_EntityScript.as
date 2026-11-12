// A cut piece of a food that replicates: one half of a cut the authority made (utils_foodpiece::Request_SpawnCutPiece).
// Every machine composes its root transform and its entity tag and resolves its food from the recipe's definition id. The
// authority's copy carries its birth (the slice's geometry and the half's spec) and composes the FoodPiece from it, then
// dresses it. A copy without one asks for its recipe to be rebuilt (utils_foodpiece::Request_Replay) and continues its
// construction until the replay resolves: Built composes the FoodPiece on the shared geometry, which arrives and is dressed
// (wearing the authority's cook state) only once it stands, and takes off what it wears once a piece cut from it stands;
// Failed finishes it as a non-piece that shows the food's mesh fitted to the authority's bounds (a stand-in) once the
// ledger brings them.
//
// Stance REPLICATES from the replicated spawn owner: the spawn data is the recipe, the identity and the mass, and the root
// transform replicates; the authority shares the cut's geometry, a client rebuilds its own from the recipe. Only the
// authority's piece has a body (none is added here). Not a world item, so it has no pickup. A client shows a piece only
// while it stands (its standing is local, ruled by the Succession processor).
class UMars_FoodPiece_EntityScript : UCk_GenericEntityScript_UE
{
    // Stance REPLICATES: from the spawn owner; spawn data is the recipe, the identity and the mass.
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

    private UMars_Food_Def _Food;
    private FCk_Handle _Entity;
    private FCk_Handle_FoodPiece _Piece;
    // A failed replay's wait for the authority's bounds.
    private FCk_Handle_Timer _StandInWait;

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

        // The authority's piece is born of a cut: one spawned any other way has no geometry to share, and the authority
        // rebuilds nothing.
        if (ck::EnsureIfNot(utils_net::Get_HasAuthority(InHandle) == false,
            f"[FoodPiece] [{InHandle.ToString()}] is a piece script with authority and no birth: spawn it through utils_foodpiece::Request_SpawnCutPiece"))
        {
            utils_entity_lifetime::Request_DestroyEntity(InHandle);
            return ECk_EntityScript_ConstructionFlow::Finished;
        }

        _Food = Food;
        _Entity = InHandle;
        utils_foodpiece::Request_Replay(InHandle, Make_ReplaySpec(Food));
        utils_foodpiece::BindTo_OnReplayResolved(InHandle, FMars_Delegate_FoodPiece_OnReplayResolved(this, n"OnReplayResolved"));
        return ECk_EntityScript_ConstructionFlow::Continue;
    }

    UFUNCTION(BlueprintOverride)
    void DoEndPlay(FCk_Handle InHandle)
    {
        if (ck::IsValid(_Entity))
        { utils_foodpiece::UnbindFrom_OnReplayResolved(_Entity, FMars_Delegate_FoodPiece_OnReplayResolved(this, n"OnReplayResolved")); }

        if (ck::IsValid(_Piece))
        {
            _Piece.UnbindFrom_OnCookStateChanged(FMars_Delegate_FoodPiece_OnCookStateChanged(this, n"OnPieceCookStateChanged"));
            _Piece.UnbindFrom_OnStandingChanged(FMars_Delegate_FoodPiece_OnStandingChanged(this, n"OnPieceStandingChanged"));
        }

        End_StandInWait();
        _Entity = FCk_Handle();
        _Piece = FCk_Handle_FoodPiece();
    }

    // Built: the rebuilt geometry is shared onto the entity, so the piece is Ready at once; it arrives, and is dressed only
    // once it stands (OnStandingChanged). Failed already logged (the Replay processor): the entity stays a non-piece and
    // shows a stand-in once the authority's ledger brings its bounds.
    UFUNCTION()
    private void OnReplayResolved(FCk_Handle InEntity, EMars_FoodPiece_ReplayState InState)
    {
        if (InState != EMars_FoodPiece_ReplayState::Built)
        {
            _StandInWait = utils_timer::Create_Tick(_Entity, FCk_Delegate_Timer(this, n"OnWaitForBounds"));
            DoFinishConstruction();
            return;
        }

        auto Entity = InEntity;
        const auto Replay = utils_foodpiece::TryGet_Replay(Entity);
        // A rejected spec already ensured (Add).
        _Piece = ck::IsValid(_Food) && Replay.IsSet() ? utils_foodpiece::Add(Entity, Replay.GetValue().Piece) : FCk_Handle_FoodPiece();
        if (ck::Is_NOT_Valid(_Piece))
        {
            utils_entity_lifetime::Request_DestroyEntity(Entity);
            return;
        }

        _Piece.BindTo_OnCookStateChanged(FMars_Delegate_FoodPiece_OnCookStateChanged(this, n"OnPieceCookStateChanged"));
        _Piece.BindTo_OnStandingChanged(FMars_Delegate_FoodPiece_OnStandingChanged(this, n"OnPieceStandingChanged"));
        DoFinishConstruction();
    }

    // Current: the piece is dressed. Superseded: it takes off what it wears (nothing, if it never stood).
    UFUNCTION()
    private void OnPieceStandingChanged(FCk_Handle_FoodPiece InPiece, EMars_FoodPiece_Standing InStanding)
    {
        if (InStanding == EMars_FoodPiece_Standing::Current)
        {
            _Food.Add_Display(InPiece);
            return;
        }

        if (InStanding == EMars_FoodPiece_Standing::Superseded)
        { InPiece.Hide_Worn(); }
    }

    // A failed replay's entity: once the authority's piece has recorded its bounds, the food's mesh stands in for it.
    UFUNCTION()
    private void OnWaitForBounds(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Ledger = utils_foodpiece::TryGet_Ledger(_Entity);
        if (Ledger.IsSet() == false || Ledger.GetValue().Check != EMars_FoodPiece_Check::Recorded)
        { return; }

        End_StandInWait();
        utils_food::Add_StandIn(_Entity, _Food, FBox(Ledger.GetValue().CheckBoundsMinCm, Ledger.GetValue().CheckBoundsMaxCm));
    }

    private void End_StandInWait()
    {
        if (ck::Is_NOT_Valid(_StandInWait))
        { return; }

        utils_timer::UnbindFrom_OnUpdate(_StandInWait, FCk_Delegate_Timer(this, n"OnWaitForBounds"));
        utils_entity_lifetime::Request_DestroyEntity(_StandInWait.H());
        _StandInWait = FCk_Handle_Timer();
    }

    // A copy without authority wears the cook state the authority's ledger brought; a piece not dressed yet starts from it
    // when it is.
    UFUNCTION()
    private void OnPieceCookStateChanged(FCk_Handle_FoodPiece InPiece)
    {
        InPiece.Write_Look(utils_cookstate::Make_DisplayParams(InPiece.Get_CookState()));
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
