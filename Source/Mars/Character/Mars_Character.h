#pragma once

#include "GameFramework/Character.h"

#include "Mars_Character.generated.h"

// How this machine sees the base a pawn stands on, as far as the network is concerned.
UENUM(BlueprintType)
enum class EMars_Character_NetBase : uint8
{
	// No base (in the air, flying), or a base the authority does not report.
	None,
	// A base every machine can address: loaded with a level, or a replicated actor's.
	Crossing,
	// Authority only: a base this machine built for itself.
	PerMachine,
	// A copy: the authority says it has a base and the reference did not arrive.
	Unresolved
};

/**
 * Mars native character base.
 *
 * Sole responsibility: install UMars_CharacterMovementComponent as the movement component. The movement-component class
 * is fixed at native construction time (ObjectInitializer.SetDefaultSubobjectClass) and cannot be set from AngelScript,
 * which is the only reason this C++ base exists. Character behaviour lives in the AngelScript subclass
 * (AMars_PlayerCharacter).
 */
UCLASS(Abstract, BlueprintType, Blueprintable)
class MARS_API AMars_Character : public ACharacter
{
	GENERATED_BODY()

public:
	AMars_Character(const FObjectInitializer& ObjectInitializer = FObjectInitializer::Get());

	// With authority, the class of this machine's own base; otherwise what the authority replicated to this copy. A
	// client's own pawn reads None: the replicated base is sent to simulated copies only.
	UFUNCTION(BlueprintPure, Category = "Character Movement (Networking)")
	EMars_Character_NetBase Get_NetBase() const;

	// Whether this machine's own movement has a base (ACharacter::GetMovementBase is not reflected).
	UFUNCTION(BlueprintPure, Category = "Character Movement (Networking)")
	bool Get_HasMovementBase() const;

	virtual void PreReplication(IRepChangedPropertyTracker& ChangedPropertyTracker) override;
};
