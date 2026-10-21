// Placeable Bellkeeper clue: a plaque showing Phrase left to right, each glyph on a dial-face disc so it reads as "this
// dial, this glyph". Static: no controls, no state. The origin is the mounting surface and the plaque faces local +Z, up =
// local -X (pitch -90 to face +X on a wall), the first glyph on the viewer's left (local +Y), as on the dial panel.
class UMars_BellkeeperClue_EntityScript : UCk_GenericEntityScript_UE
{
    default _ShowInPlaceActors = true;
    default _Replication = ECk_Replication::DoesNotReplicate;

    UPROPERTY(ExposeOnSpawn)
    FTransform SpawnTransform = FTransform::Identity;

    UPROPERTY(ExposeOnSpawn)
    TArray<EMars_Bellkeeper_Glyph> Phrase;

    // Across one glyph, in cm; the discs and spacing scale with it.
    UPROPERTY(ExposeOnSpawn)
    float32 GlyphSize = 40.0f;

    UFUNCTION(BlueprintOverride)
    ECk_EntityScript_ConstructionFlow DoConstruct(FCk_Handle& InHandle)
    {
        auto Root = utils_transform::Add(InHandle, SpawnTransform, ECk_Replication::DoesNotReplicate);

        const auto Spacing = GlyphSize * 1.8;
        const auto Disc = GlyphSize * 1.5;
        const auto Thickness = 4.0;
        const auto Width = Math::Max(Phrase.Num(), 1) * Spacing + GlyphSize * 0.4;

        // Engine shapes are 100 uu with centered pivots.
        Root.Add_MeshPart(this, FMars_MeshPart(
            FTransform(FRotator::ZeroRotator, FVector(0.0, 0.0, Thickness * 0.5), FVector(Disc + GlyphSize * 0.3, Width, Thickness) * 0.01),
            engine::load::Cube(), assets::load::ProtoGrid_Wall_Mars_MI(), collision::profile::NoCollision, n"BellkeeperClue_Plaque"));

        const auto FirstY = (Phrase.Num() - 1) * Spacing * 0.5;
        for (int32 Index = 0; Index < Phrase.Num(); ++Index)
        {
            const auto Center = FVector(0.0, FirstY - Index * Spacing, Thickness);

            auto DiscPart = FMars_MeshPart(FTransform(FRotator::ZeroRotator, Center + FVector(0.0, 0.0, 0.5), FVector(Disc, Disc, 1.0) * 0.01),
                engine::load::Cylinder(), assets::load::ProtoGrid_Wall_Mars_MI(), collision::profile::NoCollision, n"BellkeeperClue_Disc");
            DiscPart.PrimaryColor = TOptional<FLinearColor>(FLinearColor(0.08f, 0.07f, 0.06f, 1.0f));
            Root.Add_MeshPart(this, DiscPart);

            Root.Add_BellkeeperGlyph(this, FMars_Bellkeeper_GlyphPlacement(Phrase[Index], Center + FVector(0.0, 0.0, 1.0), GlyphSize));
        }

        return ECk_EntityScript_ConstructionFlow::Finished;
    }
}
