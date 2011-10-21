(* OASIS_START *)
(* DO NOT EDIT (digest: 98a87aba7cea6dabc609dd2d47c15992) *)
module OASISGettext = struct
# 21 "/opt/local/var/macports/build/_Users_bmeurer_Desktop_Projects_MacPorts_ports_devel_caml-oasis/caml-oasis/work/oasis-0.2.0/src/oasis/OASISGettext.ml"
  
  let ns_ str = 
    str
  
  let s_ str = 
    str
  
  let f_ (str : ('a, 'b, 'c, 'd) format4) =
    str
  
  let fn_ fmt1 fmt2 n =
    if n = 1 then
      fmt1^^""
    else
      fmt2^^""
  
  let init = 
    []
  
end

module OASISExpr = struct
# 21 "/opt/local/var/macports/build/_Users_bmeurer_Desktop_Projects_MacPorts_ports_devel_caml-oasis/caml-oasis/work/oasis-0.2.0/src/oasis/OASISExpr.ml"
  
  
  
  open OASISGettext
  
  type test = string 
  
  type flag = string 
  
  type t =
    | EBool of bool
    | ENot of t
    | EAnd of t * t
    | EOr of t * t
    | EFlag of flag
    | ETest of test * string
    
  
  type 'a choices = (t * 'a) list 
  
  let eval var_get t =
    let rec eval' = 
      function
        | EBool b ->
            b
  
        | ENot e -> 
            not (eval' e)
  
        | EAnd (e1, e2) ->
            (eval' e1) && (eval' e2)
  
        | EOr (e1, e2) -> 
            (eval' e1) || (eval' e2)
  
        | EFlag nm ->
            let v =
              var_get nm
            in
              assert(v = "true" || v = "false");
              (v = "true")
  
        | ETest (nm, vl) ->
            let v =
              var_get nm
            in
              (v = vl)
    in
      eval' t
  
  let choose ?printer ?name var_get lst =
    let rec choose_aux = 
      function
        | (cond, vl) :: tl ->
            if eval var_get cond then 
              vl 
            else
              choose_aux tl
        | [] ->
            let str_lst = 
              if lst = [] then
                s_ "<empty>"
              else
                String.concat 
                  (s_ ", ")
                  (List.map
                     (fun (cond, vl) ->
                        match printer with
                          | Some p -> p vl
                          | None -> s_ "<no printer>")
                     lst)
            in
              match name with 
                | Some nm ->
                    failwith
                      (Printf.sprintf 
                         (f_ "No result for the choice list '%s': %s")
                         nm str_lst)
                | None ->
                    failwith
                      (Printf.sprintf
                         (f_ "No result for a choice list: %s")
                         str_lst)
    in
      choose_aux (List.rev lst)
  
end


module BaseEnvLight = struct
# 21 "/opt/local/var/macports/build/_Users_bmeurer_Desktop_Projects_MacPorts_ports_devel_caml-oasis/caml-oasis/work/oasis-0.2.0/src/base/BaseEnvLight.ml"
  
  module MapString = Map.Make(String)
  
  type t = string MapString.t
  
  let default_filename =
    Filename.concat 
      (Sys.getcwd ())
      "setup.data"
  
  let load ?(allow_empty=false) ?(filename=default_filename) () =
    if Sys.file_exists filename then
      begin
        let chn =
          open_in_bin filename
        in
        let st =
          Stream.of_channel chn
        in
        let line =
          ref 1
        in
        let st_line = 
          Stream.from
            (fun _ ->
               try
                 match Stream.next st with 
                   | '\n' -> incr line; Some '\n'
                   | c -> Some c
               with Stream.Failure -> None)
        in
        let lexer = 
          Genlex.make_lexer ["="] st_line
        in
        let rec read_file mp =
          match Stream.npeek 3 lexer with 
            | [Genlex.Ident nm; Genlex.Kwd "="; Genlex.String value] ->
                Stream.junk lexer; 
                Stream.junk lexer; 
                Stream.junk lexer;
                read_file (MapString.add nm value mp)
            | [] ->
                mp
            | _ ->
                failwith
                  (Printf.sprintf
                     "Malformed data file '%s' line %d"
                     filename !line)
        in
        let mp =
          read_file MapString.empty
        in
          close_in chn;
          mp
      end
    else if allow_empty then
      begin
        MapString.empty
      end
    else
      begin
        failwith 
          (Printf.sprintf 
             "Unable to load environment, the file '%s' doesn't exist."
             filename)
      end
  
  let var_get name env =
    let rec var_expand str =
      let buff =
        Buffer.create ((String.length str) * 2)
      in
        Buffer.add_substitute 
          buff
          (fun var -> 
             try 
               var_expand (MapString.find var env)
             with Not_found ->
               failwith 
                 (Printf.sprintf 
                    "No variable %s defined when trying to expand %S."
                    var 
                    str))
          str;
        Buffer.contents buff
    in
      var_expand (MapString.find name env)
  
  let var_choose lst env = 
    OASISExpr.choose
      (fun nm -> var_get nm env)
      lst
end


module MyOCamlbuildFindlib = struct
# 21 "/opt/local/var/macports/build/_Users_bmeurer_Desktop_Projects_MacPorts_ports_devel_caml-oasis/caml-oasis/work/oasis-0.2.0/src/plugins/ocamlbuild/MyOCamlbuildFindlib.ml"
  
  (** OCamlbuild extension, copied from 
    * http://brion.inria.fr/gallium/index.php/Using_ocamlfind_with_ocamlbuild
    * by N. Pouillard and others
    *
    * Updated on 2009/02/28
    *
    * Modified by Sylvain Le Gall 
    *)
  open Ocamlbuild_plugin
  
  (* these functions are not really officially exported *)
  let run_and_read = 
    Ocamlbuild_pack.My_unix.run_and_read
  
  let blank_sep_strings = 
    Ocamlbuild_pack.Lexers.blank_sep_strings
  
  let split s ch =
    let x = 
      ref [] 
    in
    let rec go s =
      let pos = 
        String.index s ch 
      in
        x := (String.before s pos)::!x;
        go (String.after s (pos + 1))
    in
      try
        go s
      with Not_found -> !x
  
  let split_nl s = split s '\n'
  
  let before_space s =
    try
      String.before s (String.index s ' ')
    with Not_found -> s
  
  (* this lists all supported packages *)
  let find_packages () =
    List.map before_space (split_nl & run_and_read "ocamlfind list")
  
  (* this is supposed to list available syntaxes, but I don't know how to do it. *)
  let find_syntaxes () = ["camlp4o"; "camlp4r"]
  
  (* ocamlfind command *)
  let ocamlfind x = S[A"ocamlfind"; x]
  
  let dispatch =
    function
      | Before_options ->
          (* by using Before_options one let command line options have an higher priority *)
          (* on the contrary using After_options will guarantee to have the higher priority *)
          (* override default commands by ocamlfind ones *)
          Options.ocamlc     := ocamlfind & A"ocamlc";
          Options.ocamlopt   := ocamlfind & A"ocamlopt";
          Options.ocamldep   := ocamlfind & A"ocamldep";
          Options.ocamldoc   := ocamlfind & A"ocamldoc";
          Options.ocamlmktop := ocamlfind & A"ocamlmktop"
                                  
      | After_rules ->
          
          (* When one link an OCaml library/binary/package, one should use -linkpkg *)
          flag ["ocaml"; "link"; "program"] & A"-linkpkg";
          
          (* For each ocamlfind package one inject the -package option when
           * compiling, computing dependencies, generating documentation and
           * linking. *)
          List.iter 
            begin fun pkg ->
              flag ["ocaml"; "compile";  "pkg_"^pkg] & S[A"-package"; A pkg];
              flag ["ocaml"; "ocamldep"; "pkg_"^pkg] & S[A"-package"; A pkg];
              flag ["ocaml"; "doc";      "pkg_"^pkg] & S[A"-package"; A pkg];
              flag ["ocaml"; "link";     "pkg_"^pkg] & S[A"-package"; A pkg];
              flag ["ocaml"; "infer_interface"; "pkg_"^pkg] & S[A"-package"; A pkg];
            end 
            (find_packages ());
  
          (* Like -package but for extensions syntax. Morover -syntax is useless
           * when linking. *)
          List.iter begin fun syntax ->
          flag ["ocaml"; "compile";  "syntax_"^syntax] & S[A"-syntax"; A syntax];
          flag ["ocaml"; "ocamldep"; "syntax_"^syntax] & S[A"-syntax"; A syntax];
          flag ["ocaml"; "doc";      "syntax_"^syntax] & S[A"-syntax"; A syntax];
          flag ["ocaml"; "infer_interface"; "syntax_"^syntax] & S[A"-syntax"; A syntax];
          end (find_syntaxes ());
  
          (* The default "thread" tag is not compatible with ocamlfind.
           * Indeed, the default rules add the "threads.cma" or "threads.cmxa"
           * options when using this tag. When using the "-linkpkg" option with
           * ocamlfind, this module will then be added twice on the command line.
           *                        
           * To solve this, one approach is to add the "-thread" option when using
           * the "threads" package using the previous plugin.
           *)
          flag ["ocaml"; "pkg_threads"; "compile"] (S[A "-thread"]);
          flag ["ocaml"; "pkg_threads"; "link"] (S[A "-thread"]);
          flag ["ocaml"; "pkg_threads"; "infer_interface"] (S[A "-thread"])
  
      | _ -> 
          ()
  
end

module MyOCamlbuildBase = struct
# 21 "/opt/local/var/macports/build/_Users_bmeurer_Desktop_Projects_MacPorts_ports_devel_caml-oasis/caml-oasis/work/oasis-0.2.0/src/plugins/ocamlbuild/MyOCamlbuildBase.ml"
  
  (** Base functions for writing myocamlbuild.ml
      @author Sylvain Le Gall
    *)
  
  
  
  open Ocamlbuild_plugin
  
  type dir = string 
  type file = string 
  type name = string 
  type tag = string 
  
# 55 "/opt/local/var/macports/build/_Users_bmeurer_Desktop_Projects_MacPorts_ports_devel_caml-oasis/caml-oasis/work/oasis-0.2.0/src/plugins/ocamlbuild/MyOCamlbuildBase.ml"
  
  type t =
      {
        lib_ocaml: (name * dir list) list;
        lib_c:     (name * dir * file list) list; 
        flags:     (tag list * (spec OASISExpr.choices)) list;
      } 
  
  let env_filename =
    Pathname.basename 
      BaseEnvLight.default_filename
  
  let dispatch_combine lst =
    fun e ->
      List.iter 
        (fun dispatch -> dispatch e)
        lst 
  
  let dispatch t e = 
    let env = 
      BaseEnvLight.load 
        ~filename:env_filename 
        ~allow_empty:true
        ()
    in
      match e with 
        | Before_options ->
            let no_trailing_dot s =
              if String.length s >= 1 && s.[0] = '.' then
                String.sub s 1 ((String.length s) - 1)
              else
                s
            in
              List.iter
                (fun (opt, var) ->
                   try 
                     opt := no_trailing_dot (BaseEnvLight.var_get var env)
                   with Not_found ->
                     Printf.eprintf "W: Cannot get variable %s" var)
                [
                  Options.ext_obj, "ext_obj";
                  Options.ext_lib, "ext_lib";
                  Options.ext_dll, "ext_dll";
                ]
  
        | After_rules -> 
            (* Declare OCaml libraries *)
            List.iter 
              (function
                 | lib, [] ->
                     ocaml_lib lib;
                 | lib, dir :: tl ->
                     ocaml_lib ~dir:dir lib;
                     List.iter 
                       (fun dir -> 
                          flag 
                            ["ocaml"; "use_"^lib; "compile"] 
                            (S[A"-I"; P dir]))
                       tl)
              t.lib_ocaml;
  
            (* Declare C libraries *)
            List.iter
              (fun (lib, dir, headers) ->
                   (* Handle C part of library *)
                   flag ["link"; "library"; "ocaml"; "byte"; "use_lib"^lib]
                     (S[A"-dllib"; A("-l"^lib); A"-cclib"; A("-l"^lib)]);
  
                   flag ["link"; "library"; "ocaml"; "native"; "use_lib"^lib]
                     (S[A"-cclib"; A("-l"^lib)]);
                        
                   flag ["link"; "program"; "ocaml"; "byte"; "use_lib"^lib]
                     (S[A"-dllib"; A("dll"^lib)]);
  
                   (* When ocaml link something that use the C library, then one
                      need that file to be up to date.
                    *)
                   dep  ["link"; "ocaml"; "use_lib"^lib] 
                     [dir/"lib"^lib^"."^(!Options.ext_lib)];
  
                   (* TODO: be more specific about what depends on headers *)
                   (* Depends on .h files *)
                   dep ["compile"; "c"] 
                     headers;
  
                   (* Setup search path for lib *)
                   flag ["link"; "ocaml"; "use_"^lib] 
                     (S[A"-I"; P(dir)]);
              )
              t.lib_c;
  
              (* Add flags *)
              List.iter
              (fun (tags, cond_specs) ->
                 let spec = 
                   BaseEnvLight.var_choose cond_specs env
                 in
                   flag tags & spec)
              t.flags
        | _ -> 
            ()
  
  let dispatch_default t =
    dispatch_combine 
      [
        dispatch t;
        MyOCamlbuildFindlib.dispatch;
      ]
  
end


open Ocamlbuild_plugin;;
let package_default =
  {
     MyOCamlbuildBase.lib_ocaml = [];
     lib_c = [("ocamlnat", "toplevel", [])];
     flags = [];
     }
  ;;

let dispatch_default = MyOCamlbuildBase.dispatch_default package_default;;

(* OASIS_STOP *)

module Custom = struct
  let dispatch e =
    let env =
      BaseEnvLight.load
        ~filename:(Pathname.basename BaseEnvLight.default_filename)
        ~allow_empty:true
        ()
    and sf =
      Printf.sprintf
    in
      match e with
      | After_rules ->
          let module M = struct

let arch = BaseEnvLight.var_get "architecture" env;;
let ccomptype = BaseEnvLight.var_get "ccomp_type" env;;
let os_type = BaseEnvLight.var_get "os_type" env;;
let system = BaseEnvLight.var_get "system" env;;

let windows = os_type = "Win32";;
if windows then tag_any ["windows"];;

(* C compiler flags *)
flag ["compile"; "c"]
  (S[A"-ccopt"; A("-DOS_" ^ os_type);
     A"-ccopt"; A("-DSYS_" ^ system);
     A"-ccopt"; A("-DTARGET_" ^ arch)]);;

(* The configuration file *)
rule "The configuration file"
  ~prod:"utils/config.ml"
  ~dep:"utils/config.mlp"
  ~insert:`top
  begin fun _ _ ->
    let subst v x = A(Printf.sprintf "s|%%%%%s%%%%|%s|" v x) in
    let subst_var v n = subst v (BaseEnvLight.var_get n env) in
    Cmd(S[A"sed";
          A"-e"; subst_var "LIBDIR" "standard_library_default";
          A"-e"; subst_var "BYTERUN" "standard_runtime";
          A"-e"; subst "CCOMPTYPE" ccomptype;
          A"-e"; subst_var "BYTECC" "bytecomp_c_compiler";
          A"-e"; subst_var "NATIVECC" "native_c_compiler";
          A"-e"; subst "PACKLD" "";
          A"-e"; subst "BYTECCLIBS" "";
          A"-e"; subst "NATIVECCLIBS" "";
          A"-e"; subst "RANLIBCMD" "";
          A"-e"; subst "CC_PROFILE" "";
          A"-e"; subst "ARCH" arch;
          A"-e"; subst_var "MODEL" "model";
          A"-e"; subst "SYSTEM" system;
          A"-e"; subst_var "EXT_OBJ" "ext_obj";
          A"-e"; subst_var "EXT_ASM" "ext_asm";
          A"-e"; subst_var "EXT_LIB" "ext_lib";
          A"-e"; subst_var "EXT_DLL" "ext_dll";
          A"-e"; subst_var "SYSTHREAD_SUPPORT" "systhread_supported";
          A"-e"; subst "ASM" "";
          A"-e"; subst "MKDLL" "";
          A"-e"; subst "MKEXE" "";
          A"-e"; subst "MKMAINDLL" "";
          Sh"<"; P"utils/config.mlp";
          Sh">"; Px"utils/config.ml"])
  end;;

(* The version file *)
rule "The version file"
  ~prod:"toplevel/version.ml"
  ~dep:"toplevel/version.mlp"
  ~insert:`top
  begin fun _ _ ->
    let subst v x = A(Printf.sprintf "s|%%%%%s%%%%|%s|" v x) in
    let subst_var v n = subst v (BaseEnvLight.var_get n env) in
    Cmd(S[A"sed";
          A"-e"; subst_var "VERSION" "pkg_version";
          Sh"<"; P"toplevel/version.mlp";
          Sh">"; Px"toplevel/version.ml"])
  end;;

(* Choose the right machine-dependent files *)

let mk_arch_rule ~src ~dst =
  let prod = "asmcomp"/dst in
  let dep = "asmcomp"/arch/src in
  rule (sf "arch specific files %S%%" dst) ~prod ~dep begin
    if windows then fun env _ -> cp (env dep) (env prod)
    else fun env _ -> ln_s (env (arch/src)) (env prod)
  end;;

mk_arch_rule
  ~src:(if ccomptype = "msvc" then "proc_nt.ml" else "proc.ml")
  ~dst:"proc.ml";;

List.iter
  (fun x -> mk_arch_rule ~src:x ~dst:x)
  ["arch.ml";
   "jit.ml";
   "reload.ml";
   "scheduling.ml";
   "selection.ml"];;

          end in ()
      | _ ->
          ()
end

let dispatch_custom = Custom.dispatch;;

Ocamlbuild_plugin.dispatch begin fun stage ->
   dispatch_custom stage;
   dispatch_default stage
end;;

