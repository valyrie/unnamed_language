(* cli options *)

type action =
    Rest
    | Set_bool of bool ref
    | Inc_int of int ref
    | Append_string of string list ref

type t =
    {keys: string list; action: action; help: string}

let opt_pad padding =
    String.init padding (fun _ -> ' ')
let rec keys_length keys =
    match keys with
        [] -> 0
        | [k] -> String.length k
        | k :: tail -> (String.length k) + (String.length ", ") + (keys_length tail)
let rec opt_keys_length opts =
    match opts with
        [] -> 0
        | opt :: tail -> max (keys_length opt.keys) (opt_keys_length tail)
let print_opt klen opt =
    String.concat "" [
        "  ";
        opt_pad (klen - (keys_length opt.keys));
        String.concat ", " opt.keys;
        "  ";
        opt.help]
let print opts =
    let klen = opt_keys_length opts in
        String.concat "\n" (List.map (fun opt -> print_opt klen opt) opts) 
let rec arg_in_keys arg keys =
    match keys with
        [] -> false
        | k :: rest -> if arg = k then
            true
        else
            arg_in_keys arg rest
let rec match_opt arg opts =
    match opts with
        [] -> None
        | opt :: rem_opts -> if not (arg_in_keys arg opt.keys) then
            match_opt arg rem_opts
        else
            Some opt

let rec parse_opts_argv argv opts =
    match argv with
        [] -> []
        | switch :: tail -> match (match_opt switch opts) with
            None -> argv
            | Some opt -> match opt.action with
                Rest -> tail
                | Set_bool b -> b := true; parse_opts_argv tail opts
                | Inc_int i -> i := !i + 1; parse_opts_argv tail opts
                | Append_string l -> match tail with
                    [] -> argv
                    | arg :: rem_tail -> l := !l @ [arg]; parse_opts_argv rem_tail opts

let parse opts =
    parse_opts_argv (Array.to_list Sys.argv) opts