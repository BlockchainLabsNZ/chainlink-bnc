pragma solidity 0.4.24;

import "openzeppelin-solidity/contracts/math/Math.sol";
import "openzeppelin-solidity/contracts/token/ERC20/IERC20.sol";
import "chainlink/contracts/ChainlinkClient.sol";
import "chainlink/contracts/Chainlink.sol";

/// @title Futures
/// USAGE
/// 1. deploy into Ropsten https://faucet.ropsten.be/
/// 2. send LINK tokens to the contract https://ropsten.chain.link/
/// 3. initialize
/// 4. anybody can call check (need to filter this)
/// 5a. anybody can call call (need to filter this) after finishContract
/// 5b. if is American style, anybody can call call (need to filter this) before finishContract
/// 6. if contract is finished, the price wont be updated.
/// @dev https://docs.chain.link/docs/bravenewcoin
contract Futures is ChainlinkClient {
    struct Asset {
        string symbol;
        uint256 decimals;
    }

    struct Price {
        uint256 at;
        uint256 value;
    }

    /// @notice Link Token
    address private constant LINK_TOKEN = address(
        0x20fE562d797A42Dcb3399062AE9546cd06f63280
    );
    /// @notice Oracle contract that will provide the rates.
    address private constant ORACLE = address(
        0xc99B3D447826532722E41bc36e644ba3479E4365
    );
    /// @notice Job ID that the Oracle will use to execute the propper task.
    bytes32 private constant JOB_ID = 0x56b8d86f85114952a1b80b4337864d02;
    /// @notice amount of Link Token to pay per query
    uint256 public oraclePayment;
    mapping(uint256 => uint256) private requestIds;
    /// @notice Original owner of baseAsset
    address public seller;
    /// @notice The current buyer
    address public buyer;
    /// @notice Timestamp from when the contract will start
    uint256 public startContract;
    /// @notice Timestamp from when the contract will finish
    uint256 public finishContract;
    /// @notice Asset that is gonna be given.
    Asset public cryptoAsset;
    /// @notice Asset that is gonna be received.
    Asset public marketAsset;
    /// @notice Amount of base comodity to exchange.
    uint256 public amount;
    /// @notice rate at startContract
    uint256 public initialRate;
    /// @notice rate at finishContract
    Price public finalRate;
    /// @notice American style
    bool public american;

    /// @dev American Futures can `call` at any point in time.
    modifier onlyAmerican {
        require(american || finishContract <= now);
        _;
    }

    modifier notInitialized {
        require(initialRate.value == 0);
        _;
    }

    modifier notFinished {
        require(finishContract <= now);
        _;
    }

    /**
     * @notice Futures constructor
     * @param _startContract Timestamp from when the contract will start
     * @param _duration duration of the life of this contract
     * @param _amount amount of baseAsset
     * @param _cryptoAssetCode Code for baseAsset
     * @param _cryptoAssetDecimals Amount of decimals for baseAsset
     * @param _marketAssetCode Code for buyAsset
     * @param _marketAssetDecimals Amount of decimals for buyAsset
     * @param _oraclePayment Amount of Link Token to pay per query
     */
    constructor(
        uint256 _startContract,
        uint256 _duration,
        uint256 _amount,
        string _cryptoAssetSymbol,
        uint256 _cryptoAssetDecimals,
        string _marketAssetSymbol,
        uint256 _marketAssetDecimals,
        uint256 _oraclePayment
    ) public {
        startContract = _startContract;
        finishContract = startContract.add(_duration);
        amount = _amount;
        cryptoAsset = Asset({
            symbol: _baseAssetSymbol,
            decimals: _baseAssetDecimals
        });
        marketAsset = Asset({
            symbol: _buyAssetSymbol,
            decimals: _buyAssetDecimals
        });
        setPublicChainlinkToken();
        oraclePayment = _oraclePayment;
    }

    function initialize() public notInitialized {
        requestEthereumPrice(startContract, this.updateInitialRate.selector);
    }

    /// @notice Check the rate of the baseAsset to buyAsset
    /// @dev It will use 1 LINK Token
    /// @return rate at the current time or finishContract
    function check() public pure notFinished {
        requestEthereumPrice(now, this.updateFinalRate.selector);
    }

    /// @notice Store the rate of the baseAsset to buyAsset and finish the
    /// contract.
    /// @dev It will use 1 LINK Token
    function call() public onlyAmerican {
        requestEthereumPriceAndFinish(
            now,
            this.updateFinalRateAndFinish.selector
        );
    }

    function updateInitialRate(bytes32 _requestId, uint256 _price)
        external
        recordChainlinkFulfillment(_requestId)
    {
        if (initialRate.value > 0) return;
        initialRate = Price({at: requestIds[requestId], value: _price});
    }

    function updateFinalRate(bytes32 _requestId, uint256 _price)
        external
        recordChainlinkFulfillment(_requestId)
    {
        if (requestIds[requestId] < finalRate.at) return;
        finalRate = Price({at: requestIds[requestId], value: _price});
    }

    function updateFinalRateAndFinish(bytes32 _requestId, uint256 _price)
        external
        recordChainlinkFulfillment(_requestId)
    {
        finishContract = Math.min256(finishContract, requestIds[requestId]);
        updateFinalRate(_requestId, price);
    }

    function requestEthereumPrice(
        uint256 _from,
        bytes4 _callbackFunctionSignature
    ) internal {
        Chainlink.Request memory req = buildChainlinkRequest(
            stringToBytes32(JOB_ID),
            this,
            _callbackFunctionSignature
        );
        req.add("endpoint", "mwa-historic");
        req.add("coin", cryptoAsset.symbol); // "eth"
        req.add("market", marketAsset.symbol); // "usd"
        req.addInt("times", marketAsset.decimals);
        req.addInt("from", _from);
        uint256 requestId = sendChainlinkRequestTo(ORACLE, req, oraclePayment);
        requestIds[requestId] = _from;
    }

}
