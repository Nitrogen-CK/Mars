// Editor-only: the sandbox gauntlets, five cells that each combine several mechanisms (design: the "Small dungeon gauntlets"
// handoff of 3 October 2026; presets in Script/WorldObjects/Mechanisms/Mars_SandboxGauntlets.as). To add them to an
// already-built sandbox map, open it and run: Mars.Sandbox.BuildGauntlets
//
// A hall (X -3700..2000, Y 2000..2600) runs along the main floor's north edge; the cells open off its north side, each a
// self-contained socket with its own walls, controls, reward and recovery:
//   G3 Bellkeeper's Confession (X -3700..-2200): circle seal below, triangle seal on the gallery -> reliquary (Root);
//      the reliquary's wheel latches a return door into the west corridor back to the hall.
//   G6 Blind Choir (X -2100..-900): the lower wheel opens the bell loft's shutter on the gallery; the bell's face reads
//      circle -> triangle; the lower seals in that order -> fungus vault (Fungus).
//   G1 Mourner's Table (X -800..0): chef plate AND dropped-pack plate together -> truffle alcove (Truffle).
//   G5 Porter's Wager (X 100..700): dropped pack on the slab holds the freight gate open, lifting it starts three grace
//      lamps; beyond the gate a dropped pack anywhere in the passage holds them too, and a chain lets a chef out; salt
//      niche beyond (Salt). Nothing outside but the slab opens the gate.
//   G4 Censer's Window (X 800..2000): a chain on either side lights three lamps that brake the censer and raise the shutter
//      at the end of its lane; a walled slalom lane beside it always works.
//
// Cell coordinates are local: the origin is the cell's main doorway on its south wall, at floor level; +Y runs into the
// cell. Blocks (walls are 20 uu thick, centred on their line) are given as min/max corners in those coordinates. Labels
// start with "Gauntlet" (Apply_GauntletMaterial colours them by name).

#if EDITOR
UFUNCTION()
void Mars_BuildSandboxGauntletsFunc(const TArray<FString>& Args)
{
    utils_mars_sandbox::BuildGauntlets();
}

const FConsoleCommand Mars_BuildSandboxGauntletsCommand("Mars.Sandbox.BuildGauntlets", n"Mars_BuildSandboxGauntletsFunc");

// A straight stair rising toward +Y: Steps risers of Riser over treads of Tread (15 x 20 over 30 climbs 300 in 450), Width
// wide along X.
struct FMars_SandboxGauntlet_Stair
{
    FVector Min;
    float64 Width = 300.0;
    int32 Steps = 15;
    float64 Riser = 20.0;
    float64 Tread = 30.0;

    FMars_SandboxGauntlet_Stair() {}

    FMars_SandboxGauntlet_Stair(FVector InMin, float64 InWidth)
    {
        Min = InMin;
        Width = InWidth;
    }
}

// One cell's placement: blocks and mechanisms in its local frame, labelled "<Prefix>_<Name>".
struct FMars_SandboxGauntlet_Cell
{
    FVector Origin;
    FString Prefix;

    FMars_SandboxGauntlet_Cell() {}

    FMars_SandboxGauntlet_Cell(FVector InOrigin, const FString& InPrefix)
    {
        Origin = InOrigin;
        Prefix = InPrefix;
    }

    void Block(const FString& InName, FVector InMin, FVector InMax) const
    {
        utils_mars_map_builder::Spawn_Block(engine::load::Cube(), f"{Prefix}_{InName}",
            Origin + (InMin + InMax) * 0.5, (InMax - InMin) * 0.01);
    }

    void Place(TSubclassOf<UCk_EntityScript_UE> InScriptClass, const FString& InName, FTransform InLocal) const
    {
        utils_mars_sandbox::Spawn_Mechanism(InScriptClass, f"{Prefix}_{InName}", Origin + InLocal.GetLocation(), InLocal.Rotator());
    }

    // A wall along X across InSpanX with a gate frame (240 wide, 240 tall) in it: two segments and a header. InWall: X = the
    // gate's centre, Y = the wall's line, Z = the wall's height.
    void GatedWallAlongX(const FString& InName, FVector InWall, FVector2D InSpanX) const
    {
        const auto Y = InWall.Y;
        const auto GateX = InWall.X;
        const auto Height = InWall.Z;
        Block(f"{InName}_West", FVector(InSpanX.X, Y - 10.0, 0.0), FVector(GateX - 120.0, Y + 10.0, Height));
        Block(f"{InName}_East", FVector(GateX + 120.0, Y - 10.0, 0.0), FVector(InSpanX.Y, Y + 10.0, Height));
        Block(f"{InName}_Header", FVector(GateX - 120.0, Y - 10.0, 240.0), FVector(GateX + 120.0, Y + 10.0, Height));
    }

