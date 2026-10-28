// Copyright 2024 Suricoon. All Rights Reserved.
#pragma once
#include "CoreMinimal.h"
#include "BookMenu.h"
#include "Animation/BookMenuAnimInstance.h"
#include "UObject/Object.h"
#include "Components/StaticMeshComponent.h"

#include "BookMenuActor.generated.h"
class ABookMenuInteractionActor;
class UBookMenuInteractionComponent;
class UBookMenuData;
class UBoxComponent;

/**
 * Actor that represents the Book Menu
 */
UCLASS(Blueprintable, HideCategories=("hideCategory"))
class BOOKMENU_API ABookMenuActor : public AActor
{
	GENERATED_BODY()

	/**
	 * The scene root to which all other components get attached to
	 */
	UPROPERTY(Category = "hideCategory", VisibleAnywhere, BlueprintReadOnly, meta = (AllowPrivateAccess = "true"))
		USceneComponent* DefaultSceneRoot;
	
	/**
	 * The animated book mesh
	 */
	UPROPERTY(Category = "hideCategory", VisibleAnywhere, BlueprintReadOnly, meta = (AllowPrivateAccess = "true"))
		USkeletalMeshComponent * SkeletalMeshComponent;

	/**
	 * A dummy static mesh component for doing traces. Needed to determine the UV coordinates based on trace hit results.
	 * The static mesh will be hidden in game. Must represent the book in a open state
	 */
	UPROPERTY(Category = "hideCategory", VisibleAnywhere, BlueprintReadOnly, meta = (AllowPrivateAccess = "true"))
		UStaticMeshComponent * StaticMeshComponent;

	/**
	 * Collision box used to determine which page of the book was traced 
	 */
	UPROPERTY(Category = "hideCategory", VisibleAnywhere, BlueprintReadOnly, meta = (AllowPrivateAccess = "true"))
		UBoxComponent* LeftPageCollision;

	/**
	 * Collision box used to determine which page of the book was traced 
	 */
	UPROPERTY(Category = "hideCategory", VisibleAnywhere, BlueprintReadOnly, meta = (AllowPrivateAccess = "true"))
		UBoxComponent* RightPageCollision;

	/**
	 * Reference to the actor that redirects the interaction to a widget interaction component
	 */
	UPROPERTY(Category = "hideCategory", BlueprintReadOnly, EditAnywhere, meta = (AllowPrivateAccess = "true"))
		ABookMenuInteractionActor* InteractionActor;

	
	/**
	 * Helper to reset book menu data related properties
	 */
	UFUNCTION()
		void ClearBookData();

	/**
	 * Helper to initialize the book menu actor
	 */
	UFUNCTION()
		void InitBookData();
	
public:

	/**
	 * Set the default values for this actor
	 */
	ABookMenuActor();

	/**
	 * Called when the actor begins play
	 */
	virtual void BeginPlay() override;	

	/**
	 * Default Configuration Data for the Book, containing information such as the the widgets to be displayed as book pages
	 */
	UPROPERTY(EditAnywhere, Category="Book Menu")
		UBookMenuData * BookMenuData;

	/**
	 * Can be used to set the book menu data after begin play, during the game 
	 * @param InBookMenuData the new Book Menu Data
	 */
	UFUNCTION(BlueprintCallable, Category = "Book Menu")
		void SetBookMenuData(UBookMenuData * InBookMenuData);

	/**
	 * 
	 * @return Returns the Book Menu Data
	 */
	UFUNCTION(BlueprintCallable, Category = "Book Menu")
		UBookMenuData * GetBookMenuData() const;
	
	/**
	 * 
	 * @return the current page section index; -1 in case Anim Instance is not defined
	 */
	UFUNCTION(BlueprintCallable, Category = "Book Menu")
		int32 GetCurrentPageSectionIndex() const;

	/**
	 * 
	 * @return the pending page section index; -1 in case Anim Instance is not defined
	 */
	UFUNCTION(BlueprintCallable, Category = "Book Menu")
		int32 GetPendingPageSectionIndex() const;

