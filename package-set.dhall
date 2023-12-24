let upstream = https://github.com/dfinity/vessel-package-set/releases/download/mo-0.10.2-20231113/package-set.dhall sha256:6ce0f76863d2e6c8872a59bf5480b71281eb0e3af14c2bda7a1f34af556abab2

let Package =
    { name : Text, version : Text, repo : Text, dependencies : List Text }

let
  -- This is where you can add your own packages to the package-set
  additions =
    [
      { name = "server"
      , repo = "https://github.com/krpeacock/server"
      , version = "c5307304623879ef88c25ff3f334e4523ffc88d3"
      , dependencies = [ "base", "certified-cache", "json", "array", "encoding", "motoko-sha", "serde", "test", "assets", "http-parser.mo" ]
      },
      { name = "certified-cache"
      , repo = "https://github.com/krpeacock/certified-cache"
      , version = "8657652c4062ef0e91ebe269843ccef1bb4796ae"
      , dependencies = [ "base", "ic-certification", "motoko-sha", "StableHashMap" ]
      },
      { name = "assets"
      , repo = "https://github.com/krpeacock/assets"
      , version = "4a0b09bd495a21a2b35a6077e88aec6ab3b680c8"
      , dependencies = [ "base", "test" ]
      },
      { name = "http-parser.mo"
      , repo = "https://github.com/NatLabs/http-parser.mo"
      , version = "27cba8ed0d39387e0fb660f65909ffe2a7d54413"
      , dependencies = [ "base", "json", "array", "encoding", "parser-combinators" ]
      },
      { name = "ic-certification"
      , repo = "https://github.com/nomeata/ic-certification"
      , version = "c403ffec0a60f658a1009976c785aa567ff0da77"
      , dependencies = [ "base", "sha2", "cbor" ]
      },
      { name = "test"
      , repo = "https://github.com/ZenVoich/test"
      , version = "d91f1a009c7a3da8faf50f9e078626747796f61b"
      , dependencies = [ "base" ]
      },
      { name = "serde"
      , repo = "https://github.com/NatLabs/serde"
      , version = "ed3efe38cc62a3f5392fe0cbd4a2fc9f3e061213"
      , dependencies = [ "base", "itertools", "candid", "xtended-numbers", "json", "parser-combinators", "map" ]
      },
      { name = "map"
      , repo = "https://github.com/ZhenyaUsenko/motoko-hash-map"
      , version = "428f4a7f8c7ca811de0a6afb3f54329bbd8750fd"
      , dependencies = [ "base" ]
      },
      { name = "candid"
      , repo = "https://github.com/edjcase/motoko_candid"
      , version = "62b52fb4ca29abac009ab1b63103200035fa60ea"
      , dependencies = [ "base", "test" ]
      },
      { name = "itertools"
      , repo = "https://github.com/NatLabs/Itertools"
      , version = "1def9eacc9e2f7f4046702cc7684175690f7443c"
      , dependencies = [ "base" ]
      },
      { name = "motoko-sha"
      , repo = "https://github.com/tgalal/motoko-sha"
      , version = "a6d46445670407d51996c42892f696ed34d6296b"
      , dependencies = [ "base" ]
      },
      { name = "StableHashMap"
      , repo = "https://github.com/canscale/StableHashMap"
      , version = "06d5ae9d8561ec0c3768dbfcced6ee90be923b70"
      , dependencies = [ "base" ]
      },
      { name = "mutable-queue"
      , repo = "https://github.com/ninegua/mutable-queue.mo"
      , version = "2759a3b8d61acba560cb3791bc0ee730a6ea8485"
      , dependencies = [ "base", "matchers" ]
      }
    ] : List Package

let
  overrides =
    [
      { name = "sha2"
      , repo = "https://github.com/research-ag/sha2"
      , version = "fb2d19d6d29406d3294a3f514d2b87f928f87bbf" 
      , dependencies = [ "base" ]
      },
      { name = "parser-combinators"
      , repo = "https://github.com/aviate-labs/parser-combinators.mo"
      , version = "v0.1.3"
      , dependencies = [ "base" ]
      },
      { name = "json"
      , repo = "https://github.com/aviate-labs/json.mo"
      , version = "v0.2.1"
      , dependencies = [ "base" ]
      },
      { name = "array"
      , repo = "https://github.com/aviate-labs/array.mo"
      , version = "v0.2.1"
      , dependencies = [ "base" ]
      },
      { name = "encoding"
      , repo = "https://github.com/aviate-labs/encoding.mo"
      , version = "v0.4.1"
      , dependencies = [ "base", "array" ]
      }
    ] : List Package

in  upstream # additions # overrides
