--------------------------------------------------------------------------------
-- Copyright 2001-2012, Daan Leijen, Bastiaan Heeren, Jurriaan Hage. This file 
-- is distributed under the terms of the BSD3 License. For more information, 
-- see the file "LICENSE.txt", which is included in the distribution.
--------------------------------------------------------------------------------
--  $Id: Data.hs 250 2012-08-22 10:59:40Z bastiaan $

module Lvm.Core.Utils 
   ( module Lvm.Core.Module
   , listFromBinds, unzipBinds, mapBinds, mapAccumBinds, zipBindsWith
   , mapAlts, zipAltsWith, mapExprWithSupply, mapAccum
   ) where

import Lvm.Core.Expr
import Lvm.Common.Id
import Lvm.Core.Module

----------------------------------------------------------------
-- Binders functions
----------------------------------------------------------------

listFromBinds :: Binds -> [Bind]
listFromBinds binds
  = case binds of
      NonRec bind -> [bind]
      Strict bind -> [bind]
      Rec recs    -> recs

unzipBinds :: [Bind] -> ([Id],[Expr])
unzipBinds = unzip . map (\(Bind x rhs) -> (x,rhs))

mapBinds :: (Id -> Expr -> Bind) -> Binds -> Binds
mapBinds f binds
  = case binds of
      NonRec (Bind x rhs)
        -> NonRec (f x rhs)
      Strict (Bind x rhs)
        -> Strict (f x rhs)
      Rec recs
        -> Rec (map (\(Bind x rhs) -> f x rhs) recs)

mapAccumBinds :: (a -> Id -> Expr -> (Bind,a)) -> a -> Binds -> (Binds,a)
mapAccumBinds f x binds
  = case binds of
      NonRec (Bind y rhs)
        -> let (bind,z) = f x y rhs
           in  (NonRec bind, z)
      Strict (Bind y rhs)
        -> let (bind,z) = f x y rhs
           in  (Strict bind, z)
      Rec recs
        -> let (recs',z) = mapAccum (\a (Bind y rhs) -> f a y rhs) x recs
           in  (Rec recs',z)

mapAccum               :: (a -> b -> (c,a)) -> a -> [b] -> ([c],a)
mapAccum _ s []         = ([],s)
mapAccum f s (x:xs)     = (y:ys,s'')
                         where (y,s' )  = f s x
                               (ys,s'') = mapAccum f s' xs


zipBindsWith :: (a -> Id -> Expr -> Bind) -> [a] -> Binds -> Binds
zipBindsWith f (x:_) (Strict (Bind y rhs))
  = Strict (f x y rhs)
zipBindsWith f (x:_) (NonRec (Bind y rhs))
  = NonRec (f x y rhs)
zipBindsWith f xs (Rec recs)
  = Rec (zipWith (\x (Bind y rhs) -> f x y rhs) xs recs)
zipBindsWith _ _ _ 
  = error "zipBindsWith"

----------------------------------------------------------------
-- Alternatives functions
----------------------------------------------------------------

mapAlts :: (Pat -> Expr -> Alt) -> Alts -> Alts
mapAlts f = map (\(Alt pat expr) -> f pat expr)

zipAltsWith :: (a -> Pat -> Expr -> Alt) -> [a] -> Alts -> Alts
zipAltsWith f = zipWith (\x (Alt pat expr) -> f x pat expr)

----------------------------------------------------------------
--
----------------------------------------------------------------

mapExprWithSupply :: (NameSupply -> Expr -> Expr) -> NameSupply -> CoreModule -> CoreModule
mapExprWithSupply f supply m
  = m { moduleDecls = mapWithSupply fvalue supply (moduleDecls m) }
  where
    fvalue sup decl@(DeclValue{}) = decl{ valueValue = f sup (valueValue decl)}
    fvalue _   decl               = decl
