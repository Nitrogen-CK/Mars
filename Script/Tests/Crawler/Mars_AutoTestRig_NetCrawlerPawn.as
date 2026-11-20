// The crawler net rig plus one production pawn a client controls: each machine stands the pawn on a slab of its own
// (a plain static mesh actor does not replicate, and a pawn the client controls moves on the client's world); the
// server spawns the AMars_PlayerCharacter, hands it to the one player controller in its world that is not local and
// gives that controller its old pawn back at the end. Each machine finds its copy of the pawn near its spot, takes its
// entity, its Health and its zone, records the applied amount and the frame of every OnDamaged its Health raises and,
// off authority, the frame of every rep-notify of its Health's ledger. The crawler's own Health, zone and target stay
// the crawler rig's.
UCLASS(Abstract)
class UMars_AutoTestRig_NetCrawlerPawn : UMars_AutoTestRig_NetCrawler
{
    // A pawn is found within this of its spot.
    protected const float64 k_BlowPawnNearCm = 150.0;

    protected FVector _PawnAt = FVector::ZeroVector;
    protected AMars_PlayerCharacter _BlowPawn;
    protected FCk_Handle _BlowPlayer;
    protected FCk_Handle_Health _BlowHealth;
    protected FCk_Handle_HitZone _BlowZone;

    // The applied amount of every OnDamaged this machine's copy of the pawn raised, and the frame of the first (-1
    // before).
    protected TArray<float32> _BlowApplied;
    protected int32 _BlowDamagedFrame = -1;
    protected TArray<int32> _BlowNotifyFrames;
    // The first frame the server sampled its crawler's combat target as the pawn's entity; -1 before.
    protected int32 _BlowTargetFrame = -1;

    private AStaticMeshActor _BlowSlab;
    private bool _IsServerBlowPawn = false;
    private APlayerController _BlowRemoteController;
    private APawn _BlowRemotePreviousPawn;

    // Both machines: the crawler row at InBase, the pawn's spot at InPawnOffset from it and the slab under that spot.
    protected void Begin_CrawlerPawnRow(FVector InBase, FVector InPawnOffset)
    {
        Begin_CrawlerRow(InBase);
        _PawnAt = InBase + InPawnOffset;
        Spawn_BlowSlab();
    }

    protected UWorld Get_BlowWorld()
    {
        return utils_entity_lifetime::Get_WorldForEntity(Get_SubjectEntity());
    }

