module game.blocks;
import engine;

import game.blocks.dirt;
import game.blocks.grass;

/**
    Initialize blocks
*/
void fcInitBlocks() {
    fcRegisterBlock(new DirtBlock, 1);
    fcRegisterBlock(new GrassBlock, 2);
}