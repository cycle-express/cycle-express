//////////////////////////////////////////////////////////////////////////////
//
// MIT License
// Copyright (c) 2023 Cycle.Express
//
//////////////////////////////////////////////////////////////////////////////

import "./style.scss";
import qrcode from "./qrcode.js";
import { encode, decode } from "cborg";
import { Principal } from "@dfinity/principal";
import { encodeIcrcAccount, decodeIcrcAccount } from "@dfinity/ledger-icrc";

const isSafari = /^((?!chrome|android).)*safari/i.test(navigator.userAgent);

function isPrincipalOpaque(principal) {
  const bytes = principal.toUint8Array();
  // 1 means Opaque id class (CanisterId)
  return bytes[bytes.length - 1] == 1;
}

///////////////////////////////////////////////////////////////////////////
// We use a session id to track each payment. A new id is created whenever
// the paymentLink is created/refreshed.
//
// A session id is a string of the format: <timestamp>-<8 digit nonce>
var sessionId = null;

function newPaymentLink(recipient) {
  let now = Math.floor(Date.now() / 1000);
  sessionId = now + "-" + Math.random().toString().substr(2, 8);
  return existingPaymentLink(recipient);
}

function existingPaymentLink(recipient) {
  if (!sessionId) {
    throw "NoExistingPaymentLink";
  }
  recipient = recipient.replace(".", "--");
  return `${process.env.PAYMENT_LINK_URL}?client_reference_id=${recipient}_${sessionId}`;
}

///////////////////////////////////////////////////////////////////////////
// MediaQueryList object
const useDark = window.matchMedia("(prefers-color-scheme: dark)");

// Toggles the "dark-mode" class
function toggleDarkMode(state) {
  document.documentElement.classList.toggle("dark-mode", state);
  localStorage.setItem("dark-mode", state);
  console.log("dark mode = ", state);
  if (state) {
    button_light.classList.remove("hidden");
    button_dark.classList.add("hidden");
  } else {
    button_light.classList.add("hidden");
    button_dark.classList.remove("hidden");
  }
}

///////////////////////////////////////////////////////////////////////////
// Check canister id validity
//
// echo 'module.exports={content:{sender:Buffer.from([4]),ingress_expiry:BigInt((new Date()).getTime() + 4 * 60000) * 1000000n,request_type:"read_state",paths:[]}};'|./node_modules/.bin/js2cbor|curl -H "Content-Type: application/cbor" -X POST --data-binary @- https://icp0.io/api/v2/canister/4r37y-mqaaa-aaaab-aadqq-cai/read_state --output -|./node_modules/.bin/cbor2json

const default_input_font_size = "1.2";
var max_input_length = 0;
function resize2fit(input) {
  let textLength = input.value.length;
  var font_size = input.style.getPropertyValue("--font-size");
  if (textLength == 0) {
    input.style.setProperty("--font-size", default_input_font_size + "em");
    return;
  }
  if (!font_size) {
    font_size = default_input_font_size;
  } else {
    font_size = font_size.substr(0, font_size.length - 2);
  }
  // console.log( isSafari, font_size, input.clientWidth, input.scrollWidth, input.scrollLeft);
  var clientWidth = input.clientWidth;
  var scrollWidth = input.scrollWidth;
  // Adjust clientWidth for Safari compatibility
  if (clientWidth > scrollWidth || isSafari) {
    clientWidth = Math.min(scrollWidth, clientWidth - 44);
  }
  let new_max_input_length =
    Math.floor(
      (textLength * clientWidth * font_size) /
        (scrollWidth * default_input_font_size),
    ) - 1;
  // console.log( clientWidth, scrollWidth, max_input_length, new_max_input_length, textLength);
  if (scrollWidth > clientWidth || font_size < default_input_font_size) {
    max_input_length = Math.max(max_input_length, new_max_input_length);
  } else {
    max_input_length = Math.max(max_input_length, textLength);
  }
  var new_font_size = (default_input_font_size * max_input_length) / textLength;
  if (new_font_size > default_input_font_size) {
    new_font_size = default_input_font_size;
  }
  if (new_font_size < 0.6) {
    new_font_size = 0.6;
  }
  // console.log("set font size", new_font_size);
  input.style.setProperty("--font-size", new_font_size + "em");
}

