namespace utils_foodpiece
{
    // RuntimeMesh's slice ceilings: a spec or a derived limit beyond them would make every cut an invalid request.
    const float k_MaxPortionVolumeCm3 = 1000000.0;
    const float k_MaxPortionThicknessCm = 10000.0;
    const float k_MinCapCmPerUVUnit = 0.001;
    const float k_MaxCapCmPerUVUnit = 1000000.0;
    const float k_MaxCapUVOffset = 1000000.0;

    // Exact: a released piece's Jolt body admits only exactly unit scale.
    const float k_UnitScaleTolerance = 0.0;

    // A piece is cooked face by face: the six faces of its bounds box. The owner of the count: every per-face channel of the
    // cook state is this long, and the cooking kernels index it by face.
    const int32 k_FaceCount = 6;

    // Composes the piece on InHandle, which must already carry a Transform and a RuntimeMesh. A new root (invalid
    // Data.Lineage) starts a lineage; a piece gets Data.Id, or a new Id when that is invalid. A piece whose geometry is already Ready (every cut half)
    // is Ready at once; one still importing is Pending until the Setup processor sees the import resolve. A rejected spec
    // or a missing Transform or RuntimeMesh ensures and returns an invalid handle.
    // A piece whose entity replicates (DoGet_HasLedger) also gets the replicated ledger (unless it already arrived), its local
    // mirror state and the mirror tag. The authority writes its identity, cook state and, once Ready, its check numbers into
    // the ledger. A copy without authority mints nothing: its Id and a root's Lineage are the spec's when valid, else the
    // arrived ledger's, else invalid until the mirror adopts them; it takes an arrived ledger's cook state. On such a copy a
    // cut piece starts Arriving and a whole one Current, and each is tagged for the Succession processor once its lineage
    // is known.
    FCk_Handle_FoodPiece Add(FCk_Handle& InHandle, FMars_FoodPiece_Spec InSpec)
    {
        const auto Validation = InSpec.Validate();
        if (ck::EnsureIfNot(Validation.IsValid(), f"[FoodPiece] [{InHandle.ToString()}] rejected the spec: {Validation.Get_Error()}"))
        { return FCk_Handle_FoodPiece(); }

        const auto IsComposable = InHandle.Is_Transform() && InHandle.Is_RuntimeMesh() && InHandle.Is_FoodPiece() == false;
        if (ck::EnsureIfNot(IsComposable, f"[FoodPiece] [{InHandle.ToString()}] needs a Transform and a RuntimeMesh, and no FoodPiece yet"))
        { return FCk_Handle_FoodPiece(); }

        auto Params = FMars_Fragment_FoodPiece_Params();
        Params.Tuners = InSpec.Tuners;
        Params.Cap = InSpec.Cap;
        Params.Body = InSpec.Body;
        Params.Recipe = InSpec.Data.Recipe;

        const auto HasLedger = DoGet_HasLedger(InHandle);
        const auto IsMirror = HasLedger && utils_net::Get_HasAuthority(InHandle) == false;
        const auto Arrived = TryGet_Ledger(InHandle);

        auto State = FMars_Fragment_FoodPiece();
        State.Id = InSpec.Data.Id;
        State.ParentId = InSpec.Data.ParentId;
        State.Lineage = InSpec.Data.Lineage;
        State.MassKg = InSpec.Data.MassKg;
        State.CookState = InSpec.Data.CookState;
        State.Definition = InSpec.Data.Definition;
        State.Kind = InSpec.Data.Kind;

        auto Local = FMars_Fragment_FoodPiece_Local();
        if (IsMirror == false)
        {
            if (State.Id.IsValid() == false)
            { State.Id = FGuid::NewGuid(); }

            if (State.Lineage.IsValid() == false)
            { State.Lineage = FGuid::NewGuid(); }
        }
        else if (Arrived.IsSet())
        {
            // The ledger replicated before this copy composed: it stands.
            const auto Ledger = Arrived.GetValue();
            if (State.Id.IsValid() == false)
            { State.Id = Ledger.Id; }

            if (State.Lineage.IsValid() == false)
            { State.Lineage = Ledger.Lineage; }

            State.CookState = Ledger.CookState;
            Local.LastCookSerial = Ledger.CookSerial;
        }

        // A copy's cut piece arrives and stands once the Succession processor rules; a whole food stands from the start and
        // is ruled on once its lineage is known (here, or when the mirror adopts it).
        const auto IsCut = InSpec.Data.Recipe.Cuts.Num() > 0;
        if (IsMirror && IsCut)
        { Local.Standing = EMars_FoodPiece_Standing::Arriving; }

        const auto NeedsSuccession = IsMirror && (IsCut || State.Lineage.IsValid());

        // A half is published Ready by its cut, so whoever receives the cut never sees it Pending.
        const auto Geometry = InHandle.As_RuntimeMesh();
        if (utils_runtime_mesh::Get_SetupState(Geometry) == ECk_RuntimeMesh_SetupState::Ready)
        {
            State.VolumeCm3 = utils_runtime_mesh::Get_Metrics(Geometry).Get_VolumeCm3();
            State.Status = EMars_FoodPiece_Status::Ready;
        }

        InHandle.Add_Fragment(FMars_Feature_FoodPiece());
        InHandle.Add_Fragment(Params);
        InHandle.Add_Fragment(State);
        InHandle.Add_Fragment(FMars_Tag_FoodPiece_NeedsSetup());

        if (HasLedger)
        {
            if (InHandle.Has_Fragment(FMars_Fragment_FoodPiece_Net) == false)
            { InHandle.Add_Fragment(FMars_Fragment_FoodPiece_Net(), ECk_Replication::Replicates); }

            InHandle.Add_Fragment(Local);
            InHandle.Add_Fragment(FMars_Tag_FoodPiece_NeedsMirror());
        }

        if (NeedsSuccession)
        { InHandle.Add_Fragment(FMars_Tag_FoodPiece_NeedsSuccession()); }

        auto Piece = InHandle.As_FoodPiece();
        Write_LedgerIdentity(Piece);

        if (Get_IsCooked(State.CookState))
        { Write_LedgerCookState(Piece, 1); }

        if (State.Status == EMars_FoodPiece_Status::Ready)
        { Write_LedgerCheck(Piece); }

        return Piece;
    }

    //----------------------------------------------------------------------------------------------------------------------
    // The replicated ledger: only the authority writes it, each write followed by its dirty mark; a copy without authority
    // or a piece without a ledger writes nothing
    //----------------------------------------------------------------------------------------------------------------------

    // How far a copy's geometry volume may read from the authority's, as a share of the authority's, and still match.
    const float k_CheckVolumeTolerance = 0.000001;

