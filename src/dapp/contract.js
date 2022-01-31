import FlightSuretyApp from '../../build/contracts/FlightSuretyApp.json';
import FlightSuretyData from '../../build/contracts/FlightSuretyData.json';
import Config from './config.json';
import Web3 from 'web3';

export default class Contract {
    constructor(network, callback) {

        let config = Config[network];
        // this.web3 = new Web3(new Web3.providers.HttpProvider(config.url));
        this.web3 = new Web3(new Web3.providers.WebsocketProvider(config.url.replace('http', 'ws')));
        this.flightSuretyApp = new this.web3.eth.Contract(FlightSuretyApp.abi, config.appAddress);
        this.flightSuretyData = new this.web3.eth.Contract(FlightSuretyData.abi, config.dataAddress);
        this.initialize(callback);
        this.owner = null;
        this.airlines = [];
        this.passengers = [];
    }

    initialize(callback) {
        this.web3.eth.getAccounts((error, accts) => {
           
            this.owner = accts[0];

            let counter = 1;
            
            while(this.airlines.length < 5) {
                this.airlines.push(accts[counter++]);
            }

            while(this.passengers.length < 5) {
                this.passengers.push(accts[counter++]);
            }

            callback();
        });
    }

    isOperational(callback) {
       let self = this;
       self.flightSuretyApp.methods
            .isOperational()
            .call({ from: self.owner}, callback);
    }

    isAirlineRegistered(airlineAccount, callback) {
        let self = this;
        self.flightSuretyApp.methods
            .isAirlineRegistered(airlineAccount)
            .call({
                from: self.owner
            }, callback);
    }

    isAirlineFunded(airlineAccount, callback) {
        let self = this;
        self.flightSuretyData.methods
            .isAirlineFunded(airlineAccount)
            .call({
                from: self.owner
            }, callback);
    }

    registerAirline(airlineAccount, fromAccount, airlineName, callback) {
        let self = this;
        self.flightSuretyApp.methods
            .registerAirline(airlineAccount, airlineName)
            .send({
                from: fromAccount,
                gas: 4000000,
                gasPrice: 150000000000
            }, callback);
    }

    fund(airlineAccount, callback) {
        let self = this;
        self.flightSuretyApp.methods
            .fund()
            .send({
                from: airlineAccount,
                value: this.web3.utils.toWei("10", "ether"),
                gas: 4000000,
                gasPrice: 150000000000
            }, callback);
    }


    buy(passengerAccount, airlineAccount, airlineName, departureTime, callback) {
        let self = this;
        self.flightSuretyApp.methods
            .buyInsurance(airlineAccount, airlineName, departureTime)
            .send({
                from: passengerAccount,
                value: this.web3.utils.toWei("1", "ether"),
                gas: 4000000,
                gasPrice: 150000000000
            }, callback);

    }

    registerFlight(airlineAccount, airlineName, departureTime, callback) {
        let self = this
        self.flightSuretyApp.methods
            .registerFlight(airlineName, departureTime)
            .send({
                from: airlineAccount,
                gas: 4000000,
                gasPrice: 150000000000
            }, callback);
    }

    fetchFlightStatus(airlineAccount, airlineName, departureTime, callback) {
        let self = this;
        self.flightSuretyApp.methods
            .fetchFlightStatus(airlineAccount, airlineName, departureTime)
            .send({
                from: self.owner
            }, (error, result) => {
                callback(error, result);
            });
    }

    async accountBalance(account) {
        let balance = await this.web3.eth.getBalance(account);
        return await this.web3.utils.fromWei(balance);
    }

    pay(passengerAccount, callback) {
        let self = this;
        self.flightSuretyApp.methods
            .withdrawCredits()
            .send({
                from: passengerAccount
            }, callback);
    }

}

