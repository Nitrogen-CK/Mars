// The Bellkeeper's glyphs, shared by its dial panel and its clue. A dial's ring runs in this order: index i points at glyph
// i on every dial, so a phrase of glyphs is also the lock's answer.
enum EMars_Bellkeeper_Glyph
{
    Square,
    Circle,
    // Apex toward the face's local -X: up when the face is pitched -90 onto a wall.
    Triangle,
    Diamond,
    Cross,
    // Three bars across the face's local Y.
    Bars
}

namespace constants_bellkeeper_glyphs
{
    const int32 k_Count = 6;
}

// One glyph lying flat on a face whose normal is local +Z (up = local -X), Center on that face.
struct FMars_Bellkeeper_GlyphPlacement
{
    EMars_Bellkeeper_Glyph Glyph = EMars_Bellkeeper_Glyph::Square;
    FVector Center = FVector::ZeroVector;
    // Across, in cm.
    float64 Size = 6.0;
    FLinearColor Color = FLinearColor(0.9f, 0.85f, 0.7f, 1.0f);

    FMars_Bellkeeper_GlyphPlacement() {}

    FMars_Bellkeeper_GlyphPlacement(EMars_Bellkeeper_Glyph InGlyph, FVector InCenter, float64 InSize)
    {
        Glyph = InGlyph;
        Center = InCenter;
        Size = InSize;
    }
}

// Builds InPlacement's glyph from engine primitives (100 uu, centered pivots), 1 cm proud of the face, on Self. Visual
// only: no collision.
mixin void Add_BellkeeperGlyph(FCk_Handle_Transform& Self, UObject InOuter, const FMars_Bellkeeper_GlyphPlacement& InPlacement)
{
    const auto S = InPlacement.Size * 0.01;
    const auto Thin = 0.01;
    const auto Center = InPlacement.Center + FVector(0.0, 0.0, 0.5);

    TArray<FTransform> Bars;
    auto Mesh = engine::load::Cube();
    switch (InPlacement.Glyph)
    {
        case EMars_Bellkeeper_Glyph::Square:
            Bars.Add(FTransform(FRotator::ZeroRotator, Center, FVector(S * 0.8, S * 0.8, Thin)));
            break;
        case EMars_Bellkeeper_Glyph::Circle:
            Mesh = engine::load::Cylinder();
            Bars.Add(FTransform(FRotator::ZeroRotator, Center, FVector(S, S, Thin)));
            break;
        case EMars_Bellkeeper_Glyph::Triangle:
            // Pitch 90 lays the cone's axis (its apex) along -X and its local X along the face normal, which Thin flattens.
            Mesh = engine::load::Cone();
            Bars.Add(FTransform(FRotator(90.0, 0.0, 0.0), Center, FVector(Thin, S * 1.1, S)));
            break;
        case EMars_Bellkeeper_Glyph::Diamond:
            Bars.Add(FTransform(FRotator(0.0, 45.0, 0.0), Center, FVector(S * 0.65, S * 0.65, Thin)));
            break;
        case EMars_Bellkeeper_Glyph::Cross:
            Bars.Add(FTransform(FRotator::ZeroRotator, Center, FVector(S, S * 0.25, Thin)));
            Bars.Add(FTransform(FRotator::ZeroRotator, Center, FVector(S * 0.25, S, Thin)));
            break;
        case EMars_Bellkeeper_Glyph::Bars:
            for (int32 Index = -1; Index <= 1; ++Index)
            { Bars.Add(FTransform(FRotator::ZeroRotator, Center + FVector(Index * InPlacement.Size * 0.35, 0.0, 0.0), FVector(S * 0.18, S, Thin))); }
            break;
    }

    for (const auto& Bar : Bars)
    {
        auto Part = FMars_MeshPart(Bar, Mesh, assets::load::ProtoGrid_Interactable_Mars_MI(), collision::profile::NoCollision, n"Bellkeeper_Glyph");
        Part.PrimaryColor = TOptional<FLinearColor>(InPlacement.Color);
        Part.CastShadow = false;
        Self.Add_MeshPart(InOuter, Part);
    }
}
