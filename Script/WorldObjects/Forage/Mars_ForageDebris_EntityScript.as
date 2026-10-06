// One static piece of debris: a mesh part at SpawnTransform that destroys itself after LifetimeSeconds.
class UMars_ForageDebris_EntityScript : UCk_GenericEntityScript_UE
{
    default _Replication = ECk_Replication::DoesNotReplicate;
    default _ShowInPlaceActors = false;

    UPROPERTY(ExposeOnSpawn)
    FTransform SpawnTransform = FTransform::Identity;

    UPROPERTY(ExposeOnSpawn)
    TSoftObjectPtr<UStaticMesh> Mesh;

    // Unset keeps the mesh's own material.
    UPROPERTY(ExposeOnSpawn)
    TSoftObjectPtr<UMaterialInterface> Material;

    UPROPERTY(ExposeOnSpawn)
    FVector Scale = FVector(0.2, 0.2, 0.1);

    UPROPERTY(ExposeOnSpawn)
    float32 LifetimeSeconds = 8.0f;

    private FCk_Handle _SelfEntity;

    UFUNCTION(BlueprintOverride)
    ECk_EntityScript_ConstructionFlow DoConstruct(FCk_Handle& InHandle)
    {
        _SelfEntity = InHandle;

        auto Root = utils_transform::Add(InHandle, SpawnTransform, ECk_Replication::DoesNotReplicate);
        utils_entity_tag::Add(InHandle, n"TAG_MarsForageDebris");

        UMaterialInterface LoadedMaterial = nullptr;
        if (Material.IsNull() == false)
        { LoadedMaterial = System::LoadAsset_Blocking(Material); }

        Root.Add_MeshPart(this, FMars_MeshPart(FTransform(FRotator::ZeroRotator, FVector::ZeroVector, Scale),
            System::LoadAsset_Blocking(Mesh), LoadedMaterial, collision::profile::NoCollision, n"ForageDebris"));

        auto TimerSpec = FCk_Timer_Spec(FCk_Time(LifetimeSeconds));
        TimerSpec.Set_StartingState(ECk_Timer_State::Running)
                 .Set_Behavior(ECk_Timer_Behavior::StopOnDone);

        auto Timer = utils_timer::Add(InHandle, TimerSpec);
        if (ck::IsValid(Timer))
        { Timer.BindTo_OnDone(FCk_Delegate_Timer(this, n"OnLifetimeDone")); }

        return ECk_EntityScript_ConstructionFlow::Finished;
    }

    UFUNCTION()
    private void OnLifetimeDone(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        utils_entity_lifetime::Request_DestroyEntity(_SelfEntity);
    }
}
