// Copyright 2024 Suricoon. All Rights Reserved.
#pragma once
#include "CoreMinimal.h"
#include "BookMenu.h"
#include "Kismet/BlueprintFunctionLibrary.h"
#include "Engine/TextureDefines.h"
#include "Engine/EngineTypes.h"
#include "BookMenuStatics.generated.h"

class UBookMenuData;
class ABookMenuActor;
class UWidgetComponent;
class UWidgetInteractionComponent;
/**
 * Static Function Library with functions around different purposes used for the Book Menu System. 
 */
UCLASS()
class BOOKMENU_API UBookMenuStatics : public UBlueprintFunctionLibrary
{
	GENERATED_BODY()

public :
	
	/**
	 * Method to render a User Widget onto a Render Target
	 * @param UserWidget The UserWidget to be rendered
	 * @param RenderTarget The Target to be rendered on
	 * @param DrawSize The DrawSize of the Render Target
	 * @param DeltaTime Delta time
	 * @param bUseGammaCorrection Uses Gamma Correction if true
	 */
	UFUNCTION(Category = "BookMenu", BlueprintCallable)
		static void DrawUserWidgetToRenderTarget2D(UUserWidget * UserWidget, UPARAM(ref) UTextureRenderTarget2D * RenderTarget, FVector2D DrawSize = FVector2D(1024, 1024), float DeltaTime = 0.f, bool bUseGammaCorrection = false);

	/**
	 * Creates a new Render Target with the specified parameters
	 * @param DrawSize The Draw Size of the Render Target
	 * @param Filter The Texture Filter to be applied
	 * @param UseGammaCorrection Uses Gamma Correction if true
	 * @return returns the created Render Target
	 */
	UFUNCTION(Category = "BookMenu", BlueprintCallable, Meta = (DeterminesOutputType = "UTextureRenderTarget2D"))
		static UTextureRenderTarget2D * CreateTextureRenderTarget2D(FVector2D DrawSize = FVector2D(2048,2048), TextureFilter Filter = TF_Nearest, bool UseGammaCorrection = false);
	
	/**
	 * Method to get the First local Player Controller based on the World Context
	 * @param WorldContextObject The World Context Object
	 * @return returns the first local player controller
	 */
	UFUNCTION(BlueprintPure, Category = "BookMenu", meta = (WorldContext = "WorldContextObject"))
		static APlayerController * GetLocalPlayerController(const UObject* WorldContextObject);

	/**
	 * Creates a trace based on the given collision channel. If a Book Men uActor was hit the Method determines if the book was hit from the front
	 * and tries to determine the current page and the UV Coordinates. This requires the Project Settings to be set to use the generation of UV coordinates from hit results.
	 * @param WorldContextObject The World Context Object
	 * @param BookMenuActor The Book Menu Actor we ar looking for
	 * @param Start Start of the Trace
	 * @param End End of the Trace
	 * @param OutUVCoordinates The found UV Coordinates
	 * @param OutPageIndex The found page index 0 = Left ; 1 = Right
	 * @param bDebugTrace shows a debug trace if true
	 * @param TraceChannel The Collision Channel to be used for the Trace
	 * @return returns true if the operation was successful. Otherwise false.
	 */
	UFUNCTION(Category = "BookMenu", BlueprintCallable, meta = (WorldContext = "WorldContextObject"))
		static bool BookUvTrace(const UObject* WorldContextObject, ABookMenuActor * BookMenuActor, FVector Start, FVector End, FVector2D& OutUVCoordinates, int32& OutPageIndex, bool bDebugTrace, ECollisionChannel TraceChannel = ECC_Visibility);

	/**
	 * Calculates the world location on the Page Widget based on the UV Coordinates of the Book Actors Book Mesh
	 * @param InWidgetInteractionComponent The Widget Interaction Component that shall be influenced
	 * @param InWidgetComponent The Widget Component the Pointer shall be moved on
	 * @param InReferenceRotation A reference rotation in order to do some relative calculations. e.g. the World Rotation of the Book Interaction Actor.
	 * @param UVCoordinates UV Coordinates to be translated onto the Widget
	 * @param bDebugTrace shows a debug trace if true.
	 * @return returns true if the operation was successful. Otherwise false.
	 */
	UFUNCTION(Category = "BookMenu", BlueprintCallable)
		static bool MoveWidgetInteractionPointer(UWidgetInteractionComponent* InWidgetInteractionComponent,
		                                         UWidgetComponent* InWidgetComponent, FRotator InReferenceRotation,
		                                         FVector2D UVCoordinates, bool bDebugTrace);

	/**
	 * 
	 * @param InWidgetInteractionComponent The Widget Interaction Component that shall be influenced
	 * @param InZeroLocation the safe spot location
	 * @param InReferenceRotation A reference rotation in order to do some relative calculations. e.g. the World Rotation of the Book Interaction Actor.
	 * @param bDebugTrace shows a debug trace if true.
	 * @return returns true if the operation was successful. Otherwise false.
	 */
	UFUNCTION(Category = "BookMenu", BlueprintCallable)
		static bool ResetWidgetInteractionPointer(UWidgetInteractionComponent* InWidgetInteractionComponent,
											 FVector InZeroLocation, FRotator InReferenceRotation, bool bDebugTrace);
	
	/**
	 * Method to translate the mouse position into trace parameters such as start and end
	 * @param PlayerController The Player controller
	 * @param TraceDistance The distance (length) used to perform the trace
	 * @param OutStart The resulting Start Coordinate of the Trace Parameters
	 * @param OutEnd The resulting End Coordinate of the Trace Parameters
	 * @param OutResult Indicates if the operation was successful or not. Used as exec pins in the blue print node.
	 * @return returns true if the operation was successful. Otherwise false.
	 */
	UFUNCTION(Category = "BookMenu", BlueprintCallable, meta = (ExpandEnumAsExecs = "OutResult"))
		static bool CreateMouseTraceParameters(APlayerController * PlayerController, float TraceDistance, FVector& OutStart, FVector& OutEnd, EExecResultBookMenu& OutResult);

	
	/**
	 * Creates a runtime instance of the Book Data based on a template
	 * @param Outer The new Outer for the cloned template
	 * @param Template The Template to be used as the basis for the instance
	 * @param OutResult Indicates if the operation was successful or not. Used as exec pins in the blue print node.
	 * @return 
	 */
	UFUNCTION(Category = "BookMenu", BlueprintCallable, meta = (ExpandEnumAsExecs = "OutResult"))
		static UBookMenuData * CreateBookMenuDataRuntimeInstance(UObject * Outer, UBookMenuData * Template, EExecResultBookMenu& OutResult);

};
