
Require Export CatSem.PROP_untyped.initial.
Require Export CatSem.CAT.SO.

Require Import Coq.Program.Equality.

Set Implicit Arguments.
Unset Strict Implicit.
Unset Automatic Introduction.
Unset Transparent Obligations.


(** note that this file is superseded by ./prop_arities_initial.v, which is the 
	same but without the condition of algebraicity of the domain of 
	an (in)equation
*)


Notation "[[ x ; .. ; y ]]" := (cons x .. (cons y nil) ..).


Notation "[ T ]" := (list T) (at level 5).

(** ** Propositional arities and their representations
	given a signature [Sig], we define 
	- half-equations 
	- algebraic half-equations
	- (in)equations over [Sig] as pairs of half-equations
	- representations of (in)equations as a predicate on representations of [Sig]
*)

(** ** Modules with codomain [wPO] *)

(** given a relative module [M:Set -> PO] over a relative monad [P] over Delta, 
       the data of [M] defines a [P]-module [M : Set -> wPO ] *)

Section wPO_taut_mod.

Variable P : RMonad SM_po.
Variable M : RModule P PO.

Obligation Tactic := unfold Proper, respectful; mauto;
        try apply (rmkl_eq M);
        try rew (rmklmkl M);
        try rew (rmkleta M); mauto.

Program Instance wPO_RMod_struct : RModule_struct P wPO M := {
  rmkleisli a b f := rmkleisli (RModule_struct:= M) f }.

Definition wPO_RMod : RModule P wPO := Build_RModule wPO_RMod_struct.

End wPO_taut_mod.