    // Steps rising toward +Y from InStair.Min (the first step's south-west corner on the floor).
    void Stair(const FString& InName, const FMars_SandboxGauntlet_Stair& InStair) const
    {
        for (int32 Index = 0; Index < InStair.Steps; ++Index)
        {
            const auto StepMin = InStair.Min + FVector(0.0, InStair.Tread * Index, 0.0);
            const auto StepMax = StepMin + FVector(InStair.Width, InStair.Tread, InStair.Riser * (Index + 1));
            Block(f"{InName}_{Index}", StepMin, StepMax);
        }
    }

    // An open railing on a deck from InFrom to InTo (both at deck height, along X or Y): posts at most 75 uu apart, one at
    // each end, under a top bar, 100 tall, so sightlines pass between the posts.
    void Balustrade(const FString& InName, FVector InFrom, FVector InTo) const
    {
        const float64 PostSize = 10.0;
        const float64 PostSpacing = 75.0;
        const float64 BarHeight = 20.0;
        const float64 Height = 100.0;

        const auto Span = InTo - InFrom;
        const auto Length = Span.Size();
        const auto Direction = Span / Length;
        const auto Half = FVector(PostSize * 0.5, PostSize * 0.5, 0.0);

        const auto Gaps = Math::Max(int32(Length / PostSpacing + 0.999), 1);
        for (int32 Index = 0; Index <= Gaps; ++Index)
        {
            const auto Base = InFrom + Direction * (Length * Index / Gaps);
            Block(f"{InName}_Post{Index}", Base - Half, Base + Half + FVector(0.0, 0.0, Height - BarHeight));
        }

        Block(f"{InName}_Bar", FVector(Math::Min(InFrom.X, InTo.X), Math::Min(InFrom.Y, InTo.Y), InFrom.Z) - Half
                + FVector(0.0, 0.0, Height - BarHeight),
            FVector(Math::Max(InFrom.X, InTo.X), Math::Max(InFrom.Y, InTo.Y), InFrom.Z) + Half + FVector(0.0, 0.0, Height));
    }

    // A 50 uu relief glyph centred on InCenter, facing -Y (toward a player looking north); a triangle's apex points up.
    void Glyph(const FString& InName, EMars_Seal_Glyph InGlyph, FVector InCenter) const
    {
        const auto Location = Origin + InCenter;
        const auto Label = f"{Prefix}_{InName}";
        if (InGlyph == EMars_Seal_Glyph::Circle)
        {
            // Roll 90 turns the cylinder's axis along Y.
            utils_mars_map_builder::Spawn_Block(engine::load::Cylinder(), Label, Location, FVector(0.5, 0.5, 0.04), FRotator(0.0, 0.0, 90.0));
        }
        else if (InGlyph == EMars_Seal_Glyph::Triangle)
        { utils_mars_map_builder::Spawn_Block(engine::load::Cone(), Label, Location, FVector(0.5, 0.04, 0.5)); }
        else
        { utils_mars_map_builder::Spawn_Block(engine::load::Cube(), Label, Location, FVector(0.4, 0.04, 0.4)); }
    }

    // A reading-order arrow between two glyphs, facing -Y: it points -X, which is to the right of a player looking north.
    void Arrow(const FString& InName, FVector InCenter) const
    {
        utils_mars_map_builder::Spawn_Block(engine::load::Cube(), f"{Prefix}_{InName}Shaft",
            Origin + InCenter + FVector(5.0, 0.0, 0.0), FVector(0.3, 0.04, 0.06));
        // Pitch 90 points the cone's apex along -X; its local Y (thin) stays along Y.
        utils_mars_map_builder::Spawn_Block(engine::load::Cone(), f"{Prefix}_{InName}Head",
            Origin + InCenter + FVector(-20.0, 0.0, 0.0), FVector(0.2, 0.04, 0.2), FRotator(90.0, 0.0, 0.0));
    }
}

namespace utils_mars_sandbox
{
    const FString k_GauntletLabelPrefix = "Gauntlet";
    const FString k_GauntletHallFloorLabel = "GauntletHall_Floor";

