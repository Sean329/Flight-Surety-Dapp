pragma solidity ^0.4.25;

import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";

contract FlightSuretyData {
    using SafeMath for uint256;

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    address private contractOwner;                                      // Account used to deploy contract
    bool private operational = true;                                    // Blocks all state changes throughout the contract if false

    mapping(address => bool) private authorizedCallers; //Authorized addresses which can access this contract

    struct Airline {
        address airlineAccount; 
        string airlineName; 
        bool isRegistered; 
        bool isFunded; 
        uint256 underwrittenAmount; 
    }

    mapping(address => Airline) private airlines;
    uint256 internal registeredAirlineCount;

    struct Insurance {
        address[] passengerAccount; 
        mapping(address => uint256) amount; 
        address airlineAccount; 
        string airlineName; 
        uint256 departureTime;
        bool isPaidClaims;
    }
    mapping(bytes32 => Insurance) private insurances;
    mapping(address => uint256) private passengerTotalCredits;



    /********************************************************************************************/
    /*                                       EVENT DEFINITIONS                                  */
    /********************************************************************************************/

    event AirlineRegistered(
        address indexed airlineAccount, 
        string airlineName
    );


    event AirlineFunded(
        address indexed airlineAccount, 
        uint256 amount 
    );

    event InsurancePurchased(
        address indexed passengerAccount, 
        uint256 amount, 
        address airlineAccount, 
        string airlineName, 
        uint256 departureTime 
    );

    event InsuranceClaimPaid(
        address indexed airlineAccount, 
        string indexed airlineName,
        uint256 indexed departureTime 
    );

    event InsuranceCreditReceived(
        address indexed passengerAccount,
        uint256 amount 
    );

    event InsurancePaymentWithdrawn(
        address indexed passengerAccount, 
        uint256 amount 
    );

    event PlainEtherReceived (
        address indexed account, 
        uint256 amount,
        string info
    );

    /**
    * @dev Constructor
    *      The deploying account becomes contractOwner
    */
    constructor(   address _firstAirlineAccount,
                    string _firstAirlineName
                ) 
                                public 
    {
        contractOwner = msg.sender;
        authorizedCallers[contractOwner] = true; //Authorize the owner at the initial instantiation 
        registeredAirlineCount = 1;  //Add the 1st airline at the initial instantiation
        airlines[_firstAirlineAccount] = Airline(_firstAirlineAccount, _firstAirlineName, true, false, 0);

    }

    /********************************************************************************************/
    /*                                       FUNCTION MODIFIERS                                 */
    /********************************************************************************************/

    // Modifiers help avoid duplication of code. They are typically used to validate something
    // before a function is allowed to be executed.

    /**
    * @dev Modifier that requires the "operational" boolean variable to be "true"
    *      This is used on all state changing functions to pause the contract in 
    *      the event there is an issue that needs to be fixed
    */
    modifier requireIsOperational() 
    {
        require(operational, "Contract is currently not operational");
        _;  // All modifiers require an "_" which indicates where the function body will be added
    }

    /**
    * @dev Modifier that requires the "ContractOwner" account to be the function caller
    */
    modifier requireContractOwner()
    {
        require(msg.sender == contractOwner, "Caller is not contract owner");
        _;
    }

    modifier requireIsCallerAuthorized()
    {
        require(authorizedCallers[msg.sender] == true, "Caller is not authorized");
        _;
    }

    modifier requireIsAirlineRegistered() {
        require(airlines[msg.sender].isRegistered == true, "Caller is not registered");
        _;
    }

    modifier requireIsAirlineFunded(address _airlineAccount) {
        require(airlines[_airlineAccount].isFunded == true, "Airline is not funded");
        _;
    }

    modifier requireZeroMsgData() {
        require(msg.data.length == 0, "Message data is NOT needed");
        _;
    }
    /********************************************************************************************/
    /*                                       UTILITY FUNCTIONS                                  */
    /********************************************************************************************/

    function authorizeCaller(address _address) external requireIsOperational requireContractOwner {
        authorizedCallers[_address] = true;
    }

    function deauthorizeCaller(address _address) external requireIsOperational requireContractOwner {
        delete authorizedCallers[_address];
    }


    /**
    * @dev Get operating status of contract
    *
    * @return A bool that is the current operating status
    */      
    function isOperational() 
                            external 
                            view 
                            returns(bool) 
    {
        return operational;
    }


    /**
    * @dev Sets contract operations on/off
    *
    * When operational mode is disabled, all write transactions except for this one will fail
    */    
    function setOperatingStatus(
                                bool mode
                            ) 
                            external
                            requireContractOwner 
    {
        operational = mode;
    }

    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/

   /**
    * @dev Add an airline to the registration queue
    *      Can only be called from FlightSuretyApp contract
    *
    */   
    function registerAirline(   address _airlineAccount,
                                string _airlineName
                            )
                            external 
                            requireIsCallerAuthorized
                            requireIsOperational
    {
        registeredAirlineCount = registeredAirlineCount.add(1);
        airlines[_airlineAccount] = Airline(_airlineAccount, _airlineName, true, false, 0);
        emit AirlineRegistered(_airlineAccount, _airlineName); 

    }


   /**
    * @dev Buy insurance for a flight
    *
    */   
    function buy(address _passengerAccount,
                    address _airlineAccount,
                    string _airlineName,
                    uint256 _departureTime    
                )
                            external
                            payable
                            requireIsOperational 
                            requireIsCallerAuthorized
    {
        bytes32 flightKey = getFlightKey(_airlineAccount, _airlineName, _departureTime);
        airlines[_airlineAccount].underwrittenAmount = airlines[_airlineAccount].underwrittenAmount.add(msg.value);
        insurances[flightKey].passengerAccount.push(_passengerAccount);
        insurances[flightKey].amount[_passengerAccount] = msg.value;
        insurances[flightKey].airlineAccount = _airlineAccount;
        insurances[flightKey].airlineName = _airlineName;
        insurances[flightKey].departureTime = _departureTime;
        insurances[flightKey].isPaidClaims = false;
        emit InsurancePurchased(
            _passengerAccount,
            msg.value,
            _airlineAccount,
            _airlineName,
            _departureTime
        );
    }

    /**
     *  @dev Credits payouts to insurees
    */
    function creditInsurees(uint256 _percentagePay,
                            address _airlineAccount,
                            string  _airlineName,
                            uint256 _departureTime
                            )
                                external 
                                requireIsOperational 
                                requireIsCallerAuthorized

    {
        bytes32 flightKey = getFlightKey(_airlineAccount, _airlineName, _departureTime);
        require(!insurances[flightKey].isPaidClaims, "Claims haven been paid already");

        for(uint i = 0; i < insurances[flightKey].passengerAccount.length; i++) {
            address passengerAddress = insurances[flightKey].passengerAccount[i];
            uint256 purchasedAmount = insurances[flightKey].amount[passengerAddress];
            uint256 payoutAmount = purchasedAmount.mul(_percentagePay).div(100); //150% pay out
            passengerTotalCredits[passengerAddress] = passengerTotalCredits[passengerAddress].add(payoutAmount);
            airlines[_airlineAccount].underwrittenAmount = airlines[_airlineAccount].underwrittenAmount.sub(payoutAmount);
            emit InsuranceCreditReceived(passengerAddress, payoutAmount);
        }

        insurances[flightKey].isPaidClaims = true;
        emit InsuranceClaimPaid(_airlineAccount, _airlineName, _departureTime);
    }
    

    /**
     *  @dev Transfers eligible payout funds to insuree
     *
    */
    function pay(address _passengerAccount
                )
                            external
                            requireIsOperational 
                            requireIsCallerAuthorized
    {
        require(passengerTotalCredits[_passengerAccount] > 0, "No money to withdraw");
        uint256 payableAmount = passengerTotalCredits[_passengerAccount];
        passengerTotalCredits[_passengerAccount] = 0;
        _passengerAccount.transfer(payableAmount);
        emit InsurancePaymentWithdrawn(_passengerAccount, payableAmount);
    }

   /**
    * @dev Initial funding for the insurance. Unless there are too many delayed flights
    *      resulting in insurance payouts, the contract should be self-sustaining
    *
    */   
    function fund(   address _airlineAccount
                )
                            external
                            payable
                            requireIsOperational 
                            requireIsCallerAuthorized
    {
        airlines[_airlineAccount].underwrittenAmount = airlines[_airlineAccount].underwrittenAmount.add(msg.value);
        airlines[_airlineAccount].isFunded = true;
        emit AirlineFunded(_airlineAccount, msg.value);
    }

    function getFlightKey
                        (
                            address airline,
                            string memory flight,
                            uint256 timestamp
                        )
                        pure
                        internal
                        returns(bytes32) 
    {
        return keccak256(abi.encodePacked(airline, flight, timestamp));
    }


    //Define a series of getter functions
    function isAirlineRegistered(
        address _airlineAccount
    )
    external
    view
    requireIsOperational 
    requireIsCallerAuthorized
    returns(bool) {
        return airlines[_airlineAccount].isRegistered;
    }

    function isAirlineFunded(
        address _airlineAccount
    )
    external
    view
    requireIsOperational 
    requireIsCallerAuthorized
    returns(bool) {
        return airlines[_airlineAccount].isFunded;
    }

    function getFund(
        address _airlineAccount
    ) 
    external
    view
    requireIsOperational
    requireIsCallerAuthorized
    returns(uint256) {
        return airlines[_airlineAccount].underwrittenAmount;
    }

    function getAirlinesCount()
    external
    view
    requireIsOperational
    requireIsCallerAuthorized
    returns(uint256) {
        return registeredAirlineCount;
    }

    function getPassengerTotalCredits(address _passengerAccount
    ) external
    view
    requireIsOperational
    requireIsCallerAuthorized
    returns(uint256) {
        return passengerTotalCredits[_passengerAccount];
    }

    /**
    * @dev Fallback function for funding smart contract.
    *
    */
    // This function can receive plain ETH transfers/donations not via any function call
    // and it requires zero Msgdata to avoid being exploited by malicious contracts
    function() 
    external 
    payable 
    requireZeroMsgData

    {
        emit PlainEtherReceived(msg.sender, msg.value, "Received plain Ether");
    }


}