-- |
-- Module      : Crypto.PubKey.RSA.Prim
-- License     : BSD-style
-- Maintainer  : Vincent Hanquez <vincent@snarc.org>
-- Stability   : experimental
-- Portability : Good
--
module Crypto.PubKey.RSA.Prim
    (
    -- * decrypt primitive
      dp
    , dpWithBlinding
    -- * encrypt primitive
    , ep
    ) where

import Data.ByteString (ByteString)
import Data.Maybe (fromJust)
import Crypto.Types.PubKey.RSA
import Crypto.Number.ModArithmetic (exponantiation, inverse)
import Crypto.Number.Serialize (os2ip, i2ospOf_)

{- dpSlow computes the decrypted message not using any precomputed cache value.
   only n and d need to valid. -}
dpSlow :: PrivateKey -> ByteString -> ByteString
dpSlow pk c = i2ospOf_ (private_size pk) $ expmod (os2ip c) (private_d pk) (private_n pk)

{- dpFast computes the decrypted message more efficiently if the
   precomputed private values are available. mod p and mod q are faster
   to compute than mod pq -}
dpFast :: Integer -> PrivateKey -> ByteString -> ByteString
dpFast r pk c = i2ospOf_ (private_size pk) (multiplication rm1 (m2 + h * (private_q pk)) (private_n pk))
    where
        re  = expmod r (public_e $ private_pub pk) (private_n pk)
        rm1 = fromJust $ inverse r (private_n pk)
        iC  = multiplication re (os2ip c) (private_n pk)
        m1  = expmod iC (private_dP pk) (private_p pk)
        m2  = expmod iC (private_dQ pk) (private_q pk)
        h   = ((private_qinv pk) * (m1 - m2)) `mod` (private_p pk)

dpFastNoBlinder :: PrivateKey -> ByteString -> ByteString
dpFastNoBlinder pk c = i2ospOf_ (private_size pk) (m2 + h * (private_q pk))
     where iC = os2ip c
           m1 = expmod iC (private_dP pk) (private_p pk)
           m2 = expmod iC (private_dQ pk) (private_q pk)
           h  = ((private_qinv pk) * (m1 - m2)) `mod` (private_p pk)

-- | Compute the RSA decrypt primitive.
-- if the p and q numbers are available, then dpFast is used
-- otherwise, we use dpSlow which only need d and n.
dp :: PrivateKey -> ByteString -> ByteString
dp pk
    | private_p pk /= 0 && private_q pk /= 0 = dpFastNoBlinder pk
    | otherwise                              = dpSlow pk

-- | Compute the RSA decrypt primitive
--
-- the blinder is a number between 1 and n,
-- and will be multiplied after exponantiation to e to the message.
-- This is a no-op in term of result, however it provides randomization
-- of the timing.
dpWithBlinding :: Integer -> PrivateKey -> ByteString -> ByteString
dpWithBlinding blinder pk
    | private_p pk /= 0 && private_q pk /= 0 = dpFast blinder pk
    | otherwise                              = dpSlow pk

-- | Compute the RSA encrypt primitive
ep :: PublicKey -> ByteString -> ByteString
ep pk m = i2ospOf_ (public_size pk) $ expmod (os2ip m) (public_e pk) (public_n pk)

expmod :: Integer -> Integer -> Integer -> Integer
expmod = exponantiation

-- | multiply 2 integers in Zm only performing the modulo operation if necessary
multiplication :: Integer -> Integer -> Integer -> Integer
multiplication a b m = (a * b) `mod` m