    // The tall cells (galleries at 300) get walls a gallery player cannot see over.
    const float64 k_GauntletWallHeight = 300.0;
    const float64 k_GauntletTallWallHeight = 700.0;

    void BuildGauntlets()
    {
        auto World = UUnrealEditorSubsystem::Get().GetEditorWorld();
        if (ck::Is_NOT_Valid(World) || World.GetPathName().StartsWith(k_MapPath) == false)
        {
            ck::Warning(f"[Mars.Sandbox.BuildGauntlets] Open [{k_MapPath}] first.");
            return;
        }

        for (auto Actor : UEditorActorSubsystem::Get().GetAllLevelActors())
        {
            if (Actor.GetActorLabel() == k_GauntletHallFloorLabel)
            {
                ck::Warning(f"[Mars.Sandbox.BuildGauntlets] [{k_GauntletHallFloorLabel}] already exists. Delete the {k_GauntletLabelPrefix}* actors first to rebuild.");
                return;
            }
        }

        Spawn_Gauntlets();
        Apply_ProtoGridMaterials();

        const bool Saved = ULevelEditorSubsystem::Get().SaveCurrentLevel();
        ck::Trace(f"[Mars.Sandbox.BuildGauntlets] built, saved={Saved}");
    }

    void Spawn_Gauntlets()
    {
        Spawn_GauntletHall();
        Spawn_Gauntlet3_Bellkeeper(FMars_SandboxGauntlet_Cell(FVector(-2800.0, 2600.0, 0.0), "Gauntlet3"));
        Spawn_Gauntlet6_BlindChoir(FMars_SandboxGauntlet_Cell(FVector(-1500.0, 2600.0, 0.0), "Gauntlet6"));
        Spawn_Gauntlet1_MournersTable(FMars_SandboxGauntlet_Cell(FVector(-400.0, 2600.0, 0.0), "Gauntlet1"));
        Spawn_Gauntlet5_PortersWager(FMars_SandboxGauntlet_Cell(FVector(400.0, 2600.0, 0.0), "Gauntlet5"));
        Spawn_Gauntlet4_CensersWindow(FMars_SandboxGauntlet_Cell(FVector(1400.0, 2600.0, 0.0), "Gauntlet4"));
    }

    // Local origin (0, 2000): the hall's south edge on the main floor's north edge. Its north side is the cells' south
    // walls plus a filler across each 100 uu gap between cells.
    void Spawn_GauntletHall()
    {
        const auto Hall = FMars_SandboxGauntlet_Cell(FVector(0.0, 2000.0, 0.0), "GauntletHall");
        const auto Height = k_GauntletWallHeight;

        Hall.Block("Floor", FVector(-3700.0, 0.0, -20.0), FVector(2000.0, 600.0, 0.0));

        // The main floor ends at X=-2000; west of it the hall's south edge needs a wall.
        Hall.Block("WallSouth", FVector(-3700.0, -10.0, 0.0), FVector(-2000.0, 10.0, Height));
        Hall.Block("WallWest", FVector(-3710.0, 0.0, 0.0), FVector(-3690.0, 600.0, Height));
        Hall.Block("WallEast", FVector(1990.0, 0.0, 0.0), FVector(2010.0, 600.0, Height));

        Hall.Block("Filler_3_6", FVector(-2200.0, 590.0, 0.0), FVector(-2100.0, 610.0, Height));
        Hall.Block("Filler_6_1", FVector(-900.0, 590.0, 0.0), FVector(-800.0, 610.0, Height));
        Hall.Block("Filler_1_5", FVector(0.0, 590.0, 0.0), FVector(100.0, 610.0, Height));
        Hall.Block("Filler_5_4", FVector(700.0, 590.0, 0.0), FVector(800.0, 610.0, Height));
    }

