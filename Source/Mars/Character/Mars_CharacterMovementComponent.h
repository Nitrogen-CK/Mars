#pragma once

#include "Engine/ReplicatedState.h"
#include "GameFramework/CharacterMovementComponent.h"
#include "GameFramework/CharacterMovementReplication.h"
#include "Misc/EngineVersionComparison.h"

#include "Mars_CharacterMovementComponent.generated.h"

// The client-movement-base parameter of the server position checks overridden below. UE 5.8 calls the
// FMovementBaseInterfaceData overloads; its UPrimitiveComponent overloads are deprecated and only forward to them, so
// overriding those on 5.8 compiles but is never called.
#if UE_VERSION_OLDER_THAN(5, 8, 0)
using FMars_ClientMovementBase = UPrimitiveComponent;
#else
using FMars_ClientMovementBase = FMovementBaseInterfaceData;
#endif

// A move whose base cannot reach the server as the same component is sent in world space with no base: the server
// would otherwise read the base-relative place as a world one
// (UCharacterMovementComponent::ServerMoveHandleClientError).
struct FMars_CharacterNetworkMoveData : public FCharacterNetworkMoveData
{
	virtual void ClientFillNetworkMoveData(const FSavedMove_Character& ClientMove, ENetworkMoveType MoveType) override;
};

struct FMars_CharacterNetworkMoveDataContainer : public FCharacterNetworkMoveDataContainer
{
	FMars_CharacterNetworkMoveDataContainer();

private:
	FMars_CharacterNetworkMoveData _MoveData[3];
};

// What a movement component recorded about the moves and corrections it exchanged; for tests and logs.
UENUM(BlueprintType)
enum class EMars_CharacterMovement_NetEventKind : uint8
{
	// This machine teleported the pawn (OnTeleported).
	Teleported,
	// The movement mode changed; Mode is the new one.
	ModeChanged,
	// Server: a move of the owner's ended in a correction. Other is the owner's place as the check read it.
	CorrectionMade,
	// Owner: a correction arrived and was applied. Location is the place it gave.
	CorrectionTaken,
	// Owner: a correction arrived relative to a base that does not resolve here and was dropped.
	CorrectionDropped
};

USTRUCT(BlueprintType)
struct MARS_API FMars_CharacterMovement_NetEvent
{
	GENERATED_BODY()

	// GFrameCounter: one counter for every world in the process.
	UPROPERTY(BlueprintReadOnly, Category = "Character Movement (Networking)")
	int64 Frame = 0;
	UPROPERTY(BlueprintReadOnly, Category = "Character Movement (Networking)")
	EMars_CharacterMovement_NetEventKind Kind = EMars_CharacterMovement_NetEventKind::Teleported;
	// The pawn's place after the event; for a correction taken or dropped, the place the correction gave in world
	// space (or its raw place when it was relative to a base that does not resolve).
	UPROPERTY(BlueprintReadOnly, Category = "Character Movement (Networking)")
	FVector Location = FVector::ZeroVector;
	// Server, CorrectionMade: the owner's place as the check read it.
	UPROPERTY(BlueprintReadOnly, Category = "Character Movement (Networking)")
	FVector Other = FVector::ZeroVector;
	UPROPERTY(BlueprintReadOnly, Category = "Character Movement (Networking)")
	TEnumAsByte<EMovementMode> Mode = MOVE_None;
};

USTRUCT(BlueprintType)
struct MARS_API FMars_CharacterMovement_NetCounts
{
	GENERATED_BODY()

	// Server: the owner's new moves that reached the error check, and those that named a base.
	UPROPERTY(BlueprintReadOnly, Category = "Character Movement (Networking)")
	int32 ClientMovesReceived = 0;
	UPROPERTY(BlueprintReadOnly, Category = "Character Movement (Networking)")
	int32 ClientMovesWithBase = 0;
	// Server: the checks that ended in a correction, and the largest distance (cm) the check read.
	UPROPERTY(BlueprintReadOnly, Category = "Character Movement (Networking)")
	int32 CorrectionsMade = 0;
	UPROPERTY(BlueprintReadOnly, Category = "Character Movement (Networking)")
	float LargestClientError = 0.0f;
	// Owner: the corrections that arrived, and those dropped because their base does not resolve here.
	UPROPERTY(BlueprintReadOnly, Category = "Character Movement (Networking)")
	int32 CorrectionsReceived = 0;
	UPROPERTY(BlueprintReadOnly, Category = "Character Movement (Networking)")
	int32 CorrectionsDropped = 0;
};

/**
 * Mars character movement for non-competitive co-op.
 *
 * Client-authority radius: while ClientAuthMaxError > 0 the server accepts the client's reported position without
 * correction as long as the two stay within that radius, which removes the jitter / rubber-banding latency causes. At
 * ClientAuthMaxError == 0 the behaviour is the stock UCharacterMovementComponent's.
 *
 * Replicated speed / acceleration / braking multipliers: the server sets them (SetExternalMultipliers) and every copy
 * applies them in GetMaxSpeed / GetMaxAcceleration / GetMaxBrakingDeceleration, so the server simulates the owner's
 * moves at the speed the owner runs. The player's sprint is the speed multiplier.
 */
