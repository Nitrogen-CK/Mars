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

        auto State = FMars_Fragment_FoodPiece();
        State.Id = InSpec.Data.Id.IsValid() ? InSpec.Data.Id : FGuid::NewGuid();
        State.ParentId = InSpec.Data.ParentId;
        State.Lineage = InSpec.Data.Lineage;
        if (State.Lineage.IsValid() == false)
        { State.Lineage = FGuid::NewGuid(); }

        State.MassKg = InSpec.Data.MassKg;
        State.CookState = InSpec.Data.CookState;
        State.Definition = InSpec.Data.Definition;
        State.Kind = InSpec.Data.Kind;

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
        return InHandle.As_FoodPiece();
    }

    // A Dynamic convex body of the piece's own mesh and mass with the piece's own surface (its Body tuners), on the piece's
    // entity: the one builder for a piece dropped onto a platter and a whole food item. The piece must be Ready (its
    // geometry gives the hull) and bodiless; the body reads the piece's transform as it is when the body is set up.
    FCk_Handle_JoltBody Add_Body(FCk_Handle_FoodPiece& InPiece)
    {
        FCk_Handle Entity = InPiece;
        const auto CanAdd = InPiece.Get_Status() == EMars_FoodPiece_Status::Ready && Entity.Is_JoltBody() == false;
        if (ck::EnsureIfNot(CanAdd, f"[FoodPiece] [{InPiece.ToString()}] gets a body only once Ready and bodiless (status [{InPiece.Get_Status() :n}], body [{Entity.Is_JoltBody()}])"))
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

    // Keeps what a machine without the slice needs to rebuild the piece (FMars_Fragment_FoodPiece_Replay).
    void Request_Replay(FCk_Handle& InHandle, const FMars_FoodPiece_ReplaySpec& InSpec)
    {
        InHandle.AddOrGet_Fragment(FMars_Fragment_FoodPiece_Replay).Spec = InSpec;
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
    // live holder other than InOwner here would put the piece in two ledgers (a defect); the newest admission wins.
    void Stamp_Holder(FCk_Handle_FoodPiece& InPiece, FCk_Handle InOwner)
    {
        const auto Holder = InPiece.TryGet_Holder();
        if (ck::EnsureIfNot(ck::Is_NOT_Valid(Holder) || Holder == InOwner,
            f"[FoodPiece] [{InPiece.ToString()}] is admitted by [{InOwner.ToString()}] while [{Holder.ToString()}] still holds it"))
        {
            InPiece.Get_Fragment(FMars_Fragment_FoodPiece_Holder).Owner = InOwner;
            return;
        }

        InPiece.AddOrGet_Fragment(FMars_Fragment_FoodPiece_Holder).Owner = InOwner;
    }

    // InOwner's ledger let InPiece go. A piece some other ledger holds by now keeps that holder. Called only by a ledger's
    // processor.
    void Clear_Holder(FCk_Handle_FoodPiece& InPiece, FCk_Handle InOwner)
    {
        if (ck::Is_NOT_Valid(InPiece) || InPiece.Has_Fragment(FMars_Fragment_FoodPiece_Holder) == false)
        { return; }

        if (InPiece.Get_Fragment(FMars_Fragment_FoodPiece_Holder).Owner != InOwner)
        { return; }

        InPiece.Request_TryRemove(FMars_Fragment_FoodPiece_Holder);
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
