{-*-----------------------------------------------------------------------
  The Core Assembler.

  Copyright 2001, Daan Leijen. All rights reserved. This file
  is distributed under the terms of the GHC license. For more
  information, see the file "license.txt", which is included in
  the distribution.
-----------------------------------------------------------------------*-}

-- $Id$

----------------------------------------------------------------
-- Annotate let bound expression with their free variables
----------------------------------------------------------------
module CoreFreeVar( coreFreeVar ) where

import Standard( trace )
import Id   ( Id )
import IdSet( IdSet, emptySet, isEmptySet
            , setFromMap, listFromSet, setFromList
            , elemSet, insertSet, unionSets, unionSet, deleteSet, diffSet )
import Core

----------------------------------------------------------------
-- coreFreeVar
-- Annotate let bound expression with their free variables
----------------------------------------------------------------
coreFreeVar :: CoreModule -> CoreModule
coreFreeVar mod
  = mapExpr (fvDeclExpr (globals mod)) mod

fvDeclExpr globals expr
  = let (expr',fv) = fvExpr globals expr
    in  if (isEmptySet fv)
        then Note (FreeVar fv) expr'
        else error ("CoreFreeVar.fvDeclExpr: top-level binding with free variables: "
                    ++ show (listFromSet fv))



fvBindExpr globals expr
  = let (expr',fv) = fvExpr globals expr
    in  (Note (FreeVar fv) expr',fv)

fvExpr :: IdSet -> Expr -> (Expr,IdSet)
fvExpr globals expr
  = case expr of
      Let binds expr
        -> let (expr',fv)       = fvExpr globals expr
               (binds',fvbinds) = fvBinds globals binds
           in (Let binds' expr', diffSet (unionSet fvbinds fv) (setFromList (binders binds)))
      Lam id expr
        -> let (expr',fv) = fvExpr globals expr
           in  (Lam id expr',deleteSet id fv)
      Case expr id alts
        -> let (expr',fv)     = fvExpr globals expr
               (alts',fvalts) = fvAlts globals alts
           in  (Case expr' id alts',unionSet (deleteSet id fvalts) fv)
      Ap expr1 expr2
        -> let (expr1',fv1)   = fvExpr globals expr1
               (expr2',fv2)   = fvExpr globals expr2
           in  (Ap expr1' expr2', unionSet fv1 fv2)
      Var id
        -> if (elemSet id globals)
            then (expr,emptySet)
            else (expr,insertSet id emptySet)
      Note n expr
        -> let (expr',fv) = fvExpr globals expr
           in  (Note n expr',fv)
      other
        -> (other,emptySet)


fvAlts :: IdSet -> Alts -> (Alts,IdSet)
fvAlts globals alts
  = let alts' = mapAlts (\pat expr -> let (expr',fv) = fvExpr globals expr
                                      in  Alt pat (Note (FreeVar fv) expr')) alts
        fvs   = unionSets (map (\(Alt pat expr) -> diffSet (freeVar expr) (patBinders pat)) (alts'))
    in  (alts',fvs)

fvBinds :: IdSet -> Binds -> (Binds,IdSet)
fvBinds globals binds
  = case binds of
      NonRec (Bind id expr)
        -> let (expr',fv) = fvBindExpr globals expr
           in  if (elemSet id fv)
                then error "CoreFreeVar.fvBinds: non-recursive binding refers to itself? (do CoreNoShadow first?)"
                else (NonRec (Bind id expr'),fv)
      other
        -> let binds' = mapBinds (\id rhs -> Bind id (fst (fvBindExpr globals rhs))) binds
               fvs    = unionSets (map (freeVar . bindExpr) (listFromBinds binds'))
           in  (binds',fvs)


freeVar expr
  = case expr of
      Note (FreeVar fv) expr  -> fv
      other                   -> error "CoreFreeVar.freeVar: no free variable annotation"