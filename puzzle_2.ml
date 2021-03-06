(* Inspired by this puzzle from NPR:
 http://www.npr.org/2012/01/29/146034893/this-puzzle-is-the-pits 
 (see the 'Next Weeks' challenge section there):
 "Next Week's Challenge from listener Ed Pegg Jr.: Write the digits from 
 1 to 9 in a line. If you put times signs after the 2 and 4, a plus 
 sign after the 5, and a minus sign after the 7, you have 
 12 x 34 x 5 + 67 - 89, which equals 2018.
 That's six years off from our current year 2012. This example uses 
 four arithmetic symbols. The object is to use just three of the 
 following arithmetic operations: addition, subtraction, multiplication 
 and division, in a line from 1 to 9 to get 2012 exactly. The operations 
 should be performed in order from left to right" *)

(* NOTE: this implementation performs 
 * operations from left to right
 *)

(* This program solves the puzzle above using a genetic algorithm *)

let cmd_gens   = ref 5000
let cmd_seed   = ref 42
let cmd_target = ref 2012
let cmd_popsize = ref 24
let usage = "usage: " ^ Sys.argv.(0) ^ " [-g int] [-s int]"

(* commandline args *)
let speclist = [
  ("-g", Arg.Int (fun d -> cmd_gens   := d),": generations: int param ");
  ("-s", Arg.Int (fun d -> cmd_seed   := d),": seed: int param");
  ("-t", Arg.Int (fun d -> cmd_target := d),": target: int param");
  ("-p", Arg.Int (fun d -> cmd_popsize := d),": population size: int param");
  ]
 
let () =
  (* Read the arguments *)
  Arg.parse
    speclist
    (fun x -> raise (Arg.Bad ("Bad argument : " ^ x)))
    usage;;

Random.init !cmd_seed 
let nums = [1;   2;   3;   4;   5;   6;   7;   8;   9]
let num_size   = List.length nums
let ops_size = num_size - 1 
let target = !cmd_target
let mutation_rate = 0.10 

(* for future random proportional selection:
module RouletteSel = struct
  type gene = string list
  type roulette_item = { individual: gene;
                         range_f:    float->bool } 
end;;
*)
exception SizeMismatch

let num_to_op rn = match rn with 
         0  -> "C"
       | 1  -> "+"
       | 2  -> "-"
       | 3  -> "*"
       | 4  -> "/"   
       | _  -> "C" 

(* C + - * /  *)
let  build_rnd_ops len = 

  let rec aux outlst len' = match len' with
    0 -> outlst 
  | _ -> 
         let rndnum = Random.int 5 in
         let op = num_to_op rndnum in
         aux (op::outlst) (len'-1) in
  aux [] len 

let rotate_left lst = (List.tl lst) @ [(List.hd lst)] 

let rotate_right lst = List.rev (rotate_left (List.rev lst))

let mutate ops = 
  let ops_len = List.length ops in
  let copy_all_but oplst n newop = 
    let rec aux inlst outlst i = match inlst with
      []    -> List.rev outlst
    | x::xs -> let op = if i = n then
                          newop
                        else
                           x  in
               (aux xs (op::outlst) (i+1)) in
    aux ops [] 0 in
  if (Random.float 1.0 ) < mutation_rate then
    copy_all_but ops (Random.int ops_len ) (num_to_op (Random.int 5)) 
  else
    ops 
   
let combine n_lst op_lst  = 
  let op_lst_len = List.length op_lst in
  let rec build' n_lst' outlst i = match n_lst' with 
      []    ->  List.rev outlst
   |  n::ns ->  if i < op_lst_len then
                  build' ns ( (List.nth op_lst i)::n::outlst) (i+1) 
                else 
                  build' ns ( n::outlst) (i+1) in
   build' n_lst [] 0 

let cross a b = 
  let rec aux a' b' aout bout = match (a',b') with
    ([],[]) -> [List.rev aout; List.rev bout]
  | (an1::an2::a3::[], bn1::bn2::b3::[]) -> 
      aux [] [] (a3::bn2::an1::aout) (b3::an2::bn1::bout)
  | (an1::an2::ans, bn1::bn2::bns) -> 
      aux ans bns (bn2::an1::aout) (an2::bn1::bout) 
  | (_::[],[]) | ([], _::[]) | (_,_) -> raise  SizeMismatch in
  aux a b [] [] 

let rec scramble lst = match lst with
  | [] -> []
  | [a] -> [a]
  | x::y::t -> y::x::scramble t 

let swap_ops lst = 
  let len = List.length lst in
  let r1  = Random.int len in
  let r2  = Random.int len in
  let e1  = List.nth lst r1 in
  let e2  = List.nth lst r2 in
  let rec mapi i accum l = match l with
  | [] -> List.rev accum
  | x::xs -> let item = (match i with
                 a when a = r1 -> e2
              |  b when b = r2 -> e1
              |  _  -> x
             ) in
             mapi (i+1) (item::accum) xs in 
  mapi 0 [] lst 

(* do the 'C's *)
let cat n_oplst =
  let rec do_cat nolst outs accum = match nolst with
     []   -> List.rev outs
  |  n::op::nos -> if op = "C" then
                     do_cat nos outs (accum ^ n) 
                   else 
                     do_cat nos (op::(accum^n)::outs) "" 
  | n::[]       -> do_cat [] ((accum^n)::outs) (accum^n)
                   in
     do_cat n_oplst [] ""

exception BadNumOpFormat

let do_ops lst = 
  let rec mdps nlst accum oper = match nlst with
    []         -> accum
  | n::op::ns  -> let n' = int_of_string n in
                  (match op with
                    "*" -> mdps ns (oper accum n') ( * )
                  | "/" -> mdps ns (oper accum n') ( / )
                  | "+" -> mdps ns (oper accum n') ( + )
                  | "-" -> mdps ns (oper accum n') ( - )
                  | _   -> raise BadNumOpFormat
                  )
  |  n::[]     -> let n' = int_of_string n in 
                  mdps [] (oper accum n') oper in
  mdps lst 1 ( * )  (* multiply by 1 is identity *)


let create_pop size = 
  let rec aux pop s = match s with
    0 -> pop
  | _ -> aux ((build_rnd_ops ops_size)::pop) (s-1) in
  aux [] size 
    
let ( |> ) a b = b a 

exception EvalError
let eval oplst = 
  let oplst' = (combine (List.map (fun x -> string_of_int x) nums) oplst) in
  (cat oplst' |> do_ops ) 


let delta t n =  abs (t - n)  
let delta_target = delta target

(* define a record type *)
type value_str = { value: int; str: string }

(* rank the population based on delta from target *)
let rank_pop pop = List.sort (fun a b -> 
                                if (delta_target (fst a)) > (delta_target ( fst b)) then
                                  1
                                 else if a = b then 
                                  0
                                 else -1
           ) (List.map (fun e ->  (eval e) , e ) pop) 


let take_best_after f candidates  =
  let candidates' = List.map (fun c -> f c ) candidates in
  List.map2 (fun x y -> 
    if (delta_target (eval x)) < (delta_target (eval y)) then x
    else y) candidates candidates' 

(* val tournament_selection : int -> string list list -> string list list *)
(* choose parents for the next generation *)
let tournament_selection num_parents pop = 
  let popsize = List.length pop in
  let rec choose () = 
    let fsti = Random.int (popsize-1) in
    let sndi = Random.int (popsize-1) in
    if (fsti = sndi) then
      (* keep trying until you get two different parents *)
      choose ()
    else
    (
      let a = List.nth pop fsti in
      let b = List.nth pop sndi in
      if ( delta_target (eval a)) < ( delta_target (eval b)) then
        b
      else
        a
    ) in
  let rec get_parents n parents = match n with 
    0  ->  parents
  | _  ->  get_parents (n-1) (( choose () )::parents) in
  let next_parents = get_parents num_parents [] in
  let combine in_pop out_pop  = match in_pop with
    []  -> out_pop
  | a::b::rest -> let children = (cross a b) in
                  if (Random.float 1.0 < 0.25) then
                  (
                    (* 1/4 of the time try swap_ops on children *)
                    let best_children  = take_best_after (swap_ops) children in
                    combine rest (best_children @ out_pop)
                  )
                  else
                    combine rest (children @ out_pop)
  | a::rest  -> combine rest (a::out_pop) in
  combine next_parents [] 

let runit gens = 
  let population = create_pop !cmd_popsize in
  let rec aux pop gen best = match gen with
  (* best is a tuple: ( fitness value, chromosome ) *)
    0 -> ( fst best), (snd best), ( rank_pop pop)
  | _ -> let pop_best =  (List.nth (rank_pop pop) 0) in
         let best' =
          (if (delta_target (fst pop_best)) <
              (delta_target (fst best)) then
             (
               (Printf.printf "gen: %d: pop_best better than best: %d : %d\n" 
                (gens-gen) (fst pop_best) ( fst best)  );
                ( pop_best)
             )
          else
            best
          ) in
         if (fst best') = target then
           (* we're done *)
           (fst best'),(snd best'), (rank_pop pop)
         else
         (
           let pop' = [(snd best')]@ (List.map (fun i -> mutate i )  
                                (tournament_selection (!cmd_popsize/2) pop)
                               ) @ (create_pop (!cmd_popsize/2-1)) in
           aux pop' (gen-1) best'
         ) in
  aux population gens ((eval (List.nth population 0)),List.nth population 0) 

let value, best, ranked_pop = runit !cmd_gens ;;

List.map (fun x -> 
            Printf.printf "%s : %d\n" 
               (String.concat "" 
                     (combine (List.map (fun s -> string_of_int s) nums) (snd x)
                     )) 
               (fst x) ) ranked_pop ;;


let best = List.nth ranked_pop 0 in
Printf.printf "Best answer is: %s = %d\n" 
               (String.concat "" 
                 (List.filter (fun cr -> cr <> "C" ) 
                    (combine (List.map 
                             (fun s -> string_of_int s) nums) 
                             (snd best)
                    )
                 )
               ) 
               ( fst best);;