    // InHandle's replicated ledger as it stands on this machine, on any entity (a client's cut piece is not a FoodPiece
    // yet); unset without one.
    TOptional<FMars_Fragment_FoodPiece_Net> TryGet_Ledger(const FCk_Handle& InHandle)
    {
        if (ck::Is_NOT_Valid(InHandle) || InHandle.Has_Fragment(FMars_Fragment_FoodPiece_Net) == false)
        { return TOptional<FMars_Fragment_FoodPiece_Net>(); }

        return TOptional<FMars_Fragment_FoodPiece_Net>(InHandle.Get_Fragment(FMars_Fragment_FoodPiece_Net));
    }

    // Any channel of InCookState above 0.
    bool Get_IsCooked(const FMars_FoodPiece_CookState& InCookState)
    {
        for (const auto Sear : InCookState.Sear)
        {
            if (Sear > 0.0f)
            { return true; }
        }

        for (const auto Batter : InCookState.Batter)
        {
            if (Batter > 0.0f)
            { return true; }
        }

        return InCookState.OilCoat > 0.0f || InCookState.Crumb > 0.0f || InCookState.Battered > 0.0f;
    }

    // The piece's identity, as Add gave it.
    void Write_LedgerIdentity(FCk_Handle_FoodPiece& InPiece)
    {
        if (DoGet_WritesLedger(InPiece) == false)
        { return; }

        const auto& State = InPiece.Get_Fragment(FMars_Fragment_FoodPiece);
        auto& Net = InPiece.Get_Fragment(FMars_Fragment_FoodPiece_Net);
        Net.Id = State.Id;
        Net.ParentId = State.ParentId;
        Net.Lineage = State.Lineage;
        DoMark_LedgerDirty(InPiece);
    }

    // The piece's cook state as it stands now, as the InSerial-th it was given.
    void Write_LedgerCookState(FCk_Handle_FoodPiece& InPiece, int32 InSerial)
    {
        if (DoGet_WritesLedger(InPiece) == false)
        { return; }

        const auto CookState = InPiece.Get_CookState();
        auto& Net = InPiece.Get_Fragment(FMars_Fragment_FoodPiece_Net);
        Net.CookState = CookState;
        Net.CookSerial = InSerial;
        DoMark_LedgerDirty(InPiece);
    }

    // The Ready geometry's numbers a copy checks its own import against.
    void Write_LedgerCheck(FCk_Handle_FoodPiece& InPiece)
    {
        if (DoGet_WritesLedger(InPiece) == false)
        { return; }

        const auto Metrics = utils_runtime_mesh::Get_Metrics(InPiece.Get_Geometry());
        auto& Net = InPiece.Get_Fragment(FMars_Fragment_FoodPiece_Net);
        Net.Check = EMars_FoodPiece_Check::Recorded;
        Net.CheckVolumeCm3 = Metrics.Get_VolumeCm3();
        Net.CheckTriangles = Metrics.Get_TriangleCount();
        Net.CheckBoundsMinCm = Metrics.Get_BoundsMinCm();
        Net.CheckBoundsMaxCm = Metrics.Get_BoundsMaxCm();
        DoMark_LedgerDirty(InPiece);
    }

    // InOwner's ledger holds the piece.
    void Write_LedgerHeld(FCk_Handle_FoodPiece& InPiece, FCk_Handle InOwner)
    {
        if (DoGet_WritesLedger(InPiece) == false)
        { return; }

        auto& Net = InPiece.Get_Fragment(FMars_Fragment_FoodPiece_Net);
        if (Net.Holding == EMars_FoodPiece_Holding::Held && Net.Holder == InOwner)
        { return; }

        Net.Holding = EMars_FoodPiece_Holding::Held;
        Net.Holder = InOwner;
        DoMark_LedgerDirty(InPiece);
    }

    // No ledger holds the piece. The holder handle stays as it is: Holding is what says it is meaningless.
    void Write_LedgerFree(FCk_Handle_FoodPiece& InPiece)
    {
        if (DoGet_WritesLedger(InPiece) == false)
        { return; }

        auto& Net = InPiece.Get_Fragment(FMars_Fragment_FoodPiece_Net);
        if (Net.Holding == EMars_FoodPiece_Holding::Free)
        { return; }

        Net.Holding = EMars_FoodPiece_Holding::Free;
        DoMark_LedgerDirty(InPiece);
    }

    // A copy without authority whose piece is Ready and still unchecked compares its geometry with the numbers the
    // authority recorded: Matches when the triangle counts are equal and the volumes are within k_CheckVolumeTolerance of the
    // authority's, else Differs, logged once. Differs is a counted outcome: the piece keeps its geometry. Nothing happens
    // on the authority, before the numbers are recorded, before the piece is Ready, or once it was checked.
    void Update_CheckResult(FCk_Handle_FoodPiece& InPiece)
    {
        if (utils_net::Get_HasAuthority(InPiece) || InPiece.Has_Fragment(FMars_Fragment_FoodPiece_Local) == false)
        { return; }

        if (InPiece.Get_Fragment(FMars_Fragment_FoodPiece_Local).CheckResult != EMars_FoodPiece_CheckResult::Unchecked)
        { return; }

        const auto Ledger = TryGet_Ledger(InPiece);
        if (Ledger.IsSet() == false || Ledger.GetValue().Check != EMars_FoodPiece_Check::Recorded)
        { return; }

        if (InPiece.Get_Status() != EMars_FoodPiece_Status::Ready)
        { return; }

        const auto Metrics = utils_runtime_mesh::Get_Metrics(InPiece.Get_Geometry());
        const auto Recorded = Ledger.GetValue();
        const auto VolumeDelta = Math::Abs(Metrics.Get_VolumeCm3() - Recorded.CheckVolumeCm3);
        const auto IsMatch = Metrics.Get_TriangleCount() == Recorded.CheckTriangles
            && VolumeDelta <= k_CheckVolumeTolerance * Math::Abs(Recorded.CheckVolumeCm3);

        auto& Local = InPiece.Get_Fragment(FMars_Fragment_FoodPiece_Local);
        Local.CheckResult = IsMatch ? EMars_FoodPiece_CheckResult::Matches : EMars_FoodPiece_CheckResult::Differs;
        if (IsMatch == false)
        { Warning(f"[FoodPiece] [{InPiece.ToString()}]'s geometry differs from the authority's: volume [{Metrics.Get_VolumeCm3()}] cm3 vs [{Recorded.CheckVolumeCm3}], triangles [{Metrics.Get_TriangleCount()}] vs [{Recorded.CheckTriangles}]"); }
    }

