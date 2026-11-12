// How a food piece wears its look (the 14 cook-state floats a station or a definition hands it): its RuntimeMesh display,
// and, once the look says battered on a whole piece of a batterable food, the battered shell its food shows in the
// display's place. Beside UMars_Food_Def (which dresses a piece with it), so no food layer depends on a station script.

namespace constants_food
{
    // The scene node under a piece that carries its battered shell.
    const FName k_BatteredShellTag = n"TAG_MarsBatteredShell";

    // The scene node under an entity whose replay built nothing that carries the food's mesh in its place.
    const FName k_StandInTag = n"TAG_MarsFoodStandIn";
}

namespace utils_food
{
    // The first component on a lifetime dependent of InEntity tagged InTag and not ending; invalid when there is none.
    FCk_Handle_UnrealComponent TryGet_TaggedComponent(FCk_Handle InEntity, FName InTag)
    {
        for (auto Dependent : utils_entity_lifetime::Get_LifetimeDependents(InEntity))
        {
            if (utils_foodpiece::Get_IsLiveEntity(Dependent) == false || utils_entity_tag::Has(Dependent, InTag) == false)
            { continue; }

            const auto Components = utils_unreal_component::Get_AllHandles(Dependent);
            if (Components.Num() > 0)
            { return Components[0]; }
        }

        return FCk_Handle_UnrealComponent();
    }

    // The stand-in Add_StandIn made under InEntity; invalid while it has none.
    FCk_Handle_UnrealComponent TryGet_StandIn(FCk_Handle InEntity)
    {
        return TryGet_TaggedComponent(InEntity, constants_food::k_StandInTag);
    }

    // InFood's mesh on a tagged scene node under InEntity, placed and scaled per axis so the mesh's own bounding box fills
    // InBoundsCm (in InEntity's frame), wearing the food's display materials on the mesh's slots, no collision. For an entity
    // whose cut piece could not be rebuilt: it shows where the piece is and how big, not its shape. The scale is the node's,
    // never the entity's (pieces stay unscaled). A mesh that does not load, or a flat box, ensures and adds nothing.
    FCk_Handle_UnrealComponent Add_StandIn(FCk_Handle InEntity, const UMars_Food_Def InFood, FBox InBoundsCm)
    {
        auto Mesh = System::LoadAsset_Blocking(InFood.Data.Mesh);
        if (ck::EnsureIfNot(ck::IsValid(Mesh),
            f"[Food] [{InFood.GetName()}] mesh [{InFood.Data.Mesh.ToSoftObjectPath().ToString()}] did not load: [{InEntity.ToString()}] has no stand-in"))
        { return FCk_Handle_UnrealComponent(); }

        const auto MeshBox = Mesh.GetBoundingBox();
        const auto MeshSize = MeshBox.Max - MeshBox.Min;
        const auto Size = InBoundsCm.Max - InBoundsCm.Min;
        const auto IsFillable = MeshSize.X > 0.0 && MeshSize.Y > 0.0 && MeshSize.Z > 0.0 && Size.X > 0.0 && Size.Y > 0.0 && Size.Z > 0.0;
        if (ck::EnsureIfNot(IsFillable,
            f"[Food] [{InFood.GetName()}] cannot fit its mesh box [{MeshSize.ToString()}] to [{Size.ToString()}]: [{InEntity.ToString()}] has no stand-in"))
        { return FCk_Handle_UnrealComponent(); }

        const auto Scale = FVector(Size.X / MeshSize.X, Size.Y / MeshSize.Y, Size.Z / MeshSize.Z);
        const auto Location = InBoundsCm.Min - FVector(MeshBox.Min.X * Scale.X, MeshBox.Min.Y * Scale.Y, MeshBox.Min.Z * Scale.Z);

        auto Entity = InEntity;
        auto Node = utils_scene_node::Create(Entity.As_Transform(), FTransform(FRotator::ZeroRotator, Location, Scale));
        utils_entity_tag::Add(Node.H(), constants_food::k_StandInTag);

        // A template the hosted component is instanced from; nothing keeps it once it has been.
        auto Archetype = NewObject(GetTransientPackage(), UStaticMeshComponent);
        Archetype.SetMobility(EComponentMobility::Movable);
        Archetype.SetStaticMesh(Mesh);
        // The display's last slots are the cap's; the mesh's own slots come first.
        const auto Materials = InFood.Visuals.Display.Get_Materials();
        const auto CapSlot = InFood.Visuals.Cap.Get_MaterialID();
        for (int32 Slot = 0; Slot < Materials.Num(); ++Slot)
        {
            if (Slot != CapSlot)
            { Archetype.SetMaterial(Slot, System::LoadAsset_Blocking(Materials[Slot])); }
        }

        Archetype.SetCollisionProfileName(collision::profile::NoCollision);

        const auto Params = utils_unreal_component::Make_Params_FromArchetype(Archetype, ECk_UnrealComponent_TickPolicy::DoNotTick, n"Food_StandIn");
        return utils_unreal_component::Add(Node.H(), Params);
    }

