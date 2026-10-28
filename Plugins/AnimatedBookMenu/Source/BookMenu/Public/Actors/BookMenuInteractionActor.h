// Copyright 2024 Suricoon. All Rights Reserved.
#pragma once
#include "CoreMinimal.h"
#include "Components/ArrowComponent.h"
#include "GameFramework/Actor.h"
#include "BookMenuInteractionActor.generated.h"

class UWidgetInteractionComponent;
class UWidgetComponent;

/**
 * 
 */
UCLASS()
class BOOKMENU_API ABookMenuInteractionActor : public AActor
{
	GENERATED_BODY()
	
public:
	/**
	 * The scene root to which all other components get attached to
	 */
	UPROPERTY(Category = "hideCategory", VisibleAnywhere, BlueprintReadOnly, meta = (AllowPrivateAccess = "true"))
		USceneComponent* DefaultSceneRoot;

	/**
	 * Location to point the interaction component to, if there is no pointer interaction
	 */
	UPROPERTY(Category = "hideCategory", VisibleAnywhere, BlueprintReadOnly, meta = (AllowPrivateAccess = "true"))
		UArrowComponent* PointerZero;
	
	/**
	 * The widget interaction component used to redirect the book interaction onto a Widget Component
	 */
	UPROPERTY(Category = "hideCategory", VisibleAnywhere, BlueprintReadOnly, meta = (AllowPrivateAccess = "true"))
		UWidgetInteractionComponent* WidgetInteractionComponent;
	
	/**
	 * The widget component used to display the Page One
	 */
	UPROPERTY(Category = "hideCategory", VisibleAnywhere, BlueprintReadOnly, meta = (AllowPrivateAccess = "true"))
		UWidgetComponent* PageWidgetComponentA;

	/**
	 * The widget component used to display the Page Two
	 */
	UPROPERTY(Category = "hideCategory", VisibleAnywhere, BlueprintReadOnly, meta = (AllowPrivateAccess = "true"))
		UWidgetComponent* PageWidgetComponentB;

	/**
	 * The widget component used to display the Page Three
	 */
	UPROPERTY(Category = "hideCategory", VisibleAnywhere, BlueprintReadOnly, meta = (AllowPrivateAccess = "true"))
		UWidgetComponent* PageWidgetComponentC;

	/**
	 * TThe widget component used to display the Page Four
	 */
	UPROPERTY(Category = "hideCategory", VisibleAnywhere, BlueprintReadOnly, meta = (AllowPrivateAccess = "true"))
		UWidgetComponent* PageWidgetComponentD;

	/**
	 * The focused widget component
	 */
	UPROPERTY(Category = "hideCategory", BlueprintReadOnly)
		UWidgetComponent* ActiveWidgetComponent;
	
	// Sets default values for this actor's properties
	ABookMenuInteractionActor();

	/**
	 * The Draw Size of the Widget. User Widgets and Render Targets must have the same resolution. Will be set via the
	 * Book Menu Data of the Book Menu Actor
	 */
	UPROPERTY(BlueprintReadOnly, Category="Book Menu")
		FVector2D DrawSize;	

protected:
	// Called when the game starts or when spawned
	virtual void BeginPlay() override;

public:
	// Called every frame
	virtual void Tick(float DeltaTime) override;

	
	/**
	 * Calculates the world location on the Page Widget based on the UV Coordinates of the Book Actors Book Mesh
	 * @param UVCoordinates UV Coordinates of the Book Page
	 * @param bDebugTrace Shows a debug trace if true
	 * @return returns true if the operation was successful. Otherwise false.
	 */
	UFUNCTION(BlueprintCallable, Category = "Book Menu")
		bool MovePointer(FVector2D UVCoordinates, bool bDebugTrace = false);

	/**
	 * Sets the position of the pointer to a pre defined safe spot
	 * @param bDebugTrace Shows a debug trace if true
	 * @return returns true if the operation was successful. Otherwise false.
	 */
	UFUNCTION(BlueprintCallable, Category = "Book Menu")
		bool ResetPointer(bool bDebugTrace = false);
		
	/**
	 * 
	 * @return returns the Widget Interaction Component. Can be used to do further interaction with the widget such as send keys etc.
	 */
	UFUNCTION(BlueprintPure, Category = "Book Menu")
		UWidgetInteractionComponent * GetInteractionComponent() const;
};