    // A piece composing on InHandle carries the replicated ledger: its entity replicates. The authority has the replication
    // driver from before construction; a copy without authority receives its driver after it constructs, so there the
    // entity's own replication says it.
    bool DoGet_HasLedger(const FCk_Handle& InHandle)
    {
        if (utils_entity_replication_driver::Has(InHandle))
        { return true; }

        if (utils_net::Get_HasAuthority(InHandle) || utils_net::Has(InHandle) == false)
        { return false; }

        return utils_net::Get_EntityReplication(InHandle) == ECk_Replication::Replicates;
    }

    bool DoGet_WritesLedger(const FCk_Handle_FoodPiece& InPiece)
    {
        return InPiece.Has_Fragment(FMars_Fragment_FoodPiece_Net) && utils_net::Get_HasAuthority(InPiece);
    }

    void DoMark_LedgerDirty(FCk_Handle_FoodPiece& InPiece)
    {
        FCk_Handle Entity = InPiece;
        Entity.Request_MarkReplicationDirty(FMars_Fragment_FoodPiece_Net);
    }

    // A Dynamic convex body of the piece's own mesh and mass with the piece's own surface (its Body tuners), on the piece's
    // entity: the one builder for a piece dropped onto a platter and a whole food item. The piece must be Ready (its
    // geometry gives the hull) and bodiless; the body reads the piece's transform as it is when the body is set up. Bodies
    // are the authority's: a copy without authority would run a second simulation against the replicated pose.
    FCk_Handle_JoltBody Add_Body(FCk_Handle_FoodPiece& InPiece)
    {
        FCk_Handle Entity = InPiece;
        const auto HasAuthority = utils_net::Get_HasAuthority(Entity);
        const auto CanAdd = InPiece.Get_Status() == EMars_FoodPiece_Status::Ready && Entity.Is_JoltBody() == false && HasAuthority;
        if (ck::EnsureIfNot(CanAdd, f"[FoodPiece] [{InPiece.ToString()}] gets a body only once Ready, bodiless and with authority (status [{InPiece.Get_Status() :n}], body [{Entity.Is_JoltBody()}], authority [{HasAuthority}])"))
        { return FCk_Handle_JoltBody(); }

        const auto Tuners = InPiece.Get_BodyTuners();
        auto Convex = FCk_JoltBody_RuntimeConvexSpec();
        Convex.Set_PointsCm(utils_runtime_mesh::Copy_LocalVerticesCm(InPiece.Get_Geometry()));

        auto BodySpec = FCk_JoltBody_Spec(ECk_JoltBody_ShapeSource::RuntimeConvex);
        BodySpec.Set_RuntimeConvex(Convex);
        BodySpec.Set_MotionType(ECk_MotionType::Dynamic);
        BodySpec.Set_MassSource(ECk_JoltBody_MassSource::Explicit);
        BodySpec.Set_MassKg(float32(InPiece.Get_MassKg()));
        BodySpec.Set_SurfaceSource(ECk_JoltBody_SurfaceSource::Explicit);
        BodySpec.Set_Friction(Tuners.Friction);
        BodySpec.Set_Restitution(Tuners.Restitution);
        BodySpec.Set_CollisionProfileName(Tuners.CollisionProfileName);
        // A Resting on this body needs a Persisted contact every step from a resting awake piece.
        BodySpec.Set_PersistContacts(ECk_EnableDisable::Enable);
        return utils_jolt_body::Add(Entity, BodySpec);
    }

    // InPlane in the local frame of a piece whose world transform is InPieceWorld: the frame a slice is expressed in.
    // RuntimeMesh geometry is never scaled, so a scaled piece frame is a defect: it ensures and there is no plane.
    TOptional<FCk_RuntimeMesh_PlaneLocal> Get_LocalPlane(const FTransform& InPieceWorld, const FMars_FoodPiece_WorldPlane& InPlane)
    {
        const auto IsUnitScale = InPieceWorld.GetScale3D().Equals(FVector::OneVector, k_UnitScaleTolerance);
        if (ck::EnsureIfNot(IsUnitScale, f"[FoodPiece] a piece frame has scale [{InPieceWorld.GetScale3D()}]: pieces are cut in an unscaled frame"))
        { return TOptional<FCk_RuntimeMesh_PlaneLocal>(); }

        auto Plane = FCk_RuntimeMesh_PlaneLocal();
        Plane.Set_PositionCm(InPieceWorld.InverseTransformPositionNoScale(InPlane.PositionCm));
        Plane.Set_Normal(InPieceWorld.InverseTransformVectorNoScale(InPlane.Normal));
        Plane.Set_Tangent(InPieceWorld.InverseTransformVectorNoScale(InPlane.Tangent));
        return TOptional<FCk_RuntimeMesh_PlaneLocal>(Plane);
    }

    // The outcome a resolved slice gives the cut.
    EMars_FoodPiece_CutOutcome Get_CutOutcome(ECk_RuntimeMesh_SliceOutcome InSliceOutcome)
    {
        switch (InSliceOutcome)
        {
            case ECk_RuntimeMesh_SliceOutcome::Succeeded: return EMars_FoodPiece_CutOutcome::Cut;
            case ECk_RuntimeMesh_SliceOutcome::NoIntersection: return EMars_FoodPiece_CutOutcome::Missed;
            case ECk_RuntimeMesh_SliceOutcome::TouchingOnly: return EMars_FoodPiece_CutOutcome::Missed;
            case ECk_RuntimeMesh_SliceOutcome::RejectedTooSmall: return EMars_FoodPiece_CutOutcome::Rejected;
            case ECk_RuntimeMesh_SliceOutcome::RejectedLimit: return EMars_FoodPiece_CutOutcome::Rejected;
            case ECk_RuntimeMesh_SliceOutcome::RejectedTopology: return EMars_FoodPiece_CutOutcome::Rejected;
            case ECk_RuntimeMesh_SliceOutcome::NotReady: return EMars_FoodPiece_CutOutcome::Rejected;
            case ECk_RuntimeMesh_SliceOutcome::InvalidRequest: return EMars_FoodPiece_CutOutcome::Rejected;
            case ECk_RuntimeMesh_SliceOutcome::FailedCancelled: return EMars_FoodPiece_CutOutcome::Cancelled;
            default: return EMars_FoodPiece_CutOutcome::Failed;
        }
    }

    // InMassKg split by the halves' mesh volumes. The smaller half takes its share by ratio and the larger the remainder,
    // so the two add back to the whole.
    FMars_FoodPiece_MassSplit Get_MassSplit(float InMassKg, const FCk_RuntimeMesh_SliceResult& InResult)
    {
        const auto PositiveCm3 = InResult.Get_PositiveMetrics().Get_VolumeCm3();
        const auto NegativeCm3 = InResult.Get_NegativeMetrics().Get_VolumeCm3();

        auto Split = FMars_FoodPiece_MassSplit();
        if (PositiveCm3 <= NegativeCm3)
        {
            Split.PositiveKg = InMassKg * PositiveCm3 / (PositiveCm3 + NegativeCm3);
            Split.NegativeKg = InMassKg - Split.PositiveKg;
        }
        else
        {
            Split.NegativeKg = InMassKg * NegativeCm3 / (PositiveCm3 + NegativeCm3);
            Split.PositiveKg = InMassKg - Split.NegativeKg;
        }

        return Split;
    }

