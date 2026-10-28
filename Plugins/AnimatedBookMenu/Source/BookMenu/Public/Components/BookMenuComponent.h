// Copyright 2024 Suricoon. All Rights Reserved.

#pragma once
#include "CoreMinimal.h"
#include "Actors/BookMenuActor.h"
#include "Components/BoxComponent.h"
#include "Components/PrimitiveComponent.h"
#include "Components/WidgetComponent.h"
#include "Components/WidgetInteractionComponent.h"
#include "DataAssets/BookMenuData.h"
#include "BookMenuComponent.generated.h"

/**
 * Book Menu Component to spawn a Book Menu Actor attached to this component 
 */
UCLASS(ClassGroup=(Custom), meta=(BlueprintSpawnableComponent), Blueprintable, HideCategories=("hideCategory"))
class BOOKMENU_API UBookMenuComponent : public UPrimitiveComponent
{
	GENERATED_BODY()

public:
	// Sets default values for this component's properties
	UBookMenuComponent();

	/**
	 * The spawned Book Menu Actor
	 */
	UPROPERTY(BlueprintReadOnly, Category="Book Menu")
		ABookMenuActor * BookMenuActor;
	
	/**
	 * The Book Menu Data to initialize the spawned Book Menu Actor
	 */
	UPROPERTY(EditAnywhere, Category="Book Menu")
		UBookMenuData * BookMenuData;
	
	/**
	 * The Class of the Book Menu Actor to be spawned at Begin Play
	 */
	UPROPERTY(EditAnywhere, Category="Book Menu")
		TSubclassOf<ABookMenuActor> BookMenuActorClass;

	/**
	 * Can be used to set the book menu data after begin play, during the game 
	 * @param InBookMenuData the new Book Menu Data
	 */
	UFUNCTION(BlueprintCallable, Category = "Book Menu")
		void SetBookMenuData(UBookMenuData * InBookMenuData);

	/**
	 * 
	 * @return returns the Book Menu Data
	 */
	UFUNCTION(BlueprintCallable, Category = "Book Menu")
		UBookMenuData * GetBookMenuData() const;
	
	/**
	 * 
	 * @return the current page section index; -1 in case BookMenuActor is not defined
	 */
	UFUNCTION(BlueprintCallable, Category = "Book Menu")
		int32 GetCurrentPageSectionIndex() const;

	/**
	 * @return the pending page section index; -1 in case BookMenuActor is not defined
	 */
	UFUNCTION(BlueprintCallable, Category = "Book Menu")
		int32 GetPendingPageSectionIndex() const;

	/**
	 * 
	 * @return the current page index 0 = Left ; 1 = Right
	 * returns -1 in case BookMenuActor is not defined
	 */
	UFUNCTION(BlueprintCallable, Category = "Book Menu")
		int32 GetCurrentPageIndex() const;

	/**
	 * 
	 * @return true if the book is in open state; false if the book is in closed state
	 */
	UFUNCTION(BlueprintCallable, Category = "Book Menu")
		bool GetBookIsOpen() const;

	/**
	 * 
	 * @return true if the book should be in open state
	 */
	UFUNCTION(BlueprintCallable, Category = "Book Menu")
		bool GetBookShouldOpen() const;

	/**
	 * 
	 * @return true if the book should be in closed state
	 */
	UFUNCTION(BlueprintCallable, Category = "Book Menu")
		bool GetBookShouldClose() const;

	/**
	 * 
	 * @return an Map of the page sections of the book
	 */
	UFUNCTION(BlueprintCallable, Category = "Book Menu")
		TMap<int32,FPageSectionDataStruct> GetPageSections() const;
	
	/**
	 * Method to register a Book Menu Interaction Component
	 * @param InInteractionComponent The Book Menu Interaction Component to be registered. 
	 */
	UFUNCTION(BlueprintCallable, Category = "PageControl")
		void RegisterInteractionComponent(UBookMenuInteractionComponent * InInteractionComponent);

	/**
	 * Method to directly register a Book Menu Interaction Actor.
	 * @param InteractionActor The Book Menu Interaction Actor to be registered. 
	 */
	UFUNCTION(BlueprintCallable, Category = "PageControl")
		void RegisterInteractionActor(ABookMenuInteractionActor * InteractionActor);


	/**
	 * Performs a Line Trace based on the Start and End Parameters and moves the Widget Interaction pointer of the
	 * Book Menu Interaction Actor if it is set. Also tells the Animation Blueprint which page was traced to.
	 * @param Start Start of the Line Trace
	 * @param End End of the Line Trace
	 * @param OutResult Indicates if the Interaction was executed successfully or not
	 * @param bDebugTrace Shows a debug trace if true.
	 * @param TraceChannel The Collision Channel to be used for the line trace.
	 * @return returns tru if the operation was successful. Otherwise false
	 */
	UFUNCTION(BlueprintCallable, Category = "PageControl", meta = (ExpandEnumAsExecs = "OutResult"))
		bool Interact(FVector Start, FVector End, EExecResultBookMenu &OutResult, bool bDebugTrace = false, ECollisionChannel TraceChannel = ECC_Visibility);

	/**
	 * Performs a Line Trace based on the Start and End Parameters and moves the Widget Interaction pointer of the
	 * Book Menu Interaction Actor if it is set. Also tells the Animation Blueprint which page was traced to.
	 * @param Start Start of the Line Trace
	 * @param End End of the Line Trace
	 * @param OutResult Indicates if the Interaction was executed successfully or not
	 * @param OutUVCoordinates The UV coordinates of the traced page
	 * @param bDebugTrace Shows a debug trace if true.
	 * @param TraceChannel The Collision Channel to be used for the line trace.
	 * @return returns tru if the operation was successful. Otherwise false
	*/
	UFUNCTION(BlueprintCallable, Category = "Book Menu", meta = (ExpandEnumAsExecs = "OutResult"))
	bool InteractExt(FVector Start, FVector End, EExecResultBookMenu &OutResult, FVector2D& OutUVCoordinates , bool bDebugTrace = false,  ECollisionChannel TraceChannel = ECC_Visibility);

	/**
	 * 
	 * @param InPageIndex The page index to set the focus to
	 * @param OutResult Indicates if the Interaction was executed successfully or not
	 * @return returns true if the operation was successful. Otherwise false
	 */
	UFUNCTION(BlueprintCallable, Category = "Book Menu", meta = (ExpandEnumAsExecs = "OutResult"))
		bool SetKeyboardFocus(int32 InPageIndex, EExecResultBookMenu &OutResult);
	
protected:
	// Called when the game starts
	virtual void BeginPlay() override;

public:
	// Called every frame
	virtual void TickComponent(float DeltaTime, ELevelTick TickType,
	                           FActorComponentTickFunction* ThisTickFunction) override;

};
