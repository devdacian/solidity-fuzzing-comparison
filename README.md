# Solidity Fuzzing Challenge: Foundry vs Echidna vs Medusa #

A comparison of solidity fuzzing tools [Foundry](https://book.getfoundry.sh/), [Echidna](https://secure-contracts.com/program-analysis/echidna/index.html) & Medusa. This challenge set is not intended to be an academically rigorous benchmark but rather to present the experiences of an auditor "in the trenches"; the goal is finding the best performance "out of the box" with as little guidance & tweaking as possible.

## Setup ##

Ensure you are using a recent version of [Foundry](https://github.com/foundry-rs/foundry) which includes [PR6530](https://github.com/foundry-rs/foundry/pull/6530). 

Install a more [recent](https://github.com/crytic/echidna/actions/runs/7623460304) build of Echidna.

Compile the [latest](https://github.com/crytic/medusa) Medusa source code as it is experimental and under active development.

Configure [solc-select](https://github.com/crytic/solc-select) for Echidna & Medusa:

`solc-select install 0.8.23`\
`solc-select use 0.8.23`

To compile this project:

`forge build`

Every exercise has a `basic` some optionally an `advanced` fuzz configuration for Foundry, Echidna & Medusa. The `basic` configuration does not guide the fuzzer at all; it simply sets up the scenario and allows the fuzzer to do whatever it wants. The `advanced` configuration guides the fuzzer to the functions it should call and helps to eliminate invalid inputs which result in useless fuzz runs.

## Results ##

### Challenge #1 Naive Receiver: (Winner TIED ALL) ###

`echidna --config test/01-naive-receiver/NaiveReceiverBasicEchidna.yaml ./ --contract NaiveReceiverBasicEchidna`\
`forge test --match-contract NaiveReceiverBasicFoundry`

`echidna --config test/01-naive-receiver/NaiveReceiverAdvancedEchidna.yaml ./ --contract NaiveReceiverAdvancedEchidna`\
`forge test --match-contract NaiveReceiverAdvancedFoundry`

In `basic` configuration both Foundry & Echidna are able to break the simpler invariant but not the more valuable and difficult one. In `advanced` configuration both Foundry & Echidna can break both invariants. Both Foundry & Echidna reduce the exploit chain to a very concise & optimized transaction set and present this to the user in an easy to understand output. As a result they are tied and there is no clear winner. Medusa is unable to be used for this challenge as it requires a feature currently under development.

### Challenge #2 Unstoppable: (Winner MEDUSA) ###

`medusa --config test/02-unstoppable/UnstoppableBasicMedusa.json fuzz`\
`echidna --config test/02-unstoppable/UnstoppableBasicEchidna.yaml ./ --contract UnstoppableBasicEchidna`\
`forge test --match-contract UnstoppableBasicFoundry`

`forge test --match-contract UnstoppableAdvancedFoundry`

Echidna in `basic` configuration can frequently break both invariants while Foundry in `basic` configuration can sometimes break the easier invariant but never the harder one. Foundry using `advanced` configuration is able to break both invariants if given an extreme amount of targeting. Medusa in `basic` configuration can always break both invariants and achieves this much faster than Echidna, making Medusa the clear winner.

### Challenge #3 Proposal: (Winner TIED ALL) ###

Both Foundry & Echidna in `basic` mode are able to easily break the invariant, resulting in a tie. Medusa is unable to be used for this challenge as it requires a feature currently under development.

### Challenge #4 Voting NFT: (Winner TIED ALL) ###

In `basic` configuration Foundry, Echidna & Medusa are all able to break the easier invariant but not the more difficult one. All Fuzzers are able to provide the user with a minimal transaction set to generate the exploit. Hence they are tied, there is no clear winner. Please note that the fuzz solvers for this challenge are not able to be publicly released at this time.

### Challenge #5 Token Sale: (Winner MEDUSA) ###

In `basic` configuration Foundry & Echidna can only break the easier and more valuable invariant which leads to a Critical exploit but not the harder though less valuable invariant which leads to a High/Medium. However Medusa is able to almost immediately break both invariants in unguided `basic` mode, making Medusa the clear winner. Please note that the fuzz solvers for this challenge are not able to be publicly released at this time.

### Challenge #6 Rarely False: (Winner MEDUSA) ###

Both Echidna & Foundry are unable to break the assertion in this stateless fuzzing challenge, while Medusa is able to break it almost instantly.

### Challenge #7 Byte Battle: (Winner TIED FOUNDRY & ECHIDNA)

Foundry & Echidna are able to break the assertion in this stateless fuzzing challenge, but Medusa is unable to break it.

### Challenge #8 Omni Protocol: (Winner MEDUSA)

All 3 Fuzzers configured in `advanced` guided mode attempted to break 16 invariants on Beta Finance [Omni Protocol](https://github.com/beta-finance/Omni-Protocol). Medusa is typically able to break 2 invariants within 5 minutes (often much sooner on subsequent runs) though on the first run can take a bit longer. Echidna can sometimes break 1 invariant within 5 minutes and Foundry appears to never be able to break any invariants within 5 minutes. Hence Medusa is the clear winner. The fuzzers written for this challenge were [contributed](https://github.com/beta-finance/Omni-Protocol/pull/2) to Beta Finance.
