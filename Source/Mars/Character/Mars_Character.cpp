#include "Mars_Character.h"

#include "Mars_CharacterMovementComponent.h"

#include "Components/PrimitiveComponent.h"
#include "Misc/EngineVersionComparison.h"

// -------------------------------------------------------------------------------------------------

AMars_Character::AMars_Character(const FObjectInitializer& ObjectInitializer)
	: Super(ObjectInitializer.SetDefaultSubobjectClass<UMars_CharacterMovementComponent>(
		ACharacter::CharacterMovementComponentName))
{
}

EMars_Character_NetBase AMars_Character::Get_NetBase() const
{
	if (HasAuthority())
	{
#if UE_VERSION_OLDER_THAN(5, 8, 0)
		const UObject* Base = GetBasedMovement().MovementBase;
#else
		const UObject* Base = GetBasedMovement().MovementBaseInterfaceData.PhysicsObjectOwner.Get();
#endif
		if (Base == nullptr)
		{ return EMars_Character_NetBase::None; }

		return UMars_CharacterMovementComponent::Get_CanBaseCrossTheNetwork(*Base)
			? EMars_Character_NetBase::Crossing
			: EMars_Character_NetBase::PerMachine;
	}

	const FBasedMovementInfo& Replicated = GetReplicatedBasedMovement();
	if (Replicated.IsBaseUnresolved())
	{ return EMars_Character_NetBase::Unresolved; }

#if UE_VERSION_OLDER_THAN(5, 8, 0)
	if (Replicated.MovementBase != nullptr)
#else
	if (Replicated.MovementBaseInterfaceData.IsValid())
#endif
	{ return EMars_Character_NetBase::Crossing; }

	return EMars_Character_NetBase::None;
}

bool AMars_Character::Get_HasMovementBase() const
{
#if UE_VERSION_OLDER_THAN(5, 8, 0)
	return GetMovementBase() != nullptr;
#else
	return GetMovementBaseObject() != nullptr;
#endif
}

// A simulated copy skips SimulateMovement while its replicated base is unresolved (the authority has a base and the
// reference did not arrive), so it neither applies the replicated movement mode nor finds a floor. A base this machine
// built for itself never resolves on another, so it is not reported: the copy then places itself from
// ReplicatedMovement in world space and finds its own floor. The authority keeps its real base; the struct written is
// the same on every pass, so it does not change while the base does not.
void AMars_Character::PreReplication(IRepChangedPropertyTracker& ChangedPropertyTracker)
{
	Super::PreReplication(ChangedPropertyTracker);

	FBasedMovementInfo& Replicated = GetReplicatedBasedMovement_Mutable();
#if UE_VERSION_OLDER_THAN(5, 8, 0)
	const UObject* Base = Replicated.MovementBase;
#else
	const UObject* Base = Replicated.MovementBaseInterfaceData.PhysicsObjectOwner.Get();
#endif
	if (Base == nullptr || UMars_CharacterMovementComponent::Get_CanBaseCrossTheNetwork(*Base))
	{ return; }

#if UE_VERSION_OLDER_THAN(5, 8, 0)
	Replicated.MovementBase = nullptr;
#else
	Replicated.MovementBaseInterfaceData.Clear();
	PRAGMA_DISABLE_DEPRECATION_WARNINGS
	Replicated.MovementBase = nullptr;
	PRAGMA_ENABLE_DEPRECATION_WARNINGS
#endif
	Replicated.BoneName = NAME_None;
	Replicated.bServerHasBaseComponent = false;
	Replicated.bRelativeRotation = false;
	Replicated.bServerHasVelocity = false;
	Replicated.Location = FVector::ZeroVector;
	Replicated.Rotation = FRotator::ZeroRotator;
}
