// The Platter net tests' shared steps, on the food net rig. Both machines compose a carrier on the subject (one bag slot; the
// client's hand node stands 60 cm apart in Y from the server's, so only a local mount puts a carried platter at it). The
// server lays the floor at the test's X, spawns a large platter on it under the replicated spawn owner and foods 150 cm
// beside it, loads them once they are Ready and waits until the pile has frozen. What the client compares against goes out
// in one test-only replicated report on the subject: each frozen piece's id and its offset under the platter root as the
// server reads it. Each machine finds its own copy of the platter (a platter world item near the test's X) and records
// every signal that copy raises. One [PlatterNetTest] line per test per machine; ensures are 0 on both.

// One frozen piece as the server reads it.
struct FMars_TESTONLY_NetPlatterSlot
{
    UPROPERTY()
    FGuid Id;

    UPROPERTY()
    FVector RideLocation = FVector::ZeroVector;

    // Pitch, yaw, roll in degrees.
    UPROPERTY()
    FVector RideEuler = FVector::ZeroVector;
}

// Written by the server only, through Get_Fragment + Request_MarkReplicationDirty (test-only: a feature's processors are
// the only writers in game code).
struct FMars_Fragment_TESTONLY_NetPlatterReport
{
    UPROPERTY()
    int32 Serial = 0;

    UPROPERTY()
    int32 Step = 0;

    // How many of the slots are filled.
    UPROPERTY()
    int32 Count = 0;

    UPROPERTY()
    FMars_TESTONLY_NetPlatterSlot Slot0;

    UPROPERTY()
    FMars_TESTONLY_NetPlatterSlot Slot1;

    UPROPERTY()
    FMars_TESTONLY_NetPlatterSlot Slot2;

    UPROPERTY()
    FMars_TESTONLY_NetPlatterSlot Slot3;

    // A world location a step reports besides the rides.
    UPROPERTY()
    FVector Location = FVector::ZeroVector;
}

UCLASS(Abstract)
class UMars_AutoTestRig_NetPlatter : UMars_AutoTestRig_NetFoodPiece
{
    default _TimeoutSeconds = 25.0f;

    protected const float64 k_BesideCm = 150.0;
    protected const float64 k_HandApartCm = 60.0;
    protected const float64 k_RideToleranceCm = 0.01;
    protected const float64 k_RideToleranceDegrees = 0.01;
    protected const float64 k_CarriedToleranceCm = 0.05;
    protected const float64 k_HandPoseToleranceCm = 2.0;
    // The client asserts this long after a step arrived.
    protected const float32 k_ClientSettleSeconds = 1.0f;
    // The server holds this long after its last step before it ends, so the client asserts on a live pile.
    protected const float32 k_ServerOutliveSeconds = 3.0f;
    protected const int32 k_SlotCount = 4;

    protected FMars_TESTONLY_NetCarrier _Carrier;
    // Server: the platter world item it spawned.
    protected FCk_Handle _PlatterEntity;
    // This machine's copy of the platter, once found.
    protected FCk_Handle_Platter _Platter;

    // Every signal this machine's copy raised since it was found.
    protected int32 _Loaded = 0;
    protected int32 _Accepted = 0;
    protected int32 _Refused = 0;
    protected int32 _Unloaded = 0;

    // Set by the last Get_RideFault that reached the offset.
    protected float64 _RideErrorCm = -1.0;
    protected float64 _RideErrorDegrees = -1.0;

    // Client: the frame of its last Deposit.
    protected int64 _DepositFrame = -1;

    private FCk_Handle _LoadFood;
    private FCk_Handle _AwaitedFood;
    private int32 _FrozenHeld = 0;
    private int32 _FrozenLoaded = 0;
    private int32 _AwaitedStep = 0;
    private FString _EndText;

    // Call first, on both machines.
    protected void Begin_PlatterRig(FCk_Handle InTestEntity, float64 InX)
    {
        Begin_Rig(InX);
        Add_PlatterReport();

        const auto HandApart = Get_IsServer() ? FVector::ZeroVector : FVector(0.0, k_HandApartCm, 0.0);
        _Carrier = Compose_Carrier(_FloorTop + FVector(-200.0, 0.0, 100.0) + HandApart, 1);

        if (Get_IsServer() == false)
        { return; }

        Begin_ServerFloor(InTestEntity);
        WaitUntil(n"Is_ReplicatedSpawnOwnerPublished", n"OnRigPlatterOwnerPublished", k_SlowPolls);
    }

