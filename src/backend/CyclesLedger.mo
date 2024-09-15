// This is a generated Motoko binding.
// Please use `import service "ic:canister_id"` instead to call canisters on the IC if possible.

module {
  public type Account = { owner : Principal; subaccount : ?Blob };
  public type Allowance = { allowance : Nat; expires_at : ?Nat64 };
  public type AllowanceArgs = { account : Account; spender : Account };
  public type ApproveArgs = {
    fee : ?Nat;
    memo : ?Blob;
    from_subaccount : ?Blob;
    created_at_time : ?Nat64;
    amount : Nat;
    expected_allowance : ?Nat;
    expires_at : ?Nat64;
    spender : Account;
  };
  public type ApproveError = {
    #GenericError : { message : Text; error_code : Nat };
    #TemporarilyUnavailable;
    #Duplicate : { duplicate_of : Nat };
    #BadFee : { expected_fee : Nat };
    #AllowanceChanged : { current_allowance : Nat };
    #CreatedInFuture : { ledger_time : Nat64 };
    #TooOld;
    #Expired : { ledger_time : Nat64 };
    #InsufficientFunds : { balance : Nat };
  };
  public type BlockIndex = Nat;
  public type CanisterSettings = {
    freezing_threshold : ?Nat;
    controllers : ?[Principal];
    reserved_cycles_limit : ?Nat;
    memory_allocation : ?Nat;
    compute_allocation : ?Nat;
  };
  public type ChangeIndexId = { #SetTo : Principal; #Unset };
  public type CmcCreateCanisterArgs = {
    subnet_selection : ?SubnetSelection;
    settings : ?CanisterSettings;
  };
  public type CreateCanisterArgs = {
    from_subaccount : ?Blob;
    created_at_time : ?Nat64;
    amount : Nat;
    creation_args : ?CmcCreateCanisterArgs;
  };
  public type CreateCanisterError = {
    #GenericError : { message : Text; error_code : Nat };
    #TemporarilyUnavailable;
    #Duplicate : { duplicate_of : Nat; canister_id : ?Principal };
    #CreatedInFuture : { ledger_time : Nat64 };
    #FailedToCreate : {
      error : Text;
      refund_block : ?BlockIndex;
      fee_block : ?BlockIndex;
    };
    #TooOld;
    #InsufficientFunds : { balance : Nat };
  };
  public type CreateCanisterFromArgs = {
    spender_subaccount : ?Blob;
    from : Account;
    created_at_time : ?Nat64;
    amount : Nat;
    creation_args : ?CmcCreateCanisterArgs;
  };
  public type CreateCanisterFromError = {
    #FailedToCreateFrom : {
      create_from_block : ?BlockIndex;
      rejection_code : RejectionCode;
      refund_block : ?BlockIndex;
      approval_refund_block : ?BlockIndex;
      rejection_reason : Text;
    };
    #GenericError : { message : Text; error_code : Nat };
    #TemporarilyUnavailable;
    #InsufficientAllowance : { allowance : Nat };
    #Duplicate : { duplicate_of : Nat; canister_id : ?Principal };
    #CreatedInFuture : { ledger_time : Nat64 };
    #TooOld;
    #InsufficientFunds : { balance : Nat };
  };
  public type CreateCanisterSuccess = {
    block_id : BlockIndex;
    canister_id : Principal;
  };
  public type DataCertificate = { certificate : Blob; hash_tree : Blob };
  public type DepositArgs = { to : Account; memo : ?Blob };
  public type DepositResult = { balance : Nat; block_index : BlockIndex };
  public type GetArchivesArgs = { from : ?Principal };
  public type GetArchivesResult = [
    { end : Nat; canister_id : Principal; start : Nat }
  ];
  public type GetBlocksArgs = [{ start : Nat; length : Nat }];
  public type GetBlocksResult = {
    log_length : Nat;
    blocks : [{ id : Nat; block : Value }];
    archived_blocks : [
      {
        args : GetBlocksArgs;
        callback : shared query GetBlocksArgs -> async GetBlocksResult;
      }
    ];
  };
  public type HttpRequest = {
    url : Text;
    method : Text;
    body : Blob;
    headers : [(Text, Text)];
  };
  public type HttpResponse = {
    body : Blob;
    headers : [(Text, Text)];
    status_code : Nat16;
  };
  public type InitArgs = {
    index_id : ?Principal;
    max_blocks_per_request : Nat64;
  };
  public type LedgerArgs = { #Upgrade : ?UpgradeArgs; #Init : InitArgs };
  public type MetadataValue = {
    #Int : Int;
    #Nat : Nat;
    #Blob : Blob;
    #Text : Text;
  };
  public type RejectionCode = {
    #NoError;
    #CanisterError;
    #SysTransient;
    #DestinationInvalid;
    #Unknown;
    #SysFatal;
    #CanisterReject;
  };
  public type SubnetFilter = { subnet_type : ?Text };
  public type SubnetSelection = {
    #Filter : SubnetFilter;
    #Subnet : { subnet : Principal };
  };
  public type SupportedBlockType = { url : Text; block_type : Text };
  public type SupportedStandard = { url : Text; name : Text };
  public type TransferArgs = {
    to : Account;
    fee : ?Nat;
    memo : ?Blob;
    from_subaccount : ?Blob;
    created_at_time : ?Nat64;
    amount : Nat;
  };
  public type TransferError = {
    #GenericError : { message : Text; error_code : Nat };
    #TemporarilyUnavailable;
    #BadBurn : { min_burn_amount : Nat };
    #Duplicate : { duplicate_of : Nat };
    #BadFee : { expected_fee : Nat };
    #CreatedInFuture : { ledger_time : Nat64 };
    #TooOld;
    #InsufficientFunds : { balance : Nat };
  };
  public type TransferFromArgs = {
    to : Account;
    fee : ?Nat;
    spender_subaccount : ?Blob;
    from : Account;
    memo : ?Blob;
    created_at_time : ?Nat64;
    amount : Nat;
  };
  public type TransferFromError = {
    #GenericError : { message : Text; error_code : Nat };
    #TemporarilyUnavailable;
    #InsufficientAllowance : { allowance : Nat };
    #BadBurn : { min_burn_amount : Nat };
    #Duplicate : { duplicate_of : Nat };
    #BadFee : { expected_fee : Nat };
    #CreatedInFuture : { ledger_time : Nat64 };
    #TooOld;
    #InsufficientFunds : { balance : Nat };
  };
  public type UpgradeArgs = {
    change_index_id : ?ChangeIndexId;
    max_blocks_per_request : ?Nat64;
  };
  public type Value = {
    #Int : Int;
    #Map : [(Text, Value)];
    #Nat : Nat;
    #Nat64 : Nat64;
    #Blob : Blob;
    #Text : Text;
    #Array : [Value];
  };
  public type WithdrawArgs = {
    to : Principal;
    from_subaccount : ?Blob;
    created_at_time : ?Nat64;
    amount : Nat;
  };
  public type WithdrawError = {
    #FailedToWithdraw : {
      rejection_code : RejectionCode;
      fee_block : ?Nat;
      rejection_reason : Text;
    };
    #GenericError : { message : Text; error_code : Nat };
    #TemporarilyUnavailable;
    #Duplicate : { duplicate_of : Nat };
    #BadFee : { expected_fee : Nat };
    #InvalidReceiver : { receiver : Principal };
    #CreatedInFuture : { ledger_time : Nat64 };
    #TooOld;
    #InsufficientFunds : { balance : Nat };
  };
  public type WithdrawFromArgs = {
    to : Principal;
    spender_subaccount : ?Blob;
    from : Account;
    created_at_time : ?Nat64;
    amount : Nat;
  };
  public type WithdrawFromError = {
    #GenericError : { message : Text; error_code : Nat };
    #TemporarilyUnavailable;
    #InsufficientAllowance : { allowance : Nat };
    #Duplicate : { duplicate_of : BlockIndex };
    #InvalidReceiver : { receiver : Principal };
    #CreatedInFuture : { ledger_time : Nat64 };
    #TooOld;
    #FailedToWithdrawFrom : {
      withdraw_from_block : ?Nat;
      rejection_code : RejectionCode;
      refund_block : ?Nat;
      approval_refund_block : ?Nat;
      rejection_reason : Text;
    };
    #InsufficientFunds : { balance : Nat };
  };
  public type Self = actor {
    create_canister : shared CreateCanisterArgs -> async {
        #Ok : CreateCanisterSuccess;
        #Err : CreateCanisterError;
      };
    create_canister_from : shared CreateCanisterFromArgs -> async {
        #Ok : CreateCanisterSuccess;
        #Err : CreateCanisterFromError;
      };
    deposit : shared DepositArgs -> async DepositResult;
    http_request : shared query HttpRequest -> async HttpResponse;
    icrc1_balance_of : shared query Account -> async Nat;
    icrc1_decimals : shared query () -> async Nat8;
    icrc1_fee : shared query () -> async Nat;
    icrc1_metadata : shared query () -> async [(Text, MetadataValue)];
    icrc1_minting_account : shared query () -> async ?Account;
    icrc1_name : shared query () -> async Text;
    icrc1_supported_standards : shared query () -> async [SupportedStandard];
    icrc1_symbol : shared query () -> async Text;
    icrc1_total_supply : shared query () -> async Nat;
    icrc1_transfer : shared TransferArgs -> async {
        #Ok : BlockIndex;
        #Err : TransferError;
      };
    icrc2_allowance : shared query AllowanceArgs -> async Allowance;
    icrc2_approve : shared ApproveArgs -> async {
        #Ok : Nat;
        #Err : ApproveError;
      };
    icrc2_transfer_from : shared TransferFromArgs -> async {
        #Ok : Nat;
        #Err : TransferFromError;
      };
    icrc3_get_archives : shared query GetArchivesArgs -> async GetArchivesResult;
    icrc3_get_blocks : shared query GetBlocksArgs -> async GetBlocksResult;
    icrc3_get_tip_certificate : shared query () -> async ?DataCertificate;
    icrc3_supported_block_types : shared query () -> async [SupportedBlockType];
    withdraw : shared WithdrawArgs -> async {
        #Ok : BlockIndex;
        #Err : WithdrawError;
      };
    withdraw_from : shared WithdrawFromArgs -> async {
        #Ok : BlockIndex;
        #Err : WithdrawFromError;
      };
  }
}
