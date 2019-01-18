pragma solidity ^0.4.23;

import "openzeppelin-solidity/contracts/ownership/Ownable.sol";
import "openzeppelin-solidity/contracts/math/SafeMath.sol";

interface ITOKEN {

    function balanceOf(address owner) public view returns (uint256);
    function transferFrom(address from, address to, uint256 value) public returns (bool);
    function transfer(address to, uint256 value) public returns (bool);
}

contract ApproveAndCallFallBack {
    function receiveApproval(address from, uint256 _amount, address _token, bytes _data) public;
    function isContract(address _addr) internal view returns(bool) {
        uint size;
        if (_addr == 0) return false;
        assembly {
            size := extcodesize(_addr)
        }
        return size>0;
    }
}

contract DexBridge is ApproveAndCallFallBack, Ownable {
    using SafeMath for uint256;

    uint256 public minFeeToken;

    address public feeOwner;

    address public tokenAddress;

    //deployed contract network
    uint256 public network;

    uint256 public initFeeRatio;

    uint256 public startTime;

    uint256 public maxDexAmount;

    uint256 internal constant TIMEDURATION = 6*3600;

    /// Event created on initilizing token dex in source network.
    event DexToken (bytes32 indexed dexNonce, address from, address to,
        uint256 dexAmount, uint256 approvedToken,uint256 requiredFee, uint256 network, uint256 dstNetwork);
    event ClaimedTokens(address indexed _token, address indexed _controller, uint _amount);


    /// Constructor.
    constructor (
        address tokenAddressParam,
        uint256 minFeeTokenParam,
        address feeOwnerParam,
        uint256 networkParam,
        uint256 initFeeRatioParam,
        uint256 maxDexAmountParam
    ) public
    {
        require(tokenAddressParam != address(0) && isContract(tokenAddressParam), "token address is invalid!");

        tokenAddress = tokenAddressParam;
        minFeeToken = minFeeTokenParam;
        feeOwner = feeOwnerParam;

        network = networkParam;
        initFeeRatio = initFeeRatioParam;

        maxDexAmount = maxDexAmountParam;

        startTime = now;
    }

    //users initial the exchange token with token method of "approveAndCall" in the source chain network
    //then invoke the following function in this contract
    //_amount include the fee token
    function receiveApproval(address from, uint256 _amount, address _token, bytes _data) public {

        require(_token == tokenAddress, "init dex token address error!");
        require(msg.sender == tokenAddress, "this function should be only invoked by token contract!");

        uint256 dexAmount;
        uint256 dstNetwork;
        address receipt;
        uint256 unixtime;

        assembly {
            let ptr := mload(0x40)
            calldatacopy(ptr, 0, calldatasize)
            dexAmount := mload(add(ptr, 164))
            dstNetwork := mload(add(ptr, 196))
            receipt :=  mload(add(ptr, 228))
            unixtime := mload(add(ptr, 260))
        }

        require(_amount > dexAmount, "init approved ones not much more that the dex token amount!");

        ITOKEN token = ITOKEN(_token);
        require(token.balanceOf(from) >= _amount, "the user token balance is not enough!");

        uint256 requiredFee = queryDexFee(dexAmount);
        require(requiredFee <= _amount - dexAmount, "the user fee token is too less!");

        if(requiredFee > 0){
            require(token.transferFrom(from,feeOwner,requiredFee), "init transfer fee token fail!");
        }

        require(token.transferFrom(from,this,dexAmount), "init transfer locking token fail!");

        bytes32 dexNonce =  keccak256(abi.encodePacked(from, receipt, dexAmount, network, dstNetwork, unixtime));

        emit DexToken(dexNonce, from, receipt, dexAmount,_amount,requiredFee, network, dstNetwork);

    }


    function setMinFeeToken(uint256 token) public onlyOwner{
        require(token >= 100 * 10**18, "min fee ring is too less!");
        minFeeToken = token;
    }

    function setFeeOwner(address newFeeOwner) public onlyOwner{
        require(feeOwner != newFeeOwner, "fee owner is same to the old one!");
        feeOwner = newFeeOwner;
    }

    function setStartTime(uint256 tick) public onlyOwner{
        require(tick > startTime, "start time is not valid!");

        startTime = tick;

    }

    function setMaxDexAmount(uint256 amount) public onlyOwner{
        maxDexAmount = amount;
    }

    function queryDexFee(uint256 amount) public view returns (uint256) {
        if (now - startTime >= TIMEDURATION || now <= startTime) {
            return minFeeToken;
        }

        uint256 dt = now - startTime;
        uint256 tmp = initFeeRatio;
        uint256 required = tmp.mul(amount).mul(TIMEDURATION - dt).div(TIMEDURATION * 100);

        if (required < minFeeToken ){
            required =  minFeeToken;
        }

        return required;
    }

    function claimTokens(address _token) public onlyOwner {
        if (_token == 0x0) {
            address(msg.sender).transfer(address(this).balance);
            return;
        }

        ITOKEN token = ITOKEN(_token);
        uint balance = token.balanceOf(this);
        token.transfer(address(msg.sender), balance);

        emit ClaimedTokens(_token, address(msg.sender), balance);
    }
}
