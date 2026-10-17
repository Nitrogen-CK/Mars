// The expedition's harvest is actual cookable food. The existing vine owns strike/knock, yield and regrowth;
// this bed only supplies its yield and its project-art presentation on the authored stone planter.
class UMars_Expedition_MushroomBed_EntityScript : UMars_ForageVine_EntityScript
{
    // The strike centre clears the planter lip. The mesh's base stays planted on the authored soil surface.
    default HangHeight = 35.0f;
    default FruitRadius = 22.0f;
    default RegrowSeconds = 180.0f;

    protected TSoftObjectPtr<UCk_InventoryItem_Definition> Get_YieldDefinition() const override
    { return TSoftObjectPtr<UCk_InventoryItem_Definition>(mars_items::Food_Mushroom()); }

    protected void AddVisuals(FCk_Handle_Transform& InRoot, FCk_Handle_Transform& InFruit) override
    {
        _FruitMesh = InFruit.Add_MeshPart(this, FMars_MeshPart(
            FTransform(FRotator::ZeroRotator, FVector(0.0, 0.0, -35.0), FVector::OneVector * 4.0),
            assets::load::Mushroom_Mars_SM(), nullptr, collision::profile::NoCollision, n"ExpeditionHarvest_Mushroom"));
    }
}
