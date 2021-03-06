-----------------------------------------------------------------------------
--
-- Pretty-printing assembly language
--
-- (c) The University of Glasgow 1993-2005
--
-----------------------------------------------------------------------------

module PprBase (
        castFloatToWord8Array,
        castDoubleToWord8Array,
        floatToBytes,
        doubleToBytes,
        pprSectionHeader
)

where

import CLabel
import Cmm
import DynFlags
import FastString
import Outputable
import Platform

import qualified Data.Array.Unsafe as U ( castSTUArray )
import Data.Array.ST

import Control.Monad.ST

import Data.Word



-- -----------------------------------------------------------------------------
-- Converting floating-point literals to integrals for printing

castFloatToWord8Array :: STUArray s Int Float -> ST s (STUArray s Int Word8)
castFloatToWord8Array = U.castSTUArray

castDoubleToWord8Array :: STUArray s Int Double -> ST s (STUArray s Int Word8)
castDoubleToWord8Array = U.castSTUArray

-- floatToBytes and doubleToBytes convert to the host's byte
-- order.  Providing that we're not cross-compiling for a
-- target with the opposite endianness, this should work ok
-- on all targets.

-- ToDo: this stuff is very similar to the shenanigans in PprAbs,
-- could they be merged?

floatToBytes :: Float -> [Int]
floatToBytes f
   = runST (do
        arr <- newArray_ ((0::Int),3)
        writeArray arr 0 f
        arr <- castFloatToWord8Array arr
        i0 <- readArray arr 0
        i1 <- readArray arr 1
        i2 <- readArray arr 2
        i3 <- readArray arr 3
        return (map fromIntegral [i0,i1,i2,i3])
     )

doubleToBytes :: Double -> [Int]
doubleToBytes d
   = runST (do
        arr <- newArray_ ((0::Int),7)
        writeArray arr 0 d
        arr <- castDoubleToWord8Array arr
        i0 <- readArray arr 0
        i1 <- readArray arr 1
        i2 <- readArray arr 2
        i3 <- readArray arr 3
        i4 <- readArray arr 4
        i5 <- readArray arr 5
        i6 <- readArray arr 6
        i7 <- readArray arr 7
        return (map fromIntegral [i0,i1,i2,i3,i4,i5,i6,i7])
     )

-- ----------------------------------------------------------------------------
-- Printing section headers.
--
-- If -split-section was specified, include the suffix label, otherwise just
-- print the section type. For Darwin, where subsections-for-symbols are
-- used instead, only print section type.

pprSectionHeader :: Platform -> Section -> SDoc
pprSectionHeader platform (Section t suffix) =
 case platformOS platform of
   OSDarwin -> pprDarwinSectionHeader t
   _        -> pprGNUSectionHeader t suffix

pprGNUSectionHeader :: SectionType -> CLabel -> SDoc
pprGNUSectionHeader t suffix = sdocWithDynFlags $ \dflags ->
  let splitSections = gopt Opt_SplitSections dflags
      subsection | splitSections = char '.' <> ppr suffix
                 | otherwise     = empty
  in  ptext (sLit ".section ") <> ptext header <> subsection
  where
    header = case t of
      Text -> sLit ".text"
      Data -> sLit ".data"
      ReadOnlyData -> sLit ".rodata"
      RelocatableReadOnlyData -> sLit ".data.rel.ro"
      UninitialisedData -> sLit ".bss"
      ReadOnlyData16 -> sLit ".rodata.cst16"
      OtherSection _ ->
        panic "PprBase.pprGNUSectionHeader: unknown section type"

pprDarwinSectionHeader :: SectionType -> SDoc
pprDarwinSectionHeader t =
  ptext $ case t of
     Text -> sLit ".text"
     Data -> sLit ".data"
     ReadOnlyData -> sLit ".const"
     RelocatableReadOnlyData -> sLit ".const_data"
     UninitialisedData -> sLit ".data"
     ReadOnlyData16 -> sLit ".const"
     OtherSection _ ->
       panic "PprBase.pprDarwinSectionHeader: unknown section type"
