Require Import Coq.Relations.Relations.

Require Export CatSem.CAT.ind_potype.
Require Export CatSem.PCF.PCF_syntax.


Set Implicit Arguments.
Unset Strict Implicit.
Unset Transparent Obligations.
Unset Automatic Introduction.

Section close_notation.
Notation "'TY'" := PCF.Sorts.
Notation "'Bool'" := PCF.Bool.
Notation "'Nat'" := PCF.Nat.

Notation "'IT'" := (ITYPE TY).
Notation "a '~>' b" := (PCF.Arrow a b) 
   (at level 69, right associativity).
Notation "M [*:= N ]" := (substar N M) (at level 50).
Notation "'$' f" := (@_shift _ _ _ f) (at level 30).
Notation "y >>- f" := (_shift f y) (at level 44).
Notation "y >>= f" := (@subst _ _ f _ y) (at level 42).

Notation "a @ b" := (App a b)(at level 20, left associativity).
Notation "M '" := (Const _ M) (at level 15).

Ltac opt := simpl; intros; elim_opt.

Ltac fin := simpl in *; intros; 
   autorewrite with fin; auto with fin; simpl;
	try reflexivity.
Hint Unfold lift : fin.
Hint Extern 1 (_ = _) => f_equal : fin.
Hint Resolve rename_eq : fin.
Hint Rewrite rename_eq : fin.
Hint Resolve  rename_id shift_eq : fin.
Hint Rewrite  rename_id shift_eq : fin.
Hint Resolve shift_var : fin.
Hint Rewrite shift_var : fin.
Hint Resolve var_lift_shift_eq : fin.
Hint Resolve shift_lift : fin.
Hint Rewrite shift_lift : fin.
Hint Resolve subst_eq : fin.
Hint Rewrite subst_eq : fin.
Hint Rewrite subst_rename rename_subst : fin.
Hint Unfold inj : fin.
Hint Resolve subst_shift_shift subst_var subst_var_eta : fin.
Hint Rewrite subst_shift_shift subst_var subst_var_eta : fin.
Hint Resolve subst_var subst_subst : fin.
Hint Rewrite subst_subst : fin.
Hint Rewrite lift_rename : fin.

Section Relations_on_PCF.

Reserved Notation "x :> y" (at level 70).

Variable rel : forall (V:IT) t, relation (PCF V t).

Inductive propag (V: IT) 
       : forall t, relation (PCF V t) :=