async function validateRecipient(recipient_id) {
  // First check if it is well formed
  if (recipient_id == "") {
    throw "Empty";
  }
  let account;
  try {
    account = decodeIcrcAccount(recipient_id);
  } catch (err) {
    throw "Malformed";
  }
  if (account.owner.isAnonymous()) {
    throw "Anonymous";
  }
  let url = `${API_HOST}/api/v2/canister/${recipient_id}/read_state`;
  if (!account.subaccount) {
    let req = {
      content: {
        sender: new Uint8Array([4]), // anonymous
        ingress_expiry: BigInt(new Date().getTime() + 4 * 60000) * 1000000n,
        request_type: "read_state",
        paths: [],
      },
    };
    try {
      let res = await fetch(url, {
        method: "POST",
        body: encode(req),
        headers: { "Content-type": "application/cbor" },
      });
      if (res.ok) {
        return;
      }
    } catch (err) {
      console.log(err);
      throw "Error";
    }
    throw "NotFound";
  }
  return account;
}

var recipientNeedsValidation = true;
// Setup a timer to check recipient id by delaying 1 second.
function setupCheckRecipient() {
  let timeout = null;
  let check = async () => {
    let recipientIsCanister = false;
    // Skip the check if inputbox is hidden
    if (input_recipient.getClientRects().length === 0) return;
    let msg = "&nbsp;";
    let recipient_id = input_recipient.value.trim();
    let account = null;
    recipientNeedsValidation = true;
    try {
      msg_recipient.innerHTML = "Checking...";
      account = await validateRecipient(recipient_id);
      if (recipient_id != input_recipient.value.trim()) {
        return;
      }
      recipientNeedsValidation = false;
      recipientIsCanister = true;
    } catch (err) {
      button_next.disabled = true;
      if (err == "Empty") {
        msg = "&nbsp;";
      } else if (err == "Malformed" || err == "Anonymous") {
        msg = "<i>Please input a valid canister or account id.</i>";
      } else if (err == "NotFound") {
        recipientIsCanister = false;
        recipientNeedsValidation = false;
      } else {
        console.log(err);
        msg = "<b>Internal error. Please contact support.</b>";
      }
    }
    if (!recipientNeedsValidation) {
      button_next.disabled =
        typeof cyclesPerUsd != "bigint" || recipientNeedsValidation;
      if (recipientIsCanister) {
        if (account && "subaccount" in account) {
          msg = "<s>Canister found. Buying TCycles for subaccount?</s>";
          canister_id.innerText = "ICRC Account";
        } else {
          msg = "<s>Canister found. Topping up cycle balance?</s>";
          canister_id.innerText = "canister id";
        }
      } else {
        msg = "<s>ICRC account identified. Buying TCycles?</s>";
        canister_id.innerText = "ICRC Account";
      }
    }
    if (typeof cyclesPerUsd == "string") {
      msg = cyclesPerUsd;
    }
    msg_recipient.innerHTML = msg;
  };
  return (evt) => {
    resize2fit(input_recipient);
    if (timeout) {
      clearTimeout(timeout);
    }
    timeout = setTimeout(check, 1000);
  };
}

///////////////////////////////////////////////////////////////////////////
// Setup UI
let div_loading, div_main, div_about;
let button_light, button_dark, button_camera;
let button_back, button_next, button_pay, button_again;
let input_recipient, msg_recipient, div_qrcode;
let card_input, card_payment, card_receipt;
let stepper_input, stepper_payment, stepper_receipt;
let stacker_payment, stacker_cycles, stacker_done;
let paid_amount, paid_total, paid_fee, paid_cycles;
let recipient_account, msg_receipt, exchange_rate;
let payment_topup, payment_recipient, payment_instruction;
let payment_recipient_error, payment_instruction_error;
let canister_id;

function showQR(recipient) {
  let typeNumber = 0;
  let errorCorrectionLevel = "L";
  let qr = qrcode(typeNumber, errorCorrectionLevel);
  let url = newPaymentLink(recipient);
  qr.addData(url);
  qr.make(1);
  div_qrcode.innerHTML = qr.createSvgTag({
    cellSize: 2,
    margin: 4,
    scalable: true,
  });
}