    // An engine cube scaled to a 20 m slab centred under the pawn's spot, its top face at the spot's Z.
    private void Spawn_BlowSlab()
    {
        const auto WorldContext = FAngelscriptGameThreadScopeWorldContext(Get_BlowWorld());
        auto Cube = Cast<UStaticMesh>(LoadObject(UStaticMesh, "/Engine/BasicShapes/Cube.Cube"));
        _BlowSlab = Cast<AStaticMeshActor>(SpawnActor(AStaticMeshActor, _PawnAt - FVector(0.0, 0.0, 50.0)));
        if (ck::Is_NOT_Valid(_BlowSlab) || ck::Is_NOT_Valid(Cube))
        {
            FinishFailure("the slab (the engine cube) did not spawn");
            return;
        }

        _BlowSlab.StaticMeshComponent.SetMobility(EComponentMobility::Movable);
        _BlowSlab.StaticMeshComponent.SetStaticMesh(Cube);
        _BlowSlab.SetActorScale3D(FVector(20.0, 20.0, 1.0));
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Server: the pawn and its controller
    //----------------------------------------------------------------------------------------------------------------------

    // The production pawn standing at its spot, facing +X, possessed by nobody.
    protected void Spawn_ServerBlowPawn()
    {
        const auto WorldContext = FAngelscriptGameThreadScopeWorldContext(Get_BlowWorld());
        const auto HalfHeight = float64(mars::Mars_PlayerCharacter_Config.Body.CapsuleHalfHeight);
        _BlowPawn = Cast<AMars_PlayerCharacter>(SpawnActor(AMars_PlayerCharacter, _PawnAt + FVector(0.0, 0.0, HalfHeight + 2.0), FRotator::ZeroRotator));
        _IsServerBlowPawn = ck::IsValid(_BlowPawn);
        if (_IsServerBlowPawn == false)
        { FinishFailure("AMars_PlayerCharacter did not spawn on the server"); }
    }

    // Hands the pawn to the one player controller in the server's world that is not local, found by a scan of the
    // world's player controllers. False (nothing possessed) without exactly one.
    protected bool Request_ServerPossessBlowPawn()
    {
        const auto WorldContext = FAngelscriptGameThreadScopeWorldContext(Get_BlowWorld());
        auto Controllers = TArray<AActor>();
        Gameplay::GetAllActorsOfClass(APlayerController, Controllers);

        APlayerController Remote;
        auto Count = 0;
        for (auto Actor : Controllers)
        {
            auto Controller = Cast<APlayerController>(Actor);
            if (ck::Is_NOT_Valid(Controller) || Controller.IsLocalController())
            { continue; }

            Remote = Controller;
            Count += 1;
        }

        if (Count != 1)
        { return false; }

        _BlowRemoteController = Remote;
        _BlowRemotePreviousPawn = Remote.GetControlledPawn();
        Remote.Possess(_BlowPawn);
        return true;
    }

    // The remote controller gets its old pawn back. Safe to call twice.
    protected void Request_ServerReturnRemote()
    {
        if (ck::Is_NOT_Valid(_BlowRemoteController))
        { return; }

        const auto Controlled = _BlowRemoteController.GetControlledPawn();
        if (ck::IsValid(Controlled) && Controlled == _BlowPawn)
        { _BlowRemoteController.UnPossess(); }

        if (ck::IsValid(_BlowRemotePreviousPawn) && _BlowRemoteController.GetControlledPawn() != _BlowRemotePreviousPawn)
        { _BlowRemoteController.Possess(_BlowRemotePreviousPawn); }

        _BlowRemoteController = nullptr;
    }

    // Returns the controller, destroys the pawn this machine spawned and this machine's slab. Safe to call twice.
    protected void TearDown_BlowPawn()
    {
        Request_ServerReturnRemote();
        if (_IsServerBlowPawn && ck::IsValid(_BlowPawn))
        { _BlowPawn.DestroyActor(); }

        if (ck::IsValid(_BlowSlab))
        { _BlowSlab.DestroyActor(); }

        _BlowSlab = nullptr;
        _IsServerBlowPawn = false;
    }

    UFUNCTION(BlueprintOverride)
    void DoEndPlay(FCk_Handle InHandle)
    {
        TearDown_BlowPawn();
    }

    // Server: the first frame its crawler's combat target is the pawn's entity.
    protected void Sample_BlowTarget()
    {
        if (_BlowTargetFrame >= 0 || Get_IsServer() == false || Get_IsCrawlerGone() || ck::Is_NOT_Valid(_BlowPlayer))
        { return; }

        if (_Crawler.Get_CombatTarget() == _BlowPlayer)
        { _BlowTargetFrame = int32(utils_time::Get_FrameCounter()); }
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Each machine: its copy of the pawn
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    protected void Is_BlowPawnComposed(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsBlowPawnComposed());
    }

    // This machine's copy of the pawn near its spot has composed its entity, its Health and its zone; the first time,
    // its Health's signals are recorded from here.
    protected bool Get_IsBlowPawnComposed()
    {
        if (ck::IsValid(_BlowHealth))
        { return true; }

        if (ck::Is_NOT_Valid(_BlowPawn))
        { _BlowPawn = DoFind_BlowPawn(); }

        if (ck::Is_NOT_Valid(_BlowPawn))
        { return false; }

        if (ck::Is_NOT_Valid(_BlowPlayer))
        { _BlowPlayer = _BlowPawn.Get_GameplayComposedEntity(); }

        if (ck::Is_NOT_Valid(_BlowPlayer))
        { return false; }

        auto Health = _BlowPlayer.As_Health(ECk_SanityCheck::UnChecked);
        auto Zone = _BlowPlayer.As_HitZone(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(Health) || ck::Is_NOT_Valid(Zone))
        { return false; }

        _BlowZone = Zone;
        _BlowHealth = Health;
        _BlowHealth.BindTo_OnDamaged(FMars_Delegate_Health_OnDamaged(this, n"OnBlowPawnDamaged"));
        if (Get_IsServer() == false)
        { _BlowPlayer.BindTo_OnRepNotify(FMars_Fragment_Health_Net, FCk_DynamicFragment_OnRepNotify(this, n"OnBlowPawnHealthNotify")); }

        return true;
    }

    // The AMars_PlayerCharacter in this machine's world nearest the pawn's spot, within k_BlowPawnNearCm; null without
    // one.
    private AMars_PlayerCharacter DoFind_BlowPawn()
    {
        const auto WorldContext = FAngelscriptGameThreadScopeWorldContext(Get_BlowWorld());
        auto Pawns = TArray<AActor>();
        Gameplay::GetAllActorsOfClass(AMars_PlayerCharacter, Pawns);

        AMars_PlayerCharacter Found;
        auto Nearest = k_BlowPawnNearCm;
        for (auto Actor : Pawns)
        {
            if (ck::Is_NOT_Valid(Actor))
            { continue; }

            const auto Distance = (Actor.GetActorLocation() - _PawnAt).Size();
            if (Distance >= Nearest)
            { continue; }

            Found = Cast<AMars_PlayerCharacter>(Actor);
            Nearest = Distance;
        }

        return Found;
    }

    protected bool Get_BlowPawnHasTag(FName InTag)
    {
        return ck::IsValid(_BlowPlayer) && utils_entity_tag::Has(_BlowPlayer, InTag);
    }

    protected FString Describe_BlowPawn()
    {
        auto Applied = FString();
        for (const auto& Amount : _BlowApplied)
        { Applied += f"{Amount},"; }

        const auto Current = ck::IsValid(_BlowHealth) ? _BlowHealth.Get_Current() : -1.0f;
        const auto HasAuthority = ck::IsValid(_BlowPlayer) && utils_net::Get_HasAuthority(_BlowPlayer);
        const auto IsLocal = ck::IsValid(_BlowPawn) && _BlowPawn.IsLocallyControlled();
        const auto HasShared = Get_BlowPawnHasTag(n"TAG_MarsSharedCombatTarget");
        const auto HasLocal = Get_BlowPawnHasTag(n"TAG_MarsCombatTarget");
        return f"pawn=[health {Current} damaged {_BlowApplied.Num()} applied {Applied} damagedFrame {_BlowDamagedFrame} "
            + f"shared {HasShared} local {HasLocal} authority {HasAuthority} locallyControlled {IsLocal} "
            + f"targetFrame {_BlowTargetFrame} notifies {_BlowNotifyFrames.Num()}]";
    }

    UFUNCTION()
    private void OnBlowPawnDamaged(FCk_Handle_Health InHealth, FMars_DamageEvent InEvent, float32 InApplied, float32 InRemaining)
    {
        _BlowApplied.Add(InApplied);
        if (_BlowDamagedFrame < 0)
        { _BlowDamagedFrame = int32(utils_time::Get_FrameCounter()); }
    }

    // A notify can land on a pawn already ending.
    UFUNCTION()
    private void OnBlowPawnHealthNotify(FCk_Handle InHandle, FCk_DynamicFragment_RepNotifyInfo InInfo)
    {
        if (ck::Is_NOT_Valid(InHandle) || InHandle.Has_Fragment(FMars_Fragment_Health_Net) == false)
        { return; }

        _BlowNotifyFrames.Add(int32(utils_time::Get_FrameCounter()));
    }
}
