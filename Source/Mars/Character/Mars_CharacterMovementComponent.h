#pragma once

#include "GameFramework/CharacterMovementComponent.h"

#include "Mars_CharacterMovementComponent.generated.h"

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

	virtual float GetMaxSpeed() const override;
	virtual float GetMaxAcceleration() const override;
	virtual float GetMaxBrakingDeceleration() const override;
	virtual void GetLifetimeReplicatedProps(TArray<FLifetimeProperty>& OutLifetimeProps) const override;

protected:
	/** Accept the client's position as truth while within ClientAuthMaxError. */
	virtual bool ServerShouldUseAuthoritativePosition(
		float ClientTimeStamp,
		float DeltaTime,
		const FVector& Accel,
		const FVector& ClientWorldLocation,
		const FVector& RelativeClientLocation,
		UPrimitiveComponent* ClientMovementBase,
		FName ClientBaseBoneName,
		uint8 ClientMovementMode) override;

	/** Suppress error detection while within ClientAuthMaxError. */
	virtual bool ServerExceedsAllowablePositionError(
		float ClientTimeStamp,
		float DeltaTime,
		const FVector& Accel,
		const FVector& ClientWorldLocation,
		const FVector& RelativeClientLocation,
		UPrimitiveComponent* ClientMovementBase,
		FName ClientBaseBoneName,
		uint8 ClientMovementMode) override;

private:
	bool IsWithinClientAuthRadius(const FVector& ClientWorldLocation) const;

	UPROPERTY(Replicated)
	float _ExternalSpeedMultiplier = 1.0f;

	UPROPERTY(Replicated)
	float _ExternalAccelMultiplier = 1.0f;

	UPROPERTY(Replicated)
	float _ExternalBrakeMultiplier = 1.0f;
};