var cyclesPerUsd = "Fetching cycle price...";
async function fetchExchangeRate() {
  let tx = null;
  try {
    let res = await fetch("/status", {
      method: "GET",
    });
    if ("ok" in res && res.ok) {
      tx = await res.json();
      if (tx.normal && tx.normal.cyclesPerUsd) {
        cyclesPerUsd = BigInt(tx.normal.cyclesPerUsd);
        exchange_rate.innerHTML =
          "" + Number(cyclesPerUsd / 1000000000n) / 1000;
      }
    }
  } catch (err) {
    console.log(err);
  }
  if (!tx) {
    cyclesPerUsd = "<b>Error fetching cycle price. Pelase try again later.</b>";
  }
  input_recipient.oninput();
}

// Open a window for the Strip payment link.
// When we detect the payment is done,
// automatically close this window.
var paymentWindow = null;

// We use a polling method to check if the payment for a particular
// session is completed.
var pollIntervalId = null;

// Whether the session has any status
var sessionStatus = null;

async function pollSession() {
  if (!sessionId) return;
  if (!document.hasFocus() && (!paymentWindow || paymentWindow.closed)) return;
  let url = `/status?sessionId=${sessionId}`;
  try {
    let res = await fetch(url, {
      method: "GET",
    });
    if (res.ok) {
      let tx = await res.json();
      // console.log("status = ", tx);
      if (paymentWindow) {
        paymentWindow.close();
        paymentWindow = null;
      }
      if (sessionStatus == null) {
        sessionStatus = tx.status;
        history.replaceState({}, "", "#receipt");
        gotoReceipt(tx.account, tx.amount, tx.fee, tx.cycles);
      }
      if (tx.status == "pending") {
        setReceiptPending();
      } else if (tx.status == "done") {
        setReceiptDone();
        clearInterval(pollIntervalId);
      } else {
        setReceiptError(tx.status);
        clearInterval(pollIntervalId);
      }
      return;
    }
  } catch (err) {
    console.log(err);
  }
}

const openPaymentWindow = (recipient) => () => {
  paymentWindow = window.open(existingPaymentLink(recipient), "_blank");
  paymentWindow.focus();
};

function gotoInput() {
  stepper_input.classList.add("active");
  stepper_payment.classList.remove("active");
  stepper_receipt.classList.remove("active");
  stepper_input.classList.remove("completed");
  stepper_payment.classList.remove("completed");
  stepper_receipt.classList.remove("completed");
  card_input.classList.remove("hidden");
  card_payment.classList.add("hidden");
  card_receipt.classList.add("hidden");
  button_again.classList.add("hidden");
  if (pollIntervalId) {
    clearInterval(pollIntervalId);
  }
}

function gotoPayment(to) {
  stepper_input.classList.remove("active");
  stepper_payment.classList.add("active");
  stepper_receipt.classList.remove("active");
  stepper_input.classList.add("completed");
  stepper_payment.classList.remove("completed");
  stepper_receipt.classList.remove("completed");
  card_input.classList.add("hidden");
  card_payment.classList.remove("hidden");
  card_receipt.classList.add("hidden");
  button_again.classList.add("hidden");
  let recipient = to ? to : input_recipient.value.trim();
  payment_recipient.innerText = recipient;
  let account = null;
  try {
    account = decodeIcrcAccount(recipient);
  } catch (err) {
    console.log(err);
  }
  if (!account) {
    console.log("Failed to decode account!");
    payment_recipient.classList.add("error");
    payment_topup.classList.add("hidden");
    payment_recipient_error.classList.remove("hidden");
    payment_instruction.classList.add("hidden");
    payment_instruction_error.classList.remove("hidden");
    button_pay.classList.add("hidden");
  } else {
    console.log("Pay to account", account);
    if (isPrincipalOpaque(account.owner) && !("subaccount" in account)) {
      payment_topup.innerText = "To topup cycles for canister:";
    } else {
      payment_topup.innerText = "To buy TCycles for account:";
    }
    payment_topup.classList.remove("hidden");
    payment_recipient_error.classList.add("hidden");
    payment_instruction.classList.remove("hidden");
    payment_instruction_error.classList.add("hidden");
    button_pay.classList.remove("hidden");
    payment_recipient.classList.remove("error");
    // payto would be canonical
    let payto = encodeIcrcAccount(account);
    payment_recipient.innerText = payto;
    showQR(payto);
    pollIntervalId = setInterval(pollSession, 4000);
    sessionStatus = null;
    button_pay.onclick = openPaymentWindow(payto);
  }
}

