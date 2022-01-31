# FlightSurety

The FlightSurety application is a dApp that enables airlines to form a consortium to register flights, receive flight status updates from mock oracles, and make payouts to passengers who have purchased flight insurance. The dApp separates data storage concerns from application logic that make the app possible to upgrade without re-deploying the data contract.

## Project Specification

- Separation of Concerns
  - Smart Contract code is separated into multiple contracts for data persistence, app logic, and oracle code
  - Dapp client has been created and is used for triggering contract calls. Client can be launched with "npm run dapp" and is available at http://localhost:8000
  - A server app has been created for simulating oracle behavior. Server can be launched with "npm run server"
  - Operational status control is implemented
  - Contract functions "fail fast" by having a majority of "require()" calls at the beginning of function body

- Airlines
  - First airline is registered when contract is deployed.
  - Only an existing airline may register a new airline until there are at least four airlines registered
  - Registration of fifth and subsequent airlines requires multi-party consensus of 50% of registered airlines
  - Airline can be registered, but does not participate in contract until it submits funding of 10 ether

- Passengers
  - Passengers can choose from a fixed list of flight numbers and departure that are defined in the Dapp client
  - Passengers may pay up to 1 ether for purchasing flight insurance.
  - If flight is delayed due to airline fault, passenger receives credit of 1.5X the amount they paid
  - Passenger can withdraw any funds owed to them as a result of receiving credit for insurance payout
  - Insurance payouts are not sent directly to passenger’s wallet

- Oracles (Server App)
  - Oracle functionality is implemented in the server app.
  - Upon startup, 20+ oracles are registered and their assigned indexes are persisted in memory
  - Update flight status requests from client Dapp result in OracleRequest event emitted by Smart Contract that is captured by server (displays on console and handled in code)
  - Server will loop through all registered oracles, identify those oracles for which the OracleRequest event applies, and respond by calling into FlightSuretyApp contract with random status code of Unknown (0), On Time (10) or Late Airline (20), Late Weather (30), Late Technical (40), or Late Other (50)

## Install

This repository contains Smart Contract code in Solidity (using Truffle), tests (also using Truffle), dApp scaffolding (using HTML, CSS and JS) and server app scaffolding.

To install, download or clone the repo, then:

`npm install`
`truffle compile`

## Develop Client

To run truffle tests:

`truffle test ./test/flightSurety.js`
`truffle test ./test/oracles.js`

```
Contract: Flight Surety Tests
    ✓ (multiparty) has correct initial isOperational() value
    ✓ (multiparty) has the first airline registered automatically with constructor
    ✓ (multiparty) can block access to setOperatingStatus() for non-Contract Owner account (51ms)
    ✓ (multiparty) can allow access to setOperatingStatus() for Contract Owner account
    ✓ (multiparty) can block access to functions using requireIsOperational when operating status is false (78ms)
    ✓ (airline) cannot register an Airline using registerAirline() if it is not funded
    ✓ (airline) can register an airline using registerAirline() if it is funded (181ms)
    ✓ (airline) can register only 4 airlines using registerAirline() without the need of consensus (304ms)
    ✓ (airline) can register another airline with at least 50% of consensus (192ms)
    ✓ (airline) cannot register another airline with less than 50% of consensus (184ms)
    ✓ (passenger) can buy insurance for no more than 1 ether premium (124ms)
    ✓ (passenger) cannot buy insurance for a flight paying more than 1 ether (114ms)
    ✓ (passenger) assume flight is delayed due to airline reasons, passenger gets paid credit, and can withdraw all the historical credits owed to them into their own account (428ms)


  13 passing (2s)
```


To use the dapp:

`truffle migrate`
`npm run dapp`

To view dapp:

`http://localhost:8000`

![Screen Shot 2022-01-30 at 4 27 20 PM](https://user-images.githubusercontent.com/7294966/151724904-1fb88ddb-b15f-4b95-97e7-0bc617612065.png)


## Develop Server

`npm run server`
`truffle test ./test/oracles.js`

## Deploy

To build dapp for prod:
`npm run dapp:prod`

Deploy the contents of the ./dapp folder


## Resources

* [How does Ethereum work anyway?](https://medium.com/@preethikasireddy/how-does-ethereum-work-anyway-22d1df506369)
* [BIP39 Mnemonic Generator](https://iancoleman.io/bip39/)
* [Truffle Framework](http://truffleframework.com/)
* [Ganache Local Blockchain](http://truffleframework.com/ganache/)
* [Remix Solidity IDE](https://remix.ethereum.org/)
* [Solidity Language Reference](http://solidity.readthedocs.io/en/v0.4.24/)
* [Ethereum Blockchain Explorer](https://etherscan.io/)
* [Web3Js Reference](https://github.com/ethereum/wiki/wiki/JavaScript-API)