    // 01 - The Mourner's Table. 8 x 8 m, flat. Two oversized relief plates face a barred alcove in the north wall; the chef
    // plate and the dropped-pack plate pressed together latch it open. The truffle sits at the alcove's back, out of reach
    // through the bars (the interaction trace is 250 uu).
    void Spawn_Gauntlet1_MournersTable(const FMars_SandboxGauntlet_Cell& InCell)
    {
        const auto Height = k_GauntletWallHeight;

        InCell.Block("Floor", FVector(-400.0, 0.0, -20.0), FVector(400.0, 800.0, 0.0));
        InCell.Block("AlcoveFloor", FVector(-150.0, 800.0, -20.0), FVector(150.0, 1100.0, 0.0));

        InCell.Block("WallSouth_West", FVector(-400.0, -10.0, 0.0), FVector(-150.0, 10.0, Height));
        InCell.Block("WallSouth_East", FVector(150.0, -10.0, 0.0), FVector(400.0, 10.0, Height));
        InCell.Block("WallWest", FVector(-410.0, 0.0, 0.0), FVector(-390.0, 800.0, Height));
        InCell.Block("WallEast", FVector(390.0, 0.0, 0.0), FVector(410.0, 800.0, Height));
        InCell.GatedWallAlongX("WallNorth", FVector(0.0, 800.0, Height), FVector2D(-400.0, 400.0));

        InCell.Block("AlcoveWall_West", FVector(-160.0, 800.0, 0.0), FVector(-140.0, 1100.0, Height));
        InCell.Block("AlcoveWall_East", FVector(140.0, 800.0, 0.0), FVector(160.0, 1100.0, Height));
        InCell.Block("AlcoveWall_North", FVector(-150.0, 1090.0, 0.0), FVector(150.0, 1110.0, Height));

        // Gates yawed 90 span X; plates yawed 90 so their decals read upright to a player walking north.
        const auto North = FRotator(0.0, 90.0, 0.0);
        InCell.Place(UMars_Gauntlet_Mourner_AlcoveGate_EntityScript, "Mech_AlcoveGate", FTransform(North, FVector(0.0, 800.0, 0.0)));
        InCell.Place(UMars_Gauntlet_Mourner_ChefPlate_EntityScript, "Mech_ChefPlate", FTransform(North, FVector(-180.0, 420.0, 0.0)));
        InCell.Place(UMars_Gauntlet_Mourner_PackPlate_EntityScript, "Mech_PackPlate", FTransform(North, FVector(180.0, 420.0, 0.0)));
        InCell.Place(UMars_Gauntlet_Truffle_EntityScript, "Item_Truffle", FTransform(FRotator::ZeroRotator, FVector(0.0, 1050.0, 30.0)));
    }