(*
Section monadic_subst_as_mod_hom.

Variable P : RMonad SM_po.

(*
Print RModule_Hom.

Definition bla:
(forall c : TYPE,
  (product (C:= RMOD P wPO) (wPO_RMod ((DER_RMOD_not PO P) P)) (wPO_RMod P)) c --->
  (wPO_RMod P) c).
simpl.
intro c.
apply (fun y => Rsubstar_not (snd y) (fst y)).
Defined.

(*
apply substar_not.
intro c.
apply (substar 
*)
Print bla.
*)

Ltac elim_option := match goal with [H : option _ |- _ ] => 
                     destruct H end.

Ltac t := mauto ; repeat (unfold Rsubstar_not ||
         match goal with [H: prod _ _ |-_] => destruct H end ||
         rew (rklkl P) || app (rkl_eq P) || elim_option ||  
         rew (rkleta P) || rew (retakl P ) || 
         rew (rlift_rkleisli P) || rew (rkleisli_rlift P) || 
         unfold rlift || rew (rkleta_eq (FM:=P)) || mauto ).

(*
Obligation Tactic := t.
Check Der_RMod_not.
Program Instance Rsubstar_mod_hom_struct : RModule_Hom_struct
   (M := product (C:=RMOD P wPO) ((DER_RMOD_not _ _ (wPO_RMod P))) (wPO_RMod P)) 
   (N := wPO_RMod P) 
   (fun c y => Rsubstar_not (snd y) (fst y)).
Definition Rsubstar_mod_hom := Build_RModule_Hom Rsubstar_mod_hom_struct.
*)

End monadic_subst_as_mod_hom.
*)

(** ** S-Modules and Equations
   given signature [Sig], we define equations and the predicate [verifies_prop_sig]
     on representations of [Sig]
*)

Section S_Mods_and_Eqs.

Variable Sig : Signature.

(** an S_Module over [Sig] should be a functor from representations of [Sig]
      to the category whose objects are pairs of a monad P and a module over P.
   we don't need the functor properties, and use dependent types instead of the cumbersome 
   category of pairs
*)

Class S_Module_s (s_mod_rep : forall R : REP Sig, RMOD R wPO) := {
   S_Mod_Hom : forall (R S : REP Sig) (f : R ---> S), 
      s_mod_rep R ---> PbRMod f (s_mod_rep S)  }.

Record S_Module := {
  s_mod_rep :> forall R : REP Sig, RMOD R wPO ;
  s_mod_hom :> S_Module_s s_mod_rep }.

(** a half-equation is a natural transformation of between S-Modules. 
    we need the naturality condition in the following *)

Class half_equation_struct (U V : S_Module) 
    (half_eq : forall R : REP Sig, s_mod_rep U R ---> s_mod_rep V R) := {
  comm_eq_s : forall (R S : REP Sig)  (f : R ---> S), 
     S_Mod_Hom (S_Module_s := U) f ;; PbRMod_Hom _ (half_eq S) == 
                half_eq R ;; S_Mod_Hom (S_Module_s := V) f }.


Record half_equation (U V : S_Module) := {
  half_eq :> forall R : REP Sig, 
         s_mod_rep U R ---> s_mod_rep V R ;
  half_eq_s :> half_equation_struct half_eq }.

Section S_Module_algebraic.



(** ** Algebraic S-Modules and Equations 

we are interested in algebraic S-Modules, i.e. of the form PROD_i P^{n(i)} *)

Variable l : [nat].

Section ob.

Variable P : RMonad SM_po.
Variable M : RModule P PO.

Obligation Tactic := mauto; repeat (t || unfold Proper, respectful || 
                             app pm_mkl_eq || rew pm_mkl_mkl || app pm_mkl_weta).

Program Instance S_Mod_alg_ob_s : RModule_struct P wPO (fun V => prod_mod_po M V l) := {
  rmkleisli a b f := pm_mkl f }.

Definition S_Mod_alg_ob : RMOD P wPO := Build_RModule S_Mod_alg_ob_s.

End ob.

Section mor.

Variables P Q : RMonad SM_po.
Variable f : RMonad_Hom P Q.

Obligation Tactic := repeat (mauto || rew prod_mod_c_kl || app pm_mkl_eq).

Program Instance S_Mod_alg_mor_s : RModule_Hom_struct 
       (M := S_Mod_alg_ob P) (N := PbRMod f (S_Mod_alg_ob Q)) 
       (@Prod_mor_c _ _ f (l)).

Definition S_Mod_alg_mor := Build_RModule_Hom S_Mod_alg_mor_s.

End mor.

Instance S_Mod_alg_s : S_Module_s (fun R => S_Mod_alg_ob R) := {
  S_Mod_Hom R S f := S_Mod_alg_mor f }.

Definition S_Mod_alg := Build_S_Module S_Mod_alg_s.

End S_Module_algebraic.

(** ** Example : substitution *)

Section substitution.

(** substitiution is an example of half-equation *)

(** the carrier is - for the moment - defined by tactics. Buh! 
     we don't care, since it's just an example *)

Definition blubb (P : REP Sig) :
(forall c : TYPE, (S_Mod_alg_ob [[1; 0]] P) c ---> (S_Mod_alg_ob [[0]] P) c) .
simpl.
intros.
simpl in *.
inversion X.
simpl in *.
inversion X1.
simpl in X2.
constructor.
simpl.
apply (Rsubstar_not X2 X0).
apply TTT.
Defined.


Program Instance sub_struct (P : Representation Sig) : RModule_Hom_struct 
  (M:=S_Mod_alg_ob [[1;0]] P) (N:=S_Mod_alg_ob [[0]] P) (blubb (P:=P)).
Next Obligation.
Proof.
  dependent destruction x.
  dependent destruction x.
  simpl in *.
  apply CONSTR_eq; auto.
  unfold Rsubstar_not.
  rew (rklkl P).
  rew (rklkl P).
  apply (rkl_eq P).
  simpl.
  mauto. 
  destruct x0; simpl.
  unfold rlift.
  simpl.
  rew (retakl P).
  rew (rklkl P).
  rew (rkleta_eq (FM:=P)).
  intros.
  rew (retakl P).
  rew (retakl P).
Qed.

Print Assumptions sub_struct.

Definition sub (P : REP Sig) := Build_RModule_Hom (sub_struct P).


Program Instance subst_half_s : half_equation_struct 
      (U:=Build_S_Module (S_Mod_alg [[1 ; 0]])) (V:=S_Mod_alg [[0]]) sub.
Next Obligation.
Proof.
  
  dependent destruction x.
  dependent destruction x.
  dependent destruction x.
  
  simpl.
  apply CONSTR_eq; auto.
  unfold Rsubstar_not.
  
  rew (rmon_hom_rkl f).
  app (rkl_eq S).
  intros. 
  match goal with [H:option _ |- _]=>destruct H end;
  simpl.
  rew (rmon_hom_rweta f).
  auto.
Qed.

Definition subst_half := Build_half_equation subst_half_s.

End substitution.


(** ** Algebraic stuff cont. 

an algebraic half-equation is a half-equation with algebraic codomain *)
(** to simplify, we also suppose the domain to be algebraic, but in fact we 
   don't care *)

(** note that a proof without this condition (algebraicity of the domain)
   is in ./prop_arities_initial.v

sorry, this is work in progress....
*)


Definition half_eq_alg (doml codl : [nat]) := 
      half_equation (S_Mod_alg doml) (S_Mod_alg codl).

(** an algebraic (in)equation is given by 
       - an algebraic domain (condition can be deleted)
       - an algebraic codomain 
       - two half-equations eq1 and eq2 *)

Record eq_alg := {
  doml : [nat] ;
  codl : [nat] ;
  eq1 : half_eq_alg doml codl ;
  eq2 : half_eq_alg doml codl }.



(*
Definition verifies_eq l l' (e : eq_alg l l') (P : REP Sig) : Prop.
intros.
destruct e.
simpl in *.
destruct eq3.
destruct eq4.
Check S_Mod_alg. Print S_Module.
apply (forall c : TYPE,
         forall x : s_mod_rep (S_Mod_alg l) P c, half_eq0 P _ x << half_eq1 _ _ x).
Defined.
Print verifies_eq.
*)

(** ** Representation of (a set of) (in)equations 

a representation [P] verifies an equation [e] iff for any element in the domain,
    its two images under e1 and e2 are related
*)

Definition verifies_eq (e : eq_alg) (P : REP Sig) :=
  forall c (x : (s_mod_rep (S_Mod_alg (doml e)) P) c), 
       half_eq (eq1 e) P _ x << half_eq (eq2 e)_ _ x.

(** a set of (in)equations, indexed by a set A *)

Definition Prop_Sig_struct (A : Type) := forall a : A, eq_alg.

(** [R] verifies [T] iff it verifies any equation of [T] *)

Definition verifies_prop_sig A (T : Prop_Sig_struct A) (R : REP Sig) :=
      forall a, verifies_eq (T a) R.

(** ** Subcategory of Rep(Sig) of representations verifying equations *)

Section subcat.

(** given any set of (in)equations [T], we consider the following subcategory of 
    the category of representations:
     - objects : representations which verify [T]
     - morphisms : morphisms which verify [True], hence any 
*)

Variable A : Type.
Variable T : Prop_Sig_struct A.

(** lemma stating that the properties are closed under composition and 
    identity *)

Program Instance Prop_Rep : SubCat_compat (REP Sig)
     (fun P => verifies_prop_sig T P) (fun a b f => True).

(** hence we obtain a category, the category of representations of [(Sig, T)] *)

Definition PROP_REP : Cat := SubCat Prop_Rep.


(** ** Initiality in the subcategory 
We proceed with the construction of its initial object *)

(** first thing to do is to build the correct order on the set of terms:
     - two terms [x] and [y] are related if their images under any 
        initial morphism towards a rep of [(Sig, T)] is
     - this initial morphism is actually in the category of representations of 
     [Sig], hence we must inject [R] into the big category
*)

Definition prop_rel_c X (x y : UTS Sig X) : Prop :=
      forall R : PROP_REP, init (SC_inj_ob R) x << init (SC_inj_ob R) y.

(** this ordering is a preorder *)

Program Instance prop_rel_po X : PreOrder (@prop_rel_c X).
Next Obligation.
Proof.
  unfold Reflexive.
  unfold prop_rel_c.
  reflexivity.
Qed.
Next Obligation.
Proof.
  unfold Transitive.
  unfold prop_rel_c.
  simpl; intros.
  transitivity (
   init (SC_inj_ob
     (subobP:=fun P : Representation Sig => verifies_prop_sig (A:=A) T P) R)
  y); auto.
Qed.

Definition prop_rel_po_s X := Build_PO_obj_struct (prop_rel_po X).

Definition prop_rel X := Build_PO_obj (prop_rel_po_s X).

(** ** Substitution compatible with new order
substitution as defined previously is compatible with this order *)

Program Instance subst_prop_rel_s X Y (f : X ---> UTS Sig Y) : 
   PO_mor_struct (a := prop_rel X) (b := prop_rel Y) 
     (subst f).
Next Obligation.
Proof.
  unfold Proper, respectful.
  unfold prop_rel_c.
  simpl. intros.
  assert (H':= init_kleisli (SC_inj_ob R)).
  simpl in H'.
  assert (H2 := H' X x _ (Sm_ind f)).
  simpl in H2.
  rewrite H2.
  clear H2.
  assert (H3 := H' X y _ (Sm_ind f)).
  rew H3.
  clear H3.
  apply PO_mor_monotone.
  auto.
Qed.

Definition subst_prop_rel X Y f := Build_PO_mor (subst_prop_rel_s X Y f).

(** now this gives a new relative monad
     - the set of terms is the same as [UTS_sm]
     - the order on any set of terms is different
*)

Obligation Tactic := cat; 
      repeat (unfold Proper, respectful || 
       rewrite subst_var || app subst_eq ||
       rewrite subst_subst || cat).
      
(** ** Monad with previously defined terms but new order *)

Program Instance UTS_prop_rel_rmonad_s : RMonad_struct SM_po prop_rel := {
  rweta c := Sm_ind (@Var Sig c);
  rkleisli := subst_prop_rel
}.

Definition UTSP := Build_RMonad (UTS_prop_rel_rmonad_s).

(** ** Important Lemma
This lemma corresponds to one direction of Lemma 36 *)
(** it says : the relation defined by the set of equations
       behaves well when doing products and derivations.
 this is why we restrict ourselves to algebraic codomains
*)

Lemma lemma36 (l : [nat]) (V : Type)
    (x y : prod_mod_c (fun x : Type => UTS Sig x) V l)
    (H : prod_mod_c_rel (M:=prop_rel) x y) 
    (R : subob (fun P : Representation Sig => verifies_prop_sig (A:=A) T P)):
Rel (PO_obj_struct := prod_mod_po (SC_inj_ob R) V l) 
  (Prod_mor_c (init_mon (Sig:=Sig) (SC_inj_ob R)) x)
  (Prod_mor_c (init_mon (Sig:=Sig) (SC_inj_ob R)) y).
Proof.
  simpl.
  induction l; simpl;
  intros.
  dependent destruction x.
  dependent destruction y.
  constructor.
  dependent destruction x.
  simpl.
  dependent destruction y.
  simpl.
  constructor.
  simpl.
  Focus 2.
  apply IHl.
  dependent destruction H.
  auto.
  dependent destruction H.
  unfold prop_rel in H. simpl in H.
  unfold prop_rel_c in H.
  apply (H R).
Qed.


(** ** Representation in the new monad 
we now pass to representations of [Sig] in our new shiny monad. the carrier is 
    the same as for the diagonal monad. we have to prove that it is compatible with
    the new order on terms *)

Program Instance Build_prop_pos (i : sig_index Sig) V : PO_mor_struct
  (a := prod_mod UTSP (sig i) V) (b := UTSP V)
  (fun X => Build (i:=i) (UTSl_f_pm (V:=V) X)).
Next Obligation.
Proof.
  unfold Proper; red.
  intros; simpl.
  unfold prop_rel_c.
  simpl.
  intros.
  assert (H2:= repr_hom_s (Representation_Hom_struct := init_representic (SC_inj_ob R))).
  simpl in H2.
  unfold commute in H2.
  simpl in H2.
  rewrite <- H2.
  rewrite <- H2.
  apply PO_mor_monotone.
  apply lemma36.
  auto.
Qed.

Definition Build_prop_po i V := Build_PO_mor (Build_prop_pos i V).

(** these lemmas are the same as for the other monad *)
(** perhaps we could reuse some code here, but that is not urgent *)

Lemma _lshift_lshift_eq2 (b : nat)
  (X : TYPE) (W : Type) (f : PO_mor (sm_po X) (prop_rel W))
   (x : X ** b):
 lshift_c (P:=UTSP) (l:=b) (V:=X) (W:=W) f x =
    _lshift (Sig:=Sig) (l:=b) (V:=X) (W:=W) f x .
Proof.
  induction b;
  simpl; intros.
  auto. 
  rewrite IHb.
  apply _lshift_eq.
  simpl.
  intros.
  destruct x0; simpl;
  auto.
  unfold inj.
  rewrite subst_eq_rename.
  auto.
Qed.

Lemma sts_list_subst2 l X (v : prod_mod (UTSP) l X) 
       W (f : SM_po X ---> UTSP W):
  UTSl_f_pm  (pm_mkl f v ) = list_subst (UTSl_f_pm v) f.
Proof.
  induction v; simpl;
  intros. auto.
  apply constr_eq.
  apply subst_eq.
  intros.
  rewrite _lshift_lshift_eq2.
  auto.
  auto.
Qed.

Hint Resolve sts_list_subst : fin.
Hint Rewrite sts_list_subst : fin.

(** we need module morphisms for the representation *)

Program Instance Build_prop_s i : RModule_Hom_struct (Build_prop_po i).
Next Obligation.
Proof.
  rewrite sts_list_subst2.
  auto.
Qed.

(** [Build_prop i] represents the arity [i] *)

Definition Build_prop i := Build_RModule_Hom (Build_prop_s i).


(**  UTSP has a structure as a representation of Sig *)

Canonical Structure UTSPROPrepr : Repr Sig UTSP := Build_prop.

Canonical Structure UTSPROPRepr : REP Sig := 
       Build_Representation (@UTSPROPrepr).

(** other direction of Lemma 36
    - also here some code savings possible *)

Lemma lemma36_2 (l : [nat]) (V : Type)
    (x y : prod_mod_c (fun x : Type => UTS Sig x) V l)
    (H : forall R : subob (fun P : Representation Sig => verifies_prop_sig (A:=A) T P),
        Rel (PO_obj_struct := prod_mod_po (SC_inj_ob R) V l) 
  (Prod_mor_c (init_mon (Sig:=Sig) (SC_inj_ob R)) x)
  (Prod_mor_c (init_mon (Sig:=Sig) (SC_inj_ob R)) y) ) :
prod_mod_c_rel (M:=prop_rel) x y.
Proof.
  simpl.
  induction l; simpl;
  intros.
  constructor.
  dependent destruction x.
  dependent destruction y.
  simpl.
  constructor.
  simpl.
  Focus 2.
  apply IHl.
  intros.
  assert (h:= H R).
  clear H.
  dependent destruction h.
  apply h.
  unfold prop_rel_c.
  intros.
  assert (h:= H R).
  dependent destruction h.
  apply H0.
Qed.

(** ** A morphism of representations 
we produce a morphism of representations from [UTSP_sm] to 
     [UTSPREPR] 
     - this is in fact the identity morphism
     - just the order becomes bigger
*)
(** we use this morphism to show that an equation is the same on 
  [UTSM_sm] (diagonal order) and [UTSP] (order induced by equations)
*)

Program Instance debi1s : 
   RMonad_Hom_struct (P:=UTSM Sig) (Q:=UTSP) 
   (fun c => Sm_ind (id (UTS Sig c))).

Definition debi1 := Build_RMonad_Hom debi1s.

Lemma debi25 l c (x : prod_mod_c (fun x => UTS Sig x) c l) : 
      Prod_mor_c debi1 x = x.
Proof.
  induction x; simpl; intros;
  auto; apply CONSTR_eq; auto.
Qed.

Obligation Tactic := unfold commute; simpl; intros;
     repeat (apply f_equal || apply debi25 || auto).

Program Instance debi2s : 
     Representation_Hom_struct (P:=UTSRepr Sig) (Q:=UTSPROPRepr) debi1.

Definition debi2 := Build_Representation_Hom debi2s.

Existing Instance UTS_initial.

Lemma half_eq_const_on_carrier : forall c x, 
   init_rep UTSPROPRepr c x = x.
Proof.
  simpl;
  assert (H:=InitMorUnique (C:=REP Sig) debi2);
  simpl in H;
  auto.
Qed.

(** this lemma states that half-equations are constant on 
    representations whose underlying sets of terms are the same and the 
     order gets bigger *)
(** when passing from [UTSM_sm] to [UTSP], the equations remain the same *)

Lemma debi3s a c x:
forall h : half_eq_alg (doml (T a)) (codl (T a)),
    (h (UTSRepr Sig)) c x = (h UTSPROPRepr) c x.
Proof.
  simpl.
  intros.
  destruct h.
  simpl in *.
  destruct half_eq_s0.
  simpl in *.
  assert (H:= comm_eq_s0 _ _ (debi2) c x).
  rewrite debi25 in H.
  rewrite debi25 in H.
  auto.
Qed.

(** [UTSPROPRepr] verifies (in)equations
the new nice representation [UTSPROPRepr] verifies the equations of [T], contrary
    to the old one, [UTSRepr] *)


Lemma UTSPRepr_sig_prop : verifies_prop_sig T UTSPROPRepr.
Proof.
  unfold verifies_prop_sig, verifies_eq.
  simpl; intros.
  apply lemma36_2.
  intros. 
  assert (H4:=comm_eq_s (half_equation_struct := eq1 (T a))).
  assert (H5:=H4 _ _ (init_rep (SC_inj_ob R))).
  simpl in H5.
  clear H4.
  rerew (debi3s x (eq2 (T a)) ).
  rerew (debi3s x (eq1 (T a))).
  rewrite <- H5.
  clear H5.
  assert (H4:=comm_eq_s (half_equation_struct := eq2 (T a))).
  assert (H5:=H4 _ _ (init_rep (SC_inj_ob R))).
  simpl in H5.
  rewrite <- H5.
  clear H5 H4.
  simpl in *.
  destruct R; simpl in *.
  unfold verifies_prop_sig in v.
  unfold verifies_eq in v.
  simpl in v.
  apply v.
Qed.

(** ** an object of the subcategory 
*)

Definition UTSPROPREPR : PROP_REP := 
 exist (fun a : Representation Sig => verifies_prop_sig (A:=A) T a) UTSPROPRepr
  UTSPRepr_sig_prop.

(** ** Initiality in the subcategory *)

Section init.

Variable R : PROP_REP.

(** the initial morphism is the same as before
      - we need to show that it is monotone, which is by definition
      - that it is a morphism of monads
      - morphism of representations
      - unicity
*)


Program Instance init_prop_s V : PO_mor_struct
    (a:=(FINJ _ UTSPROPREPR) V) (b:=(FINJ _ R) V) (init (FINJ _ R) (V:=V)).
Next Obligation.
Proof.
  unfold Proper, respectful;
  intros; app_any.
Qed.

Definition init_prop_po V := Build_PO_mor (init_prop_s V).

Obligation Tactic := cat; rewrite init_kleisli2; 
           app (rkl_eq (proj1_sig R)).

(** monadicity *)

Program Instance init_prop_mon_s : RMonad_Hom_struct
      (P:=FINJ _ UTSPROPREPR)(Q:=FINJ _ R) init_prop_po.

Definition init_prop_mon := Build_RMonad_Hom init_prop_mon_s.

(** representativity asks for a lemma, same as for case without equations *)

Lemma prod_mor_eq_init_list2 (i : sig_index Sig) V
       (x : prod_mod_c (fun V => UTS Sig V) V (sig i)) :
  Prod_mor_c init_prop_mon x = init_list _ (UTSl_f_pm x).
Proof.
  induction x;
  simpl; auto.
  unfold FINJ in IHx. simpl in *.
  rewrite  IHx.
  simpl. auto.
Qed.

Obligation Tactic := repeat (cat || unfold commute ||
             rewrite prod_mor_eq_init_list2).

Program Instance init_prop_rep : Representation_Hom_struct 
       init_prop_mon.

Definition init_prop_re := Build_Representation_Hom init_prop_rep.

(** ** Weak Initiality in Subcategory 
and we have our morphism (weak initiality) *)

Definition init_prop : UTSPROPREPR ---> R := exist _ init_prop_re I.

Section unique.

(** ** Initiality in subcategory *)

Variable f : UTSPROPREPR ---> R.

Existing Instance REPRESENTATION_struct.

(** the proof uses initiality of init in the case wout equations *)

Lemma init_prop_unique : f == init_prop.
Proof.
  simpl. intros.
  destruct f.
  simpl in *.
  clear t.
  clear f.
  unfold SC_inj_ob in x1.
  simpl in x1.
  destruct R.
  simpl in *.
  clear R.
  assert (H:= InitMorUnique (Initial := UTS_initial Sig) 
                         (debi2 ;; x1)).
  simpl in H.
  auto.
Qed.  


(*
Lemma init_prop_unique : f == init_prop.
Proof.
  simpl. intros.
  destruct f.
  simpl in *.
  clear t.
  clear f.
  unfold SC_inj_ob in x1.
  simpl in x1.
  destruct R.
  simpl in *.
  clear R.
  
  apply (@UTSind Sig
     (fun V v => x1 V v = init x2 v)
     (fun V l v => Prod_mor x1 l V (pm_f_STSl v) = init_list _ v));
  simpl; intros;
  auto.
  rew (rmon_hom_rweta x1).
  rewrite <- (one_way u).
  assert (H':=@repr_hom_s _ _ _ x1 x1).
  unfold commute in H'.
  simpl in H'.
  rewrite <- H'.
  
  rewrite one_way.
  rewrite H. auto.
  rewrite H0. simpl.
  rewrite H.
  auto.
Qed.
*)

End unique.

End init.

(** ** Initiality verified by Coq *)

Program Instance INITIAL_PROP : Initial PROP_REP := {
  Init := UTSPROPREPR ;
  InitMor := init_prop ;
  InitMorUnique := init_prop_unique
}.

End subcat.
End S_Mods_and_Eqs.
