// The basin ring a forage source drops its yield into: four walls on the floor around the origin.
struct FMars_ForageBasin_Spec
{
    // Origin to each wall's centre line.
    UPROPERTY()
    float32 HalfWidth = 0.0f;

    UPROPERTY()
    float32 WallHeight = 40.0f;

    UPROPERTY()
    float32 WallThickness = 12.0f;

    FMars_ForageBasin_Spec() {}

    FMars_ForageBasin_Spec(float32 InHalfWidth)
    {
        HalfWidth = InHalfWidth;
    }

    FMars_ForageBasin_Spec(float32 InHalfWidth, float32 InWallHeight, float32 InWallThickness)
    {
        HalfWidth = InHalfWidth;
        WallHeight = InWallHeight;
        WallThickness = InWallThickness;
    }
}

// Adds the four walls under Self. They block: a collision-bearing mesh part bakes into the Jolt static world, so a
// dropped yield lands inside the ring. InOuter is the entity script building them (the Add_MeshPart archetype outer).
mixin void Add_ForageBasinRing(FCk_Handle_Transform& Self, UObject InOuter, const FMars_ForageBasin_Spec& InSpec)
{
    auto CubeMesh = engine::load::Cube();
    auto PlatformMaterial = assets::load::ProtoGrid_Platform_Mars_MI();
    const float64 HalfWidth = InSpec.HalfWidth;
    const float64 WallZ = InSpec.WallHeight * 0.5;
    const float64 WallLength = HalfWidth * 2.0 + InSpec.WallThickness;

    // Engine cube is 100 uu with its pivot at the centre.
    const auto AlongX = FVector(WallLength, InSpec.WallThickness, InSpec.WallHeight) * 0.01;
    const auto AlongY = FVector(InSpec.WallThickness, WallLength, InSpec.WallHeight) * 0.01;

    Self.Add_MeshPart(InOuter, FMars_MeshPart(FTransform(FRotator::ZeroRotator, FVector(0.0, HalfWidth, WallZ), AlongX),
        CubeMesh, PlatformMaterial, collision::profile::BlockAll, n"ForageBasin_North"));
    Self.Add_MeshPart(InOuter, FMars_MeshPart(FTransform(FRotator::ZeroRotator, FVector(0.0, -HalfWidth, WallZ), AlongX),
        CubeMesh, PlatformMaterial, collision::profile::BlockAll, n"ForageBasin_South"));
    Self.Add_MeshPart(InOuter, FMars_MeshPart(FTransform(FRotator::ZeroRotator, FVector(HalfWidth, 0.0, WallZ), AlongY),
        CubeMesh, PlatformMaterial, collision::profile::BlockAll, n"ForageBasin_East"));
    Self.Add_MeshPart(InOuter, FMars_MeshPart(FTransform(FRotator::ZeroRotator, FVector(-HalfWidth, 0.0, WallZ), AlongY),
        CubeMesh, PlatformMaterial, collision::profile::BlockAll, n"ForageBasin_West"));
}
