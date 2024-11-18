// run from base folder:
// certoraRun test/02-unstoppable/certora.conf
using ReceiverUnstoppable as receiver;
using UnstoppableLender as lender;
using TestToken as token;

methods {
    // `dispatcher` summary to prevent HAVOC
    function _.receiveTokens(address tokenAddress, uint256 amount) external => DISPATCHER(true);

    // `envfree` definitions to call functions without explicit `env`
    function token.balanceOf(address) external returns (uint256) envfree;
}

// executeFlashLoan() -> f() -> executeFlashLoan() should always succeed
rule executeFlashLoan_mustNotRevert(uint256 loanAmount) {
    // enforce valid msg.sender:
    // 1) not a protocol contract
    // 2) equal to ReceiverUnstoppable::owner
    env e1;
    require e1.msg.sender != currentContract &&
            e1.msg.sender != lender &&
            e1.msg.sender != receiver &&
            e1.msg.sender != token &&
            e1.msg.sender == receiver.owner &&
            e1.msg.value  == 0; // not payable

    // enforce sufficient tokens exist to take out flash loan
    require loanAmount > 0 && loanAmount <= token.balanceOf(lender);

    // first executeFlashLoan() succeeds
    executeFlashLoan(e1, loanAmount);

    // perform another arbitrary successful transaction f()
    env e2;
    require e2.msg.sender != currentContract &&
            e2.msg.sender != lender &&
            e2.msg.sender != receiver &&
            e2.msg.sender != token;
    method f;
    calldataarg args;
    f(e2, args);

    // second executeFlashLoan() should always succeed; there should
    // exist no previous transaction f() that could make it fail
    executeFlashLoan@withrevert(e1, loanAmount);
    assert !lastReverted;
}