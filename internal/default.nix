{ lib }:
let
  inherit (builtins)
    filter head pathExists readDir replaceStrings stringLength substring tail;

  inherit (lib) concatLists mapAttrsToList stringToCharacters;

  inherit (lib.filesystem) pathType;

in rec {
  globSegments = root: pattern: firstSegment:
    let
      patternStart = firstUnescapedMeta pattern;

      splitIndex = lastIndexSlash pattern;

      dir = if splitIndex == -1 then "" else substring 0 splitIndex pattern;

      pattern' = if splitIndex == -1 then
        pattern
      else
        substring (splitIndex + 1) (stringLength pattern) pattern;

    in if patternStart == -1 then
      handleNoMeta root pattern firstSegment
    else if firstSegment && pattern == "**" then
      [ "" ]
    else if splitIndex <= patternStart then
      globSegment root dir pattern' firstSegment
    else
      concatLists (map (dir: globSegment root dir pattern' firstSegment)
        (globSegments root dir false));

  handleNoMeta = root: pattern: firstSegment:
    let
      # If pattern doesn't contain any meta characters, unescape the
      # escaped meta characters.
      escapedPattern = unescapeMeta pattern;

      escapedPath = root + "/${escapedPattern}";

      isDirectory = (pathType escapedPath) == "directory";

    in if pathExists escapedPath && (!firstSegment || !isDirectory) then
      [ escapedPattern ]
    else
      [ ];

  globSegment = root: dir: pattern: matchFiles:
    let path = root + "/${dir}";
    in if pattern == "" then
      if matchFiles then [ ] else [ dir ]
    else if pattern == "**" then
      globDoublestar root dir matchFiles
    else if !pathExists path || pathType path != "directory" then
      [ ]
    else
      let
        matchFileType = file:
          if matchFiles then
            file.type == "regular"
          else
            file.type == "directory";

        onlyMatches = file:
          matchFileType file && lib.globset.match pattern file.name;

        files =
          mapAttrsToList (name: type: { inherit name type; }) (readDir path);

      in map (file: "${dir}/${file.name}") (filter onlyMatches files);

  globDoublestar = root: dir: matchFiles:
    let
      doGlob = root: dir: canMatchFiles:
        let path = root + "/${dir}";
        in if !pathExists path || pathType path != "directory" then
          [ ]
        else
          let
            processEntry = name: type:
              if type == "directory" then
                doGlob root "${dir}/${name}" canMatchFiles
              else if canMatchFiles && type == "regular" then
                [ "${dir}/${name}" ]
              else
                [ ];

            matchesInSubdirs =
              concatLists (mapAttrsToList processEntry (readDir path));

          in [ dir ] ++ matchesInSubdirs;

    in doGlob root dir matchFiles;

  isZeroLengthPattern = pattern:
    pattern == "" || pattern == "*" || pattern == "**" || pattern == "/**"
    || pattern == "**/" || pattern == "/**/";

  firstUnescapedMeta = str:
    let
      chars = stringToCharacters str;

      find = i: chars:
        if chars == [ ] then
          -1
        else
          let
            char = head chars;
            rest = tail chars;
          in if char == "*" || char == "[" then
            i
          else if char == "\\" then
            if rest == [ ] then -1 else find (i + 2) (tail rest)
          else
            find (i + 1) rest;

    in find 0 chars;

  lastIndexSlash = str:
    let
      len = stringLength str;

      isUnescapedSlash = i:
        (substring i 1 str == "/")
        && (i == 0 || substring (i - 1) 1 str != "\\");

      findLastSlash = i:
        if i < 0 then
          -1
        else if isUnescapedSlash i then
          i
        else
          findLastSlash (i - 1);

    in findLastSlash (len - 1);

  findNextSeparator = str: startIdx:
    let
      len = stringLength str;

      findSeparator = i:
        if i >= len then
          -1
        else if substring i 1 str == "/" then
          i
        else
          findSeparator (i + 1);

    in findSeparator startIdx;

  unescapeMeta = str:
    replaceStrings [ "\\*" "\\[" "\\]" "\\-" ] [ "*" "[" "]" "-" ] str;

  /* Function: parseCharClass
     Type: String -> Int -> { content: String, endIdx: Int, isNegated: Bool }
     Parses a character class starting at the given index. Handles
       - Simple classes [abc]
       - Ranges [a-z]
       - Negated classes [^abc] or [!abc]

     Examples:
       parseCharClass "[abc]def" 0 => { content = "abc", endIdx = 4, isNegated = false }
       parseCharClass "x[^0-9]" 1 => { content = "^0-9", endIdx = 6, isNegated = true }
  */
  parseCharClass = str: startIdx:
    let
      len = stringLength str;

      findClosingBracket = idx:
        if idx >= len then
          -1
        else
          let
            char = substring idx 1 str;
            nextChar =
              if (idx + 1) < len then substring (idx + 1) 1 str else "";
          in if char == "\\" && nextChar == "]" then
            findClosingBracket (idx + 2)
          else if char == "]" && idx > startIdx + 1 then
            idx
          else
            findClosingBracket (idx + 1);

      endIdx = findClosingBracket (startIdx + 1);

      processContent = str:
        let
          chars = stringToCharacters str;
          process = chars:
            if chars == [ ] then
              [ ]
            else if head chars == "\\" && tail chars != [ ] then
              [ (head (tail chars)) ] ++ (process (tail (tail chars)))
            else
              [ (head chars) ] ++ (process (tail chars));
        in concatStrings (process (stringToCharacters str));

      rawContent = substring (startIdx + 1) (endIdx - startIdx - 1) str;
      content = processContent rawContent;
      firstChar = substring (startIdx + 1) 1 str;
    in {
      inherit content endIdx;
      isNegated = firstChar == "^" || firstChar == "!";
    };

  /* Function: matchesCharClass
     Type: String -> String -> Bool
     Checks if a character matches the given character class definition

     Examples:
      matchesCharClass "abc" "b"    => true   # Direct match
      matchesCharClass "a-z" "m"    => true   # Range match
      matchesCharClass "^0-9" "a"   => true   # Negated match
      matchesCharClass "!aeiou" "x" => true   # Alternative negation
  */
  matchesCharClass = class: char:
    let
      isNegated = hasPrefix "^" class || hasPrefix "!" class;
      actualClass =
        if isNegated then substring 1 (stringLength class - 1) class else class;

      chars = stringToCharacters actualClass;
      matches = if length chars < 3 then
        builtins.elem char chars
      else if elemAt chars 1 == "-" then
        inCharRange (head chars) (elemAt chars 2) char
      else
        builtins.elem char chars;
      debug = builtins.trace
        "Testing ${char} against ${class} (matches: ${toString matches})" null;
    in if isNegated then !matches else matches;

  /* Function: inCharRange
     Type: String -> String -> String -> Bool

     Checks if a character falls within an ASCII range using character codes.
     Used for implementing range matches like [a-z].

     Examples:
       inCharRange "a" "z" "m" => true  # m is between a-z
       inCharRange "0" "9" "5" => true  # 5 is between 0-9
       inCharRange "a" "f" "x" => false # x is outside a-f
  */
  inCharRange = start: end: char:
    let
      startCode = charToInt start;
      endCode = charToInt end;
      charCode = charToInt char;
    in charCode >= startCode && charCode <= endCode;
}
