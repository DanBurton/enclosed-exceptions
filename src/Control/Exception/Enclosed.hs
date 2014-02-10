{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE NoImplicitPrelude #-}
{-# LANGUAGE TypeFamilies #-}

-- | The purpose of this module is to allow you to capture all exceptions
-- originating from within the enclosed computation, while still reacting
-- to asynchronous exceptions aimed at the calling thread.
--
-- This way, you can be sure that the function that calls, for example,
-- @'catchAny'@, will still respond to @'ThreadKilled'@ or @'Timeout'@
-- events raised by another thread (with @'throwTo'@), while capturing
-- all exceptions, synchronous or asynchronous, resulting from the
-- execution of the enclosed computation.
--
-- One particular use case is to allow the safe execution of code from various
-- libraries (which you do not control), capturing any faults that might
-- occur, while remaining responsive to higher level events and control
-- actions.
--
-- This library was originally developed by Michael Snoyman for the
-- 'ClassyPrelude' library, and was latter 'spun-off' into a separate
-- independent package.
--
-- For a more detailed explanation of the motivation behind this functions,
-- see:
--
-- <https://www.fpcomplete.com/user/snoyberg/general-haskell/exceptions/catching-all-exceptions>
--
-- and
--
-- <https://groups.google.com/forum/#!topic/haskell-cafe/e9H2I-3uVJE>
--
module Control.Exception.Enclosed
    ( -- ** Exceptions
      catchAny
    , handleAny
    , tryAny
    , catchAnyDeep
    , handleAnyDeep
    , tryAnyDeep
    , catchIO
    , handleIO
    , tryIO
      -- ** Force types
      -- | Helper functions for situations where type inferer gets confused.
    , asIOException
    , asSomeException
    ) where

import Prelude
import Control.Exception.Lifted
import Control.Monad (liftM)
import Control.Monad.Trans.Control (MonadBaseControl, liftBaseWith, restoreM)
import Control.Concurrent.Async (withAsync, waitCatch)
import Control.DeepSeq (NFData, ($!!))

-- | A version of 'catch' which is specialized for any exception. This
-- simplifies usage as no explicit type signatures are necessary.
--
-- Note that since version 0.5.9, this function now has proper support for
-- asynchronous exceptions, by only catching exceptions generated by the
-- internal (enclosed) action.
--
-- Since 0.5.6
catchAny :: MonadBaseControl IO m => m a -> (SomeException -> m a) -> m a
catchAny action onE = tryAny action >>= either onE return

-- | A version of 'handle' which is specialized for any exception.  This
-- simplifies usage as no explicit type signatures are necessary.
--
-- Note that since version 0.5.9, this function now has proper support for
-- asynchronous exceptions, by only catching exceptions generated by the
-- internal (enclosed) action.
--
-- Since 0.5.6
handleAny :: MonadBaseControl IO m => (SomeException -> m a) -> m a -> m a
handleAny = flip catchAny

-- | A version of 'try' which is specialized for any exception.
-- This simplifies usage as no explicit type signatures are necessary.
--
-- Note that since version 0.5.9, this function now has proper support for
-- asynchronous exceptions, by only catching exceptions generated by the
-- internal (enclosed) action.
--
-- Since 0.5.6
tryAny :: MonadBaseControl IO m => m a -> m (Either SomeException a)
tryAny m =
    liftBaseWith (\runInIO -> withAsync (runInIO m) waitCatch) >>=
    either (return . Left) (liftM Right . restoreM)

-- | An extension to @catchAny@ which ensures that the return value is fully
-- evaluated. See @tryAnyDeep@.
--
-- Since 0.5.9
catchAnyDeep :: (NFData a, MonadBaseControl IO m) => m a -> (SomeException -> m a) -> m a
catchAnyDeep action onE = tryAnyDeep action >>= either onE return

-- | @flip catchAnyDeep@
--
-- Since 0.5.6
handleAnyDeep :: (NFData a, MonadBaseControl IO m) => (SomeException -> m a) -> m a -> m a
handleAnyDeep = flip catchAnyDeep

-- | An extension to @tryAny@ which ensures that the return value is fully
-- evaluated. In other words, if you get a @Right@ response here, you can be
-- confident that using it will not result in another exception.
--
-- Since 0.5.9
tryAnyDeep :: (NFData a, MonadBaseControl IO m)
           => m a
           -> m (Either SomeException a)
tryAnyDeep m = tryAny $ do
    x <- m
    return $!! x

-- | A version of 'catch' which is specialized for IO exceptions. This
-- simplifies usage as no explicit type signatures are necessary.
--
-- Since 0.5.6
catchIO :: MonadBaseControl IO m => m a -> (IOException -> m a) -> m a
catchIO = catch

-- | A version of 'handle' which is specialized for IO exceptions.  This
-- simplifies usage as no explicit type signatures are necessary.
--
-- Since 0.5.6
handleIO :: MonadBaseControl IO m => (IOException -> m a) -> m a -> m a
handleIO = handle

-- | A version of 'try' which is specialized for IO exceptions.
-- This simplifies usage as no explicit type signatures are necessary.
--
-- Since 0.5.6
tryIO :: MonadBaseControl IO m => m a -> m (Either IOException a)
tryIO = try

-- |
--
-- Since 0.5.6
asSomeException :: SomeException -> SomeException
asSomeException = id

-- |
--
-- Since 0.5.6
asIOException :: IOException -> IOException
asIOException = id

