// One piece of a severed limb as its host drew it: where it sits relative to the limb's root, the half extents it is
// drawn at, and what it wears (an unset mesh is a box of the half extents tinted Color).
struct FMars_SeveredLimb_Piece
{
    UPROPERTY()
    FTransform Offset = FTransform::Identity;

    UPROPERTY()
    FVector HalfExtents = FVector::ZeroVector;

    UPROPERTY()
    TSoftObjectPtr<UStaticMesh> Mesh;

    UPROPERTY()
    FLinearColor Color = FLinearColor(1.0f, 1.0f, 1.0f, 1.0f);
}

// A severed leg as one limb (utils_severed_limb). The entity, its root and the pose ledger replicate; the bodies, the
// joints and the despawn timer are the authority's; a copy poses its pieces from the ledger and simulates nothing.
// This script owns what is seen: each piece's ISM proxy, the piece's look mesh at its authored size or an engine-cube
// box of its half extents, Material replacing slot 0 of a look mesh.
class UMars_SeveredLimb_EntityScript : UCk_GenericEntityScript_UE
{
    // Spawned once by the authority under the replicated spawn owner; every machine builds its own pieces and visuals.
    default _Replication = ECk_Replication::Replicates;
    default _ShowInPlaceActors = false;

    // The cut: the first piece's world transform when the leg was severed. The root stays here.
    UPROPERTY(ExposeOnSpawn)
    FTransform SpawnTransform = FTransform::Identity;

    // In chain order, the foot last.
    UPROPERTY(ExposeOnSpawn)
    TArray<FMars_SeveredLimb_Piece> Pieces;

    UPROPERTY(ExposeOnSpawn)
    TSoftObjectPtr<UMaterialInterface> Material;

    UPROPERTY(ExposeOnSpawn)
    FMars_BodyPart_Debris Debris;

    UPROPERTY(ExposeOnSpawn)
    FVector LaunchVelocity = FVector::ZeroVector;

    // False builds the same pieces with no ISM visuals (headless autotests).
    UPROPERTY(ExposeOnSpawn)
    bool WithVisuals = true;

    private UMaterialInterface _Material;
    // Created on first use of each look mesh and tint.
    private FMars_Crawler_PieceRenderers _PieceRenderers;

    UFUNCTION(BlueprintOverride)
    ECk_EntityScript_ConstructionFlow DoConstruct(FCk_Handle& InHandle)
    {
        utils_handle::Set_DebugName(InHandle, n"SeveredLimb");
        utils_transform::Add(InHandle, SpawnTransform, ECk_Replication::Replicates);
        utils_entity_tag::Add(InHandle, n"TAG_MarsSeveredLimb");

        if (WithVisuals && Material.IsNull() == false)
        { _Material = System::LoadAsset_Blocking(Material); }

        auto Spec = FMars_SeveredLimb_Spec();
        Spec.Debris = Debris;
        Spec.LaunchVelocity = LaunchVelocity;
        for (const auto& Piece : Pieces)
        { Spec.Pieces.Add(FMars_SeveredLimb_PieceSpec(AddPiece(InHandle, Piece), Piece.HalfExtents)); }

        const auto HasAuthority = utils_net::Get_HasAuthority(InHandle);
        const auto Limb = utils_severed_limb::Add(InHandle, Spec);
        if (ck::Is_NOT_Valid(Limb))
        {
            if (HasAuthority)
            { utils_entity_lifetime::Request_DestroyEntity(InHandle); }

            return ECk_EntityScript_ConstructionFlow::Finished;
        }

        // The timer dies with the entity; nothing to unbind.
        if (HasAuthority)
        { utils_monster::Add_DespawnTimer(InHandle, Debris.LifetimeSeconds, FCk_Delegate_Timer(this, n"OnLifetimeEnded")); }

        return ECk_EntityScript_ConstructionFlow::Finished;
    }

    UFUNCTION()
    private void OnLifetimeEnded(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        utils_monster::Request_DestroyTimerOwner(InTimer);
    }

    // A lifetime child of InRoot at its offset from the cut, with its ISM proxy when there are visuals.
    private FCk_Handle_Transform AddPiece(FCk_Handle& InRoot, const FMars_SeveredLimb_Piece& InPiece)
    {
        auto Entity = utils_entity_lifetime::Request_CreateEntity(InRoot);
        utils_handle::Set_DebugName(Entity, n"SeveredLimb.Piece");
        auto Transform = utils_transform::Add(Entity, InPiece.Offset * SpawnTransform, ECk_Replication::DoesNotReplicate);
        if (WithVisuals == false)
        { return Transform; }

        UStaticMesh Mesh = nullptr;
        if (InPiece.Mesh.IsNull() == false)
        { Mesh = System::LoadAsset_Blocking(InPiece.Mesh); }

        const auto WearsMesh = ck::IsValid(Mesh);
        auto Renderer = WearsMesh ? _PieceRenderers.GetOrCreate_ForMesh(InRoot, Mesh, _Material) : _PieceRenderers.GetOrCreate_ForTint(InRoot, InPiece.Color);
        if (ck::IsValid(Renderer))
        {
            auto ProxySpec = FCk_IsmProxy_Spec(Renderer);
            // Engine cube: 100 uu side, 50 uu half extent.
            ProxySpec.Set_ScaleMultiplier(WearsMesh ? FVector::OneVector : InPiece.HalfExtents / 50.0);
            utils_ism_proxy::Add(Transform, ProxySpec);
        }

        return Transform;
    }
}
