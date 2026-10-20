// The shared plumbing of the dressing actors that lay chain links (AMars_HangingChain, AMars_HangingRack): the pitch of
// interlocking links, the Jolt static-world bake opt-out, and the editor-only lookup of the kit meshes. It holds no
// property of its own: each actor keeps its placed fields.
UCLASS(Abstract)
class AMars_LinkDressing : AActor
{
    default bReplicates = false;

    protected const FName JoltNoBakeTag = n"Ck.Jolt.NoBake";
    protected const FString KitMeshFolder = "/Game/Mars/Environment/Meshes/Crypt";

    // Centre-to-centre distance of interlocking links: the mesh's length along X at InScale, less InOverlap; the overlap
    // never eats more than half a link, so a short fallback link still reads as a chain.
    protected float Get_LinkPitchOf(UStaticMesh InMesh, FVector InScale, float32 InOverlap) const
    {
        const float MeshLength = 2.0 * InMesh.GetBounds().BoxExtent.X * InScale.X;
        return Math::Max(MeshLength - float(InOverlap), Math::Max(MeshLength * 0.5, 1.0));
    }

    // InPrimitive blocks and is baked into the Jolt static world, or has no collision and is left out of the bake (a
    // colliding primitive's instances feed the Jolt cook hash: every edit then needs a static-world re-cook).
    protected void Apply_Collides(UPrimitiveComponent InPrimitive, bool InCollides)
    {
        if (InCollides)
        {
            InPrimitive.SetCollisionProfileName(collision::profile::BlockAll);
            InPrimitive.ComponentTags.Remove(JoltNoBakeTag);
            return;
        }

        InPrimitive.SetCollisionProfileName(collision::profile::NoCollision);
        InPrimitive.ComponentTags.AddUnique(JoltNoBakeTag);
    }

    protected void Apply_ActorBaked(bool InBaked)
    {
        if (InBaked)
        { Tags.Remove(JoltNoBakeTag); }
        else
        { Tags.AddUnique(JoltNoBakeTag); }
    }

    // InFolder/InName, looked up only in the editor world (a missing package must not log: it fails automation runs, and
    // the editor asset library refuses play worlds). Null in a game world, outside the editor, or when it is absent; the
    // caller keeps what it found on its property so PIE and cooked builds never look it up.
    protected UStaticMesh TryLoad_EditorMesh(const FString& InFolder, const FString& InName)
    {
#if EDITOR
        auto OwningWorld = GetWorld();
        if (ck::Is_NOT_Valid(OwningWorld) || OwningWorld.IsGameWorld())
        { return nullptr; }

        const FString PackagePath = f"{InFolder}/{InName}";
        if (EditorAsset::DoesAssetExist(PackagePath) == false)
        { return nullptr; }

        return Cast<UStaticMesh>(LoadObject(this, f"{PackagePath}.{InName}"));
#else
        return nullptr;
#endif
    }
}