function gotoReceipt(account_id, amount, fee, cycles) {
  let account = null;
  let unit = "T cycles";
  try {
    account = decodeIcrcAccount(account_id);
    if ("subaccount" in account || !isPrincipalOpaque(account.owner)) {
      unit = " TCycles";
    }
  } catch (err) {
    console.log(err);
  }
  stepper_input.classList.remove("active");
  stepper_payment.classList.remove("active");
  stepper_receipt.classList.add("active");
  stepper_input.classList.add("completed");
  stepper_payment.classList.add("completed");
  stepper_receipt.classList.remove("completed");
  card_input.classList.add("hidden");
  card_payment.classList.add("hidden");
  card_receipt.classList.remove("hidden");
  paid_amount.innerText = "" + Number(amount) / 100;
  paid_total.innerText = "" + (Number(amount) + Number(fee)) / 100;
  paid_fee.innerText = "" + Number(fee) / 100;
  paid_cycles.innerText =
    "" + Number(BigInt(cycles) / 1000000000n) / 1000 + unit;
  recipient_account.innerText = account_id;
  msg_receipt.innerHTML = "We are done!";
  button_again.classList.add("hidden");
}

function setReceiptPending() {
  stacker_payment.classList.remove("active");
  stacker_payment.classList.add("completed");
  stacker_cycles.classList.remove("completed");
  stacker_cycles.classList.add("active");
  stacker_cycles.children[0].children[0].classClist.remove("hidden");
  stacker_done.classList.remove("completed");
  stacker_done.classList.remove("active");
  button_again.classList.add("hidden");
}

function setReceiptDone() {
  stacker_payment.classList.remove("active");
  stacker_payment.classList.add("completed");
  stacker_cycles.classList.remove("active");
  stacker_cycles.classList.add("completed");
  stacker_cycles.children[0].children[0].classList.add("hidden");
  stacker_done.classList.remove("active");
  stacker_done.classList.add("completed");
  button_again.classList.remove("hidden");
  msg_receipt.innerHTML = "Deposited. We are done!";
  gotoCompleted();
}

function setReceiptError(message) {
  stacker_payment.classList.remove("active");
  stacker_payment.classList.add("completed");
  stacker_cycles.classList.remove("active");
  stacker_cycles.classList.add("completed");
  stacker_cycles.children[0].children[0].classList.add("hidden");
  stacker_done.classList.remove("active");
  stacker_done.classList.remove("completed");
  let session = sessionId
    ? "record your session id " + sessionId + " and "
    : "";
  msg_receipt.innerHTML =
    "<b>" + message + "</b>. Please " + session + "contact support.";
  button_again.classList.remove("hidden");
}

function gotoCompleted() {
  stepper_input.classList.remove("active");
  stepper_payment.classList.remove("active");
  stepper_receipt.classList.remove("active");
  stepper_input.classList.add("completed");
  stepper_payment.classList.add("completed");
  stepper_receipt.classList.add("completed");
}

// This is only triggered with browser back & forward button, but not
// history.pushState or history.replaceState.
async function route() {
  const queryString = window.location.search;
  const urlParams = new URLSearchParams(queryString);
  const to = urlParams.get("to");
  let hash = window.location.hash;
  // console.log("window.location.hash", hash);
  if (hash == "" || hash == null || hash == "#" || hash == "#input") {
    div_main.hidden = false;
    div_about.hidden = true;
    if (to) {
      gotoPayment(to);
    } else {
      gotoInput();
    }
  } else if (hash == "#payment") {
    if (typeof cyclesPerUsd != "bigint" || recipientNeedsValidation) {
      window.location.hash = "";
      history.replaceState({}, "", "");
    } else {
      gotoPayment();
    }
  } else if (hash == "#receipt") {
    if (!sessionStatus) {
      window.location.hash = "";
      history.replaceState({}, "", "");
    }
  } else if (hash == "#about" || hash == "#privacy" || hash == "#terms") {
    div_loading.hidden = false;
    div_loading.classList.remove("fade");
    history.replaceState({}, "", hash);
    let page = hash.substr(1) + ".html";
    try {
      let response = await fetch(page);
      let html = await response.text();
      div_main.hidden = true;
      div_about.hidden = false;
      div_about.innerHTML = `<section>${html}</section>`;
    } catch (err) {
      console.log(err);
    }
    div_loading.classList.add("fade");
    setTimeout(() => {
      window.scrollTo({ top: 0, behavior: "smooth" });
    }, 100);
    setTimeout(() => {
      div_loading.hidden = true;
    }, 500);
  }
}

