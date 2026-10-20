// How a food piece wears its look (the 14 cook-state floats a station or a definition hands it): its RuntimeMesh display,
// and, once the look says battered on a whole piece of a batterable food, the battered shell its food shows in the
// display's place. Beside UMars_Food_Def (which dresses a piece with it), so no food layer depends on a station script.

namespace constants_food
{
    // The scene node under a piece that carries its battered shell.
    const FName k_BatteredShellTag = n"TAG_MarsBatteredShell";
}

namespace utils_food
{
    // The battered shell Write_Look made under InPiece; invalid while it wears none.
    FCk_Handle_UnrealComponent TryGet_BatteredShell(FCk_Handle_FoodPiece InPiece)
    {
        FCk_Handle Entity = InPiece;
        for (auto Dependent : utils_entity_lifetime::Get_LifetimeDependents(Entity))
        {
            if (ck::Is_NOT_Valid(Dependent) || utils_entity_tag::Has(Dependent, constants_food::k_BatteredShellTag) == false)
            { continue; }

            const auto Components = utils_unreal_component::Get_AllHandles(Dependent);
            if (Components.Num() > 0)
            { return Components[0]; }
        }

        return FCk_Handle_UnrealComponent();
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
// dressed yet), which wears nothing.
mixin bool Write_Look(const FCk_Handle_FoodPiece& Self, const FMars_CookState& InLook)
{
    FCk_Handle Entity = Self;
    if (Entity.Is_RuntimeMeshDisplay() == false)
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
