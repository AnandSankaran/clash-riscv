{-# LANGUAGE ImplicitParams #-}
module System where

import Clash.Prelude
import qualified Prelude as P
import RiscV.RV32I
import RiscV.Encode.RV32I
import Core.Pipeline
import Prog

system :: HiddenClockResetEnable dom => Vec (2 ^ 10) (BitVector 32) -> Signal dom ToDataMem
system program = register (errorX "X") toDataMem
    where
    --The instruction memory
    instr_0 = romPow2 program (resize . instructionAddress <$> toInstructionMem)
    --The data memory
    memReadData_3' = readNew (blockRamPow2 (repeat 0 :: Vec (2 ^ 10) (BitVector 32)))
        ((resize . readAddress)  <$> toDataMem) --read address
        (mux ((/=0) . writeStrobe <$> toDataMem) (Just <$> bundle ((resize . writeAddress) <$> toDataMem, writeData <$> toDataMem)) (pure Nothing))

    --The processor
    (toInstructionMem, toDataMem, _) = pipeline (FromInstructionMem <$> instr_0 <*> pure False) (FromDataMem <$> memReadData_3')

{-# ANN topEntity
  (Synthesize
    { t_name   = "riscvPipeline"
    , t_inputs = [PortName "clk", PortName "rst"]
    , t_output = PortProduct "res" [PortName "readAddress", PortName "writeAddress", PortName "writeData", PortName "writeStrobe"]
    }) #-}
topEntity :: Clock System -> Reset System -> Signal System ToDataMem
topEntity clk rst = withClockResetEnable clk rst enableGen $ system ($(listToVecTH (P.map encodeInstr fib)) ++ repeat 0)
