let upstream = https://github.com/dfinity/vessel-package-set/releases/download/mo-0.12.1-20240808/package-set.dhall sha256:975d4b33f3ce1fa051c73e45fab69dd187dba6b037b6d2e5568ccac26c477d4f

let Package =
    { name : Text, version : Text, repo : Text, dependencies : List Text }

let
  -- This is where you can add your own packages to the package-set
  additions =
    [
      { name = "server"
      , repo = "https://github.com/krpeacock/server"
      , version = "011677de33a188fa981d6eac42e09dbe65dabd00"
      , dependencies = [ "base", "certified-cache", "serde", "test", "assets", "http-parser" ]
      },
      { name = "certified-cache"
      , repo = "https://github.com/krpeacock/certified-cache"
      , version = "96ef8a3f05669641506fb90faf01ac55dde9721d"
      , dependencies = [ "base", "ic-certification", "sha2", "StableHashMap" ]
      },
      { name = "assets"
      , repo = "https://github.com/krpeacock/assets"
      , version = "b3b5788a136695cea1b3877f5356f3b8bc205d14"
      , dependencies = [ "base", "test" ]
      },
      { name = "http-parser"
      , repo = "https://github.com/NatLabs/http-parser.mo"
      , version = "0387c36851547731d69a4e2839916bbf16bc56b8"
      , dependencies = [ "base", "json", "encoding", "format" ]
      },
      { name = "format"
      , repo = "https://github.com/tomijaga/format.mo"
      , version = "e96cb389d44f923164e940b0bd35c8a459f128f1"
      , dependencies = [ "base" ]
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
