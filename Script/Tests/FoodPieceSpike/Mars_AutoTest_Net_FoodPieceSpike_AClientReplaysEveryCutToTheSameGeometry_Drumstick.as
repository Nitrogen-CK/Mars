// The server cuts 50 seeded lineages of the Drumstick joint, up to 6 committed cuts each through the real FoodPiece cut, keeping
// one half per cut; the client replays each recipe from its own import of the definition mesh and every kept half's digest
// equals the server's. World X 81000.
// Surface: Ck.FoodPieceSpike.Net.AS_FoodPieceSpike_AClientReplaysEveryCutToTheSameGeometry_Drumstick
class UCk_AutoTest_Net_FoodPieceSpike_AClientReplaysEveryCutToTheSameGeometry_Drumstick : UMars_AutoTestRig_FoodPieceSpike_Replay
{
    protected UMars_Food_Def Get_Definition() const override
    {
        return mars::Food_Drumstick_Mars;
    }

    protected int32 Get_DefinitionIndex() const override
    {
        return 2;
    }
}