    // 03 - The Bellkeeper's Confession. 15 x 14 m, two height bands. The barred reliquary (north-west) shows from the door,
    // with the order relief (circle -> triangle) on its header and the sequence lamps beside it. The circle seal is on the
    // lower west wall; the triangle seal on the east wall of the gallery (top 300), up a 3 m wide stair. Inside the
    // reliquary a hand wheel latches the return door into the west corridor, which runs straight back to the hall.
    void Spawn_Gauntlet3_Bellkeeper(const FMars_SandboxGauntlet_Cell& InCell)
    {
        const auto Height = k_GauntletTallWallHeight;

        InCell.Block("Floor", FVector(-900.0, 0.0, -20.0), FVector(600.0, 1400.0, 0.0));

        // South wall: the return corridor's mouth (X -900..-600) and the main doorway are open.
        InCell.Block("WallSouth_West", FVector(-600.0, -10.0, 0.0), FVector(-150.0, 10.0, Height));
        InCell.Block("WallSouth_East", FVector(150.0, -10.0, 0.0), FVector(600.0, 10.0, Height));
        InCell.Block("WallWest", FVector(-910.0, 0.0, 0.0), FVector(-890.0, 1400.0, Height));
        InCell.Block("WallEast", FVector(590.0, 0.0, 0.0), FVector(610.0, 1400.0, Height));
        InCell.Block("WallNorth", FVector(-900.0, 1390.0, 0.0), FVector(600.0, 1410.0, Height));

        // The corridor's east wall, then the reliquary's west wall with the return door centred on Y=1250.
        InCell.Block("CorridorWall", FVector(-610.0, 0.0, 0.0), FVector(-590.0, 1100.0, Height));
        InCell.Block("ReliquaryWall_West_South", FVector(-610.0, 1100.0, 0.0), FVector(-590.0, 1130.0, Height));
        InCell.Block("ReliquaryWall_West_North", FVector(-610.0, 1370.0, 0.0), FVector(-590.0, 1400.0, Height));
        InCell.Block("ReliquaryWall_West_Header", FVector(-610.0, 1130.0, 240.0), FVector(-590.0, 1370.0, Height));
        InCell.Block("ReliquaryWall_East", FVector(-160.0, 1100.0, 0.0), FVector(-140.0, 1400.0, Height));
        InCell.GatedWallAlongX("ReliquaryFront", FVector(-375.0, 1100.0, Height), FVector2D(-600.0, -150.0));

        // Gallery: a solid band X 250..600, Y 650..1400, top 300, reached by the stair rising north from Y=200.
        InCell.Block("Gallery", FVector(250.0, 650.0, 0.0), FVector(600.0, 1400.0, 300.0));
        InCell.Stair("Stair", FMars_SandboxGauntlet_Stair(FVector(300.0, 200.0, 0.0), 300.0));
        InCell.Balustrade("GalleryRail_West", FVector(260.0, 655.0, 300.0), FVector(260.0, 1395.0, 300.0));
        InCell.Balustrade("GalleryRail_South", FVector(260.0, 660.0, 300.0), FVector(295.0, 660.0, 300.0));

        // The order relief over the reliquary gate, read left to right by a player looking north (+X is their left).
        const auto ReliefZ = 300.0;
        InCell.Glyph("Glyph_ClueCircle", EMars_Seal_Glyph::Circle, FVector(-305.0, 1088.0, ReliefZ));
        InCell.Arrow("Glyph_ClueArrow", FVector(-375.0, 1088.0, ReliefZ));
        InCell.Glyph("Glyph_ClueTriangle", EMars_Seal_Glyph::Triangle, FVector(-445.0, 1088.0, ReliefZ));

        // Seals face out of their walls (pitch -90 faces +X; yaw 180 then faces -X). The triangle seal sits high enough on
        // the gallery wall to show over the gallery's edge from the middle of the lower floor.
        InCell.Place(UMars_Gauntlet_Bell_CircleSeal_EntityScript, "Mech_CircleSeal",
            FTransform(FRotator(-90.0, 0.0, 0.0), FVector(-590.0, 600.0, 120.0)));
        InCell.Place(UMars_Gauntlet_Bell_TriangleSeal_EntityScript, "Mech_TriangleSeal",
            FTransform(FRotator(-90.0, 180.0, 0.0), FVector(590.0, 1000.0, 460.0)));

        // Yawed 90, the sequence lamps run circle (left) to triangle (right) for a player looking north.
        const auto North = FRotator(0.0, 90.0, 0.0);
        InCell.Place(UMars_Gauntlet_Bell_Sequence_EntityScript, "Mech_Sequence", FTransform(North, FVector(-540.0, 1030.0, 0.0)));
        InCell.Place(UMars_Gauntlet_Bell_ReliquaryGate_EntityScript, "Mech_ReliquaryGate", FTransform(North, FVector(-375.0, 1100.0, 0.0)));

        // The wheel on the reliquary's north wall (yaw -90 points its +X out of the wall, south); the door spans Y (yaw 0).
        InCell.Place(UMars_Gauntlet_Bell_ReturnWheel_EntityScript, "Mech_ReturnWheel",
            FTransform(FRotator(0.0, -90.0, 0.0), FVector(-480.0, 1390.0, 110.0)));
        InCell.Place(UMars_Gauntlet_Bell_ReturnDoor_EntityScript, "Mech_ReturnDoor", FTransform(FRotator::ZeroRotator, FVector(-600.0, 1250.0, 0.0)));

        InCell.Place(UMars_Gauntlet_Root_EntityScript, "Item_Root", FTransform(FRotator::ZeroRotator, FVector(-300.0, 1360.0, 30.0)));
    }