	/**
	 * 
	 * @return the current page index 0 = Left ; 1 = Right
	 * returns -1 in case Anim Instance is not defined
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
	 * 
	 * @return Returns the reference to the Book Menu Interaction Actor
	 */
	UFUNCTION(BlueprintCallable, Category = "Book Menu")
		ABookMenuInteractionActor * GetInteractionActor() const;

	/**
	 * Method to register a Book Menu Interaction Component
	 * @param InInteractionComponent The Book Menu Interaction Component to be registered. 
	 */
	UFUNCTION(BlueprintCallable, Category = "PageControl")
		void RegisterInteractionComponent(UBookMenuInteractionComponent * InInteractionComponent);

	/**
	 * Method to directly register a Book Menu Interaction Actor.
	 * @param InInteractionActor The Book Menu Interaction Actor to be registered. 
	 */
	UFUNCTION(BlueprintCallable, Category = "PageControl")
		void RegisterInteractionActor(ABookMenuInteractionActor * InInteractionActor);
	
	/**
	 * Registers the Book Menu Interaction Actor to be used for Interaction with the Book 
	 * @param InInteractionActor the Book Menu Interaction Actor to be set
	 */
	UFUNCTION(BlueprintCallable, Category = "Book Menu")
		void SetInteractionActor(ABookMenuInteractionActor * InInteractionActor);
	
	/**
	 * Determines if a forward or backward page turn need to be performed based on the current page section index.
	 * @param SectionIndex the index of the Page Section to be displayed
	 */
	UFUNCTION(BlueprintCallable, Category = "Book Menu")
		void JumpToPageSection(int32 SectionIndex);

	/**
	 * If the book is closed, this triggers the open book animation and upfront sets the correct section to display.
	 * @param SectionIndex The Page Section Index to be displayed while opening the book
	 */
	UFUNCTION(BlueprintCallable, Category = "Book Menu")
		void OpenBookAt(int32 SectionIndex);

	/**
	 * Triggers the Close Book animation
	 */
	UFUNCTION(BlueprintCallable, Category = "Book Menu")
		void CloseBook();

	/**
	 * Pauses the animation update of the anim instance without closing the book first.
	 */
	UFUNCTION(BlueprintCallable, Category = "Book Menu")
		void PauseBookUpdate();

	/**
	 * Resume the animation update of the anim instance. Will only resume if the book is already open. Closed books don't need to consume render time
	 */
	UFUNCTION(BlueprintCallable, Category = "Book Menu")
		void ResumeBookUpdate();
	
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
	UFUNCTION(BlueprintCallable, Category = "Book Menu", meta = (ExpandEnumAsExecs = "OutResult"))
		bool Interact(FVector Start, FVector End, EExecResultBookMenu &OutResult, bool bDebugTrace = false,  ECollisionChannel TraceChannel = ECC_Visibility);

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
	 * @param bDebugTrace Shows a debug trace if true.
	 * @return returns true if the operation was successful. Otherwise false
	 */
	UFUNCTION(BlueprintCallable, Category = "Book Menu", meta = (ExpandEnumAsExecs = "OutResult"))
		bool SetKeyboardFocus(int32 InPageIndex, EExecResultBookMenu &OutResult, bool bDebugTrace = false);

	
	
	/**
	 * 
	 * @return Returns the Animation Instance of the Animation Blueprint
	 */
	UFUNCTION(BlueprintPure, Category = "Book Menu")
		UBookMenuAnimInstance * GetAnimInstance() const;

	/**
	 * 
	 * @return Returns the Collision Box of the left page
	 */
	UFUNCTION(BlueprintPure, Category = "Book Menu")
		UBoxComponent*  GetLeftPageCollisionBox() const;

	/**
	 * 
	 * @return Returns the Collision Box of the right page
	 */
	UFUNCTION(BlueprintPure, Category = "Book Menu")
		UBoxComponent*  GetRightPageCollisionBox() const;

	/**
	 * 
	 * @return Returns the Static Mesh Component
	 */
	UFUNCTION(BlueprintPure, Category = "Book Menu")
		UStaticMeshComponent*  GetStaticMeshComponent() const;
	
};
