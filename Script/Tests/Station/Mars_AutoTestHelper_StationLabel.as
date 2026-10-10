// What a feed station's world label shows (UMars_FeedStation_EntityScript tags its label part TAG_MarsStationLabel); empty
// until the label's component exists. Every station's label carries the tag, so this station's is the one whose lifetime
// owners lead to it.
mixin FString Get_ShownLabel(const FCk_Handle_Station& Self)
{
    FCk_Handle Station = Self;
    for (auto Entity : utils_entity_tag::ForEach_Entity(Station, n"TAG_MarsStationLabel"))
    {
        auto Owner = utils_entity_lifetime::Get_LifetimeOwner(Entity);
        while (ck::IsValid(Owner) && Owner != Station && utils_entity_lifetime::Get_IsTransientEntity(Owner) == false)
        { Owner = utils_entity_lifetime::Get_LifetimeOwner(Owner); }

        if (Owner != Station)
        { continue; }

        auto Text = Cast<UTextRenderComponent>(utils_unreal_component::Get_Component(Entity.As_UnrealComponent()));
        if (ck::IsValid(Text))
        { return Text.Text.ToString(); }
    }

    return "";
}
