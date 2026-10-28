// Copyright 2024 Suricoon. All Rights Reserved.
#pragma once
#include "CoreMinimal.h"
#include "Components/PrimitiveComponent.h"
#include "BookMenuInteractionComponent.generated.h"


class ABookMenuInteractionActor;
class UWidgetComponent;
class UWidgetInteractionComponent;

/**
 * Book Menu Interaction Component to spawn a Book Menu Interaction Actor attached to this component 
 */
UCLASS(ClassGroup=(Custom), meta=(BlueprintSpawnableComponent))
class BOOKMENU_API UBookMenuInteractionComponent : public UPrimitiveComponent
{
	GENERATED_BODY()

public:

	// Sets default values for this component's properties
	UBookMenuInteractionComponent();

	/**
	 * The Class of the Book Menu Interaction Actor to be spawned at Begin Play
	 */
	UPROPERTY(EditAnywhere, Category="Book Menu")
		TSubclassOf<ABookMenuInteractionActor> BookMenuInteractionActorClass;
	
protected:
	// Called when the game starts
	virtual void BeginPlay() override;

public:
	// Called every frame
	virtual void TickComponent(float DeltaTime, ELevelTick TickType,
	                           FActorComponentTickFunction* ThisTickFunction) override;

	/**
	 * The spawned Book Menu Interaction Actor
	 */
	UPROPERTY(BlueprintReadOnly, Category = "PageControl")
		ABookMenuInteractionActor * InteractionActor;

	/**
	 *	
	 * @return returns the Widget Interaction Component
	 */
	UFUNCTION(BlueprintPure, Category = "PageControl")
		UWidgetInteractionComponent * GetWidgetInteractionComponent() const;
	
};
