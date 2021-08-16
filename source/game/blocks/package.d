module game.blocks;
import engine;

import game.blocks.dirt;
import game.blocks.grass;
import game.blocks.glass;
import game.blocks.stone;

/**
    Initialize blocks
*/
void fcInitBlocks() {
    fcRegisterBlock(new StoneBlock, 1);
    fcRegisterBlock(new DirtBlock, 2);
    fcRegisterBlock(new GrassBlock, 3);
    fcRegisterBlock(new GlassBlock, 4);
}