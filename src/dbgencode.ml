(* dbgencode.ml -- a simple CIL transformation to (dis)proof-of-concept the idea
 * of generating debug info using inline assembly hacks, without destroying too
 * much optimisation potential.
 *
 * Stephen Kell <stephen.kell@kcl.ac.uk>
 * Copyright 2024--25 King's College London
 *)

open Cil
open Feature

class dsFunVisitor =
  fun fl ->
  object(self)
  inherit Liveness.livenessVisitorClass (* normally we want "after instruction" i.e. "out" *) true as super (* from cil/src/ext *) 

  val comment : string = "#"
  val currentFunc : fundec option ref = ref None

  (* initializer
    begin
    end
  *)

  method mkDebugInstrs (loc : location) liveVarSet : instr list =
      (* CIL's liveness analysis also includes non-local vars, 
       * like 'printf', so filter those out. *)
      let liveLocalList = List.flatten (
        List.map (fun var -> if var.vglob then [] else [var]) (Liveness.VS.elements liveVarSet)
      )
      in
      (* FIXME: what to do for non-scalar vars?
       * Is it their non-scalarness, or their bigger-than-a-wordness that is the problem?
       * Let's try it and see, first of all.
       *
       * For structs, we could enumerate their scalar elements.
       * For arrays, we could do the same (in CIL arrays are never variable-length).
       *
       * In both cases, this might generate a ton of printout.
       * We can be "xargs-like" and split into multiple asm instrs if we like.
       *
       * All this will only work well if our liveness analysis is "field-sensitive" (it isn't).
       * At present, a whole struct or array would be live or not.
       * We could proxy a struct or array by its first scalar non-bitfield element,
       * (or skip it if there is none)
       * while admitting that we are not ensuring the debug-visibility of
       * the whole struct or array. Seems good enough for now.
       *
       * Going further, we could use "m" for structs/arrays bigger than a word,
       * and treat whole structs of size <= a word just like a scalar.
       *)
      (* We can only supply 30 operands at a time to gcc's "asm", so chunk into 30s *)
      let chunkedLiveLocals =
        let filteri = fun l -> List.mapi (fun i -> fun x -> (i, x)) l in
        let take n l = snd (List.split (List.filter (fun (i, x) -> i < n) (filteri l))) in
        let drop n l = snd (List.split (List.filter (fun (i, x) -> i >= n) (filteri l))) in
        let rec revAccumChunks acc l =
            let taken = take 30 l in
            let rest = drop 30 l in
            match rest with
                [] -> taken :: acc
              | _  -> revAccumChunks (taken :: acc) rest
        in
        List.rev (revAccumChunks [] liveLocalList)
      in
      let constraintForVar v =
          if v.vstorage = Register then "r"
          else
          match bitsSizeOf v.vtype with
            8|16|32|64(*|128|256*) -> "m" (* "mr" *) (* the order makes absolutely no difference, but "m" vs "rm" does... *)
          | _ -> "m"
      in
      let asmForChunk l =
      Asm((* attributes *)    [(* Attr("volatile", []) *)],
          (* templates *)     (* string list -- usually just one big template string *)
                              [comment ^ " dbg l" ^ (string_of_int loc.line) ^ ": " ^
                               (let (_, endString) =
                               (List.fold_left (fun (n, builtStr) -> fun var -> (
                                 n+1,
                                 (if n = 0 then "" else (builtStr ^ ", ")) ^ "v(" ^ (string_of_int (bitsSizeOf var.vtype)) ^ ") " ^ var.vname ^ " %" ^ (string_of_int n)
                               )) (0, "") l)
                               in endString)
                              ],
          (* outConstraints *)[],    (* (string option * string * lval) list)          *)
          (* inConstraints *) (* (string option * string * exp) list)           *)
                              List.map (fun v -> (None, constraintForVar v, Lval(Var(v), NoOffset))) l,
          (* clobbers *)      [],    (* string list *)
          (* location *) loc
      )
      in
      List.map asmForChunk chunkedLiveLocals

  method vstmt (s : stmt) : stmt visitAction =
    super#vstmt s; (* always returns DoChildren; in the case of Instr only, may set liv_dat_lst to Some thing *)
    match s.skind with
        Instr(is) -> ChangeDoChildrenPost(s,
            let initialLvs = match Liveness.getLiveSet s.sid with
               None -> []
             | Some vs -> Liveness.instrLiveness is s vs (* out? we want in *) false
            in
            fun replacedS ->
            match replacedS.skind with
                Instr(replacedIs) -> (replacedS.skind <- Instr(
                    match replacedIs with
                        [] -> []
                      | ri::ris ->  (* For any block that has >1 instruction,
                                       we also insert a start-of-stmt debug instruction *)
                                    (self#mkDebugInstrs (get_instrLoc ri) (List.hd initialLvs)) @ replacedIs
                ); replacedS)
        )
      | _ -> DoChildren

  method vinst (i: instr) : instr list visitAction =
      super#vinst i;
      let liveVarSet = match cur_liv_dat with None -> Liveness.VS.empty | Some s -> s
      in
      match i with
          _ -> (
              let ans = ChangeTo (i :: (self#mkDebugInstrs (get_instrLoc i) liveVarSet)) in
              ans
          )

  method vfunc (f : fundec) : fundec visitAction =
     currentFunc := Some(f);
     (* Run the liveness analysis on this function. 
      * What does it do?
      * It seems to create results keyed by statement ID, such that
      * LiveFlow.stmtStartData nil
      * retrieves it. (This is what the print_everything () call of the stock liveness feature does.
      * And the visitor is doing getLiveSet which is also doing this.
      * OK, this seems to work.
      *)
     Cfg.clearCFGinfo f;
     ignore(Cfg.cfgFun f);
     Liveness.computeLiveness f;
     ChangeDoChildrenPost(f, fun x -> currentFunc := None; x)

end

let feature : Feature.t = 
  { fd_name = "dbgencode";
    fd_enabled = false;
    fd_description = "debug info by foul means";
    fd_extraopt = [];
    fd_doit = (function (fl: file) ->
      (* First run the stock liveness analysis on the file. *)
      let v = new dsFunVisitor fl in
      visitCilFileSameGlobals (v :> cilVisitor) fl
    );
    fd_post_check = true;
  }

let () = Feature.register feature