UCLASS()
class MARS_API UMars_CharacterMovementComponent : public UCharacterMovementComponent
{
	GENERATED_BODY()

public:
	UMars_CharacterMovementComponent(const FObjectInitializer& ObjectInitializer = FObjectInitializer::Get());

	/**
	 * Maximum positional error (cm) the server tolerates before overriding the client. While > 0 the server treats the
	 * client's position as authoritative when the difference is within this radius. 0 = stock server-authoritative
	 * correction.
	 */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Character Movement (Networking)")
	float ClientAuthMaxError = 0.0f;

	/** Set the external multipliers. Server-only: the values replicate to clients. */
	UFUNCTION(BlueprintCallable, Category = "Character Movement")
	void SetExternalMultipliers(float InSpeed, float InAccel, float InBrake);

	/** Reset every external multiplier to 1.0. Server-only. */
	UFUNCTION(BlueprintCallable, Category = "Character Movement")
	void ResetExternalMultipliers();

	UFUNCTION(BlueprintPure, Category = "Character Movement")
	bool HasExternalMultipliers() const;

	UFUNCTION(BlueprintPure, Category = "Character Movement")
	float GetExternalSpeedMultiplier() const;

	// Whether a reference to InBase reaches the other machine as the same component. A component loaded with its level
	// has a stable path; any other is addressable only below a replicated actor, and only if it replicates or its
	// owner's class names it (ObjectReferenceCache::CreateObjectReferenceInternal). Any other reference is either not
	// created or resolved by a name the other machine need not share.
	static bool Get_CanBaseCrossTheNetwork(const UPrimitiveComponent& InBase);

	// A base that does not cross the network makes the server read a base-relative move as a world one
	// (ServerMoveHandleClientError), or the owner drop a correction relative to a base it cannot resolve
	// (ClientAdjustPosition_Implementation). These say which happened, how often and on which frame. The counts are
	// integers bumped per move; the events are recorded only on a teleport, a mode change and a correction.
	UFUNCTION(BlueprintPure, Category = "Character Movement (Networking)")
	FMars_CharacterMovement_NetCounts Get_NetCounts() const;

	// The last 64 events, oldest first.
	UFUNCTION(BlueprintPure, Category = "Character Movement (Networking)")
	TArray<FMars_CharacterMovement_NetEvent> Get_NetEvents() const;

	virtual float GetMaxSpeed() const override;
	virtual float GetMaxAcceleration() const override;
	virtual float GetMaxBrakingDeceleration() const override;
	virtual void GetLifetimeReplicatedProps(TArray<FLifetimeProperty>& OutLifetimeProps) const override;
	virtual void OnTeleported() override;
	virtual void ClientAdjustPosition_Implementation(
		float TimeStamp,
		FVector NewLoc,
		FVector NewVel,
		UPrimitiveComponent* NewBase,
		FName NewBaseBoneName,
		bool bHasBase,
		bool bBaseRelativePosition,
		uint8 ServerMovementMode,
		TOptional<FRotator> OptionalRotation = TOptional<FRotator>()) override;

protected:
	virtual void OnMovementModeChanged(EMovementMode PreviousMovementMode, uint8 PreviousCustomMode) override;

	virtual void ServerMoveHandleClientError(
		float ClientTimeStamp,
		float DeltaTime,
		const FVector& Accel,
		const FVector& RelativeClientLocation,
		UPrimitiveComponent* ClientMovementBase,
		FName ClientBaseBoneName,
		uint8 ClientMovementMode) override;

	/** Accept the client's position as truth while within ClientAuthMaxError. */
	virtual bool ServerShouldUseAuthoritativePosition(
		float ClientTimeStamp,
		float DeltaTime,
		const FVector& Accel,
		const FVector& ClientWorldLocation,
		const FVector& RelativeClientLocation,
		FMars_ClientMovementBase* ClientMovementBase,
		FName ClientBaseBoneName,
		uint8 ClientMovementMode) override;

	/** Suppress error detection while within ClientAuthMaxError. */
	virtual bool ServerExceedsAllowablePositionError(
		float ClientTimeStamp,
		float DeltaTime,
		const FVector& Accel,
		const FVector& ClientWorldLocation,
		const FVector& RelativeClientLocation,
		FMars_ClientMovementBase* ClientMovementBase,
		FName ClientBaseBoneName,
		uint8 ClientMovementMode) override;

private:
	bool IsWithinClientAuthRadius(const FVector& ClientWorldLocation) const;

	void Record_NetEvent(
		EMars_CharacterMovement_NetEventKind InKind,
		const FVector& InLocation,
		const FVector& InOther,
		EMovementMode InMode);

	static constexpr int32 k_NetEventCapacity = 64;

	FMars_CharacterNetworkMoveDataContainer _NetworkMoveDataContainer;

	FMars_CharacterMovement_NetCounts _NetCounts;
	// A fixed store: recording an event never allocates.
	TArray<FMars_CharacterMovement_NetEvent, TFixedAllocator<k_NetEventCapacity>> _NetEvents;

	UPROPERTY(Replicated)
	float _ExternalSpeedMultiplier = 1.0f;

	UPROPERTY(Replicated)
	float _ExternalAccelMultiplier = 1.0f;

	UPROPERTY(Replicated)
	float _ExternalBrakeMultiplier = 1.0f;
};
