//////////////////////////////////////////////////////////////////////////////
//
// MIT License
// Copyright (c) 2023 Cycle.Express
//
//////////////////////////////////////////////////////////////////////////////

import Server "mo:server";
import Assets "mo:assets";
import T "mo:assets/Types";
import HttpTypes "mo:http-parser/Types";
import JSON "mo:json/JSON";
import Queue "mo:mutable-queue/Queue";

import Account "./Account";
import Util "./Util";
import CyclesLedger "./CyclesLedger";

import Buffer "mo:base/Buffer";
import Cycles "mo:base/ExperimentalCycles";
import Int "mo:base/Int";
import Nat "mo:base/Nat";
import Option "mo:base/Option";
import Principal "mo:base/Principal";
import Text "mo:base/Text";
import Time "mo:base/Time";
import Region "mo:base/Region";
import Nat64 "mo:base/Nat64";

shared ({ caller = creator }) actor class CycleExpress(init: {
  prodKey: Text;     // authKey for checkout endpoint
  testKey: Text;     // authKey for checkout testing
  margin: Nat;       // profit margin, percentage radix 2
  defaultPrice: Nat; // default price, Cycles per USD 
}) {

/*********************************************************
 ********************** Persistent Logs ******************
 *********************************************************/

  // Index of saved log entry.
  public type Index = Nat64;

  // Internal representation uses two regions, working together.
  stable var logState = {
    bytes = Region.new();
    var bytesCount : Nat64 = 0;
    elems = Region.new ();
    var elemsCount : Nat64 = 0;
  };

  // Grow a region to hold a certain number of total bytes.
  func regionEnsureSizeBytes(r : Region, new_byte_count : Nat64) {
    let pages = Region.size(r);
    if (new_byte_count > pages << 16) {
      let new_pages = pages + ((new_byte_count + ((1 << 16) - 1)) / (1 << 16));
      assert Region.grow(r, new_pages) == pages
    }
  };

  // Element = Position and size of a saved a Blob.
  type Elem = {
    pos : Nat64;
    size : Nat64;
  };

  let elem_size = 16 : Nat64; /* two Nat64s, for pos and size. */

  func logCount() : Nat64 {
      logState.elemsCount
  };

  // Constant-time random access to previously-logged Blob.
  func get_log(index : Index) : Blob {
    assert index < logState.elemsCount;
    let pos = Region.loadNat64(logState.elems, index * elem_size);
    let size = Region.loadNat64(logState.elems, index * elem_size + 8);
    let elem = { pos ; size };
    Region.loadBlob(logState.bytes, elem.pos, Nat64.toNat(elem.size))
  };

  // View logs in the given interval.
  public shared ({ caller }) func view_logs(start: Index, count: Nat64) : async [Text] {
    assert(caller == creator);
    let size = logState.elemsCount;
    var i = start;
    let logs : Buffer.Buffer<Text> = Buffer.Buffer(Nat64.toNat(count));
    while (i < size and i < start + count) {
      let blob = get_log(i);
      switch (Text.decodeUtf8(blob)) {
        case (?text) { logs.add(text); };
        case null {}
      };
      i := i + 1;
    };
    Buffer.toArray(logs)
  };

  // Add Blob to the log, and return the index of it.
  func add_log(text : Text) {
    let blob = Text.encodeUtf8(text);
    let elem_i = logState.elemsCount;
    logState.elemsCount += 1;

    let elem_pos = logState.bytesCount;
    logState.bytesCount += Nat64.fromNat(blob.size());

    regionEnsureSizeBytes(logState.bytes, logState.bytesCount);
    Region.storeBlob(logState.bytes, elem_pos, blob);

    regionEnsureSizeBytes(logState.elems, logState.elemsCount * elem_size);
    Region.storeNat64(logState.elems, elem_i * elem_size + 0, elem_pos);
    Region.storeNat64(logState.elems, elem_i * elem_size + 8, Nat64.fromNat(blob.size()));
  };

  // Helper to create logging function.
  func logger(name: Text) : Text -> async () {
    let prefix = "[" # Int.toText(Time.now()) # "/";
    func(s: Text) : async () {
      add_log(prefix # Int.toText(Time.now() / 1_000_000_000) # "] " # name # ": " # s)
    }
  };

/*********************************************************
 *************** System Administration *******************
 *********************************************************/
  // Number of cycles per USD.
  type Status = Util.Status;
  type ClientId = Util.ClientId;
  type Cycle = Nat; // radix 12
  type Icp = Nat; // radix 8
  type Usd = Nat; // radix 2

  // Track deposited cycles and their purchase price. 
  // Must call deposit() method to add new deposits.
  stable var deposits = Queue.empty<(Cycle, Usd)>();

  // Track shippings (Cycle) and income (Usd).
  // A new zero entry is pushed to front for each new deposit. 
  // The top entry is always updated whenever there is a 
  // successful transaction.
  stable var shippings = Queue.empty<(Cycle, Usd)>();

  // Cycles per Usd
  func currentPrice() : Cycle {
    Option.get(
      Util.calculatePrice(
        Queue.toIter(deposits), Queue.toIter(shippings), init.margin),
      init.defaultPrice);
  };

  stable var serviceStatus : Status = #Normal({ cyclesPerUsd = currentPrice() });

  func status() : Status {
    switch (serviceStatus) {
      case (#Normal(_)) (#Normal({ cyclesPerUsd = currentPrice() }));
      case _ serviceStatus;
    }
  };

  type Stats = {
    creator: Principal;
    authorized: [Principal];
    cycles: Nat;
    status: Status;
    logCount: Nat64;
    logProcessed: Nat64;
    pending: Nat64;
    failed: Nat64;
    processed: Nat64;
    pumping: Bool;
    deposits: [(Cycle, Usd)];
    shippings: [(Cycle, Usd)];
  };

  public shared ({ caller }) func deposit(cycles: Cycle, icp: Icp, usdPerIcp: Usd) {
    assert(caller == creator);
    ignore Queue.pushFront((cycles, icp * usdPerIcp / 100_000_000), deposits);
    ignore Queue.pushFront((0, 0), shippings);
  };

  public shared ({ caller }) func stats() : async Stats {
    assert(caller == creator);
    { creator = creator; 
      authorized = serializedEntries.2;
      status = status();
      cycles = Cycles.balance();
      logCount = logCount();
      logProcessed = processedCount;
      pending = Nat64.fromNat(Queue.size(pending));
      failed = Nat64.fromNat(Queue.size(failed));
      processed = Nat64.fromNat(Queue.size(processed));
      pumping = pumping;
      deposits = Queue.toArray(deposits);
      shippings = Queue.toArray(shippings);
    }
  };

/*********************************************************
 *************** Transaction Processor *******************
 *********************************************************/
  type Management = actor { deposit_cycles : ({canister_id: Principal}) -> async (); };
 
  let MAX_QUEUE_SIZE : Int = 333;
  let MIN_CYCLE_RESERVE = 100_000_000_000_000; // 100T cycle reserve
  let FEE_USD = 30; // Stripe flat fee
  stable var pending = Queue.empty<(ClientId, Nat)>();
  stable var failed = Queue.empty<(ClientId, Nat, Text)>();
  stable var processed = Queue.empty<(ClientId, Nat)>();
  stable var processedCount : Nat64 = 0;


  public shared ({ caller }) func resetAuthorized() {
    assert(caller == creator);
    let (caches, stables, _) = serializedEntries;
    serializedEntries := (caches, stables, [creator]);
  };

  public shared ({ caller }) func resetProcessed() {
    assert(caller == creator);
    processedCount := 0;    
  };

  public shared ({ caller }) func pumpFailed() {
    assert(caller == creator);
    label LOOP loop {
      switch (Queue.popFront(failed)) {
        case null { break LOOP };
        case (?(client, amount, _)) {
          ignore Queue.pushBack(pending, (client, amount))
        }
      }
    };
    await pump();
  };

  stable var pumping = false;
  // This function must never throw.
  func pump() : async () {
    if (pumping) return;
    pumping := true;
    let log = logger("pump");
    let mgmt : Management = actor("aaaaa-aa");
    label LOOP loop {
      switch (Queue.popFront(pending)) {
        case null { break LOOP };
        case (?(client, paid_amount)) {
          await log("processing = " # debug_show(client, paid_amount));
          if (paid_amount <= FEE_USD) {
              let item = (client, paid_amount, "InsufficientAmount");
              await log("failed = " # debug_show(item));
              ignore Queue.pushBack(failed, item);
          } else {
            let amount = Nat.sub(paid_amount, FEE_USD);
            let cycles = amount * currentPrice() / 100;
            if (cycles + MIN_CYCLE_RESERVE > Cycles.balance()) {
              let item = (client, amount, "InsufficientCycles");
              await log("failed = " # debug_show(item));
              ignore Queue.pushBack(failed, item);
              break LOOP;
            };
            try {
              switch (client.subaccount) {
                case (?subaccount) {
                  let ledger : CyclesLedger.Self = actor("um5iw-rqaaa-aaaaq-qaaba-cai");
                  let to = { owner = client.canisterId; subaccount = ?subaccount };
                  let memo = ?Text.encodeUtf8(client.nonce);
                  Cycles.add<system>(cycles);
                  let result = await ledger.deposit({ to; memo });
                  await log("processed = " # debug_show(client, amount, result));
                };
                case null {
                  Cycles.add<system>(cycles);
                  await mgmt.deposit_cycles({ canister_id = client.canisterId });
                  await log("processed = " # debug_show(client, amount));
                };
              };
              switch (Queue.popFront(shippings)) {
                case null {};
                case (?(shipped, earned)) {
                  ignore Queue.pushFront((shipped + cycles, earned + amount), shippings);
                }
              };
              ignore Queue.pushBack(processed, (client, amount));
              if (Queue.size(processed) > MAX_QUEUE_SIZE) {
                ignore Queue.popFront(processed);
              }
            } catch (err) {
              let item = (client, amount, Util.showError(err));
              await log("failed = " # debug_show(item));
              ignore Queue.pushBack(failed, item);
              break LOOP;
            };
          }
        }
      }
    };
    pumping := false;
  };

  func lookupSession(sessionId: Text) : ?(Text, Account.Account, Nat) {
    do ? {
      let (timestamp, nonce) = Util.parseSessionId(sessionId) !;
      for ((client, amount) in Queue.toIter(pending)) {
        if (timestamp == client.timestamp and nonce == client.nonce) {
          let account = { owner = client.canisterId; subaccount = client.subaccount };
          return ?("pending", account, amount)
        }
      };
      for ((client, amount) in Queue.toIter(processed)) {
        if (timestamp == client.timestamp and nonce == client.nonce) {
          let account = { owner = client.canisterId; subaccount = client.subaccount };
          return ?("done", account, amount)
        }
      };
      for ((client, amount, error) in Queue.toIter(failed)) {
        if (timestamp == client.timestamp and nonce == client.nonce) {
          let account = { owner = client.canisterId; subaccount = client.subaccount };
          return ?(error, account, amount)
        }
      };
      null !
    }
  };

  func process(i: Nat64) {
    let blob = get_log(i);  
    switch (Util.parseLog(blob)) {
      case (?(client, status, amount)) {
        if (status == "paid") {
          ignore Queue.pushBack(pending, (client, amount));
        }
      };
      case _ {}
    }
  };

  // Helper function only for admin.
  public shared ({ caller }) func processOne(i: Nat64) {
    assert(caller == creator);
    process(i);
    ignore pump();
  };

  public func processLogs() {
    var i = processedCount;
    while (i < logCount()) {
      process(i);
      i := i + 1;
    };
    processedCount := i;
    ignore pump();
  };

 /*********************************************************
 ********************** HTTP Server **********************
 ********************************************************/

  type Request = Server.Request;
  type Response = Server.Response;
  type HttpRequest = Server.HttpRequest;
  type HttpResponse = Server.HttpResponse;
  type ResponseClass = Server.ResponseClass;
  type Body = HttpTypes.Body;
  type JSON = JSON.JSON;

  stable var serializedEntries : Server.SerializedEntries = ([], [], [creator]);

  var server = Server.Server({ serializedEntries });

  let assets = server.assets;

  func checkout(endpoint: Text): (Request, ResponseClass) -> async* Response {
    func(req : Request, res : ResponseClass) : async* Response {
      let authKey = if (endpoint == "checkout") init.prodKey else init.testKey;
      let log = logger(endpoint);
      await log("headers = " # Util.headersText(req.headers));
      let signature = 
        Option.map<[Text], Text>(
          req.headers.get("stripe-signature"),
          func (texts) { Text.join(",", texts.vals()) });
      let (status_code, body) = 
        switch (Option.chain(signature, Util.parseStripeSignature), req.body) {
          case (null, _) { 
            await log("malformed stripe-signature");
            (400: Nat16, "Missing or malformed stripe-signature header")
          };
          case (_, null) {
            await log("missing body");
            (400: Nat16, "Missing body")
          };
          case (?(timestamp, signature), ?body) {
            // TODO:
            // 1. Reject expired requests
            // 2. Dedup non-expired requests
            switch (body.deserialize()) {
              case null {
                await log("malformed body = " # body.text());
                (400: Nat16, "Malformed JSON body")
              };
              case (?json) {
                if (not Util.verifyStripeSignature(timestamp, signature, 
                     authKey, body.text())) {
                  await log("invalid signature, body = " # body.text());
                  (400: Nat16, "Invalid signature") 
                } else {
                  await log("body = " # JSON.show(json));
                  if (authKey == init.prodKey) { processLogs() };
                  (200: Nat16, "")
                }
              }
            }
          }
        };
      res.json({
        status_code = status_code;
        body = body;
        cache_strategy = #noCache;
        upgrade = ?true;
      })
    }
  };

  server.post("/checkout", checkout("checkout"));

  server.post("/test-checkout", checkout("test-checkout"));

  server.get(
    "/status",
    func(req : Request, res : ResponseClass) : async* Response {
      let (status_code, body) = switch (req.url.queryObj.get("sessionId")) {
        case null (200 : Nat16, Util.statusText(status()));
        case (?sessionId) {
          switch (lookupSession(sessionId)) {
            case null (404 : Nat16, "SessionNotFound");
            case (?(status, account, amount)) {
              let cycles = amount * currentPrice() / 100;
              (200 : Nat16, "{ \"status\": \"" # status #
                  "\",\"account\": \"" # Account.toText(account) #
                  "\", \"amount\": \"" # Nat.toText(amount) #
                  "\", \"cycles\": \"" # Nat.toText(cycles) #
                  "\", \"fee\": \"" # Nat.toText(FEE_USD) #
                  "\" }")
            }
          }
        }
      };
      res.json({
        status_code = status_code;
        body = body;
        cache_strategy = #noCache;
      });
    },
  );

  public shared ({ caller }) func authorize(other : Principal) : async () {
    server.authorize({
      caller;
      other;
    });
  };

  public query func retrieve(path : Assets.Path) : async Assets.Contents {
    assets.retrieve(path);
  };

  public shared ({ caller }) func store(
    arg : {
      key : Assets.Key;
      content_type : Text;
      content_encoding : Text;
      content : Blob;
      sha256 : ?Blob;
    }
  ) : async () {
    server.store({
      caller;
      arg;
    });
  };

  public query func list(arg : {}) : async [T.AssetDetails] {
    assets.list(arg);
  };

  public query func get(
    arg : {
      key : T.Key;
      accept_encodings : [Text];
    }
  ) : async ({
    content : Blob;
    content_type : Text;
    content_encoding : Text;
    total_length : Nat;
    sha256 : ?Blob;
  }) {
    assets.get(arg);
  };

  public shared ({ caller }) func create_batch(arg : {}) : async ({
    batch_id : T.BatchId;
  }) {
    assets.create_batch({
      caller;
      arg;
    });
  };

  public shared ({ caller }) func create_chunk(
    arg : {
      batch_id : T.BatchId;
      content : Blob;
    }
  ) : async ({
    chunk_id : T.ChunkId;
  }) {
    assets.create_chunk({
      caller;
      arg;
    });
  };

  public shared ({ caller }) func commit_batch(args : T.CommitBatchArguments) : async () {
    assets.commit_batch({
      caller;
      args;
    });
  };

  public shared ({ caller }) func create_asset(arg : T.CreateAssetArguments) : async () {
    assets.create_asset({
      caller;
      arg;
    });
  };

  public shared ({ caller }) func set_asset_content(arg : T.SetAssetContentArguments) : async () {
    assets.set_asset_content({
      caller;
      arg;
    });
  };

  public shared ({ caller }) func unset_asset_content(args : T.UnsetAssetContentArguments) : async () {
    assets.unset_asset_content({
      caller;
      args;
    });
  };

  public shared ({ caller }) func delete_asset(args : T.DeleteAssetArguments) : async () {
    assets.delete_asset({
      caller;
      args;
    });
  };

  public shared ({ caller }) func clear(args : T.ClearArguments) : async () {
    assets.clear({
      caller;
      args;
    });
  };

  public type StreamingCallbackToken = {
    key : Text;
    content_encoding : Text;
    index : Nat;
    sha256 : ?Blob;
  };

  public type StreamingCallbackHttpResponse = {
    body : Blob;
    token : ?StreamingCallbackToken;
  };

  public query func http_request_streaming_callback(token : T.StreamingCallbackToken) : async StreamingCallbackHttpResponse {
    assets.http_request_streaming_callback(token);
  };
  public query func http_request(req : HttpRequest) : async HttpResponse {
    var url = Option.get(Text.split(req.url, #char '?').next(), "/");
    if (Text.endsWith(url, #text "status")) { url := req.url; };
    server.http_request({ method = req.method; url; headers = req.headers; body = req.body });
  };
  public func http_request_update(req : HttpRequest) : async HttpResponse {
    var url = Option.get(Text.split(req.url, #char '?').next(), "/");
    if (Text.endsWith(url, #text "status")) { url := req.url; };
    await* server.http_request_update({ method = req.method; url; headers = req.headers; body = req.body });
  };

  /**
    * upgrade hooks
    */
  system func preupgrade() {
    serializedEntries := server.entries();
  };

  system func postupgrade() {
    ignore server.cache.pruneAll();
  };

  public shared ({ caller }) func invalidate_cache() {
    assert(caller == creator);
    ignore server.cache.pruneAll();
  };
};
