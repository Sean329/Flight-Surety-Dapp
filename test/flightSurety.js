
var Test = require('../config/testConfig.js');
var BigNumber = require('bignumber.js');

const truffleAssert = require('truffle-assertions');

contract('Flight Surety Tests', async (accounts) => {

  var config;
  before('setup contract', async () => {
    config = await Test.Config(accounts);
    await config.flightSuretyData.authorizeCaller(config.flightSuretyApp.address);

  });

  /****************************************************************************************/
  /* Operations and Settings                                                              */
  /****************************************************************************************/

  it(`(multiparty) has correct initial isOperational() value`, async function () {

    // Get operating status
    let status = await config.flightSuretyData.isOperational.call();
    assert.equal(status, true, "Incorrect initial operating status value");

  });

  it(`(multiparty) has the first airline registered automatically with constructor`, async function () {
    // Get operating status
    let status = await config.flightSuretyData.isAirlineRegistered.call(config.firstAirline);
    assert.equal(status, true, "First airline not registered automatically");
  });

  it(`(multiparty) can block access to setOperatingStatus() for non-Contract Owner account`, async function () {

      // Ensure that access is denied for non-Contract Owner account
      let accessDenied = false;
      try 
      {
          await config.flightSuretyData.setOperatingStatus(false, { from: config.testAddresses[2] });
      }
      catch(e) {
          accessDenied = true;
      }
      assert.equal(accessDenied, true, "Access not restricted to Contract Owner");
            
  });

  it(`(multiparty) can allow access to setOperatingStatus() for Contract Owner account`, async function () {

      // Ensure that access is allowed for Contract Owner account
      let accessDenied = false;
      try 
      {
          await config.flightSuretyData.setOperatingStatus(false);
      }
      catch(e) {
          accessDenied = true;
      }
      assert.equal(accessDenied, false, "Access not restricted to Contract Owner");
      
  });

  it(`(multiparty) can block access to functions using requireIsOperational when operating status is false`, async function () {

      await config.flightSuretyData.setOperatingStatus(false);

      let reverted = false;
      try 
      {
          await config.flightSurety.setTestingMode(true);
      }
      catch(e) {
          reverted = true;
      }
      assert.equal(reverted, true, "Access not blocked for requireIsOperational");      

      // Set it back for other tests to work
      await config.flightSuretyData.setOperatingStatus(true);

  });

  it('(airline) cannot register an Airline using registerAirline() if it is not funded', async () => {
    
    // ARRANGE
    let newAirline = accounts[2];

    // ACT
    try {
        await config.flightSuretyApp.registerAirline(newAirline, {from: config.firstAirline});
    }
    catch(e) {

    }
    let result = await config.flightSuretyData.isAirlineRegistered.call(newAirline); 

    // ASSERT
    assert.equal(result, false, "Airline should not be able to register another airline if it hasn't provided funding");

  });
 
  it('(airline) can register an airline using registerAirline() if it is funded', async () => {
    // ARRANGE
    let newAirline = accounts[2];
    // ACT
    let minFund = await config.flightSuretyApp.MIN_FUND.call();
    await config.flightSuretyApp.fund({
        from: config.firstAirline,
        value: minFund
    });
    await config.flightSuretyApp.registerAirline(newAirline, "Airline 2", {
        from: config.firstAirline
    });
    let result = await config.flightSuretyData.isAirlineRegistered.call(newAirline);
    // ASSERT
    assert.equal(result, true, "Airline should be able to register another airline if it has provided funding");
});

it('(airline) can register only 4 airlines using registerAirline() without the need of consensus', async () => {
    // ARRANGE 
    // Note: firstAirline and secondAirline are already registered, and firstAirline has funded before
    let thirdAirline = accounts[3];
    let fourthAirline = accounts[4];
    let fifthAirline = accounts[5];
    // ACT
    
    await config.flightSuretyApp.registerAirline(thirdAirline, "Airline 3", {
        from: config.firstAirline
    });
    await config.flightSuretyApp.registerAirline(fourthAirline, "Airline 4", {
        from: config.firstAirline
    });
    await config.flightSuretyApp.registerAirline(fifthAirline, "Airline 5", {
        from: config.firstAirline
    });
    let resultIsAirline3 = await config.flightSuretyData.isAirlineRegistered.call(thirdAirline);
    let resultIsAirline4 = await config.flightSuretyData.isAirlineRegistered.call(fourthAirline);
    let resultIsAirline5 = await config.flightSuretyData.isAirlineRegistered.call(fifthAirline);
    // ASSERT
    assert.equal(resultIsAirline3, true, "First airline should be able to register the third airline because it has provided funding");
    assert.equal(resultIsAirline4, true, "First airline should be able to register the fourth airline because it has provided funding");
    assert.equal(resultIsAirline5, false, "First airline should not be able to register the fifth airline without consensus");
    assert.equal(await config.flightSuretyData.getAirlinesCount(), 4, {
        from: config.firstAirline
    });
});

it('(airline) can register another airline with at least 50% of consensus', async () => {
    // ARRANGE 
    // Note: four airlines are already registered, now let the 2nd airline also register the 5th airline to reach consensus
    let secondAirline = accounts[2];
    let fifthAirline = accounts[5];
    // ACT
    let minFund = await config.flightSuretyApp.MIN_FUND.call();
    await config.flightSuretyApp.fund({
        from: secondAirline,
        value: minFund
    });
    await config.flightSuretyApp.registerAirline(fifthAirline, "Airline 5", {
        from: secondAirline
    });
    let result = await config.flightSuretyData.isAirlineRegistered.call(fifthAirline);
    // ASSERT
    assert.equal(result, true, "Fifth airline should be registered by consensus");
    assert.equal(await config.flightSuretyData.getAirlinesCount(), 5);
});

it('(airline) cannot register another airline with less than 50% of consensus', async () => {
    // ARRANGE 
    // Note: five airlines are already registered, and 1st and 2nd airlines have funded
    let secondAirline = accounts[2];
    let sixthAirline = accounts[6];
    // ACT
    await config.flightSuretyApp.registerAirline(sixthAirline, "Airline 6", {
        from: config.firstAirline
    });
    await config.flightSuretyApp.registerAirline(sixthAirline, "Airline 6", {
        from: secondAirline
    });
    let result = await config.flightSuretyData.isAirlineRegistered.call(sixthAirline);
    // ASSERT
    assert.equal(result, false, "Sixth airline should not be registered without 50% consensus");
    assert.equal(await config.flightSuretyData.getAirlinesCount(), 5);
});

it('(passenger) can buy insurance for no more than 1 ether premium', async () => {
    // ARRANGE
    let passengerAccount = accounts[7];
    let airlineName = "UA0001";
    let departureTime = Math.trunc(((new Date()).getTime() + 10 * 3600) / 1000);
    let amountPaid = web3.utils.toWei("0.999", "ether");
    // ACT
    await config.flightSuretyApp.registerFlight(airlineName, departureTime, {
        from: config.firstAirline
    });
    let event = await config.flightSuretyApp.buyInsurance(config.firstAirline, airlineName, departureTime, {
        from: passengerAccount,
        value: amountPaid
    });
    // ASSERT
    truffleAssert.eventEmitted(event, 'InsurancePurchaseSuccess');
});

it('(passenger) cannot buy insurance for a flight paying more than 1 ether', async () => {
    // ARRANGE
    let passengerAccount = accounts[8];
    let airlineName = "UA0002";
    let departureTime = Math.trunc(((new Date()).getTime() + 10 * 3600) / 1000);
    let amountPaid = web3.utils.toWei("1.001", "ether");
    // ACT
    try {
        await config.flightSuretyApp.registerFlight(airlineName, departureTime, {
            from: config.firstAirline
        });
        await expectThrow(
            config.flightSuretyApp.buyInsurance(config.firstAirline, airlineName, departureTime, {
                from: passengerAccount,
                value: amountPaid
            })
        );
    } catch (e) {
        assert.fail(e.message);
    }
});

it('(passenger) assume flight is delayed due to airline reasons, passenger gets paid credit, and can withdraw all the historical credits owed to them into their own account', async () => {
    // ARRANGE
    let passengerAccount = accounts[9];
    let airlineName1 = "UA0003";
    let airlineName2 = "UA0004";
    let departureTime1 = Math.trunc(((new Date()).getTime() + 10 * 3600) / 1000);
    let departureTime2 = Math.trunc(((new Date()).getTime() + 11 * 3600) / 1000);
    let passengerAmountPaid1 = web3.utils.toWei("0.1", "ether");
    let passengerAmountPaid2 = web3.utils.toWei("0.1", "ether");
    let insuranceReturnPercentage = 150;
    let credit1 = passengerAmountPaid1* insuranceReturnPercentage / 100;
    let credit2 = passengerAmountPaid2* insuranceReturnPercentage / 100;
    let totalCredits = BigNumber(credit1 + credit2).toNumber();
    let balanceBefore;
    let balanceAfter;

    //Act
    let event1 = await config.flightSuretyApp.registerFlight(airlineName1, departureTime1, {
        from: config.firstAirline
    });
    let event2 =await config.flightSuretyApp.registerFlight(airlineName2, departureTime2, {
        from: config.firstAirline
    });

    //Assert
    truffleAssert.eventEmitted(event1, 'FlightRegistered');
    truffleAssert.eventEmitted(event2, 'FlightRegistered');

    //Act continue
    let event3 = await config.flightSuretyApp.buyInsurance(config.firstAirline, airlineName1, departureTime1, {
        from: passengerAccount,
        value: passengerAmountPaid1
    });
    let event4 = await config.flightSuretyApp.buyInsurance(config.firstAirline, airlineName2, departureTime2, {
        from: passengerAccount,
        value: passengerAmountPaid2
    });

    //Assert
    truffleAssert.eventEmitted(event3, 'InsurancePurchaseSuccess');
    truffleAssert.eventEmitted(event4, 'InsurancePurchaseSuccess');

    //Act continue
    let event5 = await config.flightSuretyData.creditInsurees(insuranceReturnPercentage, config.firstAirline, airlineName1, departureTime1, {
        from: config.owner
    });

    let event6 = await config.flightSuretyData.creditInsurees(insuranceReturnPercentage, config.firstAirline, airlineName2, departureTime2, {
        from: config.owner
    });

    //Assert
    truffleAssert.eventEmitted(event5, 'InsuranceCreditReceived');
    truffleAssert.eventEmitted(event6, 'InsuranceClaimPaid');
    truffleAssert.eventEmitted(event5, 'InsuranceCreditReceived');
    truffleAssert.eventEmitted(event6, 'InsuranceClaimPaid');

    //Act continue
    try {
        balanceBefore = BigNumber(await web3.eth.getBalance(passengerAccount)).toNumber();
        await config.flightSuretyApp.withdrawCredits({
            from: passengerAccount,
            gasPrice: 0
        });
        balanceAfter = BigNumber(await web3.eth.getBalance(passengerAccount)).toNumber();
    } catch (e) {
        assert.fail(e.message);
    }
    // ASSERT
    assert.equal(totalCredits, (balanceAfter - balanceBefore));
});


});

let expectThrow = async function (promise) {
    try {
        await promise;
    } catch (error) {
        assert.exists(error);
        return;
    }
    assert.fail("Expected an error but didn't see one");
}