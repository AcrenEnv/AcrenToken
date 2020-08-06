pragma solidity 0.6.8;

import "./oz/Ownable.sol";
import "./oz/SafeMath.sol";
import "./oz/ERC20.sol";

import "./bancor/BancorFormula.sol";

contract AcrenToken is Ownable, ERC20,  BancorFormula {
    using SafeMath for uint;
    using Address for address;

    uint256 internal reserve;
    uint32 public reserveRatio;
    mapping (address => uint256) private unlocked;
    uint public lowerBound;
    uint public upperBound;
    uint public defaultFundingRatio;
    uint public sellFee;
    address public platformAddress;

    event Minted(address sender, uint amount, uint deposit);
    event Burned(address sender, uint amount, uint refund);

    modifier isPlatform() {
        require(platformAddress == _msgSender(), "Caller is not the registered Plattform.");
        _;
    }

    modifier isInRange(uint _percentageFunding) {
        require(_percentageFunding >= lowerBound, "Chosen Percentage is below lowerBound.");
        require(_percentageFunding <= upperBound, "Chosen Percentage is over upperBound.");
        _;
    }

    constructor(
        string memory _name,
        string memory _symbol,
        uint _initialSupply,
        uint32 _reserveRatio,
        address _platformAddress,
        uint _sellFee
    ) public payable ERC20(_name, _symbol) {
        reserveRatio = _reserveRatio;
        sellFee = _sellFee;
        platformAddress = _platformAddress;
        _mint(msg.sender, _initialSupply);
        reserve = msg.value;
    }

    function Supply() public view returns (uint) {
        return totalSupply();
    }

    function lowerBoundFundingRatio() public view returns (uint) {
        return lowerBound;
    }

    function upperBoundFundingRatio() public view returns (uint) {
        return upperBound;
    }

    function FundingRatio() public view returns (uint) {
        return defaultFundingRatio;
    }

    function reserveBalance() public view returns (uint) {
        return reserve;
    }

    function getMintReward(uint _depositTokenAmount) public view returns (uint) {
        return calculatePurchaseReturn(Supply(), reserveBalance(), reserveRatio, _depositTokenAmount);
    }

    function getBurnRefund(uint _bondingTokenAmount) public view returns (uint) {
        return calculateSaleReturn(Supply(), reserveBalance(), reserveRatio, _bondingTokenAmount);
    }

    function updatePlatform(address _platformAddress) onlyOwner() public returns (bool) {
        require(_platformAddress.isContract(), "Address must be a Contract address ");
        platformAddress = _platformAddress;
        return true;
    }

    function updateRatioConfiguration(uint _lowerBound, uint _upperBound, uint _defaultFundingRatio) isPlatform() public returns (bool) {
        require(_lowerBound > 0, "Lower Bound Percentage has to be over 0");
        require(_lowerBound < 100, "Lower Bound Percentage has to be below 100");
        require(_upperBound > 0, "Upper Bound Percentage has to be over 0");
        require(_upperBound < 100, "Upper Bound Percentage has to be below 100");
        require(_defaultFundingRatio > 0, "Default Percentage has to be over 0");
        require(_defaultFundingRatio < 100, "Default Percentage has to be below 100");
        lowerBound = _lowerBound;
        upperBound = _upperBound;
        defaultFundingRatio = _defaultFundingRatio;
    }

 //   fallback () external payable { contribute(); }

  //  receive () external payable { contribute(); }

    function contribute() public payable returns (bool) {
        (uint fundingAmount, uint tokenAmount) = calculate (msg.value, defaultFundingRatio);
        _sendToPlatform(fundingAmount, platformAddress);
        _mint(tokenAmount);
        return true;
    }

    function contribute(uint _percentageFunding) isInRange(_percentageFunding) public payable returns (bool) {
        (uint fundingAmount, uint tokenAmount) = calculate (msg.value, _percentageFunding);
        _sendToPlatform(fundingAmount, platformAddress);
        _mint(tokenAmount);
        return true;
    }

    function contribute(uint _percentageFunding, address _campaign) isInRange(_percentageFunding) public payable returns (bool) {
        (uint fundingAmount, uint tokenAmount) = calculate (msg.value, _percentageFunding);
        _sendToPlatform(fundingAmount, _campaign);
        _mint(tokenAmount);
        return true;
    }

    function calculate(uint _amount, uint _percentage) public pure returns (uint calculatedFundingAmount, uint calculatedTokenAmount) {
        calculatedFundingAmount = _amount.mul(_percentage);
        calculatedFundingAmount = calculatedFundingAmount.div(100);
        calculatedTokenAmount = _amount.sub(calculatedFundingAmount);
        return (calculatedFundingAmount, calculatedTokenAmount);
    }
    
    function unlock(address _user, uint256 _amount) isPlatform() public payable returns (bool) {
        unlocked[_user].add(_amount);
    }

    function buy() public payable returns (bool) {
        //TODO: accept value of the unlocked tokens and send rest back 
       require(unlocked[msg.sender] > msg.value, "You are not allowed to buy so much tokens.");
        _mint(msg.value);
        unlocked[msg.sender] = unlocked[msg.sender].sub(msg.value);
        return true;
    }

    function sell(uint _amount) public returns (bool) {
        require(_amount > 0, "Amount must be non-zero.");
        (uint fundingAmount, uint tokenAmount) = calculate(_amount, sellFee);
        _burn(fundingAmount, tokenAmount, platformAddress);
        return true;
    }

    function sell(uint _amount, address _campaign) public returns (bool) {
        require(_amount > 0, "Amount must be non-zero.");
        require(balanceOf(msg.sender) >= _amount, "Insufficient tokens to burn.");
        (uint fundingAmount, uint tokenAmount) = calculate(_amount, sellFee);
        _burn(fundingAmount, tokenAmount, _campaign);
        return true;
    }


    function _mint(uint _purchaseAmount) internal {
        require(_purchaseAmount > 0, "Deposit must be non-zero.");
        uint rewardAmount = getMintReward(_purchaseAmount);
        _mint(msg.sender, rewardAmount);
        emit Minted(msg.sender, rewardAmount, _purchaseAmount);
        reserve = reserve.add(_purchaseAmount);
    }

    function _burn(uint _fundingAmount, uint _tokenAmount, address _fundingAddress) internal {
        uint refundFundingAmount = getBurnRefund(_fundingAmount);
        uint refundTokenAmount = getBurnRefund(_tokenAmount);
        _burn(msg.sender, _fundingAmount + _tokenAmount);
        emit Burned(msg.sender, _fundingAmount + _tokenAmount, refundFundingAmount + refundTokenAmount);
        reserve = reserve.sub(refundFundingAmount + refundTokenAmount);
        _sendToPlatform(refundFundingAmount, _fundingAddress);
        msg.sender.transfer(refundTokenAmount);
    }
    
    function _sendToPlatform(uint _amount, address _campaign) internal {
        require(_amount > 0, "Deposit must be non-zero.");
        //checkIfRegisteredPlatformOrCampaign
        //sendToCampaignOrPlatform
    }
}