module game.blocks.dirt;
import engine;

/**
    A dirt block
*/
class DirtBlock : Block {
    /**
        Instantiates this dirt block
    */
    this() {
        this.setTexture("dirt");
        this.setName("Dirt");
    }
} 