module Map = Base.Map.Poly

let process_dir root =
  let rec process_dir dir =
    let dir_path = Filename.concat root dir in
    let files = Sys.readdir dir_path |> Array.to_list in
    let re = Str.regexp {| *\.\. *_\(.+\):|} in
    List.map
      (fun file ->
         let file_path = Filename.concat dir_path file in
         let new_path = Filename.concat dir file in
         if Sys.is_directory file_path
         then process_dir new_path
         else if String.ends_with ~suffix:".rst" file_path
         then (
           let basename = String.sub file 0 (String.length file - 4) in
           let destination = Filename.concat dir basename in
           let lines = In_channel.with_open_text file_path In_channel.input_lines in
           List.filter_map
             (fun line ->
                if Str.string_match re line 0
                then (
                  let label = Str.matched_group 1 line in
                  Some (label, destination))
                else None)
             lines)
         else [])
      files
    |> List.flatten
  in
  process_dir "."
;;

let usage () =
  Format.printf "usage: rsttools COMMAND ...\n";
  Format.printf "\tcollect <dir with rst> - collect refs from RST files\n";
  Format.printf "\tsubstitute <dict.txt> - substitute refs into Markdown files \n"
;;

let () =
  let cmd = Array.get Sys.argv 1 in
  match cmd with
  | "collect" ->
    let () =
      if Array.length Sys.argv < 3
      then (
        Format.printf "usage: rsttools collect <dir with rst>";
        exit (-2))
    in
    let root = Array.get Sys.argv 2 in
    process_dir root |> List.iter (fun (a, b) -> Format.printf "%s %s\n" a b)
  | "substitute" ->
    let () =
      if Array.length Sys.argv < 3
      then (
        Format.printf "usage: rsttools substitute <dict.txt>";
        exit (-2))
    in
    let dict_file = Array.get Sys.argv 2 in
    let dict_lines = In_channel.with_open_text dict_file In_channel.input_lines in
    let dict =
      List.filter_map
        (fun line ->
           match String.split_on_char ' ' line with
           | [ a; b ] -> Some (a, b)
           | _ -> None)
        dict_lines
      |> Map.of_alist_reduce ~f:(fun v1 _ -> v1)
    in
    let rec loop () =
      match In_channel.input_line stdin with
      | Some line ->
        let re = Str.regexp {|](\(.*\))|} in
        let rec get_all_matches i s =
          match Str.search_forward re s i with
          | i ->
            (match Str.matched_group 1 s with
             | label ->
               (match Map.find dict label with
                | Some repl ->
                  Str.replace_first re (String.concat "" [ "]("; repl; ")" ]) s
                  |> get_all_matches (i + 1)
                | None -> get_all_matches (i + 1) s)
             | exception Invalid_argument _ -> get_all_matches (i + 1) s)
          | exception Not_found -> s
          | exception Invalid_argument _ -> s
        in
        Format.printf "%s\n" (get_all_matches 0 line);
        loop ()
      | None -> ()
    in
    loop ()
  | _ -> usage ()
;;