    // Whether InWorld's ledger (the world's transient entity) still holds a slice in flight for InPiece.
    bool Get_HasPendingCut(const FCk_Handle& InWorld, const FCk_Handle_FoodPiece& InPiece)
    {
        if (InWorld.Has_Fragment(FMars_Fragment_FoodPiece_PendingCuts) == false)
        { return false; }

        for (const auto& Entry : InWorld.Get_Fragment(FMars_Fragment_FoodPiece_PendingCuts).Entries)
        {
            if (Entry.Piece == InPiece)
            { return true; }
        }

        return false;
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Replicated pieces: a cut whose source replicates makes its halves as piece scripts (UMars_FoodPiece_EntityScript)
    //----------------------------------------------------------------------------------------------------------------------

    // A cut of InPiece makes replicated piece scripts: its entity replicates. Any other piece's cut composes its halves on
    // the slice's own entities, on this machine only.
    bool Get_CutsIntoReplicatedPieces(const FCk_Handle_FoodPiece& InPiece)
    {
        return utils_entity_replication_driver::Has(InPiece);
    }

    // The one spawn of a piece script: under the replicated spawn owner, its spawn data taken from InBirth (World, the
    // recipe, the identity, the mass), InBirth stamped on the entity under construction for the script to compose from.
    // Returns that entity; invalid, having ensured, where there is no replicated spawn owner (a client, or an authority
    // whose owner is not published yet). The host checks that it replicates.
    FCk_Handle Request_SpawnCutPiece(const FCk_Handle& InAnyHandle, const FMars_FoodPiece_Birth& InBirth)
    {
        auto Owner = utils_mars_net::Get_ReplicatedSpawnOwner(InAnyHandle);
        if (ck::EnsureIfNot(ck::IsValid(Owner), f"[FoodPiece] a cut piece spawned from [{InAnyHandle.ToString()}] has no replicated spawn owner: nothing spawns"))
        { return FCk_Handle(); }

        auto Params = FMars_FoodPiece_SpawnParams();
        Params.SpawnTransform = InBirth.World;
        Params.Definition = InBirth.Spec.Data.Recipe.Definition;
        Params.Cuts = InBirth.Spec.Data.Recipe.Cuts;
        Params.Id = InBirth.Spec.Data.Id;
        Params.ParentId = InBirth.Spec.Data.ParentId;
        Params.Lineage = InBirth.Spec.Data.Lineage;
        Params.MassKg = InBirth.Spec.Data.MassKg;

        auto Pending = utils_entity_script::Request_SpawnEntity(Owner, UMars_FoodPiece_EntityScript, Params);
        auto Entity = Pending.Get_EntityUnderConstruction();
        utils_net_spawn::Expect_Replicated(Entity);
        if (ck::IsValid(Entity))
        { Entity.Add_Fragment(FMars_Fragment_FoodPiece_Birth(InBirth)); }

        return Entity;
    }

    // InHandle (a piece script under construction, already carrying its transform) has its birth: the authority spawned it
    // and it has not composed yet.
    bool Get_IsBorn(const FCk_Handle& InHandle)
    {
        return ck::IsValid(InHandle) && InHandle.Has_Fragment(FMars_Fragment_FoodPiece_Birth);
    }

    // Composes the piece InHandle was born to be: the birth geometry shared onto it (that geometry's own entity is then
    // destroyed) and a FoodPiece of the birth spec, Ready at once. A birth that names a source finishes or abandons that
    // source's cut. The source gone or no longer committing: the sibling, if it is a piece, is destroyed and this piece is
    // not composed. The sibling already a piece: the cut commits here (OnCutResolved reports both halves as the source
    // recorded them, then the source is destroyed). The sibling still unborn: this piece waits for it. The sibling neither
    // (it failed or is gone), or this piece failing to compose: the cut fails (the source is Ready again, OnCutResolved
    // reports Failed) and this piece is not composed. Returns the piece, or an invalid handle: the caller ends the entity.
    FCk_Handle_FoodPiece Add_Born(FCk_Handle& InHandle)
    {
        if (ck::EnsureIfNot(Get_IsBorn(InHandle), f"[FoodPiece] [{InHandle.ToString()}] has no birth to compose from"))
        { return FCk_Handle_FoodPiece(); }

        // Removed first: the sibling reads it to tell an unborn half from a failed one.
        const auto Birth = InHandle.Get_Fragment(FMars_Fragment_FoodPiece_Birth).Birth;
        InHandle.Request_TryRemove(FMars_Fragment_FoodPiece_Birth);

        const auto Piece = DoCompose_Born(InHandle, Birth);
        if (Birth.Source == FCk_Handle_FoodPiece())
        { return Piece; }

        auto Source = Birth.Source;
        FCk_Handle Sibling = Birth.Sibling;
        const auto SiblingIsPiece = ck::IsValid(Sibling) && Sibling.Is_FoodPiece()
            && utils_entity_lifetime::Get_IsPendingDestroy(Sibling, ECk_EntityLifetime_DestructionPhase::BeginDestroy) == false;

        if (Source.Get_IsGone() || Source.Has_Fragment(FMars_Fragment_FoodPiece_PendingCommit) == false)
        {
            if (SiblingIsPiece)
            { utils_entity_lifetime::Request_DestroyEntity(Sibling); }

            return FCk_Handle_FoodPiece();
        }

        if (ck::Is_NOT_Valid(Piece))
        {
            if (SiblingIsPiece)
            { utils_entity_lifetime::Request_DestroyEntity(Sibling); }

            DoFail_PendingCommit(Source);
            return FCk_Handle_FoodPiece();
        }

        if (SiblingIsPiece)
        {
            DoFinish_PendingCommit(Source);
            return Piece;
        }

        if (Get_IsBorn(Sibling))
        { return Piece; }

        DoFail_PendingCommit(Source);
        return FCk_Handle_FoodPiece();
    }

    // Keeps what a machine without the slice needs to rebuild the piece (FMars_Fragment_FoodPiece_Replay) and asks for the
    // rebuild: the Replay processor walks the recipe and resolves it once, Built or Failed (OnReplayResolved).
    void Request_Replay(FCk_Handle& InHandle, const FMars_FoodPiece_ReplaySpec& InSpec)
    {
        auto Replay = FMars_Fragment_FoodPiece_Replay();
        Replay.Spec = InSpec;
        InHandle.AddOrGet_Fragment(FMars_Fragment_FoodPiece_Replay) = Replay;
        if (InHandle.Has_Fragment(FMars_Tag_FoodPiece_AwaitsReplay) == false)
        { InHandle.Add_Fragment(FMars_Tag_FoodPiece_AwaitsReplay()); }
    }

    // How InHandle's replay stands; unset when Request_Replay kept nothing on it.
    TOptional<FMars_FoodPiece_ReplayResult> TryGet_ReplayResult(const FCk_Handle& InHandle)
    {
        if (ck::Is_NOT_Valid(InHandle) || InHandle.Has_Fragment(FMars_Fragment_FoodPiece_Replay) == false)
        { return TOptional<FMars_FoodPiece_ReplayResult>(); }

        const auto& Replay = InHandle.Get_Fragment(FMars_Fragment_FoodPiece_Replay);
        auto Result = FMars_FoodPiece_ReplayResult();
        Result.State = Replay.State;
        Result.Failure = Replay.Failure;
        Result.SliceOutcome = Replay.SliceOutcome;
        return TOptional<FMars_FoodPiece_ReplayResult>(Result);
    }

    void BindTo_OnReplayResolved(FCk_Handle& InHandle, FMars_Delegate_FoodPiece_OnReplayResolved InDelegate)
    {
        auto& Fragment = InHandle.AddOrGet_Fragment(FMars_Fragment_FoodPiece_ReplaySignals);
        Fragment.OnReplayResolved.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
    }

    void UnbindFrom_OnReplayResolved(FCk_Handle& InHandle, FMars_Delegate_FoodPiece_OnReplayResolved InDelegate)
    {
        if (InHandle.Has_Fragment(FMars_Fragment_FoodPiece_ReplaySignals) == false)
        { return; }

        InHandle.Get_Fragment(FMars_Fragment_FoodPiece_ReplaySignals).OnReplayResolved.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
    }

    // At most this many replay slices are in flight on one machine; a node that would exceed it waits a frame.
    const int32 k_MaxReplayFlights = 8;

    // How long a lineage with no slice in flight and no live piece is kept before its geometry is dropped.
    const float32 k_MemoGraceSeconds = 2.0f;

    // InWorld's (the world's transient entity) replay memo as counts; all zero without one.
    FMars_FoodPiece_ReplayTally Get_ReplayTally(const FCk_Handle& InWorld)
    {
        auto Tally = FMars_FoodPiece_ReplayTally();
        if (ck::Is_NOT_Valid(InWorld) || InWorld.Has_Fragment(FMars_Fragment_FoodPiece_ReplayMemo) == false)
        { return Tally; }

        const auto& Memo = InWorld.Get_Fragment(FMars_Fragment_FoodPiece_ReplayMemo);
        Tally.Slices = Memo.Tally.Slices;
        Tally.Built = Memo.Tally.Built;
        Tally.Failed = Memo.Tally.Failed;
        Tally.Lineages = Memo.Lineages.Num();

        for (const auto& Import : Memo.Imports)
        {
            if (Get_IsLiveEntity(Import.Geometry))
            { ++Tally.Geometries; }
        }

        // Node 0 is the import, counted above.
        for (const auto& Lineage : Memo.Lineages)
        {
            for (int32 Index = 1; Index < Lineage.Nodes.Num(); ++Index)
            {
                if (Get_IsLiveEntity(Lineage.Nodes[Index].Geometry))
                { ++Tally.Geometries; }
            }
        }

        return Tally;
    }

    // InEntity is valid and not yet in its BeginDestroy.
    bool Get_IsLiveEntity(const FCk_Handle& InEntity)
    {
        return ck::IsValid(InEntity) && utils_entity_lifetime::Get_IsPendingDestroy(InEntity, ECk_EntityLifetime_DestructionPhase::BeginDestroy) == false;
    }

    // The same plane, exactly: position, normal and tangent.
    bool Get_IsSamePlane(const FCk_RuntimeMesh_PlaneLocal& InA, const FCk_RuntimeMesh_PlaneLocal& InB)
    {
        return InA.Get_PositionCm() == InB.Get_PositionCm() && InA.Get_Normal() == InB.Get_Normal() && InA.Get_Tangent() == InB.Get_Tangent();
    }

    // InPiece was cut from InAncestor: one lineage (its cuts share one frame), InAncestor's recipe strictly shorter, and
    // each of InAncestor's cuts the same plane and kept side as InPiece's cut at that index.
    bool Get_IsCutFrom(const FCk_Handle_FoodPiece& InPiece, const FCk_Handle_FoodPiece& InAncestor)
    {
        const auto Lineage = InPiece.Get_Lineage();
        if (Lineage.IsValid() == false || InAncestor.Get_Lineage() != Lineage)
        { return false; }

        const auto Cuts = InPiece.Get_Recipe().Cuts;
        const auto AncestorCuts = InAncestor.Get_Recipe().Cuts;
        if (AncestorCuts.Num() >= Cuts.Num())
        { return false; }

        for (int32 Index = 0; Index < AncestorCuts.Num(); ++Index)
        {
            if (AncestorCuts[Index].Kept != Cuts[Index].Kept || Get_IsSamePlane(AncestorCuts[Index].Plane, Cuts[Index].Plane) == false)
            { return false; }
        }

        return true;
    }

    // What Request_Replay kept on InHandle; unset when it kept nothing.
    TOptional<FMars_FoodPiece_ReplaySpec> TryGet_Replay(const FCk_Handle& InHandle)
    {
        if (ck::Is_NOT_Valid(InHandle) || InHandle.Has_Fragment(FMars_Fragment_FoodPiece_Replay) == false)
        { return TOptional<FMars_FoodPiece_ReplaySpec>(); }

        return TOptional<FMars_FoodPiece_ReplaySpec>(InHandle.Get_Fragment(FMars_Fragment_FoodPiece_Replay).Spec);
    }

    // A rejected share or spec already ensured (RuntimeMesh, Add).
    FCk_Handle_FoodPiece DoCompose_Born(FCk_Handle& InHandle, const FMars_FoodPiece_Birth& InBirth)
    {
        const auto Shared = utils_runtime_mesh::Add_SharedGeometry(InHandle, InBirth.Geometry);

        FCk_Handle GeometryEntity = InBirth.Geometry;
        if (ck::IsValid(GeometryEntity))
        { utils_entity_lifetime::Request_DestroyEntity(GeometryEntity); }

        if (ck::Is_NOT_Valid(Shared))
        { return FCk_Handle_FoodPiece(); }

        return Add(InHandle, InBirth.Spec);
    }

    // Both halves are pieces: the cut the source was committing is reported and the source ends.
    void DoFinish_PendingCommit(FCk_Handle_FoodPiece& InSource)
    {
        const auto Commit = InSource.Get_Fragment(FMars_Fragment_FoodPiece_PendingCommit);
        InSource.Request_TryRemove(FMars_Fragment_FoodPiece_PendingCommit);

        auto Result = FMars_FoodPiece_CutResult(EMars_FoodPiece_CutOutcome::Cut, Commit.SliceOutcome);
        Result.Positive = Commit.Positive.As_FoodPiece();
        Result.Negative = Commit.Negative.As_FoodPiece();
        DoBroadcast_CutResolved(InSource, Result);

        utils_entity_lifetime::Request_DestroyEntity(InSource);
    }

    // A half of the cut the source was committing will never be a piece: the source is whole and Ready again.
    void DoFail_PendingCommit(FCk_Handle_FoodPiece& InSource)
    {
        const auto SliceOutcome = InSource.Get_Fragment(FMars_Fragment_FoodPiece_PendingCommit).SliceOutcome;
        InSource.Request_TryRemove(FMars_Fragment_FoodPiece_PendingCommit);

        auto& State = InSource.Get_Fragment(FMars_Fragment_FoodPiece);
        State.PendingCut.Reset();
        State.Status = EMars_FoodPiece_Status::Ready;
        DoBroadcast_CutResolved(InSource, FMars_FoodPiece_CutResult(EMars_FoodPiece_CutOutcome::Failed, SliceOutcome));
    }

    void DoBroadcast_CutResolved(FCk_Handle_FoodPiece& InSource, const FMars_FoodPiece_CutResult& InResult)
    {
        if (InSource.Has_Fragment(FMars_Fragment_FoodPiece_Signals))
        { InSource.Get_Fragment(FMars_Fragment_FoodPiece_Signals).OnCutResolved.Broadcast(InSource, InResult); }
    }

    bool Get_IsUnitColor(const FLinearColor& InColor)
    {
        return Get_IsUnitInterval(InColor.R) && Get_IsUnitInterval(InColor.G)
            && Get_IsUnitInterval(InColor.B) && Get_IsUnitInterval(InColor.A);
    }

    bool Get_IsUnitInterval(float32 InValue)
    {
        return Math::IsFinite(InValue) && InValue >= 0.0f && InValue <= 1.0f;
    }

    // The middle of a piece's mesh bounds, in its own frame (a cut half's origin is the uncut piece's, not its own middle).
    FVector Get_BoundsCentre(const FCk_RuntimeMesh_Metrics& InMetrics)
    {
        return (InMetrics.Get_BoundsMinCm() + InMetrics.Get_BoundsMaxCm()) * 0.5;
    }

    FVector Get_BoundsHalfExtents(const FCk_RuntimeMesh_Metrics& InMetrics)
    {
        return (InMetrics.Get_BoundsMaxCm() - InMetrics.Get_BoundsMinCm()) * 0.5;
    }

    // InPieceTransform (in any frame) moved to the piece's middle: the frame its faces are measured from.
    FTransform Get_CentreFrame(const FTransform& InPieceTransform, const FVector& InCentreLocal)
    {
        return FTransform(InPieceTransform.GetRotation(), InPieceTransform.TransformPosition(InCentreLocal));
    }

    //----------------------------------------------------------------------------------------------------------------------
    // The face vocabulary every cooking kernel shares: a piece is its mesh's bounds box in its own frame, its middle
    // CentreLocal (Get_BoundsCentre) and its half sizes HalfExtents (Get_BoundsHalfExtents).
    //----------------------------------------------------------------------------------------------------------------------

    // The face's outward normal in the piece's own frame.
    FVector Get_FaceNormal(EMars_FoodPiece_Face InFace)
    {
        switch (InFace)
        {
            case EMars_FoodPiece_Face::PosX: return FVector(1.0, 0.0, 0.0);
            case EMars_FoodPiece_Face::NegX: return FVector(-1.0, 0.0, 0.0);
            case EMars_FoodPiece_Face::PosY: return FVector(0.0, 1.0, 0.0);
            case EMars_FoodPiece_Face::NegY: return FVector(0.0, -1.0, 0.0);
            case EMars_FoodPiece_Face::PosZ: return FVector(0.0, 0.0, 1.0);
            default: return FVector(0.0, 0.0, -1.0);
        }
    }

    // The face whose world normal (InPieceRotation applied to its body normal) has the smallest dot with InUp.
    EMars_FoodPiece_Face Get_DownFace(const FQuat& InPieceRotation, const FVector& InUp)
    {
        auto Best = EMars_FoodPiece_Face::NegZ;
        auto BestDot = 2.0;
        for (int32 Index = 0; Index < k_FaceCount; ++Index)
        {
            const auto Face = EMars_FoodPiece_Face(Index);
            const auto Dot = InPieceRotation.RotateVector(Get_FaceNormal(Face)).DotProduct(InUp);
            if (Dot < BestDot)
            {
                BestDot = Dot;
                Best = Face;
            }
        }

        return Best;
    }

    // The piece rotation that lays InFace against -Z. MakeFromXZ(X, -N) turns the body's +Z onto -N (X is any body axis
    // perpendicular to N); its inverse is the rotation that turns N onto -Z.
    FRotator Make_FaceDownRotation(EMars_FoodPiece_Face InFace)
    {
        const auto Normal = Get_FaceNormal(InFace);
        const auto Perpendicular = Math::Abs(Normal.X) > 0.5 ? FVector(0.0, 0.0, 1.0) : FVector(1.0, 0.0, 0.0);
        const auto Basis = FTransform(FQuat(FRotator::MakeFromXZ(Perpendicular, -Normal)), FVector::ZeroVector, FVector::OneVector);
        return Basis.InverseTransformRotation(FQuat::Identity).Rotator();
    }

    FString Get_FaceName(EMars_FoodPiece_Face InFace)
    {
        switch (InFace)
        {
            case EMars_FoodPiece_Face::PosX: return "+X";
            case EMars_FoodPiece_Face::NegX: return "-X";
            case EMars_FoodPiece_Face::PosY: return "+Y";
            case EMars_FoodPiece_Face::NegY: return "-Y";
            case EMars_FoodPiece_Face::PosZ: return "+Z";
            default: return "-Z";
        }
    }

    // The middle of InFace in InCentreFrame's parent frame: the face's normal picks the half extent it lies out.
    FVector Get_FaceCentre(const FTransform& InCentreFrame, EMars_FoodPiece_Face InFace, const FVector& InHalfExtents)
    {
        const auto Normal = Get_FaceNormal(InFace);
        const auto Out = FVector(Normal.X * InHalfExtents.X, Normal.Y * InHalfExtents.Y, Normal.Z * InHalfExtents.Z);
        return InCentreFrame.GetLocation() + InCentreFrame.GetRotation().RotateVector(Out);
    }

    // The half height of the rotated box along its parent frame's Z: how far its bottom lies under its middle.
    float64 Get_WorldHalfExtentZ(const FQuat& InRotation, const FVector& InHalfExtents)
    {
        return Math::Abs(InRotation.RotateVector(FVector::ForwardVector).Z) * InHalfExtents.X
            + Math::Abs(InRotation.RotateVector(FVector::RightVector).Z) * InHalfExtents.Y
            + Math::Abs(InRotation.RotateVector(FVector::UpVector).Z) * InHalfExtents.Z;
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Arrival: a kernel that adopts a released piece judges it only once its transform reads the release
    //----------------------------------------------------------------------------------------------------------------------

    // How far an adopted piece's transform may read from its release location and count as arrived.
    const float64 k_ArrivalToleranceCm = 5.0;
    // How long an adopted piece may take to arrive: past it the kernel ensures (its pose never got there) and judges it
    // where it is, so a piece is never left unjudged.
    const float32 k_ArrivalMaxSeconds = 1.0f;

    // An adopted piece has arrived once its body is in the simulation and its transform reads the release location (within
    // k_ArrivalToleranceCm: a released piece may already have moved a frame's worth).
    bool Get_HasArrived(const FCk_Handle_JoltBody& InBody, const FCk_Handle& InEntity, const FVector& InReleaseLocation)
    {
        if (utils_jolt_body::Get_IsBodyAdded(InBody) == false)
        { return false; }

        return Get_ArrivalDistance(InEntity, InReleaseLocation) <= k_ArrivalToleranceCm;
    }

    // How far an adopted piece's transform reads from its release location.
    float64 Get_ArrivalDistance(const FCk_Handle& InEntity, const FVector& InReleaseLocation)
    {
        return (utils_transform::Get_EntityCurrentLocation(InEntity.As_Transform()) - InReleaseLocation).Size();
    }

    // InOwner's ledger admitted InPiece. Called only by a ledger's processor, after its own refusals read the holder: a
    // live holder other than InOwner here would put the piece in two ledgers (a defect); the newest admission wins. The
    // authority publishes the holder in the replicated ledger (TryGet_ReplicatedHolder).
    void Stamp_Holder(FCk_Handle_FoodPiece& InPiece, FCk_Handle InOwner)
    {
        const auto Holder = InPiece.TryGet_Holder();
        if (ck::EnsureIfNot(ck::Is_NOT_Valid(Holder) || Holder == InOwner,
            f"[FoodPiece] [{InPiece.ToString()}] is admitted by [{InOwner.ToString()}] while [{Holder.ToString()}] still holds it"))
        {
            InPiece.Get_Fragment(FMars_Fragment_FoodPiece_Holder).Owner = InOwner;
            Write_LedgerHeld(InPiece, InOwner);
            return;
        }

        InPiece.AddOrGet_Fragment(FMars_Fragment_FoodPiece_Holder).Owner = InOwner;
        Write_LedgerHeld(InPiece, InOwner);
    }

    // InOwner's ledger let InPiece go. A piece some other ledger holds by now keeps that holder. Called only by a ledger's
    // processor. The authority publishes the piece free.
    void Clear_Holder(FCk_Handle_FoodPiece& InPiece, FCk_Handle InOwner)
    {
        if (ck::Is_NOT_Valid(InPiece) || InPiece.Has_Fragment(FMars_Fragment_FoodPiece_Holder) == false)
        { return; }

        if (InPiece.Get_Fragment(FMars_Fragment_FoodPiece_Holder).Owner != InOwner)
        { return; }

        InPiece.Request_TryRemove(FMars_Fragment_FoodPiece_Holder);
        Write_LedgerFree(InPiece);
    }
}

//--------------------------------------------------------------------------------------------------------------------------
// Getters
//--------------------------------------------------------------------------------------------------------------------------

// The piece is gone or going: an invalid handle, or an entity already in its BeginDestroy. Safe on any handle.
mixin bool Get_IsGone(const FCk_Handle_FoodPiece& Self)
{
    return ck::Is_NOT_Valid(Self) || utils_entity_lifetime::Get_IsPendingDestroy(Self, ECk_EntityLifetime_DestructionPhase::BeginDestroy);
}

mixin FGuid Get_Id(const FCk_Handle_FoodPiece& Self)
{
    return Self.Get_Fragment(FMars_Fragment_FoodPiece).Id;
}

// Invalid for a root.
mixin FGuid Get_ParentId(const FCk_Handle_FoodPiece& Self)
{
    return Self.Get_Fragment(FMars_Fragment_FoodPiece).ParentId;
}

mixin FGuid Get_Lineage(const FCk_Handle_FoodPiece& Self)
{
    return Self.Get_Fragment(FMars_Fragment_FoodPiece).Lineage;
}

mixin float Get_MassKg(const FCk_Handle_FoodPiece& Self)
{
    return Self.Get_Fragment(FMars_Fragment_FoodPiece).MassKg;
}

// Zero until the piece is Ready.
mixin float Get_VolumeCm3(const FCk_Handle_FoodPiece& Self)
{
    return Self.Get_Fragment(FMars_Fragment_FoodPiece).VolumeCm3;
}

mixin FMars_FoodPiece_CookState Get_CookState(const FCk_Handle_FoodPiece& Self)
{
    return Self.Get_Fragment(FMars_Fragment_FoodPiece).CookState;
}

// Unset for a bare piece.
mixin TWeakObjectPtr<UMars_Food_Def> Get_Definition(const FCk_Handle_FoodPiece& Self)
{
    return Self.Get_Fragment(FMars_Fragment_FoodPiece).Definition;
}

mixin FGameplayTagContainer Get_Kind(const FCk_Handle_FoodPiece& Self)
{
    return Self.Get_Fragment(FMars_Fragment_FoodPiece).Kind;
}

// A root (never cut from another piece).
mixin bool Get_IsWhole(const FCk_Handle_FoodPiece& Self)
{
    return Self.Get_Fragment(FMars_Fragment_FoodPiece).ParentId.IsValid() == false;
}

mixin EMars_FoodPiece_Status Get_Status(const FCk_Handle_FoodPiece& Self)
{
    return Self.Get_Fragment(FMars_Fragment_FoodPiece).Status;
}

mixin bool Get_IsCutting(const FCk_Handle_FoodPiece& Self)
{
    return Self.Get_Fragment(FMars_Fragment_FoodPiece).PendingCut.IsSet();
}

mixin FMars_FoodPiece_Tuners Get_Tuners(const FCk_Handle_FoodPiece& Self)
{
    return Self.Get_Fragment(FMars_Fragment_FoodPiece_Params).Tuners;
}

mixin FCk_RuntimeMesh_Cap Get_Cap(const FCk_Handle_FoodPiece& Self)
{
    return Self.Get_Fragment(FMars_Fragment_FoodPiece_Params).Cap;
}

// How another machine rebuilds the piece: its food's wire id and every cut of its lineage. Empty for a bare piece.
mixin FMars_FoodPiece_Recipe Get_Recipe(const FCk_Handle_FoodPiece& Self)
{
    return Self.Get_Fragment(FMars_Fragment_FoodPiece_Params).Recipe;
}

// The surface of every body the piece is given.
mixin FMars_FoodPiece_BodyTuners Get_BodyTuners(const FCk_Handle_FoodPiece& Self)
{
    return Self.Get_Fragment(FMars_Fragment_FoodPiece_Params).Body;
}

// The piece's own entity, as its geometry.
mixin FCk_Handle_RuntimeMesh Get_Geometry(const FCk_Handle_FoodPiece& Self)
{
    FCk_Handle Entity = Self;
    return Entity.As_RuntimeMesh();
}

// MinPortionMassKg as a volume at the piece's density: the smallest half a cut of this piece may leave.
mixin float Get_MinimumPortionVolumeCm3(const FCk_Handle_FoodPiece& Self)
{
    const auto& State = Self.Get_Fragment(FMars_Fragment_FoodPiece);
    const auto MinimumCm3 = Self.Get_Tuners().MinPortionMassKg * State.VolumeCm3 / State.MassKg;
    return Math::Min(MinimumCm3, utils_foodpiece::k_MaxPortionVolumeCm3);
}

// The ledger holding the piece (FMars_Fragment_FoodPiece_Holder); invalid while none does, or once it is gone.
mixin FCk_Handle TryGet_Holder(const FCk_Handle_FoodPiece& Self)
{
    if (ck::Is_NOT_Valid(Self) || Self.Has_Fragment(FMars_Fragment_FoodPiece_Holder) == false)
    { return FCk_Handle(); }

    const auto Owner = Self.Get_Fragment(FMars_Fragment_FoodPiece_Holder).Owner;
    if (ck::Is_NOT_Valid(Owner))
    { return FCk_Handle(); }

    return Owner;
}

// The ledger holding the piece as the authority published it: the replicated ledger's holder while it says Held, else
// invalid; invalid for a piece without a replicated ledger. A client reads the authority's holder only through this.
mixin FCk_Handle TryGet_ReplicatedHolder(const FCk_Handle_FoodPiece& Self)
{
    const auto Ledger = utils_foodpiece::TryGet_Ledger(Self);
    if (Ledger.IsSet() == false || Ledger.GetValue().Holding != EMars_FoodPiece_Holding::Held)
    { return FCk_Handle(); }

    return Ledger.GetValue().Holder;
}

// How many drains set the piece's cook state, as the replicated ledger says (0 while never cooked, and for a piece without
// a replicated ledger).
mixin int32 Get_CookSerial(const FCk_Handle_FoodPiece& Self)
{
    const auto Ledger = utils_foodpiece::TryGet_Ledger(Self);
    if (Ledger.IsSet() == false)
    { return 0; }

    return Ledger.GetValue().CookSerial;
}

// How this copy's geometry compared with the authority's numbers (utils_foodpiece::Update_CheckResult); Unchecked on the
// authority and for a piece without a replicated ledger.
mixin EMars_FoodPiece_CheckResult Get_CheckResult(const FCk_Handle_FoodPiece& Self)
{
    if (Self.Has_Fragment(FMars_Fragment_FoodPiece_Local) == false)
    { return EMars_FoodPiece_CheckResult::Unchecked; }

    return Self.Get_Fragment(FMars_Fragment_FoodPiece_Local).CheckResult;
}

// Whether this copy shows the piece (the Succession processor rules); Current on the authority and for a piece without a
// replicated ledger.
mixin EMars_FoodPiece_Standing Get_Standing(const FCk_Handle_FoodPiece& Self)
{
    if (Self.Has_Fragment(FMars_Fragment_FoodPiece_Local) == false)
    { return EMars_FoodPiece_Standing::Current; }

    return Self.Get_Fragment(FMars_Fragment_FoodPiece_Local).Standing;
}

//--------------------------------------------------------------------------------------------------------------------------
// Requests
//--------------------------------------------------------------------------------------------------------------------------

mixin void Request_Cut(FCk_Handle_FoodPiece& Self, const FMars_Request_FoodPiece_Cut& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_FoodPiece_Requests);
    Requests.CutRequests.Add(InRequest);
}

mixin void Request_SetCookState(FCk_Handle_FoodPiece& Self, const FMars_Request_FoodPiece_SetCookState& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_FoodPiece_Requests);
    Requests.SetCookStateRequests.Add(InRequest);
}

