Require Import Coq.Relations.Relations.

Require Export CatSem.CAT.retype_functor_po.
Require Export CatSem.CAT.rmonad_gen_type_po.

Set Implicit Arguments.
Unset Strict Implicit.

Unset Automatic Introduction.

Notation "^ f" := (lift (M:= opt_monad _) f) (at level 5).

Ltac fin := simpl in *; intros; 
   autorewrite with fin; auto with fin.

Hint Unfold lift : fin.
Hint Extern 1 (_ = _) => f_equal : fin.




Notation "V *" := (opt (T:=unit) _ V) (at level 5).

Definition TT := ITYPE unit.

Lemma l_eq (V W : TT) (f g : forall t, V t -> W t) r: 
   (forall t v, f t v = g t v) ->
       (forall t (v : opt r V t), 
       lift (M:=opt_monad r) f t v = ^g t v).
Proof.
  intros.
  destruct v;
  unfold lift;
  simpl;
  auto. 
  rewrite H.
  auto.
Qed.

(*
Inductive ULC_ (V : Type) : Type := 
  | Var : V -> ULC_ V
  | Abs : ULC_ (option V) -> ULC_ V
  | App : ULC_ V -> ULC_ V -> ULC_ V.

Definition ULC_d (V : TT) : Type :=
      ULC_ (V tt).
Definition ULC (V : TT) : TT := 
       fun _ => ULC_d V.
*)

Inductive ULC (V : TT) : TT :=
  | Var : V tt -> ULC V tt
  | Abs : ULC (opt tt V) tt -> ULC V tt
  | App : ULC V tt -> ULC V tt -> ULC V tt.

Definition VAR V : V ---> ULC V := 
   fun t => match t as t0 return V t0 -> ULC V t0 with
           | tt => @Var V end.


Lemma App_eq V  (M M' N N': ULC V tt) :
  M = M' -> N = N' -> App M N = App M' N'.
Proof.
  intros.
  rewrite H.
  rewrite H0.
  auto.
Qed.

Fixpoint rename V W (f : V ---> W) t (y : ULC V t) : 
          ULC W t :=
  match y in ULC _ tt return ULC W tt with
  | Var v => Var (f _ v)
  | Abs v => Abs (rename ^f v)
  | App s t => App (rename f s) (rename f t)
  end.

Definition inj u V := rename (V:=V) (W:= opt u V) 
                (@some unit u V).

(*
Definition _shift_tac u (V W : TT) (f : V ---> ULC W) : 
         opt u V ---> ULC (opt u W).
simpl.
intros.
destruct X.
apply (inj u). apply f. apply v.
apply VAR. apply none.

Defined.
Print _shift_tac.
*)

Definition _shift (u : unit) (V W : TT) (f : V ---> ULC W) : 
         V*  ---> ULC (W*) :=
   fun t v => 
   match v in (opt _ _ y) return (ULC (W *) y) with
   | some t0 p => inj u (f t0 p)
   | none => VAR (none u W)
   end.

Fixpoint _subst V W (f : V ---> ULC W) t (y : ULC V t) : 
         ULC W t :=
  match y in ULC _ tt return ULC W tt with
  | Var v => f _ v
  | Abs v => Abs (_subst (_shift f) v)
  | App s t => App (_subst f s) (_subst f t)
  end.

(*
Definition subst_map_tac (u : unit) (V : TT) (M : ULC V u) :
    opt u V ---> ULC V.
simpl. intros u V M t y.
destruct y.
apply (VAR v).
apply M.
Defined.
Print subst_map_tac.

Definition subst_map: forall (u : unit) (V : TT), 
    ULC V u -> V * ---> ULC V := 
fun (u : unit) (V : unit -> Type) (M : ULC V u) (t : unit) (X : V * t) =>
match X in (opt _ _ y) return (ULC V y) with
| some t0 v =>
    match t0 as u0 return (V u0 -> ULC V u0) with
    | tt => fun v0 : V tt => Var (V:=V) v0
    end v
| none => M
end.


Definition substar (u : unit) (V : TT) (M : ULC V u) :
           ULC (opt u V) ---> ULC V :=
 _subst (subst_map M).
*)

Definition substar (u : unit) (V : TT) (M : ULC V u) :
           ULC (opt u V) ---> ULC V :=
 _subst (fun t (y : opt u V t) => match y with
         | none => M
         | some _ v => VAR v
         end).


Notation "M [*:= N ]" := (substar N M) (at level 50).

(** Notations for functions *)
Notation "y //- f" := (rename f y)
  (at level 42, left associativity).
Notation "y >- f" := (_shift f y) (at level 40).
Notation "y >>= f" := (_subst f y) 
  (at level 42, left associativity).

Lemma rename_eq : forall (V : TT) (t : unit) (v : ULC V t) 
         (W : TT) (f g : V ---> W),
     (forall t y, f t y = g t y) -> v //- f = v //- g.
