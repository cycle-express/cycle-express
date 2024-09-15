//////////////////////////////////////////////////////////////////////////////
//
// MIT License
// Copyright (c) 2023 Cycle.Express
//
//////////////////////////////////////////////////////////////////////////////

import Array "mo:base/Array";
import Blob "mo:base/Blob";
import Debug "mo:base/Debug";
import Error "mo:base/Error";
import Int "mo:base/Int";
import Iter "mo:base/Iter";
import Nat "mo:base/Nat";
import Nat8 "mo:base/Nat8";
import Option "mo:base/Option";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Text "mo:base/Text";
import Time "mo:base/Time";

import HttpTypes "mo:http-parser/Types";
import Hex "mo:encoding/Hex";
import JSON "mo:json/JSON";
import Hmac "./Hmac";

module Util {
  type JSON = JSON.JSON;
  type Price = Nat;
  type Error = Error.Error;

  public type Status = {
     #Normal: { cyclesPerUsd: Price };
     #Halted;
     #SuspendedUntil: Time.Time;
     #InsufficientBalance;
     #Paid;
     #Error: Text;
  };

  // Convert Status to JSON text.
  public func statusText(status: Status) : Text {
     switch status {
       case (#Normal({ cyclesPerUsd })) {
         "{ \"normal\": { \"cyclesPerUsd\": \"" # Nat.toText(cyclesPerUsd) # "\" } }"
       };
       case (#Halted) { "{ \"halted\": true }" };
       case (#SuspendedUntil(t)) {
         "{ \"suspendedUntil\": " # Int.toText(t / 1_0000_0000) # " }"
       };
       case (#InsufficientBalance) { "{ \"insufficientBalance\": true }" };
       case (#Paid) { "{ \"paid\": true }" };
       case (#Error(err)) {
         "{ \"error\": \"" # err # "\" }"
       }
     }
  };

  public func headersText(headers: HttpTypes.Headers): Text {
    let rows = Array.map<(Text, Text), Text>(headers.original, 
                   func((key, val)) { "(" # key # ", " # val # ")" });
    "[" # Text.join(",", rows.vals()) # "]"
  };

  public type PaymentStatus = Text;

  public type ClientId = {
    canisterId: Principal;
    timestamp: Nat; // Unix timestamp in seconds
    nonce: Text;
    tag: ?Text; // "ledger", "tipjar", or null
  };

  public func parseSessionId(sessionId: Text) : ?(Nat, Text) {
    do ? {
      let iter = Text.split(sessionId, #char('-'));
      let time = iter.next() !;
      let timestamp = Nat.fromText(time) !;
      let nonce = iter.next() !;
      (timestamp, nonce) 
    }
  };

  public func parseClientId(clientId: Text) : ?ClientId  {
    do ? {
      let iter = Text.split(clientId, #char('_'));
      let canisterId = iter.next() !;
      let sessionId = iter.next() !;
      let tag = iter.next();
      let (timestamp, nonce) = parseSessionId(sessionId) !;
      { canisterId = Principal.fromText(canisterId);
        timestamp = timestamp;
        nonce = nonce;
        tag = tag;
      }
    }
  };

  func fieldOf(json: ?JSON, name: Text) : ?JSON {
     switch json {
       case (?(#Object(fields))) {
         for ((key, value) in Array.vals(fields)) {
           if (key == name) {
             return ?value;
           }
         }
       };
       case _ {}
     };
     null
  };

  func extractClientId(json: JSON) : ?Text {
    switch (fieldOf(fieldOf(fieldOf(?json, "data"), "object"), "client_reference_id")) {
      case (?(#String(clientId))) { return ?clientId };
      case _ {};
    };
    null
  };

  func extractPaymentStatus(json: JSON) : ?PaymentStatus {
    switch (fieldOf(fieldOf(fieldOf(?json, "data"), "object"), "payment_status")) {
      case (?(#String(status))) { return ?status };
      case _ {};
    };
    null
  };

  func extractAmount(json: JSON) : ?Nat {
    switch (fieldOf(fieldOf(fieldOf(?json, "data"), "object"), "amount_subtotal")) {
      case (?(#Number(amount))) { return ?Int.abs(amount) };
      case _ {};
    };
    null
  };


  public func parseLog(log: Blob) : ?(ClientId, PaymentStatus, Nat) {
    do ? {
      let txt = Text.decodeUtf8(log) !;
      let trimmed = Text.trimStart(txt, #predicate(func (c) { c != ' ' }));
      let json_txt = Text.stripStart(trimmed, #text(" checkout: body = ")) !;
      let json = JSON.parse(json_txt) !;
      let client = extractClientId(json) !;
      let status = extractPaymentStatus(json) !;
      let amount = extractAmount(json) !;
      let clientId = parseClientId(client) !; 
      (clientId, status, amount)
    }
  };

  public func showError(err: Error) : Text {
    debug_show({ error = Error.code(err); message = Error.message(err); })
  };

  public func parseStripeSignature(input: Text) : ?(Text, Text) {
    do ? {
      let parts = Text.split(input, #char ',');
      let part1 = parts.next() !;
      let timestamp = Text.stripStart(part1, #text "t=") !;
      for (part in parts) {
        switch (Text.stripStart(Text.trim(part, #char ' '),  #text "v1=")) {
          case (?signature) { return ?(timestamp, signature) };
          case null {}
        }
      };
      null !;
    }
  };

  public func computeHMACSignature(payload: Blob, secret: Blob) : [Nat8] {
    let hmac = Hmac.sha256(Blob.toArray(secret));
    hmac.write(Blob.toArray(payload));
    let digest = hmac.sum();
    digest
  };

  public func verifyStripeSignature(timestamp: Text, signature: Text, secret: Text, body: Text) : Bool {
      let result = do ? {
        let sig_ = Result.toOption(Hex.decode(signature)) !;
        let payload = timestamp # "." # body;
        let secretBlob = Text.encodeUtf8(secret);
        let payloadBlob = Text.encodeUtf8(payload);
        let sig = computeHMACSignature(payloadBlob, secretBlob);
        Array.equal(sig_, sig, Nat8.equal)
      };
      Option.get(result, false)
  };

  // Calculate cycle price
  public func calculatePrice(
      incoming: Iter.Iter<(Nat, Nat)>, 
      outgoing: Iter.Iter<(Nat, Nat)>,
      margin: Nat) : ?Nat {
    var cycles : Int = 0; // total cycles remaining
    var costs : Int = 0; // total costs for the remaining cycles
    label LOOP loop {
      switch (incoming.next(), outgoing.next()) {
        case (?(bought, cost), ?(spent, income)) {
          cycles := cycles + bought - spent;
          // each cost is inflated to include margin, because the
          // income has included the margin already.
          costs := costs + cost * (100 + margin) / 100 - income; 
        };
        case _ { break LOOP }
      }
    };
    if (cycles <= 0 or costs <= 0) null
    else ?Int.abs(cycles / costs * 100)
  };
}
