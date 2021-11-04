(* parser type *)

open Ast
open File
type t =
    {v: Expr.t list; offset: int; source: Source.t}
let make_from off stop: From.t =
    {offset = off.offset; stop = stop.offset; source = off.source}
let make_from1 off: From.t =
    {offset = off.offset; stop = off.offset + 1; source = off.source}
let of_source s =
    {v = []; offset = 0; source = s}
let look p n =
    Source.read_byte p.source (p.offset + n)
let advance p n =
    {p with offset = p.offset + n}
let is_iws c =
    c = ' ' || c = '\t'
let is_break c =
    is_iws c || c = '\n' || c = '\r'
let rec skip_iws p =
    match look p 0 with
        Some c when is_iws c -> advance p 1 |> skip_iws
        | Some '\n' -> advance p 1 |> skip_iws
        | Some '\r' -> begin match look p 1 with
            Some '\n' -> advance p 2 |> skip_iws
            | _ -> p
        end
        | _ -> p
let rec lex_ident_body s p: t * Expr.t =
    match look p 0 with
        Some c when not (is_break c) -> advance p 1 |> lex_ident_body s
        | _ -> p, Identifier {bytes = Source.read_bytes s.source s.offset (p.offset - s.offset); from = make_from s p}
let lex_token p: t * Expr.t =
    let p = skip_iws p in
    match look p 0 with
        None -> p, None
        | Some '(' -> advance p 1, Left_parenthesis {from = make_from1 p}
        | Some ')' -> advance p 1, Right_parenthesis {from = make_from1 p}
        | Some _ -> advance p 1 |> lex_ident_body p
let push x p =
    {p with v = x :: p.v}
let rec drop n p =
    if n > 0 then
        drop (n - 1) {p with v = List.tl p.v}
    else
        p
let la1 p =
    let (_, x) = lex_token p in
        x
let rec shift p =
    let (px, x) = lex_token p in
        push x px |> parse_expr
and reduce n x p =
    drop n p |> push x |> parse_expr
and parse_expr p: Expr.t =
    match (la1 p, p.v) with
        (* REDUCE UNIT *)
        | _, (Right_parenthesis r) :: (Left_parenthesis l) :: _ -> reduce 2 (Unit {left = l; right = r}) p
        (* REDUCE PARENS *)
        | _, (Right_parenthesis r) :: x :: (Left_parenthesis l) :: _ -> reduce 3 (Parentheses {x = x; left = l; right = r}) p
        (* REDUCE CONS *)
        | _, r :: l :: _ when not (is_structural r) && not (is_structural l) -> reduce 2 (Cons {left = l; right = r}) p
        (* RETURN *)
        | None, [x] -> x
        | None, [] -> None
        (* SHIFT *)
        | _, _ -> shift p