#include "Mars_CharacterMovementComponent.h"

#include "Net/UnrealNetwork.h"

// -------------------------------------------------------------------------------------------------

void UMars_CharacterMovementComponent::SetExternalMultipliers(float InSpeed, float InAccel, float InBrake)
{
	_ExternalSpeedMultiplier = FMath::Max(InSpeed, 0.0f);
	_ExternalAccelMultiplier = FMath::Max(InAccel, 0.0f);
	_ExternalBrakeMultiplier = FMath::Max(InBrake, 0.0f);
}

void UMars_CharacterMovementComponent::ResetExternalMultipliers()
{
	_ExternalSpeedMultiplier = 1.0f;
	_ExternalAccelMultiplier = 1.0f;
	_ExternalBrakeMultiplier = 1.0f;
}

bool UMars_CharacterMovementComponent::HasExternalMultipliers() const
{
	return !FMath::IsNearlyEqual(_ExternalSpeedMultiplier, 1.0f)
		|| !FMath::IsNearlyEqual(_ExternalAccelMultiplier, 1.0f)
		|| !FMath::IsNearlyEqual(_ExternalBrakeMultiplier, 1.0f);
}

float UMars_CharacterMovementComponent::GetExternalSpeedMultiplier() const
{
	return _ExternalSpeedMultiplier;
}

float UMars_CharacterMovementComponent::GetMaxSpeed() const
{
	return Super::GetMaxSpeed() * _ExternalSpeedMultiplier;
}

float UMars_CharacterMovementComponent::GetMaxAcceleration() const
{
	return Super::GetMaxAcceleration() * _ExternalAccelMultiplier;
}

float UMars_CharacterMovementComponent::GetMaxBrakingDeceleration() const
{
	return Super::GetMaxBrakingDeceleration() * _ExternalBrakeMultiplier;
}

void UMars_CharacterMovementComponent::GetLifetimeReplicatedProps(TArray<FLifetimeProperty>& OutLifetimeProps) const
{
	Super::GetLifetimeReplicatedProps(OutLifetimeProps);

	DOREPLIFETIME(UMars_CharacterMovementComponent, _ExternalSpeedMultiplier);
	DOREPLIFETIME(UMars_CharacterMovementComponent, _ExternalAccelMultiplier);
	DOREPLIFETIME(UMars_CharacterMovementComponent, _ExternalBrakeMultiplier);
}

// -------------------------------------------------------------------------------------------------

bool UMars_CharacterMovementComponent::IsWithinClientAuthRadius(const FVector& ClientWorldLocation) const
{
	if (ClientAuthMaxError <= 0.0f)
	{
		return false;
	}

	const FVector LocDiff = UpdatedComponent->GetComponentLocation() - ClientWorldLocation;
	return LocDiff.SizeSquared() <= FMath::Square(ClientAuthMaxError);
}

bool UMars_CharacterMovementComponent::ServerShouldUseAuthoritativePosition(
	float ClientTimeStamp,
	float DeltaTime,
	const FVector& Accel,
	const FVector& ClientWorldLocation,
	const FVector& RelativeClientLocation,
	UPrimitiveComponent* ClientMovementBase,
	FName ClientBaseBoneName,
	uint8 ClientMovementMode)
{
	if (IsWithinClientAuthRadius(ClientWorldLocation))
	{
		return true;
	}

	return Super::ServerShouldUseAuthoritativePosition(
		ClientTimeStamp, DeltaTime, Accel,
		ClientWorldLocation, RelativeClientLocation,
		ClientMovementBase, ClientBaseBoneName, ClientMovementMode);
}

bool UMars_CharacterMovementComponent::ServerExceedsAllowablePositionError(
	float ClientTimeStamp,
	float DeltaTime,
	const FVector& Accel,
	const FVector& ClientWorldLocation,
	const FVector& RelativeClientLocation,
	UPrimitiveComponent* ClientMovementBase,
	FName ClientBaseBoneName,
	uint8 ClientMovementMode)
{
	if (IsWithinClientAuthRadius(ClientWorldLocation))
	{
		return false;
	}

	return Super::ServerExceedsAllowablePositionError(
		ClientTimeStamp, DeltaTime, Accel,
		ClientWorldLocation, RelativeClientLocation,
		ClientMovementBase, ClientBaseBoneName, ClientMovementMode);
}
