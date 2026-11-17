#include "Mars_CharacterMovementComponent.h"

#include "Components/PrimitiveComponent.h"
#include "Engine/ReplicatedState.h"
#include "GameFramework/Character.h"
#include "Net/UnrealNetwork.h"

// -------------------------------------------------------------------------------------------------

FMars_CharacterNetworkMoveDataContainer::FMars_CharacterNetworkMoveDataContainer()
{
	NewMoveData = &_MoveData[0];
	PendingMoveData = &_MoveData[1];
	OldMoveData = &_MoveData[2];
}

void FMars_CharacterNetworkMoveData::ClientFillNetworkMoveData(const FSavedMove_Character& ClientMove, ENetworkMoveType MoveType)
{
	FCharacterNetworkMoveData::ClientFillNetworkMoveData(ClientMove, MoveType);

	if (MovementBase == nullptr || UMars_CharacterMovementComponent::Get_CanBaseCrossTheNetwork(*MovementBase))
	{ return; }

	Location = FRepMovement::RebaseOntoZeroOrigin(ClientMove.SavedLocation, ClientMove.CharacterOwner->GetCharacterMovement());
	Acceleration = ClientMove.Acceleration;
	MovementBase = nullptr;
	MovementBaseBoneName = NAME_None;
}

// -------------------------------------------------------------------------------------------------

UMars_CharacterMovementComponent::UMars_CharacterMovementComponent(const FObjectInitializer& ObjectInitializer)
	: Super(ObjectInitializer)
{
	SetNetworkMoveDataContainer(_NetworkMoveDataContainer);
}

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
	FMars_ClientMovementBase* ClientMovementBase,
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
	FMars_ClientMovementBase* ClientMovementBase,
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

// -------------------------------------------------------------------------------------------------

bool UMars_CharacterMovementComponent::Get_CanBaseCrossTheNetwork(const UPrimitiveComponent& InBase)
{
	if (InBase.IsFullNameStableForNetworking())
	{ return true; }

	const AActor* Owner = InBase.GetOwner();
	if (Owner == nullptr || Owner->GetIsReplicated() == false)
	{ return false; }

	return InBase.GetIsReplicated() || InBase.IsNameStableForNetworking();
}

FMars_CharacterMovement_NetCounts UMars_CharacterMovementComponent::Get_NetCounts() const
{
	return _NetCounts;
}

TArray<FMars_CharacterMovement_NetEvent> UMars_CharacterMovementComponent::Get_NetEvents() const
{
	return TArray<FMars_CharacterMovement_NetEvent>(_NetEvents);
}

void UMars_CharacterMovementComponent::Record_NetEvent(
	EMars_CharacterMovement_NetEventKind InKind,
	const FVector& InLocation,
	const FVector& InOther,
	EMovementMode InMode)
{
	if (_NetEvents.Num() >= k_NetEventCapacity)
	{ _NetEvents.RemoveAt(0); }

	auto& Event = _NetEvents.AddDefaulted_GetRef();
	Event.Frame = static_cast<int64>(GFrameCounter);
	Event.Kind = InKind;
	Event.Location = InLocation;
	Event.Other = InOther;
	Event.Mode = InMode;
}

void UMars_CharacterMovementComponent::OnTeleported()
{
	Super::OnTeleported();

	const auto Location = UpdatedComponent != nullptr ? UpdatedComponent->GetComponentLocation() : FVector::ZeroVector;
	Record_NetEvent(EMars_CharacterMovement_NetEventKind::Teleported, Location, FVector::ZeroVector, MovementMode);
}

void UMars_CharacterMovementComponent::OnMovementModeChanged(EMovementMode PreviousMovementMode, uint8 PreviousCustomMode)
{
	Super::OnMovementModeChanged(PreviousMovementMode, PreviousCustomMode);

	const auto Location = UpdatedComponent != nullptr ? UpdatedComponent->GetComponentLocation() : FVector::ZeroVector;
	Record_NetEvent(EMars_CharacterMovement_NetEventKind::ModeChanged, Location, FVector::ZeroVector, MovementMode);
}

