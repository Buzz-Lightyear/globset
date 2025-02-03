{ lib }:

let
  inherit (builtins)
    listToAttrs
    genList
    length
    elemAt
  ;

  internal = import ./. { inherit lib; };

  mkSuite = {
    testNameFn
  , valueFn
  , tests
  }:
    listToAttrs
      (genList
        (i: let
          testCase = elemAt tests i;
          testName = testNameFn testCase;
        in {
          name = "test (${testName})";
          value = {
            expr = valueFn testCase;
            expected = testCase.expected;
          };
        })
        (length tests)
      );

in {
  decodeUtf8 = mkSuite {
    testNameFn = testCase: ''decodeUtf8 "${testCase.str}" ${toString testCase.offset}'';
    valueFn = testCase: internal.decodeUtf8 testCase.str testCase.offset;
    tests = [
      {
        str = "•foo";
        offset = 0;
        expected = "•";
      }
      {
        str = "•foo";
        offset = 3;
        expected = "f";
      }
    ];
  };

  parseCharClass = mkSuite {
    testNameFn = testCase: ''parseCharClass "${testCase.input}" ${toString testCase.startIdx}'';
    valueFn = testCase: internal.parseCharClass testCase.input testCase.startIdx;
    tests = [
      {
        input = "[abc]def";
        startIdx = 0;
        expected = {
          content = "abc";
          endIdx = 4;
          isNegated = false;
        };
      }
      {
        input = "x[^0-9]";
        startIdx = 1;
        expected = {
          content = "0-9";
          endIdx = 6;
          isNegated = true;
        };
      }
      {
        input = "[a\\]b]";
        startIdx = 0;
        expected = {
          content = "a\\]b";
          endIdx = 5;
          isNegated = false;
        };
      }
      {
        input = "[\\^abc]";
        startIdx = 0;
        expected = {
          content = "\\^abc";
          endIdx = 6;
          isNegated = false;
        };
      }
      {
        input = "[!a-z]123";
        startIdx = 0;
        expected = {
          content = "a-z";
          endIdx = 5;
          isNegated = true;
        };
      }
      {
        input = "[^abc]";
        startIdx = 0;
        expected = {
          content = "abc";
          endIdx = 5;
          isNegated = true;
        };
      }
      {
        input = "[abc";
        startIdx = 0;
        expected = {
          content = "abc";
          endIdx = -1;
          isNegated = false;
        };
      }
    ];
  };

  matchesCharClass = mkSuite {
    testNameFn = testCase: ''matchesCharClass "${testCase.class}" "${testCase.char}"'';
    valueFn = testCase: internal.matchesCharClass testCase.class testCase.char;
    tests = [
      {class = "abc"; char = "b"; expected = true;}
      {class = "abc"; char = "d"; expected = false;}
      {class = "abç"; char = "ç"; expected = true;}
      {class = "abc"; char = "ç"; expected = false;}
      {class = "a-c"; char = "c"; expected = true;}
      {class = "a-c"; char = "d"; expected = false;}
      {class = "α-ε"; char = "δ"; expected = true;}
      {class = "α-γ"; char = "δ"; expected = false;}
      {class = "^α-ε"; char = "δ"; expected = false;}
      {class = "^α-γ"; char = "δ"; expected = true;}
      {class = "!α-ε"; char = "δ"; expected = false;}
      {class = "!α-γ"; char = "δ"; expected = true;}
      {class = "^0-9"; char = "a"; expected = true;}
      {class = "^0-9"; char = "9"; expected = false;}
      {class = "!e-g"; char = "d"; expected = true;}
      {class = "!e-g"; char = "f"; expected = false;}
      {class = "^abc"; char = "d"; expected = true;}
      {class = "!abc"; char = "c"; expected = false;}
      {class = "^ab√"; char = "v"; expected = true;}
      {class = "!ab√"; char = "v"; expected = true;}
      {class = "^ab√"; char = "√"; expected = false;}
      {class = "!ab√"; char = "√"; expected = false;}
    ];
  };

  inCharRange = mkSuite {
    testNameFn = testCase: ''inCharRange "${testCase.start}" "${testCase.end}" "${testCase.char}"'';
    valueFn = testCase: internal.inCharRange testCase.start testCase.end testCase.char;
    tests = [
      {start = "a"; end = "c"; char = "b"; expected = true;}
      {start = "a"; end = "c"; char = "B"; expected = false;}
      {start = "0"; end = "9"; char = "5"; expected = true;}
      {start = "3"; end = "6"; char = "7"; expected = false;}
      {start = "3"; end = "6"; char = "6"; expected = true;}
      {start = "3"; end = "6"; char = "3"; expected = true;}
      {start = "α"; end = "ε"; char = "δ"; expected = true;}
      {start = "α"; end = "γ"; char = "δ"; expected = false;}
      {start = "←"; end = "↓"; char = "→"; expected = true;}
      {start = "가"; end = "힣"; char = "박"; expected = true;}
      {start = "あ"; end = "ん"; char = "き"; expected = true;}
      {start = "😀"; end = "😎"; char = "😄"; expected = true;}
    ];
  };

  firstUnescapedMeta = mkSuite {
    testNameFn = testCase: ''firstUnescapedMeta "${testCase.str}"'';
    valueFn = testCase: internal.firstUnescapedMeta testCase.str;
    tests = [
      { str = ""; expected = -1; }
      { str = "*abc"; expected = 0; }
      { str = "\\*a*"; expected = 3; }
      { str = "abc\\*def"; expected = -1; }
      { str = "ab\\*cd*ef"; expected = 6; }
      #TODO: Fix
      # { str = "a∫\\*cd*ef"; expected = 6; }
      { str = "no\\*meta"; expected = -1; }
      { str = "\\\\*meta"; expected = 2; }
      { str = "escaped\\"; expected = -1; }
      { str = "escaped\\\\"; expected = -1; }
    ];
  };

  findOpenBrace = mkSuite {
    testNameFn = testCase: ''findOpenBrace "${testCase.str}" "${toString testCase.idx}"'';
    valueFn = testCase: internal.findOpenBrace testCase.str testCase.idx;
    tests = [
      { str = ""; idx = 0; expected = -1; }
      { str = "{abc"; idx = 0; expected = 0; }
      { str = "{abc"; idx = 1; expected = -1; }
      { str = "\\{a{"; idx = 0; expected = 3; }
      { str = "abc\\{def"; idx = 0; expected = -1; }
      { str = "ab\\{cd{ef"; idx = 0; expected = 6; }
      { str = "åb\\{cd{ef"; idx = 0; expected = 7; }
      { str = "escaped\\"; idx = 0; expected = -1; }
      { str = "escaped\\\\"; idx = 0; expected = -1; }
    ];
  };

  findCloseBrace = mkSuite {
    testNameFn = testCase: ''findCloseBrace "${testCase.str}" "${toString testCase.idx}"'';
    valueFn = testCase: internal.findCloseBrace testCase.str testCase.idx;
    tests = [
      { str = ""; idx = 0; expected = -1; }
      { str = "}abc"; idx = 0; expected = 0; }
      { str = "}abc"; idx = 1; expected = -1; }
      { str = "\\}a}"; idx = 0; expected = 3; }
      { str = "abc\\}def"; idx = 0; expected = -1; }
      { str = "ab\\}cd}ef"; idx = 0; expected = 6; }
      { str = "aå\\}cd}ef"; idx = 0; expected = 7; }
      { str = "escaped\\"; idx = 0; expected = -1; }
      { str = "escaped\\\\"; idx = 0; expected = -1; }
    ];
  };

  findNextComma = mkSuite {
    testNameFn = testCase: ''findNextComma "${testCase.str}" "${toString testCase.idx}" "${toString testCase.len}"'';
    valueFn = testCase: internal.findNextComma testCase.str testCase.idx testCase.len;
    tests = [
      { str = ""; idx = 0; len = 0; expected = -1; }
      { str = ",abc"; idx = 0; len = 4; expected = 0; }
      { str = ",åbc"; idx = 0; len = 4; expected = 0; }
      { str = "abc,def"; idx = 0; len = 7; expected = 3; }
      # TODO: Fix
      # { str = "abç,def"; idx = 0; len = 7; expected = 3; }
      { str = "abc\\,def"; idx = 0; len = 9; expected = -1; }
      { str = "abc\\,def,ghi"; idx = 0; len = 13; expected = 8; }
    ];
  };

  collectParts = mkSuite {
    testNameFn = testCase: ''collectParts "${testCase.str}"'';
    valueFn = testCase: internal.collectParts testCase.str;
    tests = [
      { str = "a,b,c"; expected = ["a" "b" "c"]; }
      { str = "å,b,c"; expected = ["å" "b" "c"]; }
      { str = "å,b,cç,d"; expected = ["å" "b" "cç" "d"]; }
      { str = "a\\,b,c"; expected = ["a\\,b" "c"]; }
      { str = "a\\[b,c"; expected = ["a\\[b" "c"]; }
      { str = "a\\[∫,c"; expected = ["a\\[∫" "c"]; }
      { str = "a\\]b,c"; expected = ["a\\]b" "c"]; }
      { str = "a\\-b,c"; expected = ["a\\-b" "c"]; }
      { str = "a\\*b,c"; expected = ["a\\*b" "c"]; }
      { str = "a,b,[cd]"; expected = ["a" "b" "[cd]"]; }
      { str = "a\\,b,c,d\\{"; expected = ["a\\,b" "c" "d\\{"]; }
      { str = "a\\,∫,c,ƒ\\{"; expected = ["a\\,∫" "c" "ƒ\\{"]; }
      { str = "foo\\,bar,baz"; expected = ["foo\\,bar" "baz"]; }
      { str = "single"; expected = ["single"]; }
      { str = "\\,"; expected = ["\\,"]; }
      { str = "\\µ"; expected = ["\\µ"]; }
      { str = ","; expected = ["" ""]; }
    ];
  };

  expandAlternates = mkSuite {
    testNameFn = testCase: ''expandAlternates "${testCase.pattern}"'';
    valueFn = testCase: internal.expandAlternates testCase.pattern;
    tests = [
      { pattern = "{a,b}"; expected = ["a" "b"]; }
      { pattern = "{å,b}"; expected = ["å" "b"]; }
      { pattern = "{a*,b}"; expected = ["a*" "b"]; }
      { pattern = "{å*,b}"; expected = ["å*" "b"]; }
      { pattern = "{å*µ*,b}"; expected = ["å*µ*" "b"]; }
      { pattern = "{foo.[ch],test_foo.[ch]}"; expected = ["foo.[ch]" "test_foo.[ch]"]; }
      { pattern = "{foo.[çh],test_foo.[çh]}"; expected = ["foo.[çh]" "test_foo.[çh]"]; }
      { pattern = "{[x-z],b}"; expected = ["[x-z]" "b"]; }
      { pattern = "{[ƒ-√],b}"; expected = ["[ƒ-√]" "b"]; }
      { pattern = "pre{a\\,b,c}post"; expected = ["prea,bpost" "precpost"]; }
      { pattern = "foo\\{bar,baz}"; expected = ["foo\\{bar,baz}"]; }
      { pattern = "{a,b\\,c,d}"; expected = ["a" "b,c" "d"]; }
      { pattern = "{a,b\\,c,∂}"; expected = ["a" "b,c" "∂"]; }
      { pattern = "{foo,bar}.{c,h}"; expected = ["foo.c" "foo.h" "bar.c" "bar.h"]; }
      { pattern = "{foo,bar}.{ç,˙}"; expected = ["foo.ç" "foo.˙" "bar.ç" "bar.˙"]; }
      { pattern = "{,foo}"; expected = ["" "foo"]; }
      { pattern = "pre{a,b}post{1,2}"; expected = ["preapost1" "preapost2" "prebpost1" "prebpost2"]; }
    ];
  };

  parseAlternates = mkSuite {
    testNameFn = testCase: ''parseAlternates "${testCase.pattern}"'';
    valueFn = testCase: internal.parseAlternates testCase.pattern;
    tests = [
      { pattern = "{a,b}"; expected = { prefix = ""; alternates = ["a" "b"]; suffix = ""; }; }
      { pattern = "{å,b}"; expected = { prefix = ""; alternates = ["å" "b"]; suffix = ""; }; }
      { pattern = "{ßå,b}"; expected = { prefix = ""; alternates = ["ßå" "b"]; suffix = ""; }; }
      { pattern = "{ßå,b,√∫˜}"; expected = { prefix = ""; alternates = ["ßå" "b" "√∫˜"]; suffix = ""; }; }
      { pattern = "pre{a\\,b,c}post"; expected = { prefix = "pre"; alternates = ["a\\,b" "c"]; suffix = "post"; }; }
      { pattern = "pre{a\\,∫,c}pos†"; expected = { prefix = "pre"; alternates = ["a\\,∫" "c"]; suffix = "pos†"; }; }
      { pattern = "foo\\{bar,baz}"; expected = { prefix = ""; alternates = ["foo\\{bar,baz}"]; suffix = ""; }; }
      { pattern = "{a,b\\,c,d}"; expected = { prefix = ""; alternates = ["a" "b\\,c" "d"]; suffix = ""; }; }
      { pattern = "{å,b\\,ç,d}"; expected = { prefix = ""; alternates = ["å" "b\\,ç" "d"]; suffix = ""; }; }
    ];
  };

  match = mkSuite {
    testNameFn = testCase: ''match "${testCase.pattern}" "${testCase.path}"'';
    valueFn = testCase: lib.globset.match testCase.pattern testCase.path;
    tests = [
      # Single glob
      { pattern = "*"; path = ""; expected = true; }
      { pattern = "*"; path = "/"; expected = false; }
      { pattern = "/*"; path = "/"; expected = true; }
      { pattern = "/*"; path = "/debug/"; expected = false; }
      { pattern = "/*"; path = "//"; expected = false; }
      { pattern = "abc"; path = "abc"; expected = true; }
      { pattern = "åbc"; path = "åbc"; expected = true; }
      { pattern = "*"; path = "abc"; expected = true; }
      { pattern = "*c"; path = "abc"; expected = true; }
      { pattern = "*ç"; path = "abç"; expected = true; }
      { pattern = "*/"; path = "a/"; expected = true; }
      { pattern = "a*"; path = "a"; expected = true; }
      { pattern = "a*"; path = "abc"; expected = true; }
      { pattern = "a*"; path = "ab/c"; expected = false; }
      { pattern = "a*/b"; path = "abc/b"; expected = true; }
      { pattern = "å*/b"; path = "åbc/b"; expected = true; }
      { pattern = "a*/b"; path = "a/c/b"; expected = false; }
      { pattern = "a*/c/"; path = "a/b"; expected = false; }
      { pattern = "a*b*c*d*e*"; path = "axbxcxdxe"; expected = true; }
      { pattern = "a*b*c*d*e*/f"; path = "axbxcxdxe/f"; expected = true; }
      { pattern = "a*b*c*d*e*/f"; path = "axbxcxdxexxx/f"; expected = true; }
      { pattern = "a*b*c*d*e*/f"; path = "axbxcxdxe/xxx/f"; expected = false; }
      { pattern = "a*b*c*d*e*/f"; path = "axbxcxdxexxx/fff"; expected = false; }
      { pattern = "a\\*b"; path = "ab"; expected = false; }

      # Globstar / doublestar
      { pattern = "**"; path = ""; expected = true; }
      { pattern = "a/**"; path = "a"; expected = true; }
      { pattern = "å/**"; path = "å"; expected = true; }
      { pattern = "a/**/"; path = "a"; expected = true; }
      { pattern = "a/**"; path = "a/"; expected = true; }
      { pattern = "a/**/"; path = "a/"; expected = true; }
      { pattern = "a/**"; path = "a/b"; expected = true; }
      { pattern = "a/**"; path = "a/b/c"; expected = true; }
      { pattern = "**/c"; path = "c"; expected = true; }
      { pattern = "**/c"; path = "b/c"; expected = true; }
      { pattern = "**/c"; path = "a/b/c"; expected = true; }
      { pattern = "**/ç"; path = "a/b/ç"; expected = true; }
      { pattern = "**/c"; path = "a/b"; expected = false; }
      { pattern = "**/c"; path = "abcd"; expected = false; }
      { pattern = "**/c"; path = "a/abc"; expected = false; }
      { pattern = "a/**/b"; path = "a/b"; expected = true; }
      { pattern = "å/**/∫"; path = "å/∫"; expected = true; }
      { pattern = "a/**/c"; path = "a/b/c"; expected = true; }
      { pattern = "a/**/d"; path = "a/b/c/d"; expected = true; }
      { pattern = "a/\\**"; path = "a/b/c"; expected = false; }

      # Character Class
      {
        pattern = "[abc]";
        path = "b";
        expected = true;
      }
      {
        pattern = "[abc]";
        path = "d";
        expected = false;
      }
      {
        pattern = "[abç]";
        path = "ç";
        expected = true;
      }
      {
        pattern = "[abç]";
        path = "d";
        expected = false;
      }
      {
        pattern = "[α-θ]";
        path = "θ";
        expected = true;
      }
      {
        pattern = "[α-θ]";
        path = "ω";
        expected = false;
      }
      {
        pattern = "[^α-θ]";
        path = "θ";
        expected = false;
      }
      {
        pattern = "[^α-θ]";
        path = "ω";
        expected = true;
      }
      {
        pattern = "[!α-θ]";
        path = "θ";
        expected = false;
      }
      {
        pattern = "[!α-θ]";
        path = "ω";
        expected = true;
      }
      {
        pattern = "[^abc]";
        path = "d";
        expected = true;
      }
      {
        pattern = "[^abc]";
        path = "b";
        expected = false;
      }
      {
        pattern = "[!0-9]";
        path = "a";
        expected = true;
      }
      {
        pattern = "[!0-9]";
        path = "5";
        expected = false;
      }
      {
        pattern = "foo[abc].txt";
        path = "fooa.txt";
        expected = true;
      }
      {
        pattern = "[a-z]/**/*.txt";
        path = "d/foo/bar.txt";
        expected = true;
      }
      {
        pattern = "*.[ch]";
        path = "foo.c";
        expected = true;
      }
      {
        pattern = "*.[ch]";
        path = "foo.o";
        expected = false;
      }
      {
        pattern = "[^a-e][!p-r]o.c";
        path = "foo.c";
        expected = true;
      }
      {
        pattern = "f[\\-].c";
        path = "f-.c";
        expected = true;
      }
      {
        pattern = "f[\\[\\]].c";
        path = "f[.c";
        expected = true;
      }
      {
        pattern = "f[\\[\\]].c";
        path = "f].c";
        expected = true;
      }
      {
        pattern = "ƒ[\\[\\]].ç";
        path = "ƒ].ç";
        expected = true;
      }
      {
        pattern = "[ef]\\*.c";
        path = "f*.c";
        expected = true;
      }
      {
        pattern = "[´f]\\*.c";
        path = "´*.c";
        expected = true;
      }
    ];
  };
}