//--------------------------------------------------------------------------------------------------------------------------
// Signal Binding
//--------------------------------------------------------------------------------------------------------------------------

mixin void BindTo_OnReady(FCk_Handle_FoodPiece& Self, FMars_Delegate_FoodPiece_OnReady InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_FoodPiece_Signals);
    Fragment.OnReady.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnReady(FCk_Handle_FoodPiece& Self, FMars_Delegate_FoodPiece_OnReady InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_FoodPiece_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_FoodPiece_Signals).OnReady.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void BindTo_OnFailed(FCk_Handle_FoodPiece& Self, FMars_Delegate_FoodPiece_OnFailed InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_FoodPiece_Signals);
    Fragment.OnFailed.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnFailed(FCk_Handle_FoodPiece& Self, FMars_Delegate_FoodPiece_OnFailed InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_FoodPiece_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_FoodPiece_Signals).OnFailed.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void BindTo_OnCutResolved(FCk_Handle_FoodPiece& Self, FMars_Delegate_FoodPiece_OnCutResolved InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_FoodPiece_Signals);
    Fragment.OnCutResolved.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnCutResolved(FCk_Handle_FoodPiece& Self, FMars_Delegate_FoodPiece_OnCutResolved InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_FoodPiece_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_FoodPiece_Signals).OnCutResolved.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void BindTo_OnCookStateChanged(FCk_Handle_FoodPiece& Self, FMars_Delegate_FoodPiece_OnCookStateChanged InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_FoodPiece_Signals);
    Fragment.OnCookStateChanged.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnCookStateChanged(FCk_Handle_FoodPiece& Self, FMars_Delegate_FoodPiece_OnCookStateChanged InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_FoodPiece_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_FoodPiece_Signals).OnCookStateChanged.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void BindTo_OnStandingChanged(FCk_Handle_FoodPiece& Self, FMars_Delegate_FoodPiece_OnStandingChanged InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_FoodPiece_Signals);
    Fragment.OnStandingChanged.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnStandingChanged(FCk_Handle_FoodPiece& Self, FMars_Delegate_FoodPiece_OnStandingChanged InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_FoodPiece_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_FoodPiece_Signals).OnStandingChanged.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}
