Require Export CatSem.CAT.Misc.
Require Export CatSem.PROP_untyped.representations.

Require Import Coq.Program.Equality.

Set Implicit Arguments.
Unset Strict Implicit.
Unset Transparent Obligations.
Unset Automatic Introduction.

(** in this file we define 
    - STS, the initial monad
    - Var, a constructor of STS
    - rename, the functoriality
    - inj, renaming with (v => Some v)
    - shift, taking the substitution function and changing it in a capture
             avoiding fashion
    - subst, the substitution

    correspondences to the general monad definitions 
        (STS left, Monad right):
    - Var = weta
    - rename f = lift f
    - inj = lift weta
    - shift = opt_inj
    - subst = kleisli

    subst is defined in terms of rename. this is precisely the other way 
       round for monads. 
    after having established monadicity, we must show:
    - rename = lift
    - shift = opt_inj
*)

Section initial_type.

Ltac fin := simpl in *; intros; autorewrite with fin; auto with fin.

Variable Sig : Signature.
Notation "V *" := (option V).
Notation "V ** l" := (pow l V) (at level 10).
Notation "f ^^ l" := (pow_map (l:=l) f) (at level 10).
Notation "^ f" := (lift (M:= option_monad) f) (at level 5).
Notation "[ T ]" := (list T) (at level 5).


(** STS will be the initial monad, STS_list represents the arguments of
     a constructor *)
(** STS_list is actually isomorphic to [prod_mod_carrier STS], but 
    we wouldn't get such a nice induction scheme with a non-mutual
    inductive type
*)


Inductive UTS (V : TYPE) : TYPE :=
  | Var : V -> UTS V
  | Build : forall (i : sig_index Sig),
             UTS_list V (sig i) -> UTS V
with 
UTS_list (V : TYPE) : [nat] -> Type :=
  | TT : UTS_list V nil
  | constr : forall b bs, 
      UTS (V ** b) -> UTS_list V bs -> UTS_list V (b::bs).

Definition UTS_sm V := SM_po (UTS V).

Scheme STSind := Induction for UTS Sort Prop with
       STSlistind := Induction for UTS_list Sort Prop.

Scheme STSrect := Induction for UTS Sort Type with
       STSlistrect := Induction for UTS_list Sort Type.

Lemma constr_eq : forall (V : TYPE) (b : nat) 
            (bs : [nat]) (x y : UTS _ )
              (v w : UTS_list V bs),
     x = y -> v = w -> constr (b:=b) x v = constr y w.
Proof.
  intros; subst; auto.
Qed.

Hint Rewrite constr_eq pow_map_eq pow_eq_id : fin.
Hint Resolve constr_eq f_equal pow_map_eq : fin.

Reserved Notation "x //- f" (at level 42, left associativity).
Reserved Notation "x //-- f" (at level 42, left associativity).


(** renaming is a mutually recursive function *)

Fixpoint rename (V W: TYPE ) (f : V ---> W) (v : UTS V):=
    match v in UTS _ return UTS W with
    | Var v => Var (f v)
    | Build i l => Build (i:=i) (list_rename l f)
    end