    protected void Log_Platter(FString InText)
    {
        const auto Machine = Get_MachineName();
        const auto TestName = GetClass().GetName();
        const auto Ensures = Get_EnsureDelta();
        Log(f"[PlatterNetTest] {TestName} {Machine}: {InText} ensures={Ensures}");
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Report
    //----------------------------------------------------------------------------------------------------------------------

    protected void Add_PlatterReport()
    {
        auto Subject = Get_SubjectEntity();
        if (Subject.Has_Fragment(FMars_Fragment_TESTONLY_NetPlatterReport) == false)
        { Subject.Add_Fragment(FMars_Fragment_TESTONLY_NetPlatterReport(), ECk_Replication::Replicates); }
    }

    protected FMars_Fragment_TESTONLY_NetPlatterReport Get_PlatterReport()
    {
        return Get_SubjectEntity().Get_Fragment(FMars_Fragment_TESTONLY_NetPlatterReport);
    }

    // InReport with the next serial, published.
    protected void Write_PlatterReport(FMars_Fragment_TESTONLY_NetPlatterReport InReport)
    {
        auto Subject = Get_SubjectEntity();
        auto& Report = Subject.Get_Fragment(FMars_Fragment_TESTONLY_NetPlatterReport);
        const auto Serial = Report.Serial;
        Report = InReport;
        Report.Serial = Serial + 1;
        Subject.Request_MarkReplicationDirty(FMars_Fragment_TESTONLY_NetPlatterReport);
    }

    protected FMars_TESTONLY_NetPlatterSlot Get_Slot(FMars_Fragment_TESTONLY_NetPlatterReport InReport, int32 InIndex)
    {
        if (InIndex == 0)
        { return InReport.Slot0; }

        if (InIndex == 1)
        { return InReport.Slot1; }

        if (InIndex == 2)
        { return InReport.Slot2; }

        return InReport.Slot3;
    }

    protected void Set_Slot(FMars_Fragment_TESTONLY_NetPlatterReport& InOutReport, int32 InIndex, FMars_TESTONLY_NetPlatterSlot InSlot)
    {
        if (InIndex == 0)
        { InOutReport.Slot0 = InSlot; }
        else if (InIndex == 1)
        { InOutReport.Slot1 = InSlot; }
        else if (InIndex == 2)
        { InOutReport.Slot2 = InSlot; }
        else
        { InOutReport.Slot3 = InSlot; }
    }

    // InPiece's id and its offset under its scene-node parent, as this machine reads them.
    protected FMars_TESTONLY_NetPlatterSlot Make_Slot(FCk_Handle_FoodPiece InPiece, FTransform InOffset)
    {
        auto Slot = FMars_TESTONLY_NetPlatterSlot();
        Slot.Id = InPiece.Get_Id();
        Slot.RideLocation = InOffset.GetLocation();
        const auto Rotation = InOffset.Rotator();
        Slot.RideEuler = FVector(Rotation.Pitch, Rotation.Yaw, Rotation.Roll);
        return Slot;
    }

    // Server: step InStep with every frozen piece of the platter (at most k_SlotCount) at its offset under the root.
    protected void Publish_Rides(int32 InStep)
    {
        auto Report = Get_PlatterReport();
        Report.Step = InStep;
        const auto Held = _Platter.Get_Held();
        Report.Count = Math::Min(Held.Num(), k_SlotCount);
        for (int32 Index = 0; Index < Report.Count; ++Index)
        { Set_Slot(Report, Index, Make_Slot(Held[Index], Get_Offset(Held[Index]))); }

        Write_PlatterReport(Report);
    }

    // Server: step InStep carrying InLocation; the slots stay as they were.
    protected void Publish_Location(int32 InStep, FVector InLocation)
    {
        auto Report = Get_PlatterReport();
        Report.Step = InStep;
        Report.Location = InLocation;
        Write_PlatterReport(Report);
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Either machine
    //----------------------------------------------------------------------------------------------------------------------

    // This machine's platter world item near the test's X; invalid while none is composed.
    protected FCk_Handle_Platter Find_PlatterNear()
    {
        for (auto Candidate : utils_entity_tag::ForEach_Entity(Get_SubjectEntity(), n"TAG_MarsWorldItem"))
        {
            if (Get_IsLive(Candidate) && Candidate.Is_Transform() && Candidate.Is_Platter() && Get_IsNear(Candidate, _FloorTop))
            { return Candidate.As_Platter(); }
        }

        return FCk_Handle_Platter();
    }

    // Finds this machine's copy once and records its signals from then on.
    protected bool Try_FindPlatter()
    {
        if (ck::IsValid(_Platter))
        { return true; }

        auto Platter = Find_PlatterNear();
        if (ck::Is_NOT_Valid(Platter))
        { return false; }

        _Platter = Platter;
        _Platter.BindTo_OnLoaded(FMars_Delegate_Platter_OnLoaded(this, n"OnRigLoaded"));
        _Platter.BindTo_OnLoadAccepted(FMars_Delegate_Platter_OnLoadAccepted(this, n"OnRigLoadAccepted"));
        _Platter.BindTo_OnLoadRefused(FMars_Delegate_Platter_OnLoadRefused(this, n"OnRigLoadRefused"));
        _Platter.BindTo_OnUnloaded(FMars_Delegate_Platter_OnUnloaded(this, n"OnRigUnloaded"));
        return true;
    }

    UFUNCTION()
    private void OnRigLoaded(FCk_Handle_Platter InPlatter, FCk_Handle_FoodPiece InPiece)
    {
        ++_Loaded;
    }

    UFUNCTION()
    private void OnRigLoadAccepted(FCk_Handle_Platter InPlatter, FCk_Handle_FoodPiece InPiece)
    {
        ++_Accepted;
    }

    UFUNCTION()
    private void OnRigLoadRefused(FCk_Handle_Platter InPlatter, FCk_Handle_FoodPiece InPiece, EMars_Platter_LoadRefusal InRefusal)
    {
        ++_Refused;
    }

    UFUNCTION()
    private void OnRigUnloaded(FCk_Handle_Platter InPlatter, FCk_Handle_FoodPiece InPiece)
    {
        ++_Unloaded;
    }

    protected FString Describe_Signals()
    {
        return f"loaded={_Loaded} accepted={_Accepted} refused={_Refused} unloaded={_Unloaded}";
    }

    protected FString Describe_Counts()
    {
        if (ck::Is_NOT_Valid(_Platter))
        { return "no platter"; }

        return f"held={_Platter.Get_HeldCount()} occupancy={_Platter.Get_Occupancy()}";
    }

    protected FCk_Handle_Transform Get_PlatterRoot()
    {
        FCk_Handle Entity = _Platter;
        return Entity.As_Transform();
    }

    protected FCk_Handle_WorldItem Get_PlatterWorldItem()
    {
        FCk_Handle Entity = _Platter;
        return Entity.As_WorldItem(ECk_SanityCheck::UnChecked);
    }

    // InPiece's scene-node parent; invalid without one.
    protected FCk_Handle_Transform Get_Parent(FCk_Handle_FoodPiece InPiece)
    {
        FCk_Handle Entity = InPiece;
        auto Node = Entity.As_SceneNode(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(Node))
        { return FCk_Handle_Transform(); }

        return utils_scene_node::Get_Parent(Node);
    }

    protected bool Get_IsOnPlatterRoot(FCk_Handle_FoodPiece InPiece)
    {
        const auto Parent = Get_Parent(InPiece);
        return ck::IsValid(Parent) && Parent == Get_PlatterRoot();
    }

    // InPiece's scene-node offset; identity without a node.
    protected FTransform Get_Offset(FCk_Handle_FoodPiece InPiece)
    {
        FCk_Handle Entity = InPiece;
        auto Node = Entity.As_SceneNode(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(Node))
        { return FTransform::Identity; }

        return utils_scene_node::Get_Offset(Node);
    }

    protected FTransform Get_SlotTransform(FMars_TESTONLY_NetPlatterSlot InSlot)
    {
        return FTransform(FRotator(InSlot.RideEuler.X, InSlot.RideEuler.Y, InSlot.RideEuler.Z), InSlot.RideLocation);
    }

    protected float64 Get_AngleDegrees(FQuat InA, FQuat InB)
    {
        const auto Dot = Math::Min(1.0, Math::Abs(InA.X * InB.X + InA.Y * InB.Y + InA.Z * InB.Z + InA.W * InB.W));
        return Math::RadiansToDegrees(2.0 * Math::Acos(Dot));
    }

    // This machine's FoodPiece with InId near the test's X, whole food or piece script; invalid when none has it.
    protected FCk_Handle_FoodPiece Find_PieceById(FGuid InId)
    {
        auto Pieces = Get_FoodPiecesNear(_FloorTop);
        Pieces.Append(Get_ReadyPiecesNear(_FloorTop));
        return Find_ById(Pieces, InId);
    }

    // Empty when InPiece rides this machine's platter at InSlot: a Ready FoodPiece whose replicated holder is the platter,
    // whose scene-node parent is the platter's root, whose ride parent is the platter and whose offset under that root is
    // the slot's within k_RideToleranceCm and k_RideToleranceDegrees. Otherwise the first fault.
    protected FString Get_RideFault(FCk_Handle_FoodPiece InPiece, FMars_TESTONLY_NetPlatterSlot InSlot)
    {
        if (Get_IsLive(InPiece) == false)
        { return "no live piece"; }

        if (InPiece.Get_Status() != EMars_FoodPiece_Status::Ready)
        { return f"status {InPiece.Get_Status() :n}"; }

        if (InPiece.TryGet_ReplicatedHolder() != _Platter)
        { return f"replicated holder [{InPiece.TryGet_ReplicatedHolder().ToString()}] is not the platter"; }

        if (Get_IsOnPlatterRoot(InPiece) == false)
        { return f"scene-node parent [{Get_Parent(InPiece).ToString()}] is not the platter's root"; }

        if (InPiece.Get_RideParent() != _Platter)
        { return f"ride parent [{InPiece.Get_RideParent().ToString()}] is not the platter"; }

        const auto Offset = Get_Offset(InPiece);
        const auto Expected = Get_SlotTransform(InSlot);
        _RideErrorCm = Offset.GetLocation().Distance(Expected.GetLocation());
        _RideErrorDegrees = Get_AngleDegrees(Offset.GetRotation(), Expected.GetRotation());
        if (_RideErrorCm > k_RideToleranceCm || _RideErrorDegrees > k_RideToleranceDegrees)
        { return f"offset off by {_RideErrorCm} cm and {_RideErrorDegrees} deg"; }

        return "";
    }

    // How far InPiece's world location is from InSlot's offset under this machine's platter root, in cm.
    protected float64 Get_CarriedError(FCk_Handle_FoodPiece InPiece, FMars_TESTONLY_NetPlatterSlot InSlot)
    {
        FCk_Handle Entity = InPiece;
        const auto Expected = Get_SlotTransform(InSlot) * utils_transform::Get_EntityCurrentTransform(Get_PlatterRoot());
        return (Get_RootLocation(Entity) - Expected.GetLocation()).Size();
    }

    // Empty when this machine's platter is Held by the subject on this machine's hand node at its held offset.
    protected FString Get_HeldFault()
    {
        auto WorldItem = Get_PlatterWorldItem();
        if (ck::Is_NOT_Valid(WorldItem))
        { return "no platter world item"; }

        if (WorldItem.Get_Mount() != EMars_WorldItem_Mount::Held || WorldItem.Get_Carrier() != Get_SubjectEntity())
        { return f"mount {WorldItem.Get_Mount() :n} by [{WorldItem.Get_Carrier().ToString()}]"; }

        const UMars_ItemTrait_Presentation Presentation = WorldItem.Get_Item().Get_Presentation();
        FCk_Handle Entity = _Platter;
        const auto Error = Get_PoseError(Entity, _Carrier.Hand, Presentation.Mounting.HeldOffset);
        if (Error > k_HandPoseToleranceCm)
        { return f"off its hand node by {Error} cm"; }

        return "";
    }

    // This machine's platter refusal ledger.
    protected bool Get_PlatterLedgerNamesSubject()
    {
        return _Platter.Get_LastRefused() == Get_SubjectEntity();
    }

    protected FString Describe_PlatterLedger()
    {
        if (ck::Is_NOT_Valid(_Platter))
        { return "ledger=[no platter]"; }

        return f"ledger=[serial={_Platter.Get_RefusalSerial()} last={_Platter.Get_LastRefusal() :n} namesSubject={Get_PlatterLedgerNamesSubject()}]";
    }

    // This machine's FoodPiece of the subject's selected food; invalid while it holds none.
    protected FCk_Handle_FoodPiece Get_SelectedFoodPiece()
    {
        return utils_platter_dock::TryGet_SelectedFoodPiece(Get_SubjectEntity());
    }

    // The subject's deposit on this machine's platter, as the deposit task asks it at the grip.
    protected void Deposit()
    {
        _DepositFrame = utils_time::Get_FrameCounter();
        utils_platter::Request_DepositFor(_Platter, Get_SubjectEntity());
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Server
    //----------------------------------------------------------------------------------------------------------------------

    protected void On_ServerFoodHeld() {}

    // Server: the subject holds InFood once its piece is Ready (its item into the subject's stow target, the kernel path a
    // pickup takes); On_ServerFoodHeld once it is the subject's held item, Held and settled.
    protected void Hold_FoodWhenReady(FCk_Handle InFood)
    {
        _AwaitedFood = InFood;
        WaitUntil(n"Is_RigHeldFoodReady", n"OnRigHeldFoodReady", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_RigHeldFoodReady(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsFoodReady(_AwaitedFood) && _AwaitedFood.As_WorldItem().Get_IsLinked() && Get_IsCarrierReady(_Carrier));
    }

    UFUNCTION()
    private void OnRigHeldFoodReady(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Stow(_AwaitedFood.As_WorldItem());
        WaitUntil(n"Is_RigFoodStowed", n"OnRigFoodStowed", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_RigFoodStowed(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_Carrier.Hotbar.TryGet_SlotIndexOf(_AwaitedFood.As_WorldItem().Get_Item()).IsSet());
    }

    // A food stowed in a bag slot is in the hands once that slot is selected.
    UFUNCTION()
    private void OnRigFoodStowed(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Index = _Carrier.Hotbar.TryGet_SlotIndexOf(_AwaitedFood.As_WorldItem().Get_Item()).GetValue();
        _Carrier.Hotbar.Request_SetSelection(FMars_Request_Hotbar_SetSelection(TOptional<int32>(Index)));
        WaitUntil(n"Is_RigFoodHeld", n"OnRigFoodHeld", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_RigFoodHeld(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto WorldItem = _AwaitedFood.As_WorldItem();
        auto Result = OutResult;
        Result.Set(_Carrier.HeldItem.Get_CurrentItem() == WorldItem.Get_Item() && WorldItem.Get_Mount() == EMars_WorldItem_Mount::Held
            && WorldItem.Get_Carrier() == Get_SubjectEntity() && WorldItem.Get_IsSettled());
    }

    UFUNCTION()
    private void OnRigFoodHeld(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        On_ServerFoodHeld();
    }

    protected void On_ServerPlatterReady() {}

    protected void On_ServerFrozen() {}

    protected void On_ServerPlatterHeld() {}

    UFUNCTION()
    private void OnRigPlatterOwnerPublished(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        auto Owner = utils_mars_net::Get_ReplicatedSpawnOwner(Get_SubjectEntity());
        const auto Root = FTransform(FRotator::ZeroRotator, _FloorTop + FVector(0.0, 0.0, constants_platter::k_FloorAboveBase + 0.5));
        _PlatterEntity = utils_platter::Request_SpawnWorld(Owner, FMars_Platter_SpawnSpec(Root, mars_items::Platter_Large()));
        Track_ForCleanup(_PlatterEntity);
        WaitUntil(n"Is_RigPlatterBuilt", n"OnRigPlatterBuilt", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_RigPlatterBuilt(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsLive(_PlatterEntity) && _PlatterEntity.Is_Platter() && _PlatterEntity.Has_Fragment(FMars_Feature_WorldItem));
    }

    UFUNCTION()
    private void OnRigPlatterBuilt(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_True(Try_FindPlatter() && _Platter == _PlatterEntity, "the server finds the platter it spawned");
        On_ServerPlatterReady();
    }

    // InItem's whole food InSide x 150 cm beside the platter in Y, 5 cm above the floor, tracked.
    protected FCk_Handle Spawn_BesideFood(UCk_InventoryItem_Definition InItem, float64 InSide)
    {
        return Spawn_ServerFood(InItem, _FloorTop + FVector(0.0, InSide * k_BesideCm, 5.0));
    }

    // Loads InFood's piece once it is Ready, then On_ServerFrozen once the platter holds InHeldAfter frozen pieces.
    protected void Load_WhenReady(FCk_Handle InFood, int32 InHeldAfter)
    {
        _LoadFood = InFood;
        _FrozenHeld = InHeldAfter;
        _FrozenLoaded = _Loaded + 1;
        WaitUntil(n"Is_RigFoodReady", n"OnRigFoodReady", k_SlowPolls);
    }

    // On_ServerFrozen once the platter holds InHeld frozen pieces and raised InLoaded OnLoaded.
    protected void Await_Frozen(int32 InHeld, int32 InLoaded)
    {
        _FrozenHeld = InHeld;
        _FrozenLoaded = InLoaded;
        WaitUntil(n"Is_RigFrozen", n"OnRigFrozen", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_RigFoodReady(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsFoodReady(_LoadFood));
    }

    UFUNCTION()
    private void OnRigFoodReady(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _Platter.Request_Load(FMars_Request_Platter_Load(_LoadFood.As_FoodPiece()));
        WaitUntil(n"Is_RigFrozen", n"OnRigFrozen", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_RigFrozen(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_Platter.Get_HeldCount() == _FrozenHeld && _Loaded >= _FrozenLoaded);
    }

    UFUNCTION()
    private void OnRigFrozen(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        On_ServerFrozen();
    }

    // What the pickup task does for a Persistent item: the platter's item goes into the subject's stow target; its mount
    // follows. On_ServerPlatterHeld once it is Held and settled.
    protected void Carry_Platter()
    {
        Assert_True(Get_IsCarrierReady(_Carrier), "the server's carrier is ready");
        Stow(Get_PlatterWorldItem());
        WaitUntil(n"Is_RigPlatterHeld", n"OnRigPlatterHeld", k_SlowPolls);
    }

    // InWorldItem's item goes into the subject's stow target for it.
    protected void Stow(FCk_Handle_WorldItem InWorldItem)
    {
        auto Item = InWorldItem.Get_Item();
        auto Target = _Carrier.Hotbar.TryGet_StowTarget(Item);
        Assert_True(ck::IsValid(Target), "the subject has a stow target for the item");
        auto Holder = InWorldItem.Get_Holder();
        Holder.Request_TransferItem_ToDataOnly(FCk_Request_Inventory_TransferItem_ToDataOnly(Item, Target),
            FCk_Delegate_Inventory_OnOperationResult_Transfer());
    }

    UFUNCTION()
    private void Is_RigPlatterHeld(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto WorldItem = Get_PlatterWorldItem();
        auto Result = OutResult;
        Result.Set(ck::IsValid(WorldItem) && WorldItem.Get_Mount() == EMars_WorldItem_Mount::Held && WorldItem.Get_IsSettled());
    }

    UFUNCTION()
    private void OnRigPlatterHeld(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        On_ServerPlatterHeld();
    }

    // The server's last step: it holds k_ServerOutliveSeconds while the client asserts, logs InText, asserts no ensure
    // and ends clean.
    protected void End_PlatterServer(FString InText)
    {
        _EndText = InText;
        WaitSeconds(k_ServerOutliveSeconds, n"OnRigServerOutlived");
    }

    UFUNCTION()
    private void OnRigServerOutlived(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_Equals_Int(Get_EnsureDelta(), 0, "no ensure on the server");
        Log_Platter(_EndText);
        End_Server();
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Client
    //----------------------------------------------------------------------------------------------------------------------

    protected void On_ClientStep(int32 InStep) {}

    // On_ClientStep(InStep) k_ClientSettleSeconds after this machine has its platter and the report's step reached InStep.
    protected void Await_Step(int32 InStep)
    {
        _AwaitedStep = InStep;
        WaitUntil(n"Is_RigStepArrived", n"OnRigStepArrived", k_SlowPolls);
    }

    protected bool Get_IsStepArrived(int32 InStep)
    {
        return Try_FindPlatter() && Get_PlatterReport().Step >= InStep;
    }

    UFUNCTION()
    private void Is_RigStepArrived(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsStepArrived(_AwaitedStep));
    }

    UFUNCTION()
    private void OnRigStepArrived(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_ClientSettleSeconds, n"OnRigStepSettled");
    }

    UFUNCTION()
    private void OnRigStepSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        On_ClientStep(_AwaitedStep);
    }

    // The client's last step: asserts no ensure, logs InText and waits until its X is clean.
    protected void End_PlatterClient(FString InText)
    {
        End_Sampling();
        Assert_Equals_Int(Get_EnsureDelta(), 0, "no ensure on the client");
        Log_Platter(InText);
        End_Client();
    }
}