function main() {
  div_loading = document.getElementById("loadingDiv");
  div_main = document.getElementById("div-main");
  div_about = document.getElementById("div-about");
  input_recipient = document.getElementById("input-recipient");
  button_light = document.getElementById("button-light");
  button_dark = document.getElementById("button-dark");
  button_camera = document.getElementById("button-camera");
  button_pay = document.getElementById("button-pay");
  button_next = document.getElementById("button-next");
  button_back = document.getElementById("button-back");
  button_again = document.getElementById("button-again");
  msg_recipient = document.getElementById("msg-recipient");
  card_input = document.getElementById("card-input");
  card_payment = document.getElementById("card-payment");
  card_receipt = document.getElementById("card-receipt");
  stepper_input = document.getElementById("stepper-input");
  stepper_payment = document.getElementById("stepper-payment");
  stepper_receipt = document.getElementById("stepper-receipt");
  div_qrcode = document.getElementById("qrcode");
  stacker_payment = document.getElementById("stacker-payment");
  stacker_cycles = document.getElementById("stacker-cycles");
  stacker_done = document.getElementById("stacker-done");
  paid_amount = document.getElementById("paid-amount");
  paid_total = document.getElementById("paid-total");
  paid_fee = document.getElementById("paid-fee");
  paid_cycles = document.getElementById("paid-cycles");
  recipient_account = document.getElementById("recipient-account");
  msg_receipt = document.getElementById("msg-receipt");
  exchange_rate = document.getElementById("exchange-rate");
  payment_topup = document.getElementById("payment-topup");
  payment_recipient = document.getElementById("payment-recipient");
  payment_instruction = document.getElementById("payment-instruction");
  payment_recipient_error = document.getElementById("payment-recipient-error");
  payment_instruction_error = document.getElementById(
    "payment-instruction-error",
  );
  canister_id = document.getElementById("canister-id");

  input_recipient.oninput = setupCheckRecipient();
  input_recipient.oninput();

  const queryString = window.location.search;
  const urlParams = new URLSearchParams(queryString);
  if (urlParams.get("to")) {
    button_back.innerText = "Cancel";
    button_again.innerText = "Done";
  }
  let back_or_close = () => {
    if (urlParams.get("to")) {
      window.close();
    } else {
      history.go(-1);
    }
  };
  button_back.onclick = back_or_close;
  button_again.onclick = back_or_close;
  button_next.onclick = () => {
    history.pushState({}, "", "#payment");
    gotoPayment();
  };
  button_next.disabled = true;

  // Initial setting
  toggleDarkMode(localStorage.getItem("dark-mode") == "true");

  // Listen for changes in the OS settings.
  // Note: the arrow function shorthand works only in modern browsers,
  // for older browsers define the function using the function keyword.
  useDark.addListener((evt) => toggleDarkMode(evt.matches));

  button_light.addEventListener("click", (e) => {
    e.preventDefault();
    toggleDarkMode(false);
  });
  button_dark.addEventListener("click", (e) => {
    e.preventDefault();
    toggleDarkMode(true);
  });

  fetchExchangeRate();
  // gotoPayment();
  // gotoReceipt("k54e2-ciaaa-aaaab-aaaka-cai", "70", "30", "750000000000");
  // setReceiptDone();
  window.addEventListener("hashchange", route);
  route();
  div_loading.classList.add("fade");
  setTimeout(() => {
    div_loading.hidden = true;
  }, 500);
}

window.onload = main;