    // 04 - The Censer's Window. 12 x 9 m. A full-height divider splits the middle band: west, the censer's lane ending in a
    // shutter; east, a walled slalom that always works. A chain at the lanes' mouth (and one past the shutter) lights three
    // lamps over the shutter; while any is lit the censer is caught at its west extreme and the shutter is up. The shutter
    // waits for an empty doorway before it drops.
    void Spawn_Gauntlet4_CensersWindow(const FMars_SandboxGauntlet_Cell& InCell)
    {
        const auto Height = k_GauntletWallHeight;

        InCell.Block("Floor", FVector(-600.0, 0.0, -20.0), FVector(600.0, 900.0, 0.0));

        InCell.Block("WallSouth_West", FVector(-600.0, -10.0, 0.0), FVector(-150.0, 10.0, Height));
        InCell.Block("WallSouth_East", FVector(150.0, -10.0, 0.0), FVector(600.0, 10.0, Height));
        InCell.Block("WallWest", FVector(-610.0, 0.0, 0.0), FVector(-590.0, 900.0, Height));
        InCell.Block("WallEast", FVector(590.0, 0.0, 0.0), FVector(610.0, 900.0, Height));
        InCell.Block("WallNorth", FVector(-600.0, 890.0, 0.0), FVector(600.0, 910.0, Height));

        InCell.Block("Divider", FVector(-60.0, 250.0, 0.0), FVector(60.0, 650.0, Height));
        InCell.GatedWallAlongX("LaneEnd", FVector(-330.0, 650.0, Height), FVector2D(-600.0, -60.0));

        // The slalom: two staggered baffles, each leaving a 200 uu gap.
        InCell.Block("Baffle_South", FVector(60.0, 370.0, 0.0), FVector(400.0, 390.0, Height));
        InCell.Block("Baffle_North", FVector(260.0, 510.0, 0.0), FVector(600.0, 530.0, Height));

        InCell.Block("Plinth", FVector(-60.0, 760.0, 0.0), FVector(60.0, 860.0, 80.0));

        // Yaw 0: the censer swings across the lane (local X); -90 / 90 point the lamps' and chains' +X south / north.
        const auto South = FRotator(0.0, -90.0, 0.0);
        const auto North = FRotator(0.0, 90.0, 0.0);
        InCell.Place(UMars_Gauntlet_Censer_EntityScript, "Mech_Censer", FTransform(FRotator::ZeroRotator, FVector(-330.0, 450.0, 0.0)));
        InCell.Place(UMars_Gauntlet_Censer_Shutter_EntityScript, "Mech_Shutter", FTransform(North, FVector(-330.0, 650.0, 0.0)));
        InCell.Place(UMars_Gauntlet_Censer_Lamps_EntityScript, "Mech_Lamps", FTransform(South, FVector(-330.0, 640.0, 270.0)));
        InCell.Place(UMars_Gauntlet_Censer_Chain_EntityScript, "Mech_ChainNear", FTransform(South, FVector(0.0, 250.0, 260.0)));
        InCell.Place(UMars_Gauntlet_Censer_Chain_EntityScript, "Mech_ChainFar", FTransform(North, FVector(-150.0, 660.0, 260.0)));
    }

    // 05 - The Porter's Wager. A 6 x 11 m freight passage: the pack slab, then a barred freight gate in a partition at Y=500
    // with three grace lamps over it, then the salt niche at the far end. Inside the gate: a chain on the partition and an
    // invisible volume over the whole passage (Y 520..1090) that holds the lamps full while a dropped pack lies in it.
    void Spawn_Gauntlet5_PortersWager(const FMars_SandboxGauntlet_Cell& InCell)
    {
        const auto Height = k_GauntletWallHeight;

        InCell.Block("Floor", FVector(-300.0, 0.0, -20.0), FVector(300.0, 1100.0, 0.0));

        InCell.Block("WallSouth_West", FVector(-300.0, -10.0, 0.0), FVector(-150.0, 10.0, Height));
        InCell.Block("WallSouth_East", FVector(150.0, -10.0, 0.0), FVector(300.0, 10.0, Height));
        InCell.Block("WallWest", FVector(-310.0, 0.0, 0.0), FVector(-290.0, 1100.0, Height));
        InCell.Block("WallEast", FVector(290.0, 0.0, 0.0), FVector(310.0, 1100.0, Height));
        InCell.Block("WallNorth", FVector(-300.0, 1090.0, 0.0), FVector(300.0, 1110.0, Height));
        InCell.GatedWallAlongX("Partition", FVector(0.0, 500.0, Height), FVector2D(-300.0, 300.0));

        InCell.Block("Plinth", FVector(-60.0, 980.0, 0.0), FVector(60.0, 1090.0, 60.0));

        const auto South = FRotator(0.0, -90.0, 0.0);
        const auto North = FRotator(0.0, 90.0, 0.0);
        InCell.Place(UMars_Gauntlet_Porter_Slab_EntityScript, "Mech_Slab", FTransform(North, FVector(0.0, 300.0, 0.0)));
        InCell.Place(UMars_Gauntlet_Porter_Gate_EntityScript, "Mech_FreightGate", FTransform(North, FVector(0.0, 500.0, 0.0)));
        InCell.Place(UMars_Gauntlet_Porter_Lamps_EntityScript, "Mech_Lamps", FTransform(South, FVector(0.0, 490.0, 270.0)));
        InCell.Place(UMars_Gauntlet_Porter_Chain_EntityScript, "Mech_ChainInside", FTransform(North, FVector(200.0, 510.0, 260.0)));
        InCell.Place(UMars_Gauntlet_Porter_PackInside_EntityScript, "Mech_PackInside", FTransform(FRotator::ZeroRotator, FVector(0.0, 805.0, 0.0)));
        InCell.Place(UMars_Gauntlet_Salt_EntityScript, "Item_Salt", FTransform(FRotator::ZeroRotator, FVector(0.0, 1035.0, 90.0)));
    }