void UMars_CharacterMovementComponent::ServerMoveHandleClientError(
	float ClientTimeStamp,
	float DeltaTime,
	const FVector& Accel,
	const FVector& RelativeClientLocation,
	UPrimitiveComponent* ClientMovementBase,
	FName ClientBaseBoneName,
	uint8 ClientMovementMode)
{
	// The owner's place exactly as the engine's check reads it.
	auto ClientLocation = FVector::ZeroVector;
	if (MovementBaseUtility::UseRelativeLocation(ClientMovementBase))
	{ MovementBaseUtility::TransformLocationToWorld(ClientMovementBase, ClientBaseBoneName, RelativeClientLocation, ClientLocation); }
	else
	{ ClientLocation = FRepMovement::RebaseOntoLocalOrigin(RelativeClientLocation, this); }

	_NetCounts.ClientMovesReceived += 1;
	if (ClientMovementBase != nullptr)
	{ _NetCounts.ClientMovesWithBase += 1; }

	if (UpdatedComponent != nullptr)
	{
		const auto Error = static_cast<float>(FVector::Dist(UpdatedComponent->GetComponentLocation(), ClientLocation));
		_NetCounts.LargestClientError = FMath::Max(_NetCounts.LargestClientError, Error);
	}

	Super::ServerMoveHandleClientError(
		ClientTimeStamp, DeltaTime, Accel, RelativeClientLocation,
		ClientMovementBase, ClientBaseBoneName, ClientMovementMode);

	FNetworkPredictionData_Server_Character* ServerData = GetPredictionData_Server_Character();
	if (ServerData == nullptr)
	{ return; }

	// Only a correction this call made is read: an early return inside the engine's handler leaves an older one
	// pending, and the engine never clears NewBase, so an older adjustment may name a component that no longer exists.
	FClientAdjustment& Adjustment = ServerData->PendingAdjustment;
	if (Adjustment.bAckGoodMove || Adjustment.TimeStamp != ClientTimeStamp)
	{ return; }

	_NetCounts.CorrectionsMade += 1;
	const auto ServerLocation = UpdatedComponent != nullptr ? UpdatedComponent->GetComponentLocation() : FVector::ZeroVector;
	Record_NetEvent(EMars_CharacterMovement_NetEventKind::CorrectionMade, ServerLocation, ClientLocation, MovementMode);

	UPrimitiveComponent* Base = Adjustment.NewBase;
	if (Base == nullptr || Get_CanBaseCrossTheNetwork(*Base))
	{ return; }

	// The owner drops a correction relative to a base it cannot resolve (ClientAdjustPosition_Implementation), and a
	// base this machine built for itself resolves nowhere else: send the place and the velocity in world space with no
	// base, and the owner finds its own floor at that place.
	if (Adjustment.bBaseRelativePosition)
	{
		auto WorldLocation = FVector::ZeroVector;
		MovementBaseUtility::TransformLocationToWorld(Base, Adjustment.NewBaseBoneName, Adjustment.NewLoc, WorldLocation);
		Adjustment.NewLoc = FRepMovement::RebaseOntoZeroOrigin(WorldLocation, this);
	}

	if (Adjustment.bBaseRelativeVelocity)
	{
		auto WorldVelocity = FVector::ZeroVector;
		MovementBaseUtility::TransformDirectionToWorld(Base, Adjustment.NewBaseBoneName, Adjustment.NewVel, WorldVelocity);
		Adjustment.NewVel = WorldVelocity;
	}

	Adjustment.NewBase = nullptr;
	Adjustment.NewBaseBoneName = NAME_None;
	Adjustment.bBaseRelativePosition = false;
	Adjustment.bBaseRelativeVelocity = false;
}

void UMars_CharacterMovementComponent::ClientAdjustPosition_Implementation(
	float TimeStamp,
	FVector NewLoc,
	FVector NewVel,
	UPrimitiveComponent* NewBase,
	FName NewBaseBoneName,
	bool bHasBase,
	bool bBaseRelativePosition,
	uint8 ServerMovementMode,
	TOptional<FRotator> OptionalRotation)
{
	TEnumAsByte<EMovementMode> NetMovementMode(MOVE_None);
	TEnumAsByte<EMovementMode> NetGroundMode(MOVE_None);
	uint8 NetCustomMode = 0;
	UnpackNetworkMovementMode(ServerMovementMode, NetMovementMode, NetCustomMode, NetGroundMode);

	_NetCounts.CorrectionsReceived += 1;
	if (bHasBase && NewBase == nullptr && bBaseRelativePosition)
	{
		_NetCounts.CorrectionsDropped += 1;
		Record_NetEvent(EMars_CharacterMovement_NetEventKind::CorrectionDropped, NewLoc, FVector::ZeroVector, NetMovementMode);
	}
	else
	{
		auto WorldLocation = FVector::ZeroVector;
		if (bBaseRelativePosition)
		{ MovementBaseUtility::TransformLocationToWorld(NewBase, NewBaseBoneName, NewLoc, WorldLocation); }
		else
		{ WorldLocation = FRepMovement::RebaseOntoLocalOrigin(NewLoc, this); }

		Record_NetEvent(EMars_CharacterMovement_NetEventKind::CorrectionTaken, WorldLocation, FVector::ZeroVector, NetMovementMode);
	}

	Super::ClientAdjustPosition_Implementation(
		TimeStamp, NewLoc, NewVel, NewBase, NewBaseBoneName,
		bHasBase, bBaseRelativePosition, ServerMovementMode, OptionalRotation);
}