Proof.
  intros V t v.
  induction v;
  intros;
  simpl.
  rewrite H;
  auto.
  
  apply f_equal.
  apply IHv.
  simpl in *.
  intros.
  destruct t.
  assert (H':= l_eq (r:=tt) H (t:=tt) y).
  simpl in *.
  rewrite <- H'.
  auto.

  rewrite (IHv1 _ _ _ H).
  rewrite (IHv2 _ _ _ H).
  auto.
Qed.

Hint Resolve rename_eq l_eq : fin.
Hint Rewrite rename_eq l_eq : fin.


Lemma rename_comp V t (y : ULC V t) W 
         (f : V ---> W) Z (g : W ---> Z):
 y //- (fun s y => g s (f s y)) =  y //- f //- g.
Proof.
  intros V t y.
  induction y;
  simpl; 
  intros;
  fin.

  apply f_equal.
  rewrite <- IHy.
  apply rename_eq.
  intros r' y0.
  destruct y0; 
  fin.
Qed.

Lemma rename_id_eq V t (y : ULC V t) (f : V ---> V)
        (H : forall t v, f t v = v) : 
    y //- f = y.
Proof.
  intros V t y.
  induction y;
  simpl; 
  intros;
  fin.
  apply f_equal.
  apply IHy.
  intros r' v;
  destruct v;
  fin. unfold lift. 
  fin.
Qed.

Lemma rename_id V t (y : ULC V t) : y //- id _ = y .
Proof.
  intros V t y.
  apply rename_id_eq.
  fin.
Qed.

Lemma _shift_eq u V W (f g : V ---> ULC W) 
     (H : forall t v, f t v = g t v) t (y : opt u V t) : 
          y >- f = y >- g.
Proof.
  intros u V W f g H t v.
  destruct v;
  fin. 
Qed.

Hint Resolve  rename_id _shift_eq : fin.
Hint Rewrite  rename_id _shift_eq : fin.


Lemma shift_var u (V : TT) t (y : opt u V t) :
       y >- @VAR V = VAR y.
Proof.
  intros u V t y.
  induction y.
  simpl.
  destruct u.
  destruct t.
  fin.
  destruct u.
  fin.
Qed.

Hint Resolve shift_var : fin.
Hint Rewrite shift_var : fin.

 
Lemma var_lift_shift (u : unit) V W 
    (f : V ---> W) t (y : opt u V t) :
     VAR (^f _ y) = y >- (f ;; @VAR _ ).
Proof.
  intros u V W f t y;
  induction y; fin.
  destruct u.
  destruct t; fin.
Qed.

Hint Resolve var_lift_shift : fin.


Lemma shift_lift u V W Z (f : V ---> W) 
         (g : W ---> ULC Z) t (y : opt u V t) :
      (^f _ y) >- g = y >- (f ;; g).
Proof.
  intros u V W Z f g t y.
  induction y; fin.
Qed.

Hint Resolve shift_lift : fin.
Hint Rewrite shift_lift : fin.

Lemma subst_eq V t (y : ULC V t) 
      W (f g : V ---> ULC W) 
       (H : forall t y, f t y = g t y):  
      y >>= f = y >>= g.
Proof.
  intros V t y.
  induction y;
  fin.
Qed.

Hint Resolve subst_eq : fin.
Hint Rewrite subst_eq : fin.

Obligation Tactic := unfold Proper; red; fin.

Program Instance subst_oid V W : 
 Proper (equiv ==> equiv (Setoid:=mor_oid (ULC V) (ULC W))) 
                (@_subst V W).

Lemma subst_var (V : TT) : 
    forall t (v : ULC V t), v >>= (@VAR V) = v .
Proof.
  intros V t y.
  induction y;
  fin.
  apply f_equal.
  rewrite <- IHy at 2.
  apply subst_eq.
  fin.
Qed.
  

Lemma subst_eq_rename V t (v : ULC V t) W 
            (f : V ---> W)  : 
     v //- f  = v >>= (f ;; VAR (V:=W)).
Proof.
  intros V t y.
  induction y;
  fin.
  apply f_equal.
  rewrite IHy.
  apply subst_eq.
  intros tr z;
  destruct z;
  fin.
  destruct t.
  fin.
Qed.

Lemma rename_shift a V W Z (f : V ---> ULC W) 
           (g : W ---> Z) t 
       (y : opt a V t) : 
    (y >- f) //- ^g = y >- (f ;; rename g).
Proof.
  intros a V W Z f g t y.
  induction y;
  fin.  
  unfold inj.
  rewrite <- rename_comp.
  rewrite <- rename_comp.
  fin.
  destruct a;
  fin.
Qed.


Hint Rewrite rename_shift : fin.
Hint Resolve rename_shift : fin.

Hint Unfold inj : fin.

Lemma rename_subst V t (v : ULC V t) W Z (f : V ---> ULC W)
      (g : W ---> Z) : 
      (v >>= f) //- g  = v >>= (f ;; rename g).
Proof.
  intros V t y.
  induction y;
  fin.
  rewrite IHy.
  apply f_equal.
  apply subst_eq.
  intros tr z;
  destruct z;
  simpl; auto.
  unfold inj.
  rewrite <- rename_comp.
  rewrite <- rename_comp.
  apply rename_eq.
  fin.
Qed.

Lemma subst_rename V t (v : ULC V t) W Z (f : V ---> W)
      (g : W ---> ULC Z) : 
      v //- f >>= g = v >>= (f ;; g).
Proof.
  intros V t y.
  induction y;
  fin.
  apply f_equal.
  rewrite IHy.
  apply subst_eq.
  intros tr z;
  destruct z;
  fin.
Qed.


Lemma rename_substar V u t (v : ULC (opt u V) t) W 
       (f : V ---> W) N:
     v [*:= N] //- f = (v //- ^f) [*:= N //- f ].
Proof.
  intros.
  unfold substar.
  rewrite rename_subst.
  rewrite subst_rename.
  apply subst_eq.
  intros t0 z ; 
  destruct z ;  
  fin.
  destruct t0;
  fin.
Qed.

Hint Rewrite subst_rename rename_subst : fin.


Hint Rewrite rename_shift : fin.
Hint Resolve rename_shift : fin.


Lemma subst_shift_shift (u:unit) V (t : unit)
      (v : opt u V t)
         W Z (f: V ---> ULC W) (g: W ---> ULC Z):
    (v >- f) >>= (_shift g)  = 
             v >- (f ;; _subst g).
Proof.
  intros u V t v.
  induction v; 
  simpl; intros; 
  try apply subst_term_inj; auto.
  unfold inj.
  rewrite subst_rename. 
  fin.
  destruct u;
  fin.
Qed.

Hint Resolve subst_shift_shift : fin.
Hint Rewrite subst_shift_shift : fin.


Lemma subst_subst V t (v : ULC V t) W Z 
             (f : V ---> ULC W) 
             (g : W ---> ULC Z) :
     v >>= f >>= g = v >>= (f;; _subst g).
Proof.
  intros V t y.
  induction y; 
  fin.
  apply f_equal.
  rewrite IHy.
  apply subst_eq.
  intros tr z;
  destruct z;
  fin.
  unfold inj. 
  fin.
Qed.


Lemma lift_rename V t (s : ULC V t) W (f : V ---> W) :
          s >>= (fun t z => VAR (f t z)) = s //- f.
Proof.
  intros V t y.
  induction y;
  fin.
  apply f_equal.
  rewrite <- IHy.
  apply subst_eq.
  intros tr z;
  destruct z;
  fin.
  destruct t.
  fin.
Qed.

Lemma rename_rename V W Z (f : V ---> W) 
        (g : W ---> Z) t (v : ULC V t) :
  v //- f //- g = v //- (f ;; g).
Proof.
  intros.
  repeat rewrite <- lift_rename.
  rewrite subst_subst.
  fin.
  destruct t.
  apply subst_eq.
  intros.
  destruct t.
  simpl.
  fin.
Qed.

Lemma subst_var_eta (V:TT) t (v:ULC V t):
        v >>= (fun t z => @VAR V t z) = v.
Proof. 
  induction v; intros; simpl; auto.
  rewrite <- IHv at 2.
  apply f_equal. apply subst_eq.
  intros; apply shift_var.
  rewrite IHv1. rewrite IHv2; auto.
Qed.

Lemma subst_substar (V W : TT) 
       t (M: ULC (opt t V) t) (N:ULC V t) 
      (f:forall t, V t -> ULC W t):
   M [*:=N]  >>= f = (M >>= _shift f) [*:= (N >>= f)].
Proof.
  intros V W t M N f.
  unfold substar. simpl.
  repeat rewrite subst_subst.
  apply subst_eq.
  intros t0 y.
  simpl.
  destruct y. unfold _shift.
  unfold inj. 
  simpl.
  rewrite subst_rename. simpl. 
  destruct t0.
  assert (H:=subst_var_eta (f tt v)).
  unfold VAR in H.
  simpl in *.
  rewrite <- H at 1.
  apply subst_eq.
  intros t0 w. destruct t0.
  auto.
  destruct t.
  simpl.
  auto.
Qed.

Hint Resolve subst_var subst_subst lift_rename : fin.
Hint Rewrite subst_subst lift_rename: fin.


Ltac sim := unfold substar; simpl ;
            unfold inj; simpl.


Section Relations_on_ULC.

Reserved Notation "x :> y" (at level 70).

Variable rel : forall (V:TT) t, relation (ULC V t).

Inductive ULCpropag (V: TT) 
       : forall t, relation (ULC V t) :=
| relorig : forall t (v v': ULC V t), rel v v' ->  v :> v'
| relApp1: forall (M M' N : ULC V tt), 
       M :> M' -> App M N :> App M' N
| relApp2: forall M (N N' : ULC V tt),
      N :> N' -> App M N :> App M N'
| relAbs: forall (M M':ULC (opt tt V) tt),
      M :> M' -> Abs M :> Abs M'

where "y :> z" := (@ULCpropag _ _ y z). 

Notation "y :>> z" := 
  (clos_refl_trans_1n _ (@ULCpropag _ _ ) y z) (at level 50).


Variable V : TT.
Variable s t : unit.

(** these are some trivial lemmata  which will be used later *)

Lemma cp_App1 (M M' N : ULC V tt) :
    M :>> M' -> App M N :>> App M' N.
Proof. 
  intros. generalize N. 
  induction H. constructor.
  intros. constructor 2 with (App y N0); auto.
  constructor 2. auto.
Qed.

Lemma cp_App2 (M N N' : ULC V tt) :
    N :>> N' -> App M N :>> App M N'.
Proof. 
  intros. generalize M. 
  induction H. constructor.
  intros. constructor 2 with (App M0 y); auto.
  constructor 3. auto.
Qed.

Lemma cp_Abs (M M': ULC (opt tt V) tt):
      M :>> M' -> Abs M :>> Abs M'.
Proof. 
  intros. induction H. constructor.
  constructor 2 with (Abs y); auto.
  constructor 4. auto.
Qed.


End Relations_on_ULC.

(** Beta reduction *)

Reserved Notation "a >> b" (at level 70).


Inductive beta (V : TT): forall t, relation (ULC V t) :=
| app_abs : forall (M: ULC (opt tt V) tt) N, 
               beta (App (Abs M) N) (M [*:= N]).

Definition beta_star := ULCpropag beta.

Definition beta_rel := 
   fun (V : TT) t => clos_refl_trans_1n _ (@beta_star V t).

Notation "a >> b" := (beta_rel a b).

(** lemmata *)

Lemma beta_eq : forall V t (M N : ULC V t),
   M = N -> M >> N.
Proof.
  intros.
  destruct H.
  reflexivity.
Qed.

Lemma beta_trans : forall V t (M N K : ULC V t),
 M >> K -> N >> M -> N >> K.
Proof.
  intros.
  transitivity M;
  auto.
Qed.

Lemma beta_beta : forall V M (N : ULC V tt), 
   App (Abs M) N >> M [*:= N].
Proof.
  intros.
  apply clos_refl_trans_1n_contains.
  apply relorig.
  constructor.
Qed.

Lemma app_abs_red V (M : ULC _ tt) (N M' : ULC V tt) :
   M [*:= N ] >> M' -> App (Abs M) N >> M'.
Proof.
  intros.
  apply (beta_trans H).
  apply beta_beta.
Qed.

Lemma App1_app_abs V  (M : ULC (opt tt V) tt) 
       (N : ULC V tt) (L : ULC _ tt) K:
  beta_rel (App (M [*:= N]) L) K -> 
  beta_rel (App (App (Abs M) N) L) K.
Proof.
  intros.
  transitivity (App (M[*:=N]) L).
  apply cp_App1.
  apply clos_refl_trans_1n_contains.
  apply relorig.
  constructor.
  auto.
Qed.

Lemma App2_app_abs V (M : ULC (opt tt V) tt) 
      M' (N : ULC V _) K:
  beta_rel (App M' (M [*:= N])) K -> 
  beta_rel (App M' (App (Abs M) N)) K.
Proof.
  intros.
  transitivity (App M' (M[*:=N])).
  apply cp_App2.
  apply beta_beta.
  auto.
Qed.

Lemma App1_App1_app_abs V  
     (M : ULC (opt tt V) tt)  
     (N : ULC _ tt) 
     (K : ULC V tt) 
     (L : ULC V tt) (R : ULC V tt):
  beta_rel (App (App (M[*:=N]) K) L) R ->
  beta_rel (App (App (App (Abs M) N) K) L) R.
Proof.
  simpl; intros.
  transitivity (App (App (M [*:=N]) K) L).
  apply cp_App1.
  apply cp_App1.
  apply beta_beta.
  auto.
Qed.

Lemma App1_App1_App1_app_abs V 
       (M : ULC (opt tt V) tt) 
       (N : ULC V tt)
       (K : ULC V tt) 
       (L : ULC V tt)  
       (J : ULC V tt) (R : ULC V tt):
  beta_rel (App (App (App (M[*:=N]) K) L) J) R ->
  beta_rel (App (App (App (App (Abs M) N) K) L) J) R.
Proof.
  simpl; intros.
  apply (beta_trans H).
  do 3 apply cp_App1.
  apply beta_beta.
Qed.

Lemma Abs_Abs_App1_App1_Abs_app_abs V 
        (M : ULC (opt tt (opt tt (opt tt (opt tt V)))) tt) 
        (N : ULC _ tt) 
        (K : ULC _ tt)
        (L : ULC _ tt) (R : ULC V tt):
beta_rel (Abs (Abs 
      (App (App (Abs (M[*:=N])) K) L))) R ->
beta_rel (Abs (Abs (App (App (Abs (App (Abs M) N)) K) L))) R.
Proof.
  intros.
  apply (beta_trans H).
  repeat apply cp_Abs.
  repeat apply cp_App1.
  apply cp_Abs.
  apply beta_beta.
Qed. 

Lemma Abs_Abs_App1_App1_app_abs V
         (M : ULC (opt tt (opt tt (opt tt V))) tt) 
         (N : ULC _ tt)
         (K : ULC _ tt)
         (L : ULC _ tt) (R : ULC V tt):
beta_rel (Abs (Abs (App (App (M[*:=N]) K) L))) R ->
beta_rel (Abs (Abs (App (App (App (Abs M) N) K) L))) R.
Proof.
  intros.
  apply (beta_trans H).
  repeat apply cp_Abs.
  repeat apply cp_App1.
  apply beta_beta.
Qed. 

Lemma Abs_Abs_App1_app_abs V
       (M : ULC (opt tt (opt tt (opt tt V))) tt) 
       N (K : ULC _ tt) (R : ULC V tt) : 
beta_rel (Abs (Abs (App (M[*:=N]) K))) R ->
beta_rel (Abs (Abs (App (App (Abs M) N) K))) R.
Proof.
  intros.
  apply (beta_trans H).
  do 2 apply cp_Abs.
  apply cp_App1.
  apply beta_beta.
Qed.

Lemma Abs_Abs_app_abs V
       (M : ULC (opt tt (opt tt (opt tt V))) tt) 
       N (R : ULC V tt) :
beta_rel (Abs (Abs (M[*:=N]))) R -> 
beta_rel (Abs (Abs (App (Abs M) N))) R.
Proof.
  intros.
  apply (beta_trans H).
  do 2 apply cp_Abs.
  apply beta_beta.
Qed.

Lemma App2_App1_app_abs V 
    (M : ULC (opt tt V) tt) N K 
    (L : ULC V tt)  (R:ULC V tt) :
  App K (App (M [*:=N]) L) >> R ->
  App K (App (App (Abs M) N) L) >> R.
Proof.
  intros.
  apply (beta_trans H).
  apply cp_App2.
  apply cp_App1.
  apply beta_beta.
Qed.

Lemma Abs_Abs_App1_Abs_App2_App1_app_abs V
     (M : ULC (opt tt (opt tt (opt tt (opt tt V)))) tt)
     N (K : ULC _ tt) (L : ULC _ tt) (J : ULC _ tt) 
       (R:ULC V tt):
   Abs (Abs (App (Abs (App K 
             (App (M[*:=N]) J))) L)) >> R ->
   Abs (Abs (App (Abs (App K 
     (App (App (Abs M) N) J))) L)) >> R.
Proof.
  intros.
  apply (beta_trans H).
  do 2 apply cp_Abs.
  apply cp_App1.
  apply cp_Abs.
  apply cp_App2.
  apply cp_App1.
  apply beta_beta.
Qed.

Lemma Abs_Abs_App1_Abs_App2_app_abs V 
   (M : ULC (opt tt (opt tt (opt tt (opt tt V)))) tt) 
   N (K : ULC _ tt) (L : ULC _ tt) 
       (R:ULC V tt):
   Abs (Abs (App (Abs (App K 
             (M[*:=N]) )) L)) >> R ->
   Abs (Abs (App (Abs (App K 
      (App (Abs M) N) )) L)) >> R.
Proof.
  intros.
  apply (beta_trans H).
  do 2 apply cp_Abs.
  apply cp_App1.
  apply cp_Abs.
  apply cp_App2.
  apply beta_beta.
Qed.

Lemma Abs_Abs_App2_app_abs V 
      (M : ULC (opt tt (opt tt (opt tt V))) tt) 
      N K (R:ULC V tt) :
  Abs (Abs (App K (M[*:=N]))) >> R ->
  Abs (Abs (App K (App (Abs M) N))) >> R.
Proof.
  intros.
  apply (beta_trans H).
  do 2 apply cp_Abs.
  apply cp_App2.
  apply beta_beta.
Qed.

Lemma App2_Abs_Abs_App2_App1_app_abs V 
     (M : ULC (opt tt (opt tt (opt tt V))) tt) 
     N K L (J : ULC _ tt) (R:ULC V tt) :
   App K (Abs (Abs (App L (App (M[*:=N]) J)))) >> R ->
   App K (Abs (Abs (App L (App (App (Abs M) N) J)))) >> R.
Proof.
  intros.
  apply (beta_trans H).
  apply cp_App2.
  do 2 apply cp_Abs.
  apply cp_App2.
  apply cp_App1.
  apply beta_beta.
Qed.

Lemma Abs_Abs_App1_App1_App1_app_abs V
   (M : ULC (opt tt (opt tt (opt tt V))) tt) 
   N (K : ULC _ tt) (L : ULC _ tt) (J : ULC _ tt) (R:ULC V tt) :
  Abs (Abs (App (App (App (M [*:=N]) K) L) J)) >> R ->
  Abs (Abs (App (App (App (App (Abs M) N) K) L) J)) >> R .
Proof.
  intros.
  apply (beta_trans H).
  do 2 apply cp_Abs.
  do 3 apply cp_App1.
  apply beta_beta.
Qed.

Lemma Abs_Abs_App2_App1_App1_app_abs V 
    (M : ULC (opt tt (opt tt (opt tt V))) tt)  
    (N : ULC _ _) (K : ULC _ tt) 
    (L : ULC _ tt) (J : ULC _ tt) (R:ULC V tt):
   Abs (Abs (App K (App (App (M[*:=N]) L) J))) >> R -> 
   Abs (Abs (App K (App (App (App (Abs M) N) L) J))) >> R.
Proof.
  intros.
  apply (beta_trans H).
  do 2 apply cp_Abs.
  apply cp_App2.
  do 2 apply cp_App1.
  apply beta_beta.
Qed.

Lemma Abs_Abs_App2_App1_app_abs V
    (M : ULC (opt tt (opt tt (opt tt V))) tt) 
    N (K : ULC _ tt) (L : ULC _ tt) (R:ULC V tt):
  Abs (Abs (App K (App (M[*:=N]) L))) >> R ->
  Abs (Abs (App K (App (App (Abs M) N) L))) >> R.
Proof.
  intros.
  apply (beta_trans H).
  do 2 apply cp_Abs.
  apply cp_App2.
  apply cp_App1.
  apply beta_beta.
Qed.

Lemma Abs_App2_app_abs V 
     (M : ULC (opt tt (opt tt V)) tt) 
     N K (R : ULC V tt) :
   Abs (App K (M[*:=N])) >> R -> 
   Abs (App K (App (Abs M) N)) >> R.
Proof.
  intros.
  apply (beta_trans H).
  apply cp_Abs.
  apply cp_App2.
  apply beta_beta.
Qed.

Lemma App1_Abs_app_abs V 
   (M : ULC (opt tt (opt tt V)) tt) 
   N (K : ULC _ tt) (R:ULC V tt) :
  App (Abs (M[*:=N])) K >> R ->
  App (Abs (App (Abs M) N)) K >> R.
Proof.
  intros.
  apply (beta_trans H).
  apply cp_App1.
  apply cp_Abs.
  apply beta_beta.
Qed.

Lemma App1_Abs_App2_App1_app_abs V 
   (M : ULC (opt tt (opt tt V)) tt) 
   N (K : ULC _ tt) (L : ULC _ tt) 
   (J : ULC _ tt) (R:ULC V tt) :
  App (Abs (App K (App (M[*:=N]) L))) J >> R -> 
  App (Abs (App K (App (App (Abs M) N) L))) J >> R.
Proof.
  intros.
  apply (beta_trans H).
  apply cp_App1.
  apply cp_Abs.
  apply cp_App2.
  apply cp_App1.
  apply beta_beta.
Qed.


Lemma App1_Abs_Abs_App2_App1_app_abs V 
   (M : ULC (opt tt (opt tt (opt tt V))) tt) 
    N (K : ULC _ tt) (L:ULC _ tt) (J : ULC _ tt) (R:ULC V tt) :
  App (Abs (Abs (App K (App (M[*:=N]) L)))) J >> R -> 
  App (Abs (Abs (App K (App (App (Abs M) N) L)))) J >> R.
Proof.
  intros.
  apply (beta_trans H).
  apply cp_App1.
  do 2 apply cp_Abs.
  apply cp_App2.
  apply cp_App1.
  apply beta_beta.
Qed.

Lemma App1_App1_Abs_app_abs V
   (M : ULC (opt tt (opt tt V)) tt)  
    N (K : ULC _ tt) (L : ULC _ tt) (R:ULC V tt) :
  App (App (Abs (M[*:=N])) K) L >> R -> 
  App (App (Abs (App (Abs M)N)) K) L >> R.
Proof.
  intros.
  apply (beta_trans H).
  do 2 apply cp_App1.
  apply cp_Abs.
  apply beta_beta.
Qed.

Lemma App1_App1_Abs_Abs_app_abs V
    (M : ULC (opt tt (opt tt (opt tt V))) tt) 
     N (K : ULC _ tt) (L : ULC _ tt) (R:ULC V tt) :
  App (App (Abs (Abs (M[*:=N]))) K) L >> R -> 
  App (App (Abs (Abs (App (Abs M)N))) K) L >> R.
Proof.
  intros.
  apply (beta_trans H).
  do 2 apply cp_App1.
  do 2 apply cp_Abs.
  apply beta_beta.
Qed.

Obligation Tactic := idtac.

Program Instance ULCBETA_struct (V : TT) : 
   ipo_obj_struct (ULC V) := {
 IRel t := @beta_rel V t
}.
Next Obligation.
Proof.
  constructor.
  constructor.
  assert (H':= @clos_rt_is_preorder _ (@beta_star V t)).
  unfold beta_rel in *.
  unfold Transitive.
  intros.
  destruct H' as [H1 H2].
  unfold transitive in H2.
  simpl in *.
  apply trans_rt1n.
  apply H2 with y;
    apply rt1n_trans;
    auto.
Qed.



Definition ULCBETA (V: TT) : IPO unit :=
    Build_ipo_obj (ULCBETA_struct V ).

Program Instance Var_s (V : TT) : 
    ipo_mor_struct (a:=SM_ipo _ V) (b:=ULCBETA V) (VAR (V:=V)).
Next Obligation.
Proof.
  intros V t.
  unfold Proper;
  red.
  simpl.
  intros y z H.
  induction H.
  reflexivity.
Qed.

Definition VVAR V := Build_ipo_mor (Var_s V).

Lemma rename_beta (V W : TT)(f : V ---> W) t (v w : ULC V t):
     v >> w -> v //- f >> w //- f.
Proof.
  intros V W f t v w H.
  generalize dependent W.
  induction H.
  reflexivity.
  intros W f.
  transitivity (y //- f);
  auto.
  clear dependent z.
  generalize dependent W.
  induction H.
  induction H.

  simpl.
  intros W f.
  apply app_abs_red.
  simpl.
  unfold substar.
  rewrite  rename_subst.
  simpl.
  rewrite subst_rename.
  simpl.
  apply beta_eq.
  apply (subst_eq M).
  intros s y;
  destruct y as [s y| ];
  simpl; 
  auto.
  destruct s;
  fin.
  
  intros W f. 
  simpl.
  apply cp_App1.
  apply IHULCpropag.
  intros W f.
  simpl.
  apply cp_App2.
  apply IHULCpropag.
  simpl.
  intros W f.
  apply cp_Abs.
  apply IHULCpropag.
Qed.
  
  
  
  

Program Instance subst_s (V W : TT) 
     (f : SM_ipo _ V ---> ULCBETA W) :
   ipo_mor_struct 
     (a:=ULCBETA V) (b:=ULCBETA W) (_subst f).
Next Obligation.
Proof.
  intros V W f t.
  unfold Proper;
  red.
  intros y z H.
  generalize dependent W.
  induction H;
  simpl;
  intros. 
  constructor.
  transitivity (_subst f y);
  try apply IHclos_refl_trans_1n.
  clear dependent z.

    generalize dependent W.
  induction H;
  simpl;
  intros.
  
  Focus 2.
  apply cp_App1.
  apply IHULCpropag.
  Focus 2.
  apply cp_App2.
  apply IHULCpropag.
  Focus 2.
  apply cp_Abs.
  simpl in *.
  apply (IHULCpropag _ (SM_ind 
            (V:=opt _ V) (W:=ULCBETA (opt tt W)) 
      (fun t y => _shift f y))).

  generalize dependent W.
    induction H;
    simpl;
    intros.
    apply clos_refl_trans_1n_contains.
    apply relorig.
    assert (H:=app_abs (_subst (_shift f) M) (_subst f N)).
    rewrite subst_substar.
    auto.
Qed.
 
Lemma subst_beta (V W : TT) (f : V ---> ULC W) t 
    (v w : ULC V t) :
   v >> w -> v >>= f >> w >>= f.
Proof.
  intros.
  assert (H':= subst_s _ _ (SM_ind (W:= ULCBETA W) f)).
  apply H'.
  simpl.
  auto.
Qed.

Definition SUBST V W f := Build_ipo_mor (subst_s V W f).

Obligation Tactic := fin.

Program Instance ULCBETAM_s : RMonad_struct (SM_ipo unit) ULCBETA := {
   rweta := VVAR;
   rkleisli a b f := SUBST f
}.
Next Obligation.
Proof.
  unfold Proper;
  red;
  fin.
Qed.
Next Obligation.
Proof.
  destruct t.
  simpl.
  auto.
Qed.

Definition ULCBETAM : RMonad (SM_ipo unit) := Build_RMonad ULCBETAM_s.

Lemma rename_lift V t (v : ULC V t) W (f : V ---> W) : 
       v //- f = rlift ULCBETAM f _ v.
Proof.
  unfold lift;
  fin.
Qed.
(*
Hint Rewrite lift_rename : fin.
*)

Lemma shift_shift r s V W (f : SM_ipo _ V ---> ULCBETAM W)
                (y : (opt r V) s) :
   sshift_ (P:=ULCBETAM) (W:=W) f y = y >- f .
Proof.
  intros r  s V W f y.
  destruct y as [t y | ];
  simpl;
  unfold inj;
  fin.
Qed.


Hint Resolve shift_shift : fin.
Hint Rewrite shift_shift : fin.




(* the Turing fixpoint operator Theta.
   it has (Theta g) --> g (Theta g)
*)
Definition ULC_theta_h (V : TT) : ULC V tt :=
 Abs(
  Abs(
   App 
    (Var (none tt _ ))
    (App 
      (App
        (Var (some tt (none tt V))) 
        (Var (some tt (none tt V))))
      (Var (none tt _)))
)).

Definition ULC_theta (V : TT) : ULC V tt :=
App (ULC_theta_h V) (ULC_theta_h V).


(* Y = \f. (\x. f (x x)) (\x. f (x x))  *)

Definition ULC_fix (V : TT) : ULC V tt := 
 Abs (
   App 
    (Abs 
      (App 
        (Var (some tt (none tt V)))
        (App 
          (Var (none tt (opt tt V)))
          (Var (none tt (opt tt V))))
     ))
    (Abs 
      (App          
        (Var (some tt (none tt V)))
        (App 
          (Var (none tt (opt tt V)))
          (Var (none tt (opt tt V))))
     ))

).


(* not: [m+1] = 
     \f.\n. ([m] f) (f n)

instead : [m+1] = \fn. f ([m] f n)
*)

(* note : [m] has 2*m redexes in it *)

Fixpoint ULC_Nat (n : nat) (V : TT) := match n with
| 0 => Abs (Abs (Var (none tt (opt tt V))))
| S n' =>
    Abs(
     Abs (
      App 
       (Var (some tt (none tt _ )))
       (App 
         (App
           (ULC_Nat n' _ )
           (Var (some tt (none tt _ ))))
         (Var (none tt _ )))))
end.


(* naturals are constant under renaming *)

Lemma ulc_nats_rename n :
  forall (V W : TT) (f : V ---> W),
     ULC_Nat n W = ULC_Nat n V //- f.
Proof.
  induction n.
  simpl.
  intros.
  unfold lift.
  simpl.
  auto.
  
  simpl.
  intros.
  apply f_equal.
  apply f_equal.
  apply f_equal.
  rewrite <- IHn.
  auto.
Qed.

(* nats are constant under substitution *)

Lemma ulc_nats_subst n :
 forall (V W : TT)
       (f : V ---> ULC W),
     ULC_Nat n W = ULC_Nat n V >>= f.
Proof.
  induction n.
  reflexivity.
  simpl.
  intros.
  rewrite <- (IHn (V * *)).
  reflexivity.
Qed.


(* - pow 0 T = \x.x 
   - pow Sn T = \x. T ((pow n T) x)

   - pow 1 T = \x. T ((pow 0 T) x) = 
             = \x. T (\y.y x) -> \x. T x

   - pow 2 T = \x. T ((pow 1 T) x) =
             -> \x. T ((\x.Tx) x) ->
                \x. T (T x)
*)

Fixpoint pow n V (T : ULC V tt) : ULC V tt :=
  match n return ULC V tt with
  | 0 => Abs (Var (none tt V ))
  | S n' => Abs 
       (App 
        (inj _ T)
        (App 
          (inj tt (pow n' T))
          (Var (none tt _))))
  end.


(* lets build  fun f x => App f (f^n x) *)
(* - ULC_nat_skel 0 f y = y
   - ULC_nat_skel Sn f y = App f (...)
*)

Fixpoint ULC_nat_skel n V  
   (f : ULC (opt tt V) tt)
   (y : ULC (opt tt (opt tt V)) tt) :
      ULC (opt tt (opt tt V)) tt :=
match n with
| 0 => y
| S n' => App (inj tt f) (ULC_nat_skel n' f y)
end.

(*  take the to-be-bound-next free variables as f and y *)

Definition ULC_nat_sk n V :=
 ULC_nat_skel n (Var (none tt V)) (Var (none tt (V*))).


(*  have free variables f, y

   - ULC_Nat_noredex 0 = y
   - ULC_Nat_noredex Sn = f (...)
*)
(*
Fixpoint ULC_Nat_noredex n V t :=
  match n with
  | 0 => Var (V:=opt t (opt t V)) (none t (opt t V))
  | S n' => App _ (Var (some t (none t V)))
                   (ULC_Nat_noredex n' V t)
  end.
*0
(* ULC_nat_sk = ULC_Nat_noredex *)
(* both have two free variables f, y
*)
*)
(*
Lemma ULC_nat_sk_ULC_Nat_noredex n V :
   ULC_nat_sk n V = ULC_Nat_noredex n V tt.
Proof.
  induction n.
  reflexivity.
  simpl; intros.
  rewrite <- IHn.
  reflexivity.
Qed.
*)
(* we bind the free variables f, y 
   in order to define the natural numbers
*)
(*
Definition ULC_Nat_nox n V t : ULC V t :=
  Abs (
   Abs (ULC_Nat_noredex n V t)).
*)
Definition ULC_N n V : ULC V tt :=
  Abs (Abs (ULC_nat_sk n V)).


Lemma ULC_nat_skel_rename_lift n V W 
     (f : V* ---> W*) a b :
  ULC_nat_skel n a b //- (^f) = 
         ULC_nat_skel n (a//-f) (b//-^f).
Proof.
induction n.
  reflexivity.
  intros;
  simpl in *.
  apply App_eq;
  auto.
  unfold inj.
  repeat rewrite rename_rename.
  fin.
Qed.


Lemma ULC_nat_skel_rename_some n V  
       a b :
   ULC_nat_skel n a b //- (some tt (A:=V * *)) = 
     ULC_nat_skel n (inj _ a) (b //- some tt (A:= V * * )).
Proof.
  simpl.
  intros.
  induction n.
  reflexivity.
  simpl.
  apply App_eq.
  auto.
  simpl.
  auto.
Qed.
 

Lemma ULC_N_skel_subst_shift n V W 
   (f : V* ---> ULC W*) a b :
  ULC_nat_skel n a b >>= (_shift f) =
  ULC_nat_skel n (a>>= f) (b>>=(_shift f)).
Proof.
  induction n.
  reflexivity.
  intros;
  simpl in *.
  apply App_eq;
  auto.
  unfold inj;
  simpl.
  rewrite rename_subst.
  rewrite subst_rename.
  fin.
Qed.

(* is less useful than it might seem *)

Lemma ULC_N_skel_substar n V (M : ULC (V* * ) tt) 
                (a : ULC (V* * ) tt) 
                (b:ULC (opt tt (opt tt V) * ) tt) :
  inj tt (ULC_nat_skel n (a) b [*:= M]) =
  ( ULC_nat_skel n a ((inj tt (b[*:= M])))).
Proof.
  induction n.
  reflexivity.
  simpl;
  intros.
  rewrite <- IHn.
  unfold inj;
  simpl.
  apply App_eq;
  auto.
  rewrite subst_rename.
  rewrite rename_subst.
  simpl.
  rewrite rename_lift.
  simpl.
  auto.
  apply subst_eq.
  intros t y.
  destruct t.
  simpl.
  auto.
Qed.


(* renaming with 2 times lifted map doesn't change 
   ULC_nat_sk (which has only 2 free vars)
*)
  
Lemma ULC_N_sk_rename n V W (f : V ---> W)  :
  ULC_nat_sk n V //- ^(^f) = ULC_nat_sk n _ .
Proof.
  induction n.
  reflexivity.
  intros;
  simpl in *.
  apply App_eq.
  auto.
  rewrite IHn.
  auto.
Qed.

(* similar for substitution with 2times shifted map
*)

Lemma ULC_N_sk_subst n V W (f : V ---> ULC W) :
  ULC_nat_sk n V >>= _shift (_shift f) =
    ULC_nat_sk n W .
Proof.
  induction n.
  reflexivity.
  simpl.
  intros.
  rewrite IHn.
  unfold inj.
  simpl.
  reflexivity.
Qed.

(* the naturals defined with skel are constant under 
   substitution
*)

Lemma ULC_N_subst n V W (f : V ---> ULC W) :
  ULC_N n V >>= f = ULC_N n W.
Proof.
  simpl.
  intros.
  rewrite ULC_N_sk_subst.
  auto.
Qed.


(* the following lemma are the same as for skel.
   no surprise, the defs are equal
*)
(*
Lemma ULC_Nat_noredex_rename n V W (f : V ---> W) t :
  ULC_Nat_noredex n V t //- ^(^f) = ULC_Nat_noredex n _ t.
Proof.
  induction n.
  reflexivity.
  intros;
  simpl in *.
  apply App_eq.
  auto.
  rewrite IHn.
  auto.
Qed.

Lemma ULC_Nat_noredex_subst n V W (f : V ---> ULC W) t :
  ULC_Nat_noredex n V t >>= _shift (_shift f) =
    ULC_Nat_noredex n W t.
Proof.
  induction n.
  reflexivity.
  simpl.
  intros.
  apply App_eq; 
  auto.
Qed.

Lemma ULC_Nat_nox_subst n V W (f : V ---> ULC W) t:
  ULC_Nat_nox n V t >>= f = ULC_Nat_nox n W t.
Proof.
  induction n.
  reflexivity.
  simpl in *.
  intros.
  (**)
  unfold _shift in IHn.
  unfold inj in IHn.
  simpl in IHn.
  (**)
  unfold ULC_Nat_nox in *.
  simpl.
  repeat apply f_equal.
  apply ULC_Nat_noredex_subst.
Qed.
*)


(* Nat n reduces to Nat_nox n *)
(* Nat n has 2n redexes *)
(*
Lemma ULC_nat_red_ULC_Nat_alt n V :
  ULC_Nat n V >> ULC_Nat_nox n V tt.
Proof.
  induction n.
  reflexivity.
  intros.
  simpl.
  unfold ULC_Nat_nox in *.
  assert (H:= IHn (opt tt (opt tt V))).
transitivity (
Abs
  (Abs
     (App (Var (V:=(V * ) * ) (t:=tt) 
             (some tt (A:=V * ) (t:=tt) (none tt V)))
        (App
           (App 

(Abs (Abs (ULC_Nat_noredex n (V * ) * tt)))

              (Var (V:=(V * ) * ) (t:=tt)
                 (some tt (A:=V * ) (t:=tt) (none tt V))))
           (Var (V:=(V * ) * ) (t:=tt) (none tt V * )))))
).
  apply cp_Abs.
  apply cp_Abs.
  apply cp_App2.
  apply cp_App1.
  apply cp_App1.
  apply H.
  clear H IHn.
  sim.
  apply cp_Abs.
  apply cp_Abs.
  apply cp_App2.
  apply App1_app_abs.
  sim.
  apply app_abs_red.
  sim.
  rewrite subst_subst.
  simpl.
  
  apply beta_eq.
  generalize dependent V.
  
  induction n.
  reflexivity.
  simpl.
  intro V.
  rewrite IHn.
  auto.
Qed.
 *)


Lemma pow_rename (n: nat) (V W : TT)(f : V ---> W) T :
   pow n T //- f = pow n (T //- f).
Proof.
  induction n.
  reflexivity.
  intros; 
  simpl.
  apply f_equal.
  apply App_eq.
  unfold inj; simpl.
  repeat rewrite rename_rename;
  fin.
  apply App_eq.
  unfold inj; simpl.
  rewrite <- IHn.
  repeat rewrite rename_rename;
  fin.
  fin.
Qed.
  

Lemma pow_subst (n: nat) (V W : TT)(f : V ---> ULC W) T :
   pow n T >>= f = pow n (T >>= f).
Proof.
  induction n.
  reflexivity.
  simpl.
  intros.
  apply f_equal.
  apply App_eq.
  unfold inj.
  rewrite rename_subst.
  rewrite subst_rename.
  fin.
  apply App_eq.
  unfold inj.
  rewrite <- IHn.
  rewrite rename_subst.
  rewrite subst_rename.
  fin.
  auto.
Qed.


Lemma n_red_pow n V T :
  App (ULC_Nat n V) T >> pow n T.
Proof.
  intro n;
  induction n.
  simpl.
  intros V T.
  apply app_abs_red.
  unfold substar;
  simpl.
  reflexivity.
  simpl in IHn.
  unfold pow in IHn.
  intros V T.
  simpl.
  apply app_abs_red.
  unfold substar;
  simpl.
  unfold pow.
  simpl.
  rewrite <- ulc_nats_subst.
  apply cp_Abs.
  apply cp_App2.
  apply cp_App1.
  unfold inj;
  simpl.
  assert (H':= rename_beta (some tt (A:=V))
                (IHn V T)).
  apply (beta_trans H').
  apply beta_eq.
  simpl.
  rewrite <- ulc_nats_rename.
  auto.
Qed.

Definition ULC_Nat_alt n V : ULC V tt :=
  Abs (pow n (Var (none tt V))).


(** plus = \n.\m.\f.\x. n(f) (m(f)x) *)
(*
Definition ULC_plus (V : TT) := 
  Abs (V:=V)
   (
   Abs (V:=opt tt V)
     (
    Abs (V:= opt tt (opt tt V))
         (
          Abs (V:= opt tt (opt tt (opt tt V)))
           (
             App (V:=opt tt (opt tt (opt tt (opt tt V))))
               (App (V:=opt tt (opt tt (opt tt (opt tt V))))
                    (Var (V:=opt tt (opt tt (opt tt (opt tt V))))
                         (some tt (some tt (some tt (none tt V)))))
                    (Var (V:=opt tt (opt tt (opt tt (opt tt V))))
                         (some tt (A:=(opt tt (opt tt (opt tt V))))
                              (none tt (opt tt (opt tt V)) ))) )   
               (App (V:=opt tt (opt tt (opt tt (opt tt V))))
                    (App (V:=opt tt (opt tt (opt tt (opt tt V))))
                         (Var (V:=opt tt (opt tt (opt tt (opt tt V))))
                              (some tt (some tt (none tt (opt tt V) )))) 
                         (Var (V:=opt tt (opt tt (opt tt (opt tt V))))
                              (some tt (A:= opt tt (opt tt (opt tt V)))
                                  (none tt (opt tt (opt tt V))))))
                    (Var (V:=opt tt (opt tt (opt tt (opt tt V))))
                         (none tt (opt tt (opt tt (opt tt V) )) )))
              )
             
             )
       )
 ).
*)
(** SUCC := \nfx.f (n f x) *)
Definition ULCsucc V : ULC V tt := 
  Abs (
   Abs (
    Abs (
      App 
       (Var (some tt (none tt _ )))
       (App 
         (App
           (Var (some tt (some tt (none tt _ ))))
           (Var (some tt (none tt _ )))
         )
         (Var (none tt _ ))
       )))).


(* alternative definition for succ :
    succ := \m.\f.\n. (m f)(f n)
*)
(*
Definition ULCsucc_alt V : ULC V tt :=
  Abs (
   Abs (
    Abs(
     App
      (App 
        (Var (some tt (some tt (none tt V))))
        (Var (some tt (none tt (opt tt V)))))
      (App 
        (Var (some tt (none tt _ )))
        (Var (none tt _ )))
      
))).
*)


(** if then else = \a.\b.\c. a(b)(c) *)

Definition ULC_cond (V : TT) :=
     Abs (V:=V)
        ( Abs (V:=opt tt V)
            ( Abs (V:=opt tt (opt tt V))
               (
                   App (V:= opt tt (opt tt (opt tt V))) 
                      (App (V:= opt tt (opt tt (opt tt V)))
                         (Var (V:= opt tt (opt tt (opt tt V)))
                            (some tt (some tt (none tt V)))) 
                         (Var (some tt (none tt (opt tt V))))
                      )
                      (Var (none tt (opt tt (opt tt V)))
                      )
               )
            )
        ).


Definition ULC_omega (V : TT) :=
    Abs (V:= V)
      ( App  (Var (none tt V)) (Var (none tt V))).

(* TRUE = \xy.x *)
Definition ULC_True V : ULC V tt :=
  Abs (Abs (Var (some tt (none tt V)))).

(* FALSE = \xy.y *)
Definition ULC_False V : ULC V tt := 
  Abs (Abs (Var (none tt (opt tt V)))).


(* zero? = \n.((n)(true)false)true     *)

Definition ULC_zero (V : TT) := 
  Abs (
   App  
     (App 
       (Var (none tt V ))
       (Abs  (ULC_False _)))
     (ULC_True _ )).


(* T f := \gh. h (g f) *)
Definition ULC_T V f : ULC V tt :=
  Abs (
   Abs (
    App 
     (Var (none tt _))
     (App 
       (Var (some tt (none tt V)))
       (inj _ (inj (t:=tt) _ f))))
).

Lemma T_rename (V W : TT) (g : V ---> W) f :
  ULC_T  f //- g = ULC_T (f//-g).
Proof.
  simpl.
  unfold ULC_T.
  intros.
  repeat apply f_equal.
  unfold inj;
  simpl.
  repeat rewrite rename_rename.
  apply rename_eq.
  simpl.
  auto.
Qed.


(*PRED := \nfx.n (\gh.h (g f)) (\u.x) (\u.u)*)

Definition ULC_pred_alt (V : TT) : ULC V tt :=
  Abs (
   Abs (
    Abs (
     App 
       (App 
         (App 
           (Var (some tt (some tt (none tt V))))         
           (ULC_T (Var (some tt (none tt _ ))))
)
         (Abs (Var (some tt (none tt _ )))))
       (Abs (Var (none tt _ )))
))).


Definition ULC_pred (V : TT) : ULC V tt :=
  Abs (
   Abs (
    Abs (
     App 
       (App 
         (App 
           (Var (some tt (some tt (none tt V))))         
           (Abs (
             Abs (
              App 
               (Var (none tt _ ))
               (App 
                 (Var (some tt (none tt _ )))
                 (Var (some tt (some tt (some tt (none tt _ )))))
             )))))
         (Abs (Var (some tt (none tt _ )))))
       (Abs (Var (none tt _ )))
))).

Lemma ULC_pred_alt_correct V : 
  ULC_pred_alt V = ULC_pred V.
Proof.
  reflexivity.
Qed.


