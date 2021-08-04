module game.blocks.grass;
import engine;

/**
    A grass block
*/
class GrassBlock : Block {
    /**
        Instantiates this grass block
    */
    this() {
        this.setTexturesSides([
            "grass_side",
            "grass_side",
            "grass_top",
            "dirt",
            "grass_side",
            "grass_side",
        ]);
        this.setName("Grass");
    }
} 