| relorig : forall t (v v': PCF V t), rel v v' ->  v :> v'
| relApp1: forall (s t : TY)(M M' : PCF V (s ~> t)) N, 
       M :> M' -> App M N :> App M' N
| relApp2: forall (s t:TY)(M:PCF V (s ~> t)) N N',
      N :> N' -> M @ N :> M @ N'
| relLam: forall (s t:TY)(M M':PCF (opt s V) t),
      M :> M' -> Lam M :> Lam M'
| relRec: forall (t : TY)(M M' : PCF V (t ~> t)), 
      M :> M' -> Rec M :> Rec M'

where "x :> y" := (@propag _ _ x y). 

Notation "x :>> y" := 
  (clos_refl_trans_1n _ (@propag _ _ ) x y) (at level 50).

Variable V: IT.
Variables s t: TY.

(** these are some trivial lemmata  which will be used later *)

Lemma cp_App1 (M M': PCF V (s ~> t)) N :
    M :>> M' -> M @ N :>> M' @ N.
Proof. 
  induction 1;
  simpl; intros;
  try constructor;
  match goal with 
    [H : ?y :>> ?z|- App ?x ?N :>> App ?z ?N ] =>
      constructor 2 with (App y N) end;
  fin;
  constructor 2;
  auto.
Qed.

Lemma cp_App2 (M: PCF V (s ~> t)) N N':
    N :>> N' -> App M N :>> App M N'.
Proof. 
  induction 1;
  simpl; intros;
  try constructor;
  match goal with 
    [H : ?y :>> ?z|- App ?N ?x :>> App ?N ?z ] =>
      constructor 2 with (App N y) end;
  fin;
  constructor 3;
  fin.
Qed.

Lemma cp_Lam (M M': PCF (opt s V) t ):
      M :>> M' -> Lam M :>> Lam M'.
Proof. 
  induction 1;
  simpl; intros;
  try constructor;
  match goal with 
    [H : ?y :>> ?z|- Lam ?x :>> Lam ?z ] =>
      constructor 2 with (Lam y) end;
  fin;
  constructor 4;
  fin.
Qed.

Lemma cp_Rec (M M': PCF V (t ~> t)) :
      M :>> M' -> Rec M :>> Rec M'.
Proof.
  induction 1;
  simpl; intros;
  try constructor;
  match goal with 
    [H : ?y :>> ?z|- Rec ?x :>> Rec ?z ] =>
      constructor 2 with (Rec y) end;
  fin;
  constructor 5;
  fin.
Qed.

End Relations_on_PCF.




(** Beta reduction *)

Reserved Notation "a >> b" (at level 60).

Inductive eval (V : IT): forall t, relation (PCF V t) :=
| app_abs : forall (s t:TY) (M: PCF (opt s V) t) N, 
               eval (Lam M @ N) (M [*:= N])
| condN_t: forall n m, eval (condN ' @ ttt ' @ n @ m) n 
| condN_f: forall n m, eval (condN ' @ fff ' @ n @ m) m 
| condB_t: forall u v, eval (condB ' @ ttt ' @ u @ v) u 
| condB_f: forall u v, eval (condB ' @ fff ' @ u @ v) v
| succ_red: forall n, eval (succ ' @ Nats n ') (Nats (S n) ')
| zero_t: eval ( zero ' @ Nats 0 ') (ttt ')
| zero_f: forall n, eval (zero ' @ Nats (S n)') (fff ')
| pred_Succ: forall n, eval (preds ' @ (succ ' @ Nats n ')) (Nats n ')
| pred_z: eval (preds ' @ Nats 0 ') (Nats 0 ')
| rec_a : forall t g, eval (Rec g) (g @ (Rec (t:=t) g)).



Definition eval_star := propag eval.

Definition eval_rel := 
   fun (V : IT) t => clos_refl_trans_1n _ (@eval_star V t).

Notation "a >> b" := (eval_rel a b) (at level 60, no associativity).

Obligation Tactic := unfold eval_rel; simpl; 
           intros; auto using Clos_RT_1n_prf.

Program Instance PCFEVAL_struct (V : IT) : ipo_obj_struct (PCF V) := {
 IRel t := @eval_rel V t
}.

Definition PCFE (V: IT) : IPO TY :=
    Build_ipo_obj (PCFEVAL_struct V ).

Obligation Tactic := intros; try unf_Proper; 
   simpl; intros;
   match goal with [H : smallest_irel _ _ |- _ ] => destruct H end;
   reflexivity.

Program Instance Var_s (V : IT) : 
    ipo_mor_struct (a:=IDelta _ V) (b:=PCFE V) (Var (V:=V)).

Definition VAR V := Build_ipo_mor (Var_s V).

Lemma eval_eval V (s t:TY) (M: PCF (opt s V) t) N : 
        App (Lam M) N >> M [*:= N].
Proof.
  intros; 
  apply clos_refl_trans_1n_contains;
  apply relorig;
  constructor.
Qed.

Lemma eval_eq V t (y z : PCF V t) : 
      y = z ->  y >> z.
Proof.
  intros; subst;
  reflexivity.
Qed.

Lemma eval_red V t (x y : PCF V t) : eval x y ->  x >> y.
Proof.
  intros;
  apply clos_refl_trans_1n_contains;
  constructor;
  auto.
Qed.  

Lemma subst_eval V t (x y : PCF V t) :
   eval x y -> forall (W : IT) 
   (f : V ---> PCF W), 
     x >>= f >> y >>= f.
Proof.
  induction 1; 
  simpl; intros;
  try (apply eval_red; constructor);
  try match goal with[|- eval_rel _ (?M [*:= ?N] >>= ?f)] => 
     transitivity ((M >>= _shift f) [*:=N >>= f]) end;
  try apply eval_eval;
  unfold substar;
  try (apply eval_eq;
  fin;
  try apply subst_eq;
  fin; opt; simpl;
  unfold inj; simpl; fin).
Qed.

Hint Resolve subst_eval : fin.

Ltac sub_beta := match goal with
     [|- App ?M _ >> App ?M _ ] => apply cp_App2 
   | [|- App _ ?N >> App _ ?N ] => apply cp_App1
   | [|- Rec _ >> Rec _ ] => apply cp_Rec
   | [|- Lam _ >> Lam _ ] => apply cp_Lam end.

Ltac spec := match goal with 
     [H:forall _ _ , _ >> _ |- _] => apply H end.

Lemma subst_eval_star (V : IT) (t : TY) (x y : PCF V t) :
   eval_star x y -> forall (W : IT) 
   (f : V ---> PCF W), x >>= f >> y >>= f.
Proof.
  induction 1;
  simpl; intros;
  fin;
  sub_beta; spec.
Qed.

Hint Resolve subst_eval_star : fin.

Lemma subst_eval_rel V t (x y : PCF V t) :
   x >> y -> forall (W : IT) 
   (f : V ---> PCF W), x >>= f >> y >>= f.
Proof.
  induction 1;
  fin.
  match goal with 
      [H:forall _ _ , ?y >>= _ >> ?z >>= _ |- _ >> ?z >>= ?g] =>
        transitivity (y >>= g) end;
  fin;
  try apply subst_eval_star;
  fin.
Qed.

Hint Resolve subst_eval_rel : fin.

Obligation Tactic := simpl; intros; try unf_Proper; 
     simpl; intros;
     try apply subst_eval_rel; fin.

Program Instance subst_s (V W : IT) (f : IDelta _ V ---> PCFE W) :
   ipo_mor_struct (a:=PCFE V) (b:=PCFE W) (subst f).

Definition SUBST V W f := Build_ipo_mor (subst_s V W f).

End close_notation.