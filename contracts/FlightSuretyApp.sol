pragma solidity ^0.4.25;

// It's important to avoid vulnerabilities due to numeric overflow bugs
// OpenZeppelin's SafeMath library, when used correctly, protects agains such bugs
// More info: https://www.nccgroup.trust/us/about-us/newsroom-and-events/blog/2018/november/smart-contract-insecurity-bad-arithmetic/

import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";

/************************************************** */
/* FlightSurety Smart Contract                      */
/************************************************** */
contract FlightSuretyApp {
    using SafeMath for uint256; // Allow SafeMath functions to be called for all uint256 types (similar to "prototype" in Javascript)

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    // Flight status codees
    uint8 private constant STATUS_CODE_UNKNOWN = 0;
    uint8 private constant STATUS_CODE_ON_TIME = 10;
    uint8 private constant STATUS_CODE_LATE_AIRLINE = 20;
    uint8 private constant STATUS_CODE_LATE_WEATHER = 30;
    uint8 private constant STATUS_CODE_LATE_TECHNICAL = 40;
    uint8 private constant STATUS_CODE_LATE_OTHER = 50;

    uint256 private constant AIRLINES_THRESHOLD = 4;
    uint256 public constant MAX_PREMIUM = 1 ether;
    uint256 public constant PERCENTAGE_PAY = 150;
    uint256 public constant MIN_FUND = 10 ether;

    address private contractOwner;          // Account used to deploy contract

    struct Flight {
        bool isRegistered;
        uint8 statusCode;
        uint256 updatedTimestamp;        
        address airline;
    }
    mapping(bytes32 => Flight) private flights;

    FlightSuretyData internal flightSuretyData;

    struct Voting {
        address[] voters;
        mapping(address => bool) hasVoted;
        uint256 gotVotes;
    }

    mapping(address => Voting) private votes;

    event FlightRegistered(
        address airlineAccount,
        string airlineName,
        uint256 departureTime
    );

    event RegisterAirlineSuccess(
        bool success,
        uint256 gotVotes
    );

    event InsurancePurchaseSuccess(
        address indexed passengerAccount,
        uint256 premium,
        address airlineAccount,
        string airlineName,
        uint256 departureTime
    );
 
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
         // Modify to call data contract's status
        require(flightSuretyData.isOperational(), "Contract is currently not operational");  
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

    modifier requireIsAirlineRegistered() {
        require(flightSuretyData.isAirlineRegistered(msg.sender), "Caller is not registered airline");
        _;
    }

    modifier requireIsAirlineFunded() {
        require(flightSuretyData.isAirlineFunded(msg.sender), "Caller airline is not funded");
        _;
    }

    modifier requireIsFutureFlight(uint256 _departureTime) {
        require(_departureTime > now, "Flight is not in future");
        _;
    }

    modifier requireIsMinFunded() {
        require(msg.value >= MIN_FUND, "Not enough fund");
        _;
    }
    /********************************************************************************************/
    /*                                       CONSTRUCTOR                                        */
    /********************************************************************************************/

    /**
    * @dev Contract constructor
    *
    */
    constructor( address _dataContract
               ) 
                                public 
    {
        contractOwner = msg.sender;
        flightSuretyData = FlightSuretyData(_dataContract);
    }

    /********************************************************************************************/
    /*                                       UTILITY FUNCTIONS                                  */
    /********************************************************************************************/

    function isOperational() 
                            public 
                            view 
                            returns(bool) 
    {
        return flightSuretyData.isOperational();  // Modify to call data contract's status
    }

    function isAirlineRegistered(address _airlineAccount) public view returns(bool) {
        return flightSuretyData.isAirlineRegistered(_airlineAccount);
    }

    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/

  
   /**
    * @dev Add an airline to the registration queue
    *
    */   
    function addVote(
        address _airlineAccount,
        address _voterAirlineAccount) internal {
        //To avoid double counting
        if (votes[_airlineAccount].hasVoted[_voterAirlineAccount] == false) {
            votes[_airlineAccount].hasVoted[_voterAirlineAccount] = true;
            votes[_airlineAccount].voters.push(_voterAirlineAccount);
            votes[_airlineAccount].gotVotes = votes[_airlineAccount].gotVotes.add(1);
        }
    }

    function registerAirline( address _airlineAccount,
                                string _airlineName  
                            )
                            external
                            requireIsOperational 
                            requireIsAirlineRegistered 
                            requireIsAirlineFunded 
                            returns(bool _success, uint256 _votes){
        require(!isAirlineRegistered(_airlineAccount), "Already registered");
        _success = false;
        _votes =0;

        uint256 airlinesCount = flightSuretyData.getAirlinesCount();
        if (airlinesCount < AIRLINES_THRESHOLD) {
            flightSuretyData.registerAirline(_airlineAccount, _airlineName);
            _success = true;
        } else {
            uint256 votesNeeded = airlinesCount.mul(100).div(2);
            addVote(_airlineAccount, msg.sender);
            _votes = votes[_airlineAccount].gotVotes;
            if (_votes.mul(100) >= votesNeeded) {
                flightSuretyData.registerAirline(_airlineAccount, _airlineName);
                _success = true;
            }
        }
        emit RegisterAirlineSuccess(_success, _votes);


    }

    function fund() external payable requireIsOperational requireIsAirlineRegistered {
        require(msg.value >= MIN_FUND,"Airline funding requires at least 10 Ether");
        // dataContractAddress.transfer(msg.value);
        flightSuretyData.fund.value(msg.value)(msg.sender);
    }

   /**
    * @dev Register a future flight for insuring.
    *
    */  
    function registerFlight( string _airlineName,
                                uint256 _departureTime
                            )
                                external
                                requireIsOperational
                                requireIsAirlineRegistered
                                requireIsAirlineFunded
                                requireIsFutureFlight(_departureTime)
    {
        bytes32 flightKey = getFlightKey(msg.sender, _airlineName, _departureTime);
        flights[flightKey] = Flight(true, STATUS_CODE_UNKNOWN, now, msg.sender);
        emit FlightRegistered(msg.sender, _airlineName, _departureTime);
    }
    
   /**
    * @dev Called after oracle has updated flight status
    *
    */  
    function processFlightStatus(
                                    address _airlineAccount,
                                    string memory _airlineName,
                                    uint256 _departureTime,
                                    uint8 _statusCode
                                )
                                internal
    {
        bytes32 flightKey = getFlightKey(_airlineAccount, _airlineName, _departureTime);
        flights[flightKey].updatedTimestamp = now;
        flights[flightKey].statusCode = _statusCode;
    }


    // Generate a request for oracles to fetch flight information
    function fetchFlightStatus(
                            address _airlineAccount,
                            string _airlineName,
                            uint256 _departureTime                            
                        )
                        external
    {
        uint8 index = getRandomIndex(msg.sender);

        // Generate a unique key for storing the request
        bytes32 key = keccak256(abi.encodePacked(index, _airlineAccount, _airlineName, _departureTime));
        oracleResponses[key] = ResponseInfo({
                                                requester: msg.sender,
                                                isOpen: true
                                            });

        emit OracleRequest(index, _airlineAccount, _airlineName, _departureTime);
    } 


    function buyInsurance(address _airlineAccount,
                            string _airlineName,
                            uint256 _departureTime
    ) external
    payable
    requireIsOperational {
        require(!isAirlineRegistered(msg.sender), "Caller is airline account");
        require(now < _departureTime, "Insurance is not available after flight departure");
        require(msg.value <= MAX_PREMIUM, "Max premium 1 Ether");
        bytes32 flightKey = getFlightKey(_airlineAccount, _airlineName, _departureTime);
        require(flights[flightKey].isRegistered == true, "Airline is not registered");
        // dataContractAddress.transfer(msg.value);
        flightSuretyData.buy.value(msg.value)(msg.sender,_airlineAccount,_airlineName,_departureTime);
        emit InsurancePurchaseSuccess(msg.sender, msg.value, _airlineAccount,_airlineName,_departureTime);
    }

    function claimCredit(address _airlineAccount,
                            string _airlineName,
                            uint256 _departureTime
    ) external
    requireIsOperational {
        bytes32 flightKey = getFlightKey(_airlineAccount, _airlineName, _departureTime);
        require(flights[flightKey].statusCode == STATUS_CODE_LATE_AIRLINE, "Flight is not delayed due to any issues caused by the airline");
        require(now > flights[flightKey].updatedTimestamp, "Plz wait for flight status to be updated");
        flightSuretyData.creditInsurees(PERCENTAGE_PAY,_airlineAccount,_airlineName,_departureTime);
    }

    function withdrawCredits()
    external
    requireIsOperational {
        require(flightSuretyData.getPassengerTotalCredits(msg.sender) > 0, "No credits available");
        flightSuretyData.pay(msg.sender);
    }

// region ORACLE MANAGEMENT

    // Incremented to add pseudo-randomness at various points
    uint8 private nonce = 0;    

    // Fee to be paid when registering oracle
    uint256 public constant REGISTRATION_FEE = 1 ether;

    // Number of oracles that must respond for valid status
    uint256 private constant MIN_RESPONSES = 3;


    struct Oracle {
        bool isRegistered;
        uint8[3] indexes;        
    }

    // Track all registered oracles
    mapping(address => Oracle) private oracles;

    // Model for responses from oracles
    struct ResponseInfo {
        address requester;                              // Account that requested status
        bool isOpen;                                    // If open, oracle responses are accepted
        mapping(uint8 => address[]) responses;          // Mapping key is the status code reported
                                                        // This lets us group responses and identify
                                                        // the response that majority of the oracles
    }

    // Track all oracle responses
    // Key = hash(index, flight, timestamp)
    mapping(bytes32 => ResponseInfo) private oracleResponses;

    // Event fired each time an oracle submits a response
    event FlightStatusInfo(address airline, string flight, uint256 timestamp, uint8 status);

    event OracleReport(address airline, string flight, uint256 timestamp, uint8 status);

    // Event fired when flight status request is submitted
    // Oracles track this and if they have a matching index
    // they fetch data and submit a response
    event OracleRequest(uint8 index, address airline, string flight, uint256 timestamp);


    // Register an oracle with the contract
    function registerOracle
                            (
                            )
                            external
                            payable
    {
        // Require registration fee
        require(msg.value >= REGISTRATION_FEE, "Registration fee is required");

        uint8[3] memory indexes = generateIndexes(msg.sender);

        oracles[msg.sender] = Oracle({
                                        isRegistered: true,
                                        indexes: indexes
                                    });
    }

    function getMyIndexes
                            (
                            )
                            view
                            external
                            returns(uint8[3])
    {
        require(oracles[msg.sender].isRegistered, "Not registered as an oracle");

        return oracles[msg.sender].indexes;
    }




    // Called by oracle when a response is available to an outstanding request
    // For the response to be accepted, there must be a pending request that is open
    // and matches one of the three Indexes randomly assigned to the oracle at the
    // time of registration (i.e. uninvited oracles are not welcome)
    function submitOracleResponse
                        (
                            uint8 index,
                            address airline,
                            string flight,
                            uint256 timestamp,
                            uint8 statusCode
                        )
                        external
    {
        require((oracles[msg.sender].indexes[0] == index) || (oracles[msg.sender].indexes[1] == index) || (oracles[msg.sender].indexes[2] == index), "Index does not match oracle request");


        bytes32 key = keccak256(abi.encodePacked(index, airline, flight, timestamp)); 
        require(oracleResponses[key].isOpen, "Flight or timestamp do not match oracle request");

        oracleResponses[key].responses[statusCode].push(msg.sender);

        // Information isn't considered verified until at least MIN_RESPONSES
        // oracles respond with the *** same *** information
        emit OracleReport(airline, flight, timestamp, statusCode);
        if (oracleResponses[key].responses[statusCode].length >= MIN_RESPONSES) {

            emit FlightStatusInfo(airline, flight, timestamp, statusCode);

            // Handle flight status as appropriate
            processFlightStatus(airline, flight, timestamp, statusCode);
        }
    }


    function getFlightKey
                        (
                            address airline,
                            string flight,
                            uint256 timestamp
                        )
                        pure
                        internal
                        returns(bytes32) 
    {
        return keccak256(abi.encodePacked(airline, flight, timestamp));
    }

    // Returns array of three non-duplicating integers from 0-9
    function generateIndexes
                            (                       
                                address account         
                            )
                            internal
                            returns(uint8[3])
    {
        uint8[3] memory indexes;
        indexes[0] = getRandomIndex(account);
        
        indexes[1] = indexes[0];
        while(indexes[1] == indexes[0]) {
            indexes[1] = getRandomIndex(account);
        }

        indexes[2] = indexes[1];
        while((indexes[2] == indexes[0]) || (indexes[2] == indexes[1])) {
            indexes[2] = getRandomIndex(account);
        }

        return indexes;
    }

    // Returns array of three non-duplicating integers from 0-9
    function getRandomIndex
                            (
                                address account
                            )
                            internal
                            returns (uint8)
    {
        uint8 maxValue = 10;

        // Pseudo random number...the incrementing nonce adds variation
        uint8 random = uint8(uint256(keccak256(abi.encodePacked(blockhash(block.number - nonce++), account))) % maxValue);

        if (nonce > 250) {
            nonce = 0;  // Can only fetch blockhashes for last 256 blocks so we adapt
        }

        return random;
    }

// endregion

}   

// Interface to FlightSuretyData.sol
interface FlightSuretyData {

    function isOperational() external view returns(bool);

    function isAirlineRegistered(address _airlineAccount) external view returns(bool);

    function isAirlineFunded(address _airlineAccount) external view returns(bool);

    function getAirlinesCount() external view returns(uint256);

    function registerAirline(address _airlineAccount,string _airlineName) external;

    function fund(address _airlineAccount) external payable;

    function buy(address _passengerAccount,address _airlineAccount,string _airlineName,uint256 _departureTime) external payable ;

    function creditInsurees(uint256 _percentagePay,address _airlineAccount,string  _airlineName,uint256 _departureTime) external ;

    function getPassengerTotalCredits(address _passengerAccount) external view returns(uint256);

    function pay(address _passengerAccount) external ;
}