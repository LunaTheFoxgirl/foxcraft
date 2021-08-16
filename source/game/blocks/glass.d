module game.blocks.glass;
import engine;

/**
    A dirt block
*/
class GlassBlock : Block {
    /**
        Instantiates this dirt block
    */
    this() {
        this.setTexture("glass");
        this.setName("Glass");
    }
} 