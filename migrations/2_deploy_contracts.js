const FlightSuretyApp = artifacts.require("FlightSuretyApp");
const FlightSuretyData = artifacts.require("FlightSuretyData");
const fs = require('fs');

module.exports = function (deployer) {
    
    //Inputs of the contracts' initiation are updated here
    //this is the accounts[1] generated with the specified seed phrase
    let firstAirline = '0xf17f52151EbEF6C7334FAD080c5704D77216b732'; 
    let firstAirlineName = 'Airline 1';

    deployer.deploy(FlightSuretyData, firstAirline, firstAirlineName).then(() => {
        return FlightSuretyData.deployed();
    }).then((dataContractInstance) => {
        return deployer.deploy(FlightSuretyApp, FlightSuretyData.address).then(() => {
            
            //Authorize the app contract address in here
            dataContractInstance.authorizeCaller(FlightSuretyApp.address);
            
            let config = {
                localhost: {
                    url: 'http://127.0.0.1:8545',
                    dataAddress: FlightSuretyData.address,
                    appAddress: FlightSuretyApp.address
                }
            }
            fs.writeFileSync(__dirname + '/../src/dapp/config.json', JSON.stringify(config, null, '\t'), 'utf-8');
            fs.writeFileSync(__dirname + '/../src/server/config.json', JSON.stringify(config, null, '\t'), 'utf-8');
        });
    });
}