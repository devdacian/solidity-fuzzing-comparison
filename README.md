# Solidity Fuzzing Challenge: Foundry vs Echidna vs Medusa #

A comparison of solidity fuzzing tools Foundry, Echidna & Medusa.

## Setup ##

Install a more [recent](https://github.com/crytic/echidna/actions/runs/6747387119) build of Echidna which appears to work fine with Solidity 0.8.23.

Compile the [latest](https://github.com/crytic/medusa) Medusa source code as it is experimental and under active development.

Configure [solc-select](https://github.com/crytic/solc-select) for Echidna & Medusa:

`solc-select install 0.8.23`\
`solc-select use 0.8.23`

To compile this project:

`forge build`

Every exercise has a `basic` some optionally an `advanced` fuzz configuration for Foundry, Echidna & Medusa. The `basic` configuration does not guide the fuzzer at all; it simply sets up the scenario and allows the fuzzer to do whatever it wants. The `advanced` configuration guides the fuzzer to the functions it should call and helps to eliminate invalid inputs which result in useless fuzz runs.

## Results ##

### Challenge #1 Naive Receiver: (Winner ECHIDNA) ###

`echidna --config test/01-naive-receiver/NaiveReceiverBasicEchidna.yaml ./ --contract NaiveReceiverBasicEchidna`\
`forge test --match-contract NaiveReceiverBasicFoundry`

`echidna --config test/01-naive-receiver/NaiveReceiverAdvancedEchidna.yaml ./ --contract NaiveReceiverAdvancedEchidna`\
`forge test --match-contract NaiveReceiverAdvancedFoundry`

In `basic` configuration both Foundry & Echidna are able to break the simpler invariant but not the more valuable and difficult one. In `advanced` configuration both Foundry & Echidna can break both invariants, but Echidna reduces the exploit chain to a very concise & optimized transaction set and presents this to the user in an easy to understand output. As a result Echidna is the clear winner of this challenge.

### Challenge #2 Unstoppable: (Winner ECHIDNA) ###

`echidna --config test/02-unstoppable/UnstoppableBasicEchidna.yaml ./ --contract UnstoppableBasicEchidna`\
`forge test --match-contract UnstoppableBasicFoundry`\
`forge test --match-contract UnstoppableAdvancedFoundry`

Echidna in `basic` configuration can frequently break both invariants while Foundry in `basic` configuration can sometimes break the easier invariant but never the harder one. Foundry using `advanced` configuration is able to break both invariants if given an extreme amount of targeting. Hence Echidna is the clear winner again.

### Challenge #6 Rarely False: (Winner MEDUSA) ###

Both Echidna & Foundry are unable to break the assertion in this stateless fuzzing challenge, while Medusa is able to break it almost instantly.