    // 06 - The Blind Choir. 12 x 10 m, two height bands. The gallery (Y 750..1000, top 300, solid parapet) is reached by a
    // stair on the west; the barred fungus vault is cut into its front. Above the vault, the north wall holds the viewing
    // shutter into the bell loft (Y 1000..1300), hidden from the lower floor by the gallery and its parapet. The lower
    // wheel latches the shutter open; the plaque on the bell reads circle -> triangle. The lower seals sit on the east wall,
    // triangle first, so reading them left to right is the wrong order.
    void Spawn_Gauntlet6_BlindChoir(const FMars_SandboxGauntlet_Cell& InCell)
    {
        const auto Height = k_GauntletTallWallHeight;

        InCell.Block("Floor", FVector(-600.0, 0.0, -20.0), FVector(600.0, 1000.0, 0.0));

        InCell.Block("WallSouth_West", FVector(-600.0, -10.0, 0.0), FVector(-150.0, 10.0, Height));
        InCell.Block("WallSouth_East", FVector(150.0, -10.0, 0.0), FVector(600.0, 10.0, Height));
        InCell.Block("WallWest", FVector(-610.0, 0.0, 0.0), FVector(-590.0, 1000.0, Height));
        InCell.Block("WallEast", FVector(590.0, 0.0, 0.0), FVector(610.0, 1000.0, Height));

        // North wall around the shutter's frame (X -120..120, Z 300..540); below the frame the vault runs on through it.
        InCell.Block("WallNorth_West", FVector(-600.0, 990.0, 0.0), FVector(-120.0, 1010.0, Height));
        InCell.Block("WallNorth_East", FVector(120.0, 990.0, 0.0), FVector(600.0, 1010.0, Height));
        InCell.Block("WallNorth_Sill", FVector(-120.0, 990.0, 260.0), FVector(120.0, 1010.0, 300.0));
        InCell.Block("WallNorth_Header", FVector(-120.0, 990.0, 540.0), FVector(120.0, 1010.0, Height));

        // Gallery with the vault (X -150..150, 260 high) cut into its front; the vault runs on, 240 wide, under the loft to
        // Y=1200, so the fungus at its back lies past the interaction trace's reach through the bars.
        InCell.Block("Gallery_West", FVector(-600.0, 750.0, 0.0), FVector(-150.0, 1000.0, 300.0));
        InCell.Block("Gallery_East", FVector(150.0, 750.0, 0.0), FVector(600.0, 1000.0, 300.0));
        InCell.Block("Gallery_VaultRoof", FVector(-150.0, 750.0, 260.0), FVector(150.0, 1000.0, 300.0));
        InCell.Block("VaultFront_West", FVector(-150.0, 740.0, 0.0), FVector(-120.0, 760.0, 260.0));
        InCell.Block("VaultFront_East", FVector(120.0, 740.0, 0.0), FVector(150.0, 760.0, 260.0));
        InCell.Block("VaultFront_Header", FVector(-120.0, 740.0, 240.0), FVector(120.0, 760.0, 260.0));
        InCell.Block("VaultBack_West", FVector(-140.0, 1000.0, 0.0), FVector(-120.0, 1200.0, 280.0));
        InCell.Block("VaultBack_East", FVector(120.0, 1000.0, 0.0), FVector(140.0, 1200.0, 280.0));
        InCell.Block("VaultBack_North", FVector(-140.0, 1200.0, 0.0), FVector(140.0, 1220.0, 280.0));
        InCell.Stair("Stair", FMars_SandboxGauntlet_Stair(FVector(-600.0, 300.0, 0.0), 300.0));
        InCell.Block("GalleryParapet", FVector(-300.0, 750.0, 300.0), FVector(600.0, 770.0, 400.0));

        // The loft: walls to full height, a floor level with the gallery, the bell hung in it with the order plaque on the
        // face the shutter looks at.
        InCell.Block("LoftFloor", FVector(-300.0, 1000.0, 280.0), FVector(300.0, 1300.0, 300.0));
        InCell.Block("LoftWall_West", FVector(-310.0, 1000.0, 0.0), FVector(-290.0, 1300.0, Height));
        InCell.Block("LoftWall_East", FVector(290.0, 1000.0, 0.0), FVector(310.0, 1300.0, Height));
        InCell.Block("LoftWall_North", FVector(-300.0, 1290.0, 0.0), FVector(300.0, 1310.0, Height));
        utils_mars_map_builder::Spawn_Block(engine::load::Cone(), f"{InCell.Prefix}_Bell",
            InCell.Origin + FVector(0.0, 1170.0, 480.0), FVector(2.4, 2.4, 2.4));
        InCell.Block("BellChain", FVector(-5.0, 1165.0, 600.0), FVector(5.0, 1175.0, Height));
        InCell.Block("BellPlaque", FVector(-110.0, 1036.0, 420.0), FVector(110.0, 1044.0, 520.0));
        InCell.Glyph("Glyph_BellCircle", EMars_Seal_Glyph::Circle, FVector(60.0, 1032.0, 470.0));
        InCell.Arrow("Glyph_BellArrow", FVector(0.0, 1032.0, 470.0));
        InCell.Glyph("Glyph_BellTriangle", EMars_Seal_Glyph::Triangle, FVector(-60.0, 1032.0, 470.0));

        const auto North = FRotator(0.0, 90.0, 0.0);
        InCell.Place(UMars_Gauntlet_Choir_Wheel_EntityScript, "Mech_Wheel", FTransform(FRotator::ZeroRotator, FVector(-590.0, 150.0, 110.0)));
        InCell.Place(UMars_Gauntlet_Choir_Shutter_EntityScript, "Mech_Shutter", FTransform(North, FVector(0.0, 1000.0, 300.0)));

        // East wall, facing -X: triangle at Y=250 (a player facing east sees it on the left), circle at Y=500.
        const auto FacingWest = FRotator(-90.0, 180.0, 0.0);
        InCell.Place(UMars_Gauntlet_Choir_TriangleSeal_EntityScript, "Mech_TriangleSeal", FTransform(FacingWest, FVector(590.0, 250.0, 120.0)));
        InCell.Place(UMars_Gauntlet_Choir_CircleSeal_EntityScript, "Mech_CircleSeal", FTransform(FacingWest, FVector(590.0, 500.0, 120.0)));

        InCell.Place(UMars_Gauntlet_Choir_Sequence_EntityScript, "Mech_Sequence", FTransform(North, FVector(300.0, 680.0, 0.0)));
        InCell.Place(UMars_Gauntlet_Choir_VaultGate_EntityScript, "Mech_VaultGate", FTransform(North, FVector(0.0, 750.0, 0.0)));
        InCell.Place(UMars_Gauntlet_Fungus_EntityScript, "Item_Fungus", FTransform(FRotator::ZeroRotator, FVector(0.0, 1150.0, 30.0)));
    }

    // Floors grey, raised and edge pieces (galleries, stairs, rails, plinths, the bell) orange, clue glyphs green, the rest
    // walls.
    void Apply_GauntletMaterial(AStaticMeshActor InBlock, const FString& InLabel)
    {
        auto Material = utils_mars_map_builder::Get_ProtoGrid_Wall();
        if (InLabel.EndsWith("_Floor") || InLabel.EndsWith("AlcoveFloor"))
        { Material = utils_mars_map_builder::Get_ProtoGrid_Floor(); }
        else if (InLabel.Contains("_Glyph"))
        { Material = utils_mars_map_builder::Get_ProtoGrid_Interactable(); }
        else if (InLabel.Contains("_Gallery") || InLabel.Contains("_Stair") || InLabel.Contains("Rail")
            || InLabel.Contains("Parapet") || InLabel.Contains("_Plinth") || InLabel.Contains("_Bell") || InLabel.Contains("LoftFloor"))
        { Material = utils_mars_map_builder::Get_ProtoGrid_Platform(); }

        InBlock.StaticMeshComponent.SetMaterial(0, Material);
    }
}
#endif