    // The battered shell Write_Look made under InPiece; invalid while it wears none.
    FCk_Handle_UnrealComponent TryGet_BatteredShell(FCk_Handle_FoodPiece InPiece)
    {
        return TryGet_TaggedComponent(InPiece, constants_food::k_BatteredShellTag);
    }

    // InPiece's food's battered mesh on a tagged scene node under the piece at its pivot offset (no collision: the piece's
    // RuntimeMesh stays its body), and InDisplay hidden. A battered mesh that does not load ensures, and the piece keeps
    // showing its display.
    FCk_Handle_UnrealComponent Add_BatteredShell(FCk_Handle_FoodPiece InPiece, FCk_Handle_RuntimeMeshDisplay InDisplay)
    {
        const UMars_Food_Def Food = InPiece.Get_Definition().Get();
        const auto Battered = Food.Visuals.Battered;
        auto Mesh = System::LoadAsset_Blocking(Battered.Mesh);
        if (ck::EnsureIfNot(ck::IsValid(Mesh),
            f"[Food] [{Food.GetName()}] battered mesh [{Battered.Mesh.ToSoftObjectPath().ToString()}] did not load: piece [{InPiece.ToString()}] keeps its display"))
        { return FCk_Handle_UnrealComponent(); }

        FCk_Handle Entity = InPiece;
        auto Node = utils_scene_node::Create(Entity.As_Transform(), FTransform(FRotator::ZeroRotator, Battered.PivotOffset));
        utils_entity_tag::Add(Node.H(), constants_food::k_BatteredShellTag);

        // A template the hosted component is instanced from; nothing keeps it once it has been.
        auto Archetype = NewObject(GetTransientPackage(), UStaticMeshComponent);
        // Movable: the component is registered first and then follows the piece.
        Archetype.SetMobility(EComponentMobility::Movable);
        Archetype.SetStaticMesh(Mesh);
        for (int32 Slot = 0; Slot < Battered.Materials.Num(); ++Slot)
        { Archetype.SetMaterial(Slot, System::LoadAsset_Blocking(Battered.Materials[Slot])); }
        Archetype.SetCollisionProfileName(collision::profile::NoCollision);

        const auto Params = utils_unreal_component::Make_Params_FromArchetype(Archetype, ECk_UnrealComponent_TickPolicy::DoNotTick, n"Food_BatteredShell");
        const auto Shell = utils_unreal_component::Add(Node.H(), Params);

        auto Display = InDisplay;
        Display.Request_SetVisibility(FCk_Request_RuntimeMeshDisplay_SetVisibility(ECk_EnableDisable::Disable), FCk_Delegate_Request_OnCompleted());
        return Shell;
    }
}

// The one place a piece's look (InLook) reaches what the piece wears: its RuntimeMesh display, and, while it is a battered
// whole piece of a batterable food (utils_batter::Get_IsBatterable), the battered shell its food shows in the display's
// place: made, and the display hidden, the first time the look says battered. Every write reaches both, so the shell and
// the hidden display always carry the same block. False for a piece without a display (a bare test piece, or one not
// dressed yet), which wears nothing, and for a superseded piece, which is never shown again (a cook state that arrives
// after it was replaced makes no shell).
mixin bool Write_Look(const FCk_Handle_FoodPiece& Self, const FMars_CookState& InLook)
{
    FCk_Handle Entity = Self;
    if (Entity.Is_RuntimeMeshDisplay() == false || Self.Get_Standing() == EMars_FoodPiece_Standing::Superseded)
    { return false; }

    auto Display = Entity.As_RuntimeMeshDisplay();
    utils_cookstate::Request_Write(Display, InLook);

    if (InLook.Battered < 0.5f || utils_batter::Get_IsBatterable(Self) == false)
    { return true; }

    auto Shell = utils_food::TryGet_BatteredShell(Self);
    if (ck::Is_NOT_Valid(Shell))
    { Shell = utils_food::Add_BatteredShell(Self, Display); }

    if (ck::IsValid(Shell))
    { utils_cookstate::Request_WriteComponent(Shell, InLook); }

    return true;
}

// Takes off everything the piece wears: its display hidden when it has one (a hide asked while the display's setup is
// pending applies with the setup, so it is never drawn), and its battered shell's node destroyed when it has one.
mixin void Hide_Worn(const FCk_Handle_FoodPiece& Self)
{
    FCk_Handle Entity = Self;
    if (Entity.Is_RuntimeMeshDisplay())
    {
        auto Display = Entity.As_RuntimeMeshDisplay();
        Display.Request_SetVisibility(FCk_Request_RuntimeMeshDisplay_SetVisibility(ECk_EnableDisable::Disable), FCk_Delegate_Request_OnCompleted());
    }

    for (auto Dependent : utils_entity_lifetime::Get_LifetimeDependents(Entity))
    {
        if (ck::IsValid(Dependent) && utils_entity_tag::Has(Dependent, constants_food::k_BatteredShellTag))
        { utils_entity_lifetime::Request_DestroyEntity(Dependent); }
    }
}
