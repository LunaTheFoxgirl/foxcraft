module game.blocks.stone;
import engine;

/**
    A stone block
*/
class StoneBlock : Block {
    /**
        Instantiates this stone block
    */
    this() {
        this.setTexture("stone");
        this.setName("Stone");
    }
} 