with 
  list_rename V t (l : UTS_list V t) W (f : V ---> W) : UTS_list W t :=
     match l in UTS_list _ t return UTS_list W t with
     | TT => TT W 
     | constr b bs elem elems => 
             constr (elem //- ( f ^^ (b)))
                               (elems //-- f)
     end
where "x //- f" := (rename f x) 
and "x //-- f" := (list_rename x f).

Definition rename_sm V W (f : V ---> W) : UTS_sm V ---> UTS_sm W :=
      #SM_po (rename f).

(** functoriality of renaming for STS *)

Hint Extern 1 (_ = _) => apply f_equal.

Ltac elim_option := match goal with [H : option _ |- _] => destruct H end.

Ltac t := repeat (cat || apply constr_eq || rew_all
                      || app_any || fin || elim_option).

Lemma rename_eq : forall (V : TYPE) (v : UTS V) 
         (W : TYPE) (f g : V ---> W),
     (forall x, f x = g x) -> v //- f = v //- g.
Proof.
  app (@STSind 
       (fun (a : Type) (v : UTS a) => 
            forall (b : Type)(f g : a ---> b),
         (f == g) ->
         rename (W:=b) f v = rename (W:=b) g v)
       (fun V l (v : UTS_list V l) => 
            forall (b : TYPE)(f g : V ---> b),
         (f == g) ->
         v //-- f =  v //-- g)); t.
Qed.

Hint Resolve rename_eq constr_eq pow_id pow_comp : fin.
Hint Rewrite rename_eq constr_eq pow_id pow_comp : fin.

Obligation Tactic := unfold Proper ; red; fin.

Program Instance rename_oid V W : 
  Proper (A:=(V ---> W) -> (UTS V ---> UTS W)) 
       (equiv ==> equiv) (@rename V W).

Hint Extern 1 (?f ^^ _ _ ?x = ?x) => apply pow_eq_id.

Lemma rename_eq_id V (x : UTS V) (f : V ---> V) :
     f == id _ -> x //- f = x.
Proof.
  apply (@STSind
       (fun a (x : UTS a) => forall f, f == id _ ->
               x //- f = x)
       (fun a t (l : UTS_list a t) => forall f, f == id _ ->
            l //-- f = l)); t.
Qed.   

Lemma rename_id V (x : UTS V) : x //- id _ = x .
Proof. 
  repeat (t || apply rename_eq_id).
Qed.

Ltac tt := repeat (t || 
      match goal with [|- ?s //- _ = ?s //- _] => 
              apply rename_eq end ||
      elim_option ||
      rew pow_comp).

Lemma rename_comp V (x : UTS V) W (f : V ---> W) X (g : W ---> X):
    x //- f //- g = x //- (fun y => g (f y)).
Proof.
  apply (@STSind 
   (fun a (x : UTS a) => 
     forall b (f : a ---> b) c (g : b ---> c),
      x //- f //- g = x //- (fun y => g (f y)))
   (fun a t (l : UTS_list a t) => 
     forall b (f : a ---> b) c (g : b ---> c),
       l //-- f //-- g  = l //-- (f ;; g))); tt. 
Qed.

Hint Rewrite rename_comp rename_id : fin.
Hint Resolve rename_comp rename_id : fin.

Obligation Tactic := fin.

Program Instance rename_func : Functor_struct (Fobj := @UTS) rename.

(** injection of a term into the type of terms with one more variable *)

Definition inj V := rename (@Some V).

Definition inj_list V := 
    fun t (v : UTS_list V t) => list_rename v (@Some V).

(** the shifting, needed to avoid capture *)
(** we'll call it _ shift in order to avoid clash with generic shift *)

Definition _shift (V W : TYPE ) (f : V ---> UTS W) : 
         V * ---> UTS (W *) :=
   fun v => 
   match v in (option _) return (UTS (W *)) with
   | Some p => inj (f p)
   | None => Var None
   end.

Notation "x >- f" := (_shift f x) (at level 40).

(** same for lshift, being given a list of object language types *)
Fixpoint _lshift (l : nat) (V W : TYPE) (f : V ---> UTS W) : 
        V ** l ---> UTS (W ** l) :=
    match l return V ** l ---> UTS (W**l) with
    | 0 => f
    | S n' => @_lshift n' _ _ (_shift f)
    end.

(*Implicit Arguments shift_l [V W t].*)

Notation "x >>-- f" := (_lshift f x) (at level 40).

(*Notation "f $$ l" := (shift_list l f) (at level 20).*)


(** finally the substitution *)
Reserved Notation "x >== f" (at level  59, left associativity).
Reserved Notation "x >>== f" (at level 59, left associativity).

Fixpoint subst (V W : TYPE) (f : V ---> UTS W) (v : UTS V) : 
  UTS W :=  match v in UTS _ return UTS _ with
    | Var v => f v
    | Build i l => Build (l >>== f)
    end
with
  list_subst V W t (l : UTS_list V t) (f : V ---> UTS W) : UTS_list W t :=
     match l in UTS_list _ t return UTS_list W t with
     | TT => TT W 
     | constr b bs elem elems => 
       constr (elem >== (_lshift f)) (elems >>== f)
     end
where "x >== f" := (subst f x) 
and "x >>== f" := (list_subst x f).

Definition subst_sm (V W : TYPE) (f : SM_po V ---> UTS_sm W) :
    UTS_sm V ---> UTS_sm W := #SM_po (subst f).
  
(** substitution of one variable only *)

Definition substar (V : TYPE) (M : UTS V ) :
           UTS (V *) ---> UTS V :=
 subst (fun (x : V *) => match x with
         | None => M
         | Some v => Var v
         end).

Notation "M [*:= N ]" := (substar N M) (at level 50).


(**  FUSION LAWS *)
(**  a boring section, don't read it *)

Hint Extern 1 (_ = _) => f_equal : fin.

Lemma _shift_eq V W (f g : V ---> UTS W) 
     (H : forall x, f x = g x) (x : V*) : 
          x >- f = x >- g.
Proof. 
  tt.
Qed.

Hint Resolve _shift_eq : fin.
Hint Rewrite _shift_eq : fin.

Obligation Tactic := repeat red; fin.

Program Instance shift_oid V W : 
  Proper (equiv ==> equiv) (@_shift V W).

Lemma _lshift_eq l (V W : TYPE) (f g : V ---> UTS W) 
    (H : forall x, f x = g x) (x : V ** l) : 
       x >>-- f = x >>-- g.
Proof.
  induction l; fin.
Qed.

Hint Resolve _lshift_eq : fin.
Hint Rewrite _lshift_eq : fin.
  
Program Instance _lshift_oid l V W : 
    Proper (equiv ==> equiv) (@_lshift l V W).

Lemma shift_var (V : TYPE) (x : V*) :
       x >- @Var _ = Var x .
Proof.
  tt.
Qed.

Hint Resolve shift_var : fin.
Hint Rewrite shift_var : fin.

Ltac ttinv := repeat (tt || rerew_all; fin).

Lemma shift_l_var l V (x : V ** l) : 
      x >>-- @Var _ = Var x .
Proof.
  induction l;  ttinv.
Qed.

Hint Resolve shift_l_var : fin.

Lemma shift_l_var' l V : _lshift (l:=l) (Var (V:=V)) == Var (V:=_).
Proof. 
  tt.
Qed.
  
Lemma var_lift_shift V W (f : V ---> W) (x : option V) :
     Var (^f x) = x >- (f ;; @Var _ ).
Proof.
  induction x; tt.
Qed.

Hint Resolve var_lift_shift shift_l_var' : fin.
Hint Rewrite var_lift_shift shift_l_var' : fin.

Ltac elim_lshift := match goal with 
     [|-?x >>-- _ = ?x >>-- _ ] => apply _lshift_eq end.

Ltac t4 := repeat (tt || elim_lshift).

Lemma var_lift_shift_l (l : nat) V W (f : V ---> W) x : 
       Var ((f ^^ l) x)  =  x >>-- (f ;; @Var _ ) .
Proof.
  induction l; t4.
Qed.

Lemma shift_lift V W X (f : V ---> W) 
         (g : W ---> UTS X) (x : V*) :
      (^f x) >- g = x >- (f ;; g).
Proof.
  induction x; fin.
Qed.

Hint Resolve shift_lift var_lift_shift_l : fin.
Hint Rewrite shift_lift : fin.

Lemma shift_lift_list l V W X (f : V ---> W) (g : W ---> UTS X) x:
        (f ^^ l x) >>-- g =  x >>-- (f ;; g).
Proof.
  induction l; t4.
Qed. 

Lemma subst_eq V (x : UTS V) W (f g : V ---> UTS W) 
       (H : forall x, f x = g x):  x >== f = x >== g.
Proof.
  app (@STSind 
      (fun V x => forall W (f g : V ---> UTS W)
              (H:f == g), x >== f = x >== g)
      (fun V l (v : UTS_list V l) => 
               forall W (f g : V ---> UTS W)(H:f == g),
           v >>== f = v >>== g) );
  fin.
Qed.

Lemma lsubst_eq V l (x : UTS_list V l) 
      W (f g : V ---> UTS W) 
       (H : forall x, f x = g x):  x >>== f = x >>== g.
Proof.
  app (@STSlistind 
      (fun V x => forall W (f g : V ---> UTS W)
              (H:f == g), x >== f = x >== g)
      (fun V l (v : UTS_list V l) => 
               forall W (f g : V ---> UTS W)(H:f == g),
           v >>== f = v >>== g) );
  fin.
Qed.

Hint Resolve subst_eq shift_l_var 
  var_lift_shift_l _lshift_eq lsubst_eq : fin.
Hint Rewrite subst_eq shift_l_var var_lift_shift_l : fin.

Obligation Tactic := unfold Proper; red; fin.

Program Instance subst_oid V W : 
 Proper (equiv ==> equiv (Setoid:=mor_oid (UTS V) (UTS W))) 
                (@subst V W).


Ltac elim_fun := match goal with 
     [|-?x >>-- _ = ?x >>-- _ ] => apply _lshift_eq 
   | [|- lshift _ ?x = lshift _ ?x ] => app lshift_eq
   | [|-?x >== _ = ?x >== _ ] => apply subst_eq 
   | [|-constr _ _ = constr _ _ ] => apply constr_eq
   | [|-?x //- _ = ?x //- _ ] => apply rename_eq 
   | [|-?x >- _ = ?x >- _ ] => apply _shift_eq 
   | [|-?x >>== _ = ?x >>== _ ] => apply lsubst_eq 
   | [|-CONSTR _ _ = CONSTR _ _ ] => apply CONSTR_eq
   | [|- _ = _ ] => apply f_equal end.

Ltac t5 := repeat (elim_fun || tt || unfold inj, substar).

Lemma subst_var (V : TYPE) : forall (v : UTS V), v >== (@Var V) = v .
Proof.
  apply (@STSind
      (fun V (v : UTS V) =>  v >== (Var (V:=V)) = v)
      (fun V l (v : UTS_list V l) => v >>== (Var (V:=V)) = v)); 
  repeat (t5 ||
      match goal with [|- ?s >== _lshift _ = ?s ]=>
      transitivity (s >== (Var (V:=_))) end ).
Qed.

Lemma subst_eq_rename V (v : UTS V) W (f : V ---> W)  : 
     v //- f  = v >== f ;; Var (V:=W).
Proof.
  apply (@STSind 
    (fun V (v : UTS V) => forall W (f : V ---> W),
       v //- f = v >== (f;;Var (V:=W)))
    (fun V l (v : UTS_list V l) => forall W (f : V ---> W),
         v //-- f = v >>== (f ;; Var (V:=W))) );
  t5.
Qed.

Lemma rename_shift V W X (f : V ---> UTS W) (g : W ---> X) (x : V*) : 
    x >- f //- ^g = x >- (f ;; rename g).
Proof.
  induction x; t5.
Qed.

Hint Rewrite rename_shift shift_lift_list : fin.
Hint Resolve rename_shift shift_lift_list : fin.

Lemma rename_shift_list (l : nat) V (x : V ** l) 
              W X (f : V ---> UTS W)
                    (g : W ---> X) :
      x >>-- f //-  g ^^ l =
      x >>-- (f ;; rename g).
Proof.
  induction l; t5.
Qed.

Hint Resolve rename_shift_list : fin.
Hint Rewrite rename_shift_list : fin.
  
Lemma rename_subst V (v : UTS V) W X (f : V ---> UTS W)
      (g : W ---> X) : 
      (v >== f) //- g  = v >== (f ;; rename g).
Proof.
  apply (@STSind  
    (fun V (v : UTS V) => forall W X (f : V ---> UTS W)
                                         (g : W ---> X),
      (v >== f) //- g = v >== (f ;; rename g))
    (fun V l (v : UTS_list V l) => forall W X 
              (f : V ---> UTS W) (g : W ---> X),
      (v >>== f) //-- g = v >>== (f ;; rename g)));
  t5.
Qed.

Lemma subst_rename V (v : UTS V) W X (f : V ---> W)
      (g : W ---> UTS X) : 
      v //- f >== g = v >== (f ;; g).
Proof.
  apply (@STSind  
    (fun V (v : UTS V) => forall W X (f : V ---> W)
                                         (g : W ---> UTS X),
      v //- f >== g = v >== (f ;; g))
    (fun V l (v : UTS_list V l) => forall W X 
              (f : V ---> W) (g : W ---> UTS X),
      v //-- f >>== g = v >>== (f ;; g)));
  t5.
Qed.

Hint Resolve subst_rename rename_subst : fin.
Hint Rewrite subst_rename rename_subst : fin.
Hint Unfold substar : fin.

Lemma rename_substar V (v : UTS V*) W (f : V ---> W) N:
     v [*:= N] //- f = (v //- ^f) [*:= N //- f ].
Proof.
  t5.
Qed.

Hint Rewrite rename_subst rename_subst : fin.

Lemma subst_shift_shift V (v : V*) W X (f: V ---> UTS W) (g: W ---> UTS X):
    (v >- f) >== (_shift g)  = 
             v >- (f ;; subst g).
Proof.
  induction v; t5.
Qed.

Hint Resolve subst_shift_shift : fin.
Hint Rewrite subst_shift_shift : fin.

Lemma subst_shift_shift_list (l : nat) V (v : V ** l)
         W X (f: V ---> UTS W) (g: W ---> UTS X):
    v >>--f >== (_lshift g) = 
             v >>-- (f ;; subst g).
Proof.
  induction l; t5.
Qed.

Hint Rewrite subst_shift_shift_list : fin.
Hint Resolve subst_shift_shift_list : fin.

Lemma subst_subst V (v : UTS V) W X (f : V ---> UTS W) 
             (g : W ---> UTS X) :
     v >== f >== g = v >== f;; subst g.
Proof.
  apply (@STSind   
    (fun (V : Type) (v : UTS V) => forall (W X : Type)
          (f : V ---> UTS W) (g : W ---> UTS X),
        v >== f >== g = v >== (f;; subst g))
   (fun (V : Type) l (v : UTS_list V l) => 
       forall (W X : Type)
          (f : V ---> UTS W) (g : W ---> UTS X),
        v >>== f >>== g = v >>== (f;; subst g) ));
  t5.
Qed.

Hint Resolve subst_var subst_subst : fin.
Hint Rewrite subst_subst : fin.

Ltac tinv := t5; repeat (rerew_all || elim_fun); t5.

Lemma lift_rename V (s : UTS V) W (f : V ---> W) :
          s >== (f ;; @Var _) = s //- f.
Proof.
  app (@STSind 
    (fun V s => forall W f,
       subst (f ;; Var (V:=W)) s =
               rename  f s)
    (fun V l s => forall W f,
        list_subst s (f ;; Var (V:=W)) =
             list_rename s f));
  tinv.
Qed.

(** END OF FUSION LAWS *)

(** STS is a monad *)

Obligation Tactic := fin.

Program Instance UTS_sm_rmonad : 
     RMonad_struct SM_po UTS_sm := {
  rweta c := #SM_po (@Var c);
  rkleisli := subst_sm
}.
Next Obligation.
Proof.
  unfold Proper; red.
  fin.
Qed.

Canonical Structure UTSM_sm := Build_RMonad UTS_sm_rmonad.

(** as said before, STS_list is actually the same as 
    prod_mod_glue STS_monad. we give a module morphism translation *)

Fixpoint STSl_f_pm l V (x : prod_mod UTSM_sm l V)
         : UTS_list V l :=
    match x in prod_mod_c _ _ l return UTS_list V l with
    | TTT =>  TT V 
    | CONSTR b bs e el => constr e (STSl_f_pm el)
    end.

Fixpoint pm_f_STSl l V (v : UTS_list V l) :
       prod_mod UTSM_sm l V :=
 match v in UTS_list _ l return prod_mod UTSM_sm l V with
 | TT => TTT _ _ 
 | constr b bs elem elems => 
        CONSTR elem (pm_f_STSl elems)
 end.

Lemma one_way l V (v : UTS_list V l) : 
    STSl_f_pm (pm_f_STSl v) = v.
Proof.
  induction v; fin.
Qed.

Lemma or_another l V (v : prod_mod UTSM_sm l V) : 
       pm_f_STSl (STSl_f_pm v) = v.
Proof.
  induction v; fin.
Qed.

(** we now establish some more properties, which will help in the future 
    
    in particular the mentioned equalities:
    - rename = lift
    - _ shift = shift
*)

Lemma list_subst_eq V l (v : UTS_list V l) W 
       (f g : V ---> UTS W) (H : f == g) : 
          v >>== f =  v >>== g.
Proof.
  apply (@STSlistind 
      (fun V x => forall W (f g : V ---> UTS W)
              (H:f == g), x >== f = x >== g)
      (fun V l (v : UTS_list V l) => 
               forall W (f g : V ---> UTS W)(H:f == g),
          v >>== f = v >>== g) );
  fin.
Qed.

(** we establish some equalities *)

Hint Rewrite subst_eq_rename : fin.

(** shift = opt_inj STS *)

Notation "x >>- f" := (shift_not f x) (at level 50).
Notation "x >-- f" := (lshift _ f x) (at level 50).

Existing Instance UTS_sm_rmonad.

Lemma _shift_shift_eq V W (f : SM_po V ---> UTS_sm W) (x : V*) :
        x >>- f = x >- f. 
Proof.
  t5.
Qed.

Hint Resolve _shift_shift_eq : fin.

Lemma _lshift_lshift_eq (l : nat) V (x : V ** l) W (f : SM_po V ---> UTS_sm W):
       x >-- f = x >>-- f. 
Proof.
  induction l; t5.
Qed.

(**   rename = lift *)

Lemma lift_rename2 V (s : UTS_sm V) W (f : V ---> W): 
        rlift UTSM_sm f s = s //- f.
Proof.
  fin.
Qed.

(** STSl_f_pm ;; list_subst = mkleisli ;; STSl_f_pm *)

Hint Resolve _lshift_lshift_eq : fin.

Notation "v >>>= f" := (pm_mkl f v) (at level 67).
          
Lemma sts_list_subst l V (v : prod_mod UTSM_sm l V) 
       W (f : SM_po V ---> UTS_sm W):
  STSl_f_pm  (v >>>= f) = (STSl_f_pm v) >>== f.
Proof.
  induction v; repeat (t5 ||
  rew _lshift_lshift_eq ) .
Qed.

Hint Resolve sts_list_subst : fin.
Hint Rewrite sts_list_subst : fin.

(** we define the Representation Structure, i.e. for every arity
    a module morphism *)

Obligation Tactic := t.


Lemma bbb (l : [nat]) V (x y : prod_mod_c UTS_sm V l) :
              prod_mod_c_rel x y -> smallest_rel x y.
Proof.
intros.
induction H.
dependent induction x.
dependent induction y.
constructor.
inversion IHprod_mod_c_rel.
inversion H.
constructor.
Qed.

Lemma bba (l : [nat]) V (x y : prod_mod_c UTS_sm V l) :
              prod_mod_c_rel x y -> x = y.
Proof.
  intros.
  assert (H' := bbb H).
  inversion H'.
  auto.
Qed.

Lemma bbba (l : [nat]) V (x y : prod_mod_c UTS_sm V l) 
     (f : prod_mod_c UTS_sm V l -> UTSM_sm V):
              prod_mod_c_rel x y -> f x << f y.
Proof.
  simpl; intros.
  rewrite (bba H).
  constructor.
Qed.

Program Instance bla (i : sig_index Sig) V : PO_mor_struct
  (fun X => Build (i:=i) (STSl_f_pm (V:=V) X)).
Next Obligation.
Proof.
  unfold Proper; red.
  intros; simpl.
  rewrite (bba H).
  constructor.
Qed.


Program Instance STS_arity_rep (i : sig_index Sig) : 
  RModule_Hom_struct 
       (M := prod_mod UTSM_sm (sig i))
       (N := UTSM_sm) 
       (fun V => Build_PO_mor (bla i V)).

(**  STS has a structure as a representation of Sig *)

Canonical Structure STSrepr : Repr Sig UTSM_sm :=
       fun i => Build_RModule_Hom (STS_arity_rep i).

Canonical Structure STSRepr : REPRESENTATION Sig := 
       Build_Representation (@STSrepr).

(** now INITIALITY *)

Section initiality.

Variable R : REPRESENTATION Sig.

(** the initial morphism STS -> R *)

Fixpoint init V (v : UTS V) : R V :=
        match v in UTS _ return R V with
        | Var v => rweta (RMonad_struct := R) V v
        | Build i X => repr R i V (init_list X)
        end
with 
 init_list l (V : TYPE) (s : UTS_list V l) : prod_mod R l V :=
    match s in UTS_list _ l return prod_mod R l V with
    | TT => TTT _ _ 
    | constr b bs elem elems => 
         CONSTR (init elem) (init_list elems)
    end.

(** now for init to be a morphism of monads we need to establish
    commutativity with substitution

    the following lead towards this goal 
*)

(** init commutes with lift/rename *)

Ltac tt := t5; unfold rlift, rmlift;
           repeat (t || rew (rlift_rweta R) || app (rkl_eq R) 
                     || rew (rkleta R) || rew (retakl R)
                     || rew lshift_weta_f ).

Lemma init_lift V x W (f : V ---> W) : 
   init (x //- f) = rlift R f (init x).
Proof.
  apply (@STSind 
    (fun V (x : UTS V) => forall W (f : V ---> W),
        init (x //- f) = rlift R f (init x))
    (fun V l (s : UTS_list V l) => forall 
                 W (f : V ---> W),
         (init_list (s //-- f)) =
            rmlift (prod_mod R l) f (init_list s))) ; 
  repeat (tt ||
    match goal with [|- PO_fun (rmodule_hom ?H _) _ = _ ] => 
        rew (rmod_hom_rmkl (H)) end).
Qed.


Definition init_sm V := Sm_ind (@init V).

(** init commutes with shift and lshift *)

Lemma init_shift V W (f : SM_po V ---> UTS_sm W) (x : V*) :
  init (x >>- f) = x >>- (f ;; @init_sm _ ).
Proof.
  induction x; 
  repeat (t5 || rerew init_lift).
Qed.

Hint Rewrite init_shift : fin.

Ltac t6 := repeat (t5 || elim_option || apply lshift_eq || app init_lift).

Lemma init_lshift (l : nat) V W (f : SM_po V ---> UTS_sm W) (x : V ** l) :
     init (x >-- f) = x >-- (f ;; @init_sm _).
Proof.
  induction l; t6. t5. tt. 
  assert (H' := init_lift).
  unfold rlift in H'.
  simpl in H'.
  rewrite <- H'. 
  apply f_equal.
  rew lift_rename.
Qed.

Hint Rewrite init_lshift : fin.
Hint Resolve init_lshift : fin.
(** init is a morphism of monads *)

Lemma init_kleisli V (v : UTS V) W (f : SM_po V ---> UTS_sm W) :
  init (v >== f) =
  rkleisli (f ;; @init_sm _ ) (init v).
Proof.
  apply (@STSind 
     (fun X (v : UTS X) => 
         forall Y (f : SM_po X ---> UTS_sm Y),
      init (v >== f) =
      rkleisli (RMonad_struct := R) 
            (f ;; @init_sm _) (init v))

     (fun X l (s : UTS_list X l) => forall Y (f : SM_po X ---> UTS_sm Y),
           init_list (s >>== f) =
           rmkleisli (RModule_struct := prod_mod  R l)
              (f ;; @init_sm _ ) 
                    (init_list s)));
  repeat (tt ||
            match goal with [ i : sig_index _ |- _] => 
            rew (rmod_hom_rmkl (repr R i)) end).
  transitivity (init (u >== lshift_c  f)).
  apply f_equal.
  apply subst_eq.
  intro.

  simpl in *.
  assert (H3 := _lshift_lshift_eq x f).
  simpl in *. auto.
  assert (H4 := H _ (lshift _ f)).
  simpl in H4.
  rewrite H4.
  apply (rkl_eq R).
  simpl. 
  intros.
  rerew init_lshift.
Qed.

Hint Rewrite init_kleisli : fin.
Hint Resolve init_kleisli : fin.

Obligation Tactic := fin.

Program Instance init_monadic : RMonad_Hom_struct (P:=UTSM_sm) init_sm.
Next Obligation.
Proof.
  rew init_kleisli.
Qed.

Canonical Structure init_mon := Build_RMonad_Hom init_monadic.

(** init is not only a monad morphism, but even a morphism of 
    representations *)

(** prod_ind_mod_mor INIT = init_list (up to STSl_f_pm) *)


Lemma prod_mor_eq_init_list (i : sig_index Sig) V 
       (x : prod_mod_c UTS_sm V (sig i)) :
  Prod_mor_c1 init_mon  x = init_list (STSl_f_pm x).
Proof.
  induction x; fin.
Qed.

Obligation Tactic := 
        unfold commute; fin; try rew prod_mor_eq_init_list.

Program Instance init_representic : Representation_Hom_struct
        (P:=STSRepr) init_mon (*init*).

Definition init_rep := Build_Representation_Hom init_representic.

(** INITIALITY of STSRepr with init *)

Section init.

Variable f : Representation_Hom STSRepr R.

Hint Rewrite one_way : fin.

Ltac ttt := tt;
            (try match goal with [ s : UTS_list _ _ |-_] =>
             rewrite <- (one_way s);
             let H:=fresh in assert (H:=repr_hom f );
             unfold commute in H; simpl in H end);
             repeat (app (mh_weta f) || tinv || tt).

(*

tt; try app (mh_weta f);
         match goal with [x : STS_list _ _ |- _ ] =>
             try rerew (one_way x) end;
         match goal with [t:T|-_] =>
         try let H:=fresh in assert (H:=repr_hom f (t:=t));
          unfold commute in H; simpl in H; rerew H end;
          try elim_fun; t.
*)

Lemma init_unique_prepa V (v : UTS V) : f V v = init v.
Proof.
  apply (@STSind
     (fun V v => f V v = init v)
     (fun V l v => Prod_mor f l V (pm_f_STSl v) = init_list v));
  ttt.
  rew (rmon_hom_rweta f).
  rewrite <- (one_way u).
  let H:=fresh in (assert (H:=@repr_hom_s _ _ _ f f);
                    unfold commute in H; 
                    unfold commute_left, commute_right in H ;
                    simpl in *;
                    rewrite <- H).
  rewrite one_way.
  apply f_equal.
  auto.
Qed.

End init.

Hint Rewrite init_unique_prepa : fin.

Lemma init_unique :forall f : STSRepr ---> R , f == init_rep.
Proof.
  fin.
Qed.

End initiality.

Hint Rewrite init_unique : fin.

Obligation Tactic := fin.

Program Instance STS_initial : Initial (REPRESENTATION Sig) := {
  Init := STSRepr ;
  InitMor R := init_rep R }.

End initial_type.





