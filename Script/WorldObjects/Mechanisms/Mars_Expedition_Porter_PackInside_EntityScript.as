// Matches the expedition's 6 x 4 m freight reliquary. A pack anywhere inside keeps the existing grace circuit alive;
// a pack outside its walls cannot power it. The interior rescue chain remains reachable without the pack. The gauntlet's
// pack volume on the same channel, sized to the reliquary.
class UMars_Expedition_Porter_PackInside_EntityScript : UMars_Gauntlet_Porter_PackInside_EntityScript
{
    default _ShowInPlaceActors = true;

    protected FVector Get_BoxHalfExtents() const override
    {
        return FVector(280.0, 175.0, 60.0);
    }
}
