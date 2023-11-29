A comparion of solidity fuzzing tools like Foundry and Echidna. Using a more [recent](https://github.com/crytic/echidna/actions/runs/6747387119) build of Echidna which appears to work fine with Solidity 0.8.23.

To compile:

`forge build`

To configure [solc-select](https://github.com/crytic/solc-select) for Echidna:

`solc-select install 0.8.23`\
`solc-select use 0.8.23`

Every exercise has a "basic" and an "advanced" fuzz configuration for both Foundry and Echidna. The "basic" configuration does not guide the fuzzer at all; it simply sets up the scenario and allows the fuzzer to do whatever it wants. The "advanced" configuration guides the fuzzer to the functions it should call and helps to eliminate invalid inputs which result in useless fuzz runs.

Challenge #1 Naive Receiver: (Winner ECHIDNA)

`echidna --config test/01-naive-receiver/NaiveReceiverBasicEchidna.yaml ./ --contract NaiveReceiverBasicEchidna`\
`forge test --match-contract NaiveReceiverBasicFoundry`\\
`echidna --config test/01-naive-receiver/NaiveReceiverAdvancedEchidna.yaml ./ --contract NaiveReceiverAdvancedEchidna`\
`forge test --match-contract NaiveReceiverAdvancedFoundry`


In "basic" configuration both Foundry & Echidna are able to break the simpler invariant but not the more valuable and difficult one. In "Advanced" configuration both Foundry & Echidna can break both invariants, but Echidna reduces the exploit chain to a very concise & optimized transaction set and presents this to the user in an easy to understand output. As a result Echidna is the clear winner of this challenge.
