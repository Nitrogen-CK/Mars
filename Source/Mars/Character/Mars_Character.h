#pragma once

#include "GameFramework/Character.h"

#include "Mars_Character.generated.h"

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
};
