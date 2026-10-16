// One lock a key-lock test builds: where it stands, the key it takes, whether that key comes back out, and the channel its
// source asserts (unset = no source).
struct FMars_AutoTestRig_KeyLockSetup
{
    FVector Location = FVector::ZeroVector;
    FGameplayTag AcceptedKey;
    EMars_KeyLock_Release Release = EMars_KeyLock_Release::Kept;
    FGameplayTag Channel;

    FMars_AutoTestRig_KeyLockSetup() {}

    FMars_AutoTestRig_KeyLockSetup(FVector InLocation, FGameplayTag InAcceptedKey, EMars_KeyLock_Release InRelease, FGameplayTag InChannel)
    {
        Location = InLocation;
        AcceptedKey = InAcceptedKey;
        Release = InRelease;
        Channel = InChannel;
    }
}

// The key-lock tests' rig: the carrier rig (Hotbar, HeldItem, seeded holders) plus locks built from the kernel the way
// UMars_KeyLock_EntityScript composes them - a root, a key mount, an interactable with the lock's target, the lock and an
// optional source - without its meshes. Each test asserts channels no other test uses, since tests share the world's driver.
UCLASS(Abstract)
class UMars_AutoTestRig_KeyLock : UMars_AutoTestRig_Carrier
{
    protected FCk_Handle_KeyLock MakeLock(FCk_Handle InHandle, const FMars_AutoTestRig_KeyLockSetup& InSetup)
    {
        auto LockEntity = utils_entity_lifetime::Request_CreateEntity(InHandle);
        auto LockRoot = utils_transform::Add(LockEntity, FTransform(FRotator::ZeroRotator, InSetup.Location), ECk_Replication::DoesNotReplicate);
        auto KeyMount = utils_scene_node::Create(LockRoot, FTransform(FRotator(-90.0, 0.0, 0.0), FVector(0.0, 0.0, 14.0))).As_Transform();

        auto Probe = FMars_Interactable_ProbeInfo();
        Probe.ProbeSpec = FCk_Probe_Spec(GameplayTags::Probe_Mars_Interact);
        Probe.ProbeShape = utils_shapes::Make_Box(FCk_ShapeBox_Dimensions(FVector(30.0, 30.0, 20.0)));

        auto InteractableSpec = FMars_Interactable_Spec();
        InteractableSpec.ProbeInfo = Probe;
        InteractableSpec.Targets.Add(utils_key_lock::Make_InteractTarget());

        auto Spec = FMars_KeyLock_Spec();
        Spec.AcceptedKey = InSetup.AcceptedKey;
        Spec.Release = InSetup.Release;
        Spec.KeyMount = KeyMount;
        Spec.Interactable = utils_interactable::Create(LockRoot, InteractableSpec);

        FCk_Handle LockHandle = LockEntity;
        auto Lock = utils_key_lock::Add(LockHandle, Spec);

        if (InSetup.Channel.IsValid())
        {
            auto SourceSpec = FMars_MechanismSource_Spec();
            SourceSpec.OutputChannel = InSetup.Channel;
            utils_mechanism_source::Add(LockHandle, SourceSpec);
        }

        return Lock;
    }

    // InLock's source is asserted; false when it has none.
    protected bool Get_IsSourceAsserted(const FCk_Handle_KeyLock& InLock) const
    {
        const auto Source = InLock.As_MechanismSource(ECk_SanityCheck::UnChecked);
        return ck::IsValid(Source) && Source.Get_IsAsserted();
    }
}
